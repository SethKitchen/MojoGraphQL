# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL over WebSocket protocol `graphql-transport-ws`: its
subprotocol name, close codes and message types, the check of each
message, and the text of each message.

`parse_message` reads the JSON text of a message and checks it as
graphql-ws `validateMessage`, with the same error texts. The `*_message`
functions write the JSON text of each message type, with the members in
the order of `JSON.stringify` in graphql-ws.

This module ports graphql-ws 6.4.1 `src/common.ts` (`CloseCode`,
`MessageType`, `validateMessage`, `parseMessage`, `stringifyMessage`) and
`src/utils.ts` (`extendedTypeof`, `isObject`,
`areGraphQLFormattedErrors`, `limitCloseReason`), with
`tests/common.test.ts`.

Differences from upstream: the message keeps its parsed JSON document and
the node of its payload; graphql-ws keeps a JavaScript object. A JSON
reviver and replacer are not ported. In an error text, a payload that is
not an object is written as its JSON text, where JavaScript writes
`String(value)`.
"""

from gql_json.parser import parse
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_json.writer import stringify, write_string

from gql_ws.frame import CloseCode

comptime GRAPHQL_TRANSPORT_WS_PROTOCOL = "graphql-transport-ws"
"""The subprotocol of this protocol."""
comptime DEPRECATED_GRAPHQL_WS_PROTOCOL = "graphql-ws"
"""The subprotocol of the deprecated `subscriptions-transport-ws`."""

comptime INTERNAL_SERVER_ERROR = CloseCode(4500)
"""The server failed."""
comptime INTERNAL_CLIENT_ERROR = CloseCode(4005)
"""The client failed."""
comptime BAD_REQUEST = CloseCode(4400)
"""The client sent an invalid message."""
comptime BAD_RESPONSE = CloseCode(4004)
"""The server sent an invalid message."""
comptime UNAUTHORIZED = CloseCode(4401)
"""A subscribe came before the connection was acknowledged."""
comptime FORBIDDEN = CloseCode(4403)
"""The server refused the connection."""
comptime SUBPROTOCOL_NOT_ACCEPTABLE = CloseCode(4406)
"""The client did not offer `graphql-transport-ws`."""
comptime CONNECTION_INITIALISATION_TIMEOUT = CloseCode(4408)
"""No `connection_init` came in time."""
comptime CONNECTION_ACKNOWLEDGEMENT_TIMEOUT = CloseCode(4504)
"""No `connection_ack` came in time."""
comptime SUBSCRIBER_ALREADY_EXISTS = CloseCode(4409)
"""A subscribe used an id that is in use."""
comptime TOO_MANY_INITIALISATION_REQUESTS = CloseCode(4429)
"""A second `connection_init` came."""


@fieldwise_init
struct MessageType(Equatable, ImplicitlyCopyable, Writable):
    """The type of a message, as a type and not a bare integer."""

    var value: UInt8
    """The type's index; see `is_valid`."""

    comptime CONNECTION_INIT = MessageType(0)
    """`connection_init`, from the client."""
    comptime CONNECTION_ACK = MessageType(1)
    """`connection_ack`, from the server."""
    comptime PING = MessageType(2)
    """`ping`, both ways."""
    comptime PONG = MessageType(3)
    """`pong`, both ways."""
    comptime SUBSCRIBE = MessageType(4)
    """`subscribe`, from the client."""
    comptime NEXT = MessageType(5)
    """`next`, from the server."""
    comptime ERROR = MessageType(6)
    """`error`, from the server."""
    comptime COMPLETE = MessageType(7)
    """`complete`, both ways."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the types.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 7

    def text(self) -> StaticString:
        """Return the wire name of the type.

        Returns:
            The name, such as `connection_init`, or `invalid`.
        """
        comptime names: Array[StaticString, 8] = [
            "connection_init",
            "connection_ack",
            "ping",
            "pong",
            "subscribe",
            "next",
            "error",
            "complete",
        ]
        if not self.is_valid():
            return "invalid"
        return materialize[names]()[Int(self.value)]

    @staticmethod
    def from_text(text: StringSlice) -> MessageType:
        """Return the type of a wire name.

        Args:
            text: The name.

        Returns:
            The type; `MessageType(255)` for an unknown name.
        """
        var index: UInt8 = 0
        while index < 8:
            if MessageType(index).text() == text:
                return MessageType(index)
            index += 1
        return MessageType(255)

    def write_to(self, mut writer: Some[Writer]):
        """Write the wire name.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


