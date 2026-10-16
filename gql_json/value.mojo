# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""JSON values, kept in one arena.

A `JsonDocument` holds the bytes of a JSON text and one `List` of fixed
28-byte `JsonNode` values. A node names its kind, its first and last
child, its next sibling, and a byte range of its text. An object member is
a node with a key: a second byte range. The parser makes no other
allocation: a number keeps its exact source text, and a string keeps its
source bytes. A flag tells whether the string has escapes, and
`string_value` decodes it only when a program asks.

A program can also build a document, or add to a parsed one. The text of
a built node goes after the source bytes, already decoded.

This module has no upstream counterpart. The values are the JSON values of
RFC 8259. The readers follow ECMAScript `JSON.parse` where the RFC leaves
a choice.

Differences from upstream:

- An object keeps every member in source order, duplicates too. `find`
  and `get` return the last member with a key, as `JSON.parse` keeps the
  last value. ECMAScript also puts keys like `"1"` (array indices) first
  in an object; this module does not reorder keys.
- A number keeps its source text. `as_int64` reads it exactly, and
  `as_float64` rounds it as `JSON.parse` does.
"""

from gql_json.error import JsonError
from gql_json.number import (
    IntStatus,
    is_integer_text,
    read_float64,
    read_int64,
    write_int,
    write_number,
)


@fieldwise_init
struct JsonKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a JSON value."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NULL = JsonKind(0)
    """The value `null`."""
    comptime BOOLEAN = JsonKind(1)
    """The value `true` or `false`."""
    comptime NUMBER = JsonKind(2)
    """A number."""
    comptime STRING = JsonKind(3)
    """A string."""
    comptime ARRAY = JsonKind(4)
    """An array."""
    comptime OBJECT = JsonKind(5)
    """An object."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the six kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 5

    def text(self) -> StaticString:
        """Return the kind's name, such as `object`.

        Returns:
            The name, or `<invalid>`.
        """
        if self == JsonKind.NULL:
            return "null"
        if self == JsonKind.BOOLEAN:
            return "boolean"
        if self == JsonKind.NUMBER:
            return "number"
        if self == JsonKind.STRING:
            return "string"
        if self == JsonKind.ARRAY:
            return "array"
        if self == JsonKind.OBJECT:
            return "object"
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind's name.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


comptime NO_NODE = -1
"""The index that names no node."""
comptime FLAG_TRUE: UInt8 = 1
"""A `BOOLEAN` node that is true."""
comptime FLAG_ESCAPED: UInt8 = 1
"""A `STRING` node whose source text has escapes."""
comptime FLAG_CANONICAL: UInt8 = 2
"""A `NUMBER` node whose text `JSON.stringify` writes unchanged."""
comptime FLAG_DECODED: UInt8 = 4
"""A `STRING` node whose text a program added, decoded: it can hold bytes
that a writer must escape."""
comptime FLAG_KEY_ESCAPED: UInt8 = 8
"""A member whose source key has escapes."""
comptime FLAG_KEY_DECODED: UInt8 = 16
"""A member whose key a program added, decoded."""


@fieldwise_init
struct JsonNode(ImplicitlyCopyable, Movable):
    """One JSON value: its kind, flags, text, key and links."""

    var kind: JsonKind
    """What the value is."""
    var flags: UInt8
    """Kind-specific bits, and the key bits."""
    var start: Int32
    """A scalar's text start; a container's first child, or `NO_NODE`."""
    var end: Int32
    """A scalar's text end; a container's last child, or `NO_NODE`."""
    var count: Int32
    """A container's number of children; 0 for a scalar."""
    var key_start: Int32
    """The start of a member's key text."""
    var key_end: Int32
    """The end of a member's key text."""
    var next: Int32
    """The next sibling, or `NO_NODE`."""


