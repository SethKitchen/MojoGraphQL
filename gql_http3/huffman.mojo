# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Huffman code of HPACK (RFC 7541 Appendix B), which QPACK uses for
string literals (RFC 9204 section 4.1.2).

`huffman_encode` packs the codes into a 64-bit accumulator and writes four
bytes at a time. The last byte is padded with the high bits of EOS, that is
with ones.

`huffman_decode` keeps up to 64 input bits in an accumulator, from its
high bit down, and fills it with one 8-byte load while 8 bytes remain. A
table of
512 entries, indexed by the next 9 bits, gives the symbol and the length of
every code of 9 bits or fewer: the common bytes of field names and values.
The longer codes are found from the canonical form of the code: the codes
of one length are consecutive numbers. The tables are built at compile
time from `_CODES` and `_LENGTHS`, and live in read-only data.

A decoder must refuse padding of more than 7 bits, padding that is not the
prefix of EOS, and the EOS symbol in a string (RFC 7541 section 5.2).

This module ports `h3/src/qpack/prefix_string/encode.rs` and `decode.rs`
of hyperium/h3 h3-v0.0.8 (22c1aa3), MIT. The code table is upstream's
`HPACK_STRING` table, which is RFC 7541 Appendix B.

Differences from upstream: upstream walks a tree of tables bit window by
bit window, and returns an iterator of results. Here the decoder is a table
lookup per symbol, and it appends to a byte list. Upstream accepts a last
byte of 8 padding bits, and a code that the input cuts in the middle if its
last bits are ones. This port refuses both, as RFC 7541 section 5.2
requires.
"""

from std.bit import byte_swap
from std.builtin.globals import global_constant
from std.memory import bitcast

from gql_http3.error import H3Error, H3ErrorCode

comptime _CODES: Array[UInt32, 257] = [
    0x1FF8,
    0x7FFFD8,
    0xFFFFFE2,
    0xFFFFFE3,
    0xFFFFFE4,
    0xFFFFFE5,
    0xFFFFFE6,
    0xFFFFFE7,
    0xFFFFFE8,
    0xFFFFEA,
    0x3FFFFFFC,
    0xFFFFFE9,
    0xFFFFFEA,
    0x3FFFFFFD,
    0xFFFFFEB,
    0xFFFFFEC,
    0xFFFFFED,
    0xFFFFFEE,
    0xFFFFFEF,
    0xFFFFFF0,
    0xFFFFFF1,
    0xFFFFFF2,
    0x3FFFFFFE,
    0xFFFFFF3,
    0xFFFFFF4,
    0xFFFFFF5,
    0xFFFFFF6,
    0xFFFFFF7,
    0xFFFFFF8,
    0xFFFFFF9,
    0xFFFFFFA,
    0xFFFFFFB,
    0x14,
    0x3F8,
    0x3F9,
    0xFFA,
    0x1FF9,
    0x15,
    0xF8,
    0x7FA,
    0x3FA,
    0x3FB,
    0xF9,
    0x7FB,
    0xFA,
    0x16,
    0x17,
    0x18,
    0x0,
    0x1,
    0x2,
    0x19,
    0x1A,
    0x1B,
    0x1C,
    0x1D,
    0x1E,
    0x1F,
    0x5C,
    0xFB,
    0x7FFC,
    0x20,
    0xFFB,
    0x3FC,
    0x1FFA,
    0x21,
    0x5D,
    0x5E,
    0x5F,
    0x60,
    0x61,
    0x62,
    0x63,
    0x64,
    0x65,
    0x66,
    0x67,
    0x68,
    0x69,
    0x6A,
    0x6B,
    0x6C,
    0x6D,
    0x6E,
    0x6F,
    0x70,
    0x71,
    0x72,
    0xFC,
    0x73,
    0xFD,
    0x1FFB,
    0x7FFF0,
    0x1FFC,
    0x3FFC,
    0x22,
    0x7FFD,
    0x3,
    0x23,
    0x4,
    0x24,
    0x5,
    0x25,
    0x26,
    0x27,
    0x6,
    0x74,
    0x75,
    0x28,
    0x29,
    0x2A,
    0x7,
    0x2B,
    0x76,
    0x2C,
    0x8,
    0x9,
    0x2D,
    0x77,
    0x78,
    0x79,
    0x7A,
    0x7B,
    0x7FFE,
    0x7FC,
    0x3FFD,
    0x1FFD,
    0xFFFFFFC,
    0xFFFE6,
    0x3FFFD2,
    0xFFFE7,
    0xFFFE8,
    0x3FFFD3,
    0x3FFFD4,
    0x3FFFD5,
    0x7FFFD9,
    0x3FFFD6,
    0x7FFFDA,
    0x7FFFDB,
    0x7FFFDC,
    0x7FFFDD,
    0x7FFFDE,
    0xFFFFEB,
    0x7FFFDF,
    0xFFFFEC,
    0xFFFFED,
    0x3FFFD7,
    0x7FFFE0,
    0xFFFFEE,
    0x7FFFE1,
    0x7FFFE2,
    0x7FFFE3,
    0x7FFFE4,
    0x1FFFDC,
    0x3FFFD8,
    0x7FFFE5,
    0x3FFFD9,
    0x7FFFE6,
    0x7FFFE7,
    0xFFFFEF,
    0x3FFFDA,
    0x1FFFDD,
    0xFFFE9,
    0x3FFFDB,
    0x3FFFDC,
    0x7FFFE8,
    0x7FFFE9,
    0x1FFFDE,
    0x7FFFEA,
    0x3FFFDD,
    0x3FFFDE,
    0xFFFFF0,
    0x1FFFDF,
    0x3FFFDF,
    0x7FFFEB,
    0x7FFFEC,
    0x1FFFE0,
    0x1FFFE1,
    0x3FFFE0,
    0x1FFFE2,
    0x7FFFED,
    0x3FFFE1,
    0x7FFFEE,
    0x7FFFEF,
    0xFFFEA,
    0x3FFFE2,
    0x3FFFE3,
    0x3FFFE4,
    0x7FFFF0,
    0x3FFFE5,
    0x3FFFE6,
    0x7FFFF1,
    0x3FFFFE0,
    0x3FFFFE1,
    0xFFFEB,
    0x7FFF1,
    0x3FFFE7,
    0x7FFFF2,
    0x3FFFE8,
    0x1FFFFEC,
    0x3FFFFE2,
    0x3FFFFE3,
    0x3FFFFE4,
    0x7FFFFDE,
    0x7FFFFDF,
    0x3FFFFE5,
    0xFFFFF1,
    0x1FFFFED,
    0x7FFF2,
    0x1FFFE3,
    0x3FFFFE6,
    0x7FFFFE0,
    0x7FFFFE1,
    0x3FFFFE7,
    0x7FFFFE2,
    0xFFFFF2,
    0x1FFFE4,
    0x1FFFE5,
    0x3FFFFE8,
    0x3FFFFE9,
    0xFFFFFFD,
    0x7FFFFE3,
    0x7FFFFE4,
    0x7FFFFE5,
    0xFFFEC,
    0xFFFFF3,
    0xFFFED,
    0x1FFFE6,
    0x3FFFE9,
    0x1FFFE7,
    0x1FFFE8,
    0x7FFFF3,
    0x3FFFEA,
    0x3FFFEB,
    0x1FFFFEE,
    0x1FFFFEF,
    0xFFFFF4,
    0xFFFFF5,
    0x3FFFFEA,
    0x7FFFF4,
    0x3FFFFEB,
    0x7FFFFE6,
    0x3FFFFEC,
    0x3FFFFED,
    0x7FFFFE7,
    0x7FFFFE8,
    0x7FFFFE9,
    0x7FFFFEA,
    0x7FFFFEB,
    0xFFFFFFE,
    0x7FFFFEC,
    0x7FFFFED,
    0x7FFFFEE,
    0x7FFFFEF,
    0x7FFFFF0,
    0x3FFFFEE,
    0x3FFFFFFF,
]
"""The code of each symbol: the bytes 0 to 255, then EOS (256)."""

comptime _LENGTHS: Array[UInt8, 257] = [
    13,
    23,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    24,
    30,
    28,
    28,
    30,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    30,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    6,
    10,
    10,
    12,
    13,
    6,
    8,
    11,
    10,
    10,
    8,
    11,
    8,
    6,
    6,
    6,
    5,
    5,
    5,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    7,
    8,
    15,
    6,
    12,
    10,
    13,
    6,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    8,
    7,
    8,
    13,
    19,
    13,
    14,
    6,
    15,
    5,
    6,
    5,
    6,
    5,
    6,
    6,
    6,
    5,
    7,
    7,
    6,
    6,
    6,
    5,
    6,
    7,
    6,
    5,
    5,
    6,
    7,
    7,
    7,
    7,
    7,
    15,
    11,
    14,
    13,
    28,
    20,
    22,
    20,
    20,
    22,
    22,
    22,
    23,
    22,
    23,
    23,
    23,
    23,
    23,
    24,
    23,
    24,
    24,
    22,
    23,
    24,
    23,
    23,
    23,
    23,
    21,
    22,
    23,
    22,
    23,
    23,
    24,
    22,
    21,
    20,
    22,
    22,
    23,
    23,
    21,
    23,
    22,
    22,
    24,
    21,
    22,
    23,
    23,
    21,
    21,
    22,
    21,
    23,
    22,
    23,
    23,
    20,
    22,
    22,
    22,
    23,
    22,
    22,
    23,
    26,
    26,
    20,
    19,
    22,
    23,
    22,
    25,
    26,
    26,
    26,
    27,
    27,
    26,
    24,
    25,
    19,
    21,
    26,
    27,
    27,
    26,
    27,
    24,
    21,
    21,
    26,
    26,
    28,
    27,
    27,
    27,
    20,
    24,
    20,
    21,
    22,
    21,
    21,
    23,
    22,
    22,
    25,
    25,
    24,
    24,
    26,
    23,
    26,
    27,
    26,
    26,
    27,
    27,
    27,
    27,
    27,
    28,
    27,
    27,
    27,
    27,
    27,
    26,
    30,
]
"""The length in bits of the code of each symbol."""

comptime EOS = 256
"""The end-of-string symbol, which a string must not hold."""
comptime FAST_BITS = 9
"""The width of the first decode table: codes up to this length."""
comptime MAX_CODE_BITS = 30
"""The length of the longest code."""


def _build_fast() -> Array[UInt16, 512]:
    """Return the first decode table: `length << 8 | symbol` for each
    9-bit prefix that starts with a code of 9 bits or fewer, else 0."""
    var codes = materialize[_CODES]()
    var lengths = materialize[_LENGTHS]()
    var table = Array[UInt16, 512](fill=0)
    var symbol = 0
    while symbol < 256:
        var length = Int(lengths[symbol])
        if length <= FAST_BITS:
            var span = 1 << (FAST_BITS - length)
            var base = Int(codes[symbol]) << (FAST_BITS - length)
            var j = 0
            while j < span:
                table[base + j] = UInt16((length << 8) | symbol)
                j += 1
        symbol += 1
    return table^


def _build_sorted() -> Array[UInt16, 257]:
    """Return the symbols sorted by code length, then by symbol."""
    var lengths = materialize[_LENGTHS]()
    var out = Array[UInt16, 257](fill=0)
    var at = 0
    var length = 5
    while length <= MAX_CODE_BITS:
        var symbol = 0
        while symbol <= EOS:
            if Int(lengths[symbol]) == length:
                out[at] = UInt16(symbol)
                at += 1
            symbol += 1
        length += 1
    return out^


def _build_count() -> Array[UInt16, 32]:
    """Return the number of codes of each length."""
    var lengths = materialize[_LENGTHS]()
    var out = Array[UInt16, 32](fill=0)
    var symbol = 0
    while symbol <= EOS:
        out[Int(lengths[symbol])] += 1
        symbol += 1
    return out^


def _build_first() -> Array[UInt32, 32]:
    """Return the first code of each length, in canonical order."""
    var count = materialize[_COUNT]()
    var out = Array[UInt32, 32](fill=0)
    var code = UInt32(0)
    var length = 1
    while length <= MAX_CODE_BITS:
        out[length] = code
        code = (code + UInt32(count[length])) << 1
        length += 1
    return out^


def _build_offset() -> Array[UInt16, 32]:
    """Return the index in `_SORTED` of the first symbol of each length."""
    var count = materialize[_COUNT]()
    var out = Array[UInt16, 32](fill=0)
    var at = 0
    var length = 1
    while length <= MAX_CODE_BITS:
        out[length] = UInt16(at)
        at += Int(count[length])
        length += 1
    return out^


comptime _FAST = _build_fast()
"""The first decode table, indexed by the next 9 bits."""
comptime _SORTED = _build_sorted()
"""The symbols in canonical order."""
comptime _COUNT = _build_count()
"""The number of codes of each length."""
comptime _FIRST = _build_first()
"""The first code of each length."""
comptime _OFFSET = _build_offset()
"""The index in `_SORTED` of the first symbol of each length."""


def huffman_code(symbol: Int) -> Tuple[UInt32, Int]:
    """Return the code of a symbol and its length in bits.

    Args:
        symbol: A byte value, or `EOS`.

    Returns:
        The code, right-aligned, and its length.
    """
    ref codes = global_constant[_CODES]()
    ref lengths = global_constant[_LENGTHS]()
    return (codes[symbol], Int(lengths[symbol]))


@always_inline
def huffman_encoded_length(data: Span[UInt8, _]) -> Int:
    """Return the size of the Huffman encoding of some bytes.

    Args:
        data: The bytes.

    Returns:
        The number of bytes that `huffman_encode` appends.
    """
    ref lengths = global_constant[_LENGTHS]()
    var table = lengths.unsafe_ptr()
    var p = data.unsafe_ptr()
    var bits = 0
    var index = 0
    while index < len(data):
        bits += Int(table[unsafe_offset=Int(p[unsafe_offset=index])])
        index += 1
    return (bits + 7) >> 3


def huffman_encode(data: Span[UInt8, _], mut out: List[UInt8]):
    """Append the Huffman encoding of some bytes, padded with ones.

    Args:
        data: The bytes.
        out: The destination.
    """
    ref codes = global_constant[_CODES]()
    ref lengths = global_constant[_LENGTHS]()
    var code_table = codes.unsafe_ptr()
    var length_table = lengths.unsafe_ptr()
    var n = len(data)
    out.reserve(len(out) + n * 4 + 8)
    var dest = out.unsafe_ptr().unsafe_origin_cast[UntrackedOrigin[mut=True]]()
    var at = len(out)
    var p = data.unsafe_ptr()
    var acc = UInt64(0)
    var nbits = 0
    var index = 0
    while index < n:
        var symbol = Int(p[unsafe_offset=index])
        var length = Int(length_table[unsafe_offset=symbol])
        acc = (acc << UInt64(length)) | UInt64(code_table[unsafe_offset=symbol])
        nbits += length
        if nbits >= 32:
            nbits -= 32
            var word = acc >> UInt64(nbits)
            dest[unsafe_offset=at] = UInt8((word >> 24) & 0xFF)
            dest[unsafe_offset=at + 1] = UInt8((word >> 16) & 0xFF)
            dest[unsafe_offset=at + 2] = UInt8((word >> 8) & 0xFF)
            dest[unsafe_offset=at + 3] = UInt8(word & 0xFF)
            at += 4
        index += 1
    while nbits >= 8:
        nbits -= 8
        dest[unsafe_offset=at] = UInt8((acc >> UInt64(nbits)) & 0xFF)
        at += 1
    if nbits > 0:
        var pad = 8 - nbits
        var last = (acc << UInt64(pad)) | ((UInt64(1) << UInt64(pad)) - 1)
        dest[unsafe_offset=at] = UInt8(last & 0xFF)
        at += 1
    out._len = at


@always_inline
def _load_be64(p: Pointer[UInt8, _], at: Int) -> UInt64:
    """Return 8 bytes at an offset as a big-endian integer."""
    var bytes = p.unsafe_offset(at).unsafe_load[width=8]()
    return byte_swap(bitcast[DType.uint64, 1](bytes)[0])


def _decode_long(acc: UInt64) -> Tuple[Int, Int]:
    """Find a code longer than `FAST_BITS` from the canonical tables.

    `acc` holds the next bits from its high bit down; the bits after the
    input are zeros.

    Returns:
        The symbol and the length of the code. The code is complete, so
        30 bits always end in a code.
    """
    ref first = global_constant[_FIRST]()
    ref count = global_constant[_COUNT]()
    ref offset = global_constant[_OFFSET]()
    ref sorted = global_constant[_SORTED]()
    var length = FAST_BITS + 1
    while True:
        var code = acc >> UInt64(64 - length)
        var delta = code - UInt64(first[length])
        if delta < UInt64(count[length]):
            return (Int(sorted[Int(offset[length]) + Int(delta)]), length)
        length += 1


def _invalid() -> H3Error:
    """Return the error of a string that is not a valid Huffman encoding."""
    return H3Error(
        H3ErrorCode.QPACK_DECOMPRESSION_FAILED, "invalid Huffman encoding"
    )


def huffman_decode(data: Span[UInt8, _], mut out: List[UInt8]) raises H3Error:
    """Append the bytes that a Huffman encoding holds.

    The accumulator holds the next input bits from its high bit down. It
    takes 8 bytes with one load while 8 remain, then one byte at a time.
    A code that seems to end after the last input bit is an error, so the
    zeros after the input never decode.

    Args:
        data: The encoded bytes.
        out: The destination.

    Raises:
        H3Error: `QPACK_DECOMPRESSION_FAILED` for EOS in the string, a code
            that the input cuts, or padding that is longer than 7 bits or
            not all ones.
    """
    ref fast = global_constant[_FAST]()
    var fast_table = fast.unsafe_ptr()
    var n = len(data)
    out.reserve(len(out) + (n * 8) // 5 + 1)
    var dest = out.unsafe_ptr().unsafe_origin_cast[UntrackedOrigin[mut=True]]()
    var at = len(out)
    var p = data.unsafe_ptr()
    var acc = UInt64(0)
    var nbits = 0
    var pos = 0
    while True:
        if nbits <= 56:
            if pos + 8 <= n:
                acc |= _load_be64(p, pos) >> UInt64(nbits)
                var take = (63 - nbits) >> 3
                pos += take
                nbits += take * 8
            else:
                while nbits <= 56 and pos < n:
                    acc |= UInt64(p[unsafe_offset=pos]) << UInt64(56 - nbits)
                    nbits += 8
                    pos += 1
        if nbits < 8:
            # The input is all read. Ones that fill the last byte end it.
            var ones = (UInt64(1) << UInt64(nbits)) - 1
            if (acc >> 56) >> UInt64(8 - nbits) == ones:
                break
        var entry = Int(fast_table[unsafe_offset=Int(acc >> 55)])
        var symbol = entry & 0xFF
        var length = entry >> 8
        if length == 0:
            var found = _decode_long(acc)
            symbol = found[0]
            length = found[1]
        if length > nbits or symbol == EOS:
            out._len = at
            raise _invalid()
        dest[unsafe_offset=at] = UInt8(symbol)
        at += 1
        acc <<= UInt64(length)
        nbits -= length
    out._len = at
