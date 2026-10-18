# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.varint` and `gql_http3.error`.

Upstream: `h3/src/proto/varint.rs` and `h3/src/error/codes.rs` of
hyperium/h3 h3-v0.0.8 have no unit tests. The vectors are the examples of
RFC 9000 Appendix A.1.
"""

from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.varint import (
    VARINT_MAX,
    Progress,
    VarInt,
    decode_varint,
    encode_varint,
    encoded_size,
    is_varint,
    varint_size,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(UInt8(v))
    return out^


def _check(value: UInt64, wire: List[UInt8]) raises:
    var out = List[UInt8]()
    encode_varint(value, out)
    assert_true(out == wire, String(value))
    var read = decode_varint(Span(wire), 0)
    assert_true(read.complete())
    assert_equal(read.value, value)
    assert_equal(read.end, len(wire))
    assert_equal(varint_size(value), len(wire))
    assert_equal(encoded_size(wire[0]), len(wire))


def test_rfc9000_examples() raises:
    _check(
        151288809941952652,
        _bytes(0xC2, 0x19, 0x7C, 0x5E, 0xFF, 0x14, 0xE8, 0x8C),
    )
    _check(494878333, _bytes(0x9D, 0x7F, 0x3E, 0x7D))
    _check(15293, _bytes(0x7B, 0xBD))
    _check(37, _bytes(0x25))
    # A two-byte encoding of 37 decodes too.
    var long = _bytes(0x40, 0x25)
    var read = decode_varint(Span(long), 0)
    assert_equal(read.value, 37)
    assert_equal(read.end, 2)


def test_boundaries() raises:
    _check(0, _bytes(0))
    _check(63, _bytes(0x3F))
    _check(64, _bytes(0x40, 0x40))
    _check(16383, _bytes(0x7F, 0xFF))
    _check(16384, _bytes(0x80, 0, 0x40, 0))
    _check(1073741823, _bytes(0xBF, 0xFF, 0xFF, 0xFF))
    _check(1073741824, _bytes(0xC0, 0, 0, 0, 0x40, 0, 0, 0))
    _check(VARINT_MAX, _bytes(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF))
    assert_true(is_varint(VARINT_MAX))
    assert_false(is_varint(VARINT_MAX + 1))


def test_incomplete() raises:
    var empty = List[UInt8]()
    var read = decode_varint(Span(empty), 0)
    assert_false(read.complete())
    assert_equal(read.end, 0)
    var short = _bytes(0x00, 0x80, 0x01, 0x02)
    read = decode_varint(Span(short), 1)
    assert_true(read.status == Progress.INCOMPLETE)
    assert_equal(read.end, 1)
    read = decode_varint(Span(short), 0)
    assert_equal(read.value, 0)
    assert_equal(read.end, 1)
    assert_equal(String(VarInt(Progress.COMPLETE, 5, 1)), "complete 5 at 1")


def test_progress() raises:
    assert_true(Progress.COMPLETE.is_valid())
    assert_true(Progress.INCOMPLETE.is_valid())
    assert_false(Progress(2).is_valid())
    assert_equal(String(Progress.COMPLETE), "complete")
    assert_equal(String(Progress.INCOMPLETE), "incomplete")
    assert_equal(String(Progress(9)), "invalid")


def test_error_codes() raises:
    assert_equal(H3ErrorCode.H3_NO_ERROR.value, 0x100)
    assert_equal(H3ErrorCode.H3_VERSION_FALLBACK.value, 0x110)
    assert_equal(H3ErrorCode.QPACK_DECODER_STREAM_ERROR.value, 0x202)
    for v in [0x100, 0x10A, 0x110, 0x200, 0x202]:
        assert_true(H3ErrorCode(UInt64(v)).is_valid(), String(v))
    for v in [0, 0xFF, 0x111, 0x150, 0x1FF, 0x203, 0x300]:
        assert_false(H3ErrorCode(UInt64(v)).is_valid(), String(v))
    assert_equal(String(H3ErrorCode.H3_NO_ERROR), "H3_NO_ERROR")
    assert_equal(String(H3ErrorCode.H3_FRAME_ERROR), "H3_FRAME_ERROR")
    assert_equal(
        String(H3ErrorCode.QPACK_ENCODER_STREAM_ERROR),
        "QPACK_ENCODER_STREAM_ERROR",
    )
    assert_equal(String(H3ErrorCode(7)), "invalid")
    var e = H3Error(H3ErrorCode.H3_ID_ERROR, "bad id")
    assert_equal(String(e), "H3_ID_ERROR: bad id")
    assert_true(e.code == H3ErrorCode.H3_ID_ERROR)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
