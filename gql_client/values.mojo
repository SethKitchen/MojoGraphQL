# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The values of the normalized cache, kept in one arena.

Apollo Client 4.3.3 keeps a `StoreValue` as a plain JavaScript value: a
scalar, an array, an object, or a `Reference` object `{ __ref: id }`. This
module keeps them as `ValueNode`s in one `Values` arena. A value is an
`Int` index into it. `NO_VALUE` (`-1`) is the JavaScript `undefined`.

A value does not change after it is added. A change to a field puts a new
value in the field, as Apollo Client does with frozen objects. The arena
can then hold values that nothing uses. `compact` copies the values that
some roots use into a new arena.

The module also holds the value helpers that the cache needs:

- `equal`, the deep equality of `@wry/equality` `equal`.
- `merge`, the deep merge of the default `DeepMerger` of
  `src/utilities/internal/DeepMerger.ts`.
- `canonical_stringify`, the `canonicalStringify` of
  `src/utilities/internal/canonicalStringify.ts`: `JSON.stringify` with the
  keys of each object sorted.
- `stringify`, the text of `JSON.stringify`, with the ECMAScript order of
  the keys: the keys that are array indices first.

Differences from upstream:

- A number keeps the text that `JSON.stringify` writes for it, so a number
  is equal to another number when the texts are equal. That is the
  equality of JavaScript numbers, except that NaN cannot occur.
- An object key and an entity id are interned: each distinct text is kept
  once, in `names` and `ids`.
"""

from std.collections import Dict

from gql_json.number import read_float64, write_number
from gql_json.value import (
    FLAG_CANONICAL,
    FLAG_DECODED,
    FLAG_ESCAPED,
    FLAG_KEY_ESCAPED,
    JsonDocument,
    JsonKind,
    JsonNode,
    NO_NODE,
)
from gql_json.writer import JsonWriter, write_string


@fieldwise_init
struct ValueKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a cache value."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NULL = ValueKind(0)
    """The value `null`."""
    comptime FALSE = ValueKind(1)
    """The value `false`."""
    comptime TRUE = ValueKind(2)
    """The value `true`."""
    comptime UNDEFINED = ValueKind(3)
    """The value `undefined`, as an argument or an item can hold it."""
    comptime NUMBER = ValueKind(4)
    """A number, kept as its `JSON.stringify` text."""
    comptime STRING = ValueKind(5)
    """A string, kept decoded."""
    comptime REFERENCE = ValueKind(6)
    """A `Reference` to an entity: `{ __ref: id }`."""
    comptime ARRAY = ValueKind(7)
    """An array."""
    comptime OBJECT = ValueKind(8)
    """An object that is not a `Reference`."""

    def is_valid(self) -> Bool:
        """Return True for one of the nine kinds.

        Returns:
            Whether the index names a kind.
        """
        return self.value <= 8

    def text(self) -> StaticString:
        """Return the kind's name.

        Returns:
            The name, such as `OBJECT`, or `INVALID`.
        """
        comptime names: Array[StaticString, 9] = [
            "NULL",
            "FALSE",
            "TRUE",
            "UNDEFINED",
            "NUMBER",
            "STRING",
            "REFERENCE",
            "ARRAY",
            "OBJECT",
        ]
        if not self.is_valid():
            return "INVALID"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind's name.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


comptime NO_VALUE = -1
"""The index that names no value: JavaScript `undefined`."""
comptime NULL_VALUE = 0
"""The shared `null` value."""
comptime FALSE_VALUE = 1
"""The shared `false` value."""
comptime TRUE_VALUE = 2
"""The shared `true` value."""
comptime UNDEFINED_VALUE = 3
"""The shared `undefined` value, for an argument or an array item."""
comptime TYPENAME = 0
"""The id of the key `__typename` in `Values.names`: the first key."""
comptime REF_NAME = 1
"""The id of the key `__ref` in `Values.names`: the second key."""
comptime ID_NAME = 2
"""The id of the key `id` in `Values.names`."""
comptime UNDERSCORE_ID_NAME = 3
"""The id of the key `_id` in `Values.names`."""


@fieldwise_init
struct ValueNode(ImplicitlyCopyable, Movable):
    """One value: its kind and where its contents are."""

    var kind: ValueKind
    """What the value is."""
    var start: Int32
    """The first byte of a scalar's text, the first item of a container,
    or the entity id of a `REFERENCE`."""
    var count: Int32
    """The bytes of a scalar's text, or the items or members of a
    container."""


@fieldwise_init
struct Member(ImplicitlyCopyable, Movable):
    """One field of an object or an entity: a name and a value."""

    var name: Int32
    """The interned key."""
    var value: Int32
    """The value, or `NO_VALUE`."""


struct Interner(Copyable, Movable):
    """A table that gives each distinct text one `Int` id.

    The texts are in one byte buffer. An open addressing hash table maps a
    text to its id; a lookup copies nothing.
    """

    var bytes: List[UInt8]
    """The texts, one after another."""
    var starts: List[Int32]
    """Where the text of each id starts in `bytes`; one more entry holds
    the end."""
    var hashes: List[UInt64]
    """The hash of each id's text."""
    var slots: List[Int32]
    """The hash table: an id, or -1 for an empty slot. Its size is a power
    of two, at least twice the number of ids."""
    var indexes: List[Int64]
    """For each id, the array index that the text is, or -1."""

    def __init__(out self):
        """Make an empty table."""
        self.bytes = List[UInt8]()
        self.starts = List[Int32]()
        self.starts.append(0)
        self.hashes = List[UInt64]()
        self.slots = List[Int32](length=16, fill=-1)
        self.indexes = List[Int64]()

    def _slot(self, text: Span[UInt8, _], hash: UInt64) -> Int:
        """Return the slot of a text: its id's slot, or the empty slot
        where it goes."""
        var mask = len(self.slots) - 1
        var slot = Int(hash) & mask
        while True:
            var id = Int(self.slots.unsafe_ptr()[unsafe_offset=slot])
            if id < 0:
                return slot
            if self._equals(id, text):
                return slot
            slot = (slot + 1) & mask

    def _equals(self, id: Int, text: Span[UInt8, _]) -> Bool:
        """Return True when an id's text is some bytes."""
        var start = Int(self.starts.unsafe_ptr()[unsafe_offset=id])
        var end = Int(self.starts.unsafe_ptr()[unsafe_offset=id + 1])
        if end - start != len(text):
            return False
        var data = self.bytes.unsafe_ptr()
        var index = 0
        while index < len(text):
            if data[unsafe_offset=start + index] != text[index]:
                return False
            index += 1
        return True

    def intern(mut self, text: StringSlice) -> Int:
        """Return the id of a text, and add the text when it is new.

        Args:
            text: The text.

        Returns:
            Its id.
        """
        var bytes = text.as_bytes()
        var hash = _fnv(bytes)
        var slot = self._slot(bytes, hash)
        var found = Int(self.slots[slot])
        if found >= 0:
            return found
        var id = len(self.indexes)
        self.indexes.append(array_index(text))
        self.hashes.append(hash)
        self.bytes.extend(bytes)
        self.starts.append(Int32(len(self.bytes)))
        self.slots[slot] = Int32(id)
        if 2 * len(self.indexes) > len(self.slots):
            self._grow()
        return id

    def _grow(mut self):
        """Double the hash table and put every id in it again."""
        var size = 2 * len(self.slots)
        self.slots = List[Int32](length=size, fill=-1)
        var mask = size - 1
        var id = 0
        while id < len(self.indexes):
            var slot = Int(self.hashes[id]) & mask
            while self.slots[slot] >= 0:
                slot = (slot + 1) & mask
            self.slots[slot] = Int32(id)
            id += 1

    def find(self, text: StringSlice) -> Int:
        """Return the id of a text, without adding it.

        Args:
            text: The text.

        Returns:
            Its id, or -1 when the table does not have it.
        """
        var bytes = text.as_bytes()
        return Int(self.slots[self._slot(bytes, _fnv(bytes))])

    @always_inline
    def text(self, id: Int) -> StringSlice[origin_of(self.bytes)]:
        """Return the text of an id.

        Args:
            id: An id that this table gave out.

        Returns:
            The text.
        """
        var start = Int(self.starts.unsafe_ptr()[unsafe_offset=id])
        var end = Int(self.starts.unsafe_ptr()[unsafe_offset=id + 1])
        return StringSlice(unsafe_from_utf8=Span(self.bytes)[start:end])

    def __len__(self) -> Int:
        """Return how many texts the table has.

        Returns:
            The number of ids.
        """
        return len(self.indexes)


