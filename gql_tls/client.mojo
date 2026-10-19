# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTPS/1.1 client with a pool of keep-alive TLS connections.

`HttpsClient` sends one request and returns the whole
`gql_http.client.Response`. It reads the response with
`gql_http.client.read_response`, so its framing rules are those of the
HTTP client. Its context offers ALPN `http/1.1` only, because it speaks no
HTTP/2: `gql_http3.fallback` chooses HTTP/3, HTTP/2 or HTTP/1.1.

The client verifies the certificate and the host name of the server
against the system CA store, unless its context says otherwise.

- **Deadline:** each request has the deadline `ClientConfig.timeout_ms`,
  for the connect, the handshake, the send and the whole response.
- **Stale connections:** before the client uses a pooled connection, it
  peeks at the socket. A quiet socket is a live connection. When bytes
  wait, the client reads them without waiting: a TLS 1.3 server sends
  session tickets after the handshake, which leave the connection live,
  and anything else, or the end of the stream, makes it stale.
- **Waits:** after a request goes out, the client waits for the socket
  before its first read, because the response cannot be there yet.
- **Retry:** when a reused connection fails before any byte of the
  response arrives, the client sends the request again on a new
  connection, for an idempotent method or when the send failed.

This module ports no code. The behavior follows RFC 9112 and RFC 9110
section 4.3.3 (the `https` scheme).

