# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A WebSocket client that tries HTTP/3 first, then HTTP/2, then
HTTP/1.1.

`connect_any` chooses by the scheme of the URL:

1. `wss://`: the extended `CONNECT` of RFC 9220 over QUIC. The QUIC
   handshake has the short limit `h3_timeout_ms`, because a network that
   blocks UDP drops the packets silently.
2. `wss://`, when HTTP/3 fails: the extended `CONNECT` of RFC 8441 on an
   HTTP/2 connection over TLS, with ALPN `h2`.
3. `ws://`: `connect_ws` of `gql_ws_http2`, which tries h2c and then the
   HTTP/1.1 Upgrade. RFC 9220 needs TLS, so HTTP/3 is not in this chain.

The client tries the next protocol when the server does not answer in
time, when the connection fails, or when the server does not allow the
extended `CONNECT`. A refusal with a status, such as 404, is the answer
of the server: the client does not try again. A `wss://` server that
does not choose `h2` fails with `HANDSHAKE`, because `gql_ws` has no
WebSocket over HTTPS/1.1. The client never goes from `wss://` to a
connection without TLS.

`WsH3AnyClient` conforms to `MessageSocket`, so `connect_any_transport`
gives a `graphql-transport-ws` client on any of them.

This module ports no code. The order follows RFC 9220 section 3, RFC 8441
section 3 and the `FallbackClient` of `gql_http3`.