def _fnv(bytes: Span[UInt8, _]) -> UInt64:
    """Return the 64-bit FNV-1a hash of some bytes."""
    var hash: UInt64 = 0xCBF29CE484222325
    var index = 0
    while index < len(bytes):
        hash = (hash ^ UInt64(bytes[index])) * 0x100000001B3
        index += 1
    return hash


def array_index(text: StringSlice) -> Int64:
    """Return the array index that a key is, as ECMAScript decides it.

    ECMAScript puts the keys that are array indices first in an object, in
    numeric order. A key is an array index when it is the canonical text of
    an integer from 0 to 2^32 - 2.

    Args:
        text: The key.

    Returns:
        The index, or -1 when the key is not an array index.
    """
    var bytes = text.as_bytes()
    var length = len(bytes)
    if length == 0 or length > 10:
        return -1
    if bytes[0] == UInt8(ord("0")) and length > 1:
        return -1
    var value: Int64 = 0
    var position = 0
    while position < length:
        var byte = bytes[position]
        if byte < UInt8(ord("0")) or byte > UInt8(ord("9")):
            return -1
        value = value * 10 + Int64(byte - UInt8(ord("0")))
        position += 1
    if value > 4294967294:
        return -1
    return value


def utf16_less(a: StringSlice, b: StringSlice) -> Bool:
    """Return True when a string sorts before another in JavaScript.

    JavaScript compares strings by UTF-16 code units. That is the order of
    the code points, except that a code point above U+FFFF sorts before
    U+E000 to U+FFFF.

    Args:
        a: The first string.
        b: The second string.

    Returns:
        Whether `a < b` in JavaScript.
    """
    var x = a.as_bytes()
    var y = b.as_bytes()
    var length = min(len(x), len(y))
    var position = 0
    while position < length and x[position] == y[position]:
        position += 1
    if position == length:
        return len(x) < len(y)
    # Back up to the lead byte of the code points that differ.
    var lead = position
    while lead > 0 and x[lead] & 0xC0 == 0x80:
        lead -= 1
    return _utf16_unit(x, lead) < _utf16_unit(y, lead)


