# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An h2c server for WebSockets over HTTP/2 (RFC 8441): an epoll event
loop with one `WsH2Session` per connection.

Each connection speaks HTTP/2 with prior knowledge. Its WebSockets are in
one `Sockets` of `gql_ws`, so a `WsHandler`, such as the
`graphql-transport-ws` server of `gql_ws`, serves them as it serves the
WebSockets of HTTP/1.1. Each other request goes to the gql_http `Handler`.

- **Turns.** `poll` waits for events, reads each connection, calls
  `on_tick`, and sends what the handler sent outside a read.
- **Handler source.** A `WsHandler` with an `fd` wakes the loop, and
  `wait_ms` limits the wait.
- **Limits.** `max_connections` refuses more connections. A client that
  does not send the HTTP/2 preface gets `GOAWAY`, and the connection
  closes.
- **Idle connections.** A connection without a WebSocket that sends
  nothing for `idle_timeout_ms` closes. A connection with a WebSocket
  stays: the liveness of a WebSocket is the work of its handler, with
  pings. While connections are open, `poll` waits at most
  `min(idle_timeout_ms, 1000)` milliseconds, so the sweep runs without an
  event.

This module ports no code. The loop follows the h2c loop of
`gql_http2.server`.

Differences from upstream: none; there is no upstream.
"""

from std.time import perf_counter_ns

from gql_http.error import HttpError
from gql_http.scan import move_down
from gql_http.server import Handler, Listener, open_listener
from gql_http.server import ServerConfig as HttpConfig
from gql_http.socket import (
    EAGAIN,
    EINTR,
    EPOLL_CTL_ADD,
    EPOLL_CTL_MOD,
    EPOLL_EVENT_SIZE,
    EPOLLIN,
    EPOLLOUT,
    Sys,
    event_fd,
    event_flags,
)
from gql_http2.connection import Config
from gql_ws.protocol import WsConfig
from gql_ws.server import Sockets, WsHandler

from gql_ws_http2.session import WsH2Session


struct ServerConfig(Copyable, Movable):
    """The configuration of an h2c server for WebSockets."""

    var http: HttpConfig
    """The address, the port, the request limits, `max_connections` and
    `max_events`, as for gql_http."""
    var h2: Config
    """The limits of each HTTP/2 connection."""
    var ws: WsConfig
    """The limits of each WebSocket."""
    var path: String
    """The path of the WebSocket endpoint; empty takes every path."""
    var protocols: List[String]
    """The subprotocols that the server supports, by preference."""

    def __init__(out self):
        """Make the defaults: every path, no subprotocol."""
        self.http = HttpConfig()
        self.h2 = Config()
        self.ws = WsConfig()
        self.path = String()
        self.protocols = List[String]()


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


struct _Conn(Movable):
    """The state of one connection of this loop."""

    var fd: Int
    var session: Int
    var interest: UInt32
    var last: Int
    """When the connection last read bytes, in milliseconds."""

    def __init__(out self):
        self.fd = -1
        self.session = -1
        self.interest = 0
        self.last = 0


struct Server[W: WsHandler, H: Handler](Movable):
    """One event loop that serves WebSockets and requests over h2c.

    Parameters:
        W: The type of the WebSocket handler.
        H: The type of the request handler.
    """

    var handler: Self.W
    """The handler of the WebSockets."""
    var http: Self.H
    """The handler of the other requests."""
    var sockets: Sockets
    """The WebSockets of every connection."""
    var config: ServerConfig
    """The configuration."""
    var sys: Sys
    """The system calls of the loop."""
    var port: Int
    """The local port."""
    var open_connections: Int
    """The open connections."""
    var _listen_fd: Int
    var _epoll_fd: Int
    var _conns: List[_Conn]
    var _sessions: List[WsH2Session]
    var _free: List[Int]
    var _events: List[UInt8]
    var _buffer: List[UInt8]
    var _last_sweep: Int

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
            handler: The handler of the WebSockets.
            http: The handler of the other requests.
            config: The configuration.
            listener: The socket; the server closes it.
            sys: The system calls; tests give one with faults.

        Raises:
            HttpError: `OS` when epoll cannot be opened, or cannot watch the
                socket or the source of the handler. The socket is closed.
        """
        self.handler = handler^
        self.http = http^
        self.sockets = Sockets(config.ws, 30000)
        self.config = config.copy()
        self.sys = sys^
        self.port = listener.port
        self.open_connections = 0
        self._listen_fd = listener.fd
        self._epoll_fd = -1
        self._conns = List[_Conn]()
        self._sessions = List[WsH2Session]()
        self._free = List[Int]()
        self._events = List[UInt8](
            length=max(config.http.max_events, 1) * EPOLL_EVENT_SIZE, fill=0
        )
        self._buffer = List[UInt8](length=65536, fill=0)
        self._last_sweep = _now_ms()
        var epoll = self.sys.epoll_create()
        if epoll < 0:
            self.close()
            raise HttpError.os("epoll_create1", -epoll)
        self._epoll_fd = epoll
        var rc = self.sys.epoll_ctl(epoll, EPOLL_CTL_ADD, listener.fd, EPOLLIN)
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
        """End each WebSocket, and close every connection, the listening
        socket and epoll at once."""
        var fd = 0
        while fd < len(self._conns):
            if self._conns[fd].fd >= 0:
                self._close(fd)
            fd += 1
        if self._listen_fd >= 0:
            self.sys.close(self._listen_fd)
            self._listen_fd = -1
        if self._epoll_fd >= 0:
            self.sys.close(self._epoll_fd)
            self._epoll_fd = -1

    def poll(mut self, timeout_ms: Int) raises -> Int:
        """Run one turn of the loop: wait for events, handle them, call
        `on_tick`, and send what the handler sent.

        Args:
            timeout_ms: The longest wait in milliseconds; -1 waits until an
                event. `wait_ms` of the handler can make it shorter.

        Returns:
            The count of events.

        Raises:
            HttpError: `OS` when `epoll_wait` fails; the errors of
                `on_tick`.
        """
        var wait = timeout_ms
        var limit = self.handler.wait_ms()
        if limit >= 0 and (wait < 0 or limit < wait):
            wait = limit
        if self.open_connections > 0:
            # An idle connection times out without an event.
            var every = self._sweep_every()
            wait = every if wait < 0 else min(wait, every)
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
        var events = self._events.unsafe_ptr()
        var extra = self.handler.fd()
        var index = 0
        while index < count:
            var fd = event_fd(events, index)
            var flags = event_flags(events, index)
            index += 1
            if fd == self._listen_fd:
                self._accept()
            elif fd == extra:
                # The handler reads its own source in `on_tick`.
                continue
            elif flags & EPOLLOUT != 0:
                self._send(fd)
            else:
                self._readable(fd)
        self._sweep()
        self.handler.on_tick(self.sockets)
        if len(self.sockets.dirty) > 0:
            self.sockets.dirty.clear()
            var fd = 0
            while fd < len(self._conns):
                if self._conns[fd].fd >= 0:
                    var session = self._conns[fd].session
                    self._sessions[session].flush(self.handler, self.sockets)
                    self._send(fd)
                fd += 1
        return count

    def _sweep_every(self) -> Int:
        """Return the time between two sweeps, in milliseconds."""
        return max(min(self.config.http.idle_timeout_ms, 1000), 1)

    def _sweep(mut self):
        """Close each idle connection without a WebSocket; at most once
        per `_sweep_every`."""
        var now = _now_ms()
        if now - self._last_sweep < self._sweep_every():
            return
        self._last_sweep = now
        var fd = 0
        while fd < len(self._conns):
            if self._idle(fd, now):
                self._close(fd)
            fd += 1

    def _idle(self, fd: Int, now: Int) -> Bool:
        """Return True for an open connection without a WebSocket that has
        read nothing for `idle_timeout_ms`."""
        ref conn = self._conns[fd]
        if conn.fd < 0 or len(self._sessions[conn.session].tunnels) > 0:
            return False
        return now - conn.last >= self.config.http.idle_timeout_ms

    def _accept(mut self):
        """Accept every pending connection, and start its session."""
        while True:
            var fd = self.sys.accept(self._listen_fd)
            if fd < 0:
                return
            if self.open_connections >= self.config.http.max_connections:
                self.sys.close(fd)
                continue
            _ = self.sys.set_no_delay(fd)
            while len(self._conns) <= fd:
                self._conns.append(_Conn())
            if (
                self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_ADD, fd, EPOLLIN)
                < 0
            ):
                self.sys.close(fd)
                continue
            var session = WsH2Session(
                self.config.h2,
                self.config.http.limits,
                self.config.protocols,
                self.config.path,
            )
            session.start()
            var slot: Int
            if len(self._free) > 0:
                slot = self._free.pop()
                self._sessions[slot] = session^
            else:
                slot = len(self._sessions)
                self._sessions.append(session^)
            self._conns[fd].fd = fd
            self._conns[fd].session = slot
            self._conns[fd].interest = EPOLLIN
            self._conns[fd].last = _now_ms()
            self.open_connections += 1
            self._send(fd)

    def _close(mut self, fd: Int):
        """End the WebSockets of a connection, close it, and make its slot
        free."""
        var session = self._conns[fd].session
        self._sessions[session].close_all(self.handler, self.sockets)
        self.sys.close(fd)
        self._free.append(session)
        self._conns[fd].fd = -1
        self._conns[fd].session = -1
        self.open_connections -= 1

    def _watch(mut self, fd: Int, events: UInt32):
        """Set the events of a connection; close it when epoll fails."""
        if self._conns[fd].interest == events:
            return
        if self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_MOD, fd, events) < 0:
            self._close(fd)
            return
        self._conns[fd].interest = events

    def _readable(mut self, fd: Int):
        """Read from a connection, and serve what arrived."""
        var n = self.sys.recv(fd, self._buffer.unsafe_ptr(), len(self._buffer))
        if n == -EAGAIN or n == -EINTR:
            return
        if n <= 0:
            self._close(fd)
            return
        self._conns[fd].last = _now_ms()
        var session = self._conns[fd].session
        self._sessions[session].receive(
            self.http, self.handler, self.sockets, Span(self._buffer)[:n]
        )
        self._send(fd)

    def _send(mut self, fd: Int):
        """Send the output of a session, and keep what the socket refuses.
        A connection with output waits for `EPOLLOUT` before it reads."""
        var session = self._conns[fd].session
        var total = len(self._sessions[session].session.conn.out)
        if total > 0:
            var sent = self.sys.send(
                fd,
                self._sessions[session].session.conn.out.unsafe_ptr(),
                total,
            )
            if sent == -EAGAIN or sent == -EINTR:
                sent = 0
            if sent < 0:
                self._close(fd)
                return
            var rest = total - sent
            move_down(
                self._sessions[session].session.conn.out.unsafe_ptr(),
                0,
                sent,
                rest,
            )
            self._sessions[session].session.conn.out.resize(rest, 0)
            if rest > 0:
                self._watch(fd, EPOLLOUT)
                return
        if self._sessions[session].is_done():
            self._close(fd)
            return
        self._watch(fd, EPOLLIN)


def listen[
    W: WsHandler, H: Handler
](
    var handler: W, var http: H, config: ServerConfig, var sys: Sys = Sys()
) raises HttpError -> Server[W, H]:
    """Make a server that listens on the address and the port of a
    configuration, in this process.

    Args:
        handler: The handler of the WebSockets.
        http: The handler of the other requests.
        config: The configuration.
        sys: The system calls; tests give one with faults.

    Returns:
        The server. Its `port` is the port it listens on.

    Raises:
        HttpError: `OS` when the socket or epoll cannot be opened.

    Parameters:
        W: The type of the WebSocket handler.
        H: The type of the request handler.
    """
    var listener = open_listener(
        sys,
        config.http.host,
        config.http.port,
        config.http.backlog,
        config.http.reuse_port,
    )
    return Server(handler^, http^, config, listener, sys^)
