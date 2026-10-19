# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http2.huffman`: the Huffman code of RFC 7541.

Ports the tests of `src/hpack/huffman/mod.rs`, `encode.rs` and `decode.rs`
of hyperium/h2 v0.4.20. The random inputs come from a fixed xorshift
generator, in place of the seeded `StdRng` of h2. The reference decoder
reads one bit at a time, in place of the string prefix search of h2; it
gives the same results. The long random tests are split in parts, so each
part takes under 5 seconds under the coverage probes.
"""

from std.builtin.globals import global_constant
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_http2.huffman import (
    HuffmanDecoder,
    _CODES,
    _FAST,
    _FIRST,
    _LIMIT,
    _OFFSET,
    _SYMBOLS,
    _LENGTHS,
    huffman_decode,
    huffman_encode,
    huffman_encoded_length,
)


struct _Random(Movable):
    """A xorshift64* generator, so each run sees the same inputs."""

    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state ^= self.state >> 12
        self.state ^= self.state << 25
        self.state ^= self.state >> 27
        return self.state * 0x2545F4914F6CDD1D

    def below(mut self, bound: Int) -> Int:
        return Int(self.next() >> 33) % bound

    def byte(mut self) -> UInt8:
        return (self.next() >> 56).cast[DType.uint8]()


def _bytes(text: StringSlice) -> List[UInt8]:
    return List[UInt8](text.as_bytes())


def _encode(data: List[UInt8]) -> List[UInt8]:
    var out = List[UInt8]()
    huffman_encode(Span(data), out)
    return out^


def _decode(data: List[UInt8]) raises -> List[UInt8]:
    var out = List[UInt8]()
    if not huffman_decode(Span(data), out):
        raise Error("invalid Huffman code")
    return out^


def _try(
    decoder: HuffmanDecoder, data: List[UInt8], mut out: List[UInt8]
) -> Bool:
    return decoder.decode(Span(data), out)


def _round_trip(decoder: HuffmanDecoder, data: List[UInt8]) raises:
    var encoded = _encode(data)
    assert_equal(len(encoded), huffman_encoded_length(Span(data)))
    var decoded = List[UInt8]()
    assert_true(decoder.decode(Span(encoded), decoded))
    assert_true(decoded == data, "round trip of " + String(len(data)))


def _reference_decode(data: List[UInt8], mut out: List[UInt8]) -> Bool:
    """Decode one bit at a time; EOS is not a code here, as in h2."""
    var codes = global_constant[_CODES]().unsafe_ptr()
    var lengths = global_constant[_LENGTHS]().unsafe_ptr()
    var table = Dict[Int, Int]()
    for symbol in range(256):
        var key = (Int(lengths[unsafe_offset=symbol]) << 32) | Int(
            codes[unsafe_offset=symbol]
        )
        table[key] = symbol
    var code = 0
    var length = 0
    var all_ones = True
    for byte in data:
        for bit in range(7, -1, -1):
            var one = Int(byte >> UInt8(bit)) & 1
            code = (code << 1) | one
            length += 1
            all_ones = all_ones and one == 1
            var found = table.get((length << 32) | code)
            if found:
                out.append(UInt8(found.value()))
                code = 0
                length = 0
                all_ones = True
    return length < 8 and all_ones


def test_encode_decode_str() raises:
    var data: List[String] = [
        "hello world",
        ":method",
        ":scheme",
        ":authority",
        "yahoo.co.jp",
        "GET",
        "http",
        ":path",
        "/images/top/sp2/cmn/logo-ns-130528.png",
        "example.com",
        "hpack-test",
        "xxxxxxx1",
        (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:16.0)"
            " Gecko/20100101 Firefox/16.0"
        ),
        "accept",
        "Accept",
        "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "cookie",
        "B=76j09a189a6h4&b=3&s=0b",
        "TE",
        (
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi"
            " non bibendum libero. Etiam ultrices lorem ut."
        ),
    ]
    var decoder = HuffmanDecoder()
    for text in data:
        _round_trip(decoder, _bytes(text))


def test_encode_decode_u8() raises:
    var decoder = HuffmanDecoder()
    _round_trip(decoder, [0])
    _round_trip(decoder, [0, 0, 0])
    _round_trip(decoder, [0, 1, 2, 3, 4, 5])
    _round_trip(decoder, [255, 248])


def test_encode_decode_all_octets() raises:
    var source = List[UInt8]()
    for byte in range(256):
        source.append(UInt8(byte))
    assert_true(_decode(_encode(source)) == source)


def test_encode_decode_max_expansion() raises:
    # `0` has a 5-bit code, the shortest, so it expands the most.
    var decoder = HuffmanDecoder()
    var source = List[UInt8]()
    for _ in range(100):
        _round_trip(decoder, source)
        source.append(48)


def _random_lengths(seed: UInt64, first: Int, end: Int) raises:
    var random = _Random(seed)
    var decoder = HuffmanDecoder()
    for length in range(first, end):
        var source = List[UInt8](capacity=length)
        for _ in range(length):
            source.append(random.byte())
        _round_trip(decoder, source)


# h2 round-trips random strings of every length below 600 in one test. The
# lengths are split in four parts of about the same bytes, so each part
# takes under 5 seconds under the coverage probes too.
def test_encode_decode_random_0() raises:
    _random_lengths(0x123456789ABCDEF, 0, 300)


def test_encode_decode_random_1() raises:
    _random_lengths(0x123456789ABCDF0, 300, 424)


def test_encode_decode_random_2() raises:
    _random_lengths(0x123456789ABCDF1, 424, 519)


def test_encode_decode_random_3() raises:
    _random_lengths(0x123456789ABCDF2, 519, 600)


def test_encode_single_byte() raises:
    assert_true(_encode(_bytes("o")) == [0b00111111])
    assert_true(_encode(_bytes("0")) == [7])
    assert_true(_encode(_bytes("A")) == [(0x21 << 2) + 3])


def test_encode_rfc_example() raises:
    var expected: List[UInt8] = [
        0xF1,
        0xE3,
        0xC2,
        0xE5,
        0xF2,
        0x3A,
        0x6B,
        0xA0,
        0xAB,
        0x90,
        0xF4,
        0xFF,
    ]
    assert_true(_encode(_bytes("www.example.com")) == expected)
    assert_equal(huffman_encoded_length(Span(_bytes("www.example.com"))), 12)
    assert_equal(huffman_encoded_length(Span(List[UInt8]())), 0)


def test_encode_appends() raises:
    var out: List[UInt8] = [9]
    huffman_encode(Span(_bytes("o")), out)
    assert_true(out == [9, 0b00111111])
    huffman_encode(Span(List[UInt8]()), out)
    assert_equal(len(out), 2)


def test_decode_single_byte() raises:
    assert_true(_decode([0b00111111]) == _bytes("o"))
    assert_true(_decode([7]) == _bytes("0"))
    assert_true(_decode([(0x21 << 2) + 3]) == _bytes("A"))


def test_single_char_multi_byte() raises:
    assert_true(_decode([255, 160 + 15]) == _bytes("#"))
    assert_true(_decode([255, 200 + 7]) == _bytes("$"))
    assert_true(_decode([255, 255, 255, 240 + 3]) == [10])


def test_multi_char() raises:
    assert_true(_decode([254, 1]) == _bytes("!0"))
    assert_true(_decode([0b01010011, 0b11111000]) == _bytes(" !"))


def test_decode_appends() raises:
    var out: List[UInt8] = [9]
    var decoder = HuffmanDecoder()
    assert_true(_try(decoder, [7], out))
    assert_true(out == [9, 48])
    assert_false(_try(decoder, [0], out))
    assert_true(out == [9, 48])


def _check_reference(decoder: HuffmanDecoder, data: List[UInt8]) raises:
    var expected = List[UInt8]()
    var valid = _reference_decode(data, expected)
    var actual = List[UInt8]()
    assert_equal(decoder.decode(Span(data), actual), valid)
    if valid:
        assert_true(actual == expected)


def _arbitrary(seed: UInt64, high: UInt8) raises:
    var random = _Random(seed)
    var decoder = HuffmanDecoder()
    for _ in range(5_000):
        var length = random.below(40)
        var source = List[UInt8](capacity=length)
        for _ in range(length):
            source.append(random.byte() | high)
        _check_reference(decoder, source)


# h2 checks 10,000 random strings and 10,000 strings of high bytes in one
# test; here each set is two tests of 5,000, for the 5-second limit under
# the coverage probes.
def test_matches_reference_on_arbitrary_bytes_0() raises:
    _arbitrary(0xDEADBEEFCAFE, 0)


def test_matches_reference_on_arbitrary_bytes_1() raises:
    _arbitrary(0xDEADBEEFCAFF, 0)


def test_matches_reference_on_high_bytes_0() raises:
    # Bias toward high bytes, for long codes and EOS prefixes.
    _arbitrary(0xFEEDFACE0001, 0xE0)


def test_matches_reference_on_high_bytes_1() raises:
    _arbitrary(0xFEEDFACE0002, 0xE0)


def test_rejects_eos_and_invalid_padding() raises:
    var decoder = HuffmanDecoder()
    var out = List[UInt8]()
    assert_false(_try(decoder, [0xFF], out))
    assert_false(_try(decoder, [0xFF, 0xFF, 0xFF, 0xFF], out))
    assert_false(_try(decoder, [0], out))
    # EOS after a symbol, with 8 bytes or more so the fast load runs.
    var eos: List[UInt8] = [7, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    assert_false(decoder.decode(Span(eos), out))
    # 24 one bits: a prefix of a long code, cut off.
    assert_false(_try(decoder, [0xFF, 0xFF, 0xFF], out))
    assert_equal(len(out), 0)


def test_tables_match_the_code() raises:
    # Build the decoder tables from the code, as h2's `build_fast_table`
    # does, and compare them with the constants of the module.
    var codes = global_constant[_CODES]().unsafe_ptr()
    var lengths = global_constant[_LENGTHS]().unsafe_ptr()
    var fast = List[UInt32](length=4096, fill=0)
    for a in range(256):
        var len1 = Int(lengths[unsafe_offset=a])
        if len1 <= 12:
            var rem = 12 - len1
            var base = Int(codes[unsafe_offset=a]) << rem
            for i in range(1 << rem):
                fast[base + i] = UInt32((1 << 16) | (len1 << 24) | a)
    for a in range(256):
        var len1 = Int(lengths[unsafe_offset=a])
        if len1 + 5 > 12:
            continue
        var rem = 12 - len1
        for b in range(256):
            var len2 = Int(lengths[unsafe_offset=b])
            if len2 > rem:
                continue
            var rem2 = rem - len2
            var base = (Int(codes[unsafe_offset=a]) << rem) | (
                Int(codes[unsafe_offset=b]) << rem2
            )
            var pair = (2 << 16) | ((len1 + len2) << 24) | (b << 8) | a
            for i in range(1 << rem2):
                fast[base + i] = UInt32(pair)
    var table = global_constant[_FAST]().unsafe_ptr()
    for i in range(4096):
        assert_equal(table[unsafe_offset=i], fast[i], String(i))
    # The canonical tables: the codes of one length are consecutive.
    var counts = List[Int](length=31, fill=0)
    counts[30] = 1
    for symbol in range(256):
        counts[Int(lengths[unsafe_offset=symbol])] += 1
    var next_code = 0
    var position = 0
    var symbols = List[Int](length=257, fill=-1)
    symbols[256] = 256
    for length in range(1, 31):
        var first = global_constant[_FIRST]().unsafe_ptr()[unsafe_offset=length]
        var offset = global_constant[_OFFSET]().unsafe_ptr()[
            unsafe_offset=length
        ]
        var limit = global_constant[_LIMIT]().unsafe_ptr()[unsafe_offset=length]
        assert_equal(Int(first), next_code)
        assert_equal(Int(offset), position)
        assert_equal(Int(limit), (next_code + counts[length]) << (32 - length))
        for symbol in range(256):
            if Int(lengths[unsafe_offset=symbol]) == length:
                var code = Int(codes[unsafe_offset=symbol])
                assert_true(code >= next_code)
                assert_true(code < next_code + counts[length])
                symbols[position + code - next_code] = symbol
        next_code = (next_code + counts[length]) << 1
        position += counts[length]
    var known = global_constant[_SYMBOLS]().unsafe_ptr()
    for slot in range(257):
        assert_equal(Int(known[unsafe_offset=slot]), symbols[slot])


def test_decoder_copy() raises:
    var decoder = HuffmanDecoder()
    var copy = decoder.copy()
    var out = List[UInt8]()
    assert_true(copy.decode(Span(_encode(_bytes("copy"))), out))
    assert_true(out == _bytes("copy"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
