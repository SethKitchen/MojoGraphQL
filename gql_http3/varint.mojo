# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""QUIC variable-length integers (RFC 9000 section 16).

The two high bits of the first byte give the length: 1, 2, 4 or 8 bytes.
The other bits hold the value in network byte order. So a value is less
than 2^62. HTTP/3 writes frame types, frame lengths, stream types and
settings in this form.

`decode_varint` reads one integer at an offset of a span. When the span
ends before the integer does, it returns an `INCOMPLETE` result, and the
caller waits for more bytes. `encode_varint` appends the shortest form.

This module ports `h3/src/proto/varint.rs` of hyperium/h3 h3-v0.0.8
(22c1aa3), MIT.

Differences from upstream: upstream reads from a `Buf` cursor and returns
`UnexpectedEnd`. Here `decode_varint` reads at an offset, and returns its
status and the offset after the integer, so a stream reader can feed bytes
as they arrive. `encode_varint` takes a value that `is_varint` accepts;
upstream panics on a larger value.
"""

comptime VARINT_MAX: UInt64 = (UInt64(1) << 62) - 1
"""The largest value that a variable-length integer holds."""
comptime VARINT_MAX_SIZE = 8
"""The largest encoded size, in bytes."""


@fieldwise_init
struct Progress(Equatable, ImplicitlyCopyable, Writable):
    """Whether a read found all the bytes that it needs."""

    var value: UInt8
    """The status's index; see `is_valid`."""

    comptime COMPLETE = Progress(0)
    """The item is complete; its fields are set."""
    comptime INCOMPLETE = Progress(1)
    """The bytes end before the item does; read again with more bytes."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the statuses.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the status.

        Args:
            writer: The destination.
        """
        if self.value == 0:
            writer.write("complete")
        elif self.value == 1:
            writer.write("incomplete")
        else:
            writer.write("invalid")


@fieldwise_init
struct VarInt(ImplicitlyCopyable, Writable):
    """The result of `decode_varint`: a status, a value and an offset."""

    var status: Progress
    """`COMPLETE`, or `INCOMPLETE` when the bytes end too soon."""
    var value: UInt64
    """The value; 0 when the status is `INCOMPLETE`."""
    var end: Int
    """The offset after the integer; the start offset when `INCOMPLETE`."""

    def complete(self) -> Bool:
        """Return True when the integer was read.

        Returns:
            Whether the status is `COMPLETE`.
        """
        return self.status == Progress.COMPLETE

    def write_to(self, mut writer: Some[Writer]):
        """Write the status, the value and the end offset.

        Args:
            writer: The destination.
        """
        writer.write(self.status, " ", self.value, " at ", self.end)


@always_inline
def is_varint(value: UInt64) -> Bool:
    """Return True for a value that a variable-length integer can hold.

    Args:
        value: The value.

    Returns:
        Whether the value is at most `VARINT_MAX`.
    """
    return value <= VARINT_MAX


@always_inline
def varint_size(value: UInt64) -> Int:
    """Return the number of bytes that `encode_varint` writes for a value.

    Args:
        value: A value that `is_varint` accepts.

    Returns:
        1, 2, 4 or 8.
    """
    if value < 64:
        return 1
    if value < 16384:
        return 2
    if value < 1073741824:
        return 4
    return 8


@always_inline
def encoded_size(first: UInt8) -> Int:
    """Return the size of an encoded integer from its first byte.

    Args:
        first: The first byte.

    Returns:
        1, 2, 4 or 8.
    """
    return 1 << Int(first >> 6)


def encode_varint(value: UInt64, mut out: List[UInt8]):
    """Append the shortest encoding of a value.

    Args:
        value: A value that `is_varint` accepts. The bits above bit 61 of
            a larger value are lost.
        out: The destination.
    """
    var size = varint_size(value)
    var tag = UInt64(0)
    if size == 2:
        tag = UInt64(1) << 14
    elif size == 4:
        tag = UInt64(2) << 30
    elif size == 8:
        tag = UInt64(3) << 62
    var word = (value & VARINT_MAX) | tag
    var shift = (size - 1) * 8
    while shift >= 0:
        out.append(UInt8((word >> UInt64(shift)) & 0xFF))
        shift -= 8


@always_inline
def decode_varint(data: Span[UInt8, _], start: Int) -> VarInt:
    """Read one variable-length integer.

    Args:
        data: The bytes.
        start: The offset of the first byte of the integer.

    Returns:
        The value and the offset after it, or an `INCOMPLETE` result when
        the bytes end before the integer does.
    """
    if start >= len(data):
        return VarInt(Progress.INCOMPLETE, 0, start)
    var p = data.unsafe_ptr()
    var first = p[unsafe_offset=start]
    var size = encoded_size(first)
    if start + size > len(data):
        return VarInt(Progress.INCOMPLETE, 0, start)
    var value = UInt64(first & 0x3F)
    var index = 1
    while index < size:
        value = (value << 8) | UInt64(p[unsafe_offset=start + index])
        index += 1
    return VarInt(Progress.COMPLETE, value, start + size)
