# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTP/1.1 server: an epoll event loop per process, and worker
processes that share a port with `SO_REUSEPORT`.

A `Handler` gets each `Request` and fills a `ResponseWriter`. A `Server`
runs one event loop in the calling process: `poll` runs one turn, `run`
runs until a graceful shutdown ends. `start_workers` forks worker
processes. Each worker has its own listening socket on the same port, so
the kernel spreads the connections over them, and there are no threads.

The loop is level-triggered. Each readable connection costs one `recv`;
each response costs one `send`. Pipelined requests in one read get their
responses in one `send`. A response that does not fit in the socket waits
for `EPOLLOUT`, and the connection is not read until it has gone out.

Graceful shutdown: the server closes its listening socket and its idle
connections. A busy connection gets its response with `Connection: close`.
The loop ends when no connection is open, or after
`ServerConfig.shutdown_timeout_ms`. A worker begins it on `SIGTERM` or
`SIGINT`, which it reads from a `signalfd`, and gets `SIGTERM` when its
parent process ends.

This module ports no code. The behavior follows RFC 9110 and RFC 9112.

Differences from upstream: none; there is no upstream.
"""

from std.time import perf_counter_ns

from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.parser import Limits, ParseState, Request, RequestReader
from gql_http.scan import equals_ignore_case, move_down
from gql_http.socket import (
    EAGAIN,
    EINTR,
    EPOLL_CTL_ADD,
    EPOLL_CTL_DEL,
    EPOLL_CTL_MOD,
    EPOLL_EVENT_SIZE,
    EPOLLIN,
    EPOLLOUT,
    IPv4Address,
    SIGKILL,
    SIGTERM,
    Sys,
    event_fd,
    event_flags,
)
from gql_http.status import Method, Status, Version


trait Handler(Deinitable, Movable):
    """What a server calls for each request."""

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one request.

        The request and its content are valid until the method returns.
        When it raises before the response has begun to go out, the client
        gets an empty 500 response.

        Args:
            request: The request.
            response: The response to fill; it starts as an empty 200.

        Raises:
            Error: Any error; the server answers 500.
        """
        ...


comptime _CONTINUE = "HTTP/1.1 100 Continue\r\n\r\n"
comptime _LINGER_MS = 2000


