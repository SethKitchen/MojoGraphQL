# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A client that uses the best protocol that the path to a server allows.

`FallbackClient` sends each request with the first protocol that works:

1. HTTP/3 over QUIC, for an `https` URL, when `FallbackConfig.enable_h3`
   is set or the origin announced `h3` in an `Alt-Svc` field. The QUIC
   handshake has the short limit `h3_timeout_ms`, because a network that
   blocks UDP drops the packets silently.
2. HTTP/2 over TLS, for an `https` URL: the TLS handshake offers ALPN
   `h2` and then `http/1.1`, when `enable_h2` is set.
3. HTTPS/1.1 over TLS, on the same connection, when the server does not
   choose `h2`. `gql_https2` remembers the endpoint.
4. h2c with prior knowledge, for an `http` URL, when `enable_h2c` is set.
5. Plain HTTP/1.1 over TCP, for an `http` URL, and for a server that does
   not answer the h2c preface.

When HTTP/3 fails before a response, the client forgets the `Alt-Svc`
entry, does not try HTTP/3 for that origin for `h3_retry_after_s`, and
sends the request again over TCP. A response over TCP with an `Alt-Svc`
field adds the origin to the cache, so later requests can upgrade.

The client opens OpenSSL only for the first `https` request, so a program
that sends only `http` requests does not need it.

This module ports no code. The behavior follows RFC 7838, RFC 9114
section 3.1 and RFC 9110 section 4.3.

