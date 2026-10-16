# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""JSON-RPC 2.0 messages of the Model Context Protocol.

The rules are those of JSON-RPC 2.0 and of the MCP specification
(2025-06-18, "Base Protocol"), with the choices that Apollo MCP Server
2.0.0 makes through its SDK. The project observed these choices on the
upstream binary, because the SDK (`rmcp`) is Apache-2.0 only: this module
ports no code.

- A message is one JSON object. An array (a batch), another value, a
  missing or wrong `jsonrpc`, a `method` that is not a string, and
  `params` that are not an object or `null` make an invalid request. The
  reply is `{"code":-32600,"message":"Invalid request"}`, without an `id`.
- An `id` is an integer or a string. A message with an `id` of another
  kind (`null`, a fraction, a Boolean) gets no reply.
- A message with `result` or `error` and no `method` is a response of the
  client; the server ignores it.
- Text that is not JSON gets no reply over stdio.

Differences from upstream: none known.
"""

from gql_json.parser import parse
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_json.writer import write_string

comptime JSONRPC_VERSION = "2.0"
"""The value of the `jsonrpc` member."""
comptime INVALID_REQUEST_MESSAGE = "Invalid request"
"""The message of the reply to an invalid request."""


struct ErrorCode(Equatable, ImplicitlyCopyable):
    """A JSON-RPC error code."""

    var value: Int
    """The code."""

    comptime PARSE_ERROR = ErrorCode(-32700)
    """The text is not JSON."""
    comptime INVALID_REQUEST = ErrorCode(-32600)
    """The JSON is not a valid request."""
    comptime METHOD_NOT_FOUND = ErrorCode(-32601)
    """The method does not exist, or its params do not fit it."""
    comptime INVALID_PARAMS = ErrorCode(-32602)
    """The params are not valid."""
    comptime INTERNAL_ERROR = ErrorCode(-32603)
    """The server failed."""

    def __init__(out self, value: Int):
        """Make a code.

        Args:
            value: The code.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return whether the code is a predefined code or a server code.

        Returns:
            True for -32700, -32600 to -32603, and -32099 to -32000.
        """
        return (
            self.value == -32700
            or (self.value >= -32603 and self.value <= -32600)
            or (self.value >= -32099 and self.value <= -32000)
        )


struct MessageKind(Equatable, ImplicitlyCopyable):
    """What a received message is."""

    var value: UInt8
    """The kind's number."""

    comptime REQUEST = MessageKind(0)
    """A request: it has an `id` and a `method`."""
    comptime NOTIFICATION = MessageKind(1)
    """A notification: it has a `method` and no `id`."""
    comptime RESPONSE = MessageKind(2)
    """A response of the client; the server ignores it."""
    comptime INVALID = MessageKind(3)
    """JSON that is not a valid message."""
    comptime IGNORED = MessageKind(4)
    """A request with an `id` that is not an integer or a string."""
    comptime MALFORMED = MessageKind(5)
    """Text that is not JSON."""

    def __init__(out self, value: UInt8):
        """Make a kind from its number.

        Args:
            value: The number.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return whether the kind is one of the six kinds.

        Returns:
            True for the six kinds.
        """
        return self.value <= 5


struct Message(Movable):
    """One received JSON-RPC message."""

    var kind: MessageKind
    """What the message is."""
    var document: JsonDocument
    """The parsed JSON; empty for a `MALFORMED` message."""
    var id: String
    """The JSON text of the `id`, as the reply writes it; empty when there
    is none."""
    var method: String
    """The `method`; empty when there is none."""
    var params: Int
    """The `params` object, or `NO_NODE` when it is absent or `null`."""
    var error: String
    """The parse error of a `MALFORMED` message."""

    def __init__(out self, kind: MessageKind, var document: JsonDocument):
        """Make a message without an id, a method or params.

        Args:
            kind: What the message is.
            document: The parsed JSON.
        """
        self.kind = kind
        self.document = document^
        self.id = String()
        self.method = String()
        self.params = NO_NODE
        self.error = String()


