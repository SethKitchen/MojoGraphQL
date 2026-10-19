# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The wire forms of QPACK: the field section prefix, the field line
representations, and the instructions of the encoder and decoder streams
(RFC 9204 sections 4.3, 4.4 and 4.5).

`HeaderPrefix` encodes the Required Insert Count modulo twice the number of
entries that the table can hold, and the base as a signed delta from it
(section 4.5.1). The `write_*` functions append one representation or one
instruction. The kinds tell the representation from its first byte.

This module ports `h3/src/qpack/block.rs` and `h3/src/qpack/stream.rs` of
hyperium/h3 h3-v0.0.8 (22c1aa3), MIT.

Differences from upstream: upstream has a type for each representation,
with `encode` and `decode`. Here a writer appends each one, and the coder in
`gql_http3.qpack` reads them in place. Upstream's `Unknown` kinds are gone:
the patterns cover every first byte. `HeaderPrefix.get` follows the
algorithm of RFC 9204 section 4.5.1.1, and refuses an encoded insert count
that is larger than twice the number of entries, a count without a table,
and a decoded count of 0; upstream accepts them.
"""

from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.qpack_prefix import (
    decode_prefix_int,
    encode_prefix_int,
    encode_prefix_string,
)


@fieldwise_init
struct FieldLineKind(Equatable, ImplicitlyCopyable, Writable):
    """The representation of a field line (RFC 9204 section 4.5)."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime INDEXED = FieldLineKind(0)
    """`1T` and an index: a static or a dynamic entry."""
    comptime INDEXED_POST_BASE = FieldLineKind(1)
    """`0001` and a post-base index."""
    comptime LITERAL_NAME_REF = FieldLineKind(2)
    """`01NT`, a name index and a value."""
    comptime LITERAL_POST_BASE_NAME_REF = FieldLineKind(3)
    """`0000N`, a post-base name index and a value."""
    comptime LITERAL = FieldLineKind(4)
    """`001NH`, a name and a value."""

    @staticmethod
    @always_inline
    def of(first: UInt8) -> FieldLineKind:
        """Return the kind of the representation that starts with a byte.

        Args:
            first: The first byte.

        Returns:
            The kind.
        """
        if first & 0x80 != 0:
            return FieldLineKind.INDEXED
        if first & 0xC0 == 0x40:
            return FieldLineKind.LITERAL_NAME_REF
        if first & 0xE0 == 0x20:
            return FieldLineKind.LITERAL
        if first & 0xF0 == 0x10:
            return FieldLineKind.INDEXED_POST_BASE
        return FieldLineKind.LITERAL_POST_BASE_NAME_REF

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 4

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("field line kind ", self.value)


@fieldwise_init
struct EncoderInstructionKind(Equatable, ImplicitlyCopyable, Writable):
    """An instruction of the encoder stream (RFC 9204 section 4.3)."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime SET_CAPACITY = EncoderInstructionKind(0)
    """`001` and a capacity."""
    comptime INSERT_NAME_REF = EncoderInstructionKind(1)
    """`1T`, a name index and a value."""
    comptime INSERT_LITERAL = EncoderInstructionKind(2)
    """`01H`, a name and a value."""
    comptime DUPLICATE = EncoderInstructionKind(3)
    """`000` and a relative index."""

    @staticmethod
    def of(first: UInt8) -> EncoderInstructionKind:
        """Return the kind of the instruction that starts with a byte.

        Args:
            first: The first byte.

        Returns:
            The kind.
        """
        if first & 0x80 != 0:
            return EncoderInstructionKind.INSERT_NAME_REF
        if first & 0x40 != 0:
            return EncoderInstructionKind.INSERT_LITERAL
        if first & 0x20 != 0:
            return EncoderInstructionKind.SET_CAPACITY
        return EncoderInstructionKind.DUPLICATE

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("encoder instruction ", self.value)


@fieldwise_init
struct DecoderInstructionKind(Equatable, ImplicitlyCopyable, Writable):
    """An instruction of the decoder stream (RFC 9204 section 4.4)."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime SECTION_ACK = DecoderInstructionKind(0)
    """`1` and a stream id."""
    comptime STREAM_CANCEL = DecoderInstructionKind(1)
    """`01` and a stream id."""
    comptime INSERT_COUNT_INCREMENT = DecoderInstructionKind(2)
    """`00` and an increment."""

    @staticmethod
    def of(first: UInt8) -> DecoderInstructionKind:
        """Return the kind of the instruction that starts with a byte.

        Args:
            first: The first byte.

        Returns:
            The kind.
        """
        if first & 0x80 != 0:
            return DecoderInstructionKind.SECTION_ACK
        if first & 0x40 != 0:
            return DecoderInstructionKind.STREAM_CANCEL
        return DecoderInstructionKind.INSERT_COUNT_INCREMENT

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("decoder instruction ", self.value)


