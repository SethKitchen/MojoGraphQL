# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The storage of the QPACK dynamic table (RFC 9204 section 3.2).

The table is a queue: new entries go at the end, and eviction removes the
oldest. The size of the live entries never exceeds the capacity. The names
and the values live in one byte arena. An eviction only moves the first
live entry; the arena drops the dead bytes when they are more than half of
the entries.

`DynamicTable` speaks the 0-based absolute indexes of RFC 9204: the first
entry ever inserted is 0. It keeps a count of unacknowledged references
for each entry, which only the encoder uses: an entry with references is
not evictable (RFC 9204 section 2.1.1).

This module ports the storage of `h3/src/qpack/dynamic.rs` of hyperium/h3
h3-v0.0.8 (22c1aa3), MIT.

Differences from upstream: upstream keeps a `HeaderField` for each entry
in a `VecDeque`, and two hash maps of the latest index of each field and
each name for the encoder. Here an encoder lookup scans the live entries
from the newest; there are at most capacity / 32 of them. Upstream counts
references in a map from index to count; here the count is a list beside
the entries. The tracking of field sections is in `gql_http3.qpack`.
"""

from gql_http3.error import H3Error
from gql_http3.qpack_field import ENTRY_OVERHEAD, field_size
from gql_http3.qpack_vas import VirtualAddressSpace, index_error

comptime SETTINGS_MAX_TABLE_CAPACITY_MAX = 1_073_741_823
"""The largest table capacity that RFC 9204 allows: 2^30 - 1."""
comptime SETTINGS_MAX_BLOCKED_STREAMS_MAX = 65_535
"""The largest number of blocked streams: 2^16 - 1."""


struct DynamicTable(Movable, Writable):
    """The entries of a QPACK dynamic table, oldest first."""

    var capacity: Int
    """The current capacity in bytes; the live entries never exceed it."""
    var size: Int
    """The sum of the sizes of the live entries."""
    var vas: VirtualAddressSpace
    """The insert and eviction counts."""
    var refs: List[Int]
    """For each stored entry, the references that are not acknowledged.
    Use `refs_of` and `add_ref` with an absolute index."""
    var _bytes: List[UInt8]
    """The names and the values."""
    var _starts: List[Int]
    """The offset in `_bytes` of each stored entry."""
    var _name_ends: List[Int]
    """The end offset of each name."""
    var _value_ends: List[Int]
    """The end offset of each value."""
    var _first: Int
    """The list position of the oldest live entry."""
    var _removed: Int
    """The absolute index of list position 0."""

    def __init__(out self):
        """Make an empty table of capacity 0."""
        self.capacity = 0
        self.size = 0
        self.vas = VirtualAddressSpace()
        self.refs = List[Int]()
        self._bytes = List[UInt8]()
        self._starts = List[Int]()
        self._name_ends = List[Int]()
        self._value_ends = List[Int]()
        self._first = 0
        self._removed = 0

    def insert_count(self) -> Int:
        """Return the number of entries ever inserted.

        Returns:
            The insert count.
        """
        return self.vas.inserted

    def dropped(self) -> Int:
        """Return the number of entries evicted.

        Returns:
            The absolute index of the oldest live entry.
        """
        return self.vas.dropped

    def live(self) -> Int:
        """Return the number of live entries.

        Returns:
            The count.
        """
        return self.vas.delta

    @always_inline
    def _position(self, absolute: Int) -> Int:
        """Return the list position of a stored entry."""
        return absolute - self._removed

    def name(self, absolute: Int) -> Span[UInt8, origin_of(self._bytes)]:
        """Return the name of a live entry.

        Args:
            absolute: The 0-based absolute index of the entry.

        Returns:
            The bytes of the name.
        """
        var at = self._position(absolute)
        return Span(self._bytes)[self._starts[at] : self._name_ends[at]]

    def value(self, absolute: Int) -> Span[UInt8, origin_of(self._bytes)]:
        """Return the value of a live entry.

        Args:
            absolute: The 0-based absolute index of the entry.

        Returns:
            The bytes of the value.
        """
        var at = self._position(absolute)
        return Span(self._bytes)[self._name_ends[at] : self._value_ends[at]]

    def _size_at(self, at: Int) -> Int:
        """Return the size of the entry at a list position."""
        return self._value_ends[at] - self._starts[at] + ENTRY_OVERHEAD

    def refs_of(self, absolute: Int) -> Int:
        """Return the unacknowledged references to a live entry.

        Args:
            absolute: The 0-based absolute index of the entry.

        Returns:
            The count.
        """
        return self.refs[self._position(absolute)]

    def add_ref(mut self, absolute: Int, delta: Int):
        """Change the unacknowledged references to a live entry.

        Args:
            absolute: The 0-based absolute index of the entry.
            delta: 1 for a new reference, -1 for an acknowledged one.
        """
        self.refs[self._position(absolute)] += delta

    def before_base(self, base: Int, index: Int) raises H3Error -> Int:
        """Return the absolute index of a field line's relative index.

        Args:
            base: The base of the field section.
            index: The relative index: 0 is the entry at `base - 1`.

        Returns:
            The 0-based absolute index of a live entry.

        Raises:
            H3Error: When no live entry has the index.
        """
        var position = self.vas.relative_base(base, index)
        if position >= self.vas.delta:
            raise index_error("relative", index)
        return position + self.vas.dropped

    def after_base(self, base: Int, index: Int) raises H3Error -> Int:
        """Return the absolute index of a post-base index.

        Args:
            base: The base of the field section.
            index: The post-base index: 0 is the entry at `base`.

        Returns:
            The 0-based absolute index of a live entry.

        Raises:
            H3Error: When no live entry has the index.
        """
        return self.vas.post_base(base, index) + self.vas.dropped

    def from_insert_count(self, index: Int) raises H3Error -> Int:
        """Return the absolute index of an encoder instruction's index.

        Args:
            index: The relative index: 0 is the newest entry.

        Returns:
            The 0-based absolute index of a live entry.

        Raises:
            H3Error: When no live entry has the index.
        """
        return self.vas.relative(index) + self.vas.dropped

    def can_free(self, needed: Int) -> Bool:
        """Return True when evictions can make room for `needed` bytes.

        An entry with an unacknowledged reference cannot be evicted.

        Args:
            needed: The size of the entry to insert.

        Returns:
            Whether `needed` bytes fit after evicting only entries without
            references.
        """
        if needed > self.capacity:
            return False
        var free = self.capacity - self.size
        var at = self._first
        while free < needed:
            if self.refs[at] > 0:
                return False
            free += self._size_at(at)
            at += 1
        return True

    def evict_oldest(mut self):
        """Evict the oldest live entry. The table must have one."""
        self.size -= self._size_at(self._first)
        self._first += 1
        self.vas.drop()

    def set_capacity(mut self, capacity: Int):
        """Change the capacity, and evict the oldest entries until they fit.

        Args:
            capacity: The new capacity.
        """
        self.capacity = capacity
        while self.size > capacity:
            self.evict_oldest()

    def insert(mut self, name: Span[UInt8, _], value: Span[UInt8, _]):
        """Insert an entry; evict the oldest entries to make room.

        The spans must not point into this table. Copy the name of an entry
        first, because the insertion can evict that entry.

        Args:
            name: The name.
            value: The value. The entry size must be at most `capacity`.
        """
        var size = field_size(len(name), len(value))
        while self.capacity - self.size < size:
            self.evict_oldest()
        self._compact()
        self._starts.append(len(self._bytes))
        self._bytes.extend(name)
        self._name_ends.append(len(self._bytes))
        self._bytes.extend(value)
        self._value_ends.append(len(self._bytes))
        self.refs.append(0)
        self.size += size
        _ = self.vas.add()

    def _compact(mut self):
        """Drop the evicted entries when they are more than half the list."""
        if self._first < 32 or self._first * 2 < len(self._starts):
            return
        var shift = self._starts[self._first]
        var count = len(self._starts) - self._first
        var bytes = List[UInt8](capacity=len(self._bytes) - shift)
        bytes.extend(Span(self._bytes)[shift:])
        self._bytes = bytes^
        var index = 0
        while index < count:
            var source = self._first + index
            self._starts[index] = self._starts[source] - shift
            self._name_ends[index] = self._name_ends[source] - shift
            self._value_ends[index] = self._value_ends[source] - shift
            self.refs[index] = self.refs[source]
            index += 1
        self._starts.resize(count, 0)
        self._name_ends.resize(count, 0)
        self._value_ends.resize(count, 0)
        self.refs.resize(count, 0)
        self._removed += self._first
        self._first = 0

    def find(self, name: Span[UInt8, _], value: Span[UInt8, _]) -> Int:
        """Return the newest live entry with a name and a value.

        Args:
            name: The name.
            value: The value.

        Returns:
            The 0-based absolute index, or -1.
        """
        var absolute = self.vas.inserted - 1
        while absolute >= self.vas.dropped:
            if self.value(absolute) == value and self.name(absolute) == name:
                return absolute
            absolute -= 1
        return -1

    def find_name(self, name: Span[UInt8, _]) -> Int:
        """Return the newest live entry with a name.

        Args:
            name: The name.

        Returns:
            The 0-based absolute index, or -1.
        """
        var absolute = self.vas.inserted - 1
        while absolute >= self.vas.dropped:
            if self.name(absolute) == name:
                return absolute
            absolute -= 1
        return -1

    def write_to(self, mut writer: Some[Writer]):
        """Write the capacity, the size and the counts.

        Args:
            writer: The destination.
        """
        writer.write(
            "capacity ", self.capacity, " size ", self.size, " ", self.vas
        )
