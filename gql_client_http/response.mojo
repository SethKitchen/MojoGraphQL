# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The response parsing of the HTTP link: the results of a `multipart/mixed`
response, and the check of a JSON response.

Port of Apollo Client 4.3.3 `src/link/http/parseAndCheckHttpResponse.ts`:
`readMultipartBody`, the boundary and the part checks of
`consumeMultipartBody`, `parseJsonEncoding`, `parseResponse` and
`parseAndCheckHttpResponse`.

`MultipartBodyReader` takes the bytes of a response as they arrive and
gives the results, each a `JsonDocument`. A result of the multipart
subscription protocol (`{"payload": ...}`) gives its payload, and its
`errors` are the protocol errors. Give each result of an incremental
request to the `handle` of a request of `gql_client.incremental`.

Differences from upstream:

- The bytes of the parts are read by `MultipartDecoder` of `gql_http`,
  which reads RFC 2046 parts as meros does. Upstream splits the text at
  each `\\r\\n--boundary` and reads a part that has no header line as
  text that is not JSON; `MultipartDecoder` reads its body.
- The errors are `Error`s with the upstream messages. `ServerError`,
  `ServerParseError` and `CombinedProtocolErrors` are not classes: a
  parse error has the message of `gql_json`, and the protocol errors are
  `MultipartResult.protocol_errors`.
- A payload that is not an object gives `{}`. Upstream spreads it, so an
  array or a string gives its indices as keys.
- `parse_and_check_http_response` takes the status, the content type and
  the text of the response, and one operation name: batches are not
  ported.