struct JsonDocument(Copyable, Movable):
    """A parsed or built JSON value: its bytes and its nodes."""

    var bytes: List[UInt8]
    """The source bytes, then the text that a program added."""
    var nodes: List[JsonNode]
    """Every node; a parsed document is in preorder."""
    var root: Int
    """The index of the root value, or `NO_NODE`."""

    def __init__(out self):
        """Start an empty document, with no root."""
        self.bytes = List[UInt8]()
        self.nodes = List[JsonNode]()
        self.root = NO_NODE

    def __init__(out self, var bytes: List[UInt8], var nodes: List[JsonNode]):
        """Wrap parsed nodes; the root is node 0.

        Args:
            bytes: The source bytes.
            nodes: The nodes, in preorder.
        """
        self.bytes = bytes^
        self.nodes = nodes^
        self.root = 0

    # --- reading --------------------------------------------------------
    #
    # Every reader takes a node index that this document gave out. The
    # index is not checked again: a reader runs once per node in a walk.

    @always_inline
    def _node(self, node: Int) -> JsonNode:
        """Return a copy of a node, without a bounds check."""
        return self.nodes.unsafe_ptr()[unsafe_offset=node]

    @always_inline
    def kind(self, node: Int) -> JsonKind:
        """Return a value's kind.

        Args:
            node: The node's index.

        Returns:
            Its kind.
        """
        return self._node(node).kind

    @always_inline
    def length(self, node: Int) -> Int:
        """Return how many items an array has, or members an object has.

        Args:
            node: The node's index.

        Returns:
            The count; 0 for a scalar.
        """
        return Int(self._node(node).count)

    @always_inline
    def first(self, node: Int) -> Int:
        """Return the first item of an array, or member of an object.

        Args:
            node: The node's index.

        Returns:
            The child's index, or `NO_NODE`.
        """
        var found = self._node(node)
        if found.count == 0:
            return NO_NODE
        return Int(found.start)

    @always_inline
    def next(self, node: Int) -> Int:
        """Return the next item, or member, after a child.

        Args:
            node: A child's index.

        Returns:
            The sibling's index, or `NO_NODE`.
        """
        return Int(self._node(node).next)

    def at(self, node: Int, index: Int) -> Int:
        """Return the child at a position.

        Args:
            node: An array or an object.
            index: The position, from 0.

        Returns:
            The child's index, or `NO_NODE` when the position is out of
            range.
        """
        if index < 0 or index >= self.length(node):
            return NO_NODE
        var current = self.first(node)
        var position = 0
        while position < index:
            current = self.next(current)
            position += 1
        return current

    def children(self, node: Int) -> List[Int]:
        """Return the children of an array or an object, in order.

        Args:
            node: The node's index.

        Returns:
            The children's indices; empty for a scalar.
        """
        var out = List[Int](capacity=self.length(node))
        var current = self.first(node)
        while current != NO_NODE:
            out.append(current)
            current = self.next(current)
        return out^

    def text(self, node: Int) -> StringSlice[origin_of(self.bytes)]:
        """Return a scalar's stored text.

        That is the source text of a number, and the text between the
        quotes of a string, escapes not decoded.

        Args:
            node: The node's index.

        Returns:
            A view of the text; empty for other kinds.
        """
        var found = self._node(node)
        var start = Int(found.start)
        var end = Int(found.end)
        if found.kind.value >= JsonKind.ARRAY.value:
            start = 0
            end = 0
        return StringSlice(unsafe_from_utf8=Span(self.bytes)[start:end])

    def raw_key(self, node: Int) -> StringSlice[origin_of(self.bytes)]:
        """Return a member's stored key text, escapes not decoded.

        Args:
            node: A member's index.

        Returns:
            A view of the key; empty for an array item.
        """
        var found = self._node(node)
        return StringSlice(
            unsafe_from_utf8=Span(self.bytes)[
                Int(found.key_start) : Int(found.key_end)
            ]
        )

    def key(self, node: Int) -> String:
        """Return a member's decoded key.

        Args:
            node: A member's index.

        Returns:
            The key; empty for an array item.
        """
        var found = self._node(node)
        var start = Int(found.key_start)
        var end = Int(found.key_end)
        if found.flags & FLAG_KEY_ESCAPED == 0:
            return String(self.raw_key(node))
        var out = List[UInt8](capacity=end - start)
        decode_string(Span(self.bytes), start, end, out)
        return String(unsafe_from_utf8=out^)

    def key_equals(self, node: Int, key: StringSlice) -> Bool:
        """Return True if a member's decoded key equals some text.

        Args:
            node: A member's index.
            key: The text to compare.

        Returns:
            Whether the keys are equal.
        """
        if self._node(node).flags & FLAG_KEY_ESCAPED == 0:
            return self.raw_key(node) == key
        return self.key(node) == key

    def find(self, node: Int, key: StringSlice) -> Int:
        """Return the last member of an object with a key.

        The search is linear. For many lookups in a large object, build a
        `JsonObjectIndex`.

        Args:
            node: An object's index.
            key: The decoded key.

        Returns:
            The member's index, or `NO_NODE` when there is none.
        """
        var found = NO_NODE
        var current = self.first(node)
        while current != NO_NODE:
            if self.key_equals(current, key):
                found = current
            current = self.next(current)
        return found

    def get(self, node: Int, key: StringSlice) raises JsonError -> Int:
        """Return the last member of an object with a key.

        Args:
            node: An object's index.
            key: The decoded key.

        Returns:
            The member's index.

        Raises:
            JsonError: If the object has no member with the key.
        """
        var found = self.find(node, key)
        if found == NO_NODE:
            raise JsonError(String("No member named ", key))
        return found

    def bool_value(self, node: Int) -> Bool:
        """Return True for the value `true`.

        Args:
            node: The node's index.

        Returns:
            Whether the node is the boolean `true`.
        """
        var found = self._node(node)
        return found.kind == JsonKind.BOOLEAN and found.flags & FLAG_TRUE != 0

    def has_escapes(self, node: Int) -> Bool:
        """Return True if a parsed string's source text has escapes.

        Args:
            node: The node's index.

        Returns:
            Whether `text` differs from `string_value`.
        """
        var found = self._node(node)
        return found.kind == JsonKind.STRING and found.flags & FLAG_ESCAPED != 0

    def string_value(self, node: Int) -> String:
        """Return the decoded value of a string.

        Args:
            node: A string's index.

        Returns:
            The value, escapes decoded; empty for other kinds.
        """
        if not self.has_escapes(node):
            return String(self.text(node))
        var found = self._node(node)
        var out = List[UInt8](capacity=Int(found.end - found.start))
        decode_string(Span(self.bytes), Int(found.start), Int(found.end), out)
        return String(unsafe_from_utf8=out^)

    def is_integer(self, node: Int) -> Bool:
        """Return True if a number's exact value is an integer.

        `1.0` and `1e2` are integers, as ECMAScript `Number.isInteger`
        says.

        Args:
            node: The node's index.

        Returns:
            Whether the node is a number without a fraction.
        """
        var found = self._node(node)
        if found.kind != JsonKind.NUMBER:
            return False
        if found.flags & FLAG_CANONICAL != 0:
            return True
        return is_integer_text(self.text(node).as_bytes())

    def as_int64(self, node: Int) raises JsonError -> Int64:
        """Return a number's exact value as an `Int64`.

        Args:
            node: A number's index.

        Returns:
            The value. `1e2` and `1.0` are integers.

        Raises:
            JsonError: If the node is not a number, if the number has a
                fraction, or if it is outside the `Int64` range.
        """
        var found = self._node(node)
        if found.kind != JsonKind.NUMBER:
            raise JsonError(String("Expected a number, found ", found.kind))
        var result = read_int64(self.text(node).as_bytes())
        if result[1] == IntStatus.FRACTION:
            raise JsonError(
                String("The number ", self.text(node), " is not an integer")
            )
        if result[1] == IntStatus.OVERFLOW:
            raise JsonError(
                String("The number ", self.text(node), " overflows Int64")
            )
        return result[0]

    def as_float64(self, node: Int) -> Float64:
        """Return a number's value as the nearest `Float64`.

        The rounding is the rounding of ECMAScript `JSON.parse`: to nearest,
        ties to even. A number too large for a `Float64` gives an infinity.

        Args:
            node: A number's index.

        Returns:
            The value; NaN when the node is not a number.
        """
        var found = self._node(node)
        if found.kind != JsonKind.NUMBER:
            return _nan()
        return read_float64(self.text(node).as_bytes())

    # --- building -------------------------------------------------------

    def _add(
        mut self, kind: JsonKind, flags: UInt8, start: Int, end: Int
    ) -> Int:
        """Add a node with no parent; return its index."""
        self.nodes.append(
            JsonNode(
                kind,
                flags,
                Int32(start),
                Int32(end),
                0,
                0,
                0,
                Int32(NO_NODE),
            )
        )
        return len(self.nodes) - 1

    def _add_text(
        mut self, kind: JsonKind, flags: UInt8, text: Span[UInt8, _]
    ) -> Int:
        """Add a scalar whose text goes after the bytes."""
        var start = len(self.bytes)
        self.bytes.extend(text)
        return self._add(kind, flags, start, len(self.bytes))

    def add_null(mut self) -> Int:
        """Add the value `null`, with no parent.

        Returns:
            The new node's index.
        """
        return self._add(JsonKind.NULL, 0, 0, 0)

    def add_bool(mut self, value: Bool) -> Int:
        """Add a boolean, with no parent.

        Args:
            value: The value.

        Returns:
            The new node's index.
        """
        return self._add(JsonKind.BOOLEAN, FLAG_TRUE if value else 0, 0, 0)

    def add_int(mut self, value: Int64) -> Int:
        """Add an integer, with no parent.

        Args:
            value: The value; every `Int64` is kept exactly.

        Returns:
            The new node's index.
        """
        var text = List[UInt8]()
        write_int(text, value)
        return self._add_text(JsonKind.NUMBER, FLAG_CANONICAL, Span(text))

    def add_float(mut self, value: Float64) -> Int:
        """Add a number, as `JSON.stringify` writes it, with no parent.

        Args:
            value: The value. NaN and the infinities become `null`, as
                `JSON.stringify` writes them.

        Returns:
            The new node's index.
        """
        if value - value != 0.0:
            return self.add_null()
        var text = List[UInt8]()
        write_number(text, value)
        return self._add_text(JsonKind.NUMBER, FLAG_CANONICAL, Span(text))

    def add_number(mut self, text: StringSlice) raises JsonError -> Int:
        """Add a number from its JSON text, with no parent.

        The text is kept exactly, as a parsed number keeps it.

        Args:
            text: The number in JSON syntax, such as `-1.5e3`.

        Returns:
            The new node's index.

        Raises:
            JsonError: If the text is not a JSON number.
        """
        var bytes = text.as_bytes()
        var end = number_end(bytes, 0)
        if end != len(bytes):
            raise JsonError(String("Not a JSON number: ", text))
        var flags = FLAG_CANONICAL if is_canonical_number(bytes) else UInt8(0)
        return self._add_text(JsonKind.NUMBER, flags, bytes)

    def add_string(mut self, text: StringSlice) -> Int:
        """Add a string, with no parent.

        Args:
            text: The decoded value.

        Returns:
            The new node's index.
        """
        return self._add_text(JsonKind.STRING, FLAG_DECODED, text.as_bytes())

    def add_array(mut self) -> Int:
        """Add an empty array, with no parent.

        Returns:
            The new node's index.
        """
        return self._add(JsonKind.ARRAY, 0, NO_NODE, NO_NODE)

    def add_object(mut self) -> Int:
        """Add an empty object, with no parent.

        Returns:
            The new node's index.
        """
        return self._add(JsonKind.OBJECT, 0, NO_NODE, NO_NODE)

    def append(mut self, parent: Int, child: Int):
        """Make a value the last item of an array.

        Args:
            parent: An array's index.
            child: A node with no parent.
        """
        _link(self.nodes, parent, child)

    def add_member(mut self, parent: Int, key: StringSlice, child: Int):
        """Make a value the last member of an object, with a key.

        Args:
            parent: An object's index.
            key: The decoded key.
            child: A node with no parent.
        """
        var start = len(self.bytes)
        self.bytes.extend(key.as_bytes())
        ref member = self.nodes[child]
        member.key_start = Int32(start)
        member.key_end = Int32(len(self.bytes))
        member.flags = (member.flags & ~FLAG_KEY_ESCAPED) | FLAG_KEY_DECODED
        _link(self.nodes, parent, child)

    def add_copy(mut self, other: JsonDocument, node: Int) -> Int:
        """Copy a value and its descendants from another document.

        The text is copied after this document's bytes, so the copy does
        not need the other document. Keys and strings stay as they are
        stored, escapes too.

        Args:
            other: The document to copy from.
            node: The value to copy.

        Returns:
            The copy's index; it has no parent and no key.
        """
        var root = self._copy_node(other, node)
        # Pairs of (child in `other`, parent copy), in order.
        var stack: List[Int] = [node, root]
        while len(stack) > 0:
            var copy = stack.pop()
            var original = stack.pop()
            var current = other.first(original)
            while current != NO_NODE:
                var child = self._copy_node(other, current)
                var found = other._node(current)
                if other.kind(original) == JsonKind.OBJECT:
                    var start = len(self.bytes)
                    self.bytes.extend(other.raw_key(current).as_bytes())
                    ref member = self.nodes[child]
                    member.key_start = Int32(start)
                    member.key_end = Int32(len(self.bytes))
                    member.flags |= found.flags & (
                        FLAG_KEY_ESCAPED | FLAG_KEY_DECODED
                    )
                _link(self.nodes, copy, child)
                if found.count > 0:
                    stack.append(current)
                    stack.append(child)
                current = other.next(current)
        return root

    def _copy_node(mut self, other: JsonDocument, node: Int) -> Int:
        """Copy one node, with its text and flags but not its children."""
        var found = other._node(node)
        var flags = found.flags & ~(FLAG_KEY_ESCAPED | FLAG_KEY_DECODED)
        if found.kind.value >= JsonKind.ARRAY.value:
            return self._add(found.kind, flags, NO_NODE, NO_NODE)
        return self._add_text(found.kind, flags, other.text(node).as_bytes())


