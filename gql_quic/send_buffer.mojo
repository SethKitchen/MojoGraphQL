# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The bytes of a stream or of CRYPTO frames that wait for acknowledgment.

`SendBuffer` keeps every byte from the first unacknowledged offset to the
last written one. `poll_transmit` gives the next range to send: lost
ranges first, then new bytes. `ack` drops acknowledged bytes from the
front, and `retransmit` queues a lost range again.

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/connection/send_buffer.rs (MIT OR Apache-2.0, used under
MIT).

Differences from upstream: quinn keeps a queue of `Bytes` segments. Here
the bytes are in one `List[UInt8]` with a read head, which moves the bytes
down once the acknowledged prefix is large. `poll_transmit` returns the
range only; `encode_length` is the caller's choice.
"""

from gql_quic.range_set import Interval, RangeSet


struct SendBuffer(Movable):
    """The unacknowledged bytes of one stream or one CRYPTO space."""

    var data: List[UInt8]
    """The bytes from `base()`, after `head` bytes that are acknowledged."""
    var head: Int
    """The count of acknowledged bytes at the front of `data`."""
    var offset: UInt64
    """The offset after the last written byte."""
    var unsent: UInt64
    """The offset of the first byte never sent."""
    var acks: RangeSet
    """The acknowledged ranges above `base()`."""
    var retransmits: RangeSet
    """The ranges to send again."""

    def __init__(out self):
        """Make an empty buffer."""
        self.data = List[UInt8]()
        self.head = 0
        self.offset = 0
        self.unsent = 0
        self.acks = RangeSet()
        self.retransmits = RangeSet()

    def base(self) -> UInt64:
        """Return the offset of the first unacknowledged byte.

        Returns:
            The offset.
        """
        return self.offset - UInt64(len(self.data) - self.head)

    def write(mut self, data: Span[UInt8, _]):
        """Append bytes after the last written one.

        Args:
            data: The bytes.
        """
        self.data.extend(data)
        self.offset += UInt64(len(data))

    def ack(mut self, start: UInt64, end: UInt64):
        """Mark a range as acknowledged, and drop the acknowledged prefix.

        Args:
            start: The first offset.
            end: The offset after the range.
        """
        var base = self.base()
        _ = self.acks.insert(max(base, start), max(base, end))
        while True:
            var low = self.acks.peek_min()
            if not low or low.value().start != self.base():
                break
            var prefix = self.acks.pop_min().value()
            self.head += Int(prefix.end - prefix.start)
        if self.head == len(self.data):
            self.data.clear()
            self.head = 0
        elif self.head >= 65536 and self.head * 2 >= len(self.data):
            var rest = List[UInt8](self.data[self.head :])
            self.data = rest^
            self.head = 0

    def poll_transmit(mut self, max_len: Int) -> Interval:
        """Take the next range to send: a lost range, else new bytes.

        Args:
            max_len: The most bytes to take.

        Returns:
            The range; empty when nothing waits.
        """
        var lost = self.retransmits.pop_min()
        if lost:
            var range = lost.value()
            var end = min(range.end, range.start + UInt64(max_len))
            if end != range.end:
                _ = self.retransmits.insert(end, range.end)
            return Interval(range.start, end)
        var end = min(self.offset, self.unsent + UInt64(max_len))
        var result = Interval(self.unsent, end)
        self.unsent = end
        return result

    def get(self, start: UInt64, end: UInt64) -> Span[UInt8, origin_of(self.data)]:
        """Return the bytes of a range that is not acknowledged yet.

        Args:
            start: The first offset, at least `base()`.
            end: The offset after the range, at most `offset`.

        Returns:
            The bytes.
        """
        var at = self.head + Int(start - self.base())
        return Span(self.data)[at : at + Int(end - start)]

    def retransmit(mut self, start: UInt64, end: UInt64):
        """Queue a lost range to send again.

        Args:
            start: The first offset.
            end: The offset after the range.
        """
        var base = self.base()
        if end <= base:
            return
        _ = self.retransmits.insert(max(start, base), end)
        # Ranges that were acknowledged since need no retransmission.
        self.retransmits.subtract(self.acks)

    def is_fully_acked(self) -> Bool:
        """Return True when every written byte is acknowledged.

        Returns:
            Whether nothing waits for an acknowledgment.
        """
        return self.head == len(self.data)

    def has_unsent_data(self) -> Bool:
        """Return True when bytes wait to be sent or sent again.

        Returns:
            Whether `poll_transmit` gives a range.
        """
        return self.unsent != self.offset or not self.retransmits.is_empty()

    def buffered(self) -> Int:
        """Return the count of unacknowledged bytes in the buffer.

        Returns:
            Bytes.
        """
        return len(self.data) - self.head