"""

from gql_http.multipart import MultipartDecoder
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument, JsonKind, NO_NODE


comptime _QUOTE = UInt8(ord("'"))
comptime _DOUBLE_QUOTE = UInt8(ord('"'))
comptime _SEMICOLON = UInt8(ord(";"))


def _is_space(byte: UInt8) -> Bool:
    """Return True for an ASCII byte of the `\\s` class."""
    return byte == 32 or (byte >= 9 and byte <= 13)


def _ends_parameter(bytes: Span[UInt8, _], start: Int) -> Bool:
    """Tell if `\\s*(?:;|$)` matches at a position."""
    var position = start
    while position < len(bytes) and _is_space(bytes[position]):
        position += 1
    return position == len(bytes) or bytes[position] == _SEMICOLON


def _boundary_at(bytes: Span[UInt8, _], start: Int) -> Optional[String]:
    """Match `\\s*boundary=(?:'([^']+)'|"([^"]+)"|([^"'].+?))\\s*(?:;|$)`,
    case insensitively, after a `;`."""
    var position = start
    while position < len(bytes) and _is_space(bytes[position]):
        position += 1
    var name = "boundary=".as_bytes()
    if position + len(name) > len(bytes):
        return None
    var index = 0
    while index < len(name):
        var byte = bytes[position + index]
        if byte >= 65 and byte <= 90:
            byte += 32
        if byte != name[index]:
            return None
        index += 1
    var value = position + len(name)
    if value == len(bytes):
        return None
    var first = bytes[value]
    if first == _QUOTE or first == _DOUBLE_QUOTE:
        var close = value + 1
        while close < len(bytes) and bytes[close] != first:
            close += 1
        if (
            close < len(bytes)
            and close > value + 1
            and _ends_parameter(bytes, close + 1)
        ):
            return String(unsafe_from_utf8=bytes[value + 1 : close])
        return None
    # `[^"'].+?`: at least two bytes, and `.` stops at a line end.
    var end = value + 2
    while end <= len(bytes):
        var last = bytes[end - 1]
        if last == 10 or last == 13:
            return None
        if _ends_parameter(bytes, end):
            return String(unsafe_from_utf8=bytes[value:end])
        end += 1
    return None


def boundary_from_content_type(content_type: StringSlice) -> String:
    """Return the boundary of a `multipart/mixed` content type, as
    `consumeMultipartBody` reads it.

    Args:
        content_type: The `content-type` value of the response.

    Returns:
        The first `boundary` parameter that matches, or `-` when none does.
    """
    var bytes = content_type.as_bytes()
    var index = 0
    while index < len(bytes):
        if bytes[index] == _SEMICOLON:
            var found = _boundary_at(bytes, index + 1)
            if found:
                return found.value()
        index += 1
    return String("-")


def parse_json_encoding(
    status: Int, body_text: StringSlice
) raises -> JsonDocument:
    """Parse a response body, as upstream `parseJsonEncoding`.

    Args:
        status: The HTTP status code.
        body_text: The body.

    Returns:
        The JSON document.

    Raises:
        Error: `Response not successful: Received status code N` for a
            status of 300 or more, or the parse error of the body.
    """
    if status >= 300:
        raise Error(
            String("Response not successful: Received status code ", status)
        )
    try:
        return parse_json(body_text)
    except e:
        raise Error(String(e))


def parse_and_check_http_response(
    operation_name: StringSlice,
    status: Int,
    content_type: StringSlice,
    body_text: StringSlice,
) raises -> JsonDocument:
    """Parse and check a JSON response, as `parseAndCheckHttpResponse`.

    A `application/graphql-response+json` body is parsed whatever the
    status is. Another body must have a status below 300.

    Args:
        operation_name: The name of the operation.
        status: The HTTP status code.
        content_type: The `content-type` value, or empty.
        body_text: The body.

    Returns:
        The result: an array, or an object with `data` or `errors`.

    Raises:
        Error: For the errors of `parse_json_encoding`, or `Server
            response was malformed for query 'name'.`
    """
    var result: JsonDocument
    if "application/graphql-response+json" in content_type:
        try:
            result = parse_json(body_text)
        except e:
            raise Error(String(e))
    else:
        result = parse_json_encoding(status, body_text)
    var kind = result.kind(result.root)
    if kind == JsonKind.ARRAY:
        return result^
    if kind == JsonKind.OBJECT and (
        result.find(result.root, "data") != NO_NODE
        or result.find(result.root, "errors") != NO_NODE
    ):
        return result^
    raise Error(
        String(
            "Server response was malformed for query '", operation_name, "'."
        )
    )


struct MultipartResult(Movable):
    """One result of a `multipart/mixed` response."""

    var result: JsonDocument
    """The result, or the payload of a subscription result."""
    var protocol_errors: Optional[JsonDocument]
    """The `errors` of a subscription result (upstream
    `CombinedProtocolErrors`), or None."""

    def __init__(
        out self,
        var result: JsonDocument,
        var protocol_errors: Optional[JsonDocument],
    ):
        """Make a result.

        Args:
            result: The result.
            protocol_errors: The protocol errors, or None.
        """
        self.result = result^
        self.protocol_errors = protocol_errors^


def _key_count(result: JsonDocument) raises -> Int:
    """Return `Object.keys(result).length`."""
    var kind = result.kind(result.root)
    if kind == JsonKind.NULL:
        raise Error("Cannot convert undefined or null to object")
    if kind == JsonKind.OBJECT or kind == JsonKind.ARRAY:
        return result.length(result.root)
    if kind == JsonKind.STRING:
        return result.string_value(result.root).byte_length()
    return 0


def _unwrap_payload(result: JsonDocument) -> MultipartResult:
    """Return the payload of a subscription result, as `{...payload}`, with
    `extensions` when the result has `errors`."""
    var out = JsonDocument()
    out.root = out.add_object()
    var errors = result.find(result.root, "errors")
    var payload = result.find(result.root, "payload")
    var has_extensions = False
    if result.kind(payload) == JsonKind.OBJECT:
        var member = result.first(payload)
        while member != NO_NODE:
            var key = result.key(member)
            if errors != NO_NODE and key == "extensions":
                out.add_member(out.root, key, _spread(out, result, member))
                has_extensions = True
            else:
                out.add_member(out.root, key, out.add_copy(result, member))
            member = result.next(member)
    if errors == NO_NODE:
        return MultipartResult(out^, None)
    if not has_extensions:
        out.add_member(out.root, "extensions", out.add_object())
    var protocol = JsonDocument()
    if result.kind(errors) == JsonKind.NULL:
        protocol.root = protocol.add_array()
    else:
        protocol.root = protocol.add_copy(result, errors)
    return MultipartResult(out^, protocol^)


def _spread(mut out: JsonDocument, source: JsonDocument, node: Int) -> Int:
    """Copy `{...value}`: the members of an object, or `{}`."""
    if source.kind(node) == JsonKind.OBJECT:
        return out.add_copy(source, node)
    return out.add_object()


struct MultipartBodyReader(Movable):
    """Reads the results of a `multipart/mixed` response as its bytes
    arrive: upstream `readMultipartBody`."""

    var decoder: MultipartDecoder
    """The reader of the parts."""
    var status: Int
    """The HTTP status code of the response."""
    var stopped: Bool
    """Whether a `{"payload": null}` result ended the reading."""

    def __init__(out self, content_type: StringSlice, status: Int = 200):
        """Start reading a response.

        Args:
            content_type: The `content-type` value of the response.
            status: The HTTP status code.
        """
        self.decoder = MultipartDecoder(
            boundary_from_content_type(content_type)
        )
        self.status = status
        self.stopped = False

    def feed(mut self, data: Span[UInt8, _]) raises -> List[MultipartResult]:
        """Read more bytes of the response.

        Args:
            data: The bytes, in the order they arrived.

        Returns:
            The results of the parts that the bytes complete. A result
            that is an empty object is not given.

        Raises:
            Error: `Unsupported patch content type: application/json is
                required.` for a part that is not JSON, or the errors of
                `parse_json_encoding`, or of `MultipartDecoder`.
        """
        var out = List[MultipartResult]()
        if self.stopped:
            return out^
        try:
            _ = self.decoder.feed(data)
        except e:
            raise Error(String(e))
        var parts = self.decoder.take()
        var index = 0
        while index < len(parts):
            ref part = parts[index]
            index += 1
            var content_type = String(part.content_type.strip()).lower()
            if content_type.byte_length() > 0 and (
                "application/json" not in content_type
            ):
                raise Error(
                    "Unsupported patch content type: application/json is"
                    " required."
                )
            var result = parse_json_encoding(self.status, part.text())
            if _key_count(result) == 0:
                continue
            var payload = NO_NODE
            if result.kind(result.root) == JsonKind.OBJECT:
                payload = result.find(result.root, "payload")
            if payload == NO_NODE:
                out.append(MultipartResult(result^, None))
                continue
            if result.length(result.root) == 1 and (
                result.kind(payload) == JsonKind.NULL
            ):
                self.stopped = True
                return out^
            out.append(_unwrap_payload(result))
        return out^

    def finish(self) raises:
        """Check the end of the response, when the body has ended.

        Raises:
            Error: `premature end of multipart body` when the close
                delimiter did not arrive.
        """
        if self.stopped or self.decoder.done():
            return
        raise Error("premature end of multipart body")
