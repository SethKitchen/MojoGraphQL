# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The static and the dynamic tables of HPACK (RFC 7541 section 2.3).

The static table has 61 fixed entries (Appendix A). The dynamic table is
a first-in, first-out list of the fields that the peer told us to keep.
An entry has the size of its name, its value and 32 bytes (section 4.1).
When an insertion makes the table too large, the oldest entries go first
(section 4.4).

`DynamicTable` keeps the bytes of its entries in one buffer, in the order
of insertion. An eviction only moves a start offset; when enough evicted
bytes collect, one copy removes them. An encoder table also keeps the
entries in 128 hash chains by name, newest first, so that a lookup reads
only the entries of one chain. An eviction takes the oldest entries, so a
chain needs no removal: a walk stops at the first entry that is gone.

Ports the static table of `src/hpack/decoder.rs` (`get_static`) and of
`src/hpack/table.rs` (`index_static`), and the size rules of both tables,
of hyperium/h2 v0.4.20 (MIT).

Differences from upstream: h2 indexes the encoder table with a Robin Hood
hash map of name chains, and keeps the decoder table as a deque of
`Header` values. This module uses one byte buffer and FIFO hash chains for
both, with the same lookups, the same evictions and the same results.
"""

from std.builtin.globals import global_constant
from std.memory import unsafe_memcpy

comptime STATIC_TABLE_LENGTH = 61
"""The number of entries in the static table."""
comptime ENTRY_OVERHEAD = 32
"""The bytes that RFC 7541 adds to the size of each entry."""
comptime HASH_BUCKETS = 128
"""The number of name chains of an encoder table."""
comptime _COMPACT_BYTES = 16384
"""The least number of evicted bytes that starts a compaction."""

comptime _STATIC_NAMES: Array[StaticString, 62] = [
    "",
    ":authority",
    ":method",
    ":method",
    ":path",
    ":path",
    ":scheme",
    ":scheme",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    ":status",
    "accept-charset",
    "accept-encoding",
    "accept-language",
    "accept-ranges",
    "accept",
    "access-control-allow-origin",
    "age",
    "allow",
    "authorization",
    "cache-control",
    "content-disposition",
    "content-encoding",
    "content-language",
    "content-length",
    "content-location",
    "content-range",
    "content-type",
    "cookie",
    "date",
    "etag",
    "expect",
    "expires",
    "from",
    "host",
    "if-match",
    "if-modified-since",
    "if-none-match",
    "if-range",
    "if-unmodified-since",
    "last-modified",
    "link",
    "location",
    "max-forwards",
    "proxy-authenticate",
    "proxy-authorization",
    "range",
    "referer",
    "refresh",
    "retry-after",
    "server",
    "set-cookie",
    "strict-transport-security",
    "transfer-encoding",
    "user-agent",
    "vary",
    "via",
    "www-authenticate",
]
"""The name of each static entry; entry 0 is not used."""

comptime _STATIC_VALUES: Array[StaticString, 62] = [
    "",
    "",
    "GET",
    "POST",
    "/",
    "/index.html",
    "http",
    "https",
    "200",
    "204",
    "206",
    "304",
    "400",
    "404",
    "500",
    "",
    "gzip, deflate",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
]
"""The value of each static entry; most are empty."""

comptime _STATIC_FIRST: Array[UInt8, 63] = [
    0, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 8, 8, 8, 8, 15,
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 0,
]  # fmt: skip
"""For each static entry: the first entry with the same name."""


def static_name(index: Int) -> StaticString:
    """Return the name of a static table entry.

    Args:
        index: The index, 1 to 61.

    Returns:
        The name, such as `:method`.
    """
    return global_constant[_STATIC_NAMES]().unsafe_ptr()[unsafe_offset=index]


def static_value(index: Int) -> StaticString:
    """Return the value of a static table entry.

    Args:
        index: The index, 1 to 61.

    Returns:
        The value, such as `GET`; empty for most entries.
    """
    return global_constant[_STATIC_VALUES]().unsafe_ptr()[unsafe_offset=index]


@always_inline
def _word(data: Pointer[UInt8, _], offset: Int) -> UInt64:
    """Read 8 bytes at an offset."""
    return (
        data.unsafe_offset(offset)
        .unsafe_bitcast[UInt64]()
        .unsafe_load[alignment=1]()
    )


@always_inline
def _half(data: Pointer[UInt8, _], offset: Int) -> UInt32:
    """Read 4 bytes at an offset."""
    return (
        data.unsafe_offset(offset)
        .unsafe_bitcast[UInt32]()
        .unsafe_load[alignment=1]()
    )


@always_inline
def bytes_equal(
    a: Pointer[UInt8, _], b: Pointer[UInt8, _], length: Int
) -> Bool:
    """Return True when two runs of bytes are equal.

    The compare reads 8 bytes at a time, and the last 8 bytes again, so a
    field name takes one or two loads. It reads no byte past `length`.

    Args:
        a: The first bytes.
        b: The second bytes.
        length: How many bytes to compare.

    Returns:
        Whether the bytes are equal.
    """
    if length >= 8:
        var offset = 0
        while offset + 8 < length:
            if _word(a, offset) != _word(b, offset):
                return False
            offset += 8
        return _word(a, length - 8) == _word(b, length - 8)
    if length >= 4:
        var head = _half(a, 0) == _half(b, 0)
        return head and _half(a, length - 4) == _half(b, length - 4)
    var index = 0
    while index < length:
        if a[unsafe_offset=index] != b[unsafe_offset=index]:
            return False
        index += 1
    return True


@always_inline
def _copy(
    dst: Pointer[mut=True, UInt8, _], src: Pointer[UInt8, _], length: Int
):
    """Copy bytes 8 at a time, the last 8 again; a short name or value
    takes one or two moves, without a call."""
    if length >= 8:
        var offset = 0
        while offset + 8 < length:
            dst.unsafe_offset(offset).unsafe_bitcast[UInt64]().unsafe_store[
                alignment=1
            ](_word(src, offset))
            offset += 8
        dst.unsafe_offset(length - 8).unsafe_bitcast[UInt64]().unsafe_store[
            alignment=1
        ](_word(src, length - 8))
        return
    if length >= 4:
        var head = _half(src, 0)
        var tail = _half(src, length - 4)
        dst.unsafe_bitcast[UInt32]().unsafe_store[alignment=1](head)
        dst.unsafe_offset(length - 4).unsafe_bitcast[UInt32]().unsafe_store[
            alignment=1
        ](tail)
        return
    var index = 0
    while index < length:
        dst[unsafe_offset=index] = src[unsafe_offset=index]
        index += 1


@always_inline
def append_pair(
    mut out: List[UInt8], first: Span[UInt8, _], second: Span[UInt8, _]
):
    """Append two runs of bytes to a buffer, with one capacity check.

    Args:
        out: The buffer.
        first: The bytes to append first.
        second: The bytes to append after them.
    """
    var start = len(out)
    var total = start + len(first) + len(second)
    if total > out.capacity():
        out.reserve(max(total, out.capacity() * 2))
    var dst = out.unsafe_ptr().unsafe_offset(start)
    _copy(dst, first.unsafe_ptr(), len(first))
    _copy(dst.unsafe_offset(len(first)), second.unsafe_ptr(), len(second))
    out.resize(unsafe_uninit_length=total)


@always_inline
def _same(
    a: Pointer[UInt8, _], a_length: Int, b: Pointer[UInt8, _], b_length: Int
) -> Bool:
    """Return True when two byte strings are equal."""
    return a_length == b_length and bytes_equal(a, b, a_length)


@always_inline
def name_hash(name: Span[UInt8, _]) -> UInt64:
    """Return the hash of a field name, for the encoder's lookups.

    The hash reads the first and the last 8 bytes, or fewer for a short
    name, and the length. Its top 7 bits select a chain.

    Args:
        name: The name.

    Returns:
        The hash.
    """
    var length = len(name)
    var data = name.unsafe_ptr()
    var first: UInt64 = 0
    var last: UInt64 = 0
    if length >= 8:
        first = data.unsafe_bitcast[UInt64]().unsafe_load[alignment=1]()
        last = (
            data.unsafe_offset(length - 8)
            .unsafe_bitcast[UInt64]()
            .unsafe_load[alignment=1]()
        )
    elif length >= 4:
        first = UInt64(data.unsafe_bitcast[UInt32]().unsafe_load[alignment=1]())
        last = UInt64(
            data.unsafe_offset(length - 4)
            .unsafe_bitcast[UInt32]()
            .unsafe_load[alignment=1]()
        )
    elif length > 0:
        first = (
            UInt64(data[unsafe_offset=0])
            | (UInt64(data[unsafe_offset=length >> 1]) << 8)
            | (UInt64(data[unsafe_offset=length - 1]) << 16)
        )
    var hash = (first * 0x9E3779B97F4A7C15) ^ (last * 0xC2B2AE3D27D4EB4F)
    hash ^= UInt64(length) * 0x165667B19E3779F9
    hash ^= hash >> 29
    return hash * 0x9E3779B97F4A7C15


@always_inline
def _slot(hash: UInt64) -> Int:
    """Return the chain or the slot of a hash: its top 7 bits."""
    return Int(hash >> 57)


# Generated from the static names and `name_hash`. `test_hpack_encoder.mojo`
# builds it again and checks that it is the same.
comptime _STATIC_SLOTS: Array[UInt8, 128] = [
    0x0, 0x0, 0x27, 0x30, 0x0, 0x0, 0x3a, 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x2, 0x22,
    0x0, 0x0, 0x0, 0x2d, 0x0, 0x0, 0x15, 0x0, 0x0, 0x0, 0x19, 0x1f, 0x36, 0x0, 0x0, 0x8,
    0x0, 0x0, 0x0, 0x14, 0x11, 0x0, 0x0, 0x0, 0x1a, 0x0, 0x0, 0x25, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x16, 0x2f, 0x38, 0x0, 0x3c, 0x18, 0x0, 0x17, 0x1b, 0x2c, 0x31, 0x0, 0x29,
    0x0, 0x37, 0x3d, 0x0, 0x0, 0x24, 0x0, 0x0, 0x1d, 0x0, 0x0, 0x34, 0x1c, 0x20, 0x26, 0x3b,
    0x12, 0x1, 0xf, 0x13, 0x32, 0x0, 0x0, 0x0, 0x0, 0x35, 0x39, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x28, 0x0, 0x0, 0x21, 0x6, 0x0, 0x0, 0x0, 0x0, 0x0, 0x4, 0x1e, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x2a, 0x0, 0x0, 0x0, 0x0, 0x0, 0x23, 0x0, 0x0, 0x2b, 0x2e, 0x0, 0x33, 0x0,
]  # fmt: skip
"""For each of the 128 slots: the first static entry of a name, or 0. A
name goes in the slot of the top 7 bits of its hash, or after it on a
collision."""


@fieldwise_init
struct StaticIndex(ImplicitlyCopyable, Movable):
    """The hash index of the static table names, for the encoder. Its
    table is a constant, so it holds no state."""

    @always_inline
    def find(self, name: Span[UInt8, _], hash: UInt64) -> Int:
        """Return the first static entry with a name.

        Args:
            name: The name.
            hash: `name_hash(name)`.

        Returns:
            The index, 1 to 61, or 0 when no static entry has the name.
        """
        var slots = global_constant[_STATIC_SLOTS]().unsafe_ptr()
        var slot = _slot(hash)
        while True:
            var index = Int(slots[unsafe_offset=slot])
            if index == 0:
                return 0
            var known = static_name(index)
            if _same(
                name.unsafe_ptr(),
                len(name),
                known.unsafe_ptr(),
                known.byte_length(),
            ):
                return index
            slot = (slot + 1) & (HASH_BUCKETS - 1)

    @always_inline
    def find_value(self, first: Int, value: Span[UInt8, _]) -> Int:
        """Return the static entry with a name and a value.

        Only the entries with a value can match: `:method`, `:path`,
        `:scheme`, `:status` and `accept-encoding`, as in h2.

        Args:
            first: The first entry with the name, from `find`, or 0.
            value: The value.

        Returns:
            The index, or 0 when no static entry has both.
        """
        var index = first
        while index > 0 and Int(_static_first(index)) == first:
            var known = static_value(index)
            if known.byte_length() > 0 and _same(
                value.unsafe_ptr(),
                len(value),
                known.unsafe_ptr(),
                known.byte_length(),
            ):
                return index
            index += 1
        return 0


@always_inline
def _static_first(index: Int) -> UInt8:
    """Return the first static entry with the name of an entry; index 62
    gives 0, so a walk stops at the end of the table."""
    return global_constant[_STATIC_FIRST]().unsafe_ptr()[unsafe_offset=index]


@fieldwise_init
struct TableEntry(ImplicitlyCopyable, Movable):
    """Where the bytes of one dynamic table entry are."""

    var start: Int
    """The offset of the name in the table buffer; the value follows."""
    var name_length: Int
    """The length of the name."""
    var value_length: Int
    """The length of the value."""
    var next: Int
    """The sequence number of the next older entry of the same chain, or
    -1; only an encoder table links its entries."""


@fieldwise_init
struct TableMatch(ImplicitlyCopyable, Movable):
    """The result of a dynamic table lookup."""

    var value_index: Int
    """The entry with the name and the value, 0 for the newest; or -1."""
    var name_index: Int
    """The newest entry with the name, 0 for the newest; or -1."""


struct DynamicTable(Copyable, Movable):
    """The dynamic table of one direction of a connection."""

    var _data: List[UInt8]
    """The names and values of the entries, oldest first, after
    `_data_start` evicted bytes."""
    var _entries: List[TableEntry]
    """The entries, oldest first, after `_first` evicted ones."""
    var _first: Int
    """How many entries at the start of `_entries` are evicted."""
    var _data_start: Int
    """How many bytes at the start of `_data` are evicted."""
    var _sequence_base: Int
    """The sequence number of `_entries[0]`."""
    var _chains: List[Int]
    """For each chain: the sequence number of its newest entry, or -1.
    Empty when the table is not indexed."""
    var _size: Int
    """The size of the entries: name, value and 32 for each."""
    var _max_size: Int
    """The largest size the table can have."""

    def __init__(out self, max_size: Int, indexed: Bool):
        """Create an empty table.

        Args:
            max_size: The largest size of the table.
            indexed: Whether `find` can look up the entries. An encoder
                table is indexed; a decoder table is not.
        """
        # One allocation each for a table of the default size.
        self._data = List[UInt8](capacity=min(max_size, 4096))
        self._entries = List[TableEntry](capacity=min(max_size // 64, 64))
        self._first = 0
        self._data_start = 0
        self._sequence_base = 0
        self._chains = List[Int]()
        if indexed:
            self._chains = List[Int](length=HASH_BUCKETS, fill=-1)
        self._size = 0
        self._max_size = max_size

    @always_inline
    def count(self) -> Int:
        """Return the number of entries.

        Returns:
            The count.
        """
        return len(self._entries) - self._first

    @always_inline
    def size(self) -> Int:
        """Return the size of the entries (RFC 7541 section 4.1).

        Returns:
            The sum of name, value and 32 bytes for each entry.
        """
        return self._size

    @always_inline
    def max_size(self) -> Int:
        """Return the largest size that the table can have.

        Returns:
            The maximum size.
        """
        return self._max_size

    @always_inline
    def entry(self, index: Int) -> TableEntry:
        """Return an entry; the caller checks the index.

        Args:
            index: 0 for the newest entry, up to `count() - 1`.

        Returns:
            The entry.
        """
        return self._entries.unsafe_ptr()[
            unsafe_offset=len(self._entries) - 1 - index
        ]

    @always_inline
    def name(self, index: Int) -> Span[UInt8, origin_of(self._data)]:
        """Return the name of an entry.

        Args:
            index: 0 for the newest entry, up to `count() - 1`.

        Returns:
            The bytes of the name.
        """
        var found = self.entry(index)
        return Span[UInt8, origin_of(self._data)](
            unsafe_ptr=self._data.unsafe_ptr().unsafe_offset(found.start),
            length=found.name_length,
        )

    @always_inline
    def value(self, index: Int) -> Span[UInt8, origin_of(self._data)]:
        """Return the value of an entry.

        Args:
            index: 0 for the newest entry, up to `count() - 1`.

        Returns:
            The bytes of the value.
        """
        var found = self.entry(index)
        var start = found.start + found.name_length
        return Span[UInt8, origin_of(self._data)](
            unsafe_ptr=self._data.unsafe_ptr().unsafe_offset(start),
            length=found.value_length,
        )

    def _evict(mut self):
        """Remove the oldest entry."""
        var oldest = self._entries[self._first]
        var length = oldest.name_length + oldest.value_length
        self._size -= length + ENTRY_OVERHEAD
        self._data_start += length
        self._first += 1

    def set_max_size(mut self, size: Int):
        """Set the largest size, and evict the oldest entries over it.

        Args:
            size: The new maximum size.
        """
        self._max_size = size
        while self._size > size:
            self._evict()

    def _compact(mut self):
        """Drop the evicted entries and bytes."""
        var live = List[TableEntry](capacity=self.count())
        var index = self._first
        while index < len(self._entries):
            var moved = self._entries[index]
            moved.start -= self._data_start
            live.append(moved)
            index += 1
        self._data = List[UInt8](Span(self._data)[self._data_start :])
        self._entries = live^
        self._sequence_base += self._first
        self._first = 0
        self._data_start = 0

    def insert(
        mut self, name: Span[UInt8, _], value: Span[UInt8, _], hash: UInt64
    ) -> Bool:
        """Add an entry as the newest, after the evictions it needs.

        An entry larger than the maximum size empties the table, and is
        not added (RFC 7541 section 4.4). The name and the value must not
        be bytes of this table.

        Args:
            name: The name.
            value: The value.
            hash: `name_hash(name)` for an indexed table; else ignored.

        Returns:
            Whether the entry was added.
        """
        var size = len(name) + len(value) + ENTRY_OVERHEAD
        while self._size + size > self._max_size and self.count() > 0:
            self._evict()
        if size > self._max_size:
            return False
        if self._data_start + self._first * ENTRY_OVERHEAD >= max(
            _COMPACT_BYTES, 2 * self._max_size
        ):
            self._compact()
        var start = len(self._data)
        append_pair(self._data, name, value)
        var sequence = self._sequence_base + len(self._entries)
        var next = -1
        if len(self._chains) > 0:
            var chain = _slot(hash)
            next = self._chains[chain]
            self._chains[chain] = sequence
        self._entries.append(TableEntry(start, len(name), len(value), next))
        self._size += size
        return True

    @always_inline
    def find(
        self, name: Span[UInt8, _], value: Span[UInt8, _], hash: UInt64
    ) -> TableMatch:
        """Look up a name and a value in an indexed table.

        Args:
            name: The name.
            value: The value.
            hash: `name_hash(name)`.

        Returns:
            The entry with both, and the newest entry with the name.
        """
        var entries = self._entries.unsafe_ptr()
        var data = self._data.unsafe_ptr()
        var oldest = self._sequence_base + self._first
        var newest = self._sequence_base + len(self._entries) - 1
        var name_index = -1
        var sequence = self._chains[_slot(hash)]
        while sequence >= oldest:
            var found = entries[unsafe_offset=sequence - self._sequence_base]
            if _same(
                data.unsafe_offset(found.start),
                found.name_length,
                name.unsafe_ptr(),
                len(name),
            ):
                if name_index < 0:
                    name_index = newest - sequence
                if _same(
                    data.unsafe_offset(found.start + found.name_length),
                    found.value_length,
                    value.unsafe_ptr(),
                    len(value),
                ):
                    return TableMatch(newest - sequence, name_index)
            sequence = found.next
        return TableMatch(-1, name_index)