Differences from upstream: none; there is no upstream.
"""

from std.time import perf_counter_ns

from gql_http.client import ClientConfig, Response, ResponseSource
from gql_http.client import read_response
from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.socket import EAGAIN, EINPROGRESS, POLLOUT, IPv4Address, Sys
from gql_http.status import Method
from gql_http.url import Url
from gql_tls.context import TlsContext
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_tls.stream import IoWant, TlsStream, wait_for


@fieldwise_init
struct HttpsEndpoint(Copyable, Movable, Writable):
    """A resolved `https` URL: the address, the port, and the names."""

    var address: IPv4Address
    """The address of the server."""
    var port: Int
    """The port; 443 by default."""
    var host: String
    """The host name, for SNI and for verification."""
    var authority: String
    """The `Host` value: the host, and the port when it is not 443."""
    var target: String
    """The path and the query of the URL."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the URL of the endpoint, without the target.

        Args:
            writer: The destination.
        """
        writer.write("https://", self.authority)


struct _IdleTls(Movable):
    """A pooled connection."""

    var address: UInt32
    var port: Int
    var stream: TlsStream

    def __init__(out self, address: UInt32, port: Int, var stream: TlsStream):
        self.address = address
        self.port = port
        self.stream = stream^

    def into_stream(deinit self) -> TlsStream:
        return self.stream^


def _now_ns() -> Int:
    """Return a monotonic time in nanoseconds."""
    return Int(perf_counter_ns())


def _to_http(error: TlsError) -> HttpError:
    """Carry a TLS error through `read_response`."""
    var kind = error.kind.value if error.kind.value <= 7 else UInt8(5)
    return HttpError(ErrorKind(kind), error.message, error.errno)


struct HttpsClient(Movable, ResponseSource):
    """An HTTPS/1.1 client with a pool of keep-alive TLS connections."""

    var config: ClientConfig
    """The timeouts and limits."""
    var sys: Sys
    """The system calls; tests give one with faults."""
    var context: TlsContext
    """The client context: trust store, verification and ALPN."""
    var _idle: List[_IdleTls]
    var _stream: TlsStream
    var _out: List[UInt8]
    var _got: Int
    var _retry: Bool
    var _sent: Bool

    def __init__(
        out self, var context: TlsContext, config: ClientConfig = ClientConfig()
    ):
        """Make a client with an empty pool.

        Args:
            context: A client context. Its ALPN protocols must be
                `http/1.1` alone, or none.
            config: The timeouts and limits.
        """
        self._stream = TlsStream(context.openssl)
        self.context = context^
        self.config = config.copy()
        self.sys = Sys()
        self._idle = List[_IdleTls]()
        self._out = List[UInt8]()
        self._got = 0
        self._retry = False
        self._sent = False

    @staticmethod
    def system(
        config: ClientConfig = ClientConfig(),
    ) raises TlsError -> HttpsClient:
        """Make a client that trusts the system CA store.

        Args:
            config: The timeouts and limits.

        Returns:
            The client.

        Raises:
            TlsError: `LIBRARY` without OpenSSL 3; `CONFIG` when the
                system store does not load.
        """
        var protocols = List[String]()
        protocols.append("http/1.1")
        return HttpsClient(TlsContext.client(OpenSsl(), protocols^), config)

    def __deinit__(deinit self):
        """Close every pooled connection."""
        self.close_idle()

    def idle_connections(self) -> Int:
        """Return the count of connections in the pool.

        Returns:
            The count.
        """
        return len(self._idle)

    def close_idle(mut self):
        """Send `close_notify` on each pooled connection, and close it."""
        while len(self._idle) > 0:
            var idle = self._idle.pop()
            _ = idle.stream.shutdown()
            var fd = idle.stream.fd
            idle.stream = TlsStream(self.context.openssl)
            self.sys.close(fd)

    def endpoint(mut self, url: StringSlice) raises TlsError -> HttpsEndpoint:
        """Parse an `https` URL and resolve its host.

        Args:
            url: The URL, such as `https://localhost:4443/graphql`.

        Returns:
            The endpoint.

        Raises:
            TlsError: `PROTOCOL` for an invalid URL, `USAGE` for a scheme
                other than `https`, `RESOLVE` for an unknown host.
        """
        try:
            var parsed = Url.parse(url)
            if parsed.scheme != "https":
                raise HttpError(
                    ErrorKind.USAGE,
                    "only https URLs are supported: " + String(url),
                    0,
                )
            var address = self.sys.resolve(parsed.host)
            return HttpsEndpoint(
                address,
                parsed.port,
                parsed.host.copy(),
                parsed.authority(),
                parsed.target(),
            )
        except e:
            raise TlsError.from_http(e)

    def get(mut self, url: StringSlice) raises TlsError -> Response:
        """Send a `GET` request.

        Args:
            url: The URL.

        Returns:
            The response.

        Raises:
            TlsError: For an invalid URL, a failed connection or handshake,
                a timeout or an invalid response.
        """
        var endpoint = self.endpoint(url)
        var target = endpoint.target.copy()
        return self.send(endpoint, Method.GET, target, Headers(), List[UInt8]())

    def post(
        mut self, url: StringSlice, content_type: StringSlice, body: StringSlice
    ) raises TlsError -> Response:
        """Send a `POST` request with content.

        Args:
            url: The URL.
            content_type: The `Content-Type` value.
            body: The content.

        Returns:
            The response.

        Raises:
            TlsError: For an invalid URL or content type, a failed
                connection or handshake, a timeout or an invalid response.
        """
        var endpoint = self.endpoint(url)
        var headers = Headers()
        try:
            headers.add("Content-Type", content_type)
        except e:
            raise TlsError.from_http(e)
        var target = endpoint.target.copy()
        return self.send(
            endpoint, Method.POST, target, headers, body.as_bytes()
        )

    def send(
        mut self,
        endpoint: HttpsEndpoint,
        method: Method,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises TlsError -> Response:
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
            TlsError: `USAGE` for an `OTHER` method, an invalid target, or
                a framing field in `headers`; `CONNECT`, `HANDSHAKE`,
                `VERIFY`, `TIMEOUT`, `CLOSED`, `PROTOCOL`, `LIMIT` or `OS`
                when the exchange fails.
        """
        self._build(endpoint, method, target, headers, body)
        var deadline = _now_ns() + self.config.timeout_ms * 1_000_000
        if self._take_idle(endpoint):
            try:
                return self._exchange(endpoint, method, deadline, True)
            except e:
                if not self._retry:
                    raise e^
        self._connect(endpoint, deadline)
        return self._exchange(endpoint, method, deadline, False)

    def _build(
        mut self,
        endpoint: HttpsEndpoint,
        method: Method,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises TlsError:
        """Write the request into `_out`."""
        if method == Method.OTHER or not method.is_valid():
            raise TlsError(TlsErrorKind.USAGE, "invalid method", 0)
        var bytes = target.as_bytes()
        if len(bytes) == 0:
            raise TlsError(TlsErrorKind.USAGE, "empty request target", 0)
        var index = 0
        while index < len(bytes):
            if bytes[index] <= 32 or bytes[index] >= 127:
                raise TlsError(TlsErrorKind.USAGE, "invalid request target", 0)
            index += 1
        if (
            headers.find("content-length") >= 0
            or headers.find("transfer-encoding") >= 0
        ):
            raise TlsError(
                TlsErrorKind.USAGE, "the client writes the framing fields", 0
            )
        self._out.clear()
        self._out.extend(method.text().as_bytes())
        self._out.append(32)
        self._out.extend(bytes)
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

    def _take_idle(mut self, endpoint: HttpsEndpoint) -> Bool:
        """Make a live pooled connection to an endpoint the current one."""
        var index = len(self._idle) - 1
        while index >= 0:
            if (
                self._idle[index].address == endpoint.address.value
                and self._idle[index].port == endpoint.port
            ):
                var idle = self._idle.pop(index)
                # A quiet socket is a live connection. The end of the
                # stream comes with a FIN, so a peek sees it.
                var n = self.sys.peek(idle.stream.fd)
                if n != -EAGAIN:
                    var buffer = List[UInt8](length=256, fill=0)
                    try:
                        # A live connection has only session tickets.
                        n = idle.stream.read(buffer.unsafe_ptr(), len(buffer))
                    except:
                        n = 0
                if n < 0:
                    self._stream = idle^.into_stream()
                    return True
                var fd = idle.stream.fd
                idle.stream = TlsStream(self.context.openssl)
                self.sys.close(fd)
            index -= 1
        return False

    def _remaining_ms(self, deadline: Int) raises TlsError -> Int:
        """Return the time to the deadline, or raise `TIMEOUT`."""
        var remaining = (deadline - _now_ns() + 999_999) // 1_000_000
        if remaining <= 0:
            raise TlsError(TlsErrorKind.TIMEOUT, "the request timed out", 0)
        return remaining

    def _drop(mut self):
        """Close the current connection; it is always an open one."""
        var fd = self._stream.fd
        self._stream = TlsStream(self.context.openssl)
        self.sys.close(fd)

    def _connect(
        mut self, endpoint: HttpsEndpoint, deadline: Int
    ) raises TlsError:
        """Open a new connection, run the handshake, and make it current."""
        var fd = self.sys.socket()
        if fd < 0:
            raise TlsError.os("socket", -fd)
        _ = self.sys.set_no_delay(fd)
        var limit = min(
            deadline, _now_ns() + self.config.connect_timeout_ms * 1_000_000
        )
        var rc = self.sys.connect(fd, endpoint.address, endpoint.port)
        if rc == -EINPROGRESS:
            try:
                wait_for(self.sys, fd, IoWant.WRITE, self._remaining_ms(limit))
            except e:
                self.sys.close(fd)
                raise e^
            rc = -self.sys.socket_error(fd)
        if rc != 0:
            self.sys.close(fd)
            raise TlsError(
                TlsErrorKind.CONNECT,
                "cannot connect to "
                + String(endpoint)
                + ": errno "
                + String(-rc),
                -rc,
            )
        try:
            self._stream = TlsStream.connect(self.context, fd, endpoint.host)
        except e:
            self.sys.close(fd)
            raise e^
        try:
            while True:
                var want = self._stream.handshake()
                if want == IoWant.NOTHING:
                    break
                wait_for(self.sys, fd, want, self._remaining_ms(limit))
        except e:
            self._drop()
            raise e^

    def _exchange(
        mut self,
        endpoint: HttpsEndpoint,
        method: Method,
        deadline: Int,
        reused: Bool,
    ) raises TlsError -> Response:
        """Send `_out` on the current connection and read the response.

        It sets `_retry` before it raises: whether a new connection can
        send the request again.
        """
        self._retry = False
        try:
            self._send_all(deadline)
        except e:
            self._drop()
            self._retry = reused and e.kind != TlsErrorKind.TIMEOUT
            raise e^
        var response = Response()
        var keep: Bool
        self._got = 0
        self._sent = True
        var limits = self.config.limits
        try:
            keep = read_response(self, method, limits, deadline, response)
        except e:
            self._drop()
            self._retry = (
                reused
                and self._got == 0
                and e.kind == ErrorKind.CLOSED
                and method.is_idempotent()
            )
            raise TlsError.from_http(e)
        if keep and self.config.max_idle_per_host > 0:
            var stream = self._stream^
            self._stream = TlsStream(self.context.openssl)
            self._idle.append(
                _IdleTls(endpoint.address.value, endpoint.port, stream^)
            )
        else:
            self._drop()
        return response^

    def _send_all(mut self, deadline: Int) raises TlsError:
        """Encrypt and send every byte of `_out`."""
        var sent = 0
        var total = len(self._out)
        while sent < total:
            var n = self._stream.write(
                self._out.unsafe_ptr().unsafe_offset(sent), total - sent
            )
            if n < 0:
                wait_for(
                    self.sys,
                    self._stream.fd,
                    IoWant.from_code(n),
                    self._remaining_ms(deadline),
                )
                continue
            sent += n

    def read_more(
        mut self, mut data: List[UInt8], mut end: Int, deadline: Int
    ) raises HttpError -> Int:
        """Read more decrypted bytes of the response into `data` at `end`.

        `read_response` calls it.

        Args:
            data: The buffer; it grows when it has little room.
            end: The count of bytes in `data`; it grows by the result.
            deadline: The deadline, from `perf_counter_ns`.

        Returns:
            The count of bytes, or 0 at the end of the stream.

        Raises:
            HttpError: `TIMEOUT` at the deadline; `CLOSED` or `PROTOCOL`
                when the connection fails.
        """
        if len(data) - end < 4096:
            data.resize(max(len(data) * 2, end + 16384), 0)
        try:
            if self._sent:
                # The response comes after the request: wait for it first,
                # and save a read that finds nothing.
                self._sent = False
                wait_for(
                    self.sys,
                    self._stream.fd,
                    IoWant.READ,
                    self._remaining_ms(deadline),
                )
            while True:
                var n = self._stream.read(
                    data.unsafe_ptr().unsafe_offset(end), len(data) - end
                )
                if n >= 0:
                    end += n
                    self._got += n
                    return n
                wait_for(
                    self.sys,
                    self._stream.fd,
                    IoWant.from_code(n),
                    self._remaining_ms(deadline),
                )
        except e:
            raise _to_http(e)
