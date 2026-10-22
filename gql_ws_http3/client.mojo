# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The client end of a WebSocket on an HTTP/3 request stream (RFC 9220),
over a real QUIC connection of `gql_http3`.

`H3WebSocket` conforms to the `MessageSocket` of `gql_ws`, so
`H3TransportClient` speaks `graphql-transport-ws` over HTTP/3.
`connect_h3` opens the QUIC connection of an `H3Client` to a `wss://`
URL, waits for the SETTINGS of the server, refuses a server without
`SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`, and sends the extended `CONNECT`.

- **Closing.** The end of the stream (FIN) is the end of the TCP
  connection of RFC 6455 (RFC 9220 section 3). After the closing handshake
  the client ends its side with FIN. A reset is a close without a
  handshake.
- **Back pressure.** A send waits, until `write_timeout_ms`, for the
  credit of the stream.
- **QPACK.** The tunnel uses its own QPACK coders with a table of
  capacity 0, as the connection does: no field line refers to a dynamic
  table.

This module ports no code. The read and write loop follows `H2WebSocket`
of `gql_ws_http2`, and the stream follows RFC 9220 section 3.

Differences from upstream: none; tungstenite has no HTTP/3 transport.
"""

from std.time import perf_counter_ns

from gql_http.url import Url
from gql_tls.error import TlsError, TlsErrorKind
from gql_http3.client import H3Client, H3Stream
from gql_http3.error import H3Error
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.quic import ReadState
from gql_ws.client import ClientConfig, MessageSocket
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.protocol import Message, Role, WsConfig
from gql_ws.transport_client import TransportClientOf

from gql_ws_http3.tunnel import H3Tunnel


comptime H3TransportClient = TransportClientOf[H3WebSocket]
"""The `graphql-transport-ws` client on an HTTP/3 WebSocket."""

comptime _FOREVER_MS = 1 << 30
"""The wait of a read without a timeout."""


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


def ws_error(error: TlsError) -> WsError:
    """Make the WebSocket error of a failed QUIC or TLS call.

    Args:
        error: The error of the call.

    Returns:
        `TIMEOUT` for a timeout, else `IO`, with the message.
    """
    var kind = (
        WsErrorKind.TIMEOUT if error.kind
        == TlsErrorKind.TIMEOUT else WsErrorKind.IO
    )
    return WsError.of(kind, "transport error: " + error.message)


struct H3WebSocket(MessageSocket):
    """A WebSocket on one request stream of a client QUIC connection."""

    var client: H3Client
    """The HTTP/3 client; the WebSocket closes its connections."""
    var stream: H3Stream
    """The request stream of the tunnel."""
    var tunnel: H3Tunnel
    """The WebSocket and the reader of the stream."""
    var protocol: String
    """The subprotocol of the server, or empty."""
    var config: ClientConfig
    """The configuration."""
    var _decoder: QpackDecoder
    var _ended: Bool
    var _sent_end: Bool
    var _in: List[UInt8]

    def __init__(
        out self,
        var client: H3Client,
        stream: H3Stream,
        config: ClientConfig = ClientConfig(),
    ):
        """Wrap a stream of `H3Client.open_stream`; call `handshake`.

        Args:
            client: The client of the stream; the WebSocket closes it.
            stream: The stream.
            config: The configuration of the WebSocket.
        """
        self.client = client^
        self.stream = stream
        self.tunnel = H3Tunnel(Role.CLIENT, stream.id, config.ws)
        self.protocol = String()
        self.config = config.copy()
        self._decoder = QpackDecoder()
        self._ended = False
        self._sent_end = False
        self._in = List[UInt8]()

    def __deinit__(deinit self):
        """Free the stream, and close the connections."""
        self.client.close_stream(self.stream)
        self.client.close()

    def handshake(
        mut self,
        authority: StringSlice,
        path: StringSlice,
        protocols: List[String] = [],
    ) raises WsError:
        """Send the extended `CONNECT`, and check the answer, within
        `connect_timeout_ms`.

        Args:
            authority: The host and the port.
            path: The path and the query.
            protocols: The subprotocols to offer.

        Raises:
            WsError: `HANDSHAKE` when the server refuses the WebSocket,
                with the status of the answer, or ends the stream first;
                `TIMEOUT` at the deadline; `IO` when the stream fails.
        """
        var deadline = _now_ms() + self.config.connect_timeout_ms
        var encoder = QpackEncoder()
        self.tunnel.request(encoder, "https", authority, path, protocols)
        self._send(False)
        while not self.tunnel.has_head():
            if self._ended:
                raise WsError.of(
                    WsErrorKind.HANDSHAKE, "Handshake not finished"
                )
            if not self._fill(deadline):
                raise WsError.of(WsErrorKind.TIMEOUT, "handshake timed out")
        self.tunnel.verify(protocols)
        self.protocol = self.tunnel.protocol

    def _send(mut self, end: Bool) raises WsError:
        """Write `out` of the tunnel on the stream."""
        try:
            self.client.write_stream(self.stream, Span(self.tunnel.out), end)
        except e:
            raise ws_error(e)
        self.tunnel.out.clear()

    def _fill(mut self, deadline: Int) raises WsError -> Bool:
        """Read what arrives; False at the deadline. -1 waits without a
        limit."""
        var wait = _FOREVER_MS if deadline < 0 else max(0, deadline - _now_ms())
        var state: ReadState
        try:
            state = self.client.read_stream(self.stream, self._in, wait)
        except e:
            raise ws_error(e)
        if state == ReadState.WAIT:
            return False
        if state != ReadState.DATA:
            self._ended = True
            return True
        try:
            self.tunnel.receive(Span(self._in), self._decoder)
        except e:
            self._in.clear()
            raise WsError.protocol("HTTP/3 error: " + e.message)
        self._in.clear()
        return True

    def flush(mut self) raises WsError:
        """Move the output of the WebSocket into DATA frames, and send
        them within `write_timeout_ms`.

        Raises:
            WsError: `TIMEOUT` when the stream gets no credit; `IO` when
                the stream fails.
        """
        # After the closing handshake the end of the stream goes out.
        var end = self.tunnel.ws.should_close() and not self._sent_end
        self.tunnel.flush()
        if not self._ended and (len(self.tunnel.out) > 0 or end):
            self._send(end)
            self._sent_end = end
        self.tunnel.out.clear()

    def read(
        mut self, mut message: Message, timeout_ms: Int = -1
    ) raises WsError -> Bool:
        """Read the next message.

        A ping gets its pong before the method returns.

        Args:
            message: The message to fill.
            timeout_ms: The longest wait; -1 waits without a limit, and 0
                reads only what has arrived.

        Returns:
            True with a message; False when the timeout passed first.

        Raises:
            WsError: `CLOSED` when the server ended the stream after the
                closing handshake; `PROTOCOL` for a reset or an end
                without it, and the errors of `WebSocket.read`; `IO` when
                the stream fails.
        """
        var deadline = -1 if timeout_ms < 0 else _now_ms() + timeout_ms
        while True:
            var got: Bool
            try:
                got = self.tunnel.ws.read(message)
            except e:
                # The close frame of the failure goes out first; a failed
                # send raises its own error.
                self.flush()
                raise e^
            self.flush()
            if got:
                return True
            if self._ended:
                var clean = self.tunnel.ws.peer_closed()
                if clean:
                    raise WsError.of(
                        WsErrorKind.CLOSED, "Connection closed normally"
                    )
                raise WsError.protocol(
                    "Connection reset without closing handshake"
                )
            if not self._fill(deadline):
                return False

    def send_text(mut self, text: StringSlice) raises WsError:
        """Send a text message.

        Args:
            text: The text.

        Raises:
            WsError: The errors of `WebSocket.send_text` and `flush`.
        """
        self.tunnel.ws.send_text(text)
        self.flush()

    def send_binary(mut self, data: Span[UInt8, _]) raises WsError:
        """Send a binary message.

        Args:
            data: The bytes.

        Raises:
            WsError: The errors of `WebSocket.send_binary` and `flush`.
        """
        self.tunnel.ws.send_binary(data)
        self.flush()

    def ping(mut self, data: Span[UInt8, _]) raises WsError:
        """Send a ping.

        Args:
            data: The payload, at most 125 bytes.

        Raises:
            WsError: The errors of `WebSocket.ping` and `flush`.
        """
        self.tunnel.ws.ping(data)
        self.flush()

    def close(
        mut self, code: CloseCode = CloseCode.NORMAL, reason: StringSlice = ""
    ) raises WsError:
        """Send a close frame. Read on until `read` raises `CLOSED`.

        Args:
            code: The code.
            reason: The reason, at most 123 bytes.

        Raises:
            WsError: The errors of `WebSocket.close` and `flush`.
        """
        self.tunnel.ws.close(code, reason)
        self.flush()


def connect_h3(
    var client: H3Client,
    url: StringSlice,
    protocols: List[String] = [],
    config: ClientConfig = ClientConfig(),
) raises WsError -> H3WebSocket:
    """Connect to a `wss://` URL over HTTP/3, and do the extended
    `CONNECT`.

    Args:
        client: The HTTP/3 client, such as `H3Client.system()`. Its
            timeouts become `connect_timeout_ms` and `write_timeout_ms`.
        url: The URL, such as `wss://localhost:4000/graphql`.
        protocols: The subprotocols to offer.
        config: The configuration of the WebSocket.

    Returns:
        The WebSocket.

    Raises:
        WsError: `HANDSHAKE` for a bad URL, a `ws://` URL, a server that
            does not allow the extended `CONNECT`, or a refused
            handshake; `TIMEOUT` when the QUIC handshake or the SETTINGS
            do not come in time; `IO` when the connection fails; the
            errors of `H3WebSocket.handshake`.
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
    client.config.connect_timeout_ms = config.connect_timeout_ms
    client.config.timeout_ms = config.write_timeout_ms
    var stream: H3Stream
    try:
        var endpoint = client.endpoint("https://" + authority + "/")
        stream = client.open_stream(endpoint)
    except e:
        if e.kind == TlsErrorKind.PROTOCOL:
            raise WsError.of(WsErrorKind.HANDSHAKE, e.message)
        raise ws_error(e)
    var target = parsed.path
    if parsed.query.byte_length() > 0:
        target += "?" + parsed.query
    var socket = H3WebSocket(client^, stream, config)
    socket.handshake(authority, target, protocols)
    return socket^


def connect_transport_h3(
    var client: H3Client,
    url: StringSlice,
    connection_params: StringSlice = "",
    ack_timeout_ms: Int = 0,
    config: ClientConfig = ClientConfig(),
) raises WsError -> H3TransportClient:
    """Connect with `connect_h3`, send `connection_init`, and wait for the
    ack.

    Args:
        client: The HTTP/3 client.
        url: The `wss://` URL of the server.
        connection_params: The JSON object of the `connection_init`
            payload, or empty.
        ack_timeout_ms: The longest wait for the ack; 0 waits without a
            limit.
        config: The configuration of the WebSocket.

    Returns:
        The client.

    Raises:
        WsError: The errors of `connect_h3` and of
            `TransportClientOf.start`.
    """
    var socket = connect_h3(
        client^, url, [GRAPHQL_TRANSPORT_WS_PROTOCOL], config
    )
    var transport = H3TransportClient(socket^)
    transport.start(connection_params, ack_timeout_ms)
    return transport^
