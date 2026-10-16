# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Byte classes of RFC 9110 and RFC 9112, and SIMD scanners for them.

The parser spends most of its time in two loops: the request target and the
field values. Each scanner here compares 32 bytes at once with SIMD, and
finishes the last bytes one at a time. A scanner reads no byte at or after
`end`. A byte class is a string of 256 `0` and `1` bytes in read-only
data, so a test is one load.

This module has no upstream counterpart. It ports no code.

Differences from upstream: none; there is no upstream.
"""

from std.bit import count_trailing_zeros
from std.memory import pack_bits

comptime WIDTH = 32
"""How many bytes one SIMD comparison looks at."""

comptime CR: UInt8 = 13
"""Carriage return."""
comptime LF: UInt8 = 10
"""Line feed."""
comptime SP: UInt8 = 32
"""Space."""
comptime HTAB: UInt8 = 9
"""Horizontal tab."""
comptime COLON: UInt8 = 58
"""The `:` byte."""


comptime _TCHAR_TABLE = (
    "0000000000000000000000000000000001011111001101101111111111000000"
    "0111111111111111111111111110001111111111111111111111111111101010"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
)
"""One `1` or `0` for each byte value: whether it is a `tchar`. A string
lives in read-only data, so a lookup is one load."""


@always_inline
def is_tchar(byte: UInt8) -> Bool:
    """Return True for a `tchar`: a byte of a token, such as a method name.

    Args:
        byte: The byte.

    Returns:
        Whether the byte is a letter, a digit or one of ``!#$%&'*+-.^_`|~``.
    """
    return (
        StaticString(_TCHAR_TABLE).unsafe_ptr()[unsafe_offset=Int(byte)] == 49
    )


comptime _HOST_TABLE = (
    "0000000000000000000000000000000001001111111111101111111111110100"
    "0111111111111111111111111111010101111111111111111111111111100010"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
)
"""One `1` or `0` for each byte value: whether a `Host` value can hold
it."""


@always_inline
def is_host_byte(byte: UInt8) -> Bool:
    """Return True for a byte that a `Host` value can hold.

    The class is `uri-host [ ":" port ]` of RFC 3986: unreserved and
    sub-delimiter bytes, `%`, `:` and the IP literal brackets.

    Args:
        byte: The byte.

    Returns:
        Whether the byte can appear in a `Host` value.
    """
    return StaticString(_HOST_TABLE).unsafe_ptr()[unsafe_offset=Int(byte)] == 49


@always_inline
def is_field_byte(byte: UInt8) -> Bool:
    """Return True for a byte of a field value: VCHAR, obs-text, SP or HTAB.

    Args:
        byte: The byte.

    Returns:
        Whether a field value can hold the byte.
    """
    return (byte >= SP and byte != 127) or byte == HTAB


@always_inline
def lower(byte: UInt8) -> UInt8:
    """Return the ASCII lowercase form of a byte.

    Args:
        byte: The byte.

    Returns:
        The byte with `A` to `Z` mapped to `a` to `z`.
    """
    var upper = byte >= 65 and byte <= 90
    return byte | 32 if upper else byte


def find_field_end(data: Pointer[UInt8, _], start: Int, end: Int) -> Int:
    """Return the offset of the first byte that is not a field-value byte.

    A field value ends at its CR. Any other byte this returns is an error
    of the message: a bare LF, a NUL, another control byte, or DEL.

    Args:
        data: The bytes.
        start: The first offset to look at.
        end: The offset after the last one.

    Returns:
        The offset, or `end` when every byte is a field-value byte.
    """
    var index = start
    while index + WIDTH <= end:
        var chunk = data.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var bad = (chunk.lt(SP) & chunk.ne(HTAB)) | chunk.eq(127)
        var bits = pack_bits[DType.uint32](bad)
        if bits != 0:
            return index + Int(count_trailing_zeros(bits))
        index += WIDTH
    while index < end:
        if not is_field_byte(data[unsafe_offset=index]):
            return index
        index += 1
    return end


def find_target_end(data: Pointer[UInt8, _], start: Int, end: Int) -> Int:
    """Return the offset of the first byte outside `%x21-7E`.

    A request target ends at its SP. Any other byte this returns is an
    error of the request line.

    Args:
        data: The bytes.
        start: The first offset to look at.
        end: The offset after the last one.

    Returns:
        The offset, or `end` when every byte is visible ASCII.
    """
    var index = start
    while index + WIDTH <= end:
        var chunk = data.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var bad = chunk.le(SP) | chunk.ge(127)
        var bits = pack_bits[DType.uint32](bad)
        if bits != 0:
            return index + Int(count_trailing_zeros(bits))
        index += WIDTH
    while index < end:
        var byte = data[unsafe_offset=index]
        if byte <= SP or byte >= 127:
            return index
        index += 1
    return end


def find_byte(data: Pointer[UInt8, _], start: Int, end: Int, a: UInt8) -> Int:
    """Return the offset of the first byte equal to `a`.

    Args:
        data: The bytes.
        start: The first offset to look at.
        end: The offset after the last one.
        a: The byte to find.

    Returns:
        The offset, or `end` when no byte matches.
    """
    var index = start
    while index + WIDTH <= end:
        var chunk = data.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var hit = chunk.eq(a)
        var bits = pack_bits[DType.uint32](hit)
        if bits != 0:
            return index + Int(count_trailing_zeros(bits))
        index += WIDTH
    while index < end:
        if data[unsafe_offset=index] == a:
            return index
        index += 1
    return end


def move_down(
    data: Pointer[mut=True, UInt8, _], dest: Int, src: Int, count: Int
):
    """Copy `count` bytes from `src` to a lower or equal offset `dest`.

    The ranges can overlap. Each 32-byte load comes before the store that
    could overwrite it, because the store is at a lower offset.

    Args:
        data: The buffer.
        dest: The offset of the first byte to write; at most `src`.
        src: The offset of the first byte to read.
        count: How many bytes to copy.
    """
    var index = 0
    while index + WIDTH <= count:
        var chunk = data.unsafe_offset(src + index).unsafe_load[width=WIDTH]()
        data.unsafe_offset(dest + index).unsafe_store(chunk)
        index += WIDTH
    while index < count:
        data[unsafe_offset=dest + index] = data[unsafe_offset=src + index]
        index += 1


def equals_ignore_case(a: Span[UInt8, _], b: Span[UInt8, _]) -> Bool:
    """Compare two byte strings with ASCII case folded.

    Args:
        a: A byte string.
        b: Another byte string.

    Returns:
        Whether the strings have the same length and the same bytes, with
        `A` to `Z` equal to `a` to `z`.
    """
    if len(a) != len(b):
        return False
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var index = 0
    while index < len(a):
        if lower(pa[unsafe_offset=index]) != lower(pb[unsafe_offset=index]):
            return False
        index += 1
    return True


@always_inline
def equals_lower(
    data: Pointer[UInt8, _], start: Int, end: Int, word: StaticString
) -> Bool:
    """Compare bytes, with ASCII case folded, to a lowercase word.

    Args:
        data: The bytes.
        start: The offset of the first byte.
        end: The offset after the last byte.
        word: The word, in lowercase.

    Returns:
        Whether the bytes spell the word in any case.
    """
    if end - start != word.byte_length():
        return False
    var w = word.unsafe_ptr()
    var index = 0
    while index < end - start:
        if lower(data[unsafe_offset=start + index]) != w[unsafe_offset=index]:
            return False
        index += 1
    return True
