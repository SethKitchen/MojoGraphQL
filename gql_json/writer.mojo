# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Write JSON text as ECMAScript `JSON.stringify` writes it.

A `JsonWriter` appends JSON text to a byte list, one call per token:
`begin_object`, `key`, `string`, `end_object`, and so on. It puts the
commas, the colons and, with an indent, the line breaks. `stringify`
writes one value of a `JsonDocument`.

The output is the output of `JSON.stringify(value, null, indent)`:

- A string escapes `"` and `\\`, writes `\\b`, `\\f`, `\\n`, `\\r` and `\\t`,
  and writes every other control character below U+0020 as `\\u00XX` with
  lowercase hex. It writes every other code point as UTF-8, U+007F and
  U+2028 too.
- A number is written as `Number.prototype.toString` writes it: `1` and
  not `1.0`, the shortest digits that read back as the same `Float64`,
  and an exponent at 1e21 and above or below 1e-6. -0 gives `0`, and
  NaN and the infinities give `null`.
- With an indent, each member and item is on its own line, indented by
  `indent` spaces for each level (at most 10), and a key is followed by
  `": "`. An empty array or object is `[]` or `{}`.

This module has no upstream counterpart. It implements ECMAScript 2025
section 25.5.2 (`JSON.stringify`), which graphql-js responses go through.

Differences from upstream:

- `int` writes every `Int64` exactly. ECMAScript has no 64-bit integer,
  and `JSON.stringify` throws for a `BigInt`.
- A parsed number that is an integer of at most 15 digits is copied as it
  is; every other parsed number is read as a `Float64` and written again,
  as `JSON.stringify(JSON.parse(text))` does.
- The writer does not check the order of the calls. A key outside an
  object, or a missing `end_object`, gives text that is not JSON.
