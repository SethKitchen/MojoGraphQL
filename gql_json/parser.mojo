# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A strict RFC 8259 JSON parser.

`parse` reads a JSON text into a `JsonDocument`. It accepts exactly the
grammar of RFC 8259: no comments, no trailing commas, no `NaN` or
`Infinity`, no leading zeros, no single quotes, and only the escapes of
the RFC. The input must be UTF-8. The parser checks each byte of a string
that is 0x80 or more, and refuses an invalid sequence, an overlong form, a
surrogate, and a code point above U+10FFFF. Any value can be the top level
value, as in RFC 8259 and ECMAScript `JSON.parse`.

The parser is not recursive: it keeps the open arrays and objects on a
stack, so a deep input cannot overflow the call stack. `max_depth` limits
the nesting.

The parser copies the input once, into the document, with `PADDING` zero
bytes after it. SIMD finders skip white space and string bytes 32 at a
time, and the zero bytes stop them at the end of the input.

This module has no upstream counterpart. It follows RFC 8259 and the
ECMAScript `JSON.parse` grammar, and it passes the JSONTestSuite of
Nicolas Seriot (MIT).

Differences from upstream (ECMAScript `JSON.parse`):

- A `\\u` escape of a lone surrogate, such as `"\\uD800"`, is an error.
  `JSON.parse` accepts it, but a Mojo `String` is valid UTF-8 and cannot
  hold it.
- A byte order mark at the start is an error, as in `JSON.parse`, and
  invalid UTF-8 is an error. `JSON.parse` reads a string, not bytes.
- `max_depth` (default 1000) limits the nesting; `JSON.parse` has no limit
  but its call stack. `max_length` limits the input, at most 2 GiB.