def _nan() -> Float64:
    """Return a quiet NaN."""
    var zero: Float64 = 0.0
    return zero / zero


def _link(mut nodes: List[JsonNode], parent: Int, child: Int):
    """Make a node the last child of another."""
    ref container = nodes[parent]
    var last = Int(container.end)
    container.end = Int32(child)
    container.count += 1
    if container.count == 1:
        container.start = Int32(child)
    else:
        nodes[last].next = Int32(child)


struct JsonObjectIndex(Movable):
    """A hash index of the keys of one object, for fast lookups.

    The index holds node indices. It stays valid while the object gets no
    new member.
    """

    var slots: List[Int32]
    """The open addressing table: a member's index, or `NO_NODE`."""
    var object: Int
    """The indexed object."""

    def __init__(out self, document: JsonDocument, object: Int):
        """Index every member of an object.

        A later member with the same key replaces an earlier one, as
        `JsonDocument.find` does.

        Args:
            document: The document.
            object: An object's index.
        """
        var size = 8
        while size < document.length(object) * 2:
            size *= 2
        self.slots = List[Int32](length=size, fill=Int32(NO_NODE))
        self.object = object
        var current = document.first(object)
        while current != NO_NODE:
            var key = document.key(current)
            var slot = self._slot(document, key)
            self.slots[slot] = Int32(current)
            current = document.next(current)

    def _slot(self, document: JsonDocument, key: StringSlice) -> Int:
        """Return the slot that holds a key, or the empty slot for it."""
        var mask = len(self.slots) - 1
        var slot = Int(_hash(key.as_bytes())) & mask
        while True:
            var member = Int(self.slots[slot])
            if member == NO_NODE or document.key_equals(member, key):
                return slot
            slot = (slot + 1) & mask

    def find(self, document: JsonDocument, key: StringSlice) -> Int:
        """Return the last member of the object with a key.

        Args:
            document: The document that the index was built from.
            key: The decoded key.

        Returns:
            The member's index, or `NO_NODE` when there is none.
        """
        return Int(self.slots[self._slot(document, key)])


