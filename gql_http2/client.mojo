# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTP/2 client: one connection over any `Transport`, and a `Client`
that tries h2c with prior knowledge and falls back to HTTP/1.1.

A `ClientConnection` sends requests on one HTTP/2 connection, one stream
each, and keeps the connection for the next request. A TLS layer can give
it a transport after ALPN chose `h2`.

`Client` keeps one HTTP/2 connection per address and port. When
`ClientConfig.prior_knowledge` is on, it opens h2c. A server that does not
answer the preface with `SETTINGS` speaks HTTP/1.1: the client remembers
that, and sends the request, and later ones, with the gql_http client.

This module ports the request parts of h2 v0.4.20 `src/client.rs`
(`handshake`, `SendRequest`, `ResponseFuture`).

Differences from upstream: h2 sends a request and returns a future of its
response. Here `send` waits for the whole response, as the gql_http
client does, with one deadline. The fallback to HTTP/1.1 is not in h2;
hyper does it with ALPN, which h2c does not have.
"""

from std.time import perf_counter_ns

from gql_http.client import Client as HttpClient
from gql_http.client import ClientConfig as HttpClientConfig
from gql_http.client import Endpoint
from gql_http.client import Response as HttpResponse
from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.scan import lower
from gql_http.socket import (
    EAGAIN,
    EINPROGRESS,
    EINTR,
    IPv4Address,
    POLLIN,
    POLLOUT,
    Sys,
)
from gql_http.status import Method, Status

from gql_http2.connection import Config, Connection, EventKind, Role
from gql_http2.error import H2Error, H2ErrorKind, Reason
from gql_http2.hpack import HeaderList
from gql_http2.session import SocketTransport, Transport, write_all


@fieldwise_init
struct Protocol(Equatable, ImplicitlyCopyable, Writable):
    """The protocol of a response."""

    var value: UInt8
    """The protocol's index; see `is_valid`."""

    comptime HTTP_1_1 = Protocol(0)
    """HTTP/1.1, or 1.0, through gql_http."""
    comptime HTTP_2 = Protocol(1)
    """HTTP/2."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the protocols.

        Returns:
            Whether the value is 0 or 1.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write `HTTP/1.1` or `HTTP/2`.

        Args:
            writer: The destination.
        """
        if self == Protocol.HTTP_1_1:
            writer.write("HTTP/1.1")
        elif self == Protocol.HTTP_2:
            writer.write("HTTP/2")
        else:
            writer.write("invalid")


struct Response(Movable):
    """A whole response: status, fields and content."""

    var status: Status
    """The status code."""
    var protocol: Protocol
    """The protocol that carried it."""
    var headers: HeaderList
    """The fields, without pseudo-header fields."""
    var data: List[UInt8]
    """The content."""

    def __init__(out self):
        """Make an empty 200 response."""
        self.status = Status.OK
        self.protocol = Protocol.HTTP_2
        self.headers = HeaderList()
        self.data = List[UInt8]()

    def header_count(self) -> Int:
        """Return the number of fields.

        Returns:
            The count.
        """
        return self.headers.count()

    def header_name(
        self, index: Int
    ) -> StringSlice[origin_of(self.headers.data)]:
        """Return the name of a field.

        Args:
            index: The field's index, from 0 to `header_count() - 1`.

        Returns:
            The name; lowercase for HTTP/2.
        """
        return StringSlice(unsafe_from_utf8=self.headers.name(index))

    def header_value(
        self, index: Int
    ) -> StringSlice[origin_of(self.headers.data)]:
        """Return the value of a field.

        Args:
            index: The field's index, from 0 to `header_count() - 1`.

        Returns:
            The value.
        """
        return StringSlice(unsafe_from_utf8=self.headers.value(index))

    def header(
        self, name: StringSlice
    ) -> Optional[StringSlice[origin_of(self.headers.data)]]:
        """Return the value of the first field with a name, case folded.

        Args:
            name: The field name, in any case.

        Returns:
            The value, or None when no field has the name.
        """
        var wanted = name.as_bytes()
        var index = 0
        while index < self.headers.count():
            var have = self.headers.name(index)
            if len(have) == len(wanted):
                var same = True
                var at = 0
                while at < len(have):
                    if lower(have[at]) != lower(wanted[at]):
                        same = False
                        break
                    at += 1
                if same:
                    return self.header_value(index)
            index += 1
        return None

    def body(self) -> Span[UInt8, origin_of(self.data)]:
        """Return the content.

        Returns:
            The bytes.
        """
        return Span(self.data)

    def text(self) raises HttpError -> String:
        """Return the content as text.

        Returns:
            The content.

        Raises:
            HttpError: `PROTOCOL` when the content is not UTF-8.
        """
        try:
            return String(from_utf8=Span(self.data))
        except:
            raise HttpError(ErrorKind.PROTOCOL, "the content is not UTF-8", 0)


