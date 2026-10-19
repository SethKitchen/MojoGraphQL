# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTPS server: one epoll event loop, TLS through OpenSSL, and ALPN.

`TlsServer` serves a `gql_http.server.Handler` over TLS. It parses each
request with the `RequestReader` of `gql_http` and writes each response
with its `ResponseWriter`, so a handler serves HTTP and HTTPS the same way.

After the handshake, the protocol that ALPN chose decides what runs on the
connection:

- `http/1.1`, or no ALPN: HTTP/1.1, served here.
- The protocol of the `TlsProtocol` parameter, such as `h2`: the server
  gives the decrypted bytes to that protocol and sends what it answers.
  `gql_tls` does not import HTTP/2; the package that joins TLS and HTTP/2
  implements `TlsProtocol`.

The loop is level-triggered. OpenSSL reads ahead: one `recv` takes every
byte that the socket has. A readable connection is read until OpenSSL holds
no more bytes, because epoll does not see the bytes that OpenSSL holds; the
bytes that the socket still has make the next turn see it again. The
response of a request goes out with one `SSL_write`.
A response that does not fit in the socket waits for `EPOLLOUT`.

The writer has no plain socket here, so `ResponseWriter.flush` keeps the
bytes. Streamed content goes out after the handler returns.

Graceful shutdown works as in `gql_http.server`. A closing connection
sends `close_notify` before the socket closes.

This module ports no code. The behavior follows RFC 9112, RFC 8446 and
RFC 7301.

