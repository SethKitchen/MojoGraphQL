# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""QUIC variable-length integers (RFC 9000 section 16), and the fixed-size
big-endian integers of the wire format.

The two high bits of the first byte of a variable-length integer give its
length: 1, 2, 4 or 8 bytes. The other bits hold the value in network byte
order, so a value is less than 2^62.

A read function takes a span and a cursor `pos`. It reads at `pos` and
moves `pos` past the integer. When the span ends first, it raises a
`QuicError` with `FRAME_ENCODING_ERROR` and the reason `unexpected end`,
and it does not move `pos`. A write function appends to a list. It reserves
the space once and writes through a pointer.

This module ports quinn-proto 0.11.19 (8192ed3) quinn-proto/src/varint.rs
and quinn-proto/src/coding.rs (MIT OR Apache-2.0, used under MIT).

Differences from upstream: upstream reads from a `Buf` and returns
`UnexpectedEnd`. Here a read takes a span and a cursor, and raises
`QuicError`, which the frame and packet decoders pass up. `write_varint_2`
and `patch_varint_2` write a two-byte form for a length that is known only
after the payload is written; upstream writes such a length with a fixed
`put_u16`. `write_varint` takes a value of at most `VARINT_MAX`; upstream
panics on a larger value, and here the bits above bit 61 are lost.
"""

from std.bit import byte_swap
from std.memory import unsafe_memcpy

from gql_quic.error import QuicError, TransportErrorCode

comptime VARINT_MAX: UInt64 = (UInt64(1) << 62) - 1
"""The largest value that a variable-length integer holds."""


@always_inline
def unexpected_end() -> QuicError:
    """Return the error for bytes that end too soon.

    Returns:
        A `FRAME_ENCODING_ERROR` with the reason `unexpected end`.
    """
    return QuicError(TransportErrorCode.FRAME_ENCODING_ERROR, "unexpected end")


@always_inline
def varint_size(value: UInt64) -> Int:
    """Return the number of bytes that `write_varint` writes for a value.

    Args:
        value: A value of at most `VARINT_MAX`.

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
def reserve_tail(mut out: List[UInt8], extra: Int) -> Int:
    """Make room for `extra` more bytes, and set the new length.

    The new bytes are not set: the caller must write all of them through
    `out.unsafe_ptr()`.

    Args:
        out: The list.
        extra: The number of bytes to add.

    Returns:
        The offset of the first new byte.
    """
    var start = len(out)
    var total = start + extra
    if total > out.capacity():
        out.reserve(max(total, out.capacity() * 2))
    out.resize(unsafe_uninit_length=total)
    return start


@always_inline
def _store_be(mut out: List[UInt8], at: Int, value: UInt64, size: Int):
    """Store the low `size` bytes of a value, big-endian, at an offset."""
    var p = out.unsafe_ptr().unsafe_offset(at)
    if size == 1:
        p[] = UInt8(value)
    elif size == 2:
        p.unsafe_bitcast[UInt16]().unsafe_store[alignment=1](
            byte_swap(UInt16(value))
        )
    elif size == 4:
        p.unsafe_bitcast[UInt32]().unsafe_store[alignment=1](
            byte_swap(UInt32(value))
        )
    else:
        p.unsafe_bitcast[UInt64]().unsafe_store[alignment=1](byte_swap(value))


@always_inline
def write_varint(mut out: List[UInt8], value: UInt64):
    """Append the shortest encoding of a value.

    Args:
        out: The destination.
        value: A value of at most `VARINT_MAX`.
    """
    var size = varint_size(value)
    var tag = UInt64(0)
    if size == 2:
        tag = UInt64(1) << 14
    elif size == 4:
        tag = UInt64(2) << 30
    elif size == 8:
        tag = UInt64(3) << 62
    var at = reserve_tail(out, size)
    _store_be(out, at, (value & VARINT_MAX) | tag, size)