def _utf16_unit(bytes: Span[UInt8, _], lead: Int) -> Int:
    """Return a key of the code point at a lead byte, in UTF-16 order.

    A code point below U+D800 keeps its value. A code point above U+FFFF
    sorts by its surrogate pair, so it goes between U+D7FF and U+E000.
    """
    var byte = Int(bytes[lead])
    var code = byte
    var extra = 0
    if byte >= 0xF0:
        code = byte & 0x07
        extra = 3
    elif byte >= 0xE0:
        code = byte & 0x0F
        extra = 2
    elif byte >= 0xC0:
        code = byte & 0x1F
        extra = 1
    var position = lead + 1
    while position <= lead + extra:
        code = (code << 6) | (Int(bytes[position]) & 0x3F)
        position += 1
    if code >= 0x10000:
        return 0xD800 + code - 0x10000
    if code >= 0xE000:
        return code + 0x100000
    return code


struct Values(Copyable, Movable):
    """The arena of cache values, with the tables of keys and ids."""

    var nodes: List[ValueNode]
    """Every value."""
    var bytes: List[UInt8]
    """The text of the numbers, strings and keys."""
    var items: List[Int32]
    """The items of each array, and the name and value of each member of
    each object."""
    var names: Interner
    """The keys of the objects and the store field names."""
    var ids: Interner
    """The entity ids that a `REFERENCE` names."""

    def __init__(out self):
        """Make an arena that holds only the shared constants."""
        self.nodes = List[ValueNode](capacity=64)
        self.bytes = List[UInt8](capacity=256)
        self.items = List[Int32](capacity=64)
        self.names = Interner()
        self.ids = Interner()
        self._add_constants()
        _ = self.names.intern("__typename")
        _ = self.names.intern("__ref")
        _ = self.names.intern("id")
        _ = self.names.intern("_id")

    def _add_constants(mut self):
        """Add `null`, `false`, `true` and `undefined` at their indices."""
        self.nodes.append(ValueNode(ValueKind.NULL, 0, 0))
        self.nodes.append(ValueNode(ValueKind.FALSE, 0, 0))
        self.nodes.append(ValueNode(ValueKind.TRUE, 0, 0))
        self.nodes.append(ValueNode(ValueKind.UNDEFINED, 0, 0))

    # --- reading --------------------------------------------------------

    @always_inline
    def node(self, value: Int) -> ValueNode:
        """Return a value's node, without a bounds check.

        Args:
            value: A value that this arena gave out.

        Returns:
            A copy of its node.
        """
        return self.nodes.unsafe_ptr()[unsafe_offset=value]

    @always_inline
    def kind(self, value: Int) -> ValueKind:
        """Return a value's kind.

        Args:
            value: A value, or `NO_VALUE`.

        Returns:
            Its kind; `UNDEFINED` for `NO_VALUE`.
        """
        if value < 0:
            return ValueKind.UNDEFINED
        return self.node(value).kind

    @always_inline
    def is_reference(self, value: Int) -> Bool:
        """Return True for a `Reference`, as Apollo Client `isReference`.

        Args:
            value: A value, or `NO_VALUE`.

        Returns:
            Whether it is a `Reference`.
        """
        return self.kind(value) == ValueKind.REFERENCE

    @always_inline
    def is_object(self, value: Int) -> Bool:
        """Return True for an object that is not a `Reference`.

        Args:
            value: A value, or `NO_VALUE`.

        Returns:
            Whether it is an `OBJECT`.
        """
        return self.kind(value) == ValueKind.OBJECT

    @always_inline
    def is_array(self, value: Int) -> Bool:
        """Return True for an array.

        Args:
            value: A value, or `NO_VALUE`.

        Returns:
            Whether it is an `ARRAY`.
        """
        return self.kind(value) == ValueKind.ARRAY

    @always_inline
    def is_undefined(self, value: Int) -> Bool:
        """Return True for `undefined`.

        Args:
            value: A value, or `NO_VALUE`.

        Returns:
            Whether it is `NO_VALUE` or `UNDEFINED`.
        """
        return self.kind(value) == ValueKind.UNDEFINED

    @always_inline
    def is_non_null_object(self, value: Int) -> Bool:
        """Return True for an array, an object or a `Reference`.

        Args:
            value: A value, or `NO_VALUE`.

        Returns:
            Whether it is a non-null JavaScript object.
        """
        return self.kind(value).value >= ValueKind.REFERENCE.value

    def text(self, value: Int) -> StringSlice[origin_of(self.bytes)]:
        """Return the text of a number or a string.

        Args:
            value: A `NUMBER` or `STRING`.

        Returns:
            The `JSON.stringify` text of the number, or the decoded string.
        """
        var found = self.node(value)
        var start = Int(found.start)
        return StringSlice(
            unsafe_from_utf8=Span(self.bytes)[start : start + Int(found.count)]
        )

    def text_equals(self, value: Int, text: StringSlice) -> Bool:
        """Return True when a string or a number has a text.

        Args:
            value: A value, or `NO_VALUE`.
            text: The text.

        Returns:
            Whether the value is a `STRING` or `NUMBER` with that text.
        """
        var kind = self.kind(value)
        if kind != ValueKind.STRING and kind != ValueKind.NUMBER:
            return False
        return self.text(value) == text

    @always_inline
    def ref_id(self, value: Int) -> Int:
        """Return the entity id of a `Reference`.

        Args:
            value: A `REFERENCE`.

        Returns:
            The interned id.
        """
        return Int(self.node(value).start)

    def ref_text(self, value: Int) -> StringSlice[origin_of(self.ids.bytes)]:
        """Return the entity id text of a `Reference`.

        Args:
            value: A `REFERENCE`.

        Returns:
            The id, such as `Book:1`.
        """
        return self.ids.text(self.ref_id(value))

    @always_inline
    def length(self, value: Int) -> Int:
        """Return the items of an array or the members of an object.

        Args:
            value: A value, or `NO_VALUE`.

        Returns:
            The count; 0 for any other kind.
        """
        var kind = self.kind(value)
        if kind == ValueKind.ARRAY or kind == ValueKind.OBJECT:
            return Int(self.node(value).count)
        return 0

    @always_inline
    def item(self, value: Int, index: Int) -> Int:
        """Return an item of an array.

        Args:
            value: An `ARRAY`.
            index: The position, from 0 to `length - 1`.

        Returns:
            The item.
        """
        return Int(
            self.items.unsafe_ptr()[
                unsafe_offset=Int(self.node(value).start) + index
            ]
        )

    @always_inline
    def member_name(self, value: Int, index: Int) -> Int:
        """Return the interned key of a member of an object.

        Args:
            value: An `OBJECT`.
            index: The member's position.

        Returns:
            The key's id in `names`.
        """
        return Int(
            self.items.unsafe_ptr()[
                unsafe_offset=Int(self.node(value).start) + 2 * index
            ]
        )

    @always_inline
    def member_value(self, value: Int, index: Int) -> Int:
        """Return the value of a member of an object.

        Args:
            value: An `OBJECT`.
            index: The member's position.

        Returns:
            The member's value.
        """
        return Int(
            self.items.unsafe_ptr()[
                unsafe_offset=Int(self.node(value).start) + 2 * index + 1
            ]
        )

    def find(self, value: Int, name: Int) -> Int:
        """Return the value of the member with a key.

        Args:
            value: Any value; only an `OBJECT` has members.
            name: The key's id in `names`.

        Returns:
            The member's value, or `NO_VALUE`.
        """
        if self.kind(value) != ValueKind.OBJECT:
            return NO_VALUE
        var found = self.node(value)
        var base = self.items.unsafe_ptr().unsafe_offset(Int(found.start))
        var index = 0
        var count = Int(found.count)
        while index < count:
            if Int(base[unsafe_offset=2 * index]) == name:
                return Int(base[unsafe_offset=2 * index + 1])
            index += 1
        return NO_VALUE

    def get(self, value: Int, key: StringSlice) -> Int:
        """Return the value of the member with a key text.

        Args:
            value: Any value.
            key: The key.

        Returns:
            The member's value, or `NO_VALUE`.
        """
        var name = self.names.find(key)
        if name < 0:
            return NO_VALUE
        return self.find(value, name)

    # --- building -------------------------------------------------------

    def add_text(mut self, kind: ValueKind, text: Span[UInt8, _]) -> Int:
        """Add a number or a string from its text.

        Args:
            kind: `NUMBER` or `STRING`.
            text: The `JSON.stringify` text of the number, or the decoded
                string.

        Returns:
            The new value.
        """
        var start = len(self.bytes)
        self.bytes.extend(text)
        self.nodes.append(ValueNode(kind, Int32(start), Int32(len(text))))
        return len(self.nodes) - 1

    def add_string(mut self, text: StringSlice) -> Int:
        """Add a string.

        Args:
            text: The decoded string.

        Returns:
            The new value.
        """
        return self.add_text(ValueKind.STRING, text.as_bytes())

    def add_float(mut self, number: Float64) -> Int:
        """Add a number; NaN and the infinities become `null`.

        Args:
            number: The number.

        Returns:
            The new value.
        """
        if number - number != 0.0:
            return NULL_VALUE
        var text = List[UInt8]()
        write_number(text, number)
        return self.add_text(ValueKind.NUMBER, Span(text))

    def add_int(mut self, number: Int) -> Int:
        """Add an integer, as a JavaScript number.

        Args:
            number: The integer.

        Returns:
            The new value.
        """
        return self.add_float(Float64(number))

    def add_number_text(mut self, text: Span[UInt8, _]) -> Int:
        """Add a number from any JSON or GraphQL number text.

        Args:
            text: The text, such as `1.50` or `1e3`.

        Returns:
            The value with the `JSON.stringify` text, such as `1.5`.
        """
        return self.add_float(read_float64(text))

    @always_inline
    def add_bool(mut self, flag: Bool) -> Int:
        """Return the shared `true` or `false` value.

        Args:
            flag: The boolean.

        Returns:
            `TRUE_VALUE` or `FALSE_VALUE`.
        """
        return TRUE_VALUE if flag else FALSE_VALUE

    def add_reference_to(mut self, id: Int) -> Int:
        """Add a `Reference` to an interned entity id.

        Args:
            id: The id's index in `ids`.

        Returns:
            The new value.
        """
        self.nodes.append(ValueNode(ValueKind.REFERENCE, Int32(id), 0))
        return len(self.nodes) - 1

    def add_reference(mut self, id: StringSlice) -> Int:
        """Add a `Reference`, as Apollo Client `makeReference`.

        Args:
            id: The entity id.

        Returns:
            The new value.
        """
        return self.add_reference_to(self.ids.intern(id))

    def add_reference_with(mut self, id: Int, extras: Int) -> Int:
        """Add a `Reference` that has members besides `__ref`.

        Upstream `isReference` only looks at `__ref`, so an object such as
        `{ __ref: "Gene:1", id: 1 }`, which a deep merge can make, is a
        `Reference` too.

        Args:
            id: The id's index in `ids`.
            extras: An `OBJECT` of the other members, or `NO_VALUE`.

        Returns:
            The new value.
        """
        self.nodes.append(
            ValueNode(ValueKind.REFERENCE, Int32(id), Int32(extras + 1))
        )
        return len(self.nodes) - 1

    @always_inline
    def ref_extras(self, value: Int) -> Int:
        """Return the members of a `Reference` besides `__ref`.

        Args:
            value: A `REFERENCE`.

        Returns:
            An `OBJECT`, or `NO_VALUE` when it has none.
        """
        return Int(self.node(value).count) - 1

    def add_array(mut self, items: List[Int]) -> Int:
        """Add an array.

        Args:
            items: The items, in order.

        Returns:
            The new value.
        """
        var start = len(self.items)
        var index = 0
        while index < len(items):
            self.items.append(Int32(items[index]))
            index += 1
        self.nodes.append(
            ValueNode(ValueKind.ARRAY, Int32(start), Int32(len(items)))
        )
        return len(self.nodes) - 1

    def add_object(mut self, members: List[Member]) -> Int:
        """Add an object.

        Args:
            members: The members, in order, with distinct keys.

        Returns:
            The new value.
        """
        return self.add_members(Span(members))

    def add_members(mut self, members: Span[Member, _]) -> Int:
        """Add an object from a span of members.

        Args:
            members: The members, in order, with distinct keys.

        Returns:
            The new value.
        """
        var start = len(self.items)
        var index = 0
        while index < len(members):
            self.items.append(members[index].name)
            self.items.append(members[index].value)
            index += 1
        self.nodes.append(
            ValueNode(ValueKind.OBJECT, Int32(start), Int32(len(members)))
        )
        return len(self.nodes) - 1

    def members(self, value: Int) -> List[Member]:
        """Return the members of an object.

        Args:
            value: Any value; only an `OBJECT` has members.

        Returns:
            The members, in order.
        """
        var out = List[Member]()
        var count = self.length(value) if self.is_object(value) else 0
        var index = 0
        while index < count:
            out.append(
                Member(
                    Int32(self.member_name(value, index)),
                    Int32(self.member_value(value, index)),
                )
            )
            index += 1
        return out^

    def array_items(self, value: Int) -> List[Int]:
        """Return the items of an array.

        Args:
            value: Any value; only an `ARRAY` has items.

        Returns:
            The items, in order.
        """
        var out = List[Int]()
        var count = self.length(value) if self.is_array(value) else 0
        var index = 0
        while index < count:
            out.append(self.item(value, index))
            index += 1
        return out^

    # --- JSON -----------------------------------------------------------

    def from_json(mut self, document: JsonDocument, node: Int) -> Int:
        """Add a copy of a JSON value.

        An object with a string `__ref` member and no other member becomes
        a `Reference`, as Apollo Client reads it.

        Args:
            document: The JSON document.
            node: The value in it, or `NO_NODE` for `undefined`.

        Returns:
            The new value, or `NO_VALUE` for `NO_NODE`.
        """
        if node == NO_NODE:
            return NO_VALUE
        var found = document.nodes.unsafe_ptr()[unsafe_offset=node]
        var kind = found.kind
        if kind == JsonKind.STRING:
            if found.flags & FLAG_ESCAPED != 0:
                return self.add_string(document.string_value(node))
            return self.add_text(
                ValueKind.STRING, document.text(node).as_bytes()
            )
        if kind == JsonKind.NUMBER:
            if found.flags & FLAG_CANONICAL != 0:
                return self.add_text(
                    ValueKind.NUMBER, document.text(node).as_bytes()
                )
            return self.add_float(document.as_float64(node))
        if kind == JsonKind.NULL:
            return NULL_VALUE
        if kind == JsonKind.BOOLEAN:
            return self.add_bool(document.bool_value(node))
        if kind == JsonKind.ARRAY:
            var items = List[Int](capacity=Int(found.count))
            var child = Int(found.start)
            while child != NO_NODE:
                items.append(self.from_json(document, child))
                child = document.next(child)
            return self.add_array(items)
        var members = List[Member](capacity=Int(found.count))
        var child = Int(found.start)
        while child != NO_NODE:
            var name: Int
            if document.nodes[child].flags & FLAG_KEY_ESCAPED != 0:
                name = self.names.intern(document.key(child))
            else:
                name = self.names.intern(document.raw_key(child))
            _set_member(
                members, Int32(name), Int32(self.from_json(document, child))
            )
            child = document.next(child)
        # An object with a string `__ref` is a `Reference`, as upstream
        # `isReference` decides; its other members stay with it.
        var position = _member_position(members, Int32(REF_NAME))
        if position >= 0 and self.kind(Int(members[position].value)) == (
            ValueKind.STRING
        ):
            var id = self.ids.intern(self.text(Int(members[position].value)))
            _ = members.pop(position)
            var extras = NO_VALUE
            if len(members) > 0:
                extras = self.add_object(members)
            return self.add_reference_with(id, extras)
        return self.add_object(members)

    def to_json(self, mut document: JsonDocument, value: Int) -> Int:
        """Add a copy of a value to a JSON document.

        `undefined` members of an object are left out, and an `undefined`
        item becomes `null`, as `JSON.stringify` writes them.

        Args:
            document: The JSON document.
            value: The value.

        Returns:
            The new node, with no parent.
        """
        var kind = self.kind(value)
        if kind == ValueKind.STRING:
            return push_json_text(
                document,
                JsonKind.STRING,
                FLAG_DECODED,
                self.text(value).as_bytes(),
            )
        if kind == ValueKind.NUMBER:
            return push_json_text(
                document,
                JsonKind.NUMBER,
                FLAG_CANONICAL,
                self.text(value).as_bytes(),
            )
        if kind == ValueKind.TRUE:
            return document.add_bool(True)
        if kind == ValueKind.FALSE:
            return document.add_bool(False)
        if kind == ValueKind.REFERENCE:
            var object = document.add_object()
            var id = push_json_text(
                document,
                JsonKind.STRING,
                FLAG_DECODED,
                self.ref_text(value).as_bytes(),
            )
            document.add_member(object, "__ref", id)
            var extras = self.ref_extras(value)
            var count = self.length(extras)
            var index = 0
            while index < count:
                document.add_member(
                    object,
                    self.names.text(self.member_name(extras, index)),
                    self.to_json(document, self.member_value(extras, index)),
                )
                index += 1
            return object
        if kind == ValueKind.ARRAY:
            var array = document.add_array()
            var count = self.length(value)
            var index = 0
            while index < count:
                document.append(
                    array, self.to_json(document, self.item(value, index))
                )
                index += 1
            return array
        if kind == ValueKind.OBJECT:
            var object = document.add_object()
            var order = self.member_order(value)
            var index = 0
            while index < len(order):
                var member = self.member_value(value, order[index])
                if not self.is_undefined(member):
                    document.add_member(
                        object,
                        self.names.text(self.member_name(value, order[index])),
                        self.to_json(document, member),
                    )
                index += 1
            return object
        return document.add_null()

    def member_order(self, value: Int) -> List[Int]:
        """Return the positions of an object's members in ECMAScript order.

        The keys that are array indices come first, in numeric order, and
        then the other keys in the order they were added.

        Args:
            value: An `OBJECT`.

        Returns:
            The member positions.
        """
        var count = self.length(value)
        var out = List[Int](capacity=count)
        var indexed = List[Int]()
        var index = 0
        while index < count:
            if self.names.indexes[self.member_name(value, index)] >= 0:
                indexed.append(index)
            else:
                out.append(index)
            index += 1
        if len(indexed) == 0:
            return out^
        # Insertion sort by numeric value: index keys are rare and few.
        var position = 1
        while position < len(indexed):
            var current = indexed[position]
            var number = self.names.indexes[self.member_name(value, current)]
            var back = position
            while back > 0 and (
                self.names.indexes[self.member_name(value, indexed[back - 1])]
                > number
            ):
                indexed[back] = indexed[back - 1]
                back -= 1
            indexed[back] = current
            position += 1
        indexed.extend(Span(out))
        return indexed^

    def write(self, mut writer: JsonWriter, value: Int, display: Bool = False):
        """Write a value as `JSON.stringify` writes it.

        Args:
            writer: The destination.
            value: The value; `undefined` writes `null`.
            display: Write `undefined` as `<undefined>` and keep the
                `undefined` members, as upstream `stringifyForDisplay`.
        """
        var kind = self.kind(value)
        if kind == ValueKind.STRING:
            writer.string(self.text(value))
        elif kind == ValueKind.NUMBER:
            writer.raw(self.text(value))
        elif kind == ValueKind.TRUE:
            writer.bool(True)
        elif kind == ValueKind.FALSE:
            writer.bool(False)
        elif kind == ValueKind.REFERENCE:
            writer.begin_object()
            writer.key("__ref")
            writer.string(self.ref_text(value))
            var extras = self.ref_extras(value)
            var count = self.length(extras)
            var index = 0
            while index < count:
                writer.key(self.names.text(self.member_name(extras, index)))
                self.write(writer, self.member_value(extras, index), display)
                index += 1
            writer.end_object()
        elif kind == ValueKind.ARRAY:
            writer.begin_array()
            var count = self.length(value)
            var index = 0
            while index < count:
                self.write(writer, self.item(value, index), display)
                index += 1
            writer.end_array()
        elif kind == ValueKind.OBJECT:
            writer.begin_object()
            var order = self.member_order(value)
            var index = 0
            while index < len(order):
                var member = self.member_value(value, order[index])
                if display or not self.is_undefined(member):
                    writer.key(
                        self.names.text(self.member_name(value, order[index]))
                    )
                    self.write(writer, member, display)
                index += 1
            writer.end_object()
        else:
            if display and kind == ValueKind.UNDEFINED:
                writer.raw("<undefined>")
            else:
                writer.null()

    def stringify(self, value: Int, indent: Int = 0) -> String:
        """Return the `JSON.stringify` text of a value.

        Args:
            value: The value; `undefined` gives `null`.
            indent: The spaces for each level, as the third argument of
                `JSON.stringify`.

        Returns:
            The JSON text.
        """
        var writer = JsonWriter(indent)
        self.write(writer, value)
        return writer^.take_string()

    def display(self, value: Int) -> String:
        """Return a value as an upstream error message shows it.

        This is `stringifyForDisplay(value, 2).slice(0, 1000)` of the
        upstream `invariant` messages; a string is shown as it is.

        Args:
            value: The value.

        Returns:
            The text, at most 1000 bytes.
        """
        if self.kind(value) == ValueKind.STRING:
            return String(self.text(value))
        var writer = JsonWriter(2)
        self.write(writer, value, True)
        var bytes = writer^.take_bytes()
        if len(bytes) > 1000:
            var cut = 1000
            while bytes[cut] & 0xC0 == 0x80:
                cut -= 1
            bytes.resize(cut, 0)
        return String(unsafe_from_utf8=bytes)

    def canonical_stringify(self, value: Int) -> String:
        """Return the text of Apollo Client `canonicalStringify`.

        That is `JSON.stringify` with the keys of each object sorted. The
        keys that are array indices still come first, in numeric order, as
        ECMAScript writes them.

        Args:
            value: The value.

        Returns:
            The JSON text.
        """
        var writer = JsonWriter()
        self.write_canonical(writer, value)
        return writer^.take_string()

    def write_canonical(self, mut writer: JsonWriter, value: Int):
        """Write a value with the keys of each object sorted.

        Args:
            writer: The destination.
            value: The value.
        """
        var kind = self.kind(value)
        if kind == ValueKind.ARRAY:
            writer.begin_array()
            var count = self.length(value)
            var index = 0
            while index < count:
                self.write_canonical(writer, self.item(value, index))
                index += 1
            writer.end_array()
        elif kind == ValueKind.OBJECT:
            writer.begin_object()
            var order = self.sorted_members(value)
            var index = 0
            while index < len(order):
                var member = self.member_value(value, order[index])
                if not self.is_undefined(member):
                    writer.key(
                        self.names.text(self.member_name(value, order[index]))
                    )
                    self.write_canonical(writer, member)
                index += 1
            writer.end_object()
        else:
            self.write(writer, value)

    def sorted_members(self, value: Int) -> List[Int]:
        """Return the positions of an object's members, sorted by key.

        Args:
            value: An `OBJECT`.

        Returns:
            The positions: array index keys in numeric order, then the
            other keys in JavaScript string order.
        """
        var order = self.member_order(value)
        var first = 0
        while first < len(order) and (
            self.names.indexes[self.member_name(value, order[first])] >= 0
        ):
            first += 1
        var position = first + 1
        while position < len(order):
            var current = order[position]
            var back = position
            while back > first and utf16_less(
                self.names.text(self.member_name(value, current)),
                self.names.text(self.member_name(value, order[back - 1])),
            ):
                order[back] = order[back - 1]
                back -= 1
            order[back] = current
            position += 1
        return order^

    # --- comparing and merging --------------------------------------------

    def equal(self, a: Int, b: Int) -> Bool:
        """Return True when two values are deeply equal.

        This is `@wry/equality` `equal` on the values that a cache holds.

        Args:
            a: A value, or `NO_VALUE`.
            b: A value, or `NO_VALUE`.

        Returns:
            Whether they are equal.
        """
        if a == b:
            return True
        var kind = self.kind(a)
        if kind != self.kind(b):
            return False
        if kind.value <= ValueKind.UNDEFINED.value:
            return True
        if kind == ValueKind.NUMBER or kind == ValueKind.STRING:
            return self.text(a) == self.text(b)
        if kind == ValueKind.REFERENCE:
            return self.ref_id(a) == self.ref_id(b) and self.equal(
                self.ref_extras(a), self.ref_extras(b)
            )
        var count = self.length(a)
        if count != self.length(b):
            return False
        var index = 0
        if kind == ValueKind.ARRAY:
            while index < count:
                if not self.equal(self.item(a, index), self.item(b, index)):
                    return False
                index += 1
            return True
        while index < count:
            var other = self.find(b, self.member_name(a, index))
            if other == NO_VALUE or not self.equal(
                self.member_value(a, index), other
            ):
                return False
            index += 1
        return True

    def merge(mut self, target: Int, source: Int) -> Int:
        """Deep merge two values, as the default `DeepMerger` merges them.

        Two objects merge member by member, and two arrays merge item by
        item. Any other source replaces the target. The result is `target`
        when the merge changes nothing.

        Args:
            target: The existing value, or `NO_VALUE`.
            source: The incoming value, or `NO_VALUE`.

        Returns:
            The merged value.
        """
        var kind = self.kind(source)
        var target_kind = self.kind(target)
        if target_kind == ValueKind.REFERENCE and (
            kind == ValueKind.OBJECT or kind == ValueKind.REFERENCE
        ):
            return self._merge_reference(target, source)
        if target_kind == ValueKind.ARRAY and kind == ValueKind.OBJECT:
            # `DeepMerger` adds the object's members to the array as
            # properties that are not items: no array operation and no
            # `JSON.stringify` sees them, so the array stays.
            return target
        if kind != target_kind:
            return source
        if kind.value < ValueKind.REFERENCE.value:
            # `DeepMerger` keeps the target when `source !== target`
            # is false, which for a scalar is equality of the values.
            return target if self.equal(target, source) else source
        if kind == ValueKind.OBJECT:
            var members = self.members(target)
            var changed = False
            var count = self.length(source)
            var index = 0
            while index < count:
                var name = Int32(self.member_name(source, index))
                var incoming = self.member_value(source, index)
                var position = _member_position(members, name)
                if position < 0:
                    members.append(Member(name, Int32(incoming)))
                    changed = True
                else:
                    var existing = Int(members[position].value)
                    if incoming != existing:
                        var merged = self.merge(existing, incoming)
                        if merged != existing:
                            members[position].value = Int32(merged)
                            changed = True
                index += 1
            if not changed:
                return target
            return self.add_object(members)
        # Both are arrays: `_merge_reference` took the references.
        var items = self.array_items(target)
        var changed = False
        var count = self.length(source)
        var index = 0
        while index < count:
            var incoming = self.item(source, index)
            if index >= len(items):
                items.append(incoming)
                changed = True
            elif incoming != items[index]:
                var merged = self.merge(items[index], incoming)
                if merged != items[index]:
                    items[index] = merged
                    changed = True
            index += 1
        if not changed:
            return target
        return self.add_array(items)

    def _merge_reference(mut self, target: Int, source: Int) -> Int:
        """Deep merge an object or a `Reference` into a `Reference`.

        `DeepMerger` sees `{ __ref }` as a plain object: the source's
        `__ref` wins, and the other members merge.
        """
        var id = self.ref_id(target)
        var incoming = source
        if self.is_reference(source):
            id = self.ref_id(source)
            incoming = self.ref_extras(source)
        var extras = self.ref_extras(target)
        var merged = extras
        if incoming != NO_VALUE:
            merged = self.merge(extras, incoming)
        if id == self.ref_id(target) and merged == extras:
            return target
        return self.add_reference_with(id, merged)

    def truthy(self, value: Int) -> Bool:
        """Return the JavaScript truth of a value.

        Args:
            value: A value, or `NO_VALUE`.

        Returns:
            False for `null`, `undefined`, `false`, `0`, `-0` and `""`;
            True for everything else.
        """
        var kind = self.kind(value)
        if kind == ValueKind.NUMBER:
            var found = self.node(value)
            return found.count != 1 or self.bytes[Int(found.start)] != UInt8(
                ord("0")
            )
        if kind == ValueKind.STRING:
            return self.node(value).count > 0
        return kind == ValueKind.TRUE or kind.value > ValueKind.STRING.value

    # --- compaction -------------------------------------------------------

    def copy_into(
        self, mut target: Values, value: Int, mut moved: List[Int32]
    ) -> Int:
        """Copy a value and all that it holds into another arena.

        The other arena must share this arena's `names` and `ids`. A value
        that was copied before is not copied again.

        Args:
            target: The new arena.
            value: The value, or `NO_VALUE`.
            moved: For each old value, its new index, or -1.

        Returns:
            The new index.
        """
        if value <= UNDEFINED_VALUE:
            return value
        if moved[value] >= 0:
            return Int(moved[value])
        var found = self.node(value)
        var copy: Int
        if found.kind == ValueKind.ARRAY:
            var items = List[Int](capacity=Int(found.count))
            var index = 0
            while index < Int(found.count):
                items.append(
                    self.copy_into(target, self.item(value, index), moved)
                )
                index += 1
            copy = target.add_array(items)
        elif found.kind == ValueKind.OBJECT:
            var members = self.members(value)
            var index = 0
            while index < len(members):
                members[index].value = Int32(
                    self.copy_into(target, Int(members[index].value), moved)
                )
                index += 1
            copy = target.add_object(members)
        elif found.kind == ValueKind.REFERENCE:
            var extras = self.copy_into(target, self.ref_extras(value), moved)
            copy = target.add_reference_with(Int(found.start), extras)
        else:
            copy = target.add_text(found.kind, self.text(value).as_bytes())
        moved[value] = Int32(copy)
        return copy


