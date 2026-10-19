# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.varint`.

Upstream: quinn-proto 0.11.19 (8192ed3) quinn-proto/src/varint.rs and
quinn-proto/src/coding.rs have no unit tests. The vectors are the examples
of RFC 9000 Appendix A.1.
"""


from gql_quic.varint import (
    VARINT_MAX,
    patch_varint_2,
    read_be,
    read_varint,
    reserve_tail,
    unexpected_end,
    varint_size,
    write_bytes,
    write_u8,
    write_u16,
    write_u32,
    write_u64,
    write_varint,
    write_varint_2,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(UInt8(v))
    return out^


def _check(value: UInt64, wire: List[UInt8]) raises:
    var out = List[UInt8]()
    write_varint(out, value)
    assert_true(out == wire, String(value))
    var pos = 0
    assert_equal(read_varint(Span(wire), pos), value)
    assert_equal(pos, len(wire))
    assert_equal(varint_size(value), len(wire))


def test_rfc9000_examples() raises:
    _check(
        151288809941952652,
        _bytes(0xC2, 0x19, 0x7C, 0x5E, 0xFF, 0x14, 0xE8, 0x8C),
    )
    _check(494878333, _bytes(0x9D, 0x7F, 0x3E, 0x7D))
    _check(15293, _bytes(0x7B, 0xBD))
    _check(37, _bytes(0x25))
    var long = _bytes(0x40, 0x25)
    var pos = 0
    assert_equal(read_varint(Span(long), pos), 37)
    assert_equal(pos, 2)


def test_boundaries() raises:
    _check(0, _bytes(0))
    _check(63, _bytes(0x3F))
    _check(64, _bytes(0x40, 0x40))
    _check(16383, _bytes(0x7F, 0xFF))
    _check(16384, _bytes(0x80, 0, 0x40, 0))
    _check(1073741823, _bytes(0xBF, 0xFF, 0xFF, 0xFF))
    _check(1073741824, _bytes(0xC0, 0, 0, 0, 0x40, 0, 0, 0))
    _check(VARINT_MAX, _bytes(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF))


def _read_error(data: List[UInt8], mut pos: Int) -> String:
    try:
        _ = read_varint(Span(data), pos)
    except e:
        return String(e)
    return "no error"


def _be_error(data: List[UInt8], mut pos: Int, size: Int) -> String:
    try:
        _ = read_be(Span(data), pos, size)
    except e:
        return String(e)
    return "no error"


def test_truncated() raises:
    var end = "FRAME_ENCODING_ERROR: unexpected end"
    var empty = List[UInt8]()
    var pos = 0
    assert_equal(_read_error(empty, pos), end)
    var short = _bytes(0x00, 0x80, 0x01, 0x02)
    pos = 1
    assert_equal(_read_error(short, pos), end)
    assert_equal(pos, 1)
    pos = 0
    assert_equal(_read_error(short, pos), "no error")
    pos = 0
    assert_equal(read_varint(Span(short), pos), 0)
    assert_equal(pos, 1)
    assert_equal(
        String(unexpected_end()), "FRAME_ENCODING_ERROR: unexpected end"
    )


def test_two_byte_form() raises:
    var out = List[UInt8]()
    write_varint_2(out, 5)
    assert_true(out == _bytes(0x40, 0x05))
    write_varint_2(out, 0)
    patch_varint_2(out, 2, 16383)
    assert_true(out == _bytes(0x40, 0x05, 0x7F, 0xFF))
    var pos = 2
    assert_equal(read_varint(Span(out), pos), 16383)


def test_fixed_size() raises:
    var out = List[UInt8]()
    write_u8(out, 0xAB)
    write_u16(out, 0x1234)
    write_u32(out, 0x89ABCDEF)
    write_u64(out, 0x0102030405060708)
    write_bytes(out, Span(_bytes(9, 10)))
    assert_equal(len(out), 17)
    var pos = 0
    assert_equal(read_be(Span(out), pos, 1), 0xAB)
    assert_equal(read_be(Span(out), pos, 2), 0x1234)
    assert_equal(read_be(Span(out), pos, 4), 0x89ABCDEF)
    assert_equal(read_be(Span(out), pos, 8), 0x0102030405060708)
    assert_equal(pos, 15)
    assert_equal(_be_error(out, pos, 4), "FRAME_ENCODING_ERROR: unexpected end")
    assert_equal(pos, 15)


def test_reserve_tail() raises:
    var out = List[UInt8](capacity=16)
    var at = reserve_tail(out, 4)
    assert_equal(at, 0)
    assert_equal(len(out), 4)
    at = reserve_tail(out, 100)
    assert_equal(at, 4)
    assert_equal(len(out), 104)
    assert_true(out.capacity() >= 104)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