def parse_message(text: StringSlice) -> Message:
    """Parse and classify one message.

    Args:
        text: The JSON text of the message.

    Returns:
        The message. Its `kind` tells how to answer it.
    """
    var document: JsonDocument
    try:
        document = parse(text)
    except e:
        var malformed = Message(MessageKind.MALFORMED, JsonDocument())
        malformed.error = e.message.copy()
        return malformed^
    var message = Message(MessageKind.INVALID, document^)
    ref doc = message.document
    var root = doc.root
    if doc.kind(root) != JsonKind.OBJECT:
        return message^
    var version = doc.find(root, "jsonrpc")
    if version == NO_NODE or doc.kind(version) != JsonKind.STRING:
        return message^
    if doc.string_value(version) != JSONRPC_VERSION:
        return message^
    var id = doc.find(root, "id")
    var method = doc.find(root, "method")
    if method == NO_NODE:
        if id != NO_NODE and (
            doc.find(root, "result") != NO_NODE
            or doc.find(root, "error") != NO_NODE
        ):
            message.kind = MessageKind.RESPONSE
        return message^
    if doc.kind(method) != JsonKind.STRING:
        return message^
    var params = doc.find(root, "params")
    if params != NO_NODE:
        var kind = doc.kind(params)
        if kind == JsonKind.OBJECT:
            message.params = params
        elif kind != JsonKind.NULL:
            return message^
    message.method = doc.string_value(method)
    if id == NO_NODE:
        message.kind = MessageKind.NOTIFICATION
        return message^
    var id_kind = doc.kind(id)
    if id_kind == JsonKind.STRING:
        var out = List[UInt8]()
        write_string(out, doc.string_value(id).as_bytes())
        message.id = String(unsafe_from_utf8=out^)
    elif id_kind == JsonKind.NUMBER and is_integer_id(doc.text(id)):
        message.id = String(doc.text(id))
    else:
        message.kind = MessageKind.IGNORED
        return message^
    message.kind = MessageKind.REQUEST
    return message^


def is_integer_id(text: StringSlice) -> Bool:
    """Return whether a JSON number is an `i64` or a `u64`, as an id must be.

    Args:
        text: The JSON text of the number.

    Returns:
        True for an integer without a fraction or an exponent, from
        -9223372036854775808 to 18446744073709551615.
    """
    var bytes = text.as_bytes()
    var negative = bytes[0] == UInt8(ord("-"))
    var start = 1 if negative else 0
    var index = start
    while index < len(bytes):
        var byte = bytes[index]
        if byte < UInt8(ord("0")) or byte > UInt8(ord("9")):
            return False
        index += 1
    var digits = String(text)[byte=start:]
    var limit = "9223372036854775808" if negative else "18446744073709551615"
    if digits.byte_length() != limit.byte_length():
        return digits.byte_length() < limit.byte_length()
    return digits <= limit


def result_message(id: StringSlice, result: StringSlice) -> String:
    """Return the JSON text of a successful response.

    Args:
        id: The JSON text of the request's `id`.
        result: The JSON text of the result.

    Returns:
        `{"jsonrpc":"2.0","id":<id>,"result":<result>}`.
    """
    var out = List[UInt8](capacity=result.byte_length() + 40)
    out.extend('{"jsonrpc":"2.0","id":'.as_bytes())
    out.extend(id.as_bytes())
    out.extend(',"result":'.as_bytes())
    out.extend(result.as_bytes())
    out.append(UInt8(ord("}")))
    return String(unsafe_from_utf8=out^)


def error_message(
    id: StringSlice, code: ErrorCode, message: StringSlice
) -> String:
    """Return the JSON text of an error response.

    Args:
        id: The JSON text of the request's `id`; empty for none.
        code: The error code.
        message: The error message.

    Returns:
        `{"jsonrpc":"2.0","id":<id>,"error":{"code":<code>,"message":<message>}}`,
        without `id` when it is empty.
    """
    var out = List[UInt8](capacity=message.byte_length() + 64)
    out.extend('{"jsonrpc":"2.0",'.as_bytes())
    if id.byte_length() > 0:
        out.extend('"id":'.as_bytes())
        out.extend(id.as_bytes())
        out.append(UInt8(ord(",")))
    out.extend('"error":{"code":'.as_bytes())
    out.extend(String(code.value).as_bytes())
    out.extend(',"message":'.as_bytes())
    write_string(out, message.as_bytes())
    out.extend("}}".as_bytes())
    return String(unsafe_from_utf8=out^)


def invalid_request_message() -> String:
    """Return the reply to an invalid request.

    Returns:
        The error response with code -32600 and no `id`.
    """
    return error_message("", ErrorCode.INVALID_REQUEST, INVALID_REQUEST_MESSAGE)
