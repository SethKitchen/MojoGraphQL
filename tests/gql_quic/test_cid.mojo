# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.cid`.

Upstream: quinn-proto 0.11.19 (8192ed3) quinn-proto/src/cid_generator.rs
has one test, `validate_keyed_cid`, for the hashed generator, which is not
ported. quinn-proto/src/shared.rs has no unit tests. These tests check the
random generator, equality, hashing and the hexadecimal form.
"""

from gql_quic.cid import (
    MAX_CID_SIZE,
    RESET_TOKEN_SIZE,
    ConnectionId,
    ResetToken,
    fill_random,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(UInt8(v))
    return out^


def test_from_bytes() raises:
    var data = _bytes(0xDE, 0xAD, 0xBE, 0xEF)
    var cid = ConnectionId(Span(data))
    assert_equal(cid.len(), 4)
    assert_equal(len(cid), 4)
    assert_equal(cid[0], 0xDE)
    assert_equal(cid[3], 0xEF)
    assert_true(cid.bytes() == Span(data))
    assert_equal(String(cid), "deadbeef")
    assert_equal(String(ConnectionId()), "")
    assert_equal(ConnectionId().len(), 0)
    var long = List[UInt8](length=25, fill=7)
    assert_equal(ConnectionId(Span(long)).len(), MAX_CID_SIZE)


def test_equality() raises:
    var a = ConnectionId(Span(_bytes(1, 2, 3)))
    var b = ConnectionId(Span(_bytes(1, 2, 3)))
    var c = ConnectionId(Span(_bytes(1, 2, 4)))
    var d = ConnectionId(Span(_bytes(1, 2, 3, 0)))
    assert_true(a == b)
    assert_true(a != c)
    assert_true(a != d)
    var full = List[UInt8](length=20, fill=9)
    var e = ConnectionId(Span(full))
    full[19] = 8
    assert_true(e != ConnectionId(Span(full)))
    full[19] = 9
    full[10] = 1
    assert_true(e != ConnectionId(Span(full)))
    assert_true(ConnectionId() == ConnectionId(Span(List[UInt8]())))


def test_dict_key() raises:
    var seen = Dict[ConnectionId, Int]()
    seen[ConnectionId(Span(_bytes(1, 2, 3)))] = 5
    assert_equal(seen[ConnectionId(Span(_bytes(1, 2, 3)))], 5)
    assert_false(ConnectionId(Span(_bytes(1, 2))) in seen)


def test_random() raises:
    var a = ConnectionId.random(8)
    var b = ConnectionId.random(8)
    assert_equal(a.len(), 8)
    assert_true(a != b)
    assert_equal(ConnectionId.random(0).len(), 0)
    assert_equal(ConnectionId.random(-3).len(), 0)
    assert_equal(ConnectionId.random(40).len(), MAX_CID_SIZE)
    assert_equal(String(a).byte_length(), 16)


def test_encode_long() raises:
    var out = List[UInt8]()
    ConnectionId(Span(_bytes(0xAA, 0xBB))).encode_long(out)
    assert_true(out == _bytes(2, 0xAA, 0xBB))


def test_fill_random() raises:
    var buf = List[UInt8](length=600, fill=0)
    fill_random(buf.unsafe_ptr(), 600)
    var zeros = 0
    for b in buf:
        if b == 0:
            zeros += 1
    assert_true(zeros < 30)
    fill_random(buf.unsafe_ptr(), 0)


def test_reset_token() raises:
    var data = List[UInt8](length=16, fill=0)
    for i in range(16):
        data[i] = UInt8(i)
    var t = ResetToken(Span(data))
    assert_equal(t[15], 15)
    assert_equal(len(t.bytes()), RESET_TOKEN_SIZE)
    assert_equal(String(t), "000102030405060708090a0b0c0d0e0f")
    assert_true(t == ResetToken(Span(data)))
    data[15] = 0
    assert_true(t != ResetToken(Span(data)))
    data[15] = 15
    data[0] = 1
    assert_true(t != ResetToken(Span(data)))
    assert_true(ResetToken() == ResetToken(Span(_bytes(0, 0))))
    assert_true(ResetToken.random() != ResetToken.random())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