def format_http_date(seconds: Int) -> String:
    """Format a time as an IMF-fixdate, the `Date` format of RFC 9110.

    Args:
        seconds: Seconds since 1970-01-01 00:00:00 UTC; not negative.

    Returns:
        Such as `Sun, 06 Nov 1994 08:49:37 GMT`.
    """
    comptime days_of_week: Array[StaticString, 7] = [
        "Thu",
        "Fri",
        "Sat",
        "Sun",
        "Mon",
        "Tue",
        "Wed",
    ]
    comptime months: Array[StaticString, 12] = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
    ]
    var days = seconds // 86400
    var rest = seconds % 86400
    # Howard Hinnant's civil_from_days, for days on or after 1970-01-01.
    var z = days + 719468
    var era = z // 146097
    var doe = z - era * 146097
    var yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    var doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    var mp = (5 * doy + 2) // 153
    var day = doy - (153 * mp + 2) // 5 + 1
    var month = mp + 3 if mp < 10 else mp - 9
    var year = yoe + era * 400 + (1 if month <= 2 else 0)
    var out = String(materialize[days_of_week]()[days % 7])
    out += ", "
    out += _two(day) + " " + String(materialize[months]()[month - 1])
    out += " " + String(year) + " " + _two(rest // 3600) + ":"
    out += _two(rest % 3600 // 60) + ":" + _two(rest % 60) + " GMT"
    return out^


def _two(value: Int) -> String:
    """Format 0 to 99 with two digits."""
    return ("0" if value < 10 else "") + String(value)


def _append_int(mut out: List[UInt8], value: Int):
    """Append the decimal digits of a value that is not negative."""
    var digits = SIMD[DType.uint8, 32](0)
    var count = 0
    var rest = value
    while True:
        digits[count] = UInt8(48 + rest % 10)
        count += 1
        rest //= 10
        if rest == 0:
            break
    while count > 0:
        count -= 1
        out.append(digits[count])


def _append_hex(mut out: List[UInt8], value: Int):
    """Append the lowercase hexadecimal digits of a positive value."""
    var digits = SIMD[DType.uint8, 32](0)
    var count = 0
    var rest = value
    while rest > 0:
        var digit = rest % 16
        digits[count] = UInt8(48 + digit if digit < 10 else 87 + digit)
        count += 1
        rest //= 16
    while count > 0:
        count -= 1
        out.append(digits[count])


@fieldwise_init
struct _WriterState(Equatable, ImplicitlyCopyable):
    """How far a response has gone."""

    var value: UInt8

    comptime OPEN = _WriterState(0)
    comptime CHUNKED = _WriterState(1)
    comptime UNTIL_CLOSE = _WriterState(2)
    comptime DONE = _WriterState(3)

    def is_valid(self) -> Bool:
        return self.value <= 3


struct ResponseWriter(Movable):
    """The response to one request: status, header fields and content.

    A handler sets the status, adds fields and writes content. When the
    handler returns, the server adds `Date`, `Content-Length` and, when the
    connection closes, `Connection: close`. To stream, call `begin_chunked`,
    then `write_chunk` and `flush` as often as needed. An HTTP/1.0 client
    gets the stream without chunks, and the connection closes at its end.
    """

    var status: Status
    """The status code; 200 at first."""
    var headers: Headers
    """The fields that the handler adds."""
    var body: List[UInt8]
    """The content that is not sent yet."""
    var out: List[UInt8]
    """The bytes for the socket that are not sent yet."""
    var keep_alive: Bool
    """Whether the connection stays open after this response."""
    var sys: Sys
    """The system calls of `flush`."""
    var _state: _WriterState
    var _fd: Int
    var _head_only: Bool
    var _http11: Bool
    var _date: List[UInt8]

    def __init__(out self):
        """Make a writer that is not bound to a connection."""
        self.status = Status.OK
        self.headers = Headers()
        self.body = List[UInt8]()
        self.out = List[UInt8]()
        self.keep_alive = True
        self.sys = Sys()
        self._state = _WriterState.OPEN
        self._fd = -1
        self._head_only = False
        self._http11 = True
        self._date = List[UInt8]()
        self.set_date(0)

    def set_date(mut self, seconds: Int):
        """Set the time of the `Date` field.

        Args:
            seconds: Seconds since 1970-01-01 00:00:00 UTC.
        """
        self._date.clear()
        self._date.extend(StaticString("Date: ").as_bytes())
        self._date.extend(format_http_date(seconds).as_bytes())
        self._date.extend(StaticString("\r\n").as_bytes())

    def begin(mut self, request: Request, fd: Int, keep_alive: Bool):
        """Start the response to a request. The server calls it.

        Args:
            request: The request.
            fd: The socket of the connection, for `flush`.
            keep_alive: Whether the connection can stay open.
        """
        self.status = Status.OK
        self.headers.clear()
        self.body.clear()
        self.keep_alive = keep_alive
        self._state = _WriterState.OPEN
        self._fd = fd
        self._head_only = request.method == Method.HEAD
        self._http11 = request.version == Version.HTTP_1_1

    def set_status(mut self, status: Status):
        """Set the status code.

        Args:
            status: The status code.
        """
        self.status = status

    def add_header(
        mut self, name: StringSlice, value: StringSlice
    ) raises HttpError:
        """Add a header field.

        The server writes the framing fields itself, so the names
        `Content-Length`, `Transfer-Encoding`, `Connection` and `Date` are
        refused. Use `close_connection` to close.

        Args:
            name: The field name, a token.
            value: The field value, without CR, LF or NUL.

        Raises:
            HttpError: `USAGE` for a framing field, an invalid name or an
                invalid value, or after `begin_chunked`.
        """
        if self._state != _WriterState.OPEN:
            raise HttpError(
                ErrorKind.USAGE, "the response head has gone out", 0
            )
        var bytes = name.as_bytes()
        if (
            equals_ignore_case(bytes, StaticString("content-length").as_bytes())
            or equals_ignore_case(
                bytes, StaticString("transfer-encoding").as_bytes()
            )
            or equals_ignore_case(bytes, StaticString("connection").as_bytes())
            or equals_ignore_case(bytes, StaticString("date").as_bytes())
        ):
            raise HttpError(
                ErrorKind.USAGE,
                "the server writes the " + String(name) + " field",
                0,
            )
        self.headers.add(name, value)

    def write(mut self, data: Span[UInt8, _]) raises HttpError:
        """Add bytes to the content.

        Args:
            data: The bytes.

        Raises:
            HttpError: `USAGE` after `begin_chunked`; use `write_chunk`.
        """
        if self._state != _WriterState.OPEN:
            raise HttpError(ErrorKind.USAGE, "use write_chunk to stream", 0)
        self.body.extend(data)

    def write_text(mut self, text: StringSlice) raises HttpError:
        """Add text to the content.

        Args:
            text: The text, in UTF-8.

        Raises:
            HttpError: `USAGE` after `begin_chunked`; use `write_chunk`.
        """
        self.write(text.as_bytes())

    def send(
        mut self, status: Status, content_type: StringSlice, body: StringSlice
    ) raises HttpError:
        """Set the status, the `Content-Type` and the whole content.

        Args:
            status: The status code.
            content_type: The `Content-Type` value.
            body: The content.

        Raises:
            HttpError: `USAGE` for an invalid content type, or after
                `begin_chunked`.
        """
        self.status = status
        self.add_header("Content-Type", content_type)
        self.write(body.as_bytes())

    def close_connection(mut self):
        """Close the connection after this response."""
        self.keep_alive = False

    def committed(self) -> Bool:
        """Return True once the head of the response has gone to `out`.

        Returns:
            Whether `begin_chunked` was called.
        """
        return self._state != _WriterState.OPEN

    def _head(mut self, content_length: Int, chunked: Bool):
        """Append the status line and the header fields to `out`."""
        self.out.extend(StaticString("HTTP/1.1 ").as_bytes())
        _append_int(self.out, self.status.code)
        self.out.append(32)
        self.out.extend(self.status.reason().as_bytes())
        self.out.extend(StaticString("\r\n").as_bytes())
        self.out.extend(Span(self._date))
        self.out.extend(Span(self.headers.data))
        if content_length >= 0:
            self.out.extend(StaticString("Content-Length: ").as_bytes())
            _append_int(self.out, content_length)
            self.out.extend(StaticString("\r\n").as_bytes())
        if chunked:
            self.out.extend(
                StaticString("Transfer-Encoding: chunked\r\n").as_bytes()
            )
        if not self.keep_alive:
            self.out.extend(StaticString("Connection: close\r\n").as_bytes())
        elif not self._http11:
            self.out.extend(
                StaticString("Connection: keep-alive\r\n").as_bytes()
            )
        self.out.extend(StaticString("\r\n").as_bytes())

    def begin_chunked(mut self) raises HttpError:
        """Send the head now, and stream the content after it.

        The content written so far becomes the first chunk.

        Raises:
            HttpError: `USAGE` when the stream has begun already, or for a
                status that has no content.
        """
        if self._state != _WriterState.OPEN:
            raise HttpError(ErrorKind.USAGE, "the stream has begun", 0)
        if not self.status.has_body():
            raise HttpError(
                ErrorKind.USAGE,
                "a " + String(self.status) + " has no content",
                0,
            )
        if self._http11:
            self._head(-1, True)
            self._state = _WriterState.CHUNKED
        else:
            self.keep_alive = False
            self._head(-1, False)
            self._state = _WriterState.UNTIL_CLOSE
        var first = self.body^
        self.body = List[UInt8]()
        self.write_chunk(first)

    def write_chunk(mut self, data: Span[UInt8, _]) raises HttpError:
        """Add bytes to the stream. Empty data adds nothing.

        Args:
            data: The bytes.

        Raises:
            HttpError: `USAGE` before `begin_chunked`.
        """
        if self._state == _WriterState.OPEN:
            raise HttpError(ErrorKind.USAGE, "call begin_chunked first", 0)
        if len(data) == 0 or self._head_only:
            return
        if self._state == _WriterState.CHUNKED:
            _append_hex(self.out, len(data))
            self.out.extend(StaticString("\r\n").as_bytes())
            self.out.extend(data)
            self.out.extend(StaticString("\r\n").as_bytes())
        else:
            self.out.extend(data)

    def flush(mut self) raises HttpError:
        """Send what `out` holds now, as far as the socket takes it.

        What the socket does not take stays in `out`, and goes out after
        the handler returns.

        A writer that is not bound to a connection, such as the writer of
        an HTTP/2 stream, keeps `out` for its owner.

        Raises:
            HttpError: `OS` when the connection has failed.
        """
        if len(self.out) == 0 or self._fd < 0:
            return
        var sent = self.sys.send(self._fd, self.out.unsafe_ptr(), len(self.out))
        if sent == -EAGAIN or sent == -EINTR:
            return
        if sent < 0:
            raise HttpError.os("send", -sent)
        var rest = len(self.out) - sent
        move_down(self.out.unsafe_ptr(), 0, sent, rest)
        self.out.resize(rest, 0)

    def fail(mut self):
        """Turn the response into an empty 500, or end a broken stream.

        The server calls it when the handler raises. A stream that has
        begun cannot change, so the connection closes without the end of
        the stream, and the client sees that the content is incomplete.
        """
        if self._state == _WriterState.OPEN:
            self.status = Status.INTERNAL_SERVER_ERROR
            self.headers.clear()
            self.body.clear()
        else:
            self.keep_alive = False
            self._state = _WriterState.DONE

    def finish(mut self):
        """End the response: append the head and the content to `out`.

        The server calls it after the handler.
        """
        if self._state == _WriterState.OPEN:
            if self.status.has_body():
                self._head(len(self.body), False)
                if not self._head_only:
                    self.out.extend(Span(self.body))
            else:
                self._head(-1, False)
        elif self._state == _WriterState.CHUNKED:
            if not self._head_only:
                self.out.extend(StaticString("0\r\n\r\n").as_bytes())
        self._state = _WriterState.DONE

    def error(mut self, status: Status):
        """Append an empty error response that closes the connection.

        Args:
            status: The status code, such as 400.
        """
        self.status = status
        self.headers.clear()
        self.body.clear()
        self.keep_alive = False
        self._head_only = False
        self._http11 = True
        self._state = _WriterState.OPEN
        self.finish()


@fieldwise_init
struct MatchKind(Equatable, ImplicitlyCopyable, Writable):
    """The outcome of `Router.find`, as a type and not a bare integer."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime FOUND = MatchKind(0)
    """A route has the method and the path."""
    comptime NOT_FOUND = MatchKind(1)
    """No route has the path: answer 404."""
    comptime METHOD_NOT_ALLOWED = MatchKind(2)
    """Routes have the path, but not the method: answer 405."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("MatchKind(", self.value, ")")


@fieldwise_init
struct Route(Copyable, Movable):
    """A method and a path, and the number that a match returns."""

    var method: Method
    """The method. A `GET` route also answers `HEAD`."""
    var path: String
    """The path; a final `*` matches any rest, such as `/static/*`."""
    var id: Int
    """The number that the caller chose for the route."""


@fieldwise_init
struct RouteMatch(Copyable, Movable):
    """The outcome of `Router.find`."""

    var kind: MatchKind
    """Whether a route matched."""
    var id: Int
    """For `FOUND`, the `id` of the route; else -1."""
    var allow: String
    """For `METHOD_NOT_ALLOWED`, the `Allow` value: the methods of the
    routes with the path."""


struct Router(Copyable, Movable):
    """A table of routes by method and path.

    `find` returns the `id` of the first route that matches, so a handler
    can dispatch with an `if` on it. `reject` writes the 404 or 405.
    """

    var routes: List[Route]
    """The routes, in the order of `add`."""

    def __init__(out self):
        """Make an empty table."""
        self.routes = List[Route]()

    def add(mut self, method: Method, path: StringSlice, id: Int):
        """Add a route.

        Args:
            method: The method.
            path: The path, such as `/graphql`, or a prefix and `*`.
            id: The number that `find` returns for the route.
        """
        self.routes.append(Route(method, String(path), id))

    def find(self, method: Method, path: StringSlice) -> RouteMatch:
        """Return the first route for a method and a path.

        Args:
            method: The method of the request.
            path: The path of the request, without its query.

        Returns:
            The match.
        """
        var allow = String()
        for ref route in self.routes:
            if not _path_matches(route.path, path):
                continue
            var same = route.method == method or (
                route.method == Method.GET and method == Method.HEAD
            )
            if same:
                return RouteMatch(MatchKind.FOUND, route.id, String())
            if allow.byte_length() > 0:
                allow += ", "
            allow += String(route.method)
        if allow.byte_length() > 0:
            return RouteMatch(MatchKind.METHOD_NOT_ALLOWED, -1, allow^)
        return RouteMatch(MatchKind.NOT_FOUND, -1, String())

    def reject(
        self, found: RouteMatch, mut response: ResponseWriter
    ) raises HttpError:
        """Write the 404 or 405 response for a match that is not FOUND.

        Args:
            found: The match.
            response: The response.

        Raises:
            HttpError: `USAGE` if the response has begun to stream.
        """
        if found.kind == MatchKind.METHOD_NOT_ALLOWED:
            response.set_status(Status.METHOD_NOT_ALLOWED)
            response.add_header("Allow", found.allow)
        else:
            response.set_status(Status.NOT_FOUND)


def _path_matches(pattern: String, path: StringSlice) -> Bool:
    """Return True for an equal path, or a prefix pattern that ends in `*`."""
    if pattern.endswith("*"):
        return path.startswith(pattern[byte = : pattern.byte_length() - 1])
    return pattern == path


@fieldwise_init
struct ServerConfig(Copyable, Movable):
    """How a server listens and what it allows."""

    var host: IPv4Address
    """The local address; `IPv4Address.ANY` at first."""
    var port: Int
    """The port; 4000 at first. 0 lets the system choose one."""
    var workers: Int
    """The worker processes of `start_workers`; 1 at first."""
    var backlog: Int
    """The queue of pending connections of each listening socket."""
    var limits: Limits
    """The size limits of a request."""
    var idle_timeout_ms: Int
    """How long a connection can be quiet: between requests, while a
    request arrives, or while the client reads no part of a response. 5000
    at first."""
    var shutdown_timeout_ms: Int
    """How long a graceful shutdown waits for busy connections."""
    var max_connections: Int
    """The most open connections of one event loop. More are closed at
    once."""
    var max_events: Int
    """The most events of one `epoll_wait`."""
    var reuse_port: Bool
    """Whether the listening socket sets `SO_REUSEPORT`."""

    def __init__(out self):
        """Make the default configuration: port 4000 on every address."""
        self.host = IPv4Address.ANY
        self.port = 4000
        self.workers = 1
        self.backlog = 1024
        self.limits = Limits()
        self.idle_timeout_ms = 5000
        self.shutdown_timeout_ms = 10000
        self.max_connections = 100000
        self.max_events = 512
        self.reuse_port = True


@fieldwise_init
struct Listener(ImplicitlyCopyable):
    """A listening socket and its port."""

    var fd: Int
    """The socket."""
    var port: Int
    """The local port."""


def _os_error(mut sys: Sys, fd: Int, call: StaticString, rc: Int) -> HttpError:
    """Close a socket and make the error of the call that failed."""
    sys.close(fd)
    return HttpError.os(call, -rc)


def open_listener(
    mut sys: Sys, host: IPv4Address, port: Int, backlog: Int, reuse_port: Bool
) raises HttpError -> Listener:
    """Open a non-blocking socket that listens on an address and a port.

    Args:
        sys: The system calls.
        host: The local address.
        port: The port; 0 lets the system choose one.
        backlog: The queue of pending connections.
        reuse_port: Whether to set `SO_REUSEPORT`.

    Returns:
        The socket and the port it listens on.

    Raises:
        HttpError: `OS` when a system call fails, such as `bind` with
            `EADDRINUSE`.
    """
    var fd = sys.socket()
    if fd < 0:
        raise HttpError.os("socket", -fd)
    var rc = sys.set_reuse_address(fd)
    if rc < 0:
        raise _os_error(sys, fd, "setsockopt", rc)
    if reuse_port:
        rc = sys.set_reuse_port(fd)
        if rc < 0:
            raise _os_error(sys, fd, "setsockopt", rc)
    rc = sys.bind(fd, host, port)
    if rc < 0:
        raise _os_error(sys, fd, "bind", rc)
    rc = sys.listen(fd, backlog)
    if rc < 0:
        raise _os_error(sys, fd, "listen", rc)
    var bound = sys.local_port(fd)
    if bound < 0:
        raise _os_error(sys, fd, "getsockname", bound)
    return Listener(fd, bound)


struct _Connection(Movable):
    """The state of one accepted connection."""

    var fd: Int
    var reader: RequestReader
    var pending: List[UInt8]
    var sent: Int
    var closing: Bool
    var discard: Bool
    var lingering: Bool
    var deadline_ms: Int
    var interest: UInt32

    def __init__(out self, limits: Limits):
        self.fd = -1
        self.reader = RequestReader(limits)
        self.pending = List[UInt8]()
        self.sent = 0
        self.closing = False
        self.discard = False
        self.lingering = False
        self.deadline_ms = 0
        self.interest = 0


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


struct Server[H: Handler](Movable):
    """One event loop that serves a handler on a listening socket.

    Parameters:
        H: The type of the handler.
    """

    var handler: Self.H
    """The handler of every request."""
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
    var _signal_fd: Int
    var _conns: List[_Connection]
    var _events: List[UInt8]
    var _now: Int
    var _second: Int
    var _last_sweep: Int
    var _drain_deadline: Int

    def __init__(
        out self,
        var handler: Self.H,
        config: ServerConfig,
        listener: Listener,
        var sys: Sys,
    ) raises HttpError:
        """Serve on a listening socket that is open already.

        A listener with the descriptor -1 makes a server without a
        listening socket. It serves only the connections that `adopt`
        gives it, such as the HTTP/1.1 connections of an HTTP/2 server.

        Args:
            handler: The handler of every request.
            config: The configuration.
            listener: The socket; the server closes it.
            sys: The system calls; tests give one with faults.

        Raises:
            HttpError: `OS` when epoll cannot be opened, or cannot watch
                the socket. The socket is closed.
        """
        self.handler = handler^
        self.config = config.copy()
        self.sys = sys^
        self.writer = ResponseWriter()
        self.port = listener.port
        self.open_connections = 0
        self.draining = False
        self._listen_fd = listener.fd
        self._epoll_fd = -1
        self._signal_fd = -1
        self._conns = List[_Connection]()
        self._events = List[UInt8](
            length=max(config.max_events, 1) * EPOLL_EVENT_SIZE, fill=0
        )
        self._now = _now_ms()
        self._second = -1
        self._last_sweep = self._now
        self._drain_deadline = 0
        self._tick()
        var epoll = self.sys.epoll_create()
        if epoll < 0:
            self.close()
            raise HttpError.os("epoll_create1", -epoll)
        self._epoll_fd = epoll
        if listener.fd < 0:
            return
        var rc = self.sys.epoll_ctl(epoll, EPOLL_CTL_ADD, listener.fd, EPOLLIN)
        if rc < 0:
            self.close()
            raise HttpError.os("epoll_ctl", -rc)

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
        if self._signal_fd >= 0:
            self.sys.close(self._signal_fd)
            self._signal_fd = -1
        if self._epoll_fd >= 0:
            self.sys.close(self._epoll_fd)
            self._epoll_fd = -1

    def listen_signals(mut self) raises HttpError:
        """Begin a graceful shutdown on `SIGTERM` or `SIGINT`.

        This blocks the two signals in the calling thread and reads them
        from a `signalfd` in the loop. Call it only in a process with one
        thread, such as a worker after `fork`: a Mojo program has more.

        Raises:
            HttpError: `OS` when the `signalfd` cannot be opened or watched.
        """
        var fd = self.sys.signal_fd()
        if fd < 0:
            raise HttpError.os("signalfd", -fd)
        var rc = self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_ADD, fd, EPOLLIN)
        if rc < 0:
            self.sys.close(fd)
            raise HttpError.os("epoll_ctl", -rc)
        self._signal_fd = fd

    def stopped(self) -> Bool:
        """Return True when a graceful shutdown has ended.

        Returns:
            Whether the server drains and has no open connection.
        """
        return self.draining and self.open_connections == 0

    def run(mut self) raises HttpError:
        """Run the loop until a graceful shutdown ends.

        Raises:
            HttpError: `OS` when `epoll_wait` fails.
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
                self._close(fd)
            fd += 1

    def _idle(self, fd: Int) -> Bool:
        """Return True for a connection between requests."""
        ref conn = self._conns[fd]
        return conn.reader.buffered() == 0 and len(conn.pending) == 0

    def _tick(mut self):
        """Read the clocks, and update the `Date` field once a second."""
        self._now = _now_ms()
        var second = self.sys.wall_seconds()
        if second != self._second:
            self._second = second
            self.writer.set_date(second)

    def poll(mut self, timeout_ms: Int) raises HttpError -> Int:
        """Run one turn of the loop: wait for events and handle them.

        Args:
            timeout_ms: The longest wait in milliseconds; -1 waits until an
                event. With open connections the wait is at most a second,
                so that idle connections time out.

        Returns:
            The count of events.

        Raises:
            HttpError: `OS` when `epoll_wait` fails.
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
            raise HttpError.os("epoll_wait", -count)
        self._tick()
        var events = self._events.unsafe_ptr()
        for index in range(count):
            var fd = event_fd(events, index)
            var flags = event_flags(events, index)
            if fd == self._listen_fd:
                self._accept()
            elif fd == self._signal_fd:
                _ = self.sys.read_signal(fd)
                self.begin_shutdown()
            elif self._conns[fd].fd < 0:
                # The connection closed earlier in this turn.
                continue
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
        """Accept every pending connection."""
        while True:
            var fd = self.sys.accept(self._listen_fd)
            if fd < 0:
                return
            if self.open_connections >= self.config.max_connections:
                self.sys.close(fd)
                continue
            _ = self.sys.set_no_delay(fd)
            while len(self._conns) <= fd:
                self._conns.append(_Connection(self.config.limits))
            if (
                self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_ADD, fd, EPOLLIN)
                < 0
            ):
                self.sys.close(fd)
                continue
            self._conns[fd].fd = fd
            self._conns[fd].interest = EPOLLIN
            self._conns[fd].deadline_ms = (
                self._now + self.config.idle_timeout_ms
            )
            self.open_connections += 1

    def epoll_fd(self) -> Int:
        """Return the epoll descriptor of the loop.

        Another event loop can watch it for `EPOLLIN`, and call `poll(0)`
        when it is readable.

        Returns:
            The descriptor.
        """
        return self._epoll_fd

    def adopt(mut self, fd: Int, data: Span[UInt8, _]):
        """Serve a connection that another loop accepted, with the bytes
        that it read from the connection already.

        An HTTP/2 server uses it for a connection that does not start with
        the HTTP/2 preface. The server owns the descriptor from now on: it
        closes it when it cannot take the connection.

        Args:
            fd: The connected socket, non-blocking.
            data: The bytes that were read from the socket, in order.
        """
        self._tick()
        if (
            self.draining
            or self.open_connections >= self.config.max_connections
        ):
            self.sys.close(fd)
            return
        while len(self._conns) <= fd:
            self._conns.append(_Connection(self.config.limits))
        if self.sys.epoll_ctl(self._epoll_fd, EPOLL_CTL_ADD, fd, EPOLLIN) < 0:
            self.sys.close(fd)
            return
        self._conns[fd].fd = fd
        self._conns[fd].interest = EPOLLIN
        self._conns[fd].deadline_ms = self._now + self.config.idle_timeout_ms
        self.open_connections += 1
        self._conns[fd].reader.append(data)
        self._process(fd)

    def _close(mut self, fd: Int):
        """Close a connection and make its slot free."""
        self.sys.close(fd)
        ref conn = self._conns[fd]
        conn.fd = -1
        conn.reader.reset()
        conn.pending.clear()
        conn.sent = 0
        conn.closing = False
        conn.discard = False
        conn.lingering = False
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

    def _readable(mut self, fd: Int):
        """Read from a connection and answer the complete requests."""
        self._conns[fd].reader.reserve(4096)
        var n = self.sys.recv(
            fd,
            self._conns[fd].reader.write_pointer(),
            self._conns[fd].reader.space(),
        )
        if n == -EAGAIN or n == -EINTR:
            return
        if n <= 0:
            self._close(fd)
            return
        if self._conns[fd].lingering:
            return
        self._conns[fd].reader.commit(n)
        self._conns[fd].deadline_ms = self._now + self.config.idle_timeout_ms
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
                self._conns[fd].discard = True
                break
            var keep = self._conns[fd].reader.request.keep_alive
            self.writer.begin(
                self._conns[fd].reader.request, fd, keep and not self.draining
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
        self._flush(fd)

    def _flush(mut self, fd: Int):
        """Send the output of the writer, and keep what the socket refuses."""
        var total = len(self.writer.out)
        if total > 0:
            var sent = self.sys.send(fd, self.writer.out.unsafe_ptr(), total)
            if sent == -EAGAIN or sent == -EINTR:
                sent = 0
            if sent < 0:
                self.writer.out.clear()
                self._close(fd)
                return
            if sent < total:
                self._conns[fd].pending.extend(Span(self.writer.out)[sent:])
                self.writer.out.clear()
                _ = self._watch(fd, EPOLLOUT)
                return
            self.writer.out.clear()
        if self._conns[fd].closing:
            self._end(fd)

    def _writable(mut self, fd: Int):
        """Send more of the output that waits for a connection."""
        ref conn = self._conns[fd]
        var rest = len(conn.pending) - conn.sent
        var sent = self.sys.send(
            fd, conn.pending.unsafe_ptr().unsafe_offset(conn.sent), rest
        )
        if sent == -EAGAIN or sent == -EINTR:
            return
        if sent < 0:
            self._close(fd)
            return
        self._conns[fd].sent += sent
        # The client reads: the connection is not quiet.
        self._conns[fd].deadline_ms = self._now + self.config.idle_timeout_ms
        if sent < rest:
            return
        self._conns[fd].pending.clear()
        self._conns[fd].sent = 0
        if self._conns[fd].closing:
            self._end(fd)
            return
        if self._watch(fd, EPOLLIN):
            self._process(fd)

    def _end(mut self, fd: Int):
        """Close a connection after its last response.

        When the client may still send, the server sends its end of the
        stream first and reads until the client closes, so that the client
        gets the response and not a reset (RFC 9112 section 9.6).
        """
        if (
            not self._conns[fd].discard
            and self._conns[fd].reader.buffered() == 0
        ):
            self._close(fd)
            return
        if self.sys.shutdown_write(fd) < 0:
            self._close(fd)
            return
        if not self._watch(fd, EPOLLIN):
            return
        self._conns[fd].lingering = True
        self._conns[fd].deadline_ms = self._now + _LINGER_MS


struct WorkerPool(Movable):
    """The worker processes that `start_workers` started."""

    var pids: List[Int]
    """The process ids of the workers that run."""
    var port: Int
    """The port that the workers listen on."""
    var sys: Sys
    """The system calls."""

    def __init__(out self, var pids: List[Int], port: Int):
        """Make a pool of running workers.

        Args:
            pids: The process ids.
            port: The port.
        """
        self.pids = pids^
        self.port = port
        self.sys = Sys()

    def wait(mut self) -> Int:
        """Wait until every worker has ended.

        Returns:
            How many workers ended with an exit code other than 0.
        """
        var failed = 0
        var index = 0
        while index < len(self.pids):
            var result = self.sys.wait(self.pids[index], True)
            if result[1] != 0:
                failed += 1
            index += 1
        self.pids.clear()
        return failed

    def stop(mut self, timeout_ms: Int = 10000) -> Int:
        """Shut the workers down gracefully, and kill those that stay.

        Args:
            timeout_ms: How long to wait before `SIGKILL`.

        Returns:
            How many workers ended with an exit code other than 0; a
            killed worker counts.
        """
        var index = 0
        while index < len(self.pids):
            _ = self.sys.kill(self.pids[index], SIGTERM)
            index += 1
        var deadline = _now_ms() + timeout_ms
        var failed = 0
        var running = self.pids.copy()
        while len(running) > 0:
            var still = List[Int]()
            index = 0
            while index < len(running):
                var result = self.sys.wait(running[index], False)
                if result[0] == 0:
                    still.append(running[index])
                elif result[1] != 0:
                    failed += 1
                index += 1
            running = still^
            if len(running) == 0:
                break
            if _now_ms() >= deadline:
                index = 0
                while index < len(running):
                    _ = self.sys.kill(running[index], SIGKILL)
                    _ = self.sys.wait(running[index], True)
                    failed += 1
                    index += 1
                break
            _ = self.sys.poll(-1, 0, 5)
        self.pids.clear()
        return failed


def start_workers[
    H: Handler
](
    var handler: H, config: ServerConfig, var sys: Sys = Sys()
) raises HttpError -> WorkerPool:
    """Fork `config.workers` processes that serve a handler on one port.

    The parent opens one listening socket per worker with `SO_REUSEPORT`,
    all on the same port, and then forks. Each worker keeps its socket and
    runs an event loop. The parent keeps no socket, and returns at once.

    Args:
        handler: The handler; each worker gets a copy of its memory.
        config: The configuration. A port of 0 picks a free port.
        sys: The system calls; tests give one with faults.

    Returns:
        The pool, with the port.

    Raises:
        HttpError: `OS` when a socket cannot be opened or `fork` fails.
            The workers that had started are stopped.

    Parameters:
        H: The type of the handler.
    """
    var count = max(config.workers, 1)
    var listeners = List[Int]()
    var port = config.port
    while len(listeners) < count:
        try:
            var listener = open_listener(
                sys, config.host, port, config.backlog, True
            )
            port = listener.port
            listeners.append(listener.fd)
        except e:
            _close_all(sys, listeners)
            raise e^
    var parent = sys.pid()
    var pids = List[Int]()
    var child = -1
    while len(pids) < count:
        var pid = sys.fork()
        if pid == 0:
            child = len(pids)
            break
        if pid < 0:
            _close_all(sys, listeners)
            var started = WorkerPool(pids^, port)
            _ = started.stop(1000)
            raise HttpError.os("fork", -pid)
        pids.append(pid)
    if child >= 0:
        run_worker(handler^, config, listeners, child, port, parent, sys.copy())
    _close_all(sys, listeners)
    return WorkerPool(pids^, port)


def _close_all(mut sys: Sys, fds: List[Int]):
    """Close every descriptor of a list."""
    var index = 0
    while index < len(fds):
        sys.close(fds[index])
        index += 1


def run_worker[
    H: Handler
](
    var handler: H,
    config: ServerConfig,
    listeners: List[Int],
    index: Int,
    port: Int,
    parent: Int,
    var sys: Sys = Sys(),
):
    """Run the event loop of one worker, then end the process.

    `start_workers` calls it in each child. It does not return.

    Args:
        handler: The handler.
        config: The configuration.
        listeners: Every listening socket; the worker keeps one.
        index: Which socket the worker keeps.
        port: The port.
        parent: The id of the parent process. When the parent has ended
            already, the worker ends at once with status 1.
        sys: The system calls of the worker and its server; tests give
            one with faults.

    Parameters:
        H: The type of the handler.
    """
    var position = 0
    while position < len(listeners):
        if position != index:
            sys.close(listeners[position])
        position += 1
    _ = sys.die_with_parent()
    var code = 0
    if sys.parent_pid() != parent:
        sys.close(listeners[index])
        code = 1
    else:
        try:
            var server = Server(
                handler^, config, Listener(listeners[index], port), sys.copy()
            )
            server.listen_signals()
            server.run()
        except:
            code = 1
    sys.exit_now(code)


def serve[
    H: Handler
](var handler: H, config: ServerConfig, var sys: Sys = Sys()) raises HttpError:
    """Serve a handler with worker processes until they end.

    The calling process waits for the workers. Send `SIGTERM` or `SIGINT`
    to the process group for a graceful shutdown; a worker also gets
    `SIGTERM` when this process ends.

    Args:
        handler: The handler.
        config: The configuration.
        sys: The system calls of the parent and the workers; tests give
            one with faults.

    Raises:
        HttpError: `OS` when the workers cannot start, or a worker fails.

    Parameters:
        H: The type of the handler.
    """
    var pool = start_workers(handler^, config, sys^)
    var failed = pool.wait()
    if failed > 0:
        raise HttpError(ErrorKind.OS, String(failed) + " workers failed", 0)


def listen[
    H: Handler
](
    var handler: H, config: ServerConfig, var sys: Sys = Sys()
) raises HttpError -> Server[H]:
    """Make a server that listens on the address and the port of a
    configuration, in this process.

    Args:
        handler: The handler of every request.
        config: The configuration.
        sys: The system calls; tests give one with faults.

    Returns:
        The server. Its `port` is the port it listens on.

    Raises:
        HttpError: `OS` when the socket or epoll cannot be opened.

    Parameters:
        H: The type of the handler.
    """
    var listener = open_listener(
        sys, config.host, config.port, config.backlog, config.reuse_port
    )
    return Server(handler^, config, listener, sys^)


def detached[
    H: Handler
](
    var handler: H, config: ServerConfig, var sys: Sys = Sys()
) raises HttpError -> Server[H]:
    """Make a server without a listening socket, in this process.

    It serves only the connections that `Server.adopt` gives it, such as
    the HTTP/1.1 connections of an HTTP/2 server. Its `port` is 0.

    Args:
        handler: The handler of every request.
        config: The configuration; the address and the port are not used.
        sys: The system calls; tests give one with faults.

    Returns:
        The server.

    Raises:
        HttpError: `OS` when epoll cannot be opened.

    Parameters:
        H: The type of the handler.
    """
    return Server(handler^, config, Listener(-1, 0), sys^)
