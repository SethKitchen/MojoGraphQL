# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The client of `graphql-transport-ws` on a `WsClient`: many operations
on one socket.

`TransportClient.connect` opens the socket with the subprotocol, sends
`connection_init`, and waits for `connection_ack`. `subscribe` sends a
`subscribe` and returns its id. `next` reads until the next `next`,
`error` or `complete` of any operation, and answers each `ping` with a
`pong`. `complete` stops an operation.

A message that breaks the protocol closes the socket with 4004 and the
error text, as graphql-ws does: a first message that is not
`connection_ack`, or a message that `parse_message` refuses. When no
acknowledgement comes within `ack_timeout_ms`, the socket closes with
4504.

This module ports the protocol part of graphql-ws 6.4.1 `src/client.ts`
(`createClient`: `connect`, `socket.onmessage`, `subscribe`, the
`generateID` UUID), with `tests/client.test.ts`.

Differences from upstream: the client is not lazy and does not retry; a
caller connects again. Results come from `next`, not through sinks.
`keepAlive` pings are the caller's, with `ping`.
"""

from std.random import random_ui64

from gql_json.writer import write_string

from gql_ws.client import ClientConfig, WsClient
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.graphql_ws import (
    BAD_RESPONSE,
    CONNECTION_ACKNOWLEDGEMENT_TIMEOUT,
    GRAPHQL_TRANSPORT_WS_PROTOCOL,
    MessageType,
    ProtocolMessage,
    id_message,
    limit_close_reason,
    parse_message,
    payload_message,
)
from gql_ws.protocol import Message, MessageKind


struct ClientEvent(Movable):
    """A `next`, `error` or `complete` of an operation."""

    var type: MessageType
    """`NEXT`, `ERROR` or `COMPLETE`."""
    var id: String
    """The id of the operation."""
    var payload: String
    """The JSON of the result or of the errors; empty for `COMPLETE`."""

    def __init__(out self):
        """Make an empty event."""
        self.type = MessageType.COMPLETE
        self.id = String()
        self.payload = String()


def generate_id() -> String:
    """Return a random UUID version 4, as the `generateID` of graphql-ws.

    Returns:
        The text, such as `110ec58a-a0f2-4ac4-8393-c866d813b8d1`.
    """
    var digits = "0123456789abcdef"
    var out = String()
    var bits = random_ui64(0, UInt64.MAX)
    var more = random_ui64(0, UInt64.MAX)
    var index = 0
    while index < 32:
        if index == 8 or index == 12 or index == 16 or index == 20:
            out += "-"
        var nibble = Int(bits & 15)
        bits = (bits >> 4) | ((more & 15) << 60)
        more >>= 4
        if index == 12:
            nibble = 4
        elif index == 16:
            nibble = (nibble & 3) | 8
        out += digits[byte=nibble]
        index += 1
    return out^


def subscribe_payload(
    query: StringSlice,
    variables: StringSlice = "",
    operation_name: StringSlice = "",
    extensions: StringSlice = "",
) -> String:
    """Write the payload of a `subscribe`.

    Args:
        query: The GraphQL document.
        variables: The JSON object of the variables, or empty.
        operation_name: The operation to run, or empty.
        extensions: The JSON object of the extensions, or empty.

    Returns:
        The JSON text, such as `{"query":"{ hello }"}`.
    """
    var out = List[UInt8]()
    out.extend(StaticString('{"query":').as_bytes())
    write_string(out, query.as_bytes())
    if variables.byte_length() > 0:
        out.extend(StaticString(',"variables":').as_bytes())
        out.extend(variables.as_bytes())
    if operation_name.byte_length() > 0:
        out.extend(StaticString(',"operationName":').as_bytes())
        write_string(out, operation_name.as_bytes())
    if extensions.byte_length() > 0:
        out.extend(StaticString(',"extensions":').as_bytes())
        out.extend(extensions.as_bytes())
    out.append(125)
    return String(unsafe_from_utf8=out^)


struct TransportClient(Movable):
    """A connected and acknowledged `graphql-transport-ws` client."""

    var socket: WsClient
    """The WebSocket."""
    var ack_payload: String
    """The JSON of the payload of the `connection_ack`, or empty."""
    var active: Dict[String, Bool]
    """The ids of the operations that have not ended."""
    var _message: Message

    def __init__(out self, var socket: WsClient):
        """Wrap a WebSocket before its `connection_init`.

        Args:
            socket: The WebSocket, with the subprotocol.
        """
        self.socket = socket^
        self.ack_payload = String()
        self.active = Dict[String, Bool]()
        self._message = Message()

    @staticmethod
    def connect(
        url: StringSlice,
        connection_params: StringSlice = "",
        ack_timeout_ms: Int = 0,
        config: ClientConfig = ClientConfig(),
    ) raises WsError -> TransportClient:
        """Connect, send `connection_init`, and wait for the ack.

        Args:
            url: The `ws://` URL of the server.
            connection_params: The JSON object of the `connection_init`
                payload, or empty.
            ack_timeout_ms: The longest wait for the ack; 0 waits without a
                limit, as `connectionAckWaitTimeout`.
            config: The configuration of the WebSocket.

        Returns:
            The client.

        Raises:
            WsError: The errors of `WsClient.connect`; `CLOSED` with the
                close code when the server closes, or the client closes
                with 4004 or 4504.
        """
        var socket = WsClient.connect(
            url, [GRAPHQL_TRANSPORT_WS_PROTOCOL], config
        )
        var client = TransportClient(socket^)
        client._send(
            payload_message(MessageType.CONNECTION_INIT, connection_params)
        )
        var timeout = ack_timeout_ms if ack_timeout_ms > 0 else -1
        var message = client._read(timeout)
        if not message:
            var failure = client._fail(
                CONNECTION_ACKNOWLEDGEMENT_TIMEOUT,
                "Connection acknowledgement timeout",
            )
            raise failure^
        if message.value().type != MessageType.CONNECTION_ACK:
            var failure = client._fail(
                BAD_RESPONSE,
                "First message cannot be of type "
                + String(message.value().type.text()),
            )
            raise failure^
        client.ack_payload = message.value().payload_json()
        return client^

    def _send(mut self, text: String) raises WsError:
        """Send one message."""
        self.socket.send_text(text)

    def _fail(
        mut self, code: CloseCode, reason: String
    ) raises WsError -> WsError:
        """Close with a code and make the error to raise."""
        self.socket.close(code, reason)
        return WsError(WsErrorKind.CLOSED, reason, code.value, 0)

    def _read(
        mut self, timeout_ms: Int
    ) raises WsError -> Optional[ProtocolMessage]:
        """Read the next message that is not a ping or a pong, and answer
        each ping. None after the timeout."""
        while True:
            if not self.socket.read(self._message, timeout_ms):
                return None
            var kind = self._message.kind
            if kind == MessageKind.CLOSE:
                raise WsError(
                    WsErrorKind.CLOSED,
                    String(self._message.text()),
                    self._message.code.value,
                    0,
                )
            if kind != MessageKind.TEXT and kind != MessageKind.BINARY:
                continue
            var parsed: ProtocolMessage
            try:
                parsed = parse_message(self._message.text())
            except e:
                var failure = self._fail(
                    BAD_RESPONSE, limit_close_reason(String(e), "Bad response")
                )
                raise failure^
            if parsed.type == MessageType.PING:
                self._send(
                    payload_message(MessageType.PONG, parsed.payload_json())
                )
                continue
            if parsed.type == MessageType.PONG:
                continue
            return parsed^

    def subscribe(mut self, payload: StringSlice) raises WsError -> String:
        """Start an operation.

        Args:
            payload: The JSON of the payload, from `subscribe_payload`.

        Returns:
            The id of the operation, a new UUID.

        Raises:
            WsError: When the send fails.
        """
        var id = generate_id()
        self._send(id_message(MessageType.SUBSCRIBE, id, payload))
        self.active[id] = True
        return id^

    def next(
        mut self, mut event: ClientEvent, timeout_ms: Int = -1
    ) raises WsError -> Bool:
        """Read the next result, error or end of any operation.

        A message for an id that has ended is dropped, as graphql-ws drops
        it without a sink.

        Args:
            event: The event to fill.
            timeout_ms: The longest wait; -1 waits without a limit.

        Returns:
            True with an event; False after the timeout.

        Raises:
            WsError: `CLOSED` with the code and the reason when the server
                closes; the errors of `WsClient.read`.
        """
        while True:
            var message = self._read(timeout_ms)
            if not message:
                return False
            ref found = message.value()
            if found.type == MessageType.CONNECTION_ACK:
                # Already connected and acknowledged.
                continue
            if not found.id in self.active:
                continue
            event.type = found.type
            event.id = found.id
            event.payload = found.payload_json()
            if found.type != MessageType.NEXT:
                _ = self.active.pop(found.id, False)
            return True

    def complete(mut self, id: StringSlice) raises WsError:
        """Stop an operation: send `complete`.

        Args:
            id: The id of the operation.

        Raises:
            WsError: When the send fails.
        """
        var key = String(id)
        if key in self.active:
            _ = self.active.pop(key, False)
            self._send(id_message(MessageType.COMPLETE, key))

    def ping(mut self, payload: StringSlice = "") raises WsError:
        """Send a protocol `ping`.

        Args:
            payload: The JSON object of the payload, or empty.

        Raises:
            WsError: When the send fails.
        """
        self._send(payload_message(MessageType.PING, payload))

    def close(
        mut self,
        code: CloseCode = CloseCode.NORMAL,
        reason: StringSlice = "Normal Closure",
    ) raises WsError:
        """Close the socket, as `dispose`.

        Args:
            code: The close code.
            reason: The close reason.

        Raises:
            WsError: When the send fails.
        """
        self.socket.close(code, reason)
