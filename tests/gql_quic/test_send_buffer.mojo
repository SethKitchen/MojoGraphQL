# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.send_buffer`. The cases port quinn-proto 0.11.19
quinn-proto/src/connection/send_buffer.rs: `fragment_with_length`,
`multiple_segments`, `retransmit`, `ack` and `reordered_ack`. The
`poll_transmit` of this port takes the room for the bytes, not for the
frame, so the ranges hold no header. `fragment_without_length` and
`reserves_encoded_offset` test the header encoding that this port leaves
to the caller, and have no case. The other cases test the split of a lost
range, the move of the bytes after a large acknowledged prefix, and the
retransmission of a range that was acknowledged since."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_quic.range_set import Interval
from gql_quic.send_buffer import SendBuffer


def unacked(buf: SendBuffer) -> String:
    """Return the unacknowledged bytes as text."""
    return String(unsafe_from_utf8=buf.get(buf.base(), buf.offset))


def test_fragment() raises:
    var buf = SendBuffer()
    var msg = "Hello, world!"
    buf.write(msg.as_bytes())
    assert_true(buf.has_unsent_data())
    assert_equal(buf.poll_transmit(8), Interval(0, 8))
    assert_equal(buf.poll_transmit(8), Interval(8, 13))
    assert_equal(buf.poll_transmit(8), Interval(13, 13))
    assert_false(buf.has_unsent_data())
    assert_equal(buf.buffered(), 13)


def test_multiple_segments() raises:
    var buf = SendBuffer()
    buf.write("ABCDEFGHIJKLMNOPQRSTUVWXYZ".as_bytes())
    buf.write("0123456789".as_bytes())
    buf.write("abcdefghijklmnopqrstuvwxyz".as_bytes())
    assert_equal(buf.offset, 62)
    assert_equal(buf.poll_transmit(30), Interval(0, 30))
    assert_equal(String(unsafe_from_utf8=buf.get(24, 30)), "YZ0123")
    assert_equal(buf.poll_transmit(40), Interval(30, 62))
    buf.ack(0, 26)
    assert_equal(buf.base(), 26)
    assert_equal(unacked(buf), "0123456789abcdefghijklmnopqrstuvwxyz")
    buf.ack(26, 36)
    assert_equal(unacked(buf), "abcdefghijklmnopqrstuvwxyz")
    buf.ack(36, 62)
    assert_true(buf.is_fully_acked())
    assert_equal(unacked(buf), "")
    assert_equal(buf.buffered(), 0)


def test_retransmit() raises:
    var buf = SendBuffer()
    var msg = "Hello, world with extra data!"
    buf.write(msg.as_bytes())
    # Transmit two frames.
    assert_equal(buf.poll_transmit(16), Interval(0, 16))
    assert_equal(buf.poll_transmit(7), Interval(16, 23))
    # Lose the first, but not the second.
    buf.retransmit(0, 16)
    assert_true(buf.has_unsent_data())
    # Only the lost frame goes again, then the new bytes.
    assert_equal(buf.poll_transmit(16), Interval(0, 16))
    assert_equal(buf.poll_transmit(16), Interval(23, 29))
    # Lose the second frame.
    buf.retransmit(16, 23)
    assert_equal(buf.poll_transmit(16), Interval(16, 23))
    assert_false(buf.has_unsent_data())


def test_retransmit_split() raises:
    var buf = SendBuffer()
    buf.write("0123456789abcdef".as_bytes())
    assert_equal(buf.poll_transmit(16), Interval(0, 16))
    buf.retransmit(2, 12)
    # A lost range larger than the room goes in two parts.
    assert_equal(buf.poll_transmit(4), Interval(2, 6))
    assert_equal(String(unsafe_from_utf8=buf.get(2, 6)), "2345")
    assert_equal(buf.poll_transmit(100), Interval(6, 12))
    assert_equal(buf.poll_transmit(100), Interval(16, 16))


def test_retransmit_acked() raises:
    var buf = SendBuffer()
    buf.write("0123456789".as_bytes())
    _ = buf.poll_transmit(10)
    buf.ack(0, 4)
    buf.ack(6, 8)
    # A range below the first unacknowledged byte needs nothing.
    buf.retransmit(0, 4)
    assert_false(buf.has_unsent_data())
    # The acknowledged parts of a lost range do not go again.
    buf.retransmit(2, 10)
    assert_equal(buf.poll_transmit(100), Interval(4, 6))
    assert_equal(buf.poll_transmit(100), Interval(8, 10))
    assert_false(buf.has_unsent_data())


def test_ack() raises:
    var buf = SendBuffer()
    var msg = "Hello, world!"
    buf.write(msg.as_bytes())
    assert_equal(buf.poll_transmit(8), Interval(0, 8))
    buf.ack(0, 8)
    assert_equal(unacked(buf), "orld!")
    assert_false(buf.is_fully_acked())
    # An acknowledgment below the base changes nothing.
    buf.ack(0, 4)
    assert_equal(buf.base(), 8)


def test_reordered_ack() raises:
    var buf = SendBuffer()
    var msg = "Hello, world with extra data!"
    buf.write(msg.as_bytes())
    assert_equal(buf.poll_transmit(16), Interval(0, 16))
    assert_equal(buf.poll_transmit(7), Interval(16, 23))
    buf.ack(16, 23)
    assert_equal(unacked(buf), msg)
    buf.ack(0, 16)
    assert_equal(unacked(buf), " data!")
    assert_true(buf.acks.is_empty())


def test_compact() raises:
    var buf = SendBuffer()
    var data = List[UInt8](capacity=200000)
    for index in range(200000):
        data.append(UInt8(index % 251))
    buf.write(data)
    _ = buf.poll_transmit(200000)
    # A large prefix that is less than half of the buffer stays.
    buf.ack(0, 70000)
    assert_equal(buf.head, 70000)
    assert_equal(len(buf.data), 200000)
    # A large prefix that is half of the buffer or more moves out.
    buf.ack(70000, 110000)
    assert_equal(buf.head, 0)
    assert_equal(len(buf.data), 90000)
    assert_equal(buf.base(), 110000)
    assert_equal(buf.buffered(), 90000)
    var got = buf.get(110000, 110002)
    assert_equal(got[0], UInt8(110000 % 251))
    assert_equal(got[1], UInt8(110001 % 251))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