def _hash(bytes: Span[UInt8, _]) -> UInt64:
    """Return the FNV-1a hash of some bytes."""
    var hash = UInt64(0xCBF29CE484222325)
    for byte in bytes:
        hash = (hash ^ UInt64(byte)) * 0x100000001B3
    return hash


# --- strings and numbers ------------------------------------------------


@always_inline
def hex_value(byte: UInt8) -> Int:
    """Return the value of a hex digit.

    Args:
        byte: Any byte.

    Returns:
        0 to 15, or -1 when the byte is not a hex digit.
    """
    if byte >= 0x30 and byte <= 0x39:
        return Int(byte) - 0x30
    var lower = byte | 0x20
    if lower >= 0x61 and lower <= 0x66:
        return Int(lower) - 0x61 + 10
    return -1


def read_hex4(data: Span[UInt8, _], position: Int) -> Int:
    """Read four hex digits.

    Args:
        data: The bytes; four must be readable at `position`.
        position: The offset of the first digit.

    Returns:
        The 16-bit value, or -1 when a byte is not a hex digit.
    """
    var value = 0
    var index = 0
    while index < 4:
        var digit = hex_value(data[position + index])
        if digit < 0:
            return -1
        value = value * 16 + digit
        index += 1
    return value


def append_codepoint(mut out: List[UInt8], code: Int):
    """Append a code point as UTF-8.

    Args:
        out: The destination.
        code: A Unicode scalar value.
    """
    if code < 0x80:
        out.append(UInt8(code))
    elif code < 0x800:
        out.append(UInt8(0xC0 | (code >> 6)))
        out.append(UInt8(0x80 | (code & 0x3F)))
    elif code < 0x10000:
        out.append(UInt8(0xE0 | (code >> 12)))
        out.append(UInt8(0x80 | ((code >> 6) & 0x3F)))
        out.append(UInt8(0x80 | (code & 0x3F)))
    else:
        out.append(UInt8(0xF0 | (code >> 18)))
        out.append(UInt8(0x80 | ((code >> 12) & 0x3F)))
        out.append(UInt8(0x80 | ((code >> 6) & 0x3F)))
        out.append(UInt8(0x80 | (code & 0x3F)))


