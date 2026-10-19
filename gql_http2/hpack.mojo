# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HPACK: the header compression of HTTP/2 (RFC 7541).

`Decoder` turns a header block into a `HeaderList`, and keeps the dynamic
table of the peer's encoder. `Encoder` turns fields into a header block,
and keeps our own dynamic table. Each connection has one of each.

The encoder makes the choices of h2:

- A field whose name and value are in the static table is indexed. Only
  the entries with a value can match, such as `:method: GET`.
- The fields `age`, `authorization`, `content-length`, `cookie`, `etag`,
  `if-modified-since`, `if-none-match`, `location`, `set-cookie` and
  `:path` are never added to the dynamic table: their values change too
  often.
- A field larger than three quarters of the table is not added.
- A sensitive field is never added, and is sent as "never indexed".
- Every other field that is not in the dynamic table is added to it.
- Every string literal is Huffman coded.

A `HeaderList` holds the fields of one block in one byte buffer. The
decoder appends to it. When the fields pass the limit on the list size
(RFC 9113 section 6.5.2), the decoder decodes the rest of the block to
keep its table in step, but adds no more fields, and sets `too_large`.

Ports `src/hpack/decoder.rs`, `src/hpack/encoder.rs` and
`src/hpack/header.rs` of hyperium/h2 v0.4.20 (MIT).

