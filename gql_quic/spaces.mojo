# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Packet number spaces (RFC 9000 section 12.3) and sent packets.

A connection has three spaces: Initial, Handshake and application data.
`PacketSpace` holds the keys of a space, its next packet number, the
packets in flight, the packet numbers to acknowledge and the CRYPTO bytes
in both directions.

`SentPacket` records what a packet carried, as `SentFrame` values, so that
an acknowledgment releases the bytes and a loss queues them again
(RFC 9002 section 2: retransmission of information, not of packets).

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/connection/spaces.rs: `PacketSpace`, `SentPacket` and
`Retransmits` (MIT OR Apache-2.0, used under MIT).

Differences from upstream: quinn's `Retransmits` is a set of pending
frames per space, and its `SentPacket` holds one. Here a sent packet holds
a list of `SentFrame` records, and the connection turns a lost record back
into pending work. Duplicate packets are found with a `RangeSet` of every
received number instead of a sliding bit window.
"""

from gql_quic.assembler import Assembler
from gql_quic.crypto import KeyPair
from gql_quic.range_set import RangeSet
from gql_quic.send_buffer import SendBuffer


@fieldwise_init
struct SentFrame(Copyable, Movable):
    """What one frame of a sent packet carried; see `kind`."""

    var kind: UInt64
    """The frame type, as `FrameType.value`; STREAM frames use 0x08."""
    var id: UInt64
    """The stream id, or the sequence of RETIRE_CONNECTION_ID."""
    var offset: UInt64
    """The offset of STREAM and CRYPTO frames."""
    var length: UInt64
    """The length of STREAM and CRYPTO frames."""
    var fin: Bool
    """Whether a STREAM frame ended the stream."""
    var value: UInt64
    """The largest acknowledged number of an ACK frame, or the error code
    of RESET_STREAM and STOP_SENDING."""


struct SentPacket(Movable):
    """A packet that is in flight or waits for its acknowledgment."""

    var pn: UInt64
    """The packet number."""
    var time: Int
    """When it was sent."""
    var size: Int
    """Its size in bytes, for congestion control."""
    var ack_eliciting: Bool
    """Whether it asks for an acknowledgment."""
    var in_flight: Bool
    """Whether it counts in the bytes in flight."""
    var frames: List[SentFrame]
    """What it carried."""

    def __init__(out self, pn: UInt64, time: Int):
        """Start a record.

        Args:
            pn: The packet number.
            time: When it is sent.
        """
        self.pn = pn
        self.time = time
        self.size = 0
        self.ack_eliciting = False
        self.in_flight = False
        self.frames = List[SentFrame]()


struct PacketSpace(Movable):
    """One packet number space of a connection."""

    var keys: List[KeyPair]
    """The keys of the space: none until they are known, then one."""
    var next_pn: UInt64
    """The next packet number to send."""
    var largest_acked: Int64
    """The largest packet number that the peer acknowledged; -1 for none."""
    var sent: List[SentPacket]
    """The packets that wait for acknowledgment, in packet number order."""
    var ack_eliciting_in_flight: Int
    """The count of ack-eliciting packets in `sent` that are in flight."""
    var last_ack_eliciting: Int
    """When the last ack-eliciting packet was sent; -1 for never."""
    var loss_time: Int
    """When a packet that is not acknowledged yet is lost; -1 for none."""
    var seen: RangeSet
    """Every received packet number, to drop duplicates."""
    var pending_acks: RangeSet
    """The received numbers that the next ACK frame reports."""
    var rx_largest: Int64
    """The largest received packet number; -1 for none."""
    var rx_largest_time: Int
    """When the largest received packet arrived."""
    var unacked_eliciting: Int
    """The ack-eliciting packets received since this end last sent an
    ACK frame."""
    var immediate_ack: Bool
    """Whether an ACK frame must go out without delay."""
    var ack_deadline: Int
    """When a delayed ACK frame must go out; -1 for none."""
    var crypto_send: SendBuffer
    """The CRYPTO bytes of this space that this end sends."""
    var crypto_recv: Assembler
    """The CRYPTO bytes of this space that arrived."""
    var loss_probes: Int
    """The probe packets that a probe timeout asks for."""
    var ping_pending: Bool
    """Whether a PING frame must go out."""

    def __init__(out self):
        """Make a space without keys."""
        self.keys = List[KeyPair]()
        self.next_pn = 0
        self.largest_acked = -1
        self.sent = List[SentPacket]()
        self.ack_eliciting_in_flight = 0
        self.last_ack_eliciting = -1
        self.loss_time = -1
        self.seen = RangeSet()
        self.pending_acks = RangeSet()
        self.rx_largest = -1
        self.rx_largest_time = 0
        self.unacked_eliciting = 0
        self.immediate_ack = False
        self.ack_deadline = -1
        self.crypto_send = SendBuffer()
        self.crypto_recv = Assembler()
        self.loss_probes = 0
        self.ping_pending = False

    def has_keys(self) -> Bool:
        """Return True once the keys of the space are installed.

        Returns:
            Whether packets of this space can be sent and opened.
        """
        return len(self.keys) > 0

    def wants_ack(self, now: Int) -> Bool:
        """Return True when an ACK frame must go out now.

        Args:
            now: The current time.

        Returns:
            Whether an immediate ACK is due, or the delayed one has come.
        """
        if self.pending_acks.is_empty():
            return False
        return self.immediate_ack or (
            self.ack_deadline >= 0 and now >= self.ack_deadline
        )

    def find_sent(self, pn: UInt64) -> Int:
        """Return the index of a sent packet in `sent`, or -1.

        Args:
            pn: The packet number.

        Returns:
            The index, by binary search.
        """
        var low = 0
        var high = len(self.sent)
        while low < high:
            var middle = (low + high) // 2
            if self.sent[middle].pn < pn:
                low = middle + 1
            else:
                high = middle
        if low < len(self.sent) and self.sent[low].pn == pn:
            return low
        return -1

    def discard(mut self) -> Int:
        """Drop the keys and every packet in flight, when the space ends.

        Returns:
            The bytes in flight that the dropped packets held.
        """
        var bytes = 0
        for index in range(len(self.sent)):
            if self.sent[index].in_flight:
                bytes += self.sent[index].size
        self.sent.clear()
        self.keys.clear()
        self.ack_eliciting_in_flight = 0
        self.loss_time = -1
        self.loss_probes = 0
        self.ping_pending = False
        self.pending_acks.clear()
        self.immediate_ack = False
        self.ack_deadline = -1
        return bytes