def _member_position(members: List[Member], name: Int32) -> Int:
    """Return the position of the member with a key, or -1."""
    var index = 0
    while index < len(members):
        if members[index].name == name:
            return index
        index += 1
    return -1


def _set_member(mut members: List[Member], name: Int32, value: Int32):
    """Set a member: replace the value of a key that is there, as a later
    duplicate key replaces an earlier one in `JSON.parse`."""
    var position = _member_position(members, name)
    if position < 0:
        members.append(Member(name, value))
    else:
        members[position].value = value


def push_json_text(
    mut document: JsonDocument,
    kind: JsonKind,
    flags: UInt8,
    text: Span[UInt8, _],
) -> Int:
    """Add a scalar node to a JSON document, with its text after the bytes.

    Args:
        document: The document.
        kind: `STRING` or `NUMBER`.
        flags: The node flags: 4 (decoded) for a string, `FLAG_CANONICAL`
            for a number in its `JSON.stringify` form.
        text: The decoded string, or the number text.

    Returns:
        The new node, with no parent.
    """
    var start = len(document.bytes)
    document.bytes.extend(text)
    document.nodes.append(
        JsonNode(
            kind,
            flags,
            Int32(start),
            Int32(len(document.bytes)),
            0,
            0,
            0,
            Int32(NO_NODE),
        )
    )
    return len(document.nodes) - 1