def _now_ns() -> Int:
    """Return a monotonic time in nanoseconds."""
    return Int(perf_counter_ns())


def _is_connection_field(name: Span[UInt8, _]) -> Bool:
    """Return True for a field that HTTP/2 does not allow in a request."""
    var text = StringSlice(unsafe_from_utf8=name)
    return (
        text == "connection"
        or text == "keep-alive"
        or text == "proxy-connection"
        or text == "transfer-encoding"
        or text == "upgrade"
        or text == "host"
        or text == "content-length"
    )


struct ClientConnection[T: Transport](Movable):
    """The client end of one HTTP/2 connection over a transport.

    Parameters:
        T: The type of the transport.
    """

    var transport: Self.T
    """The transport; the connection closes it."""
    var conn: Connection
    """The connection state."""
    var sys: Sys
    """The `poll` of the waits."""
    var _fields: HeaderList
    var _name: List[UInt8]
    var _buffer: List[UInt8]

    def __init__(out self, var transport: Self.T, config: Config = Config()):
        """Start a connection: the preface and `SETTINGS` go out with the
        first request.

        Args:
            transport: The transport, connected.
            config: The limits of this endpoint.
        """
        self.transport = transport^
        self.conn = Connection(Role.CLIENT, config)
        self.conn.start()
        self.sys = Sys()
        self._fields = HeaderList()
        self._name = List[UInt8]()
        self._buffer = List[UInt8](length=65536, fill=0)

    def usable(self) -> Bool:
        """Return True when the connection can take a new request.

        Returns:
            Whether it has not ended and the server sent no `GOAWAY`.
        """
        return not self.conn.closed and not self.conn.goaway_received

    def close(mut self):
        """Send a final `GOAWAY` when the transport takes it, and close."""
        if not self.conn.closed:
            self.conn.begin_shutdown()
            try:
                write_all(self.transport, self.conn.out, 100)
            except:
                pass
        self.transport.close()

    def send(
        mut self,
        method: StringSlice,
        scheme: StringSlice,
        authority: StringSlice,
        path: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
        timeout_ms: Int,
    ) raises H2Error -> Response:
        """Send a request on a new stream, and wait for its whole response.

        The client writes the pseudo-header fields and `content-length`.
        It drops the fields that HTTP/2 does not allow, such as
        `connection`, and `host`, which `:authority` replaces.

        Args:
            method: The method, such as `POST`.
            scheme: `http` or `https`.
            authority: The host and port, such as `localhost:4000`.
            path: The path and query, such as `/graphql`.
            headers: The other fields; names in any case.
            body: The content; empty for none.
            timeout_ms: The deadline of the whole exchange.

        Returns:
            The response.

        Raises:
            H2Error: `REMOTE_RESET` or `STREAM` when the stream was reset;
                `REMOTE_GOAWAY` when the server did not process it, so the
                request can go again; `CONNECTION` for a connection error;
                `IO` when the transport failed or closed; `TIMEOUT` at the
                deadline; `USAGE` when the server allows no more streams.
        """
        var deadline = _now_ns() + timeout_ms * 1_000_000
        var id = self.conn.open_stream()
        self._fields.clear()
        self._fields.add_text(":method", method)
        self._fields.add_text(":scheme", scheme)
        self._fields.add_text(":authority", authority)
        self._fields.add_text(":path", path)
        var index = 0
        while index < len(headers):
            var name = headers.name(index).as_bytes()
            self._name.clear()
            var at = 0
            while at < len(name):
                self._name.append(lower(name[at]))
                at += 1
            if not _is_connection_field(Span(self._name)):
                self._fields.add(
                    Span(self._name), headers.value(index).as_bytes()
                )
            index += 1
        var empty = len(body) == 0
        if not empty:
            self._fields.add_text("content-length", String(len(body)))
        self.conn.send_headers(id, self._fields, empty)
        if not empty:
            self.conn.send_data(id, body, True)
        while True:
            write_all(self.transport, self.conn.out, timeout_ms)
            var found = self._outcome(id)
            if found:
                return found.take()
            if self.conn.closed:
                # A connection error is the only way to end it here.
                raise self.conn.error.value().copy()
            var n = self.transport.read(
                Pointer[UInt8, MutUntrackedOrigin](
                    unsafe_from_address=Int(self._buffer.unsafe_ptr())
                ),
                len(self._buffer),
            )
            if n == -EAGAIN or n == -EINTR:
                var left = (deadline - _now_ns()) // 1_000_000
                if left <= 0:
                    self.conn.reset_stream(id, Reason.CANCEL)
                    raise H2Error(
                        H2ErrorKind.TIMEOUT,
                        Reason.CANCEL,
                        id,
                        "the response did not arrive in time",
                    )
                _ = self.sys.poll(self.transport.fd(), POLLIN, left)
                continue
            if n == 0:
                self.conn.closed = True
                raise H2Error.io("the server closed the connection")
            if n < 0:
                self.conn.closed = True
                raise H2Error.io("read failed: errno " + String(-n))
            self.conn.receive(Span(self._buffer)[:n])

    def _outcome(mut self, id: Int) raises H2Error -> Optional[Response]:
        """Return the response of a stream when it is whole, raise its reset,
        and clear the events."""
        if len(self.conn.events) == 0:
            return None
        # One stream is open at a time, so each event is of this stream.
        var event = self.conn.events[0].copy()
        self.conn.events.clear()
        if event.kind == EventKind.MESSAGE:
            return self._take(id)
        var error = event.error.copy()
        raise error^

    def _take(mut self, id: Int) -> Response:
        """Move the message of a stream into a `Response`, and free it."""
        var slot = self.conn.find(id)
        var response = Response()
        response.status = Status(self.conn.streams[slot].status)
        ref fields = self.conn.streams[slot].headers
        var index = 0
        while index < fields.count():
            var name = fields.name(index)
            if name[0] != 58:
                response.headers.add(name, fields.value(index))
            index += 1
        swap(response.data, self.conn.streams[slot].body)
        self.conn.release(id)
        return response^


