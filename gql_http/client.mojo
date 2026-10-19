# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTP/1.1 client with a pool of keep-alive connections per host.

`Client.send`, `get` and `post` send one request and return the whole
`Response`. The client keeps each connection that can stay open, by
address and port, and uses it again for the next request to the same
place. `Client.endpoint`
parses and resolves a URL once, so a caller that sends many requests to one
service, such as a router to its subgraphs, does that work once.

Each request has a deadline, `ClientConfig.timeout_ms`, for the connect,
the send and the whole response. The sockets are non-blocking; a wait is a
`poll` that ends at the deadline.

A connection from the pool can have been closed by the server while it was
idle. The client looks for that before it uses one. When a reused
connection fails before any byte of the response arrives, the client sends
the request once more on a new connection, if the method is idempotent or
the send itself failed. A `POST` that the server could have received is
not sent twice. This is the rule of Go `net/http`.

Only `http` URLs; there is no TLS. Only IPv4.

This module ports no code. The behavior follows RFC 9110 and RFC 9112.

Differences from upstream: none; there is no upstream.
"""

from std.time import perf_counter_ns

from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.parser import (
    BodyKind,
    ChunkedDecoder,
    Limits,
    ParseState,
    ResponseHead,
    parse_response_head,
)
from gql_http.scan import LF, equals_ignore_case, find_byte, move_down
from gql_http.socket import (
    EAGAIN,
    EINPROGRESS,
    EINTR,
    POLLIN,
    POLLOUT,
    IPv4Address,
    Sys,
)
from gql_http.status import Method, Status, Version
from gql_http.url import Url


@fieldwise_init
struct ClientConfig(Copyable, Movable):
    """The timeouts and limits of a client."""

    var connect_timeout_ms: Int
    """The longest wait for a connection; 5000 at first."""
    var timeout_ms: Int
    """The deadline of a whole request; 30000 at first."""
    var max_idle_per_host: Int
    """The most idle connections the pool keeps per address and port; 0
    turns the pool off. The client keeps at most one, because it sends one
    request at a time."""
    var limits: Limits
    """The size limits of a response; 64 MiB of content at first."""

    def __init__(out self):
        """Make the default configuration."""
        self.connect_timeout_ms = 5000
        self.timeout_ms = 30000
        self.max_idle_per_host = 64
        self.limits = Limits()
        self.limits.max_body_bytes = 64 * 1024 * 1024


@fieldwise_init
struct Endpoint(Copyable, Movable, Writable):
    """A resolved place to send requests: an address, a port, and the
    `Host` value and target of its URL."""

    var address: IPv4Address
    """The IPv4 address."""
    var port: Int
    """The port."""
    var authority: String
    """The `Host` value, such as `localhost:4001`."""
    var target: String
    """The path and query of the URL, such as `/graphql`."""

    def write_to(self, mut writer: Some[Writer]):
        """Write `http://authority/target`.

        Args:
            writer: The destination.
        """
        writer.write("http://", self.authority, self.target)


struct Response(Movable):
    """A whole response: status, fields and content, in one buffer."""

    var status: Status
    """The status code."""
    var version: Version
    """The protocol version of the response."""
    var data: List[UInt8]
    """The bytes of the head and of the decoded content."""
    var head: ResponseHead
    """The parsed head; its offsets are into `data`."""
    var _body_start: Int
    var _body_end: Int

    def __init__(out self):
        """Make an empty response."""
        self.status = Status.OK
        self.version = Version.HTTP_1_1
        self.data = List[UInt8]()
        self.head = ResponseHead()
        self._body_start = 0
        self._body_end = 0

    def _slice(self, start: Int, end: Int) -> StringSlice[origin_of(self.data)]:
        """Return bytes of `data` as text."""
        return StringSlice(unsafe_from_utf8=Span(self.data)[start:end])

    def reason(self) -> StringSlice[origin_of(self.data)]:
        """Return the reason phrase, such as `OK`.

        Returns:
            The phrase; it can be empty.
        """
        return self._slice(self.head.reason_start, self.head.reason_end)

    def header_count(self) -> Int:
        """Return the number of header fields.

        Returns:
            The count.
        """
        return len(self.head.fields)

    def header_name(self, index: Int) -> StringSlice[origin_of(self.data)]:
        """Return the name of a field, case kept.

        Args:
            index: The field's index, from 0 to `header_count() - 1`.

        Returns:
            The name.
        """
        var field = self.head.fields[index]
        return self._slice(Int(field.name_start), Int(field.name_end))

    def header_value(self, index: Int) -> StringSlice[origin_of(self.data)]:
        """Return the value of a field.

        Args:
            index: The field's index, from 0 to `header_count() - 1`.

        Returns:
            The value.
        """
        var field = self.head.fields[index]
        return self._slice(Int(field.value_start), Int(field.value_end))

    def header(
        self, name: StringSlice
    ) -> Optional[StringSlice[origin_of(self.data)]]:
        """Return the value of the first field with a name, case folded.

        Args:
            name: The field name, in any case.

        Returns:
            The value, or None.
        """
        for index in range(len(self.head.fields)):
            if equals_ignore_case(
                self.header_name(index).as_bytes(), name.as_bytes()
            ):
                return self.header_value(index)
        return None

    def body(self) -> Span[UInt8, origin_of(self.data)]:
        """Return the content, after chunked decoding.

        Returns:
            The bytes.
        """
        return Span(self.data)[self._body_start : self._body_end]

    def text(self) raises HttpError -> String:
        """Return the content as text.

        Returns:
            The content.

        Raises:
            HttpError: `PROTOCOL` when the content is not UTF-8.
        """
        try:
            return String(StringSlice(from_utf8=self.body()))
        except:
            raise HttpError(ErrorKind.PROTOCOL, "the content is not UTF-8", 0)


@fieldwise_init
struct _Idle(ImplicitlyCopyable):
    """An idle connection of the pool."""

    var address: UInt32
    var port: Int
    var fd: Int


@fieldwise_init
struct _Resolved(Copyable):
    """A host name and the address it resolved to."""

    var host: String
    var address: IPv4Address


def _now_ns() -> Int:
    """Return a monotonic time in nanoseconds."""
    return Int(perf_counter_ns())


struct Client(Movable, ResponseSource):
    """An HTTP/1.1 client with a pool of keep-alive connections."""

    var config: ClientConfig
    """The timeouts and limits."""
    var sys: Sys
    """The system calls; tests give one with faults."""
    var _idle: List[_Idle]
    var _out: List[UInt8]
    var _hosts: List[_Resolved]
    var _retry: Bool
    var _got: Int
    var _fd: Int

    def __init__(out self, config: ClientConfig = ClientConfig()):
        """Make a client with an empty pool.

        Args:
            config: The timeouts and limits.
        """
        self.config = config.copy()
        self.sys = Sys()
        self._idle = List[_Idle]()
        self._out = List[UInt8]()
        self._hosts = List[_Resolved]()
        self._retry = False
        self._got = 0
        self._fd = -1

    def __deinit__(deinit self):
        """Close the idle connections."""
        for idle in self._idle:
            self.sys.close(idle.fd)

    def idle_connections(self) -> Int:
        """Return the count of idle connections in the pool.

        Returns:
            The count.
        """
        return len(self._idle)

    def close_idle(mut self):
        """Close every idle connection."""
        for idle in self._idle:
            self.sys.close(idle.fd)
        self._idle.clear()

    def endpoint(mut self, url: StringSlice) raises HttpError -> Endpoint:
        """Parse an `http` URL and resolve its host.

        The client remembers each host that it resolved.

        Args:
            url: The URL, such as `http://localhost:4001/graphql`.

        Returns:
            The endpoint.

        Raises:
            HttpError: `PROTOCOL` for an invalid URL, `USAGE` for a scheme
                other than `http`, `RESOLVE` for an unknown host.
        """
        var parsed = Url.parse(url)
        if parsed.scheme != "http":
            raise HttpError(
                ErrorKind.USAGE,
                "only http URLs are supported: " + String(url),
                0,
            )
        var address = self._resolve(parsed.host)
        return Endpoint(
            address, parsed.port, parsed.authority(), parsed.target()
        )

    def _resolve(mut self, host: String) raises HttpError -> IPv4Address:
        """Resolve a host, or give the address it resolved to before."""
        for ref known in self._hosts:
            if known.host == host:
                return known.address
        var address = self.sys.resolve(host)
        self._hosts.append(_Resolved(host.copy(), address))
        return address

    def get(mut self, url: StringSlice) raises HttpError -> Response:
        """Send a `GET` request.

        Args:
            url: The URL.

        Returns:
            The response.

        Raises:
            HttpError: For an invalid URL, a failed connection, a timeout or
                an invalid response.
        """
        var endpoint = self.endpoint(url)
        var target = endpoint.target.copy()
        return self.send(endpoint, Method.GET, target, Headers(), List[UInt8]())

    def post(
        mut self, url: StringSlice, content_type: StringSlice, body: StringSlice
    ) raises HttpError -> Response:
        """Send a `POST` request with content.

        Args:
            url: The URL.
            content_type: The `Content-Type` value.
            body: The content.

        Returns:
            The response.

        Raises:
            HttpError: For an invalid URL or content type, a failed
                connection, a timeout or an invalid response.
        """
        var endpoint = self.endpoint(url)
        var headers = Headers()
        headers.add("Content-Type", content_type)
        var target = endpoint.target.copy()
        return self.send(
            endpoint, Method.POST, target, headers, body.as_bytes()
        )

    def send(
        mut self,
        endpoint: Endpoint,
        method: Method,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises HttpError -> Response:
        """Send a request to an endpoint and read the whole response.

        The client writes `Host` (unless `headers` has one) and
        `Content-Length`.

        Args:
            endpoint: Where to send it.
            method: The method; not `OTHER`.
            target: The request target, such as `/graphql?x=1`.
            headers: The other header fields.
            body: The content; empty for none.

        Returns:
            The response.

        Raises:
            HttpError: `USAGE` for an `OTHER` method, an invalid target, or
                a framing field in `headers`; `CONNECT`, `TIMEOUT`, `CLOSED`,
                `PROTOCOL`, `LIMIT` or `OS` when the exchange fails.
        """
        self._build(endpoint, method, target, headers, body)
        var deadline = _now_ns() + self.config.timeout_ms * 1_000_000
        var fd = self._take_idle(endpoint)
        if fd >= 0:
            try:
                return self._exchange(fd, endpoint, method, deadline, True)
            except e:
                if not self._retry:
                    raise e^
        fd = self._connect(endpoint, deadline)
        return self._exchange(fd, endpoint, method, deadline, False)

    def _build(
        mut self,
        endpoint: Endpoint,
        method: Method,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises HttpError:
        """Write the request into `_out`."""
        if method == Method.OTHER or not method.is_valid():
            raise HttpError(ErrorKind.USAGE, "invalid method", 0)
        for byte in target.as_bytes():
            if byte <= 32 or byte >= 127:
                raise HttpError(ErrorKind.USAGE, "invalid request target", 0)
        if target.byte_length() == 0:
            raise HttpError(ErrorKind.USAGE, "empty request target", 0)
        if (
            headers.find("content-length") >= 0
            or headers.find("transfer-encoding") >= 0
        ):
            raise HttpError(
                ErrorKind.USAGE, "the client writes the framing fields", 0
            )
        self._out.clear()
        self._out.extend(method.text().as_bytes())
        self._out.append(32)
        self._out.extend(target.as_bytes())
        self._out.extend(StaticString(" HTTP/1.1\r\n").as_bytes())
        if headers.find("host") < 0:
            self._out.extend(StaticString("Host: ").as_bytes())
            self._out.extend(endpoint.authority.as_bytes())
            self._out.extend(StaticString("\r\n").as_bytes())
        self._out.extend(Span(headers.data))
        var with_body = (
            method == Method.POST
            or method == Method.PUT
            or (method == Method.PATCH)
        )
        if len(body) > 0 or with_body:
            self._out.extend(StaticString("Content-Length: ").as_bytes())
            self._out.extend(String(len(body)).as_bytes())
            self._out.extend(StaticString("\r\n").as_bytes())
        self._out.extend(StaticString("\r\n").as_bytes())
        self._out.extend(body)

    def _take_idle(mut self, endpoint: Endpoint) -> Int:
        """Take a live idle connection to an endpoint, or return -1."""
        var index = len(self._idle) - 1
        while index >= 0:
            var idle = self._idle[index]
            if (
                idle.address == endpoint.address.value
                and idle.port == endpoint.port
            ):
                _ = self._idle.pop(index)
                if self.sys.peek(idle.fd) == -EAGAIN:
                    return idle.fd
                # Closed by the server, or it sent bytes without a request.
                self.sys.close(idle.fd)
            index -= 1
        return -1

    def _give_back(mut self, fd: Int, endpoint: Endpoint):
        """Put a connection in the pool, or close it when the pool is off.

        The client sends one request at a time, and `send` takes the idle
        connection of an endpoint before it opens a new one. So the pool
        never holds a second connection to an endpoint, and a limit of 1 or
        more never closes one.
        """
        if self.config.max_idle_per_host < 1:
            self.sys.close(fd)
            return
        self._idle.append(_Idle(endpoint.address.value, endpoint.port, fd))

    def _wait(mut self, fd: Int, events: Int, deadline: Int) raises HttpError:
        """Wait until a socket is ready, or raise `TIMEOUT` at the deadline."""
        while True:
            var remaining = (deadline - _now_ns() + 999_999) // 1_000_000
            if remaining <= 0:
                raise HttpError(ErrorKind.TIMEOUT, "the request timed out", 0)
            var rc = self.sys.poll(fd, events, remaining)
            if rc > 0:
                return
            if rc < 0 and rc != -EINTR:
                raise HttpError.os("poll", -rc)

    def _connect(
        mut self, endpoint: Endpoint, deadline: Int
    ) raises HttpError -> Int:
        """Open a new connection to an endpoint."""
        var fd = self.sys.socket()
        if fd < 0:
            raise HttpError.os("socket", -fd)
        _ = self.sys.set_no_delay(fd)
        var rc = self.sys.connect(fd, endpoint.address, endpoint.port)
        if rc == -EINPROGRESS:
            var limit = _now_ns() + self.config.connect_timeout_ms * 1_000_000
            try:
                self._wait(fd, POLLOUT, min(deadline, limit))
            except e:
                self.sys.close(fd)
                raise e^
            rc = self.sys.socket_error(fd)
            if rc > 0:
                rc = -rc
        if rc != 0:
            self.sys.close(fd)
            raise HttpError(
                ErrorKind.CONNECT,
                "cannot connect to "
                + String(endpoint)
                + ": errno "
                + String(-rc),
                -rc,
            )
        return fd

    def _exchange(
        mut self,
        fd: Int,
        endpoint: Endpoint,
        method: Method,
        deadline: Int,
        reused: Bool,
    ) raises HttpError -> Response:
        """Send `_out` on a connection and read the response.

        It sets `_retry` before it raises: whether a new connection can
        send the request again.
        """
        self._retry = False
        try:
            self._send_all(fd, deadline)
        except e:
            self.sys.close(fd)
            self._retry = reused and e.kind != ErrorKind.TIMEOUT
            raise e^
        var response = Response()
        var keep: Bool
        try:
            keep = self._receive(fd, method, deadline, response)
        except e:
            self.sys.close(fd)
            self._retry = (
                reused
                and self._got == 0
                and e.kind == ErrorKind.CLOSED
                and method.is_idempotent()
            )
            raise e^
        if keep:
            self._give_back(fd, endpoint)
        else:
            self.sys.close(fd)
        return response^

    def _send_all(mut self, fd: Int, deadline: Int) raises HttpError:
        """Send every byte of `_out`."""
        var sent = 0
        var total = len(self._out)
        while sent < total:
            var n = self.sys.send(
                fd, self._out.unsafe_ptr().unsafe_offset(sent), total - sent
            )
            if n == -EAGAIN:
                self._wait(fd, POLLOUT, deadline)
                continue
            if n == -EINTR:
                continue
            if n < 0:
                raise HttpError(
                    ErrorKind.CLOSED, "send failed: errno " + String(-n), -n
                )
            sent += n

    def read_more(
        mut self, mut data: List[UInt8], mut end: Int, deadline: Int
    ) raises HttpError -> Int:
        """Read more bytes of the response into `data` at `end`.

        `read_response` calls it, on the connection of the request that
        the client sends now.

        Args:
            data: The buffer; it grows when it has little room.
            end: The count of bytes in `data`; it grows by the result.
            deadline: The deadline, from `perf_counter_ns`.

        Returns:
            The count of bytes, or 0 at the end of the stream.

        Raises:
            HttpError: `TIMEOUT` at the deadline; `CLOSED` when `recv`
                fails.
        """
        if len(data) - end < 4096:
            data.resize(max(len(data) * 2, end + 16384), 0)
        while True:
            var n = self.sys.recv(
                self._fd, data.unsafe_ptr().unsafe_offset(end), len(data) - end
            )
            if n > 0:
                end += n
                self._got += n
                return n
            if n == 0:
                return 0
            if n == -EAGAIN:
                self._wait(self._fd, POLLIN, deadline)
            elif n != -EINTR:
                raise HttpError(
                    ErrorKind.CLOSED, "recv failed: errno " + String(-n), -n
                )

    def _receive(
        mut self, fd: Int, method: Method, deadline: Int, mut response: Response
    ) raises HttpError -> Bool:
        """Read a whole response; return whether the connection can stay
        open."""
        self._fd = fd
        self._got = 0
        var limits = self.config.limits
        return read_response(self, method, limits, deadline, response)


trait ResponseSource:
    """Where `read_response` reads the bytes of a response: a socket, or a
    TLS stream."""

    def read_more(
        mut self, mut data: List[UInt8], mut end: Int, deadline: Int
    ) raises HttpError -> Int:
        """Read more bytes of the response into `data` at `end`.

        Args:
            data: The buffer; it grows when it has little room.
            end: The count of bytes in `data`; it grows by the result.
            deadline: The deadline, from `perf_counter_ns`.

        Returns:
            The count of bytes, or 0 at the end of the stream.

        Raises:
            HttpError: `TIMEOUT` at the deadline; `CLOSED` when the
                connection fails.
        """
        ...


def read_response[
    S: ResponseSource
](
    mut source: S,
    method: Method,
    limits: Limits,
    deadline: Int,
    mut response: Response,
) raises HttpError -> Bool:
    """Read a whole response: the head, then content by its framing.

    Interim responses, such as `100 Continue`, are dropped.

    Args:
        source: Where the bytes come from.
        method: The method of the request; a `HEAD` response has no
            content.
        limits: The size limits of the response.
        deadline: The deadline, from `perf_counter_ns`.
        response: The response to fill.

    Returns:
        Whether the connection can stay open.

    Raises:
        HttpError: `CLOSED` when the stream ends early, `PROTOCOL` for an
            invalid response, `LIMIT` for one that is too large, and the
            errors of `source`.

    Parameters:
        S: The type of the source.
    """
    var data = List[UInt8]()
    var end = 0
    var scanned = 0
    while True:
        if find_byte(data.unsafe_ptr(), scanned, end, LF) == end:
            scanned = end
            if source.read_more(data, end, deadline) == 0:
                raise HttpError(
                    ErrorKind.CLOSED,
                    "the connection closed before the response",
                    0,
                )
            continue
        var head = parse_response_head(
            data.unsafe_ptr(), end, limits, response.head
        )
        if head.state == ParseState.ERROR:
            raise HttpError(ErrorKind.PROTOCOL, "invalid response head", 0)
        if head.state == ParseState.INCOMPLETE:
            scanned = end
            continue
        if not response.head.status.is_informational():
            break
        if response.head.status == Status.SWITCHING_PROTOCOLS:
            raise HttpError(
                ErrorKind.PROTOCOL, "the server switched protocols", 0
            )
        # Drop a 100 Continue or another interim response.
        move_down(data.unsafe_ptr(), 0, head.size, end - head.size)
        end -= head.size
        scanned = 0
    var head_size = response.head.head_size
    var kind = response.head.body_kind(method)
    var message_end = head_size
    var body_end = head_size
    if kind == BodyKind.LENGTH:
        var length = response.head.content_length
        if length > limits.max_body_bytes:
            raise HttpError(ErrorKind.LIMIT, "the response is too large", 0)
        while end - head_size < length:
            if source.read_more(data, end, deadline) == 0:
                raise HttpError(
                    ErrorKind.CLOSED,
                    "the connection closed in the content",
                    0,
                )
        message_end = head_size + length
        body_end = message_end
    elif kind == BodyKind.CHUNKED:
        var decoder = ChunkedDecoder()
        decoder.reset(head_size)
        while True:
            var result = decoder.feed(data.unsafe_ptr(), end, limits)
            if result.state == ParseState.COMPLETE:
                message_end = result.size
                break
            if result.state == ParseState.ERROR:
                if result.status == Status.CONTENT_TOO_LARGE:
                    raise HttpError(
                        ErrorKind.LIMIT, "the response is too large", 0
                    )
                raise HttpError(
                    ErrorKind.PROTOCOL, "invalid chunked content", 0
                )
            if source.read_more(data, end, deadline) == 0:
                raise HttpError(
                    ErrorKind.CLOSED,
                    "the connection closed in the content",
                    0,
                )
        body_end = decoder.write
    elif kind == BodyKind.CLOSE:
        # The first read can bring the whole body with the head.
        while end - head_size <= limits.max_body_bytes:
            if source.read_more(data, end, deadline) == 0:
                break
        if end - head_size > limits.max_body_bytes:
            raise HttpError(ErrorKind.LIMIT, "the response is too large", 0)
        message_end = end
        body_end = end
    var keep = (
        response.head.keep_alive
        and kind != BodyKind.CLOSE
        and end == message_end
    )
    data.resize(body_end, 0)
    response.data = data^
    response.status = response.head.status
    response.version = response.head.version
    response._body_start = head_size
    response._body_end = body_end
    return keep
