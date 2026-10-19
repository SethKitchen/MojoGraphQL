# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.assembler`. The cases port quinn-proto 0.11.19
quinn-proto/src/connection/assembler.rs: `assemble_ordered`,
`assemble_unordered`, `assemble_duplicate`, `assemble_contained`,
`assemble_contains`, `assemble_overlapping`, `assemble_complex`,
`assemble_old` and `defrag_with_missing_prefix`. A read of this port
gives every byte up to the first gap, so the bytes of two frames come in
one read. The `_compact` cases and the unordered reads test the chunk heap
and the `defragment` that this port does not have, and have no case. The
other cases test empty frames, `peek`, `consume`, `end` and the move of
the bytes after a large read prefix."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_quic.assembler import Assembler


def next(mut x: Assembler, size: Int) -> String:
    """Read at most `size` bytes, as text."""
    var buf = List[UInt8](length=size, fill=0)
    var n = x.read(buf.unsafe_ptr(), size)
    return String(unsafe_from_utf8=Span(buf)[0:n])


def test_assemble_ordered() raises:
    var x = Assembler()
    assert_equal(next(x, 32), "")
    x.insert(0, "123".as_bytes())
    assert_equal(next(x, 1), "1")
    assert_equal(next(x, 3), "23")
    x.insert(3, "456".as_bytes())
    assert_equal(next(x, 32), "456")
    x.insert(6, "789".as_bytes())
    x.insert(9, "10".as_bytes())
    assert_equal(next(x, 32), "78910")
    assert_equal(next(x, 32), "")
    assert_equal(x.bytes_read, 11)


def test_assemble_unordered() raises:
    var x = Assembler()
    x.insert(3, "456".as_bytes())
    assert_equal(x.readable(), 0)
    assert_equal(next(x, 32), "")
    assert_equal(x.end(), 6)
    x.insert(0, "123".as_bytes())
    assert_equal(next(x, 32), "123456")
    assert_equal(next(x, 32), "")


def test_assemble_duplicate() raises:
    var x = Assembler()
    x.insert(0, "123".as_bytes())
    x.insert(0, "123".as_bytes())
    assert_equal(next(x, 32), "123")
    assert_equal(next(x, 32), "")


def test_assemble_contained() raises:
    var x = Assembler()
    x.insert(0, "12345".as_bytes())
    x.insert(1, "234".as_bytes())
    assert_equal(next(x, 32), "12345")
    assert_equal(next(x, 32), "")


def test_assemble_contains() raises:
    var x = Assembler()
    x.insert(1, "234".as_bytes())
    x.insert(0, "12345".as_bytes())
    assert_equal(next(x, 32), "12345")
    assert_equal(next(x, 32), "")


def test_assemble_overlapping() raises:
    var x = Assembler()
    x.insert(0, "123".as_bytes())
    assert_equal(next(x, 2), "12")
    # The bytes before the first unread one are dropped.
    x.insert(1, "234".as_bytes())
    assert_equal(next(x, 32), "34")
    assert_equal(next(x, 32), "")


def test_assemble_complex() raises:
    var x = Assembler()
    x.insert(0, "1".as_bytes())
    x.insert(2, "3".as_bytes())
    x.insert(4, "5".as_bytes())
    assert_equal(x.readable(), 1)
    x.insert(0, "123456".as_bytes())
    assert_equal(next(x, 32), "123456")
    assert_equal(next(x, 32), "")


def test_assemble_old() raises:
    var x = Assembler()
    x.insert(0, "1234".as_bytes())
    assert_equal(next(x, 32), "1234")
    x.insert(0, "1234".as_bytes())
    assert_equal(next(x, 32), "")
    assert_equal(x.end(), 4)


def test_defrag_with_missing_prefix() raises:
    var x = Assembler()
    x.insert(3, "def".as_bytes())
    assert_equal(next(x, 32), "")
    x.insert(0, "abc".as_bytes())
    assert_equal(next(x, 32), "abcdef")


def test_empty_frame() raises:
    var x = Assembler()
    var empty = List[UInt8]()
    # An empty frame above the read offset adds no bytes.
    x.insert(5, empty)
    assert_equal(x.readable(), 0)
    assert_equal(x.end(), 0)
    x.insert(0, "12345".as_bytes())
    assert_equal(next(x, 32), "12345")


def test_peek_consume() raises:
    var x = Assembler()
    assert_equal(x.end(), 0)
    x.insert(0, "hello".as_bytes())
    assert_equal(String(unsafe_from_utf8=x.peek()), "hello")
    x.consume(0)
    assert_equal(x.bytes_read, 0)
    x.consume(2)
    assert_equal(String(unsafe_from_utf8=x.peek()), "llo")
    assert_equal(x.head, 2)
    x.consume(3)
    assert_equal(x.head, 0)
    assert_equal(len(x.data), 0)
    assert_equal(x.end(), 5)
    assert_false(x.received.max().__bool__())


def test_compact() raises:
    var x = Assembler()
    var data = List[UInt8](capacity=200000)
    for index in range(200000):
        data.append(UInt8(index % 251))
    x.insert(0, data)
    # A large read prefix that is less than half of the buffer stays.
    x.consume(70000)
    assert_equal(x.head, 70000)
    assert_equal(len(x.data), 200000)
    # A large read prefix that is half of the buffer or more moves out.
    x.consume(40000)
    assert_equal(x.head, 0)
    assert_equal(len(x.data), 90000)
    assert_equal(x.readable(), 90000)
    var got = x.peek()
    assert_equal(got[0], UInt8(110000 % 251))
    assert_true(x.end() == 200000)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