Differences from upstream: the decoder takes a whole block, so a block
that ends inside a field is a `NEED_MORE` error, and h2's resumable
decoding is not needed. The decoder does not check names and values; the
connection checks them (RFC 9113 section 8.2), so h2's `InvalidUtf8`,
`InvalidStatusCode` and `InvalidPseudoheader` errors are not here. The
decoder marks a never-indexed field as sensitive, which h2 leaves as a
TODO. The encoder honors the sensitive flag of a pseudo-header too; h2
has no flag for them. h2's encoder can take a field without a name, which
reuses the name of the field before; this encoder takes a name with each
field. The decoder, like h2, does not require a size update after
`queue_size_update`; it refuses an update above the queued size.
"""

from std.collections import Optional

from gql_http2.hpack_table import (
    DynamicTable,
    ENTRY_OVERHEAD,
    STATIC_TABLE_LENGTH,
    StaticIndex,
    append_pair,
    name_hash,
    static_name,
    static_value,
)
from gql_http2.huffman import (
    HuffmanDecoder,
    huffman_encode,
)

comptime DEFAULT_TABLE_SIZE = 4096
"""The dynamic table size that HTTP/2 starts with (RFC 9113 section 6.5.2)."""
comptime MAX_INTEGER_BYTES = 5
"""The most bytes an integer can have, the prefix byte included, as in h2."""
comptime _SKIP_VALUE_INDEX: UInt64 = (
    (1 << 4)
    | (1 << 21)
    | (1 << 23)
    | (1 << 28)
    | (1 << 32)
    | (1 << 34)
    | (1 << 40)
    | (1 << 41)
    | (1 << 46)
    | (1 << 55)
)
"""One bit for each static name that h2 never adds to the dynamic table:
`:path`, `age`, `authorization`, `content-length`, `cookie`, `etag`,
`if-modified-since`, `if-none-match`, `location` and `set-cookie`."""


@fieldwise_init
struct HpackErrorKind(Equatable, ImplicitlyCopyable, Writable):
    """What was wrong with a header block, as h2's `DecoderError`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime INVALID_REPRESENTATION = HpackErrorKind(0)
    """The first byte of a field names no representation. Every byte names
    one, so the decoder does not raise it; h2 has the kind too."""
    comptime INVALID_INTEGER_PREFIX = HpackErrorKind(1)
    """An integer prefix was not 1 to 8 bits."""
    comptime INVALID_TABLE_INDEX = HpackErrorKind(2)
    """An index was 0, or past the end of the dynamic table."""
    comptime INVALID_HUFFMAN_CODE = HpackErrorKind(3)
    """A Huffman string had EOS, or bad padding (RFC 7541 section 5.2)."""
    comptime INVALID_MAX_DYNAMIC_SIZE = HpackErrorKind(4)
    """A size update came after a field, or was above the allowed size."""
    comptime INTEGER_OVERFLOW = HpackErrorKind(5)
    """An integer had more than `MAX_INTEGER_BYTES` bytes."""
    comptime NEED_MORE = HpackErrorKind(6)
    """The block ended inside a field, or a literal name was empty."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 6

    def text(self) -> StaticString:
        """Return the name of the kind.

        Returns:
            The name, such as `need more`, or `invalid` for a bad value.
        """
        comptime names: Array[StaticString, 7] = [
            "invalid representation",
            "invalid integer prefix",
            "invalid table index",
            "invalid Huffman code",
            "invalid max dynamic size",
            "integer overflow",
            "need more",
        ]
        if not self.is_valid():
            return "invalid"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the kind.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct HpackError(Copyable, Movable, Writable):
    """An error in a header block: a COMPRESSION_ERROR of the connection
    (RFC 9113 section 4.3)."""

    var kind: HpackErrorKind
    """What was wrong."""
    var message: String
    """A description for people."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind and the message, such as `need more: ...`.

        Args:
            writer: The destination.
        """
        writer.write(self.kind, ": ", self.message)


@fieldwise_init
struct HeaderField(ImplicitlyCopyable, Movable):
    """Where one field of a `HeaderList` is."""

    var start: Int
    """The offset of the name in `HeaderList.data`; the value follows."""
    var name_length: Int
    """The length of the name."""
    var value_length: Int
    """The length of the value."""
    var sensitive: Bool
    """Whether the field must never be indexed (RFC 7541 section 7.1.3)."""


struct HeaderList(Copyable, Movable):
    """The fields of one header block, in one byte buffer."""

    var data: List[UInt8]
    """The name and then the value of each field, in order."""
    var fields: List[HeaderField]
    """Where each field is in `data`."""
    var too_large: Bool
    """Set by the decoder when the fields passed the size limit; the list
    then holds only the fields before that."""
    var _size: Int
    """The list size: the sum of name, value and 32 for each field."""

    def __init__(out self):
        """Create an empty list."""
        self.data = List[UInt8]()
        self.fields = List[HeaderField]()
        self.too_large = False
        self._size = 0

    def clear(mut self):
        """Remove every field, and clear `too_large`; keep the memory."""
        self.data.clear()
        self.fields.clear()
        self.too_large = False
        self._size = 0

    @always_inline
    def add(
        mut self,
        name: Span[UInt8, _],
        value: Span[UInt8, _],
        sensitive: Bool = False,
    ):
        """Append a field.

        Args:
            name: The name, in lowercase.
            value: The value.
            sensitive: Whether the field must never be indexed.
        """
        self.fields.append(
            HeaderField(len(self.data), len(name), len(value), sensitive)
        )
        append_pair(self.data, name, value)
        self._size += len(name) + len(value) + ENTRY_OVERHEAD

    def add_text(
        mut self,
        name: StringSlice,
        value: StringSlice,
        sensitive: Bool = False,
    ):
        """Append a field given as text.

        Args:
            name: The name, in lowercase.
            value: The value.
            sensitive: Whether the field must never be indexed.
        """
        self.add(name.as_bytes(), value.as_bytes(), sensitive)

    @always_inline
    def count(self) -> Int:
        """Return the number of fields.

        Returns:
            The count.
        """
        return len(self.fields)

    @always_inline
    def name(self, index: Int) -> Span[UInt8, origin_of(self.data)]:
        """Return the name of a field.

        Args:
            index: The field, 0 to `count() - 1`.

        Returns:
            The bytes of the name.
        """
        var field = self.fields.unsafe_ptr()[unsafe_offset=index]
        return Span[UInt8, origin_of(self.data)](
            unsafe_ptr=self.data.unsafe_ptr().unsafe_offset(field.start),
            length=field.name_length,
        )

    @always_inline
    def value(self, index: Int) -> Span[UInt8, origin_of(self.data)]:
        """Return the value of a field.

        Args:
            index: The field, 0 to `count() - 1`.

        Returns:
            The bytes of the value.
        """
        var field = self.fields.unsafe_ptr()[unsafe_offset=index]
        var start = field.start + field.name_length
        return Span[UInt8, origin_of(self.data)](
            unsafe_ptr=self.data.unsafe_ptr().unsafe_offset(start),
            length=field.value_length,
        )

    def name_text(self, index: Int) -> StringSlice[origin_of(self.data)]:
        """Return the name of a field as text, unchecked.

        The bytes are not checked to be UTF-8; the caller checks them.

        Args:
            index: The field, 0 to `count() - 1`.

        Returns:
            The name.
        """
        return StringSlice(unsafe_from_utf8=self.name(index))

    def value_text(self, index: Int) -> StringSlice[origin_of(self.data)]:
        """Return the value of a field as text, unchecked.

        The bytes are not checked to be UTF-8; the caller checks them.

        Args:
            index: The field, 0 to `count() - 1`.

        Returns:
            The value.
        """
        return StringSlice(unsafe_from_utf8=self.value(index))

    def is_sensitive(self, index: Int) -> Bool:
        """Return whether a field must never be indexed.

        Args:
            index: The field, 0 to `count() - 1`.

        Returns:
            The flag.
        """
        return self.fields.unsafe_ptr()[unsafe_offset=index].sensitive

    @always_inline
    def list_size(self) -> Int:
        """Return the size of the list (RFC 9113 section 6.5.2).

        Returns:
            The sum of name, value and 32 bytes for each field.
        """
        return self._size


@always_inline
def encode_integer(
    value: Int, prefix_bits: Int, first_byte: UInt8, mut out: List[UInt8]
):
    """Append an integer with an N-bit prefix (RFC 7541 section 5.1).

    Args:
        value: The integer, 0 or more.
        prefix_bits: The bits of the first byte that hold the integer,
            1 to 8.
        first_byte: The flags in the other bits of the first byte.
        out: The buffer.
    """
    var low = (1 << prefix_bits) - 1
    if value < low:
        out.append(first_byte | UInt8(value))
        return
    out.append(first_byte | UInt8(low))
    var rest = value - low
    while rest >= 128:
        out.append(UInt8(0x80 | (rest & 0x7F)))
        rest >>= 7
    out.append(UInt8(rest))


@always_inline
def _read_integer(
    data: Pointer[UInt8, _], mut position: Int, end: Int, prefix_bits: Int
) raises HpackError -> Int:
    """Read an integer whose first byte is at `position`, which is before
    `end`."""
    var mask = (1 << prefix_bits) - 1
    var value = Int(data[unsafe_offset=position]) & mask
    position += 1
    if value < mask:
        return value
    var count = 1
    var shift = 0
    while position < end:
        var byte = data[unsafe_offset=position]
        position += 1
        count += 1
        value += Int(byte & 0x7F) << shift
        shift += 7
        if byte < 0x80:
            return value
        if count == MAX_INTEGER_BYTES:
            raise HpackError(
                HpackErrorKind.INTEGER_OVERFLOW,
                "an integer has more than 5 bytes",
            )
    raise HpackError(
        HpackErrorKind.NEED_MORE, "the block ends inside an integer"
    )


def decode_integer(
    data: Span[UInt8, _], mut position: Int, prefix_bits: Int
) raises HpackError -> Int:
    """Read an integer with an N-bit prefix (RFC 7541 section 5.1).

    Args:
        data: The bytes.
        position: The offset of the first byte; on return, the offset
            after the integer.
        prefix_bits: The bits of the first byte that hold the integer.

    Returns:
        The integer.

    Raises:
        HpackError: `INVALID_INTEGER_PREFIX` when `prefix_bits` is not 1
            to 8, `NEED_MORE` when the bytes end inside the integer, and
            `INTEGER_OVERFLOW` when it has more than 5 bytes.
    """
    if prefix_bits < 1 or prefix_bits > 8:
        raise HpackError(
            HpackErrorKind.INVALID_INTEGER_PREFIX,
            "an integer prefix must be 1 to 8 bits",
        )
    if position >= len(data):
        raise HpackError(
            HpackErrorKind.NEED_MORE, "the block ends before an integer"
        )
    return _read_integer(data.unsafe_ptr(), position, len(data), prefix_bits)


comptime _Bytes = Pointer[UInt8, ImmUntrackedOrigin]
"""A read-only pointer to bytes that outlive the call that uses them."""


@always_inline
def _untracked(pointer: Pointer[UInt8, _]) -> _Bytes:
    """Return a pointer without its origin."""
    return _Bytes(unsafe_from_address=Int(pointer))


@fieldwise_init
struct _Text(ImplicitlyCopyable):
    """Where a decoded string is: at a stable address, or in the scratch
    buffer, which can move until the field is complete."""

    var pointer: _Bytes
    """The bytes, when not in the scratch buffer."""
    var offset: Int
    """The offset in the scratch buffer, when in it."""
    var length: Int
    """The length."""
    var in_scratch: Bool
    """Whether the bytes are in the scratch buffer."""


@fieldwise_init
struct _Entry(ImplicitlyCopyable):
    """A table entry that a field refers to."""

    var name: _Bytes
    """The name."""
    var name_length: Int
    """The length of the name."""
    var value: _Bytes
    """The value."""
    var value_length: Int
    """The length of the value."""
    var dynamic: Bool
    """Whether the entry is in the dynamic table."""


@always_inline
def _append(
    mut out: HeaderList,
    name: _Bytes,
    name_length: Int,
    value: _Bytes,
    value_length: Int,
    sensitive: Bool,
    max_list_size: Int,
):
    """Append a decoded field, unless the list is past its limit."""
    var size = name_length + value_length + ENTRY_OVERHEAD
    if out.too_large or out._size + size > max_list_size:
        out.too_large = True
        return
    out.add(
        Span[UInt8, ImmUntrackedOrigin](unsafe_ptr=name, length=name_length),
        Span[UInt8, ImmUntrackedOrigin](unsafe_ptr=value, length=value_length),
        sensitive,
    )


struct Decoder(Movable):
    """The HPACK decoder of one connection: it holds the peer's dynamic
    table."""

    var table: DynamicTable
    """The dynamic table that the peer's encoder fills."""
    var _huffman: HuffmanDecoder
    """The Huffman tables."""
    var _scratch: List[UInt8]
    """The decoded strings of the current field."""
    var _max_size_update: Optional[Int]
    """The table size that our SETTINGS allowed last, to apply at the start
    of the next block."""
    var _last_max_update: Int
    """The largest size that a size update can set."""

    def __init__(out self, max_table_size: Int = DEFAULT_TABLE_SIZE):
        """Create a decoder with an empty table.

        Args:
            max_table_size: The table size; our SETTINGS_HEADER_TABLE_SIZE.
        """
        self.table = DynamicTable(max_table_size, False)
        self._huffman = HuffmanDecoder()
        self._scratch = List[UInt8](capacity=256)
        self._max_size_update = None
        self._last_max_update = max_table_size

    def queue_size_update(mut self, size: Int):
        """Allow a new table size, from the next block on.

        Call it when our SETTINGS_HEADER_TABLE_SIZE changes. Of two calls
        before a block, the larger size counts, as in h2.

        Args:
            size: The new largest table size.
        """
        if self._max_size_update:
            self._max_size_update = max(self._max_size_update.value(), size)
        else:
            self._max_size_update = size

    def decode(
        mut self,
        block: Span[UInt8, _],
        max_list_size: Int,
        mut out: HeaderList,
    ) raises HpackError:
        """Decode a whole header block, and append its fields to a list.

        When the list size passes `max_list_size`, the decoder decodes
        the rest of the block, but adds no more fields, and sets
        `out.too_large`.

        Args:
            block: The block: the fragments of HEADERS and CONTINUATION, or
                of PUSH_PROMISE, joined.
            max_list_size: The largest list size to add fields up to.
            out: The list; the fields go at its end.

        Raises:
            HpackError: When the block is not valid HPACK. The connection
                must then close with COMPRESSION_ERROR.
        """
        if self._max_size_update:
            self._last_max_update = self._max_size_update.value()
            self._max_size_update = None
        var data = block.unsafe_ptr()
        var end = len(block)
        var position = 0
        var can_resize = True
        while position < end:
            var byte = data[unsafe_offset=position]
            if byte >= 0x80:
                can_resize = False
                var index = _read_integer(data, position, end, 7)
                var found = self._lookup(index)
                _append(
                    out,
                    found.name,
                    found.name_length,
                    found.value,
                    found.value_length,
                    False,
                    max_list_size,
                )
            elif byte >= 0x40:
                can_resize = False
                self._literal(
                    data, position, end, 6, True, False, max_list_size, out
                )
            elif byte >= 0x20:
                if not can_resize:
                    raise HpackError(
                        HpackErrorKind.INVALID_MAX_DYNAMIC_SIZE,
                        "a table size update comes after a field",
                    )
                var size = _read_integer(data, position, end, 5)
                if size > self._last_max_update:
                    raise HpackError(
                        HpackErrorKind.INVALID_MAX_DYNAMIC_SIZE,
                        String(
                            "a table size update to ",
                            size,
                            " is above the allowed ",
                            self._last_max_update,
                        ),
                    )
                self.table.set_max_size(size)
            else:
                can_resize = False
                self._literal(
                    data,
                    position,
                    end,
                    4,
                    False,
                    byte >= 0x10,
                    max_list_size,
                    out,
                )

    @always_inline
    def _lookup(self, index: Int) raises HpackError -> _Entry:
        """Return the static or dynamic entry at an index."""
        if index == 0:
            raise HpackError(
                HpackErrorKind.INVALID_TABLE_INDEX, "a field refers to index 0"
            )
        if index <= STATIC_TABLE_LENGTH:
            var name = static_name(index)
            var value = static_value(index)
            return _Entry(
                _untracked(name.unsafe_ptr()),
                name.byte_length(),
                _untracked(value.unsafe_ptr()),
                value.byte_length(),
                False,
            )
        var dynamic = index - STATIC_TABLE_LENGTH - 1
        if dynamic >= self.table.count():
            raise HpackError(
                HpackErrorKind.INVALID_TABLE_INDEX,
                String(
                    "a field refers to index ",
                    index,
                    "; the dynamic table has ",
                    self.table.count(),
                    " entries",
                ),
            )
        var name = self.table.name(dynamic)
        var value = self.table.value(dynamic)
        return _Entry(
            _untracked(name.unsafe_ptr()),
            len(name),
            _untracked(value.unsafe_ptr()),
            len(value),
            True,
        )

    @always_inline
    def _read_string(
        mut self, data: Pointer[UInt8, _], mut position: Int, end: Int
    ) raises HpackError -> _Text:
        """Read a string literal (RFC 7541 section 5.2)."""
        if position >= end:
            raise HpackError(
                HpackErrorKind.NEED_MORE, "the block ends before a string"
            )
        var huffman = data[unsafe_offset=position] >= 0x80
        var length = _read_integer(data, position, end, 7)
        if length > end - position:
            raise HpackError(
                HpackErrorKind.NEED_MORE, "the block ends inside a string"
            )
        var start = data.unsafe_offset(position)
        position += length
        if huffman:
            var offset = len(self._scratch)
            if not self._huffman.decode(
                Span[UInt8, ImmUntrackedOrigin](
                    unsafe_ptr=_untracked(start), length=length
                ),
                self._scratch,
            ):
                raise HpackError(
                    HpackErrorKind.INVALID_HUFFMAN_CODE,
                    "a Huffman string is not valid",
                )
            return _Text(
                _untracked(start), offset, len(self._scratch) - offset, True
            )
        return _Text(_untracked(start), 0, length, False)

    @always_inline
    def _resolve(self, text: _Text) -> _Bytes:
        """Return the address of a string, now that the field is read."""
        if text.in_scratch:
            return _untracked(
                self._scratch.unsafe_ptr().unsafe_offset(text.offset)
            )
        return text.pointer

    @always_inline
    def _literal(
        mut self,
        data: Pointer[UInt8, _],
        mut position: Int,
        end: Int,
        prefix_bits: Int,
        indexing: Bool,
        sensitive: Bool,
        max_list_size: Int,
        mut out: HeaderList,
    ) raises HpackError:
        """Decode a literal field (RFC 7541 section 6.2)."""
        var index = _read_integer(data, position, end, prefix_bits)
        self._scratch.clear()
        var name: _Text
        if index == 0:
            name = self._read_string(data, position, end)
            if name.length == 0:
                raise HpackError(
                    HpackErrorKind.NEED_MORE, "a literal field name is empty"
                )
        else:
            var found = self._lookup(index)
            name = _Text(found.name, 0, found.name_length, False)
            if indexing and found.dynamic:
                # The insertion can move the table's bytes: copy the name.
                self._scratch.extend(
                    Span[UInt8, ImmUntrackedOrigin](
                        unsafe_ptr=found.name, length=found.name_length
                    )
                )
                name = _Text(found.name, 0, found.name_length, True)
        var value = self._read_string(data, position, end)
        var name_bytes = self._resolve(name)
        var value_bytes = self._resolve(value)
        _append(
            out,
            name_bytes,
            name.length,
            value_bytes,
            value.length,
            sensitive,
            max_list_size,
        )
        if indexing:
            _ = self.table.insert(
                Span[UInt8, ImmUntrackedOrigin](
                    unsafe_ptr=name_bytes, length=name.length
                ),
                Span[UInt8, ImmUntrackedOrigin](
                    unsafe_ptr=value_bytes, length=value.length
                ),
                0,
            )


