# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.shared`.

Upstream: quinn-proto 0.11.19 (8192ed3) quinn-proto/src/lib.rs has no unit
tests for `Side`, `Dir` and `StreamId`. The IDs are the examples of RFC
9000 section 2.1, table 1.
"""

from gql_quic.shared import Dir, Side, StreamId
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_side() raises:
    assert_true(Side.CLIENT.is_client())
    assert_false(Side.CLIENT.is_server())
    assert_true(Side.SERVER.is_server())
    assert_false(Side.SERVER.is_client())
    assert_true(Side.CLIENT.opposite() == Side.SERVER)
    assert_true(Side.SERVER.opposite() == Side.CLIENT)
    assert_true(Side.SERVER.is_valid())
    assert_false(Side(2).is_valid())
    assert_equal(String(Side.CLIENT), "client")
    assert_equal(String(Side.SERVER), "server")
    assert_equal(String(Side(2)), "invalid")
    assert_equal(hash(Side.CLIENT), hash(Side(0)))


def test_dir() raises:
    assert_true(Dir.BI.is_valid())
    assert_true(Dir.UNI.is_valid())
    assert_false(Dir(2).is_valid())
    assert_equal(String(Dir.BI), "bidirectional")
    assert_equal(String(Dir.UNI), "unidirectional")
    assert_equal(String(Dir(5)), "invalid")
    assert_equal(hash(Dir.UNI), hash(Dir(1)))


def test_stream_id() raises:
    # RFC 9000 table 1: the low two bits of the ID.
    assert_equal(StreamId(Side.CLIENT, Dir.BI, 0).value, 0)
    assert_equal(StreamId(Side.SERVER, Dir.BI, 0).value, 1)
    assert_equal(StreamId(Side.CLIENT, Dir.UNI, 0).value, 2)
    assert_equal(StreamId(Side.SERVER, Dir.UNI, 0).value, 3)
    var id = StreamId.new(Side.SERVER, Dir.UNI, 7)
    assert_equal(id.value, 31)
    assert_true(id.initiator() == Side.SERVER)
    assert_true(id.dir() == Dir.UNI)
    assert_equal(id.index(), 7)
    var other = StreamId(UInt64(4))
    assert_true(other.initiator() == Side.CLIENT)
    assert_true(other.dir() == Dir.BI)
    assert_equal(other.index(), 1)
    assert_equal(String(id), "server unidirectional stream 7")
    assert_equal(String(other), "client bidirectional stream 1")
    assert_true(id == StreamId(31))
    assert_true(id != other)
    var seen = Dict[StreamId, Int]()
    seen[id] = 1
    assert_true(StreamId(31) in seen)
    assert_false(other in seen)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