def extended_typeof(document: JsonDocument, node: Int) -> StaticString:
    """Return the name of the type of a value, as graphql-ws
    `extendedTypeof`.

    Args:
        document: The document.
        node: The value, or `NO_NODE` for a missing one.

    Returns:
        `undefined`, `null`, `boolean`, `number`, `string`, `array` or
        `object`.
    """
    if node == NO_NODE:
        return "undefined"
    comptime names: Array[StaticString, 6] = [
        "null",
        "boolean",
        "number",
        "string",
        "array",
        "object",
    ]
    return materialize[names]()[Int(document.kind(node).value)]


def limit_close_reason(reason: String, when_too_long: String) -> String:
    """Return a close reason, or another one when it is too long, as
    graphql-ws `limitCloseReason`.

    Args:
        reason: The reason.
        when_too_long: The reason to use for one of 124 bytes or more.

    Returns:
        The reason that fits in a close frame.
    """
    return reason if reason.byte_length() < 124 else when_too_long


struct ProtocolMessage(Movable):
    """A message that `parse_message` checked."""

    var type: MessageType
    """The type."""
    var id: String
    """The id of a subscribe, next, error or complete; else empty."""
    var document: JsonDocument
    """The parsed message."""
    var payload: Int
    """The node of the payload, or `NO_NODE` when it is missing or null."""

    def __init__(
        out self,
        type: MessageType,
        id: String,
        var document: JsonDocument,
        payload: Int,
    ):
        """Make a message.

        Args:
            type: The type.
            id: The id, or empty.
            document: The parsed message.
            payload: The node of the payload, or `NO_NODE`.
        """
        self.type = type
        self.id = id
        self.document = document^
        self.payload = payload

    def payload_json(self) -> String:
        """Return the JSON text of the payload.

        Returns:
            The text, or empty without a payload.
        """
        if self.payload == NO_NODE:
            return String()
        return stringify(self.document, self.payload)

    def member(self, name: StringSlice) -> Int:
        """Return a member of the payload object.

        Args:
            name: The key, such as `query`.

        Returns:
            The node, or `NO_NODE` when it is missing or null.
        """
        if self.payload == NO_NODE:
            return NO_NODE
        var node = self.document.find(self.payload, name)
        if node != NO_NODE and self.document.kind(node) == JsonKind.NULL:
            return NO_NODE
        return node

    def member_json(self, name: StringSlice) -> String:
        """Return the JSON text of a member of the payload object.

        Args:
            name: The key, such as `variables`.

        Returns:
            The text, or empty when it is missing or null.
        """
        var node = self.member(name)
        if node == NO_NODE:
            return String()
        return stringify(self.document, node)

    def member_string(self, name: StringSlice) -> String:
        """Return a string member of the payload object, decoded.

        Args:
            name: The key, such as `query`.

        Returns:
            The string, or empty when it is missing, null or not a string.
        """
        var node = self.member(name)
        if node == NO_NODE or self.document.kind(node) != JsonKind.STRING:
            return String()
        return self.document.string_value(node)


def _is_object(document: JsonDocument, node: Int) -> Bool:
    """Return True for an object node, as graphql-ws `isObject`."""
    return node != NO_NODE and document.kind(node) == JsonKind.OBJECT


def _nullish(document: JsonDocument, node: Int) -> Bool:
    """Return True for a missing or null value: `val == null`."""
    return node == NO_NODE or document.kind(node) == JsonKind.NULL


def _quote(type: StringSlice) -> String:
    """Return `"<type>"`, the start of the upstream error texts."""
    return '"' + String(type) + '"'


