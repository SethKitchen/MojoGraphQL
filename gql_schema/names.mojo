# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A hash table from (owner, name) to an index, looked up without
allocating.

A schema looks names up all the time: a type by its name, a field of a type
by the field's name, an argument of a field by the argument's name. graphql-js
does it with JavaScript object properties. This table does it with one open
addressing array: a key is an owner index (a type, a field, or -1 for the
schema itself) and the bytes of a name, so a lookup takes a `StringSlice`
straight from a parsed document and allocates nothing.

Each operation hashes the key once and probes once. The hash reads a name
8 bytes at a time.

This module has no graphql-js counterpart.
"""

from std.memory import bitcast

comptime NOT_FOUND = -1
"""What `NameTable.find` returns for a name it does not hold."""

comptime _EMPTY = UInt32(0)
"""The hash of a slot with no key. A key's hash always has its low bit
set, so it is never this value."""

comptime _MULTIPLIER: UInt64 = 0x9E3779B97F4A7C15
"""The 64-bit golden ratio, which spreads the bits of each word."""


@always_inline
def _mix(hash: UInt64, word: UInt64) -> UInt64:
    """Fold one 64-bit word into a hash."""
    var mixed = (hash ^ word) * _MULTIPLIER
    return mixed ^ (mixed >> 29)


@always_inline
def _hash(owner: Int, name: Span[UInt8, _]) -> UInt64:
    """Return the hash of an owner and a name.

    Whole 8-byte words are read with one load each; the last bytes are read
    one at a time, so the read never passes the end of the name.
    """
    var hash = _mix(UInt64(len(name)), UInt64(owner + 2))
    var bytes = name.unsafe_ptr()
    var size = len(name)
    var index = 0
    while index + 8 <= size:
        var word = bitcast[DType.uint64, 1](
            bytes.unsafe_offset(index).unsafe_load[width=8]()
        )
        hash = _mix(hash, word)
        index += 8
    var tail: UInt64 = 0
    var shift: UInt64 = 0
    while index < size:
        tail |= UInt64(bytes[unsafe_offset=index]) << shift
        shift += 8
        index += 1
    hash = _mix(hash, tail)
    # A 32-bit hash: the start slot and the tag that a slot keeps.
    return ((hash ^ (hash >> 32)) & 0xFFFFFFFF) | 1


@always_inline
def _load_word(bytes: Pointer[UInt8, _], index: Int) -> UInt64:
    """Read 8 bytes at `index` as one word."""
    return bitcast[DType.uint64, 1](
        bytes.unsafe_offset(index).unsafe_load[width=8]()
    )


@always_inline
def _bytes_equal(
    left: Pointer[UInt8, _], right: Pointer[UInt8, _], size: Int
) -> Bool:
    """Return True if two runs of `size` bytes are equal; names are short,
    so a word loop beats a call to `memcmp`."""
    var index = 0
    while index + 8 <= size:
        if _load_word(left, index) != _load_word(right, index):
            return False
        index += 8
    while index < size:
        if left[unsafe_offset=index] != right[unsafe_offset=index]:
            return False
        index += 1
    return True


@fieldwise_init
struct _Slot(ImplicitlyCopyable, Movable):
    """One slot: a key's hash, owner and name bytes, and its value.

    The slot holds everything a probe compares except the name bytes, so a
    lookup reads the slot and then the bytes: two dependent loads.
    """

    var hash: UInt32
    var owner: Int32
    var start: Int32
    var length: Int32
    var value: Int32


struct NameTable(Copyable, Movable):
    """A map from (owner, name) to a non-negative index."""

    var _slots: List[_Slot]
    var _bytes: List[UInt8]
    var _count: Int

    def __init__(out self, capacity: Int = 8):
        """Start an empty table with room for some keys.

        Args:
            capacity: How many keys the table holds before it grows.
        """
        var slots = 16
        while slots < capacity * 2:
            slots *= 2
        self._slots = List[_Slot](length=slots, fill=_Slot(_EMPTY, 0, 0, 0, 0))
        self._bytes = List[UInt8](capacity=capacity * 8)
        self._count = 0

    def __len__(self) -> Int:
        """Return how many keys the table holds.

        Returns:
            The number of keys.
        """
        return self._count

    @always_inline
    def _probe(self, hash: UInt64, owner: Int, name: Span[UInt8, _]) -> Int:
        """Return the slot that holds a key, or the free slot that ends its
        probe run.

        The table is at most half full, so a free slot ends every probe.
        """
        var mask = len(self._slots) - 1
        var slot = Int(hash) & mask
        var slots = self._slots.unsafe_ptr()
        var bytes = self._bytes.unsafe_ptr()
        var size = len(name)
        while slots[unsafe_offset=slot].hash != _EMPTY:
            ref entry = slots[unsafe_offset=slot]
            if (
                entry.hash == UInt32(hash)
                and Int(entry.owner) == owner
                and Int(entry.length) == size
                and _bytes_equal(
                    bytes.unsafe_offset(Int(entry.start)),
                    name.unsafe_ptr(),
                    size,
                )
            ):
                return slot
            slot = (slot + 1) & mask
        return slot

    def _add(
        mut self,
        slot: Int,
        hash: UInt64,
        owner: Int,
        name: Span[UInt8, _],
        value: Int,
    ):
        """Store a new key in a free slot that `_probe` returned."""
        var start = len(self._bytes)
        self._bytes.extend(name)
        self._slots.unsafe_ptr()[unsafe_offset=slot] = _Slot(
            UInt32(hash),
            Int32(owner),
            Int32(start),
            Int32(len(name)),
            Int32(value),
        )
        self._count += 1

    def find(self, owner: Int, name: StringSlice) -> Int:
        """Return the value stored for an owner and a name.

        Args:
            owner: The owner's index, or a negative key such as -1.
            name: The name.

        Returns:
            The value, or `NOT_FOUND`.
        """
        var bytes = name.as_bytes()
        var slot = self._probe(_hash(owner, bytes), owner, bytes)
        ref entry = self._slots.unsafe_ptr()[unsafe_offset=slot]
        if entry.hash == _EMPTY:
            return NOT_FOUND
        return Int(entry.value)

    def find_or_insert(
        mut self, owner: Int, name: StringSlice, value: Int
    ) -> Int:
        """Return the value stored for a key; store `value` when there is
        none.

        Args:
            owner: The owner's index, or a negative key such as -1.
            name: The name.
            value: A non-negative value, stored for a new key.

        Returns:
            The value that was there, or `NOT_FOUND` for a new key.
        """
        if (self._count + 1) * 2 > len(self._slots):
            self._grow()
        var bytes = name.as_bytes()
        var hash = _hash(owner, bytes)
        var slot = self._probe(hash, owner, bytes)
        ref entry = self._slots.unsafe_ptr()[unsafe_offset=slot]
        if entry.hash != _EMPTY:
            return Int(entry.value)
        self._add(slot, hash, owner, bytes, value)
        return NOT_FOUND

    def insert(mut self, owner: Int, name: StringSlice, value: Int) -> Bool:
        """Store a value for an owner and a name, unless one is there.

        Args:
            owner: The owner's index, or a negative key such as -1.
            name: The name.
            value: A non-negative value.

        Returns:
            True if the key was new; False, and no change, if it was there.
        """
        return self.find_or_insert(owner, name, value) == NOT_FOUND

    def assign(mut self, owner: Int, name: StringSlice, value: Int):
        """Store a value for an owner and a name, replacing any old one.

        Args:
            owner: The owner's index, or a negative key such as -1.
            name: The name.
            value: A non-negative value.
        """
        if (self._count + 1) * 2 > len(self._slots):
            self._grow()
        var bytes = name.as_bytes()
        var hash = _hash(owner, bytes)
        var slot = self._probe(hash, owner, bytes)
        if self._slots.unsafe_ptr()[unsafe_offset=slot].hash != _EMPTY:
            self._slots.unsafe_ptr()[unsafe_offset=slot].value = Int32(value)
            return
        self._add(slot, hash, owner, bytes, value)

    def _grow(mut self):
        """Double the slots and place every key again."""
        var old = self._slots^
        var count = len(old) * 2
        self._slots = List[_Slot](length=count, fill=_Slot(_EMPTY, 0, 0, 0, 0))
        var mask = count - 1
        var slots = self._slots.unsafe_ptr()
        var index = 0
        while index < len(old):
            ref entry = old.unsafe_ptr()[unsafe_offset=index]
            if entry.hash != _EMPTY:
                var slot = Int(entry.hash) & mask
                while slots[unsafe_offset=slot].hash != _EMPTY:
                    slot = (slot + 1) & mask
                slots[unsafe_offset=slot] = entry
            index += 1