def decompression_failed(message: String) -> H3Error:
    """Return a `QPACK_DECOMPRESSION_FAILED` error.

    Args:
        message: The description.

    Returns:
        The error.
    """
    return H3Error(H3ErrorCode.QPACK_DECOMPRESSION_FAILED, message)


comptime _INDEX_LIMIT = UInt64(1) << 62
"""Integers at or above this do not fit an index, a length or a count."""


@always_inline
def to_index(value: UInt64) raises H3Error -> Int:
    """Return a decoded integer as an `Int` index.

    Args:
        value: The integer.

    Returns:
        The integer.

    Raises:
        H3Error: `QPACK_DECOMPRESSION_FAILED` for 2^62 or more.
    """
    if value >= _INDEX_LIMIT:
        raise decompression_failed("integer too large")
    return Int(value)


@fieldwise_init
struct HeaderPrefix(Equatable, ImplicitlyCopyable, Writable):
    """The prefix of a field section (RFC 9204 section 4.5.1)."""

    var encoded_insert_count: Int
    """The Required Insert Count, encoded; 0 for a section without
    dynamic references."""
    var sign_negative: Bool
    """True when the base is below the Required Insert Count."""
    var delta_base: Int
    """The distance of the base from the Required Insert Count."""

    @staticmethod
    def new(
        required: Int, base: Int, total_inserted: Int, max_table_size: Int
    ) -> HeaderPrefix:
        """Return the prefix of a section.

        Args:
            required: The Required Insert Count: one more than the largest
                absolute index that the section references, or 0.
            base: The base of the section.
            total_inserted: The insert count of the table; unused, as in
                upstream.
            max_table_size: The maximum table capacity of the decoder.

        Returns:
            The prefix.
        """
        _ = total_inserted
        if max_table_size == 0 or required == 0:
            return HeaderPrefix(0, False, 0)
        var max_entries = max_table_size // 32
        if required > base:
            return HeaderPrefix(
                required % (2 * max_entries) + 1, True, required - base - 1
            )
        return HeaderPrefix(
            required % (2 * max_entries) + 1, False, base - required
        )

    def get(
        self, total_inserted: Int, max_table_size: Int
    ) raises H3Error -> Tuple[Int, Int]:
        """Return the Required Insert Count and the base of the section.

        Args:
            total_inserted: The insert count of the decoder's table.
            max_table_size: The maximum table capacity of the decoder.

        Returns:
            The Required Insert Count and the base.

        Raises:
            H3Error: `QPACK_DECOMPRESSION_FAILED` for an encoded count that
                no table could produce, or a negative base.
        """
        if self.encoded_insert_count == 0:
            return (0, 0)
        var max_entries = max_table_size // 32
        var full_range = 2 * max_entries
        if self.encoded_insert_count > full_range:
            raise decompression_failed("invalid encoded insert count")
        var max_value = total_inserted + max_entries
        var max_wrapped = (max_value // full_range) * full_range
        var required = max_wrapped + self.encoded_insert_count - 1
        if required > max_value:
            if required <= full_range:
                raise decompression_failed("invalid encoded insert count")
            required -= full_range
        if required == 0:
            raise decompression_failed("invalid encoded insert count")
        if not self.sign_negative:
            return (required, required + self.delta_base)
        if self.delta_base + 1 > required:
            raise decompression_failed(
                String("invalid base ", required - self.delta_base - 1)
            )
        return (required, required - self.delta_base - 1)

    def encode(self, mut out: List[UInt8]):
        """Append the prefix.

        Args:
            out: The destination.
        """
        encode_prefix_int(8, 0, UInt64(self.encoded_insert_count), out)
        var sign = UInt8(1) if self.sign_negative else UInt8(0)
        encode_prefix_int(7, sign, UInt64(self.delta_base), out)

    def write_to(self, mut writer: Some[Writer]):
        """Write the three fields.

        Args:
            writer: The destination.
        """
        writer.write(
            "prefix ",
            self.encoded_insert_count,
            " ",
            self.sign_negative,
            " ",
            self.delta_base,
        )


def decode_header_prefix(
    data: Span[UInt8, _], mut prefix: HeaderPrefix
) raises H3Error -> Int:
    """Read the prefix at the start of a field section.

    Args:
        data: The field section.
        prefix: Set to the prefix.

    Returns:
        The offset of the first field line.

    Raises:
        H3Error: `QPACK_DECOMPRESSION_FAILED` for a short section or an
            integer that is too large.
    """
    var count = decode_prefix_int(8, data, 0)
    if not count.complete():
        raise decompression_failed("truncated field section prefix")
    var delta = decode_prefix_int(7, data, count.end)
    if not delta.complete():
        raise decompression_failed("truncated field section prefix")
    prefix = HeaderPrefix(
        to_index(count.value), delta.flags == 1, to_index(delta.value)
    )
    return delta.end


def write_indexed_static(index: Int, mut out: List[UInt8]):
    """Append an indexed field line of a static entry.

    Args:
        index: The static index.
        out: The destination.
    """
    encode_prefix_int(6, 0b11, UInt64(index), out)


def write_indexed_dynamic(index: Int, mut out: List[UInt8]):
    """Append an indexed field line of a dynamic entry before the base.

    Args:
        index: The relative index.
        out: The destination.
    """
    encode_prefix_int(6, 0b10, UInt64(index), out)


def write_indexed_post_base(index: Int, mut out: List[UInt8]):
    """Append an indexed field line with a post-base index.

    Args:
        index: The post-base index.
        out: The destination.
    """
    encode_prefix_int(4, 0b0001, UInt64(index), out)


def write_literal_static_name(
    index: Int, value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append a literal field line with the name of a static entry.

    Args:
        index: The static index of the name.
        value: The value.
        out: The destination.
    """
    encode_prefix_int(4, 0b0101, UInt64(index), out)
    encode_prefix_string(8, 0, value, out)


def write_literal_dynamic_name(
    index: Int, value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append a literal field line with the name of a dynamic entry.

    Args:
        index: The relative index of the name.
        value: The value.
        out: The destination.
    """
    encode_prefix_int(4, 0b0100, UInt64(index), out)
    encode_prefix_string(8, 0, value, out)


def write_literal_post_base_name(
    index: Int, value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append a literal field line with a post-base name index.

    Args:
        index: The post-base index of the name.
        value: The value.
        out: The destination.
    """
    encode_prefix_int(3, 0b0000, UInt64(index), out)
    encode_prefix_string(8, 0, value, out)


def write_literal(
    name: Span[UInt8, _], value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append a literal field line with a literal name.

    Args:
        name: The name.
        value: The value.
        out: The destination.
    """
    encode_prefix_string(4, 0b0010, name, out)
    encode_prefix_string(8, 0, value, out)


def write_insert_static_name(
    index: Int, value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append an Insert With Name Reference of a static name.

    Args:
        index: The static index of the name.
        value: The value.
        out: The encoder stream.
    """
    encode_prefix_int(6, 0b11, UInt64(index), out)
    encode_prefix_string(8, 0, value, out)


def write_insert_dynamic_name(
    index: Int, value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append an Insert With Name Reference of a dynamic name.

    Args:
        index: The index of the name relative to the insert count.
        value: The value.
        out: The encoder stream.
    """
    encode_prefix_int(6, 0b10, UInt64(index), out)
    encode_prefix_string(8, 0, value, out)


def write_insert_literal(
    name: Span[UInt8, _], value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append an Insert With Literal Name.

    Args:
        name: The name.
        value: The value.
        out: The encoder stream.
    """
    encode_prefix_string(6, 0b01, name, out)
    encode_prefix_string(8, 0, value, out)


def write_duplicate(index: Int, mut out: List[UInt8]):
    """Append a Duplicate instruction.

    Args:
        index: The index of the entry relative to the insert count.
        out: The encoder stream.
    """
    encode_prefix_int(5, 0, UInt64(index), out)


def write_set_capacity(capacity: Int, mut out: List[UInt8]):
    """Append a Set Dynamic Table Capacity instruction.

    Args:
        capacity: The new capacity.
        out: The encoder stream.
    """
    encode_prefix_int(5, 0b001, UInt64(capacity), out)


def write_section_ack(stream_id: UInt64, mut out: List[UInt8]):
    """Append a Section Acknowledgment.

    Args:
        stream_id: The stream of the field section.
        out: The decoder stream.
    """
    encode_prefix_int(7, 0b1, stream_id, out)


def write_stream_cancel(stream_id: UInt64, mut out: List[UInt8]):
    """Append a Stream Cancellation.

    Args:
        stream_id: The stream that was reset or abandoned.
        out: The decoder stream.
    """
    encode_prefix_int(6, 0b01, stream_id, out)


def write_insert_count_increment(increment: Int, mut out: List[UInt8]):
    """Append an Insert Count Increment.

    Args:
        increment: The number of new entries that the decoder received.
        out: The decoder stream.
    """
    encode_prefix_int(6, 0b00, UInt64(increment), out)