def _check_id(document: JsonDocument, root: Int, type: String) raises -> String:
    """Check the `id` of a message: a string that is not empty."""
    var node = document.find(root, "id")
    if node == NO_NODE or document.kind(node) != JsonKind.STRING:
        raise Error(
            _quote(type)
            + " message expects the 'id' property to be a string, but got "
            + extended_typeof(document, node)
        )
    var id = document.string_value(node)
    if id.byte_length() == 0:
        raise Error(
            _quote(type) + " message requires a non-empty 'id' property"
        )
    return id^


def _formatted_errors(document: JsonDocument, node: Int) -> Bool:
    """Return True for a list of GraphQL errors, as graphql-ws
    `areGraphQLFormattedErrors`: a non-empty array of objects with a
    `message`."""
    if node == NO_NODE or document.kind(node) != JsonKind.ARRAY:
        return False
    if document.length(node) == 0:
        return False
    var child = document.first(node)
    while child != NO_NODE:
        if not _is_object(document, child):
            return False
        if document.find(child, "message") == NO_NODE:
            return False
        child = document.next(child)
    return True


def _optional_object(
    document: JsonDocument, payload: Int, key: StringSlice, type: String
) raises:
    """Check that a member of a subscribe payload is an object or nullish."""
    var node = document.find(payload, key)
    if not _nullish(document, node) and not _is_object(document, node):
        raise Error(
            _quote(type)
            + " message payload expects the '"
            + String(key)
            + "' property to be a an object or nullish or missing, but got "
            + extended_typeof(document, node)
        )


def _js_string(document: JsonDocument, node: Int) -> String:
    """Return the text of a value as JavaScript `String(value)` writes it."""
    var kind = document.kind(node)
    if kind == JsonKind.STRING:
        return document.string_value(node)
    if kind == JsonKind.OBJECT:
        return "[object Object]"
    if kind != JsonKind.ARRAY:
        return stringify(document, node)
    var parts = List[String]()
    var child = document.first(node)
    while child != NO_NODE:
        parts.append(_js_string(document, child))
        child = document.next(child)
    return ",".join(parts)


def _falsy(document: JsonDocument, node: Int) -> Bool:
    """Return True for a value that JavaScript reads as false: missing,
    null, false, 0 and the empty string."""
    if _nullish(document, node):
        return True
    var kind = document.kind(node)
    if kind == JsonKind.BOOLEAN:
        return not document.bool_value(node)
    if kind == JsonKind.NUMBER:
        return document.as_float64(node) == 0
    if kind == JsonKind.STRING:
        return document.text(node).byte_length() == 0
    return False


def validate_message(var document: JsonDocument) raises -> ProtocolMessage:
    """Check a parsed message, as graphql-ws `validateMessage`.

    Args:
        document: The parsed JSON of the message.

    Returns:
        The message.

    Raises:
        Error: With the upstream text, for a message that the protocol
            does not allow.
    """
    var root = document.root
    if not _is_object(document, root):
        raise Error(
            "Message is expected to be an object, but got "
            + extended_typeof(document, root)
        )
    var type_node = document.find(root, "type")
    if _falsy(document, type_node):
        raise Error("Message is missing the 'type' property")
    if document.kind(type_node) != JsonKind.STRING:
        raise Error(
            "Message is expects the 'type' property to be a string, but got "
            + extended_typeof(document, type_node)
        )
    var type_text = document.string_value(type_node)
    var type = MessageType.from_text(type_text)
    if not type.is_valid():
        raise Error("Invalid message 'type' property " + _quote(type_text))
    var payload = document.find(root, "payload")
    var id = String()
    if type.value <= MessageType.PONG.value:
        if not _nullish(document, payload) and not _is_object(
            document, payload
        ):
            raise Error(
                _quote(type_text)
                + " message expects the 'payload' property to be an object"
                " or nullish or missing, but got "
                + _quote(_js_string(document, payload))
            )
    else:
        id = _check_id(document, root, type_text)
    if type == MessageType.SUBSCRIBE or type == MessageType.NEXT:
        if not _is_object(document, payload):
            raise Error(
                _quote(type_text)
                + " message expects the 'payload' property to be an object,"
                " but got "
                + extended_typeof(document, payload)
            )
    if type == MessageType.SUBSCRIBE:
        var query = document.find(payload, "query")
        if query == NO_NODE or document.kind(query) != JsonKind.STRING:
            raise Error(
                _quote(type_text)
                + " message payload expects the 'query' property to be a"
                " string, but got "
                + extended_typeof(document, query)
            )
        _optional_object(document, payload, "variables", type_text)
        var name = document.find(payload, "operationName")
        if (
            not _nullish(document, name)
            and document.kind(name) != JsonKind.STRING
        ):
            raise Error(
                _quote(type_text)
                + " message payload expects the 'operationName' property to"
                " be a string or nullish or missing, but got "
                + extended_typeof(document, name)
            )
        _optional_object(document, payload, "extensions", type_text)
    if type == MessageType.ERROR and not _formatted_errors(document, payload):
        raise Error(
            _quote(type_text)
            + " message expects the 'payload' property to be an array of"
            " GraphQL errors, but got "
            + (
                "undefined" if payload
                == NO_NODE else stringify(document, payload)
            )
        )
    if _nullish(document, payload):
        payload = NO_NODE
    return ProtocolMessage(type, id, document^, payload)