struct ClientConfig(Copyable, Movable):
    """The configuration of a `Client`."""

    var http: HttpClientConfig
    """The timeouts and limits, also of the HTTP/1.1 client."""
    var h2: Config
    """The limits of each HTTP/2 connection."""
    var prior_knowledge: Bool
    """Whether the client tries h2c with prior knowledge first."""
    var fallback: Bool
    """Whether a server that does not speak HTTP/2 gets HTTP/1.1."""

    def __init__(out self):
        """Make the defaults: h2c first, HTTP/1.1 as the fallback."""
        self.http = HttpClientConfig()
        self.h2 = Config()
        self.prior_knowledge = True
        self.fallback = True


struct _Peer(Movable):
    """An HTTP/2 connection to one address and port."""

    var address: IPv4Address
    var port: Int
    var connection: ClientConnection[SocketTransport]

    def __init__(
        out self,
        address: IPv4Address,
        port: Int,
        var connection: ClientConnection[SocketTransport],
    ):
        self.address = address
        self.port = port
        self.connection = connection^


@fieldwise_init
struct _Known(ImplicitlyCopyable):
    """An address and port that speaks HTTP/1.1 only."""

    var address: IPv4Address
    var port: Int


def http_error(error: H2Error) -> HttpError:
    """Map an HTTP/2 error to an error of the gql_http client.

    Args:
        error: The HTTP/2 error.

    Returns:
        `CLOSED` for `IO`, `TIMEOUT` for `TIMEOUT`, `USAGE` for `USAGE`,
        and `PROTOCOL` for the others, with the text of the error.
    """
    var kind = ErrorKind.PROTOCOL
    if error.kind == H2ErrorKind.IO:
        kind = ErrorKind.CLOSED
    elif error.kind == H2ErrorKind.TIMEOUT:
        kind = ErrorKind.TIMEOUT
    elif error.kind == H2ErrorKind.USAGE:
        kind = ErrorKind.USAGE
    return HttpError(kind, String(error), 0)


def _from_http1(var response: HttpResponse) -> Response:
    """Copy a gql_http response into a `Response`."""
    var out = Response()
    out.status = response.status
    out.protocol = Protocol.HTTP_1_1
    var index = 0
    while index < response.header_count():
        out.headers.add(
            response.header_name(index).as_bytes(),
            response.header_value(index).as_bytes(),
        )
        index += 1
    out.data.extend(response.body())
    return out^