- The error messages are not the V8 messages.
"""

from gql_json.error import JsonError
from gql_json.scan import PADDING, scan_string, skip_whitespace
from gql_json.value import (
    FLAG_CANONICAL,
    FLAG_ESCAPED,
    FLAG_KEY_ESCAPED,
    FLAG_TRUE,
    JsonDocument,
    JsonKind,
    JsonNode,
    NO_NODE,
    is_canonical_number,
    number_end,
    read_hex4,
)

comptime DEFAULT_MAX_DEPTH = 1000
"""The default limit on nested arrays and objects."""
comptime MAX_LENGTH = 2_147_483_647 - PADDING
"""The largest input, in bytes: node offsets are 32-bit."""


def parse(
    text: StringSlice,
    max_depth: Int = DEFAULT_MAX_DEPTH,
    max_length: Int = MAX_LENGTH,
) raises JsonError -> JsonDocument:
    """Parse a JSON text.

    Args:
        text: The JSON text.
        max_depth: The deepest nesting of arrays and objects to accept.
        max_length: The longest input to accept, in bytes. A value above
            `MAX_LENGTH` counts as `MAX_LENGTH`.

    Returns:
        The document; its root is node 0.

    Raises:
        JsonError: If the text is not valid JSON, if it nests deeper than
            `max_depth`, if `max_depth` is negative, or if the text is
            longer than `max_length`.
    """
    var source = text.as_bytes()
    var bytes = List[UInt8](capacity=len(source) + PADDING)
    bytes.extend(source)
    return parse_bytes(bytes^, max_depth, max_length)


def parse_bytes(
    var bytes: List[UInt8],
    max_depth: Int = DEFAULT_MAX_DEPTH,
    max_length: Int = MAX_LENGTH,
) raises JsonError -> JsonDocument:
    """Parse a JSON text from UTF-8 bytes, and keep the bytes.

    Args:
        bytes: The JSON text; the document takes it.
        max_depth: The deepest nesting of arrays and objects to accept.
        max_length: The longest input to accept, in bytes. A value above
            `MAX_LENGTH` counts as `MAX_LENGTH`.

    Returns:
        The document; its root is node 0.

    Raises:
        JsonError: If the bytes are not valid UTF-8 JSON, if they nest
            deeper than `max_depth`, if `max_depth` is negative, or if the
            input is longer than `max_length`.
    """
    var length = len(bytes)
    if max_depth < 0:
        raise JsonError(String("max_depth must not be negative: ", max_depth))
    var limit = min(max_length, MAX_LENGTH)
    if length > limit:
        raise JsonError(
            String(
                "The input is too large: ",
                length,
                " bytes; the limit is ",
                limit,
            )
        )
    bytes.resize(length + PADDING, 0)
    var nodes = List[JsonNode](capacity=length // 16 + 4)
    _parse(Span(bytes), length, max_depth, nodes)
    bytes.resize(length, 0)
    return JsonDocument(bytes^, nodes^)


@inline(.never)
def _unexpected(data: Span[UInt8, _], length: Int, position: Int) -> JsonError:
    """Return the error for an unexpected byte, or the end of the input."""
    var input = data[0:length]
    if position >= length:
        return JsonError("Unexpected end of input", input, position)
    var byte = data[position]
    if byte >= 0x21 and byte <= 0x7E:
        return JsonError(
            String("Unexpected character '", chr(Int(byte)), "'"),
            input,
            position,
        )
    return JsonError(
        String("Unexpected byte 0x", hex(Int(byte), prefix="")),
        input,
        position,
    )


@inline(.never)
def _error(
    message: StringSlice, data: Span[UInt8, _], length: Int, position: Int
) -> JsonError:
    """Return an error at a position of the input."""
    return JsonError(String(message), data[0:length], position)


@always_inline
def _space(data: Span[UInt8, _], position: Int) -> Int:
    """Skip white space; most tokens have none or one space before them."""
    if data.unsafe_ptr()[unsafe_offset=position] > 0x20:
        return position
    return skip_whitespace(data, position)


def _matches(data: Span[UInt8, _], position: Int, word: StaticString) -> Bool:
    """Return True if a literal word starts at a position."""
    var bytes = word.as_bytes()
    var index = 1
    while index < len(bytes):
        if data.unsafe_ptr()[unsafe_offset=position + index] != bytes[index]:
            return False
        index += 1
    return True


@always_inline
def _continuation(byte: UInt8) -> Bool:
    """Return True for a UTF-8 continuation byte."""
    return byte & 0xC0 == 0x80


def _check_utf8(
    data: Span[UInt8, _], length: Int, position: Int
) raises JsonError -> Int:
    """Check the UTF-8 sequence that starts with a byte of 0x80 or more.

    Returns:
        The offset after the sequence.
    """
    var bytes = data.unsafe_ptr()
    var lead = bytes[unsafe_offset=position]
    var second = bytes[unsafe_offset=position + 1]
    if lead >= 0xC2 and lead <= 0xDF:
        if _continuation(second):
            return position + 2
    elif lead >= 0xE0 and lead <= 0xEF:
        # E0 needs A0 or more (no overlong form); ED needs 9F or less (no
        # surrogate).
        var low: UInt8 = 0xA0 if lead == 0xE0 else 0x80
        var high: UInt8 = 0x9F if lead == 0xED else 0xBF
        if (
            second >= low
            and second <= high
            and _continuation(bytes[unsafe_offset=position + 2])
        ):
            return position + 3
    elif lead >= 0xF0 and lead <= 0xF4:
        # F0 needs 90 or more (no overlong form); F4 needs 8F or less (no
        # code point above U+10FFFF).
        var low: UInt8 = 0x90 if lead == 0xF0 else 0x80
        var high: UInt8 = 0x8F if lead == 0xF4 else 0xBF
        if (
            second >= low
            and second <= high
            and _continuation(bytes[unsafe_offset=position + 2])
            and _continuation(bytes[unsafe_offset=position + 3])
        ):
            return position + 4
    raise _error("Invalid UTF-8", data, length, position)


def _check_escape(
    data: Span[UInt8, _], length: Int, position: Int
) raises JsonError -> Int:
    """Check the escape that starts with the backslash at a position.

    Returns:
        The offset after the escape.
    """
    var bytes = data.unsafe_ptr()
    var escape = bytes[unsafe_offset=position + 1]
    if escape == UInt8(ord("u")):
        var code = read_hex4(data, position + 2)
        if code < 0:
            raise _error("Invalid \\u escape", data, length, position)
        if code >= 0xDC00 and code <= 0xDFFF:
            raise _error(
                "Lone surrogate in a \\u escape", data, length, position
            )
        if code < 0xD800 or code > 0xDBFF:
            return position + 6
        if bytes[unsafe_offset=position + 6] == UInt8(ord("\\")) and bytes[
            unsafe_offset=position + 7
        ] == UInt8(ord("u")):
            var low = read_hex4(data, position + 8)
            if low >= 0xDC00 and low <= 0xDFFF:
                return position + 12
        raise _error("Lone surrogate in a \\u escape", data, length, position)
    if (
        escape == UInt8(ord('"'))
        or escape == UInt8(ord("\\"))
        or escape == UInt8(ord("/"))
        or escape == UInt8(ord("b"))
        or escape == UInt8(ord("f"))
        or escape == UInt8(ord("n"))
        or escape == UInt8(ord("r"))
        or escape == UInt8(ord("t"))
    ):
        return position + 2
    raise _error("Invalid escape", data, length, position)


def _read_string(
    data: Span[UInt8, _], length: Int, start: Int, mut escaped: Bool
) raises JsonError -> Int:
    """Check a string whose opening quote is at `start - 1`.

    Args:
        data: The padded input.
        length: The input length.
        start: The offset after the opening quote.
        escaped: Set to True when the string has an escape.

    Returns:
        The offset of the closing quote.
    """
    var bytes = data.unsafe_ptr()
    var position = start
    while True:
        position = scan_string(data, position)
        var byte = bytes[unsafe_offset=position]
        if byte == UInt8(ord('"')):
            return position
        if byte == UInt8(ord("\\")):
            escaped = True
            position = _check_escape(data, length, position)
        elif byte >= 0x80:
            position = _check_utf8(data, length, position)
        elif position >= length:
            raise _error("Unterminated string", data, length, start - 1)
        else:
            raise _error(
                "Control character in a string", data, length, position
            )


@always_inline
def _push(
    mut nodes: List[JsonNode],
    parent: Int,
    var node: JsonNode,
) -> Int:
    """Append a node and make it the last child of `parent`, if any."""
    var index = len(nodes)
    nodes.append(node)
    if parent != NO_NODE:
        var all = nodes.unsafe_ptr()
        ref container = all[unsafe_offset=parent]
        var last = Int(container.end)
        container.end = Int32(index)
        container.count += 1
        if last == NO_NODE:
            container.start = Int32(index)
        else:
            all[unsafe_offset=last].next = Int32(index)
    return index


def _parse(
    data: Span[UInt8, _],
    length: Int,
    max_depth: Int,
    mut nodes: List[JsonNode],
) raises JsonError:
    """Parse the padded input into nodes, in preorder."""
    var bytes = data.unsafe_ptr()
    var stack = List[Int]()
    var parent = NO_NODE
    var in_object = False
    var key_start = 0
    var key_end = 0
    var key_flags: UInt8 = 0
    var position = _space(data, 0)
    while True:
        # A value starts at `position`.
        var byte = bytes[unsafe_offset=position]
        if byte == UInt8(ord('"')):
            var escaped = False
            var end = _read_string(data, length, position + 1, escaped)
            _ = _push(
                nodes,
                parent,
                JsonNode(
                    JsonKind.STRING,
                    key_flags | (FLAG_ESCAPED if escaped else 0),
                    Int32(position + 1),
                    Int32(end),
                    0,
                    Int32(key_start),
                    Int32(key_end),
                    Int32(NO_NODE),
                ),
            )
            position = end + 1
        elif byte == UInt8(ord("{")) or byte == UInt8(ord("[")):
            if len(stack) >= max_depth:
                raise _error(
                    "The input nests too deeply", data, length, position
                )
            var kind = (
                JsonKind.OBJECT if byte == UInt8(ord("{")) else JsonKind.ARRAY
            )
            var node = _push(
                nodes,
                parent,
                JsonNode(
                    kind,
                    key_flags,
                    Int32(NO_NODE),
                    Int32(NO_NODE),
                    0,
                    Int32(key_start),
                    Int32(key_end),
                    Int32(NO_NODE),
                ),
            )
            position = _space(data, position + 1)
            var close = byte + 2
            if bytes[unsafe_offset=position] == close:
                position += 1
            else:
                stack.append(node)
                parent = node
                in_object = kind == JsonKind.OBJECT
                key_start = 0
                key_end = 0
                key_flags = 0
                if in_object:
                    position = _read_key(
                        data, length, position, key_start, key_end, key_flags
                    )
                continue
        elif byte == UInt8(ord("-")) or (
            byte >= UInt8(ord("0")) and byte <= UInt8(ord("9"))
        ):
            var end = number_end(data[0:length], position)
            if end < 0:
                raise _error("Invalid number", data, length, position)
            var canonical = is_canonical_number(data[position:end])
            _ = _push(
                nodes,
                parent,
                JsonNode(
                    JsonKind.NUMBER,
                    key_flags | (FLAG_CANONICAL if canonical else 0),
                    Int32(position),
                    Int32(end),
                    0,
                    Int32(key_start),
                    Int32(key_end),
                    Int32(NO_NODE),
                ),
            )
            position = end
        else:
            var kind: JsonKind
            var flags: UInt8 = 0
            var size = 4
            if byte == UInt8(ord("t")) and _matches(data, position, "true"):
                kind = JsonKind.BOOLEAN
                flags = FLAG_TRUE
            elif byte == UInt8(ord("f")) and _matches(data, position, "false"):
                kind = JsonKind.BOOLEAN
                size = 5
            elif byte == UInt8(ord("n")) and _matches(data, position, "null"):
                kind = JsonKind.NULL
            else:
                raise _unexpected(data, length, position)
            _ = _push(
                nodes,
                parent,
                JsonNode(
                    kind,
                    key_flags | flags,
                    0,
                    0,
                    0,
                    Int32(key_start),
                    Int32(key_end),
                    Int32(NO_NODE),
                ),
            )
            position += size
        # A value ended: find a comma, or the end of the parent.
        while True:
            position = _space(data, position)
            if parent == NO_NODE:
                if position != length:
                    raise _unexpected(data, length, position)
                return
            var next = bytes[unsafe_offset=position]
            if next == UInt8(ord(",")):
                position = _space(data, position + 1)
                if in_object:
                    position = _read_key(
                        data, length, position, key_start, key_end, key_flags
                    )
                break
            var close = UInt8(ord("}")) if in_object else UInt8(ord("]"))
            if next != close:
                raise _unexpected(data, length, position)
            position += 1
            _ = stack.pop()
            if len(stack) == 0:
                parent = NO_NODE
            else:
                parent = stack[len(stack) - 1]
                in_object = (
                    nodes.unsafe_ptr()[unsafe_offset=parent].kind
                    == JsonKind.OBJECT
                )
                # An array item has no key; an object reads the next key
                # after its comma.
                key_start = 0
                key_end = 0
                key_flags = 0


def _read_key(
    data: Span[UInt8, _],
    length: Int,
    position: Int,
    mut key_start: Int,
    mut key_end: Int,
    mut key_flags: UInt8,
) raises JsonError -> Int:
    """Read a member's key and its colon.

    Returns:
        The offset of the member's value.
    """
    if data.unsafe_ptr()[unsafe_offset=position] != UInt8(ord('"')):
        raise _unexpected(data, length, position)
    var escaped = False
    key_start = position + 1
    key_end = _read_string(data, length, key_start, escaped)
    key_flags = FLAG_KEY_ESCAPED if escaped else 0
    var colon = _space(data, key_end + 1)
    if data.unsafe_ptr()[unsafe_offset=colon] != UInt8(ord(":")):
        raise _unexpected(data, length, colon)
    return _space(data, colon + 1)
