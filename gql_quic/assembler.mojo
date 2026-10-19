# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The reassembly of the bytes of a stream or of CRYPTO frames.

Frames can arrive out of order and overlap. `Assembler.insert` puts the
bytes of a frame at their offset, and `read` gives the bytes in order,
from the first one not read to the first gap.

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/connection/assembler.rs (MIT OR Apache-2.0, used under
MIT).

Differences from upstream: quinn keeps a heap of received chunks, and
can read out of order. Here the bytes go into one buffer that starts at
the first unread offset, and a `RangeSet` records which offsets arrived;
reads are in order only. Flow control bounds the buffer.
"""

from gql_quic.range_set import RangeSet


struct Assembler(Movable):
    """The received bytes of one stream or one CRYPTO space."""

    var data: List[UInt8]
    """The bytes from `bytes_read`, after `head` bytes that were read."""
    var head: Int
    """The count of bytes at the front of `data` that were read."""
    var bytes_read: UInt64
    """The offset of the first byte not read yet."""
    var received: RangeSet
    """The offsets at or above `bytes_read` that arrived."""

    def __init__(out self):
        """Make an empty assembler."""
        self.data = List[UInt8]()
        self.head = 0
        self.bytes_read = 0
        self.received = RangeSet()

    def insert(mut self, offset: UInt64, data: Span[UInt8, _]):
        """Add the bytes of a frame.

        Args:
            offset: The offset of the first byte.
            data: The bytes; those already read are dropped.
        """
        var end = offset + UInt64(len(data))
        if end <= self.bytes_read:
            return
        var skip = (
            Int(self.bytes_read - offset) if offset < self.bytes_read else 0
        )
        var start = offset + UInt64(skip)
        var at = self.head + Int(start - self.bytes_read)
        var need = at + len(data) - skip
        if need > len(self.data):
            self.data.resize(need, 0)
        var p = self.data.unsafe_ptr()
        var q = data.unsafe_ptr()
        for index in range(len(data) - skip):
            p[unsafe_offset=at + index] = q[unsafe_offset=skip + index]
        _ = self.received.insert(start, end)

    def readable(self) -> Int:
        """Return the count of bytes that `read` can give now.

        Returns:
            The bytes from `bytes_read` to the first gap.
        """
        var low = self.received.peek_min()
        if not low or low.value().start != self.bytes_read:
            return 0
        return Int(low.value().end - self.bytes_read)

    def read(mut self, dest: Pointer[mut=True, UInt8, _], size: Int) -> Int:
        """Copy bytes in order into a buffer.

        Args:
            dest: The buffer.
            size: Its size.

        Returns:
            The count of bytes copied.
        """
        var count = min(size, self.readable())
        var p = self.data.unsafe_ptr()
        for index in range(count):
            dest[unsafe_offset=index] = p[unsafe_offset=self.head + index]
        self.consume(count)
        return count

    def peek(self) -> Span[UInt8, origin_of(self.data)]:
        """Return the bytes that `read` can give now, without taking them.

        Returns:
            The bytes; `consume` takes them.
        """
        return Span(self.data)[self.head : self.head + self.readable()]

    def consume(mut self, count: Int):
        """Take bytes from the front, as `read` does.

        Args:
            count: The count, at most `readable()`.
        """
        if count == 0:
            return
        self.bytes_read += UInt64(count)
        self.head += count
        _ = self.received.remove(0, self.bytes_read)
        if self.head == len(self.data):
            self.data.clear()
            self.head = 0
        elif self.head >= 65536 and self.head * 2 >= len(self.data):
            var rest = List[UInt8](self.data[self.head :])
            self.data = rest^
            self.head = 0

    def end(self) -> UInt64:
        """Return the offset after the highest byte that arrived.

        Returns:
            The offset; `bytes_read` when nothing waits.
        """
        var high = self.received.max()
        if high:
            return high.value() + 1
        return self.bytes_read