"""

from std.memory import unsafe_memcpy

from gql_json.number import read_float64, write_int, write_number
from gql_json.scan import find_escape
from gql_json.value import (
    FLAG_CANONICAL,
    FLAG_DECODED,
    FLAG_ESCAPED,
    FLAG_KEY_DECODED,
    FLAG_KEY_ESCAPED,
    FLAG_TRUE,
    JsonDocument,
    JsonKind,
    JsonNode,
    NO_NODE,
    append_codepoint,
    read_hex4,
)

comptime MAX_INDENT = 10
"""The largest indent, as in `JSON.stringify`."""
comptime _HEX = "0123456789abcdef"
"""The lowercase hex digits."""


def write_string(mut out: List[UInt8], text: Span[UInt8, _]):
    """Append a quoted, escaped JSON string.

    Args:
        out: The destination.
        text: The decoded value, as UTF-8.
    """
    out.append(UInt8(ord('"')))
    var end = len(text)
    var position = 0
    while True:
        var stop = find_escape(text, position, end)
        out.extend(text[position:stop])
        if stop == end:
            break
        _escape(out, text[stop])
        position = stop + 1
    out.append(UInt8(ord('"')))


def _escape(mut out: List[UInt8], byte: UInt8):
    """Append the escape of a quote, a backslash or a control character."""
    out.append(UInt8(ord("\\")))
    if byte == UInt8(ord('"')) or byte == UInt8(ord("\\")):
        out.append(byte)
    elif byte == 0x08:
        out.append(UInt8(ord("b")))
    elif byte == 0x0C:
        out.append(UInt8(ord("f")))
    elif byte == 0x0A:
        out.append(UInt8(ord("n")))
    elif byte == 0x0D:
        out.append(UInt8(ord("r")))
    elif byte == 0x09:
        out.append(UInt8(ord("t")))
    else:
        var hex = _HEX.as_bytes()
        out.extend("u00".as_bytes())
        out.append(hex[Int(byte >> 4)])
        out.append(hex[Int(byte & 15)])


struct JsonWriter(Movable):
    """Append JSON text, one token at a time, with `JSON.stringify`
    output."""

    var out: List[UInt8]
    """The text written so far."""
    var indent: Int
    """The spaces for each level, 0 to 10; 0 writes one line."""
    var _depth: Int
    """How many arrays and objects are open."""
    var _first: Bool
    """Whether the next value is the first in its array or object."""
    var _after_key: Bool
    """Whether a key was written, and its value was not."""

    def __init__(out self, indent: Int = 0, capacity: Int = 256):
        """Start an empty writer.

        Args:
            indent: The spaces for each level. As in `JSON.stringify`, a
                value below 0 counts as 0 and a value above 10 as 10.
            capacity: The bytes to reserve.
        """
        self.out = List[UInt8](capacity=capacity)
        self.indent = min(max(indent, 0), MAX_INDENT)
        self._depth = 0
        self._first = True
        self._after_key = False

    def take_bytes(deinit self) -> List[UInt8]:
        """Return the text written, and end the writer.

        Returns:
            The bytes.
        """
        return self.out^

    def take_string(deinit self) -> String:
        """Return the text written, and end the writer.

        Returns:
            The text.
        """
        return String(unsafe_from_utf8=self.out^)

    def clear(mut self):
        """Remove the text written, keep the buffer, and start again."""
        self.out.clear()
        self._depth = 0
        self._first = True
        self._after_key = False

    @always_inline
    def _prefix(mut self):
        """Write the comma and the line break before a value or a key."""
        if self._after_key:
            self._after_key = False
            return
        if self._depth > 0:
            if not self._first:
                self.out.append(UInt8(ord(",")))
            if self.indent > 0:
                self._newline(self._depth)
        self._first = False

    def _newline(mut self, depth: Int):
        """Write a line break and the indent of a level."""
        _newline(self.out, depth * self.indent)

    def _open(mut self, byte: UInt8):
        """Start an array or an object."""
        self._prefix()
        self.out.append(byte)
        self._depth += 1
        self._first = True

    def _close(mut self, byte: UInt8):
        """End an array or an object."""
        self._depth -= 1
        if self.indent > 0 and not self._first:
            self._newline(self._depth)
        self.out.append(byte)
        self._first = False

    def begin_object(mut self):
        """Start an object: write `{`."""
        self._open(UInt8(ord("{")))

    def end_object(mut self):
        """End an object: write `}`."""
        self._close(UInt8(ord("}")))

    def begin_array(mut self):
        """Start an array: write `[`."""
        self._open(UInt8(ord("[")))

    def end_array(mut self):
        """End an array: write `]`."""
        self._close(UInt8(ord("]")))

    def key(mut self, name: StringSlice):
        """Write the key of the next member of an object, and its colon.

        Args:
            name: The decoded key.
        """
        self._prefix()
        write_string(self.out, name.as_bytes())
        self._colon()

    def _colon(mut self):
        """Write the colon after a key."""
        self.out.append(UInt8(ord(":")))
        if self.indent > 0:
            self.out.append(0x20)
        self._after_key = True

    def string(mut self, text: StringSlice):
        """Write a string value.

        Args:
            text: The decoded value.
        """
        self._prefix()
        write_string(self.out, text.as_bytes())

    def int(mut self, value: Int64):
        """Write an integer value, exactly.

        Args:
            value: The value.
        """
        self._prefix()
        write_int(self.out, value)

    def float(mut self, value: Float64):
        """Write a number value, as `JSON.stringify` writes it.

        Args:
            value: The value; NaN and the infinities give `null`.
        """
        self._prefix()
        write_number(self.out, value)

    def bool(mut self, value: Bool):
        """Write `true` or `false`.

        Args:
            value: The value.
        """
        self._prefix()
        self.out.extend(("true" if value else "false").as_bytes())

    def null(mut self):
        """Write `null`."""
        self._prefix()
        self.out.extend("null".as_bytes())

    def raw(mut self, json: StringSlice):
        """Write a value that is JSON text already.

        The writer does not check the text, and does not indent it again.

        Args:
            json: One JSON value.
        """
        self._prefix()
        self.out.extend(json.as_bytes())

    def value(mut self, document: JsonDocument, node: Int):
        """Write a value of a document, and all that it holds.

        Args:
            document: The document.
            node: The value's index.
        """
        self._prefix()
        _write_value(self.out, document, node, self.indent, self._depth)


def _write_value(
    mut out: List[UInt8],
    document: JsonDocument,
    root: Int,
    indent: Int,
    base: Int,
):
    """Write a value and its descendants, at a nesting level `base`.

    The walk keeps the open containers on a stack: each entry is the
    parent and the next child to write after the current container ends.
    The common bytes go straight into the buffer: `size` is the length
    written, and the buffer is longer, with bytes not written yet. Escaped
    strings and numbers that need a new form go through the list helpers.
    """
    var nodes = document.nodes.unsafe_ptr()
    var source = document.bytes.unsafe_ptr()
    # With 32 spare bytes after the text, a short copy is one 32-byte load.
    var wide = document.bytes.capacity() - len(document.bytes) >= 32
    var found = nodes[unsafe_offset=root]
    if found.kind.value < JsonKind.ARRAY.value:
        _write_scalar(out, document, found)
        return
    var stack = List[Int](capacity=32)
    var parent = root
    var in_object = found.kind == JsonKind.OBJECT
    var child = document.first(root)
    var depth = base + 1
    var first = True
    var size = len(out)
    var bytes = _reserve(out, size, 1)
    bytes[unsafe_offset=size] = UInt8(ord("{")) if in_object else UInt8(
        ord("[")
    )
    size += 1
    while True:
        if child == NO_NODE:
            # The parent ends.
            depth -= 1
            bytes = _reserve(out, size, 2 + depth * indent)
            if indent > 0 and not first:
                size = _newline_at(bytes, size, depth * indent)
            bytes[unsafe_offset=size] = UInt8(ord("}")) if in_object else UInt8(
                ord("]")
            )
            size += 1
            if len(stack) == 0:
                out.shrink(size)
                return
            child = stack.pop()
            parent = stack.pop()
            in_object = nodes[unsafe_offset=parent].kind == JsonKind.OBJECT
            first = False
            continue
        found = nodes[unsafe_offset=child]
        var key_length = Int(found.key_end - found.key_start)
        var text_length = 0
        if found.kind.value < JsonKind.ARRAY.value:
            text_length = Int(found.end - found.start)
        bytes = _reserve(
            out, size, 48 + depth * indent + key_length + text_length
        )
        if not first:
            bytes[unsafe_offset=size] = UInt8(ord(","))
            size += 1
        if indent > 0:
            size = _newline_at(bytes, size, depth * indent)
        first = False
        if in_object:
            if found.flags & (FLAG_KEY_ESCAPED | FLAG_KEY_DECODED) == 0:
                size = _quoted_at(
                    bytes,
                    size,
                    source,
                    Int(found.key_start),
                    key_length,
                    wide,
                )
            else:
                out.shrink(size)
                _write_stored(
                    out,
                    document,
                    Int(found.key_start),
                    Int(found.key_end),
                    found.flags & FLAG_KEY_ESCAPED != 0,
                    True,
                )
                size = len(out)
                bytes = _reserve(out, size, 48 + text_length)
            bytes[unsafe_offset=size] = UInt8(ord(":"))
            size += 1
            if indent > 0:
                bytes[unsafe_offset=size] = 0x20
                size += 1
        var kind = found.kind
        if (
            kind == JsonKind.STRING
            and found.flags & (FLAG_ESCAPED | FLAG_DECODED) == 0
        ):
            size = _quoted_at(
                bytes, size, source, Int(found.start), text_length, wide
            )
        elif kind == JsonKind.NUMBER and found.flags & FLAG_CANONICAL != 0:
            _copy(
                bytes.unsafe_offset(size),
                source.unsafe_offset(Int(found.start)),
                text_length,
                wide,
            )
            size += text_length
        elif kind.value < JsonKind.ARRAY.value:
            out.shrink(size)
            _write_scalar(out, document, found)
            size = len(out)
        else:
            var opens_object = kind == JsonKind.OBJECT
            bytes[unsafe_offset=size] = UInt8(
                ord("{")
            ) if opens_object else UInt8(ord("["))
            size += 1
            if found.count == 0:
                bytes[unsafe_offset=size] = UInt8(
                    ord("}")
                ) if opens_object else UInt8(ord("]"))
                size += 1
            else:
                stack.append(parent)
                stack.append(Int(found.next))
                parent = child
                in_object = opens_object
                child = Int(found.start)
                depth += 1
                first = True
                continue
        child = Int(found.next)


@always_inline
def _reserve(
    mut out: List[UInt8], size: Int, need: Int
) -> Pointer[UInt8, origin_of(out)]:
    """Make the buffer hold `need` more bytes after `size`; return it."""
    if size + need > len(out):
        out.resize(
            unsafe_uninit_length=max(
                out.capacity(), len(out) * 2, size + need + 256
            )
        )
    return out.unsafe_ptr()


@always_inline
def _newline_at[
    origin: MutOrigin
](bytes: Pointer[UInt8, origin], size: Int, spaces: Int) -> Int:
    """Write a line break and some spaces at an offset; return the end."""
    bytes[unsafe_offset=size] = 0x0A
    var index = 0
    while index < spaces:
        bytes[unsafe_offset=size + 1 + index] = 0x20
        index += 1
    return size + 1 + spaces


@always_inline
def _quoted_at[
    origin: MutOrigin
](
    bytes: Pointer[UInt8, origin],
    size: Int,
    source: Pointer[UInt8, _],
    start: Int,
    length: Int,
    wide: Bool,
) -> Int:
    """Write text between quotes at an offset; return the end."""
    bytes[unsafe_offset=size] = UInt8(ord('"'))
    _copy(
        bytes.unsafe_offset(size + 1), source.unsafe_offset(start), length, wide
    )
    bytes[unsafe_offset=size + 1 + length] = UInt8(ord('"'))
    return size + 2 + length


def _newline(mut out: List[UInt8], spaces: Int):
    """Write a line break and some spaces."""
    out.append(0x0A)
    var index = 0
    while index < spaces:
        out.append(0x20)
        index += 1


@always_inline
def _write_scalar(
    mut out: List[UInt8],
    document: JsonDocument,
    found: JsonNode,
):
    """Write a scalar node."""
    var kind = found.kind
    if kind == JsonKind.STRING:
        _write_stored(
            out,
            document,
            Int(found.start),
            Int(found.end),
            found.flags & FLAG_ESCAPED != 0,
            found.flags & FLAG_DECODED != 0,
        )
    elif kind == JsonKind.NUMBER:
        var text = Span(document.bytes)[Int(found.start) : Int(found.end)]
        if found.flags & FLAG_CANONICAL != 0:
            out.extend(text)
        else:
            write_number(out, read_float64(text))
    elif kind == JsonKind.BOOLEAN:
        var word = "true" if found.flags & FLAG_TRUE != 0 else "false"
        out.extend(word.as_bytes())
    else:
        out.extend("null".as_bytes())


@always_inline
def _write_stored(
    mut out: List[UInt8],
    document: JsonDocument,
    start: Int,
    end: Int,
    escaped: Bool,
    decoded: Bool,
):
    """Write string text that a document stores."""
    var bytes = Span(document.bytes)
    if escaped:
        _write_reescaped(out, bytes, start, end)
    elif decoded:
        write_string(out, bytes[start:end])
    else:
        # Source text without an escape has no byte to escape.
        out.append(UInt8(ord('"')))
        out.extend(bytes[start:end])
        out.append(UInt8(ord('"')))


def stringify(document: JsonDocument, node: Int, indent: Int = 0) -> String:
    """Return the JSON text of a value, as `JSON.stringify` writes it.

    Args:
        document: The document.
        node: The value's index.
        indent: The spaces for each level, as the third argument of
            `JSON.stringify`; 0 writes one line.

    Returns:
        The JSON text.
    """
    var writer = JsonWriter(indent, len(document.bytes) + 16)
    writer.value(document, node)
    return writer^.take_string()


@always_inline
def _copy[
    origin: MutOrigin
](dest: Pointer[UInt8, origin], src: Pointer[UInt8, _], count: Int, wide: Bool):
    """Copy bytes; a short copy uses two overlapping loads, not a call."""
    if wide and count <= 32:
        # The caller has 32 readable bytes at `src`, 32 writable at `dest`.
        dest.unsafe_store(src.unsafe_load[width=32]())
        return
    if count >= 16:
        if count > 32:
            unsafe_memcpy(dest=dest, src=src, count=count)
            return
        # 16 to 32 bytes: the first 16 and the last 16.
        var head = src.unsafe_load[width=16]()
        var tail = src.unsafe_offset(count - 16).unsafe_load[width=16]()
        dest.unsafe_store(head)
        dest.unsafe_offset(count - 16).unsafe_store(tail)
        return
    if count >= 8:
        var head = src.unsafe_load[width=8]()
        var tail = src.unsafe_offset(count - 8).unsafe_load[width=8]()
        dest.unsafe_store(head)
        dest.unsafe_offset(count - 8).unsafe_store(tail)
        return
    var index = 0
    while index < count:
        dest[unsafe_offset=index] = src[unsafe_offset=index]
        index += 1


def _write_reescaped(
    mut out: List[UInt8], text: Span[UInt8, _], start: Int, end: Int
):
    """Write source string text that has escapes, as `JSON.stringify` writes
    its decoded value.

    Each escape is decoded, then written again in the `JSON.stringify`
    form: `\\/` becomes `/`, and `\\u0041` becomes `A`.
    """
    out.append(UInt8(ord('"')))
    var position = start
    while True:
        var run = position
        while run < end and text[run] != UInt8(ord("\\")):
            run += 1
        out.extend(text[position:run])
        if run == end:
            break
        var escape = text[run + 1]
        position = run + 2
        if escape == UInt8(ord("u")):
            var code = read_hex4(text, run + 2)
            position = run + 6
            if code >= 0xD800 and code <= 0xDBFF:
                var low = read_hex4(text, run + 8)
                code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                position = run + 12
            if code < 0x20 or code == 0x22 or code == 0x5C:
                _escape(out, UInt8(code))
            else:
                append_codepoint(out, code)
        elif escape == UInt8(ord("/")):
            out.append(escape)
        else:
            # A quote, a backslash or a control character: its escape is
            # already the JSON.stringify form.
            out.append(UInt8(ord("\\")))
            out.append(escape)
    out.append(UInt8(ord('"')))


def stringify_bytes(
    document: JsonDocument, node: Int, indent: Int = 0
) -> List[UInt8]:
    """Return the JSON text of a value as UTF-8 bytes, as `stringify` does.

    The bytes are ready for a socket or a file; this skips the `String`
    copy.

    Args:
        document: The document.
        node: The value's index.
        indent: The spaces for each level; 0 writes one line.

    Returns:
        The JSON text.
    """
    var writer = JsonWriter(indent, len(document.bytes) + 16)
    writer.value(document, node)
    return writer^.take_bytes()