@always_inline
def write_varint_2(mut out: List[UInt8], value: UInt64):
    """Append the two-byte encoding of a value.

    This form holds a length that `patch_varint_2` sets later.

    Args:
        out: The destination.
        value: A value below 16384.
    """
    var at = reserve_tail(out, 2)
    _store_be(out, at, (value & 0x3FFF) | 0x4000, 2)


@always_inline
def patch_varint_2(mut out: List[UInt8], at: Int, value: UInt64):
    """Overwrite a two-byte encoding that `write_varint_2` wrote.

    Args:
        out: The list.
        at: The offset of the first byte of the integer.
        value: A value below 16384.
    """
    _store_be(out, at, (value & 0x3FFF) | 0x4000, 2)


@always_inline
def write_u8(mut out: List[UInt8], value: UInt8):
    """Append one byte.

    Args:
        out: The destination.
        value: The byte.
    """
    out.append(value)


@always_inline
def write_u16(mut out: List[UInt8], value: UInt16):
    """Append a 16-bit integer, big-endian.

    Args:
        out: The destination.
        value: The integer.
    """
    var at = reserve_tail(out, 2)
    _store_be(out, at, UInt64(value), 2)


@always_inline
def write_u32(mut out: List[UInt8], value: UInt32):
    """Append a 32-bit integer, big-endian.

    Args:
        out: The destination.
        value: The integer.
    """
    var at = reserve_tail(out, 4)
    _store_be(out, at, UInt64(value), 4)


@always_inline
def write_u64(mut out: List[UInt8], value: UInt64):
    """Append a 64-bit integer, big-endian.

    Args:
        out: The destination.
        value: The integer.
    """
    var at = reserve_tail(out, 8)
    _store_be(out, at, value, 8)


@always_inline
def write_bytes(mut out: List[UInt8], data: Span[UInt8, _]):
    """Append bytes.

    Args:
        out: The destination.
        data: The bytes.
    """
    var n = len(data)
    var at = reserve_tail(out, n)
    unsafe_memcpy(
        dest=out.unsafe_ptr().unsafe_offset(at), src=data.unsafe_ptr(), count=n
    )


@always_inline
def _load_be(p: Pointer[UInt8, _], size: Int) -> UInt64:
    """Load `size` bytes, big-endian; `size` is 1, 2, 4 or 8."""
    if size == 1:
        return UInt64(p[])
    if size == 2:
        return UInt64(
            byte_swap(p.unsafe_bitcast[UInt16]().unsafe_load[alignment=1]())
        )
    if size == 4:
        return UInt64(
            byte_swap(p.unsafe_bitcast[UInt32]().unsafe_load[alignment=1]())
        )
    return byte_swap(p.unsafe_bitcast[UInt64]().unsafe_load[alignment=1]())


@always_inline
def read_be(
    data: Span[UInt8, _], mut pos: Int, size: Int
) raises QuicError -> UInt64:
    """Read a fixed-size big-endian integer.

    Args:
        data: The bytes.
        pos: The cursor. It moves past the integer.
        size: 1, 2, 4 or 8.

    Returns:
        The value.

    Raises:
        QuicError: `FRAME_ENCODING_ERROR` when the bytes end first.
    """
    if pos + size > len(data):
        raise unexpected_end()
    var value = _load_be(data.unsafe_ptr().unsafe_offset(pos), size)
    pos += size
    return value


@always_inline
def read_varint(data: Span[UInt8, _], mut pos: Int) raises QuicError -> UInt64:
    """Read one variable-length integer.

    Args:
        data: The bytes.
        pos: The cursor. It moves past the integer.

    Returns:
        The value.

    Raises:
        QuicError: `FRAME_ENCODING_ERROR` when the bytes end first.
    """
    var n = len(data)
    if pos >= n:
        raise unexpected_end()
    var p = data.unsafe_ptr().unsafe_offset(pos)
    var size = 1 << Int(p[] >> 6)
    if pos + size > n:
        raise unexpected_end()
    var value = _load_be(p, size)
    pos += size
    return value & (VARINT_MAX >> UInt64(64 - 8 * size))
