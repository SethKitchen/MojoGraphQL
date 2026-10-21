# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A WebSocket server on one port with HTTP/1.1: an epoll event loop that
reads the first request of each connection.

A request with `Upgrade: websocket` on `ServerConfig.path` gets the
opening handshake, and the connection is then a WebSocket. A `WsHandler`
gets each connection as it opens, each message, and each close. Any other
request goes to an HTTP/1.1 server of gql_http, in the same process, with
its epoll descriptor inside this loop. So one port serves GraphQL over
HTTP and over WebSocket.

The handler sends through `Sockets`, the table of open connections: at
once in a callback, or later from `on_tick`, which the loop calls on each
turn. A handler with its own event source, such as a stream event loop,
gives its descriptor in `fd`, and the server watches it.

Back pressure: a connection with output that waits for the peer is
watched for `EPOLLOUT`. A send over `WsConfig.max_write_buffer_size`
raises `WRITE_BUFFER_FULL` to the handler, which can drop the message or
close the connection.

This module ports the server role of tungstenite 0.30.0 `src/server.rs`
(`accept_hdr`) on the event loop of gql_http2 `server.mojo`.

Differences from upstream: tungstenite serves a stream that its caller
accepted, and has no event loop and no HTTP. Here the server listens,
serves HTTP/1.1 with gql_http, and reads all connections in one loop, as
the `ws` server of Node.js on an `http.Server` does. A connection that
does not answer a close frame in `ServerConfig.close_timeout_ms` is
closed, as `ws` does after its close timeout.
"""

from std.time import perf_counter_ns

from gql_http.error import HttpError
from gql_http.parser import ParseState, Request, RequestReader
from gql_http.status import Status
from gql_http.server import (
    Handler,
    Listener,
    ResponseWriter,
    detached,
    open_listener,
)
from gql_http.server import Server as HttpServer
from gql_http.server import ServerConfig as HttpConfig
from gql_http.socket import (
    EAGAIN,
    EINTR,
    EPOLL_CTL_ADD,
    EPOLL_CTL_DEL,
    EPOLL_CTL_MOD,
    EPOLL_EVENT_SIZE,
    EPOLLIN,
    EPOLLOUT,
    Sys,
    event_fd,
    event_flags,
)

from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.handshake import is_upgrade, reject_response, server_response
from gql_ws.protocol import Message, MessageKind, Role, WebSocket, WsConfig

comptime _FD_BITS = 20
"""The low bits of a connection id hold its descriptor."""
comptime _FD_MASK = (1 << _FD_BITS) - 1


struct ServerConfig(Copyable, Movable):
    """The configuration of a WebSocket server."""

    var http: HttpConfig
    """The address, the port, the request limits, `idle_timeout_ms` for
    the handshake, `max_connections` and `max_events`, as for gql_http."""
    var ws: WsConfig
    """The limits of each WebSocket connection."""
    var path: String
    """The path of the WebSocket endpoint; empty takes every path."""
    var protocols: List[String]
    """The subprotocols that the server supports, by preference."""
    var close_timeout_ms: Int
    """How long a close frame waits for its reply; 30000 at first, as
    the `closeTimeout` of `ws`."""

    def __init__(out self):
        """Make the defaults: every path, no subprotocol."""
        self.http = HttpConfig()
        self.ws = WsConfig()
        self.path = String()
        self.protocols = List[String]()
        self.close_timeout_ms = 30000


struct _Conn(Movable):
    """The state of one connection of the loop."""

    var fd: Int
    var id: Int
    var open: Bool
    var detect: List[UInt8]
    var ws: WebSocket
    var protocol: String
    var path: String
    var deadline_ms: Int
    var interest: UInt32
    var code: UInt16
    var reason: String

    def __init__(out self, config: WsConfig):
        self.fd = -1
        self.id = -1
        self.open = False
        self.detect = List[UInt8]()
        self.ws = WebSocket(Role.SERVER, config)
        self.protocol = String()
        self.path = String()
        self.deadline_ms = 0
        self.interest = 0
        self.code = CloseCode.ABNORMAL.value
        self.reason = String()


struct Sockets(Movable):
    """The open WebSocket connections, by id, for a handler to send on.

    An id stays valid until `on_close`; after that, each call with it
    does nothing.
    """

    var conns: List[_Conn]
    """The connections, by descriptor."""
    var dirty: List[Int]
    """The descriptors with new output."""
    var now_ms: Int
    """The time of the loop turn, from a monotonic clock."""
    var close_timeout_ms: Int
    """How long a close frame waits for its reply."""
    var _serial: Int
    var _config: WsConfig

    def __init__(out self, config: WsConfig, close_timeout_ms: Int):
        """Make an empty table.

        Args:
            config: The limits of each connection.
            close_timeout_ms: How long a close frame waits for its reply.
        """
        self.close_timeout_ms = close_timeout_ms
        self.conns = List[_Conn]()
        self.dirty = List[Int]()
        self.now_ms = 0
        self._serial = 0
        self._config = config.copy()

    def _slot(self, id: Int) -> Int:
        """Return the descriptor of an open connection, or -1."""
        var fd = id & _FD_MASK
        if id < 0 or fd >= len(self.conns):
            return -1
        if self.conns[fd].id != id or not self.conns[fd].open:
            return -1
        return fd

    def is_open(self, id: Int) -> Bool:
        """Return True for the id of an open WebSocket.

        Args:
            id: The connection id.

        Returns:
            Whether the connection is open and can send.
        """
        var fd = self._slot(id)
        return fd >= 0 and self.conns[fd].ws.can_write()

    def protocol(self, id: Int) -> String:
        """Return the subprotocol of a connection.

        Args:
            id: The connection id.

        Returns:
            The protocol that the handshake chose, or empty.
        """
        var fd = self._slot(id)
        if fd < 0:
            return String()
        return self.conns[fd].protocol

    def path(self, id: Int) -> String:
        """Return the request path of a connection.

        Args:
            id: The connection id.

        Returns:
            The path of the Upgrade request, or empty.
        """
        var fd = self._slot(id)
        if fd < 0:
            return String()
        return self.conns[fd].path

    def pending(self, id: Int) -> Int:
        """Return the output of a connection that waits for the peer.

        Args:
            id: The connection id.

        Returns:
            The count of bytes; 0 for a closed connection.
        """
        var fd = self._slot(id)
        if fd < 0:
            return 0
        return self.conns[fd].ws.pending()

    def _touch(mut self, fd: Int):
        """Note new output on a connection."""
        self.dirty.append(fd)

    def send_text(mut self, id: Int, text: StringSlice) raises WsError -> Bool:
        """Send a text message.

        Args:
            id: The connection id.
            text: The text.

        Returns:
            False when the id is not open.

        Raises:
            WsError: `WRITE_BUFFER_FULL` when the output has no room, and
                `SEND_AFTER_CLOSING` after a close frame.
        """
        var fd = self._slot(id)
        if fd < 0:
            return False
        self.conns[fd].ws.send_text(text)
        self._touch(fd)
        return True

    def send_binary(
        mut self, id: Int, data: Span[UInt8, _]
    ) raises WsError -> Bool:
        """Send a binary message.

        Args:
            id: The connection id.
            data: The bytes.

        Returns:
            False when the id is not open.

        Raises:
            WsError: As `send_text`.
        """
        var fd = self._slot(id)
        if fd < 0:
            return False
        self.conns[fd].ws.send_binary(data)
        self._touch(fd)
        return True

    def ping(mut self, id: Int, data: Span[UInt8, _]) raises WsError -> Bool:
        """Send a ping.

        Args:
            id: The connection id.
            data: The payload, at most 125 bytes.

        Returns:
            False when the id is not open.

        Raises:
            WsError: As `send_text`.
        """
        var fd = self._slot(id)
        if fd < 0:
            return False
        self.conns[fd].ws.ping(data)
        self._touch(fd)
        return True

    def close(
        mut self, id: Int, code: CloseCode, reason: StringSlice = ""
    ) -> Bool:
        """Start the closing handshake of a connection.

        The server closes the socket when the reply comes, or after
        `ServerConfig.close_timeout_ms`.

        Args:
            id: The connection id.
            code: The close code.
            reason: The reason; one over 123 bytes is not sent.

        Returns:
            False when the id is not open, or its close frame went out.
        """
        var fd = self._slot(id)
        if fd < 0 or not self.conns[fd].ws.can_write():
            return False
        var text = String(reason) if reason.byte_length() <= 123 else String()
        self.conns[fd].ws.go_away(code, text)
        self.conns[fd].deadline_ms = self.now_ms + self.close_timeout_ms
        self._touch(fd)
        return True

    def attach(
        mut self, slot: Int, protocol: StringSlice, path: StringSlice
    ) -> Int:
        """Open a WebSocket that a bridge carries, such as one on an HTTP/2
        stream (RFC 8441), in a slot that no socket uses.

        The bridge gives the bytes of the peer to `conns[slot].ws`, reads
        its messages, sends its output, and calls `detach` at the end.

        Args:
            slot: The slot, 0 or more; a bridge without sockets can use any.
            protocol: The subprotocol that the handshake chose, or empty.
            path: The request path.

        Returns:
            The id of the new connection.
        """
        while len(self.conns) <= slot:
            self.conns.append(_Conn(self._config))
        ref conn = self.conns[slot]
        conn.ws = WebSocket(Role.SERVER, self._config)
        conn.fd = slot
        conn.open = True
        conn.protocol = String(protocol)
        conn.path = String(path)
        conn.deadline_ms = Int.MAX
        conn.code = CloseCode.ABNORMAL.value
        conn.reason = String()
        self._serial += 1
        conn.id = (self._serial << _FD_BITS) | slot
        return conn.id

    def free_slot(self) -> Int:
        """Return the first slot that no WebSocket uses, for `attach`. A
        bridge without sockets uses it; a server with sockets must not.

        Returns:
            The slot; the end of the table when each slot is in use.
        """
        var slot = 0
        while slot < len(self.conns):
            if self.conns[slot].fd < 0:
                return slot
            slot += 1
        return slot

    def detach(mut self, slot: Int):
        """Free the slot of a WebSocket that a bridge carries. The ids of
        the slot are no longer open.

        Args:
            slot: The slot of `attach`.
        """
        ref conn = self.conns[slot]
        conn.fd = -1
        conn.open = False
        conn.code = CloseCode.ABNORMAL.value
        conn.reason = String()


trait WsHandler(Deinitable, Movable):
    """What a WebSocket server calls for its connections."""

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        """Start a connection after its handshake.

        Args:
            sockets: The open connections, to send on.
            id: The new connection.

        Raises:
            Error: Any error; the server closes the connection with 1011.
        """
        ...

    def on_message(
        mut self, mut sockets: Sockets, id: Int, message: Message
    ) raises:
        """Handle a text or binary message.

        Args:
            sockets: The open connections, to send on.
            id: The connection.
            message: The message; valid until the method returns.

        Raises:
            Error: Any error; the server closes the connection with 1011.
        """
        ...

    def on_close(
        mut self, mut sockets: Sockets, id: Int, code: UInt16, reason: String
    ):
        """Forget a connection that has closed.

        Args:
            sockets: The open connections; `id` is not one of them.
            id: The connection.
            code: The code of the close frame of the peer; 1005 for a close
                frame without a code, 1006 when none came.
            reason: The reason of the close frame of the peer.
        """
        ...

    def on_tick(mut self, mut sockets: Sockets) raises:
        """Do the work of one loop turn, such as timers and streams.

        Args:
            sockets: The open connections, to send on.

        Raises:
            Error: Any error; the server stops its loop with it.
        """
        ...

    def fd(self) -> Int:
        """Return a descriptor for the server to watch, or -1.

        When it is readable, the loop wakes and calls `on_tick`.

        Returns:
            The descriptor, such as the epoll descriptor of a stream loop.
        """
        ...

    def wait_ms(self) -> Int:
        """Return the longest wait of the loop before `on_tick`.

        Returns:
            Milliseconds, such as the time to the next timer; -1 for no
            limit.
        """
        ...


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


struct Server[W: WsHandler, H: Handler](Movable):
    """One event loop that serves WebSocket connections and HTTP/1.1.

    Parameters:
        W: The type of the WebSocket handler.
        H: The type of the HTTP handler.
    """

    var handler: Self.W
    """The handler of the WebSocket connections."""
    var sockets: Sockets
    """The connections."""
    var http1: HttpServer[Self.H]
    """The HTTP/1.1 server of the other requests."""
    var config: ServerConfig
    """The configuration."""
    var sys: Sys
    """The system calls of the loop."""
    var port: Int
    """The local port."""
    var open_connections: Int
    """The connections of this loop: WebSockets, and handshakes."""
    var draining: Bool
    """Whether a graceful shutdown has begun."""
    var _listen_fd: Int
    var _epoll_fd: Int
    var _events: List[UInt8]
    var _probe: RequestReader
    var _message: Message
    var _last_sweep: Int
    var _drain_deadline: Int

    def __init__(
        out self,
        var handler: Self.W,
        var http: Self.H,
        config: ServerConfig,
        listener: Listener,
        var sys: Sys,
    ) raises HttpError:
        """Serve on a listening socket that is open already.

        Args:
            handler: The handler of the WebSocket connections.
            http: The handler of the other HTTP/1.1 requests.
            config: The configuration.
            listener: The socket; the server closes it.
            sys: The system calls; tests give one with faults.

        Raises:
            HttpError: `OS` when epoll cannot be opened, or cannot watch the
                socket. The socket is closed.
        """
        self.handler = handler^
        self.sockets = Sockets(config.ws, config.close_timeout_ms)
        self.http1 = detached(http^, config.http)
        self.config = config.copy()
        self.sys = sys^
        self.port = listener.port
        self.open_connections = 0
        self.draining = False
        self._listen_fd = listener.fd
        self._epoll_fd = -1
        self._events = List[UInt8](
            length=max(config.http.max_events, 1) * EPOLL_EVENT_SIZE, fill=0
        )
        self._probe = RequestReader(config.http.limits)
        self._message = Message()
        self.sockets.now_ms = _now_ms()
        self._last_sweep = self.sockets.now_ms
        self._drain_deadline = 0
        var epoll = self.sys.epoll_create()
        if epoll < 0:
            self.close()
            raise HttpError.os("epoll_create1", -epoll)
        self._epoll_fd = epoll
        var rc = self.sys.epoll_ctl(epoll, EPOLL_CTL_ADD, listener.fd, EPOLLIN)
        if rc >= 0:
            rc = self.sys.epoll_ctl(
                epoll, EPOLL_CTL_ADD, self.http1.epoll_fd(), EPOLLIN
            )
        var extra = self.handler.fd()
        if rc >= 0 and extra >= 0:
            rc = self.sys.epoll_ctl(epoll, EPOLL_CTL_ADD, extra, EPOLLIN)
        if rc < 0:
            self.close()
            raise HttpError.os("epoll_ctl", -rc)

    def __deinit__(deinit self):
        """Close every descriptor that is still open."""
        self.close()

    def close(mut self):
        """Close the listening socket, every connection and epoll at once.

        The handler gets `on_close` for each open WebSocket.
        """
        var fd = 0
        while fd < len(self.sockets.conns):
            if self.sockets.conns[fd].fd >= 0:
                self._close(fd)
            fd += 1
        if self._listen_fd >= 0:
            self.sys.close(self._listen_fd)
            self._listen_fd = -1
        if self._epoll_fd >= 0:
            self.sys.close(self._epoll_fd)
            self._epoll_fd = -1
        self.http1.close()

    def stopped(self) -> Bool:
        """Return True when a graceful shutdown has ended.

        Returns:
            Whether both protocols drain and no connection is open.
        """
        return (
            self.draining
            and self.open_connections == 0
            and self.http1.stopped()
        )

    def run(mut self) raises:
        """Run the loop until a graceful shutdown ends.

        Raises:
            Error: `HttpError` when `epoll_wait` fails, or the error of
                `on_tick`.
        """
        while not self.stopped():
            _ = self.poll(-1)

    def begin_shutdown(mut self):
        """Stop accepting, and close each WebSocket with 1001 and each
        handshake at once. HTTP/1.1 drains as gql_http does."""
        if self.draining:
            return
        self.draining = True
        self._drain_deadline = (
            self.sockets.now_ms + self.config.http.shutdown_timeout_ms
        )
        if self._listen_fd >= 0:
            _ = self.sys.epoll_ctl(
                self._epoll_fd, EPOLL_CTL_DEL, self._listen_fd, 0
            )
            self.sys.close(self._listen_fd)
            self._listen_fd = -1
        self.http1.begin_shutdown()
        var fd = 0
        while fd < len(self.sockets.conns):
            if self.sockets.conns[fd].fd >= 0:
                if self.sockets.conns[fd].open:
                    self.sockets.conns[fd].ws.go_away(CloseCode.AWAY)
                    self.sockets.conns[fd].deadline_ms = (
                        self.sockets.now_ms + self.config.close_timeout_ms
                    )
                    self._flush(fd)
                else:
                    self._close(fd)
            fd += 1

    def listen_signals(mut self) raises HttpError:
        """Begin a graceful shutdown on `SIGTERM` or `SIGINT`.

        Call it only in a process with one thread, such as a worker.

        Raises:
            HttpError: `OS` when the `signalfd` cannot be opened or watched.
        """
        self.http1.listen_signals()

    def poll(mut self, timeout_ms: Int) raises -> Int:
        """Run one turn of the loop: wait for events, handle them, and call
        `on_tick` of the handler.

        Args:
            timeout_ms: The longest wait in milliseconds; -1 waits until an
                event. With open connections the wait is at most a second,
                and never longer than `wait_ms` of the handler.

        Returns:
            The count of events.

        Raises:
            Error: `HttpError` when `epoll_wait` fails, or the error of
                `on_tick`.
        """
        var wait = timeout_ms
        var busy = self.open_connections + self.http1.open_connections
        if busy > 0 or self.draining:
            wait = 1000 if wait < 0 else min(wait, 1000)
        var limit = self.handler.wait_ms()
        if limit >= 0:
            wait = limit if wait < 0 else min(wait, limit)
        if self.http1.streams() > 0:
            # A held HTTP response makes its content on each turn. It is an
            # open connection, so `wait` is not negative here.
            wait = min(wait, self.http1.config.stream_poll_ms)
        var count = self.sys.epoll_wait(
            self._epoll_fd,
            self._events.unsafe_ptr(),
            len(self._events) // EPOLL_EVENT_SIZE,
            wait,
        )
        if count == -EINTR:
            count = 0
        if count < 0:
            raise HttpError.os("epoll_wait", -count)
        self.sockets.now_ms = _now_ms()
        var events = self._events.unsafe_ptr()
        var extra = self.handler.fd()
        var index = 0
        while index < count:
            var fd = event_fd(events, index)
            var flags = event_flags(events, index)
            index += 1
            if fd == self._listen_fd:
                self._accept()
            elif fd == self.http1.epoll_fd():
                _ = self.http1.poll(0)
            elif fd == extra:
                # The handler reads its own source in `on_tick`.
                continue
            elif self.sockets.conns[fd].fd < 0:
                # The output of another connection closed it in this turn.
                continue
            elif flags & EPOLLOUT != 0:
                self._flush(fd)
            else:
                self._readable(fd)
        self.handler.on_tick(self.sockets)
        if self.http1.streams() > 0:
            self.http1.pump()
        self._flush_dirty()
        if self.http1.draining:
            self.begin_shutdown()
        if self.sockets.now_ms - self._last_sweep >= 1000 or self.draining:
            self._sweep()
        return count

    def _sweep(mut self) raises HttpError:
        """Close the connections whose deadline has passed, and let the
        HTTP/1.1 server sweep its own."""
        self._last_sweep = self.sockets.now_ms
        _ = self.http1.poll(0)
        var now = self.sockets.now_ms
        var force = self.draining and now >= self._drain_deadline
        var fd = 0
        while fd < len(self.sockets.conns):
            if self.sockets.conns[fd].fd >= 0 and (
                force or now >= self.sockets.conns[fd].deadline_ms
            ):
                self._close(fd)
            fd += 1

    def _accept(mut self):
        """Accept every pending connection."""
        while True:
            var fd = self.sys.accept(self._listen_fd)
            if fd < 0:
                return
            var open = self.open_connections + self.http1.open_connections
            if open >= self.config.http.max_connections:
                self.sys.close(fd)
                continue
            _ = self.sys.set_no_delay(fd)
            while len(self.sockets.conns) <= fd:
                self.sockets.conns.append(_Conn(self.config.ws))
            if (
                self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_ADD, fd, EPOLLIN)
                < 0
            ):
                self.sys.close(fd)
                continue
            ref conn = self.sockets.conns[fd]
            conn.fd = fd
            conn.open = False
            conn.ws = WebSocket(Role.SERVER, self.config.ws)
            conn.interest = EPOLLIN
            conn.deadline_ms = (
                self.sockets.now_ms + self.config.http.idle_timeout_ms
            )
            self.open_connections += 1

    def _close(mut self, fd: Int):
        """Close a connection, and tell the handler when it was open."""
        self.sys.close(fd)
        var was_open = self.sockets.conns[fd].open
        var id = self.sockets.conns[fd].id
        var code = self.sockets.conns[fd].code
        var reason = self.sockets.conns[fd].reason
        ref conn = self.sockets.conns[fd]
        conn.fd = -1
        conn.open = False
        conn.detect.clear()
        conn.code = CloseCode.ABNORMAL.value
        conn.reason = String()
        self.open_connections -= 1
        if was_open:
            self.handler.on_close(self.sockets, id, code, reason)

    def _watch(mut self, fd: Int, events: UInt32) -> Bool:
        """Set the events of a connection; False after closing it."""
        if self.sockets.conns[fd].interest == events:
            return True
        if self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_MOD, fd, events) < 0:
            self._close(fd)
            return False
        self.sockets.conns[fd].interest = events
        return True

    def _readable(mut self, fd: Int):
        """Read from a connection: its handshake, or its frames."""
        if not self.sockets.conns[fd].open:
            self._read_handshake(fd)
            return
        ref ws = self.sockets.conns[fd].ws
        ws.reserve(16384)
        var n = self.sys.recv(fd, ws.write_pointer(), ws.space())
        if n == -EAGAIN or n == -EINTR:
            return
        if n <= 0:
            _ = self.sockets.conns[fd].ws.peer_closed()
            self._close(fd)
            return
        self.sockets.conns[fd].ws.commit(n)
        self._process(fd)

    def _read_handshake(mut self, fd: Int):
        """Read the bytes of the first request of a connection."""
        ref detect = self.sockets.conns[fd].detect
        var size = len(detect)
        detect.resize(size + 16384, 0)
        var n = self.sys.recv(
            fd, detect.unsafe_ptr().unsafe_offset(size), 16384
        )
        detect.resize(size + max(n, 0), 0)
        if n == -EAGAIN or n == -EINTR:
            return
        if n <= 0:
            self._close(fd)
            return
        self._detect(fd)

    def _detect(mut self, fd: Int):
        """Choose WebSocket or HTTP/1.1 from the first request."""
        self._probe.reset()
        self._probe.append(self.sockets.conns[fd].detect)
        var result = self._probe.next()
        if result.state == ParseState.INCOMPLETE:
            return
        if result.state == ParseState.ERROR or not self._wants(
            self._probe.request
        ):
            self._adopt(fd)
            return
        ref conn = self.sockets.conns[fd]
        try:
            var accepted = server_response(
                self._probe.request, self.config.protocols
            )
            conn.ws.out.extend(Span(accepted.response))
            conn.protocol = accepted.protocol.copy()
        except e:
            # The answer goes out, and then the connection closes.
            conn.ws.out.extend(Span(reject_response(e)))
            _ = conn.ws.peer_closed()
            conn.detect.clear()
            self._flush(fd)
            return
        conn.path = String(self._probe.request.path())
        conn.ws.receive(Span(conn.detect)[result.size :])
        conn.detect.clear()
        conn.open = True
        self.sockets._serial += 1
        conn.id = (self.sockets._serial << _FD_BITS) | fd
        conn.deadline_ms = Int.MAX
        try:
            self.handler.on_open(self.sockets, self.sockets.conns[fd].id)
        except:
            self.sockets.conns[fd].ws.go_away(CloseCode.ERROR)
        self._process(fd)

    def _wants(self, request: Request) -> Bool:
        """Return True for an Upgrade request on the WebSocket path."""
        if not is_upgrade(request):
            return False
        return self.config.path.byte_length() == 0 or (
            request.path() == self.config.path
        )

    def _adopt(mut self, fd: Int):
        """Give a connection to the HTTP/1.1 server, with what it read."""
        _ = self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_DEL, fd, 0)
        self.sockets.conns[fd].fd = -1
        self.open_connections -= 1
        self.http1.adopt(fd, self.sockets.conns[fd].detect)
        self.sockets.conns[fd].detect.clear()

    def _process(mut self, fd: Int):
        """Read each whole message of a connection, and give it to the
        handler."""
        var id = self.sockets.conns[fd].id
        while True:
            var got: Bool
            try:
                got = self.sockets.conns[fd].ws.read(self._message)
            except:
                # The output holds the close frame of the failure.
                break
            if not got:
                break
            var kind = self._message.kind
            if kind == MessageKind.CLOSE:
                self.sockets.conns[fd].code = self._message.code.value
                self.sockets.conns[fd].reason = String(self._message.text())
            elif kind == MessageKind.TEXT or kind == MessageKind.BINARY:
                try:
                    self.handler.on_message(self.sockets, id, self._message)
                except:
                    self.sockets.conns[fd].ws.go_away(CloseCode.ERROR)
        self._flush(fd)
        self._flush_dirty()

    def _flush(mut self, fd: Int):
        """Send the output of a connection, and keep what the socket
        refuses. A connection with output waits for `EPOLLOUT` and is not
        read: that is the back pressure of a slow peer."""
        ref ws = self.sockets.conns[fd].ws
        var total = ws.pending()
        if total > 0:
            var sent = self.sys.send(fd, ws.output(), total)
            if sent == -EAGAIN or sent == -EINTR:
                sent = 0
            if sent < 0:
                _ = self.sockets.conns[fd].ws.peer_closed()
                self._close(fd)
                return
            self.sockets.conns[fd].ws.advance(sent)
            if sent < total:
                _ = self._watch(fd, EPOLLOUT)
                return
        if self.sockets.conns[fd].ws.should_close():
            self._close(fd)
            return
        _ = self._watch(fd, EPOLLIN)

    def _flush_dirty(mut self):
        """Send the output that the handler made."""
        while len(self.sockets.dirty) > 0:
            var fd = self.sockets.dirty.pop()
            if self.sockets.conns[fd].fd >= 0:
                self._flush(fd)


@fieldwise_init
struct UpgradeRequired(Handler):
    """An HTTP handler for a server without HTTP endpoints: each request
    gets `426 Upgrade Required`."""

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer 426 with `Upgrade: websocket`.

        Args:
            request: The request.
            response: The response.

        Raises:
            HttpError: Never, in practice: the fields are valid.
        """
        response.set_status(Status(426))
        response.add_header("Upgrade", "websocket")
        response.write_text("Upgrade Required")


def listen[
    W: WsHandler, H: Handler
](
    var handler: W, var http: H, config: ServerConfig, var sys: Sys = Sys()
) raises HttpError -> Server[W, H]:
    """Make a server that listens on the address and the port of a
    configuration, in this process.

    Args:
        handler: The handler of the WebSocket connections.
        http: The handler of the other HTTP/1.1 requests.
        config: The configuration.
        sys: The system calls; tests give one with faults.

    Returns:
        The server. Its `port` is the port it listens on.

    Raises:
        HttpError: `OS` when the socket or epoll cannot be opened.

    Parameters:
        W: The type of the WebSocket handler.
        H: The type of the HTTP handler.
    """
    var listener = open_listener(
        sys,
        config.http.host,
        config.http.port,
        config.http.backlog,
        config.http.reuse_port,
    )
    return Server(handler^, http^, config, listener, sys^)
