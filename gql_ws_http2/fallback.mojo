# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A WebSocket client that tries HTTP/2 first: the extended `CONNECT` of
RFC 8441 over h2c, else the HTTP/1.1 Upgrade of RFC 6455.

`connect_ws` opens h2c with prior knowledge. When the server answers with
SETTINGS that allow the extended `CONNECT`, the WebSocket is on an HTTP/2
stream. When the server does not speak HTTP/2, does not allow the
extended `CONNECT`, or does not answer within `connect_timeout_ms`, the
client connects again with `WsClient`. A refusal with a status, such as
404, is the answer of the server: the client does not try again.

`WsAnyClient` conforms to `MessageSocket`, so `connect_transport` gives a
`graphql-transport-ws` client on either.

This module ports no code. It follows the choice of RFC 8441 section 3:
a client sends the extended `CONNECT` only after the setting arrived.

Differences from upstream: none; there is no upstream. HTTP/3 (RFC 9220)
is not in the chain: `gql_ws_http3` has no QUIC driver yet.
"""

from gql_http2.session import SocketTransport
from gql_ws.client import ClientConfig, MessageSocket, WsClient
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.protocol import Message
from gql_ws.transport_client import TransportClientOf

from gql_ws_http2.client import H2WebSocket, connect_h2c


struct WsAnyClient(MessageSocket):
    """A WebSocket client on an HTTP/2 stream or on an HTTP/1.1
    connection."""

    var h2: List[H2WebSocket[SocketTransport]]
    """The HTTP/2 WebSocket, or none."""
    var h1: List[WsClient]
    """The HTTP/1.1 WebSocket, or none."""

    def __init__(out self, var h2: H2WebSocket[SocketTransport]):
        """Wrap a WebSocket on an HTTP/2 stream.

        Args:
            h2: The WebSocket.
        """
        self.h2 = List[H2WebSocket[SocketTransport]]()
        self.h2.append(h2^)
        self.h1 = List[WsClient]()

    def __init__(out self, var h1: WsClient):
        """Wrap a WebSocket on an HTTP/1.1 connection.

        Args:
            h1: The WebSocket.
        """
        self.h2 = List[H2WebSocket[SocketTransport]]()
        self.h1 = List[WsClient]()
        self.h1.append(h1^)

    def uses_http2(self) -> Bool:
        """Return True when the WebSocket is on an HTTP/2 stream.

        Returns:
            Whether the client chose HTTP/2.
        """
        return len(self.h2) > 0

    def protocol(self) -> String:
        """Return the subprotocol of the server.

        Returns:
            The subprotocol, or empty.
        """
        if self.uses_http2():
            return self.h2[0].protocol
        return self.h1[0].protocol

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
        if self.uses_http2():
            return self.h2[0].read(message, timeout_ms)
        return self.h1[0].read(message, timeout_ms)

    def send_text(mut self, text: StringSlice) raises WsError:
        """Send a text message.

        Args:
            text: The text.

        Raises:
            WsError: The errors of `send_text` of the WebSocket.
        """
        if self.uses_http2():
            self.h2[0].send_text(text)
        else:
            self.h1[0].send_text(text)

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
        if self.uses_http2():
            self.h2[0].close(code, reason)
        else:
            self.h1[0].close(code, reason)


def _falls_back(error: WsError) -> Bool:
    """Return True for a failure of HTTP/2 that is not an answer of the
    server."""
    if error.kind == WsErrorKind.TIMEOUT:
        return True
    return error.kind == WsErrorKind.HANDSHAKE and error.status == 0


def connect_ws(
    url: StringSlice,
    protocols: List[String] = [],
    config: ClientConfig = ClientConfig(),
) raises WsError -> WsAnyClient:
    """Connect to a `ws://` URL: with the extended `CONNECT` over h2c when
    the server allows it, else with the HTTP/1.1 Upgrade.

    Args:
        url: The URL, such as `ws://localhost:4000/graphql`.
        protocols: The subprotocols to offer.
        config: The configuration of the WebSocket.

    Returns:
        The client.

    Raises:
        WsError: A refusal of the HTTP/2 handshake with a status; `IO`
            when the connection fails; the errors of `WsClient.connect`.
    """
    try:
        return WsAnyClient(connect_h2c(url, protocols, config))
    except e:
        if not _falls_back(e):
            raise e^
    return WsAnyClient(WsClient.connect(url, protocols, config))


def connect_transport(
    url: StringSlice,
    connection_params: StringSlice = "",
    ack_timeout_ms: Int = 0,
    config: ClientConfig = ClientConfig(),
) raises WsError -> TransportClientOf[WsAnyClient]:
    """Connect with `connect_ws`, send `connection_init`, and wait for the
    ack.

    Args:
        url: The `ws://` URL of the server.
        connection_params: The JSON object of the `connection_init`
            payload, or empty.
        ack_timeout_ms: The longest wait for the ack; 0 waits without a
            limit.
        config: The configuration of the WebSocket.

    Returns:
        The client.

    Raises:
        WsError: The errors of `connect_ws` and of
            `TransportClientOf.start`.
    """
    var socket = connect_ws(url, [GRAPHQL_TRANSPORT_WS_PROTOCOL], config)
    var client = TransportClientOf[WsAnyClient](socket^)
    client.start(connection_params, ack_timeout_ms)
    return client^
