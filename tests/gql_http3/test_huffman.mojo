# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.huffman`.

Upstream: `h3/src/qpack/prefix_string/encode.rs` and `decode.rs` of
hyperium/h3 h3-v0.0.8 (`test_encode_single_value`,
`test_decode_single_value`, `test_encode_all_code_joined`,
`test_decode_all_code_joined`, `byte_count_exact_when_bit_count_multiple_of_8`
and `byte_`). The single-value tests are generated here from the code table
of RFC 7541 Appendix B. The string vectors are those of RFC 7541 Appendix
C.4 and C.6.
"""

from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.huffman import (
    EOS,
    huffman_code,
    huffman_decode,
    huffman_encode,
    huffman_encoded_length,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _hex(text: StaticString) -> List[UInt8]:
    """Read hex digits, with spaces between groups."""
    var out = List[UInt8]()
    var digits = List[Int]()
    for b in text.as_bytes():
        var c = Int(b)
        if c >= 48 and c <= 57:
            digits.append(c - 48)
        elif c >= 97 and c <= 102:
            digits.append(c - 87)
    var i = 0
    while i + 1 < len(digits):
        out.append(UInt8(digits[i] * 16 + digits[i + 1]))
        i += 2
    return out^


def _encode(text: StringSlice) -> List[UInt8]:
    var out = List[UInt8]()
    huffman_encode(text.as_bytes(), out)
    return out^


def _decode(data: List[UInt8]) raises -> String:
    var out = List[UInt8]()
    huffman_decode(Span(data), out)
    return String(unsafe_from_utf8=out)


def _error(data: List[UInt8]) raises -> String:
    var out = List[UInt8]()
    try:
        huffman_decode(Span(data), out)
    except e:
        assert_true(e.code == H3ErrorCode.QPACK_DECOMPRESSION_FAILED)
        return e.message.copy()
    return "no error"


def _vector(text: StaticString, wire: StaticString) raises:
    var expected = _hex(wire)
    var encoded = _encode(text)
    assert_true(encoded == expected, String(text))
    assert_equal(huffman_encoded_length(text.as_bytes()), len(expected))
    assert_equal(_decode(expected), String(text))


def test_rfc7541_vectors() raises:
    _vector("www.example.com", "f1e3 c2e5 f23a 6ba0 ab90 f4ff")
    _vector("no-cache", "a8eb 1064 9cbf")
    _vector("custom-key", "25a8 49e9 5ba9 7d7f")
    _vector("custom-value", "25a8 49e9 5bb8 e8b4 bf")
    _vector("302", "6402")
    _vector("private", "aec3 771a 4b")
    _vector(
        "Mon, 21 Oct 2013 20:13:21 GMT",
        "d07a be94 1054 d444 a820 0595 040b 8166 e082 a62d 1bff",
    )
    _vector(
        "https://www.example.com",
        "9d29 ad17 1863 c78f 0b97 c8e9 ae82 ae43 d3",
    )
    _vector("307", "640e ff")
    _vector("gzip", "9bd9 ab")
    _vector(
        "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1",
        (
            "94e7 821d d7f2 e6c7 b335 dfdf cd5b 3960 d5af 2708 7f36 72c1 ab27"
            " 0fb5 291f 9587 3160 65c0 03ed 4ee5 b106 3d50 07"
        ),
    )
    _vector("", "")


def test_code_is_canonical() raises:
    # Codes of one length are consecutive, in symbol order, and the first
    # code of a length follows the last code of the length before.
    var next_code = UInt64(0)
    var length = 5
    var previous = 5
    while length <= 30:
        var symbol = 0
        while symbol <= EOS:
            var code = huffman_code(symbol)
            if code[1] == length:
                next_code <<= UInt64(length - previous)
                previous = length
                assert_equal(UInt64(code[0]), next_code, String(symbol))
                next_code += 1
            symbol += 1
        length += 1
    assert_equal(next_code, UInt64(1) << 30)


def test_single_value() raises:
    # Each byte alone: its code, then ones up to the byte boundary.
    for symbol in range(256):
        var code = huffman_code(symbol)
        var bits = code[1]
        var size = (bits + 7) // 8
        var pad = size * 8 - bits
        var word = (UInt64(code[0]) << UInt64(pad)) | (
            (UInt64(1) << UInt64(pad)) - 1
        )
        var expected = List[UInt8]()
        var i = size - 1
        while i >= 0:
            expected.append(UInt8((word >> UInt64(i * 8)) & 0xFF))
            i -= 1
        var data = List[UInt8]()
        data.append(UInt8(symbol))
        var encoded = List[UInt8]()
        huffman_encode(Span(data), encoded)
        assert_true(encoded == expected, String(symbol))
        var decoded = List[UInt8]()
        huffman_decode(Span(encoded), decoded)
        assert_true(decoded == data, String(symbol))


def test_all_code_joined() raises:
    var values = List[UInt8]()
    for symbol in range(256):
        values.append(UInt8(symbol))
    var encoded = List[UInt8]()
    huffman_encode(Span(values), encoded)
    # The start and the end of upstream's expected bytes.
    var start = [0xFF, 0xC7, 0xFF, 0xFD, 0x8F, 0xFF, 0xFF, 0xE2]
    for i in range(len(start)):
        assert_equal(Int(encoded[i]), start[i], String(i))
    var end = [0xFF, 0xFF, 0xFB, 0xBF]
    for i in range(len(end)):
        assert_equal(Int(encoded[len(encoded) - 4 + i]), end[i], String(i))
    assert_equal(len(encoded), huffman_encoded_length(Span(values)))
    var decoded = List[UInt8]()
    huffman_decode(Span(encoded), decoded)
    assert_true(decoded == values)


def test_reencode_exact_byte_count() raises:
    var a = _hex("8c2d 4b70 ddf4 5abe fb40 05db")
    var text = _decode(a)
    var again = _encode(text)
    assert_true(again == a)
    var b = _hex("5592 beff 4836 cb86 373d 68ca c961 cede dce5 fc")
    again = _encode(_decode(b))
    assert_true(again == b)


def test_appends() raises:
    var out = List[UInt8]()
    out.append(7)
    huffman_encode(StaticString("a").as_bytes(), out)
    assert_equal(len(out), 2)
    var decoded = List[UInt8]()
    decoded.append(9)
    huffman_decode(Span(out)[1:], decoded)
    assert_equal(len(decoded), 2)
    assert_equal(Int(decoded[1]), 97)


def test_invalid() raises:
    # EOS, 30 ones, then padding.
    assert_equal(_error(_hex("ffff fffc")), "invalid Huffman encoding")
    # 'a' (00011), then 11 ones: padding longer than 7 bits.
    assert_equal(_error(_hex("1fff")), "invalid Huffman encoding")
    # 'a', then a full byte of ones.
    assert_equal(_error(_hex("1fff ff")), "invalid Huffman encoding")
    # Padding that is not ones: 'a' then 001.
    assert_equal(_error(_hex("19")), "invalid Huffman encoding")
    # A long code that the input cuts: the first byte of byte 0's code.
    assert_equal(_error(_hex("ff")), "invalid Huffman encoding")
    # '9' (011111), then two ones of padding.
    assert_equal(_decode(_hex("7f")), "9")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