Differences from upstream: none; there is no upstream.
"""

from std.time import perf_counter_ns

from gql_http.client import Client, ClientConfig, Response
from gql_http.headers import Headers
from gql_http.status import Method
from gql_http.url import Url
from gql_http2.client import Client as H2cClient
from gql_http2.client import ClientConfig as H2cConfig
from gql_http2.client import Protocol as H2Version
from gql_http2.client import Response as H2Response
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_https2.client import Https2Client, http1_response
from gql_http3.alt_svc import AltSvcCache
from gql_http3.client import H3Client
from gql_http3.quic import Quic, QuicContext


@fieldwise_init
struct Protocol(Equatable, ImplicitlyCopyable, Writable):
    """The protocol of a response, as a type and not a bare integer."""

    var value: UInt8
    """The protocol's index; see `is_valid`."""

    comptime NONE = Protocol(0)
    """No request yet."""
    comptime HTTP1 = Protocol(1)
    """HTTP/1.1 over TCP."""
    comptime HTTPS1 = Protocol(2)
    """HTTP/1.1 over TLS."""
    comptime HTTP3 = Protocol(3)
    """HTTP/3 over QUIC."""
    comptime HTTPS2 = Protocol(4)
    """HTTP/2 over TLS, after ALPN chose `h2`."""
    comptime H2C = Protocol(5)
    """HTTP/2 over TCP with prior knowledge."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the protocols.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 5

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the protocol.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 6] = [
            "none",
            "http/1.1",
            "https/1.1",
            "h3",
            "h2",
            "h2c",
        ]
        writer.write(materialize[names]()[Int(min(self.value, 5))])


@fieldwise_init
struct FallbackConfig(Copyable, Movable):
    """When the client tries HTTP/3, and the settings of every client."""

    var client: ClientConfig
    """The timeouts and limits of every request."""
    var enable_h3: Bool
    """Whether to try HTTP/3 on the port of the URL without `Alt-Svc`."""
    var h3_timeout_ms: Int
    """The longest QUIC handshake before the client uses TCP."""
    var h3_retry_after_s: Int
    """How long the client uses TCP after HTTP/3 failed for an origin."""
    var ca_file: String
    """A PEM file of trusted CA certificates; empty for the system store."""
    var verify: Bool
    """Whether to verify servers. Turn it off only for tests."""
    var enable_h2: Bool
    """Whether the TLS handshake offers ALPN `h2` before `http/1.1`."""
    var enable_h2c: Bool
    """Whether an `http` URL gets h2c with prior knowledge first."""

    def __init__(out self):
        """Make the default: HTTP/3 only after `Alt-Svc`, 300 ms to try,
        `h2` over TLS, and no h2c."""
        self.client = ClientConfig()
        self.enable_h3 = False
        self.h3_timeout_ms = 300
        self.h3_retry_after_s = 300
        self.ca_file = String()
        self.verify = True
        self.enable_h2 = True
        self.enable_h2c = False


@fieldwise_init
struct _Broken(Copyable, Movable):
    var origin: String
    var until: Int


def _now_s() -> Int:
    """Return a monotonic time in seconds."""
    return Int(perf_counter_ns() // 1_000_000_000)


struct FallbackClient(Movable):
    """A client that tries HTTP/3, then HTTP/2 or HTTPS/1.1 over TLS, then
    h2c or plain HTTP/1.1."""

    var config: FallbackConfig
    """When to try HTTP/3, and the settings of every client."""
    var alt_svc: AltSvcCache
    """The HTTP/3 alternatives that servers announced."""
    var protocol: Protocol
    """The protocol of the last response."""
    var http: Client
    """The plain HTTP/1.1 client."""
    var _https: List[Https2Client]
    var _h2c: List[H2cClient]
    var _h3: List[H3Client]
    var _broken: List[_Broken]

    def __init__(out self, config: FallbackConfig = FallbackConfig()):
        """Make a client. OpenSSL loads at the first `https` request.

        Args:
            config: When to try HTTP/3, and the settings of every client.
        """
        self.config = config.copy()
        self.alt_svc = AltSvcCache()
        self.protocol = Protocol.NONE
        self.http = Client(config.client)
        self._https = List[Https2Client]()
        self._h2c = List[H2cClient]()
        self._h3 = List[H3Client]()
        self._broken = List[_Broken]()

    def get(mut self, url: StringSlice) raises TlsError -> Response:
        """Send a `GET` request.

        Args:
            url: The URL.

        Returns:
            The response.

        Raises:
            TlsError: The errors of `send`.
        """
        return self.send(Method.GET, url, Headers(), List[UInt8]())

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
            TlsError: The errors of `send`, and `USAGE` for an invalid
                content type.
        """
        var headers = Headers()
        try:
            headers.add("Content-Type", content_type)
        except e:
            raise TlsError.from_http(e)
        return self.send(Method.POST, url, headers, body.as_bytes())

    def _broken_now(self, origin: String, now: Int) -> Bool:
        """Return True while HTTP/3 rests after a failure for an origin."""
        var index = 0
        while index < len(self._broken):
            if self._broken[index].origin == origin:
                return self._broken[index].until > now
            index += 1
        return False

    def _mark_broken(mut self, origin: String, now: Int):
        """Rest HTTP/3 for an origin, and forget its `Alt-Svc` entry."""
        self.alt_svc.forget(origin)
        var index = 0
        while index < len(self._broken):
            if self._broken[index].origin == origin:
                _ = self._broken.pop(index)
                break
            index += 1
        self._broken.append(_Broken(origin, now + self.config.h3_retry_after_s))

    def _send_h3(
        mut self,
        method: Method,
        url: StringSlice,
        port: Int,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises TlsError -> Response:
        """Send a request over HTTP/3 to a UDP port."""
        if len(self._h3) == 0:
            var quic = Quic(OpenSsl())
            var context = QuicContext.client(
                quic^, self.config.ca_file, self.config.verify
            )
            var settings = self.config.client.copy()
            settings.connect_timeout_ms = self.config.h3_timeout_ms
            self._h3.append(H3Client(context^, settings))
        var endpoint = self._h3[0].endpoint(url)
        endpoint.port = port
        var target = endpoint.target.copy()
        return self._h3[0].send(endpoint, method, target, headers, body)

    def _send_https(
        mut self,
        method: Method,
        url: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises TlsError -> Response:
        """Send a request over TLS with HTTP/2, or HTTP/1.1 when the server
        does not choose `h2`."""
        if len(self._https) == 0:
            self._https.append(
                Https2Client.create(
                    OpenSsl(),
                    self.config.ca_file,
                    self.config.verify,
                    self.config.enable_h2,
                    self.config.client,
                )
            )
        var endpoint = self._https[0].endpoint(url)
        var target = endpoint.target.copy()
        var response = self._https[0].send(
            endpoint, method, target, headers, body
        )
        var h2 = response.protocol == H2Version.HTTP_2
        self.protocol = Protocol.HTTPS2 if h2 else Protocol.HTTPS1
        return http1_response(response, method, self.config.client)

    def _send_http(
        mut self,
        method: Method,
        url: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises TlsError -> Response:
        """Send a request over TCP: h2c first when `enable_h2c` is set."""
        if not self.config.enable_h2c:
            try:
                var endpoint = self.http.endpoint(url)
                var target = endpoint.target.copy()
                var response = self.http.send(
                    endpoint, method, target, headers, body
                )
                self.protocol = Protocol.HTTP1
                return response^
            except e:
                raise TlsError.from_http(e)
        if len(self._h2c) == 0:
            var settings = H2cConfig()
            settings.http = self.config.client.copy()
            self._h2c.append(H2cClient(settings))
        var response: H2Response
        try:
            var endpoint = self._h2c[0].endpoint(url)
            var target = endpoint.target.copy()
            response = self._h2c[0].send(
                endpoint, method, target, headers, body
            )
        except e:
            raise TlsError.from_http(e)
        var h2 = response.protocol == H2Version.HTTP_2
        self.protocol = Protocol.H2C if h2 else Protocol.HTTP1
        return http1_response(response, method, self.config.client)

    def send(
        mut self,
        method: Method,
        url: StringSlice,
        headers: Headers,
        body: Span[UInt8, _],
    ) raises TlsError -> Response:
        """Send a request with the best protocol that works, and read the
        whole response.

        Args:
            method: The method; not `OTHER`.
            url: An `http` or `https` URL.
            headers: The other header fields.
            body: The content; empty for none.

        Returns:
            The response. `protocol` says how it came.

        Raises:
            TlsError: `USAGE` for another scheme or an invalid request; the
                errors of the last protocol that the client tried.
        """
        var parsed: Url
        try:
            parsed = Url.parse(url)
        except e:
            raise TlsError.from_http(e)
        if parsed.scheme == "http":
            return self._send_http(method, url, headers, body)
        if parsed.scheme != "https":
            raise TlsError(
                TlsErrorKind.USAGE, "the URL is not http or https", 0
            )
        var origin = parsed.authority()
        var now = _now_s()
        if not self._broken_now(origin, now):
            var port = -1
            var alternative = self.alt_svc.lookup(origin, now)
            if alternative:
                port = alternative.value().port
            elif self.config.enable_h3:
                port = parsed.port
            if port > 0:
                try:
                    var response = self._send_h3(
                        method, url, port, headers, body
                    )
                    self.protocol = Protocol.HTTP3
                    return response^
                except e:
                    if e.kind == TlsErrorKind.USAGE:
                        raise e^
                    self._mark_broken(origin, now)
        var response = self._send_https(method, url, headers, body)
        var announced = response.header("alt-svc")
        if announced:
            self.alt_svc.remember(origin, announced.value(), now)
        return response^