Differences from upstream: none; there is no upstream.
"""

from std.time import perf_counter_ns

from gql_http.parser import Limits, ParseState, RequestReader
from gql_http.server import Handler, Listener, ResponseWriter, ServerConfig
from gql_http.server import open_listener
from gql_http.socket import (
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
from gql_tls.context import TlsContext
from gql_tls.error import TlsError
from gql_tls.stream import IoWant, TlsStream

comptime _CONTINUE = "HTTP/1.1 100 Continue\r\n\r\n"


trait TlsProtocol(Deinitable, Movable):
    """A protocol other than HTTP/1.1 that a `TlsServer` runs after ALPN.

    The server calls it with the decrypted bytes of each connection that
    chose the protocol, and encrypts what it appends to `out`.
    """

    def protocol(self) -> String:
        """Return the ALPN name of the protocol, such as `h2`.

        Returns:
            The name; an empty name turns the protocol off.
        """
        ...

    def open(mut self, conn: Int, mut out: List[UInt8]) raises:
        """Start the protocol on a connection, after the handshake.

        Args:
            conn: The id of the connection: its socket.
            out: The bytes to send, such as a server preface.

        Raises:
            Error: Any error; the server closes the connection.
        """
        ...

    def receive(
        mut self, conn: Int, data: List[UInt8], mut out: List[UInt8]
    ) raises -> Bool:
        """Take decrypted bytes of a connection.

        Args:
            conn: The id of the connection.
            data: The bytes that arrived; the protocol takes them all.
            out: The bytes to send.

        Returns:
            False to close the connection after `out` goes out.

        Raises:
            Error: Any error; the server closes the connection.
        """
        ...

    def close(mut self, conn: Int):
        """Forget a connection that has closed.

        Args:
            conn: The id of the connection.
        """
        ...


struct NoProtocol(TlsProtocol):
    """The `TlsProtocol` of a server that speaks only HTTP/1.1."""

    def __init__(out self):
        """Make the empty protocol."""
        pass

    def protocol(self) -> String:
        """Return an empty name: no protocol.

        Returns:
            An empty string.
        """
        return String()

    def open(mut self, conn: Int, mut out: List[UInt8]):
        """Do nothing; the server never calls it.

        Args:
            conn: The id of the connection.
            out: The bytes to send.
        """
        pass

    def receive(
        mut self, conn: Int, data: List[UInt8], mut out: List[UInt8]
    ) -> Bool:
        """Refuse the bytes; the server never calls it.

        Args:
            conn: The id of the connection.
            data: The bytes.
            out: The bytes to send.

        Returns:
            False.
        """
        return False

    def close(mut self, conn: Int):
        """Do nothing.

        Args:
            conn: The id of the connection.
        """
        pass


@fieldwise_init
struct ConnectionMode(Equatable, ImplicitlyCopyable, Writable):
    """What runs on a TLS connection, as a type and not a bare integer."""

    var value: UInt8
    """The mode's index; see `is_valid`."""

    comptime HANDSHAKE = ConnectionMode(0)
    """The handshake has not ended."""
    comptime HTTP1 = ConnectionMode(1)
    """HTTP/1.1."""
    comptime OTHER = ConnectionMode(2)
    """The `TlsProtocol` of the server."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the modes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the mode.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 3] = ["handshake", "http1", "other"]
        writer.write(materialize[names]()[Int(min(self.value, 2))])


struct _TlsConnection(Movable):
    """The state of one accepted TLS connection."""

    var fd: Int
    var stream: TlsStream
    var reader: RequestReader
    var mode: ConnectionMode
    var pending: List[UInt8]
    var sent: Int
    var closing: Bool
    var read_wants_write: Bool
    var deadline_ms: Int
    var interest: UInt32

    def __init__(out self, limits: Limits, context: TlsContext):
        self.fd = -1
        self.stream = TlsStream(context.openssl)
        self.reader = RequestReader(limits)
        self.mode = ConnectionMode.HANDSHAKE
        self.pending = List[UInt8]()
        self.sent = 0
        self.closing = False
        self.read_wants_write = False
        self.deadline_ms = 0
        self.interest = 0


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


struct TlsServer[H: Handler, P: TlsProtocol = NoProtocol](Movable):
    """One event loop that serves a handler over TLS on a listening socket.

    Parameters:
        H: The type of the handler.
        P: The protocol that runs when ALPN chooses its name.
    """

    var handler: Self.H
    """The handler of every HTTP/1.1 request."""
    var other: Self.P
    """The protocol of the connections that chose its ALPN name."""
    var context: TlsContext
    """The server context: certificate, key and ALPN."""
    var config: ServerConfig
    """The configuration."""
    var sys: Sys
    """The system calls of the loop."""
    var writer: ResponseWriter
    """The response writer; one for every request in turn."""
    var port: Int
    """The local port."""
    var open_connections: Int
    """The count of open connections."""
    var draining: Bool
    """Whether a graceful shutdown has begun."""
    var _listen_fd: Int
    var _epoll_fd: Int
    var _conns: List[_TlsConnection]
    var _events: List[UInt8]
    var _input: List[UInt8]
    var _output: List[UInt8]
    var _now: Int
    var _second: Int
    var _last_sweep: Int
    var _drain_deadline: Int
    var _name: String

    def __init__(
        out self,
        var handler: Self.H,
        var other: Self.P,
        var context: TlsContext,
        config: ServerConfig,
        listener: Listener,
        var sys: Sys,
    ) raises TlsError:
        """Serve on a listening socket that is open already.

        Args:
            handler: The handler of every HTTP/1.1 request.
            other: The protocol for its ALPN name.
            context: A server context.
            config: The configuration.
            listener: The socket; the server closes it.
            sys: The system calls; tests give one with faults.

        Raises:
            TlsError: `OS` when epoll cannot be opened, or cannot watch the
                socket. The socket is closed.
        """
        self.handler = handler^
        self._name = other.protocol()
        self.other = other^
        self.context = context^
        self.config = config.copy()
        self.sys = sys^
        self.writer = ResponseWriter()
        self.port = listener.port
        self.open_connections = 0
        self.draining = False
        self._listen_fd = listener.fd
        self._epoll_fd = -1
        self._conns = List[_TlsConnection]()
        self._events = List[UInt8](
            length=max(config.max_events, 1) * EPOLL_EVENT_SIZE, fill=0
        )
        self._input = List[UInt8]()
        self._output = List[UInt8]()
        self._now = _now_ms()
        self._second = -1
        self._last_sweep = self._now
        self._drain_deadline = 0
        self._tick()
        var epoll = self.sys.epoll_create()
        if epoll < 0:
            self.close()
            raise TlsError.os("epoll_create1", -epoll)
        self._epoll_fd = epoll
        var rc = self.sys.epoll_ctl(epoll, EPOLL_CTL_ADD, listener.fd, EPOLLIN)
        if rc < 0:
            self.close()
            raise TlsError.os("epoll_ctl", -rc)

    def __deinit__(deinit self):
        """Close every descriptor that is still open."""
        self.close()

    def close(mut self):
        """Close the listening socket, every connection and epoll at once."""
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

    def stopped(self) -> Bool:
        """Return True when a graceful shutdown has ended.

        Returns:
            Whether the server drains and has no open connection.
        """
        return self.draining and self.open_connections == 0

    def run(mut self) raises TlsError:
        """Run the loop until a graceful shutdown ends.

        Raises:
            TlsError: `OS` when `epoll_wait` fails.
        """
        while not self.stopped():
            _ = self.poll(-1)

    def begin_shutdown(mut self):
        """Stop accepting, close idle connections, and let busy ones finish."""
        if self.draining:
            return
        self.draining = True
        self._drain_deadline = self._now + self.config.shutdown_timeout_ms
        if self._listen_fd >= 0:
            _ = self.sys.epoll_ctl(
                self._epoll_fd, EPOLL_CTL_DEL, self._listen_fd, 0
            )
            self.sys.close(self._listen_fd)
            self._listen_fd = -1
        var fd = 0
        while fd < len(self._conns):
            if self._conns[fd].fd >= 0 and self._idle(fd):
                self._end(fd)
            fd += 1

    def _idle(self, fd: Int) -> Bool:
        """Return True for an HTTP/1.1 connection between requests."""
        ref conn = self._conns[fd]
        return (
            conn.mode != ConnectionMode.OTHER
            and conn.reader.buffered() == 0
            and len(conn.pending) == 0
        )

    def _tick(mut self):
        """Read the clocks, and update the `Date` field once a second."""
        self._now = _now_ms()
        var second = self.sys.wall_seconds()
        if second != self._second:
            self._second = second
            self.writer.set_date(second)

    def poll(mut self, timeout_ms: Int) raises TlsError -> Int:
        """Run one turn of the loop: wait for events and handle them.

        Args:
            timeout_ms: The longest wait in milliseconds; -1 waits until an
                event. With open connections the wait is at most a second,
                so that idle connections time out.

        Returns:
            The count of events.

        Raises:
            TlsError: `OS` when `epoll_wait` fails.
        """
        var wait = timeout_ms
        if self.open_connections > 0 or self.draining:
            wait = 1000 if wait < 0 else min(wait, 1000)
        var count = self.sys.epoll_wait(
            self._epoll_fd,
            self._events.unsafe_ptr(),
            len(self._events) // EPOLL_EVENT_SIZE,
            wait,
        )
        if count == -EINTR:
            count = 0
        if count < 0:
            raise TlsError.os("epoll_wait", -count)
        self._tick()
        var events = self._events.unsafe_ptr()
        var index = 0
        while index < count:
            var fd = event_fd(events, index)
            var flags = event_flags(events, index)
            index += 1
            if fd == self._listen_fd:
                self._accept()
            elif flags & EPOLLOUT != 0:
                self._writable(fd)
            else:
                self._readable(fd)
        if self._now - self._last_sweep >= 1000 or self.draining:
            self._sweep()
        return count

    def _sweep(mut self):
        """Close the connections whose deadline has passed."""
        self._last_sweep = self._now
        var force = self.draining and self._now >= self._drain_deadline
        var fd = 0
        while fd < len(self._conns):
            if self._conns[fd].fd >= 0:
                if force or self._now >= self._conns[fd].deadline_ms:
                    self._close(fd)
            fd += 1

    def _accept(mut self):
        """Accept every pending connection, and start its handshake."""
        while True:
            var fd = self.sys.accept(self._listen_fd)
            if fd < 0:
                return
            if self.open_connections >= self.config.max_connections:
                self.sys.close(fd)
                continue
            _ = self.sys.set_no_delay(fd)
            while len(self._conns) <= fd:
                self._conns.append(
                    _TlsConnection(self.config.limits, self.context)
                )
            try:
                self._conns[fd].stream = TlsStream.accept(self.context, fd)
            except:
                self.sys.close(fd)
                continue
            if (
                self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_ADD, fd, EPOLLIN)
                < 0
            ):
                self._conns[fd].stream = TlsStream(self.context.openssl)
                self.sys.close(fd)
                continue
            ref conn = self._conns[fd]
            conn.fd = fd
            conn.mode = ConnectionMode.HANDSHAKE
            conn.interest = EPOLLIN
            conn.deadline_ms = self._now + self.config.idle_timeout_ms
            self.open_connections += 1

    def _close(mut self, fd: Int):
        """Free the TLS state of a connection, close it, and free its slot."""
        if self._conns[fd].mode == ConnectionMode.OTHER:
            self.other.close(fd)
        self._conns[fd].stream = TlsStream(self.context.openssl)
        # A copy of the descriptor, such as one that a child process
        # inherited, would keep the registration alive after `close`
        # (epoll(7)), and its events would come for a closed slot.
        _ = self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_DEL, fd, 0)
        self.sys.close(fd)
        ref conn = self._conns[fd]
        conn.fd = -1
        conn.reader.reset()
        conn.mode = ConnectionMode.HANDSHAKE
        conn.pending.clear()
        conn.sent = 0
        conn.closing = False
        conn.read_wants_write = False
        self.open_connections -= 1

    def _watch(mut self, fd: Int, events: UInt32) -> Bool:
        """Set the events of a connection; False after closing it."""
        if self._conns[fd].interest == events:
            return True
        if self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_MOD, fd, events) < 0:
            self._close(fd)
            return False
        self._conns[fd].interest = events
        return True

    def _wait(mut self, fd: Int, want: IoWant) -> Bool:
        """Watch the event that a TLS operation wants; False after closing."""
        return self._watch(fd, EPOLLOUT if want == IoWant.WRITE else EPOLLIN)

    def _readable(mut self, fd: Int):
        """Go on with the handshake, or read and answer."""
        if self._conns[fd].mode == ConnectionMode.HANDSHAKE:
            self._handshake(fd)
        else:
            self._read_more(fd)

    def _handshake(mut self, fd: Int):
        """Go on with the handshake, and choose the protocol at its end."""
        var want: IoWant
        try:
            want = self._conns[fd].stream.handshake()
        except:
            self._close(fd)
            return
        if want != IoWant.NOTHING:
            _ = self._wait(fd, want)
            return
        var other = (
            self._name.byte_length() > 0
            and self._conns[fd].stream.protocol == self._name
        )
        if other:
            self._conns[fd].mode = ConnectionMode.OTHER
            try:
                self.other.open(fd, self._output)
            except:
                self._output.clear()
                self._close(fd)
                return
            self._flush(fd)
            if self._conns[fd].fd < 0 or len(self._conns[fd].pending) > 0:
                return
        else:
            self._conns[fd].mode = ConnectionMode.HTTP1
        if self._wait(fd, IoWant.READ):
            # The first request can arrive with the end of the handshake.
            self._read_more(fd)

    def _read_more(mut self, fd: Int):
        """Read every decrypted byte that OpenSSL has, and answer."""
        var http1 = self._conns[fd].mode == ConnectionMode.HTTP1
        var got = False
        while True:
            var n: Int
            try:
                if http1:
                    self._conns[fd].reader.reserve(4096)
                    n = self._conns[fd].stream.read(
                        self._conns[fd].reader.write_pointer(),
                        self._conns[fd].reader.space(),
                    )
                else:
                    self._input.resize(16384, 0)
                    n = self._conns[fd].stream.read(
                        self._input.unsafe_ptr(), 16384
                    )
            except:
                self._close(fd)
                return
            if n == 0:
                self._close(fd)
                return
            if n < 0:
                if IoWant.from_code(n) == IoWant.WRITE:
                    self._conns[fd].read_wants_write = True
                    if not self._wait(fd, IoWant.WRITE):
                        return
                break
            self._conns[fd].deadline_ms = (
                self._now + self.config.idle_timeout_ms
            )
            if http1:
                self._conns[fd].reader.commit(n)
                got = True
                if self._conns[fd].stream.has_pending():
                    continue
                # The socket is level-triggered: what it still has comes
                # back in the next turn, without a read that finds nothing.
                break
            self._input.resize(n, 0)
            var keep: Bool
            try:
                keep = self.other.receive(fd, self._input, self._output)
            except:
                self._output.clear()
                self._close(fd)
                return
            if not keep:
                self._conns[fd].closing = True
            self._flush(fd)
            if self._conns[fd].fd < 0 or len(self._conns[fd].pending) > 0:
                return
            if not self._conns[fd].stream.has_pending():
                break
        if got:
            self._process(fd)

    def _process(mut self, fd: Int):
        """Answer the complete requests in the buffer of a connection."""
        while True:
            var result = self._conns[fd].reader.next()
            if result.state == ParseState.INCOMPLETE:
                if self._conns[fd].reader.needs_continue:
                    self.writer.out.extend(StaticString(_CONTINUE).as_bytes())
                    self._conns[fd].reader.continue_sent = True
                break
            if result.state == ParseState.ERROR:
                self.writer.error(result.status)
                self._conns[fd].closing = True
                break
            var keep = self._conns[fd].reader.request.keep_alive
            self.writer.begin(
                self._conns[fd].reader.request, -1, keep and not self.draining
            )
            try:
                self.handler.handle(self._conns[fd].reader.request, self.writer)
            except:
                self.writer.fail()
            self.writer.finish()
            self._conns[fd].reader.consume()
            if not self.writer.keep_alive:
                self._conns[fd].closing = True
                break
        var out = self.writer.out^
        self.writer.out = self._output^
        self._output = out^
        self._flush(fd)

    def _flush(mut self, fd: Int):
        """Encrypt and send `_output`, and keep what the socket refuses."""
        var total = len(self._output)
        var sent = 0
        while sent < total:
            var n: Int
            try:
                n = self._conns[fd].stream.write(
                    self._output.unsafe_ptr().unsafe_offset(sent), total - sent
                )
            except:
                self._output.clear()
                self._close(fd)
                return
            if n < 0:
                self._conns[fd].pending.extend(Span(self._output)[sent:])
                self._output.clear()
                _ = self._wait(fd, IoWant.WRITE)
                return
            sent += n
        self._output.clear()
        if self._conns[fd].closing:
            self._end(fd)

    def _writable(mut self, fd: Int):
        """Go on with the handshake, a read that needs a write, or a send."""
        if self._conns[fd].mode == ConnectionMode.HANDSHAKE:
            self._handshake(fd)
            return
        if len(self._conns[fd].pending) > 0:
            ref conn = self._conns[fd]
            while conn.sent < len(conn.pending):
                var n: Int
                try:
                    n = conn.stream.write(
                        conn.pending.unsafe_ptr().unsafe_offset(conn.sent),
                        len(conn.pending) - conn.sent,
                    )
                except:
                    self._close(fd)
                    return
                if n < 0:
                    return
                conn.sent += n
                # The client reads: the connection is not quiet.
                conn.deadline_ms = self._now + self.config.idle_timeout_ms
            conn.pending.clear()
            conn.sent = 0
            if conn.closing:
                self._end(fd)
                return
        self._conns[fd].read_wants_write = False
        if not self._wait(fd, IoWant.READ):
            return
        # `_process` answered every complete request before the send
        # waited, so only new bytes can hold a request.
        self._read_more(fd)

    def _end(mut self, fd: Int):
        """Send `close_notify`, then close the connection."""
        _ = self._conns[fd].stream.shutdown()
        self._close(fd)


def listen_tls[
    H: Handler, P: TlsProtocol
](
    var handler: H,
    var context: TlsContext,
    config: ServerConfig,
    var other: P,
    var sys: Sys = Sys(),
) raises TlsError -> TlsServer[H, P]:
    """Open a listening socket and an HTTPS event loop in this process.

    Args:
        handler: The handler of every HTTP/1.1 request.
        context: A server context.
        config: The configuration.
        other: The protocol for its ALPN name, such as an HTTP/2 server.
        sys: The system calls; tests give one with faults.

    Returns:
        The server. Its `port` is the port it listens on.

    Raises:
        TlsError: `OS` when the socket or epoll cannot be opened.

    Parameters:
        H: The type of the handler.
        P: The type of the other protocol.
    """
    var listener: Listener
    try:
        listener = open_listener(
            sys, config.host, config.port, config.backlog, config.reuse_port
        )
    except e:
        raise TlsError.from_http(e)
    return TlsServer[H, P](handler^, other^, context^, config, listener, sys^)


def listen_https[
    H: Handler
](
    var handler: H,
    var context: TlsContext,
    config: ServerConfig,
    var sys: Sys = Sys(),
) raises TlsError -> TlsServer[H, NoProtocol]:
    """Open an HTTPS event loop that speaks only HTTP/1.1.

    Give it a context whose ALPN protocols are `http/1.1` alone, or none.
    A client that chooses another protocol gets its connection closed.

    Args:
        handler: The handler of every request.
        context: A server context.
        config: The configuration.
        sys: The system calls; tests give one with faults.

    Returns:
        The server. Its `port` is the port it listens on.

    Raises:
        TlsError: `OS` when the socket or epoll cannot be opened.

    Parameters:
        H: The type of the handler.
    """
    return listen_tls(handler^, context^, config, NoProtocol(), sys^)
