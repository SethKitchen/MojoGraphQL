# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Huffman code of HPACK (RFC 7541 section 5.2 and Appendix B).

`huffman_encode` appends the code of each byte to a buffer, and pads the
last byte with the high bits of EOS (all ones). `huffman_encoded_length`
gives the length of that output first, so a string literal can write its
length prefix before its bytes.

`HuffmanDecoder` holds two lookup tables that it builds once, when it is
made. The primary table maps the next 11 bits of the input to a symbol
and its code length, for every code of 11 bits or less: that is each
letter, digit and common punctuation byte. A longer code uses the canonical
form of the code: the codes of one length are consecutive numbers, so a
search of at most 19 limits finds the length, and one subtraction finds
the symbol. The decoder refuses the EOS symbol inside the string, padding
of 8 bits or more, and padding that is not all ones.

Ports `src/hpack/huffman/mod.rs`, `src/hpack/huffman/encode.rs`,
`src/hpack/huffman/decode.rs` and `src/hpack/huffman/table.rs` of
hyperium/h2 v0.4.20 (MIT). The code tables are those of `table.rs`.

Differences from upstream: the decoder uses an 11-bit primary table of
one symbol and a canonical search for the long codes, in place of the
12-bit table of one or two symbols and the byte-walk table of h2. The
decoder returns False for a bad code, in place of
`DecoderError::InvalidHuffmanCode`. The output of both directions is the
same as that of h2.
"""

from std.bit import byte_swap
from std.builtin.globals import global_constant

comptime PRIMARY_BITS = 11
"""How many input bits one lookup of the primary table reads."""
comptime EOS = 256
"""The symbol of the end of the string, which must not be in a string."""
comptime EOS_CODE: UInt32 = 0x3FFFFFFF
"""The code of EOS: 30 one bits."""
comptime EOS_LENGTH = 30
"""The length of the EOS code; no code is longer."""

comptime _CODES: Array[UInt32, 256] = [
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
]
"""The code of each byte, right-aligned (RFC 7541 Appendix B)."""

comptime _LENGTHS: Array[UInt8, 256] = [
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
]
"""The length of the code of each byte, in bits."""


def huffman_encoded_length(data: Span[UInt8, _]) -> Int:
    """Return how many bytes `huffman_encode` writes for some bytes.

    Args:
        data: The bytes to encode.

    Returns:
        The length of the code, in bytes, with the padding.
    """
    var lengths = global_constant[_LENGTHS]().unsafe_ptr()
    var source = data.unsafe_ptr()
    var bits = 0
    var index = 0
    while index < len(data):
        bits += Int(lengths[unsafe_offset=Int(source[unsafe_offset=index])])
        index += 1
    return (bits + 7) >> 3


def huffman_encode(data: Span[UInt8, _], mut out: List[UInt8]):
    """Append the Huffman code of some bytes to a buffer.

    The last byte is padded with one bits, the high bits of EOS.

    Args:
        data: The bytes to encode.
        out: The buffer; the code goes at its end.
    """
    var codes = global_constant[_CODES]().unsafe_ptr()
    var lengths = global_constant[_LENGTHS]().unsafe_ptr()
    var source = data.unsafe_ptr()
    var start = len(out)
    # A code is at most 30 bits; a 32-bit store can pass the end by 3.
    out.reserve(start + (len(data) * 30 + 7) // 8 + 4)
    var dst = out.unsafe_ptr()
    var written = start
    var acc: UInt64 = 0
    var bits = 0
    var index = 0
    while index < len(data):
        var byte = Int(source[unsafe_offset=index])
        var length = Int(lengths[unsafe_offset=byte])
        acc = (acc << UInt64(length)) | UInt64(codes[unsafe_offset=byte])
        bits += length
        if bits >= 32:
            bits -= 32
            var word = byte_swap((acc >> UInt64(bits)).cast[DType.uint32]())
            dst.unsafe_offset(written).unsafe_bitcast[UInt32]().unsafe_store[
                alignment=1
            ](word)
            written += 4
        index += 1
    var padding = (8 - (bits & 7)) & 7
    acc = (acc << UInt64(padding)) | ((UInt64(1) << UInt64(padding)) - 1)
    bits += padding
    while bits > 0:
        bits -= 8
        dst[unsafe_offset=written] = (acc >> UInt64(bits)).cast[DType.uint8]()
        written += 1
    out.resize(unsafe_uninit_length=written)


struct HuffmanDecoder(Copyable, Movable):
    """The lookup tables of the Huffman decoder, built once.

    An HPACK `Decoder` holds one, so the tables are built once for each
    connection, in about a microsecond.
    """

    var _primary: List[UInt16]
    """For each 11-bit prefix: the code length shifted left 8, or'ed with
    the symbol; 0 when the code is longer than 11 bits."""
    var _limit: List[UInt64]
    """For each length: one more than its last code, aligned left in 32
    bits."""
    var _first: List[UInt32]
    """For each length: its first code, right-aligned."""
    var _offset: List[UInt16]
    """For each length: the position of its first symbol in `_symbols`."""
    var _symbols: List[UInt16]
    """The 257 symbols in the order of their codes."""

    def __init__(out self):
        """Build the tables from the code of RFC 7541 Appendix B."""
        var codes = global_constant[_CODES]().unsafe_ptr()
        var lengths = global_constant[_LENGTHS]().unsafe_ptr()
        self._primary = List[UInt16](length=1 << PRIMARY_BITS, fill=0)
        self._limit = List[UInt64](length=EOS_LENGTH + 1, fill=0)
        self._first = List[UInt32](length=EOS_LENGTH + 1, fill=0)
        self._offset = List[UInt16](length=EOS_LENGTH + 1, fill=0)
        self._symbols = List[UInt16](length=EOS + 1, fill=0)
        var counts = List[Int](length=EOS_LENGTH + 1, fill=0)
        counts[EOS_LENGTH] = 1
        var symbol = 0
        while symbol < EOS:
            var length = Int(lengths[unsafe_offset=symbol])
            counts[length] += 1
            if length <= PRIMARY_BITS:
                var shift = PRIMARY_BITS - length
                var base = Int(codes[unsafe_offset=symbol]) << shift
                var entry = UInt16((length << 8) | symbol)
                var fill = 0
                while fill < (1 << shift):
                    self._primary[base + fill] = entry
                    fill += 1
            symbol += 1
        # The code is canonical: the codes of one length are consecutive,
        # and the first code of a length follows the last one shorter.
        var next_code: UInt64 = 0
        var position = 0
        var length = 1
        while length <= EOS_LENGTH:
            self._first[length] = UInt32(next_code)
            self._offset[length] = UInt16(position)
            var end = next_code + UInt64(counts[length])
            self._limit[length] = end << UInt64(32 - length)
            next_code = end << 1
            position += counts[length]
            length += 1
        self._symbols[EOS] = UInt16(EOS)
        symbol = 0
        while symbol < EOS:
            var size = Int(lengths[unsafe_offset=symbol])
            var slot = Int(self._offset[size]) + Int(
                codes[unsafe_offset=symbol] - self._first[size]
            )
            self._symbols[slot] = UInt16(symbol)
            symbol += 1

    @always_inline
    def _long_code(self, acc: UInt64) -> Tuple[Int, Int]:
        """Decode a code longer than the primary table holds.

        Args:
            acc: The input bits, aligned left.

        Returns:
            The code length and the symbol.
        """
        var word = acc >> 32
        var limits = self._limit.unsafe_ptr()
        var length = PRIMARY_BITS + 1
        while word >= limits[unsafe_offset=length]:
            length += 1
        var slot = Int(self._offset[length]) + Int(
            (word >> UInt64(32 - length)) - UInt64(self._first[length])
        )
        return (length, Int(self._symbols[slot]))

    def decode(self, data: Span[UInt8, _], mut out: List[UInt8]) -> Bool:
        """Append the bytes of a Huffman coded string to a buffer.

        Args:
            data: The code.
            out: The buffer; the bytes go at its end. On an error, its
                length is unchanged.

        Returns:
            False when the code has EOS, padding of 8 bits or more, or
            padding that is not all ones (RFC 7541 section 5.2).
        """
        var size = len(data)
        var source = data.unsafe_ptr()
        var start = len(out)
        # Every code is 5 bits or more.
        out.reserve(start + size * 8 // 5 + 1)
        var dst = out.unsafe_ptr()
        var written = start
        var primary = self._primary.unsafe_ptr()
        var acc: UInt64 = 0
        var bits = 0
        var position = 0
        while True:
            if position + 8 <= size:
                # Load 8 bytes, and count the whole bytes that fit. The
                # rest land below the count; the next load writes the same
                # bits over them.
                var word = byte_swap(
                    source.unsafe_offset(position)
                    .unsafe_bitcast[UInt64]()
                    .unsafe_load[alignment=1]()
                )
                acc |= word >> UInt64(bits)
                position += (63 - bits) >> 3
                bits |= 56
            else:
                while bits <= 56 and position < size:
                    var byte = UInt64(source[unsafe_offset=position])
                    acc |= byte << UInt64(56 - bits)
                    position += 1
                    bits += 8
            while bits >= PRIMARY_BITS:
                var entry = primary[unsafe_offset=Int(acc >> 53)]
                var length = Int(entry >> 8)
                var symbol = Int(entry & 0xFF)
                if entry == 0:
                    # The longest code is 30 bits: load more first.
                    if bits < EOS_LENGTH and position < size:
                        break
                    length, symbol = self._long_code(acc)
                    if length > bits or symbol == EOS:
                        return False
                dst[unsafe_offset=written] = UInt8(symbol)
                written += 1
                acc <<= UInt64(length)
                bits -= length
            if position >= size:
                break
        # The input is done, and fewer than 11 bits are left.
        while bits > 0:
            var ones = (UInt64(1) << UInt64(bits)) - 1
            if bits < 8 and (acc >> UInt64(64 - bits)) == ones:
                break
            var entry = primary[unsafe_offset=Int(acc >> 53)]
            var length = Int(entry >> 8)
            if entry == 0 or length > bits:
                return False
            dst[unsafe_offset=written] = UInt8(entry & 0xFF)
            written += 1
            acc <<= UInt64(length)
            bits -= length
        out.resize(unsafe_uninit_length=written)
        return True


def huffman_decode(data: Span[UInt8, _], mut out: List[UInt8]) -> Bool:
    """Append the bytes of a Huffman coded string to a buffer.

    This builds the tables for each call. A decoder of many strings holds
    one `HuffmanDecoder` instead.

    Args:
        data: The code.
        out: The buffer; the bytes go at its end.

    Returns:
        False when the code is not valid; see `HuffmanDecoder.decode`.
    """
    return HuffmanDecoder().decode(data, out)