struct Client(Movable):
    """An HTTP client that speaks h2c with prior knowledge, and HTTP/1.1 to
    a server that does not speak HTTP/2."""

    var config: ClientConfig
    """The configuration."""
    var sys: Sys
    """The system calls; tests give one with faults."""
    var http1: HttpClient
    """The HTTP/1.1 client of the fallback."""
    var _peers: List[_Peer]
    var _known: List[_Known]

    def __init__(out self, config: ClientConfig = ClientConfig()):
        """Make a client with no connection.

        Args:
            config: The configuration.
        """
        self.config = config.copy()
        self.sys = Sys()
        self.http1 = HttpClient(config.http)
        self._peers = List[_Peer]()
        self._known = List[_Known]()

    def __deinit__(deinit self):
        """Close every connection."""
        self.close()

    def close(mut self):
        """Close every connection of both protocols."""
        while len(self._peers) > 0:
            var peer = self._peers.pop()
            peer.connection.close()
        self.http1.close_idle()

    def connections(self) -> Int:
        """Return the count of HTTP/2 connections that the client keeps.

        Returns:
            The count.
        """
        return len(self._peers)

    def speaks_http1(self, endpoint: Endpoint) -> Bool:
        """Return True when the client knows that an endpoint has no
        HTTP/2.

        Args:
            endpoint: The endpoint.

        Returns:
            Whether its requests go with HTTP/1.1.
        """
        var index = 0
        while index < len(self._known):
            if (
                self._known[index].address == endpoint.address
                and self._known[index].port == endpoint.port
            ):
                return True
            index += 1
        return False

    def endpoint(mut self, url: StringSlice) raises HttpError -> Endpoint:
        """Parse an `http` URL and resolve its host.

        Args:
            url: The URL, such as `http://localhost:4001/graphql`.

        Returns:
            The endpoint.

        Raises:
            HttpError: As `gql_http.client.Client.endpoint` raises.
        """
        return self.http1.endpoint(url)

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

        With `prior_knowledge`, the request goes on an h2c connection to
        the endpoint, which the client keeps for the next request. A
        server that does not answer the preface with `SETTINGS` gets the
        request with HTTP/1.1, and so does every later request to it, when
        `fallback` is on. A reused connection that the server ended before
        it processed the request gets the request again on a new one.

        Args:
            endpoint: Where to send it.
            method: The method; not `OTHER`.
            target: The request target, such as `/graphql?x=1`.
            headers: The other header fields.
            body: The content; empty for none.

        Returns:
            The response.

        Raises:
            HttpError: `USAGE` for an `OTHER` method; `CONNECT`, `TIMEOUT`,
                `CLOSED`, `PROTOCOL`, `LIMIT` or `OS` when the exchange
                fails.
        """
        if method == Method.OTHER:
            raise HttpError(ErrorKind.USAGE, "the method has no name", 0)
        if not self.config.prior_knowledge or self.speaks_http1(endpoint):
            return _from_http1(
                self.http1.send(endpoint, method, target, headers, body)
            )
        var index = self._find(endpoint)
        var reused = index >= 0
        if index < 0:
            index = self._connect(endpoint)
        try:
            return self._exchange(
                index, endpoint, method, target, headers, body
            )
        except e:
            var spoke = self._peers[index].connection.conn.got_settings()
            self._drop(index)
            # A reused connection has read the server's SETTINGS.
            if not spoke and self.config.fallback:
                self._known.append(_Known(endpoint.address, endpoint.port))
                return _from_http1(
                    self.http1.send(endpoint, method, target, headers, body)
                )
            var again = e.kind == H2ErrorKind.REMOTE_GOAWAY or (
                e.kind == H2ErrorKind.IO and method.is_idempotent()
            )
            if not (reused and again):
                raise http_error(e)
        index = self._connect(endpoint)
        try:
            return self._exchange(
                index, endpoint, method, target, headers, body
            )
        except e:
            self._drop(index)
            raise http_error(e)

    def _exchange(
        mut self,
        index: Int,
        endpoint: Endpoint,
        method: Method,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises H2Error -> Response:
        """Send a request on the connection of a peer."""
        return self._peers[index].connection.send(
            method.text(),
            "http",
            endpoint.authority,
            target,
            headers,
            body,
            self.config.http.timeout_ms,
        )

    def _find(mut self, endpoint: Endpoint) -> Int:
        """Return the peer of an endpoint that can take a request, or -1.
        A connection that cannot is closed."""
        var index = 0
        while index < len(self._peers):
            if (
                self._peers[index].address == endpoint.address
                and self._peers[index].port == endpoint.port
            ):
                if self._peers[index].connection.usable():
                    return index
                self._drop(index)
                continue
            index += 1
        return -1

    def _drop(mut self, index: Int):
        """Close the connection of a peer and forget it."""
        var peer = self._peers.pop(index)
        peer.connection.close()

    def _connect(mut self, endpoint: Endpoint) raises HttpError -> Int:
        """Open an h2c connection to an endpoint, and return its peer."""
        var fd = self.sys.socket()
        if fd < 0:
            raise HttpError.os("socket", -fd)
        _ = self.sys.set_no_delay(fd)
        var rc = self.sys.connect(fd, endpoint.address, endpoint.port)
        if rc == -EINPROGRESS:
            var ready = self.sys.poll(
                fd, POLLOUT, self.config.http.connect_timeout_ms
            )
            if ready <= 0:
                self.sys.close(fd)
                raise HttpError(
                    ErrorKind.TIMEOUT,
                    "connect to " + String(endpoint) + " timed out",
                    0,
                )
            rc = -abs(self.sys.socket_error(fd))
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
        var transport = SocketTransport(fd, self.sys.copy())
        self._peers.append(
            _Peer(
                endpoint.address,
                endpoint.port,
                ClientConnection[SocketTransport](transport^, self.config.h2),
            )
        )
        return len(self._peers) - 1