Differences from upstream: none; there is no upstream.
"""

from std.time import perf_counter_ns

from gql_http.socket import IPv4Address, Sys
from gql_http.url import Url
from gql_tls.client import HttpsEndpoint, open_tls
from gql_tls.context import TlsContext
from gql_tls.error import TlsError
from gql_tls.openssl import OpenSsl
from gql_http3.client import H3Client
from gql_http3.quic import Quic, QuicContext
from gql_https2.server import H2
from gql_https2.transport import TlsTransport
from gql_ws.client import ClientConfig, MessageSocket
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.protocol import Message
from gql_ws.transport_client import TransportClientOf
from gql_ws_http2.client import H2WebSocket
from gql_ws_http2.fallback import WsAnyClient, connect_ws

from gql_ws_http3.client import H3WebSocket, connect_h3, ws_error


struct WsH3AnyClient(MessageSocket):
    """A WebSocket client on HTTP/3, on HTTP/2 over TLS, or on the chain
    of `connect_ws`."""

    var h3: List[H3WebSocket]
    """The HTTP/3 WebSocket, or none."""
    var h2: List[H2WebSocket[TlsTransport]]
    """The WebSocket on HTTP/2 over TLS, or none."""
    var tcp: List[WsAnyClient]
    """The WebSocket of `connect_ws`, or none."""

    def __init__(out self, var h3: H3WebSocket):
        """Wrap an HTTP/3 WebSocket.

        Args:
            h3: The WebSocket.
        """
        self.h3 = List[H3WebSocket]()
        self.h3.append(h3^)
        self.h2 = List[H2WebSocket[TlsTransport]]()
        self.tcp = List[WsAnyClient]()

    def __init__(out self, var h2: H2WebSocket[TlsTransport]):
        """Wrap a WebSocket on HTTP/2 over TLS.

        Args:
            h2: The WebSocket.
        """
        self.h3 = List[H3WebSocket]()
        self.h2 = List[H2WebSocket[TlsTransport]]()
        self.h2.append(h2^)
        self.tcp = List[WsAnyClient]()

    def __init__(out self, var tcp: WsAnyClient):
        """Wrap a WebSocket of `connect_ws`.

        Args:
            tcp: The WebSocket.
        """
        self.h3 = List[H3WebSocket]()
        self.h2 = List[H2WebSocket[TlsTransport]]()
        self.tcp = List[WsAnyClient]()
        self.tcp.append(tcp^)

    def version(self) -> StaticString:
        """Return the HTTP version that carries the WebSocket.

        Returns:
            `h3`, `h2` (over TLS), `h2c`, or `http/1.1`.
        """
        if len(self.h3) > 0:
            return "h3"
        if len(self.h2) > 0:
            return "h2"
        if self.tcp[0].uses_http2():
            return "h2c"
        return "http/1.1"

    def protocol(self) -> String:
        """Return the subprotocol of the server.

        Returns:
            The subprotocol, or empty.
        """
        if len(self.h3) > 0:
            return self.h3[0].protocol
        if len(self.h2) > 0:
            return self.h2[0].protocol
        return self.tcp[0].protocol()

    def read(
        mut self, mut message: Message, timeout_ms: Int = -1
    ) raises WsError -> Bool:
        """Read the next message.

        Args:
            message: The message to fill.
            timeout_ms: The longest wait; -1 waits without a limit.

        Returns:
            True with a message; False after the timeout.

        Raises:
            WsError: The errors of `read` of the WebSocket.
        """
        if len(self.h3) > 0:
            return self.h3[0].read(message, timeout_ms)
        if len(self.h2) > 0:
            return self.h2[0].read(message, timeout_ms)
        return self.tcp[0].read(message, timeout_ms)

    def send_text(mut self, text: StringSlice) raises WsError:
        """Send a text message.

        Args:
            text: The text.

        Raises:
            WsError: The errors of `send_text` of the WebSocket.
        """
        if len(self.h3) > 0:
            self.h3[0].send_text(text)
        elif len(self.h2) > 0:
            self.h2[0].send_text(text)
        else:
            self.tcp[0].send_text(text)

    def close(
        mut self, code: CloseCode = CloseCode.NORMAL, reason: StringSlice = ""
    ) raises WsError:
        """Start the closing handshake.

        Args:
            code: The code.
            reason: The reason, at most 123 bytes.

        Raises:
            WsError: The errors of `close` of the WebSocket.
        """
        if len(self.h3) > 0:
            self.h3[0].close(code, reason)
        elif len(self.h2) > 0:
            self.h2[0].close(code, reason)
        else:
            self.tcp[0].close(code, reason)


def _falls_back(error: WsError) -> Bool:
    """Return True for a failure of HTTP/3 that is not an answer of the
    server."""
    if error.kind == WsErrorKind.TIMEOUT or error.kind == WsErrorKind.IO:
        return True
    return error.kind == WsErrorKind.HANDSHAKE and error.status == 0


def connect_h2_tls(
    url: StringSlice,
    protocols: List[String] = [],
    config: ClientConfig = ClientConfig(),
    ca_file: String = "",
    verify: Bool = True,
) raises WsError -> H2WebSocket[TlsTransport]:
    """Connect to a `wss://` URL with HTTP/2 over TLS, and do the extended
    `CONNECT` of RFC 8441.

    Args:
        url: The URL, such as `wss://localhost:4433/graphql`.
        protocols: The subprotocols to offer.
        config: The configuration of the WebSocket.
        ca_file: A PEM file of trusted CA certificates; empty for the
            system CA store.
        verify: Whether to verify the server. Turn it off only for tests.

    Returns:
        The WebSocket.

    Raises:
        WsError: `HANDSHAKE` for a bad URL, a scheme other than `wss`, or
            a server that does not choose `h2`; `TIMEOUT` and `IO` when
            the connection or the TLS handshake fails; the errors of
            `H2WebSocket.handshake`.
    """
    var parsed: Url
    try:
        parsed = Url.parse(url)
    except e:
        raise WsError.of(WsErrorKind.HANDSHAKE, "URL error: " + e.message)
    if parsed.scheme != "wss":
        raise WsError.of(
            WsErrorKind.HANDSHAKE, "URL error: URL scheme not supported"
        )
    var port = parsed.port if parsed.port >= 0 else 443
    var authority = parsed.host + ":" + String(port)
    var target = parsed.path
    if parsed.query.byte_length() > 0:
        target += "?" + parsed.query
    var sys = Sys()
    var address: IPv4Address
    try:
        address = sys.resolve(parsed.host)
    except e:
        raise WsError.of(WsErrorKind.IO, "resolve error: " + e.message)
    var endpoint = HttpsEndpoint(
        address, port, parsed.host.copy(), authority, target
    )
    var stream_protocol: String
    var transport: TlsTransport
    try:
        var offered = List[String]()
        offered.append(H2)
        var context = TlsContext.client(OpenSsl(), offered^, ca_file, verify)
        var deadline = (
            Int(perf_counter_ns()) + config.connect_timeout_ms * 1_000_000
        )
        var stream = open_tls(
            sys, context, endpoint, deadline, config.connect_timeout_ms
        )
        stream_protocol = stream.protocol
        transport = TlsTransport(stream^, sys.copy())
    except e:
        raise ws_error(e)
    if stream_protocol != H2:
        raise WsError.of(
            WsErrorKind.HANDSHAKE,
            "the server does not choose h2: no WebSocket over HTTPS/1.1",
        )
    var socket = H2WebSocket[TlsTransport](transport^, config)
    socket.handshake("https", authority, target, protocols)
    return socket^


def connect_any(
    url: StringSlice,
    protocols: List[String] = [],
    config: ClientConfig = ClientConfig(),
    ca_file: String = "",
    verify: Bool = True,
    h3_timeout_ms: Int = 1000,
) raises WsError -> WsH3AnyClient:
    """Connect to a WebSocket URL with the first protocol that works:
    HTTP/3, then HTTP/2 over TLS for `wss://`; `connect_ws` for `ws://`.

    Args:
        url: The URL, such as `wss://localhost:4433/graphql`.
        protocols: The subprotocols to offer.
        config: The configuration of the WebSocket.
        ca_file: A PEM file of trusted CA certificates; empty for the
            system CA store.
        verify: Whether to verify the server. Turn it off only for tests.
        h3_timeout_ms: The longest QUIC handshake, and the longest wait
            for the SETTINGS of the server.

    Returns:
        The client.

    Raises:
        WsError: `HANDSHAKE` for a bad URL or a refusal with a status; the
            errors of `connect_h2_tls` and of `connect_ws`.
    """
    var parsed: Url
    try:
        parsed = Url.parse(url)
    except e:
        raise WsError.of(WsErrorKind.HANDSHAKE, "URL error: " + e.message)
    if parsed.scheme == "ws":
        return WsH3AnyClient(connect_ws(url, protocols, config))
    if parsed.scheme != "wss":
        raise WsError.of(
            WsErrorKind.HANDSHAKE, "URL error: URL scheme not supported"
        )
    var h3_config = config.copy()
    h3_config.connect_timeout_ms = min(h3_timeout_ms, config.connect_timeout_ms)
    h3_config.write_timeout_ms = min(h3_timeout_ms, config.write_timeout_ms)
    try:
        var context: QuicContext
        try:
            context = QuicContext.client(Quic(OpenSsl()), ca_file, verify)
        except e:
            raise ws_error(e)
        var socket = connect_h3(H3Client(context^), url, protocols, h3_config)
        # The handshake is over: the writes get the whole limit again.
        socket.client.config.timeout_ms = config.write_timeout_ms
        return WsH3AnyClient(socket^)
    except e:
        if not _falls_back(e):
            raise e^
    return WsH3AnyClient(
        connect_h2_tls(url, protocols, config, ca_file, verify)
    )


def connect_any_transport(
    url: StringSlice,
    connection_params: StringSlice = "",
    ack_timeout_ms: Int = 0,
    config: ClientConfig = ClientConfig(),
    ca_file: String = "",
    verify: Bool = True,
) raises WsError -> TransportClientOf[WsH3AnyClient]:
    """Connect with `connect_any`, send `connection_init`, and wait for the
    ack.

    Args:
        url: The `wss://` or `ws://` URL of the server.
        connection_params: The JSON object of the `connection_init`
            payload, or empty.
        ack_timeout_ms: The longest wait for the ack; 0 waits without a
            limit.
        config: The configuration of the WebSocket.
        ca_file: A PEM file of trusted CA certificates; empty for the
            system CA store.
        verify: Whether to verify the server.

    Returns:
        The client.

    Raises:
        WsError: The errors of `connect_any` and of
            `TransportClientOf.start`.
    """
    var socket = connect_any(
        url, [GRAPHQL_TRANSPORT_WS_PROTOCOL], config, ca_file, verify
    )
    var client = TransportClientOf[WsH3AnyClient](socket^)
    client.start(connection_params, ack_timeout_ms)
    return client^
