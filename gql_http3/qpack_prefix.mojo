# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The prefixed integers and the string literals of QPACK (RFC 9204
section 4.1, after RFC 7541 sections 5.1 and 5.2).

A prefixed integer starts in the low `size` bits of a byte; the high bits
of that byte are flags. A value that does not fit continues in bytes of 7
bits each, low bits first. A string literal is a prefixed integer of
`size - 1` bits, its length, after an `H` flag bit, then the bytes, Huffman
coded when `H` is set.

A decoder returns a `PrefixInt` with an `INCOMPLETE` status when the bytes
end too soon. The instruction streams wait for more bytes then; a field
section treats it as an error.

This module ports `h3/src/qpack/prefix_int.rs` and
`h3/src/qpack/prefix_string/mod.rs` of hyperium/h3 h3-v0.0.8 (22c1aa3),
MIT.

Differences from upstream: upstream always Huffman codes a string. Here
`encode_prefix_string` Huffman codes a string only when that is shorter, so
the empty string is `0x00` and not `0x80`. A decoder reads at an offset and
returns its status, in place of a `Buf` cursor and an `UnexpectedEnd`
error. A string decodes into the end of a byte list that the caller gives.
"""

from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.huffman import (
    huffman_decode,
    huffman_encode,
    huffman_encoded_length,
)
from gql_http3.varint import Progress

comptime _MAX_POWER = 9 * 7
"""The shift after which a continuation byte overflows 64 bits."""


@fieldwise_init
struct PrefixInt(ImplicitlyCopyable, Writable):
    """The result of a decoder: a status, the flags, a value, an offset."""

    var status: Progress
    """`COMPLETE`, or `INCOMPLETE` when the bytes end too soon."""
    var flags: UInt8
    """The bits of the first byte above the prefix."""
    var value: UInt64
    """The integer; for a string, the number of bytes it appended."""
    var end: Int
    """The offset after the item; the start offset when `INCOMPLETE`."""

    def complete(self) -> Bool:
        """Return True when the item was read.

        Returns:
            Whether the status is `COMPLETE`.
        """
        return self.status == Progress.COMPLETE

    def write_to(self, mut writer: Some[Writer]):
        """Write the status, the flags, the value and the end offset.

        Args:
            writer: The destination.
        """
        writer.write(
            self.status,
            " flags ",
            self.flags,
            " ",
            self.value,
            " at ",
            self.end,
        )


def _incomplete(start: Int) -> PrefixInt:
    """Return the result of bytes that end before the item does."""
    return PrefixInt(Progress.INCOMPLETE, 0, 0, start)


def _overflow() -> H3Error:
    """Return the error of an integer that does not fit 64 bits."""
    return H3Error(
        H3ErrorCode.QPACK_DECOMPRESSION_FAILED, "prefixed integer overflow"
    )


def encode_prefix_int(
    size: Int, flags: UInt8, value: UInt64, mut out: List[UInt8]
):
    """Append a prefixed integer.

    Args:
        size: The prefix width in bits, from 1 to 8.
        flags: The bits to put above the prefix.
        value: The integer.
        out: The destination.
    """
    var mask = UInt64((1 << size) - 1)
    var high = UInt8((Int(flags) << size) & 0xFF)
    if value < mask:
        out.append(high | UInt8(value))
        return
    out.append(high | UInt8(mask))
    var remaining = value - mask
    while remaining >= 128:
        out.append(UInt8(remaining & 127) | 128)
        remaining >>= 7
    out.append(UInt8(remaining))


@always_inline
def decode_prefix_int(
    size: Int, data: Span[UInt8, _], start: Int
) raises H3Error -> PrefixInt:
    """Read a prefixed integer.

    Args:
        size: The prefix width in bits, from 1 to 8.
        data: The bytes.
        start: The offset of the first byte.

    Returns:
        The flags, the value and the offset after the integer, or an
        `INCOMPLETE` result.

    Raises:
        H3Error: `QPACK_DECOMPRESSION_FAILED` when the value needs more
            than 64 bits.
    """
    var n = len(data)
    if start >= n:
        return _incomplete(start)
    var p = data.unsafe_ptr()
    var first = Int(p[unsafe_offset=start])
    var flags = UInt8(first >> size)
    var mask = 0xFF >> (8 - size)
    var low = first & mask
    if low < mask:
        return PrefixInt(Progress.COMPLETE, flags, UInt64(low), start + 1)
    var value = UInt64(mask)
    var power = 0
    var at = start + 1
    while True:
        if at >= n:
            return _incomplete(start)
        var byte = UInt64(p[unsafe_offset=at])
        at += 1
        value += (byte & 127) << UInt64(power)
        power += 7
        if byte & 128 == 0:
            return PrefixInt(Progress.COMPLETE, flags, value, at)
        if power >= _MAX_POWER:
            raise _overflow()


def encode_prefix_string(
    size: Int, flags: UInt8, value: Span[UInt8, _], mut out: List[UInt8]
):
    """Append a string literal, Huffman coded when that is shorter.

    Args:
        size: The width of the `H` bit and the length prefix, from 2 to 8.
        flags: The bits to put above the `H` bit.
        value: The bytes of the string.
        out: The destination.
    """
    var coded = huffman_encoded_length(value)
    if coded < len(value):
        encode_prefix_int(size - 1, (flags << 1) | 1, UInt64(coded), out)
        huffman_encode(value, out)
        return
    encode_prefix_int(size - 1, flags << 1, UInt64(len(value)), out)
    out.extend(value)


@always_inline
def decode_prefix_string(
    size: Int, data: Span[UInt8, _], start: Int, mut out: List[UInt8]
) raises H3Error -> PrefixInt:
    """Read a string literal, and append its bytes.

    Args:
        size: The width of the `H` bit and the length prefix, from 2 to 8.
        data: The bytes.
        start: The offset of the first byte.
        out: The destination of the decoded bytes. Nothing is appended for
            an `INCOMPLETE` result.

    Returns:
        The flags above the `H` bit, the number of bytes appended, and the
        offset after the string, or an `INCOMPLETE` result.

    Raises:
        H3Error: `QPACK_DECOMPRESSION_FAILED` for a length that overflows,
            or an invalid Huffman encoding.
    """
    var head = decode_prefix_int(size - 1, data, start)
    if not head.complete():
        return head
    if head.value > UInt64(len(data) - head.end):
        return _incomplete(start)
    var length = Int(head.value)
    var body = data[head.end : head.end + length]
    var before = len(out)
    if head.flags & 1 == 0:
        out.extend(body)
    else:
        huffman_decode(body, out)
    return PrefixInt(
        Progress.COMPLETE,
        head.flags >> 1,
        UInt64(len(out) - before),
        head.end + length,
    )
