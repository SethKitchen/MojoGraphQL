# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Find the next byte of interest, 32 bytes at a time.

The parser spends most of its time in two places: white space between
tokens, and the bytes of a string. The writer spends most of its time in
the bytes of a string. Each finder here compares 32 bytes at once with
SIMD, turns the result into a bit mask, and counts the trailing zeros of
the mask to find the first byte that matches.

The parser finders need a padded input: at least `PADDING` readable bytes
after the end of the input, the first of them zero. A zero byte stops both
of them, so they need no check for the end of the input. The writer finder
takes an end offset and reads no byte at or after it.

This module has no upstream counterpart; the design follows
`gql_language/scan.mojo`, which `gql_json` does not import.
"""

from std.bit import count_trailing_zeros
from std.memory import pack_bits

comptime WIDTH = 32
"""How many bytes one comparison looks at."""
comptime PADDING = 64
"""The zero bytes that a parser input needs after its end."""


@always_inline
def skip_whitespace(data: Span[UInt8, _], start: Int) -> Int:
    """Return the offset of the first byte that is not JSON white space.

    JSON white space is space, tab, line feed and carriage return.

    Args:
        data: Padded bytes.
        start: The first offset to look at; at most the input length.

    Returns:
        The offset; a padding zero stops the search.
    """
    var bytes = data.unsafe_ptr()
    var index = start
    while True:
        var chunk = bytes.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var space = (
            chunk.eq(0x20) | chunk.eq(0x0A) | chunk.eq(0x0D) | chunk.eq(0x09)
        )
        var mask = pack_bits[DType.uint32](~space)
        if mask != 0:
            return index + Int(count_trailing_zeros(mask))
        index += WIDTH


@always_inline
def scan_string(data: Span[UInt8, _], start: Int) -> Int:
    """Return the offset of the first byte that a string scan must stop at.

    That is a quote, a backslash, a control character below 0x20, or a
    byte of 0x80 or more, which starts a UTF-8 sequence to check.

    Args:
        data: Padded bytes.
        start: The first offset to look at; at most the input length.

    Returns:
        The offset; a padding zero stops the search.
    """
    var bytes = data.unsafe_ptr()
    var index = start
    while True:
        var chunk = bytes.unsafe_offset(index).unsafe_load[width=WIDTH]()
        # A byte below 0x20 wraps to 0xE0 or more; a byte of 0x80 or more
        # becomes 0x60 or more.
        var stop = chunk.eq(0x22) | chunk.eq(0x5C) | (chunk - 0x20).ge(0x60)
        var mask = pack_bits[DType.uint32](stop)
        if mask != 0:
            return index + Int(count_trailing_zeros(mask))
        index += WIDTH


def find_escape(data: Span[UInt8, _], start: Int, end: Int) -> Int:
    """Return the offset of the first byte that `JSON.stringify` escapes.

    That is a quote, a backslash, or a control character below 0x20.

    Args:
        data: Valid UTF-8 bytes.
        start: The first offset to look at.
        end: The offset after the last one.

    Returns:
        The offset, or `end` when no byte needs an escape.
    """
    var bytes = data.unsafe_ptr()
    var index = start
    while index + WIDTH <= end:
        var chunk = bytes.unsafe_offset(index).unsafe_load[width=WIDTH]()
        var stop = chunk.eq(0x22) | chunk.eq(0x5C) | chunk.lt(0x20)
        var mask = pack_bits[DType.uint32](stop)
        if mask != 0:
            return index + Int(count_trailing_zeros(mask))
        index += WIDTH
    while index < end:
        var byte = bytes[unsafe_offset=index]
        if byte == 0x22 or byte == 0x5C or byte < 0x20:
            return index
        index += 1
    return end
