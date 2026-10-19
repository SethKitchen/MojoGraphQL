# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.qpack_prefix`.

Upstream: `h3/src/qpack/prefix_int.rs` (`codec_5_bits`, `codec_8_bits`,
`overflow`, `number_never_ends_with_0x80`, `overflow2`, `allow_62_bit`)
and `h3/src/qpack/prefix_string/mod.rs` (`codec_6`, `codec_8`,
`codec_8_empty`, `decode_non_huffman`, `decode_too_short`) of hyperium/h3
h3-v0.0.8. The `should_panic` tests of a size above 8 are not ported:
the size is a precondition here. The integer examples of RFC 7541 Appendix
C.1 are added.
"""

from gql_http3.error import H3ErrorCode
from gql_http3.qpack_prefix import (
    PrefixInt,
    decode_prefix_int,
    decode_prefix_string,
    encode_prefix_int,
    encode_prefix_string,
)
from gql_http3.varint import Progress
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _check_codec(
    size: Int, flags: UInt8, value: UInt64, data: List[UInt8]
) raises:
    var out = List[UInt8]()
    encode_prefix_int(size, flags, value, out)
    assert_true(out == data, String(value))
    var read = decode_prefix_int(size, Span(out), 0)
    assert_true(read.complete())
    assert_equal(read.flags, flags)
    assert_equal(read.value, value)
    assert_equal(read.end, len(data))


def _overflows(size: Int, data: List[UInt8]) raises -> Bool:
    try:
        _ = decode_prefix_int(size, Span(data), 0)
    except e:
        assert_true(e.code == H3ErrorCode.QPACK_DECOMPRESSION_FAILED)
        return True
    return False


def test_codec_5_bits() raises:
    _check_codec(5, 0b101, 10, [0b1010_1010])
    _check_codec(5, 0b101, 0, [0b1010_0000])
    _check_codec(5, 0b010, 1337, [0b0101_1111, 154, 10])
    _check_codec(5, 0b010, 31, [0b0101_1111, 0])
    _check_codec(
        5,
        0b010,
        0x80_00_00_00_00_00_00_1E,
        [95, 255, 255, 255, 255, 255, 255, 255, 255, 127],
    )


def test_codec_8_bits() raises:
    _check_codec(8, 0, 42, [0b0010_1010])
    _check_codec(8, 0, 424_242, [255, 179, 240, 25])
    _check_codec(
        8,
        0,
        0x80_00_00_00_00_00_00_FE,
        [255, 255, 255, 255, 255, 255, 255, 255, 255, 127],
    )


def test_rfc7541_c1() raises:
    # C.1.1, C.1.2 and C.1.3.
    _check_codec(5, 0, 10, [0x0A])
    _check_codec(5, 0, 1337, [0x1F, 0x9A, 0x0A])
    _check_codec(8, 0, 42, [0x2A])


def test_overflow() raises:
    assert_true(
        _overflows(
            8, [255, 128, 254, 255, 255, 255, 255, 255, 255, 255, 255, 1]
        )
    )
    assert_true(
        _overflows(5, [95, 225, 255, 255, 255, 255, 255, 255, 255, 255, 1])
    )


def test_number_never_ends_with_0x80() raises:
    _check_codec(4, 0b0001, 143, [31, 128, 1])


def test_allow_62_bit() raises:
    var buf: List[UInt8] = [3, 255, 255, 255, 255, 255, 255, 255, 255, 127]
    var read = decode_prefix_int(1, Span(buf), 0)
    assert_equal(read.flags, 1)
    assert_equal(read.value, 9223372036854775808)


def test_int_incomplete() raises:
    var empty = List[UInt8]()
    assert_false(decode_prefix_int(5, Span(empty), 0).complete())
    var cut: List[UInt8] = [0x1F, 0x9A]
    var read = decode_prefix_int(5, Span(cut), 0)
    assert_true(read.status == Progress.INCOMPLETE)
    assert_equal(read.end, 0)
    assert_equal(
        String(PrefixInt(Progress.COMPLETE, 1, 2, 3)), "complete flags 1 2 at 3"
    )


def _decode_string(size: Int, data: List[UInt8]) raises -> String:
    var out = List[UInt8]()
    var read = decode_prefix_string(size, Span(data), 0, out)
    assert_true(read.complete())
    assert_equal(read.end, len(data))
    assert_equal(Int(read.value), len(out))
    return String(unsafe_from_utf8=out)


def test_codec_6() raises:
    var buf = List[UInt8]()
    encode_prefix_string(
        6, 0b01, StaticString("name without ref").as_bytes(), buf
    )
    var expected: List[UInt8] = [
        0b0110_1100,
        168,
        116,
        149,
        79,
        6,
        76,
        231,
        181,
        42,
        88,
        89,
        127,
    ]
    assert_true(buf == expected)
    assert_equal(_decode_string(6, buf), "name without ref")


def test_codec_8() raises:
    var buf = List[UInt8]()
    encode_prefix_string(8, 0b01, StaticString("name with ref").as_bytes(), buf)
    var expected: List[UInt8] = [
        0b1000_1010,
        168,
        116,
        149,
        79,
        6,
        76,
        234,
        88,
        89,
        127,
    ]
    assert_true(buf == expected)
    assert_equal(_decode_string(8, buf), "name with ref")


def test_codec_8_empty() raises:
    # Upstream Huffman codes the empty string as 0x80; this port writes it
    # raw, as 0x00, and reads both.
    var buf = List[UInt8]()
    encode_prefix_string(8, 0b01, StaticString("").as_bytes(), buf)
    var expected: List[UInt8] = [0b0000_0000]
    assert_true(buf == expected)
    assert_equal(_decode_string(8, buf), "")
    assert_equal(_decode_string(8, [0b1000_0000]), "")


def test_raw_when_shorter() raises:
    # "{}" is 2 bytes raw and 2 bytes Huffman coded: it stays raw.
    var buf = List[UInt8]()
    encode_prefix_string(8, 0, StaticString("{}").as_bytes(), buf)
    var expected: List[UInt8] = [2, 123, 125]
    assert_true(buf == expected)
    assert_equal(_decode_string(8, buf), "{}")


def test_decode_non_huffman() raises:
    assert_equal(_decode_string(6, [0b0100_0011, 98, 97, 114]), "bar")


def test_decode_too_short() raises:
    var buf: List[UInt8] = [0b0100_0011, 98, 97]
    var out = List[UInt8]()
    var read = decode_prefix_string(6, Span(buf), 0, out)
    assert_false(read.complete())
    assert_equal(len(out), 0)
    var empty = List[UInt8]()
    assert_false(decode_prefix_string(6, Span(empty), 0, out).complete())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
