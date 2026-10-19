# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An HTTPS client that speaks HTTP/2 when ALPN chooses `h2`, and
HTTPS/1.1 when it does not.

`Https2Client` offers ALPN `h2` and then `http/1.1` in each handshake:

- **h2:** when the server chooses `h2`, the request goes on a
  `gql_http2` `ClientConnection` over a `TlsTransport`. The client keeps
  one HTTP/2 connection per address and port, for the next requests.
- **HTTPS/1.1:** when the server chooses `http/1.1`, or no protocol, the
  client gives the connection to its `HttpsClient` of `gql_tls`, and sends
  the request on it. The client remembers the endpoint: later requests to
  it go with HTTPS/1.1 at once.
- **Retry:** a reused HTTP/2 connection can fail before the response.
  When a `GOAWAY` refused the stream, the request goes again on a new
  connection. When the transport failed, only an idempotent method goes
  again.

`http1_response` turns a `Response` into a `gql_http.client.Response`, the
type of the clients of `gql_http`, `gql_tls` and `gql_http3`.

This module ports no code. The behavior follows RFC 9113 section 3.2,
RFC 7301 and RFC 9110 section 9.2.2.

Differences from upstream: none; there is no upstream.
"""

from std.time import perf_counter_ns

from gql_http.client import ClientConfig, ResponseSource, read_response
from gql_http.client import Response as HttpResponse
from gql_http.error import HttpError
from gql_http.headers import Headers
from gql_http.scan import lower
from gql_http.socket import Sys
from gql_http.status import Method
from gql_http2.client import ClientConnection, Protocol, Response, http_error
from gql_http2.connection import Config
from gql_http2.error import H2Error, H2ErrorKind
from gql_tls.client import HttpsClient, HttpsEndpoint, open_tls
from gql_tls.context import TlsContext
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_https2.server import H2
from gql_https2.transport import TlsTransport


def _now_ns() -> Int:
    """Return a monotonic time in nanoseconds."""
    return Int(perf_counter_ns())


def tls_error(error: H2Error) -> TlsError:
    """Map an HTTP/2 error to an error of the TLS clients.

    Args:
        error: The HTTP/2 error.

    Returns:
        `CLOSED` for `IO`, `TIMEOUT` for `TIMEOUT`, `USAGE` for `USAGE`,
        and `PROTOCOL` for the others, as `gql_http2.client.http_error`
        maps them.
    """
    return TlsError.from_http(http_error(error))


struct _Bytes(ResponseSource):
    """A whole response in memory, for `read_response`."""

    var data: List[UInt8]

    def __init__(out self, var data: List[UInt8]):
        self.data = data^

    def read_more(
        mut self, mut data: List[UInt8], mut end: Int, deadline: Int
    ) raises HttpError -> Int:
        """Give the whole response, then the end of the stream."""
        var size = len(self.data)
        data.resize(end, 0)
        data.extend(Span(self.data))
        end += size
        self.data.clear()
        return size


def _named(name: StringSlice, lower_name: StaticString) -> Bool:
    """Return True when a field name is a lowercase name, in any case."""
    var have = name.as_bytes()
    var want = lower_name.as_bytes()
    if len(have) != len(want):
        return False
    var index = 0
    while index < len(have):
        if lower(have[index]) != want[index]:
            return False
        index += 1
    return True


def http1_response(
    response: Response, method: Method, config: ClientConfig = ClientConfig()
) raises TlsError -> HttpResponse:
    """Copy a `Response` into a `gql_http.client.Response`.

    The status and the fields stay. A response without `content-length`
    gets one with the length of its content.

    Args:
        response: The response.
        method: The method of the request; a `HEAD` response has no
            content.
        config: The size limits of the response.

    Returns:
        The response, in the type of the `gql_http` client.

    Raises:
        TlsError: `PROTOCOL` when a field cannot be in HTTP/1.1; `LIMIT`
            when the response is over the limits.
    """
    var out = List[UInt8]()
    out.extend(StaticString("HTTP/1.1 ").as_bytes())
    out.extend(String(response.status.code).as_bytes())
    out.extend(StaticString(" \r\n").as_bytes())
    var length = False
    var index = 0
    while index < response.header_count():
        var name = response.header_name(index)
        if _named(name, "transfer-encoding"):
            # The content is decoded already.
            index += 1
            continue
        length = length or _named(name, "content-length")
        out.extend(name.as_bytes())
        out.extend(StaticString(": ").as_bytes())
        out.extend(response.header_value(index).as_bytes())
        out.extend(StaticString("\r\n").as_bytes())
        index += 1
    if not length:
        out.extend(StaticString("content-length: ").as_bytes())
        out.extend(String(len(response.data)).as_bytes())
        out.extend(StaticString("\r\n").as_bytes())
    out.extend(StaticString("\r\n").as_bytes())
    out.extend(Span(response.data))
    var source = _Bytes(out^)
    var result = HttpResponse()
    try:
        _ = read_response(source, method, config.limits, 0, result)
    except e:
        raise TlsError.from_http(e)
    return result^


def _from_http1(response: HttpResponse) -> Response:
    """Copy a `gql_http` response into a `Response` of HTTP/1.1."""
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


struct _Peer(Movable):
    """An HTTP/2 connection to one address and port."""

    var address: UInt32
    var port: Int
    var connection: ClientConnection[TlsTransport]

    def __init__(
        out self,
        address: UInt32,
        port: Int,
        var connection: ClientConnection[TlsTransport],
    ):
        self.address = address
        self.port = port
        self.connection = connection^


@fieldwise_init
struct _Known(ImplicitlyCopyable):
    """An address and port whose server did not choose `h2`."""

    var address: UInt32
    var port: Int


struct Https2Client(Movable):
    """An HTTPS client: HTTP/2 when ALPN chooses `h2`, else HTTPS/1.1."""

    var config: ClientConfig
    """The timeouts and limits of every request."""
    var h2: Config
    """The limits of each HTTP/2 connection."""
    var sys: Sys
    """The system calls; tests give one with faults."""
    var context: TlsContext
    """The context of the handshakes: ALPN `h2`, then `http/1.1`."""
    var http1: HttpsClient
    """The HTTPS/1.1 client, with a context that offers `http/1.1` only."""
    var _peers: List[_Peer]
    var _known: List[_Known]

    def __init__(
        out self,
        var context: TlsContext,
        var http1_context: TlsContext,
        config: ClientConfig = ClientConfig(),
        h2: Config = Config(),
    ):
        """Make a client with no connection.

        Args:
            context: A client context that offers `h2` and `http/1.1`.
            http1_context: A client context that offers `http/1.1` only,
                for the new connections of the HTTPS/1.1 client.
            config: The timeouts and limits.
            h2: The limits of each HTTP/2 connection.
        """
        self.config = config.copy()
        self.h2 = h2.copy()
        self.sys = Sys()
        self.context = context^
        self.http1 = HttpsClient(http1_context^, config)
        self._peers = List[_Peer]()
        self._known = List[_Known]()

    @staticmethod
    def create(
        openssl: OpenSsl,
        ca_file: String = "",
        verify: Bool = True,
        offer_h2: Bool = True,
        config: ClientConfig = ClientConfig(),
        h2: Config = Config(),
    ) raises TlsError -> Https2Client:
        """Make a client and its two contexts.

        Args:
            openssl: The library.
            ca_file: A PEM file of trusted CA certificates; empty for the
                system CA store.
            verify: Whether to verify servers. Turn it off only for tests.
            offer_h2: Whether the handshakes offer `h2`. Without it, the
                client speaks HTTPS/1.1 only.
            config: The timeouts and limits.
            h2: The limits of each HTTP/2 connection.

        Returns:
            The client.

        Raises:
            TlsError: `CONFIG` when the trust store does not load.
        """
        var protocols = List[String]()
        if offer_h2:
            protocols.append(H2)
        protocols.append("http/1.1")
        var context = TlsContext.client(
            openssl.copy(), protocols^, ca_file, verify
        )
        var single = List[String]()
        single.append("http/1.1")
        var http1_context = TlsContext.client(
            openssl.copy(), single^, ca_file, verify
        )
        return Https2Client(context^, http1_context^, config, h2)

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

    def speaks_http1(self, endpoint: HttpsEndpoint) -> Bool:
        """Return True when the server of an endpoint did not choose `h2`.

        Args:
            endpoint: The endpoint.

        Returns:
            Whether its requests go with HTTPS/1.1.
        """
        for ref known in self._known:
            if (
                known.address == endpoint.address.value
                and known.port == endpoint.port
            ):
                return True
        return False

    def endpoint(mut self, url: StringSlice) raises TlsError -> HttpsEndpoint:
        """Parse an `https` URL and resolve its host.

        Args:
            url: The URL, such as `https://localhost:4443/graphql`.

        Returns:
            The endpoint.

        Raises:
            TlsError: As `HttpsClient.endpoint` raises.
        """
        return self.http1.endpoint(url)

    def get(mut self, url: StringSlice) raises TlsError -> Response:
        """Send a `GET` request.

        Args:
            url: The URL.

        Returns:
            The response.

        Raises:
            TlsError: The errors of `endpoint` and `send`.
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
            TlsError: The errors of `endpoint` and `send`, and `USAGE` for
                an invalid content type.
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

        Args:
            endpoint: Where to send it.
            method: The method; not `OTHER`.
            target: The request target, such as `/graphql?x=1`.
            headers: The other header fields.
            body: The content; empty for none.

        Returns:
            The response. `protocol` says whether HTTP/2 carried it.

        Raises:
            TlsError: `USAGE` for an invalid method; the errors of the
                connect, the handshake and the exchange.
        """
        if method == Method.OTHER or not method.is_valid():
            raise TlsError(TlsErrorKind.USAGE, "invalid method", 0)
        if self.speaks_http1(endpoint):
            return _from_http1(
                self.http1.send(endpoint, method, target, headers, body)
            )
        var index = self._find(endpoint)
        if index >= 0:
            try:
                return self._exchange(
                    index, endpoint, method, target, headers, body
                )
            except e:
                self._drop(index)
                var again = e.kind == H2ErrorKind.REMOTE_GOAWAY or (
                    e.kind == H2ErrorKind.IO and method.is_idempotent()
                )
                if not again:
                    raise tls_error(e)
        return self._fresh(endpoint, method, target, headers, body)

    def _fresh(
        mut self,
        endpoint: HttpsEndpoint,
        method: Method,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises TlsError -> Response:
        """Send a request on a new connection, with the protocol that ALPN
        chooses."""
        var deadline = _now_ns() + self.config.timeout_ms * 1_000_000
        var stream = open_tls(
            self.sys,
            self.context,
            endpoint,
            deadline,
            self.config.connect_timeout_ms,
        )
        if stream.protocol != H2:
            self._known.append(_Known(endpoint.address.value, endpoint.port))
            self.http1.adopt(endpoint, stream^)
            return _from_http1(
                self.http1.send(endpoint, method, target, headers, body)
            )
        var transport = TlsTransport(stream^, self.sys.copy())
        self._peers.append(
            _Peer(
                endpoint.address.value,
                endpoint.port,
                ClientConnection[TlsTransport](transport^, self.h2),
            )
        )
        var index = len(self._peers) - 1
        try:
            return self._exchange(
                index, endpoint, method, target, headers, body
            )
        except e:
            self._drop(index)
            raise tls_error(e)

    def _exchange(
        mut self,
        index: Int,
        endpoint: HttpsEndpoint,
        method: Method,
        target: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises H2Error -> Response:
        """Send a request on the connection of a peer."""
        return self._peers[index].connection.send(
            method.text(),
            "https",
            endpoint.authority,
            target,
            headers,
            body,
            self.config.timeout_ms,
        )

    def _find(mut self, endpoint: HttpsEndpoint) -> Int:
        """Return the peer of an endpoint that can take a request, or -1.
        A connection that cannot is closed."""
        var index = 0
        while index < len(self._peers):
            if (
                self._peers[index].address == endpoint.address.value
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
