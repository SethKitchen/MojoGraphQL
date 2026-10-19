# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.range_set`.

Upstream: quinn-proto 0.11.19 (8192ed3) quinn-proto/src/range_set/tests.rs,
the `common_set_tests` cases for `ArrayRangeSet`, with the reference set
`RefRangeSet`. The other tests cover the accessors that this port adds.
"""

from gql_quic.range_set import Interval, RangeSet
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _elts(set: RangeSet) -> List[UInt64]:
    var out = List[UInt64]()
    for i in range(set.len()):
        var v = set.start(i)
        while v < set.end(i):
            out.append(v)
            v += 1
    return out^


def _list(*values: Int) -> List[UInt64]:
    var out = List[UInt64]()
    for v in values:
        out.append(UInt64(v))
    return out^


struct RefRangeSet(Movable):
    """A simple reference set: one flag per value, as upstream."""

    var data: List[Bool]

    def __init__(out self, capacity: Int):
        self.data = List[Bool](length=capacity, fill=False)

    def len(self) -> Int:
        var last = False
        var count = 0
        for v in self.data:
            if not last and v:
                count += 1
            last = v
        return count

    def insert(mut self, start: Int, end: Int) -> Bool:
        var result = False
        for i in range(start, end):
            if not self.data[i]:
                result = True
                self.data[i] = True
        return result

    def remove(mut self, start: Int, end: Int) -> Bool:
        var result = False
        for i in range(start, end):
            if self.data[i]:
                result = True
                self.data[i] = False
        return result

    def elts(self) -> List[UInt64]:
        var out = List[UInt64]()
        for i in range(len(self.data)):
            if self.data[i]:
                out.append(UInt64(i))
        return out^


def _same(a: Bool, b: Bool, what: StaticString) raises:
    """Check two results; plain, because `assert_equal` is slow in a loop."""
    if a != b:
        raise Error(what)


def _assert_sets_equal(set: RangeSet, reference: RefRangeSet) raises:
    _same(set.len() == reference.len(), True, "len")
    _same(set.is_empty(), reference.len() == 0, "is_empty")
    _same(_elts(set) == reference.elts(), True, "elts")


def _initial(mut set: RangeSet, mut reference: RefRangeSet) raises:
    _assert_sets_equal(set, reference)
    var pairs: List[Int] = [2, 6, 10, 14, 14, 14, 18, 19, 20, 21, 22, 24]
    pairs.extend([26, 30, 34, 38, 42, 44])
    for i in range(0, len(pairs), 2):
        var s = pairs[i]
        var e = pairs[i + 1]
        _same(set.insert(UInt64(s), UInt64(e)), reference.insert(s, e), "init")
    _assert_sets_equal(set, reference)


def test_merge_and_split() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 2))
    assert_true(set.insert(2, 4))
    assert_false(set.insert(1, 3))
    assert_equal(set.len(), 1)
    assert_true(_elts(set) == _list(0, 1, 2, 3))
    assert_false(set.contains(4))
    assert_true(set.remove(2, 3))
    assert_equal(set.len(), 2)
    assert_false(set.contains(2))
    assert_true(_elts(set) == _list(0, 1, 3))


def test_double_merge_exact() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 2))
    assert_true(set.insert(4, 6))
    assert_equal(set.len(), 2)
    assert_true(set.insert(2, 4))
    assert_equal(set.len(), 1)
    assert_true(_elts(set) == _list(0, 1, 2, 3, 4, 5))


def test_single_merge_low() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 2))
    assert_true(set.insert(4, 6))
    assert_true(set.insert(2, 3))
    assert_equal(set.len(), 2)
    assert_true(_elts(set) == _list(0, 1, 2, 4, 5))


def test_single_merge_high() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 2))
    assert_true(set.insert(4, 6))
    assert_true(set.insert(3, 4))
    assert_equal(set.len(), 2)
    assert_true(_elts(set) == _list(0, 1, 3, 4, 5))


def test_double_merge_wide() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 2))
    assert_true(set.insert(4, 6))
    assert_true(set.insert(1, 5))
    assert_equal(set.len(), 1)
    assert_true(_elts(set) == _list(0, 1, 2, 3, 4, 5))


def test_double_remove() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 2))
    assert_true(set.insert(4, 6))
    assert_true(set.remove(1, 5))
    assert_equal(set.len(), 2)
    assert_true(_elts(set) == _list(0, 5))


def test_insert_multiple() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 1))
    assert_true(set.insert(2, 3))
    assert_true(set.insert(4, 5))
    assert_true(set.insert(0, 5))
    assert_equal(set.len(), 1)


def test_remove_multiple() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 1))
    assert_true(set.insert(2, 3))
    assert_true(set.insert(4, 5))
    assert_true(set.remove(0, 5))
    assert_true(set.is_empty())


def test_double_insert() raises:
    var set = RangeSet()
    assert_true(set.insert(0, 2))
    assert_false(set.insert(0, 2))
    assert_true(set.insert(2, 4))
    assert_false(set.insert(2, 4))
    assert_false(set.insert(0, 4))
    assert_false(set.insert(1, 2))
    assert_false(set.insert(1, 3))
    assert_false(set.insert(1, 4))
    assert_equal(set.len(), 1)


def test_skip_empty_ranges() raises:
    var set = RangeSet()
    assert_false(set.insert(2, 2))
    assert_false(set.insert(4, 4))
    assert_false(set.insert(0, 0))
    assert_false(set.insert(5, 3))
    assert_equal(set.len(), 0)
    assert_false(set.remove(3, 3))


def test_compare_insert_to_reference() raises:
    comptime MAX_RANGE = 50
    for start in range(MAX_RANGE + 1):
        for end in range(MAX_RANGE + 1):
            var set = RangeSet()
            var reference = RefRangeSet(MAX_RANGE)
            _initial(set, reference)
            _same(
                set.insert(UInt64(start), UInt64(end)),
                reference.insert(start, end),
                "insert",
            )
            _assert_sets_equal(set, reference)


def test_compare_remove_to_reference() raises:
    comptime MAX_RANGE = 50
    for start in range(MAX_RANGE + 1):
        for end in range(MAX_RANGE + 1):
            var set = RangeSet()
            var reference = RefRangeSet(MAX_RANGE)
            _initial(set, reference)
            _same(
                set.remove(UInt64(start), UInt64(end)),
                reference.remove(start, end),
                "remove",
            )
            _assert_sets_equal(set, reference)


def test_min_max() raises:
    var set = RangeSet()
    _ = set.insert(1, 3)
    _ = set.insert(4, 5)
    _ = set.insert(6, 10)
    assert_equal(set.min().value(), 1)
    assert_equal(set.max().value(), 9)


def test_empty_accessors() raises:
    var set = RangeSet()
    assert_false(set.min())
    assert_false(set.max())
    assert_false(set.peek_min())
    assert_false(set.pop_min())
    assert_false(set.contains(0))
    assert_equal(String(set), "[]")


def test_accessors() raises:
    var set = RangeSet()
    assert_true(set.insert_one(7))
    assert_false(set.insert_one(7))
    assert_true(set.insert(10, 12))
    assert_true(set.insert(0, 2))
    assert_equal(len(set), 3)
    assert_equal(String(set), "[0..2, 7..8, 10..12]")
    assert_true(set.get(1) == Interval(7, 8))
    assert_equal(set.get(2).len(), 2)
    assert_true(set.peek_min().value() == Interval(0, 2))
    assert_true(set.pop_min().value() == Interval(0, 2))
    assert_equal(set.len(), 2)
    assert_true(set.contains(11))
    assert_false(set.contains(12))
    var copy = set.copy()
    set.clear()
    assert_true(set.is_empty())
    assert_equal(copy.len(), 2)


def test_subtract() raises:
    var set = RangeSet()
    _ = set.insert(0, 10)
    _ = set.insert(20, 30)
    var other = RangeSet()
    _ = other.insert(2, 4)
    _ = other.insert(8, 22)
    set.subtract(other)
    assert_equal(String(set), "[0..2, 4..8, 22..30]")
    set.subtract(RangeSet())
    assert_equal(set.len(), 3)


def test_merge_overlapping_tail() raises:
    # A range that covers the next one only in part keeps the larger end.
    var set = RangeSet()
    _ = set.insert(0, 2)
    _ = set.insert(5, 9)
    _ = set.insert(12, 14)
    assert_true(set.insert(1, 6))
    assert_equal(String(set), "[0..9, 12..14]")
    assert_true(set.insert(13, 20))
    assert_equal(String(set), "[0..9, 12..20]")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