def parse_message(text: StringSlice) raises -> ProtocolMessage:
    """Parse and check the JSON text of a message, as graphql-ws
    `parseMessage`.

    Args:
        text: The text of a WebSocket message.

    Returns:
        The message.

    Raises:
        Error: For text that is not JSON, and as `validate_message`.
    """
    var document = parse(text)
    return validate_message(document^)


def _start(mut out: List[UInt8], id: StringSlice):
    """Write `{"id":"<id>",`."""
    out.extend(StaticString('{"id":').as_bytes())
    write_string(out, id.as_bytes())
    out.append(44)


def _text(var out: List[UInt8]) -> String:
    """Make the text of a message."""
    return String(unsafe_from_utf8=out^)


def payload_message(type: MessageType, payload: StringSlice = "") -> String:
    """Write a `connection_init`, `connection_ack`, `ping` or `pong`.

    Args:
        type: The type.
        payload: The JSON text of the payload object, or empty for none.

    Returns:
        The text, such as `{"type":"ping"}`.
    """
    var out = List[UInt8](capacity=32 + payload.byte_length())
    out.extend(StaticString('{"type":"').as_bytes())
    out.extend(type.text().as_bytes())
    out.append(34)
    if payload.byte_length() > 0:
        out.extend(StaticString(',"payload":').as_bytes())
        out.extend(payload.as_bytes())
    out.append(125)
    return _text(out^)


def id_message(
    type: MessageType, id: StringSlice, payload: StringSlice = ""
) -> String:
    """Write a `subscribe`, `next`, `error` or `complete`, with its id
    first, as graphql-ws writes `{ id, type, payload }`.

    Args:
        type: The type.
        id: The id of the operation.
        payload: The JSON text of the payload, or empty for `complete`.

    Returns:
        The text, such as `{"id":"1","type":"complete"}`.
    """
    var out = List[UInt8](
        capacity=40 + id.byte_length() + payload.byte_length()
    )
    _start(out, id)
    out.extend(StaticString('"type":"').as_bytes())
    out.extend(type.text().as_bytes())
    out.append(34)
    if payload.byte_length() > 0:
        out.extend(StaticString(',"payload":').as_bytes())
        out.extend(payload.as_bytes())
    out.append(125)
    return _text(out^)


def error_payload(message: StringSlice) -> String:
    """Write the payload of an `error` with one GraphQL error.

    Args:
        message: The message of the error.

    Returns:
        The text `[{"message":"..."}]`.
    """
    var out = List[UInt8]()
    out.extend(StaticString('[{"message":').as_bytes())
    write_string(out, message.as_bytes())
    out.extend(StaticString("}]").as_bytes())
    return _text(out^)
