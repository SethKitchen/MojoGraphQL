# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Find the next byte of interest, 32 bytes at a time.

The lexer, the block string decoder and the printer spend most of their time
looking for the few bytes that end a run of ordinary text: a quote, a
backslash, a line break. Each finder compares 32 bytes at once with SIMD,
turns the matches into a bit mask, and takes its lowest bit.

A finder reads whole 32-byte chunks while they fit in `data`, even past
`end`, so a short run near the start of a long buffer is still one
comparison; a match at or past `end` counts as none. Only within 32 bytes of
the end of `data` does it read one byte at a time.

This module has no graphql-js counterpart; it is how this port is fast.
"""

from std.bit import count_trailing_zeros
from std.memory import pack_bits, unsafe_memcpy

comptime WIDTH = 32
"""How many bytes one comparison looks at."""


@always_inline
def _mask(hits: SIMD[DType.bool, WIDTH]) -> UInt32:
    """Return one bit per lane that matched."""
    return pack_bits[DType.uint32](hits)


@always_inline
def _first(index: Int, mask: UInt32, end: Int) -> Int:
    """Return the offset of a mask's lowest bit, but at most `end`."""
    return min(index + Int(count_trailing_zeros(mask)), end)


def find_byte(data: Span[UInt8, _], start: Int, end: Int, a: UInt8) -> Int:
    """Return the offset of the first byte equal to `a`.

    Args:
        data: The bytes.
        start: The first offset to look at.
        end: The offset after the last one.
        a: The byte to find.

    Returns:
        The offset, or `end` when no byte matches.
    """
    var bytes = data.unsafe_ptr()
    var limit = len(data)
    var index = start
    while index < end and index + WIDTH <= limit:
        var chunk = bytes.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var mask = _mask(chunk.eq(a))
        if mask != 0:
            return _first(index, mask, end)
        index += WIDTH
    while index < end:
        if bytes[unsafe_offset=index] == a:
            return index
        index += 1
    return end


def find_byte2(
    data: Span[UInt8, _], start: Int, end: Int, a: UInt8, b: UInt8
) -> Int:
    """Return the offset of the first byte equal to `a` or `b`.

    Args:
        data: The bytes.
        start: The first offset to look at.
        end: The offset after the last one.
        a: A byte to find.
        b: Another byte to find.

    Returns:
        The offset, or `end` when no byte matches.
    """
    var bytes = data.unsafe_ptr()
    var limit = len(data)
    var index = start
    while index < end and index + WIDTH <= limit:
        var chunk = bytes.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var mask = _mask(chunk.eq(a) | chunk.eq(b))
        if mask != 0:
            return _first(index, mask, end)
        index += WIDTH
    while index < end:
        var byte = bytes[unsafe_offset=index]
        if byte == a or byte == b:
            return index
        index += 1
    return end


def find_byte4(
    data: Span[UInt8, _],
    start: Int,
    end: Int,
    a: UInt8,
    b: UInt8,
    c: UInt8,
    d: UInt8,
) -> Int:
    """Return the offset of the first byte equal to `a`, `b`, `c` or `d`.

    Args:
        data: The bytes.
        start: The first offset to look at.
        end: The offset after the last one.
        a: A byte to find.
        b: A byte to find.
        c: A byte to find.
        d: A byte to find.

    Returns:
        The offset, or `end` when no byte matches.
    """
    var bytes = data.unsafe_ptr()
    var limit = len(data)
    var index = start
    while index < end and index + WIDTH <= limit:
        var chunk = bytes.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var hits = chunk.eq(a) | chunk.eq(b) | chunk.eq(c) | chunk.eq(d)
        var mask = _mask(hits)
        if mask != 0:
            return _first(index, mask, end)
        index += WIDTH
    while index < end:
        var byte = bytes[unsafe_offset=index]
        if byte == a or byte == b or byte == c or byte == d:
            return index
        index += 1
    return end


def find_string_escape(data: Span[UInt8, _], start: Int, end: Int) -> Int:
    """Return the offset of the first byte that graphql-js `printString`
    can escape: a control character, `"`, `\\`, U+007F, or the lead byte
    0xC2 of U+0080 to U+00BF.

    Args:
        data: UTF-8 bytes.
        start: The first offset to look at.
        end: The offset after the last one.

    Returns:
        The offset, or `end` when no byte can need an escape.
    """
    var bytes = data.unsafe_ptr()
    var limit = len(data)
    var index = start
    while index < end and index + WIDTH <= limit:
        var chunk = bytes.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var hits = (
            chunk.lt(0x20)
            | chunk.eq(0x22)
            | chunk.eq(0x5C)
            | chunk.eq(0x7F)
            | chunk.eq(0xC2)
        )
        var mask = _mask(hits)
        if mask != 0:
            return _first(index, mask, end)
        index += WIDTH
    while index < end:
        var byte = bytes[unsafe_offset=index]
        if (
            byte < 0x20
            or byte == 0x22
            or byte == 0x5C
            or byte == 0x7F
            or byte == 0xC2
        ):
            return index
        index += 1
    return end


def count_utf16(data: Span[UInt8, _], start: Int, end: Int) -> Int:
    """Return how many UTF-16 code units some UTF-8 bytes encode.

    Args:
        data: Valid UTF-8 bytes.
        start: The first offset.
        end: The offset after the last one.

    Returns:
        One unit per code point, and two above U+FFFF.
    """
    var bytes = data.unsafe_ptr()
    var units = 0
    var index = start
    while index + WIDTH <= end:
        var chunk = bytes.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var leads = (chunk & 0xC0).ne(0x80).cast[DType.uint8]()
        var wide = chunk.ge(0xF0).cast[DType.uint8]()
        units += Int((leads + wide).cast[DType.uint16]().reduce_add())
        index += WIDTH
    while index < end:
        var byte = bytes[unsafe_offset=index]
        if byte & 0xC0 != 0x80:
            units += 1
            if byte >= 0xF0:
                units += 1
        index += 1
    return units


def string_from_utf8(bytes: Span[UInt8, _]) -> String:
    """Copy bytes that are valid UTF-8 into a string, without checking them.

    `String(unsafe_from_utf8=...)` checks the bytes again. The lexer and the
    printers make bytes from a `Source`, which is valid UTF-8, so the check
    is not necessary.

    Args:
        bytes: Valid UTF-8.

    Returns:
        A string with the bytes.
    """
    var size = len(bytes)
    var text = String(unsafe_uninit_length=size)
    unsafe_memcpy(
        dest=text.unsafe_ptr_mut(), src=bytes.unsafe_ptr(), count=size
    )
    return text^