@always_inline
def _encode_string(value: Span[UInt8, _], mut out: List[UInt8]):
    """Append a string literal: Huffman coded, or one 0 byte when empty.

    As h2 does, this writes a one-byte length, then the code, and moves
    the code right when its length needs more bytes."""
    if len(value) == 0:
        out.append(0)
        return
    var at = len(out)
    out.append(0)
    huffman_encode(value, out)
    var length = len(out) - at - 1
    if length < 127:
        out[at] = UInt8(0x80 | length)
        return
    var head = List[UInt8]()
    encode_integer(length, 7, 0x80, head)
    var extra = len(head) - 1
    out.resize(len(out) + extra, 0)
    var data = out.unsafe_ptr()
    var index = len(out) - 1
    while index >= at + len(head):
        data[unsafe_offset=index] = data[unsafe_offset=index - extra]
        index -= 1
    index = 0
    while index < len(head):
        data[unsafe_offset=at + index] = head[index]
        index += 1


@always_inline
def _encode_not_indexed(
    index: Int, value: Span[UInt8, _], sensitive: Bool, mut out: List[UInt8]
):
    """Append a literal with an indexed name, not added to the table."""
    encode_integer(index, 4, UInt8(Int(sensitive) << 4), out)
    _encode_string(value, out)


struct Encoder(Movable):
    """The HPACK encoder of one connection: it holds our dynamic table."""

    var table: DynamicTable
    """The dynamic table that this encoder fills, and the peer mirrors."""
    var _static: StaticIndex
    """The index of the static table names."""
    var _max_allowed_size: Int
    """The largest table this encoder uses, whatever the peer allows."""
    var _update_first: Optional[Int]
    """The size update to send first at the next block, if any."""
    var _update_second: Optional[Int]
    """The size update to send after it, if any: a growth after a cut."""

    def __init__(out self, max_table_size: Int = DEFAULT_TABLE_SIZE):
        """Create an encoder with an empty table.

        Args:
            max_table_size: The table size; the peer's
                SETTINGS_HEADER_TABLE_SIZE. The encoder uses at most 4096
                bytes, as h2 does.
        """
        self._max_allowed_size = DEFAULT_TABLE_SIZE
        self.table = DynamicTable(min(max_table_size, DEFAULT_TABLE_SIZE), True)
        self._static = StaticIndex()
        self._update_first = None
        self._update_second = None

    def set_max_allowed_size(mut self, size: Int):
        """Set the largest table this encoder uses (4096 at first).

        Args:
            size: The largest table size.
        """
        self._max_allowed_size = size
        if self.table.max_size() > size:
            self.update_max_size(size)

    def update_max_size(mut self, size: Int):
        """Take a new SETTINGS_HEADER_TABLE_SIZE of the peer.

        The next block starts with the size update, or with two: the
        smallest size since the last block, then the last size (RFC 7541
        section 4.2).

        Args:
            size: The new table size.
        """
        var value = min(size, self._max_allowed_size)
        if self._update_second:
            var smallest = self._update_first.value()
            if value < smallest:
                self._update_first = value
                self._update_second = None
            else:
                self._update_second = value
        elif self._update_first:
            var old = self._update_first.value()
            if value > old and old <= self.table.max_size():
                self._update_second = value
            else:
                self._update_first = value
        elif value != self.table.max_size():
            self._update_first = value

    def begin_block(mut self, mut out: List[UInt8]):
        """Start a header block: append the pending size updates.

        Args:
            out: The buffer of the block.
        """
        if self._update_first:
            var first = self._update_first.value()
            self.table.set_max_size(first)
            encode_integer(first, 5, 0x20, out)
            if self._update_second:
                var second = self._update_second.value()
                self.table.set_max_size(second)
                encode_integer(second, 5, 0x20, out)
            self._update_first = None
            self._update_second = None

    def encode_field(
        mut self,
        name: Span[UInt8, _],
        value: Span[UInt8, _],
        sensitive: Bool,
        mut out: List[UInt8],
    ):
        """Append one field to a block, after `begin_block`.

        Args:
            name: The name, in lowercase.
            value: The value.
            sensitive: Whether the field must never be indexed, such as a
                password.
            out: The buffer of the block.
        """
        var hash = name_hash(name)
        var first = self._static.find(name, hash)
        var full = self._static.find_value(first, value)
        if (_SKIP_VALUE_INDEX >> UInt64(first)) & 1 == 1:
            if full != 0:
                encode_integer(full, 7, 0x80, out)
            else:
                _encode_not_indexed(first, value, sensitive, out)
            return
        if full != 0:
            encode_integer(full, 7, 0x80, out)
            return
        var size = len(name) + len(value) + ENTRY_OVERHEAD
        if size * 4 > self.table.max_size() * 3:
            self._encode_unindexed(first, name, value, sensitive, out)
            return
        var found = self.table.find(name, value, hash)
        if found.value_index >= 0:
            encode_integer(
                found.value_index + STATIC_TABLE_LENGTH + 1, 7, 0x80, out
            )
            return
        if found.name_index >= 0:
            var dynamic = found.name_index + STATIC_TABLE_LENGTH + 1
            if sensitive:
                _encode_not_indexed(dynamic, value, True, out)
                return
            if first != 0:
                dynamic = first
            encode_integer(dynamic, 6, 0x40, out)
            _encode_string(value, out)
            _ = self.table.insert(name, value, hash)
            return
        if sensitive:
            self._encode_unindexed(first, name, value, True, out)
            return
        if first != 0:
            encode_integer(first, 6, 0x40, out)
        else:
            out.append(0x40)
            _encode_string(name, out)
        _encode_string(value, out)
        _ = self.table.insert(name, value, hash)

    def _encode_unindexed(
        self,
        first: Int,
        name: Span[UInt8, _],
        value: Span[UInt8, _],
        sensitive: Bool,
        mut out: List[UInt8],
    ):
        """Append a field that is not added to the table."""
        if first != 0:
            _encode_not_indexed(first, value, sensitive, out)
            return
        out.append(UInt8(Int(sensitive) << 4))
        _encode_string(name, out)
        _encode_string(value, out)

    def encode(mut self, fields: HeaderList, mut out: List[UInt8]):
        """Append a whole header block: the size updates, then each field.

        Args:
            fields: The fields, names in lowercase.
            out: The buffer; the block goes at its end.
        """
        self.begin_block(out)
        var index = 0
        while index < fields.count():
            self.encode_field(
                fields.name(index),
                fields.value(index),
                fields.is_sensitive(index),
                out,
            )
            index += 1
