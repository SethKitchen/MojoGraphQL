# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A set of `UInt64` values, held as sorted, disjoint, half-open ranges.

QUIC keeps the packet numbers that it received, and the packet numbers
that the peer acknowledged, in such a set. An ACK frame sends the set as
ranges, largest first. Two ranges never touch: `insert` merges a range
with the ranges that it overlaps or meets.

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/range_set/array_range_set.rs (MIT OR Apache-2.0, used
under MIT).

Differences from upstream: a range is an `Interval` with `start` and
`end`, in place of a Rust `Range<u64>`, and `insert` and `remove` take the
two ends. The ranges are in a `List`, in place of a `TinyVec` with two
inline slots. `start(i)`, `end(i)` and `get(i)` read the ranges in
ascending order in place of an iterator. `peek_min` and `clear` are added.
The redundant `x.start != x.end` test in the loop of `remove` is left out,
because `remove` returns early for an empty range.
"""


@fieldwise_init
struct Interval(Equatable, ImplicitlyCopyable, Writable):
    """A half-open range of values: `start` is in it, `end` is not."""

    var start: UInt64
    """The first value."""
    var end: UInt64
    """The value after the last value."""

    def len(self) -> UInt64:
        """Return the number of values.

        Returns:
            `end - start`.
        """
        return self.end - self.start

    def write_to(self, mut writer: Some[Writer]):
        """Write the range as `start..end`.

        Args:
            writer: The destination.
        """
        writer.write(self.start, "..", self.end)


struct RangeSet(Copyable, Movable, Sized, Writable):
    """A set of values, held as sorted, disjoint, half-open ranges."""

    var _ranges: List[Interval]
    """The ranges in ascending order; no two overlap or touch."""

    def __init__(out self):
        """Make an empty set."""
        self._ranges = List[Interval]()

    @always_inline
    def len(self) -> Int:
        """Return the number of ranges.

        Returns:
            The number of ranges, not of values.
        """
        return len(self._ranges)

    @always_inline
    def __len__(self) -> Int:
        """Return the number of ranges.

        Returns:
            The number of ranges, not of values.
        """
        return len(self._ranges)

    @always_inline
    def is_empty(self) -> Bool:
        """Return True when the set holds no value.

        Returns:
            Whether there is no range.
        """
        return len(self._ranges) == 0

    @always_inline
    def get(self, index: Int) -> Interval:
        """Return a range, in ascending order.

        Args:
            index: An index below `len()`; 0 is the lowest range.

        Returns:
            The range.
        """
        return self._ranges[index]

    @always_inline
    def start(self, index: Int) -> UInt64:
        """Return the first value of a range.

        Args:
            index: An index below `len()`; 0 is the lowest range.

        Returns:
            The first value.
        """
        return self._ranges[index].start

    @always_inline
    def end(self, index: Int) -> UInt64:
        """Return the value after the last value of a range.

        Args:
            index: An index below `len()`; 0 is the lowest range.

        Returns:
            The end of the range.
        """
        return self._ranges[index].end

    def contains(self, x: UInt64) -> Bool:
        """Return True when the set holds a value.

        Args:
            x: The value.

        Returns:
            Whether a range holds the value.
        """
        for r in self._ranges:
            if r.start > x:
                return False
            if x < r.end:
                return True
        return False

    def insert_one(mut self, x: UInt64) -> Bool:
        """Add one value.

        Args:
            x: The value; below `UInt64.MAX`.

        Returns:
            Whether the value is new.
        """
        return self.insert(x, x + 1)

    def insert(mut self, start: UInt64, end: UInt64) -> Bool:
        """Add the values of a range.

        Args:
            start: The first value.
            end: The value after the last value.

        Returns:
            Whether the set holds a value that it did not hold before.
        """
        if start >= end:
            return False
        var result = False
        var idx = 0
        while idx != len(self._ranges):
            ref range = self._ranges[idx]
            if range.start > end:
                self._ranges.insert(idx, Interval(start, end))
                return True
            if range.start > start:
                result = True
                range.start = start
            if end <= range.end:
                return result
            if start <= range.end:
                range.end = end
                self._merge_after(idx)
                return True
            idx += 1
        self._ranges.append(Interval(start, end))
        return True

    def _merge_after(mut self, idx: Int):
        """Merge the range at `idx` with the ranges after it that it meets."""
        while idx != len(self._ranges) - 1:
            var curr = self._ranges[idx]
            var next = self._ranges[idx + 1]
            if curr.end < next.start:
                return
            self._ranges[idx].end = max(next.end, curr.end)
            _ = self._ranges.pop(idx + 1)

    def remove(mut self, start: UInt64, end: UInt64) -> Bool:
        """Remove the values of a range.

        Args:
            start: The first value.
            end: The value after the last value.

        Returns:
            Whether the set held a value of the range.
        """
        if start >= end:
            return False
        var result = False
        var idx = 0
        while idx != len(self._ranges):
            var range = self._ranges[idx]
            if end <= range.start:
                return result
            if start >= range.end:
                idx += 1
                continue
            result = True
            var left = Interval(range.start, start)
            var right = Interval(end, range.end)
            var left_empty = left.start >= left.end
            var right_empty = right.start >= right.end
            if left_empty and right_empty:
                _ = self._ranges.pop(idx)
            elif left_empty:
                self._ranges[idx] = right
                idx += 1
            elif right_empty:
                self._ranges[idx] = left
                idx += 1
            else:
                self._ranges[idx] = right
                self._ranges.insert(idx, left)
                idx += 2
        return result

    def subtract(mut self, other: RangeSet):
        """Remove every value of another set.

        Args:
            other: The values to remove.
        """
        for r in other._ranges:
            _ = self.remove(r.start, r.end)

    def min(self) -> Optional[UInt64]:
        """Return the smallest value.

        Returns:
            The smallest value, or None for an empty set.
        """
        if len(self._ranges) == 0:
            return None
        return self._ranges[0].start

    def max(self) -> Optional[UInt64]:
        """Return the largest value.

        Returns:
            The largest value, or None for an empty set.
        """
        if len(self._ranges) == 0:
            return None
        return self._ranges[len(self._ranges) - 1].end - 1

    def peek_min(self) -> Optional[Interval]:
        """Return the lowest range.

        Returns:
            The lowest range, or None for an empty set.
        """
        if len(self._ranges) == 0:
            return None
        return self._ranges[0]

    def pop_min(mut self) -> Optional[Interval]:
        """Remove and return the lowest range.

        Returns:
            The lowest range, or None for an empty set.
        """
        if len(self._ranges) == 0:
            return None
        return self._ranges.pop(0)

    def clear(mut self):
        """Remove every value."""
        self._ranges.clear()

    def write_to(self, mut writer: Some[Writer]):
        """Write the ranges, such as `[0..2, 4..6]`.

        Args:
            writer: The destination.
        """
        writer.write("[")
        for i in range(len(self._ranges)):
            if i > 0:
                writer.write(", ")
            writer.write(self._ranges[i])
        writer.write("]")
