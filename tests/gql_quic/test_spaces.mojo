# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.spaces`. The cases follow quinn-proto 0.11.19
quinn-proto/src/connection/spaces.rs: `pending_acks_after_immediate_ack_set`
and `pending_acks_ack_delay` become `test_wants_ack`. The `Dedup` cases
(`sanity`, `happypath`, `jump`, `dedup_*`) test the sliding bit window
that this port replaces with a `RangeSet`, which `test_range_set.mojo`
tests; `test_seen` checks the use here. `sent_packet_size` checks a Rust
type size and has no case. The other cases test `find_sent` and
`discard`."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_quic.spaces import PacketSpace, SentFrame, SentPacket


def space_with(pns: List[UInt64]) -> PacketSpace:
    """Make a space with sent packets of the given numbers."""
    var space = PacketSpace()
    for index in range(len(pns)):
        var packet = SentPacket(pns[index], 10 * index)
        packet.size = 100 + index
        packet.in_flight = index % 2 == 0
        space.sent.append(packet^)
    return space^


def test_new_space() raises:
    var space = PacketSpace()
    assert_false(space.has_keys())
    assert_equal(space.next_pn, 0)
    assert_equal(space.largest_acked, -1)
    assert_equal(space.rx_largest, -1)
    assert_equal(space.loss_time, -1)
    assert_true(space.crypto_send.is_fully_acked())
    assert_equal(space.crypto_recv.readable(), 0)


def test_sent_packet() raises:
    var packet = SentPacket(7, 1000)
    assert_equal(packet.pn, 7)
    assert_equal(packet.time, 1000)
    assert_equal(packet.size, 0)
    assert_false(packet.ack_eliciting)
    assert_false(packet.in_flight)
    packet.frames.append(SentFrame(0x08, 4, 0, 10, True, 0))
    assert_equal(len(packet.frames), 1)
    assert_true(packet.frames[0].fin)
    assert_equal(packet.frames[0].length, 10)


def test_wants_ack() raises:
    var space = PacketSpace()
    space.immediate_ack = True
    # Nothing to acknowledge.
    assert_false(space.wants_ack(0))
    _ = space.pending_acks.insert_one(0)
    assert_true(space.wants_ack(0))
    space.immediate_ack = False
    # No deadline yet.
    assert_false(space.wants_ack(100))
    space.ack_deadline = 50
    assert_false(space.wants_ack(49))
    assert_true(space.wants_ack(50))
    assert_true(space.wants_ack(51))


def test_seen() raises:
    var space = PacketSpace()
    assert_true(space.seen.insert_one(0))
    assert_true(space.seen.insert_one(2))
    # A duplicate is found.
    assert_false(space.seen.insert_one(2))
    assert_true(space.seen.insert_one(1))
    assert_equal(space.seen.len(), 1)


def test_find_sent() raises:
    var empty = PacketSpace()
    assert_equal(empty.find_sent(0), -1)
    var pns = List[UInt64]()
    pns.append(1)
    pns.append(3)
    pns.append(4)
    pns.append(8)
    pns.append(9)
    var space = space_with(pns)
    assert_equal(space.find_sent(1), 0)
    assert_equal(space.find_sent(3), 1)
    assert_equal(space.find_sent(4), 2)
    assert_equal(space.find_sent(8), 3)
    assert_equal(space.find_sent(9), 4)
    # Below, between and above the numbers in flight.
    assert_equal(space.find_sent(0), -1)
    assert_equal(space.find_sent(5), -1)
    assert_equal(space.find_sent(10), -1)


def test_discard() raises:
    var pns = List[UInt64]()
    pns.append(0)
    pns.append(1)
    pns.append(2)
    var space = space_with(pns)
    space.ack_eliciting_in_flight = 2
    space.loss_time = 30
    space.loss_probes = 2
    space.ping_pending = True
    _ = space.pending_acks.insert_one(5)
    space.immediate_ack = True
    space.ack_deadline = 40
    # Packets 0 and 2 are in flight: 100 + 102 bytes.
    assert_equal(space.discard(), 202)
    assert_equal(len(space.sent), 0)
    assert_false(space.has_keys())
    assert_equal(space.ack_eliciting_in_flight, 0)
    assert_equal(space.loss_time, -1)
    assert_equal(space.loss_probes, 0)
    assert_false(space.ping_pending)
    assert_true(space.pending_acks.is_empty())
    assert_false(space.immediate_ack)
    assert_equal(space.ack_deadline, -1)
    # A space without packets holds no bytes.
    assert_equal(space.discard(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