def decode_string(
    data: Span[UInt8, _], start: Int, end: Int, mut out: List[UInt8]
):
    """Append the decoded value of string text that the parser accepted.

    Args:
        data: The bytes.
        start: The offset after the opening quote.
        end: The offset of the closing quote.
        out: The destination.
    """
    var position = start
    while position < end:
        var run = position
        while run < end and data[run] != 0x5C:
            run += 1
        out.extend(data[position:run])
        if run == end:
            return
        var escape = data[run + 1]
        position = run + 2
        if escape == UInt8(ord("u")):
            var code = read_hex4(data, run + 2)
            position = run + 6
            if code >= 0xD800 and code <= 0xDBFF:
                var low = read_hex4(data, run + 8)
                code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                position = run + 12
            append_codepoint(out, code)
        elif escape == UInt8(ord("b")):
            out.append(0x08)
        elif escape == UInt8(ord("f")):
            out.append(0x0C)
        elif escape == UInt8(ord("n")):
            out.append(0x0A)
        elif escape == UInt8(ord("r")):
            out.append(0x0D)
        elif escape == UInt8(ord("t")):
            out.append(0x09)
        else:
            # A quote, a backslash or a solidus stands for itself.
            out.append(escape)


def number_end(data: Span[UInt8, _], start: Int) -> Int:
    """Return the end of the RFC 8259 number that starts at an offset.

    Args:
        data: The bytes.
        start: The offset of the first byte.

    Returns:
        The offset after the number, or -1 when no valid number starts
        there. A valid number can be followed by any byte.
    """
    var length = len(data)
    var position = start
    if position < length and data[position] == UInt8(ord("-")):
        position += 1
    if position == length:
        return -1
    var first = data[position]
    if first == UInt8(ord("0")):
        position += 1
    elif first >= UInt8(ord("1")) and first <= UInt8(ord("9")):
        position = _digits_end(data, position + 1)
    else:
        return -1
    if position < length and data[position] == UInt8(ord(".")):
        var digits = _digits_end(data, position + 1)
        if digits == position + 1:
            return -1
        position = digits
    if position < length and (data[position] | 0x20) == UInt8(ord("e")):
        position += 1
        if position < length and (
            data[position] == UInt8(ord("+"))
            or data[position] == UInt8(ord("-"))
        ):
            position += 1
        var digits = _digits_end(data, position)
        if digits == position:
            return -1
        position = digits
    return position


def _digits_end(data: Span[UInt8, _], start: Int) -> Int:
    """Return the offset after a run of decimal digits."""
    var position = start
    while position < len(data) and data[position] - UInt8(ord("0")) < 10:
        position += 1
    return position


def is_canonical_number(text: Span[UInt8, _]) -> Bool:
    """Return True if `JSON.stringify` writes a number's text unchanged.

    That is an integer of at most 15 digits, without a fraction, an
    exponent, or the text `-0`.

    Args:
        text: Valid JSON number text.

    Returns:
        Whether the text is already in the ECMAScript form.
    """
    var digits = len(text)
    var start = 0
    if text[0] == UInt8(ord("-")):
        digits -= 1
        start = 1
        if text[1] == UInt8(ord("0")):
            return False
    if digits > 15:
        return False
    var index = start
    while index < len(text):
        if text[index] - UInt8(ord("0")) >= 10:
            return False
        index += 1
    return True
