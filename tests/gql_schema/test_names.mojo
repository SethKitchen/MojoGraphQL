# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.names`.

`NameTable` has no graphql-js counterpart, so no upstream test file is
ported. The tests use only the public behavior: `find`, `insert`, `assign`,
`find_or_insert`, the `capacity` argument and `len`.
"""

from gql_schema.names import NOT_FOUND, NameTable
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_empty_table() raises:
    var table = NameTable()
    assert_equal(table.__len__(), 0)
    assert_equal(table.find(-1, "Query"), NOT_FOUND)
    assert_equal(table.find(0, ""), NOT_FOUND)


def test_insert_and_find() raises:
    var table = NameTable()
    assert_true(table.insert(-1, "Query", 3))
    assert_equal(table.find(-1, "Query"), 3)
    assert_equal(table.__len__(), 1)
    assert_equal(table.find(-1, "query"), NOT_FOUND)
    assert_equal(table.find(-1, "Quer"), NOT_FOUND)
    assert_equal(table.find(-1, "Query2"), NOT_FOUND)


def test_insert_keeps_the_first_value() raises:
    var table = NameTable()
    assert_true(table.insert(4, "name", 1))
    assert_false(table.insert(4, "name", 2))
    assert_equal(table.find(4, "name"), 1)
    assert_equal(table.__len__(), 1)


def test_assign_replaces_or_inserts() raises:
    var table = NameTable()
    table.assign(-1, "a", 1)
    assert_equal(table.find(-1, "a"), 1)
    table.assign(-1, "a", 7)
    assert_equal(table.find(-1, "a"), 7)
    assert_equal(table.__len__(), 1)
    table.assign(2, "a", 9)
    assert_equal(table.find(2, "a"), 9)
    assert_equal(table.find(-1, "a"), 7)
    assert_equal(table.__len__(), 2)


def test_same_name_under_different_owners() raises:
    var table = NameTable()
    var owners: List[Int] = [-1, 0, 1, 5, -2, -3, -2 - 40, 1000000]
    for index in range(len(owners)):
        assert_true(table.insert(owners[index], "field", index))
    for index in range(len(owners)):
        assert_equal(table.find(owners[index], "field"), index)
    assert_equal(table.find(2, "field"), NOT_FOUND)
    assert_equal(table.__len__(), len(owners))


def test_keys_whose_owner_and_bytes_mix_alike() raises:
    # Owner -1 with "a" and owner 0 with "`" give the same first hash state
    # in an FNV-1a hash that mixes in `owner + 1`; the keys stay apart.
    var table = NameTable()
    assert_true(table.insert(-1, "a", 1))
    assert_true(table.insert(0, "`", 2))
    assert_equal(table.find(-1, "a"), 1)
    assert_equal(table.find(0, "`"), 2)
    assert_equal(table.find(0, "a"), NOT_FOUND)
    assert_equal(table.find(-1, "`"), NOT_FOUND)
    table.assign(0, "`", 3)
    table.assign(-1, "a", 4)
    assert_equal(table.find(0, "`"), 3)
    assert_equal(table.find(-1, "a"), 4)
    table.assign(1, "b", 5)
    assert_equal(table.find(1, "b"), 5)
    assert_equal(table.__len__(), 3)


def expect_apart(
    owner_a: Int, name_a: String, owner_b: Int, name_b: String
) raises:
    """Assert that two keys with the same 32-bit hash stay apart."""
    var table = NameTable()
    assert_true(table.insert(owner_a, name_a, 1))
    assert_true(table.insert(owner_b, name_b, 2))
    assert_equal(table.find(owner_a, name_a), 1)
    assert_equal(table.find(owner_b, name_b), 2)
    table.assign(owner_b, name_b, 3)
    assert_equal(table.find(owner_b, name_b), 3)
    assert_equal(table.find(owner_a, name_a), 1)


def test_keys_with_the_same_hash() raises:
    # Each pair has the same 32-bit hash, found by a search over many keys,
    # so the second key probes past the first one.
    # The names differ in their first 8 bytes.
    expect_apart(0, "k000083368", 0, "k000012940")
    # The names differ after their first 8 bytes.
    expect_apart(0, "abcdefgh0116133", 0, "abcdefgh0007107")
    # The owners differ.
    expect_apart(0, "k000057072", 1, "k000001522")
    # The lengths differ.
    expect_apart(0, "k000290574", 0, "k0000017473")


def test_empty_name() raises:
    var table = NameTable()
    assert_true(table.insert(-1, "", 1))
    assert_true(table.insert(3, "", 2))
    assert_equal(table.find(-1, ""), 1)
    assert_equal(table.find(3, ""), 2)


def test_many_keys_grow_the_table() raises:
    var table = NameTable()
    var count = 1500
    for index in range(count):
        assert_true(table.insert(index % 7 - 3, "name" + String(index), index))
    assert_equal(table.__len__(), count)
    for index in range(count):
        assert_equal(table.find(index % 7 - 3, "name" + String(index)), index)
        assert_equal(
            table.find(index % 7 - 2, "name" + String(index)), NOT_FOUND
        )
    for index in range(0, count, 3):
        table.assign(index % 7 - 3, "name" + String(index), index + 1)
    for index in range(count):
        var expected = index + 1 if index % 3 == 0 else index
        assert_equal(
            table.find(index % 7 - 3, "name" + String(index)), expected
        )
    assert_equal(table.__len__(), count)
    assert_equal(table.find(-1, "missing"), NOT_FOUND)


def test_assign_grows_the_table() raises:
    var table = NameTable()
    for index in range(100):
        table.assign(-1, "k" + String(index), index)
    assert_equal(table.__len__(), 100)
    for index in range(100):
        assert_equal(table.find(-1, "k" + String(index)), index)


def test_find_or_insert() raises:
    var table = NameTable()
    assert_equal(table.find_or_insert(-1, "a", 4), NOT_FOUND)
    assert_equal(table.find(-1, "a"), 4)
    assert_equal(table.find_or_insert(-1, "a", 9), 4)
    assert_equal(table.find(-1, "a"), 4)
    assert_equal(table.find_or_insert(-2, "a", 5), NOT_FOUND)
    assert_equal(table.__len__(), 2)
    for index in range(50):
        assert_equal(
            table.find_or_insert(index, "x" + String(index), index), NOT_FOUND
        )
    for index in range(50):
        assert_equal(table.find_or_insert(index, "x" + String(index), 0), index)
    assert_equal(table.__len__(), 52)


def test_capacity() raises:
    var sizes: List[Int] = [0, 1, 8, 9, 100]
    for size in sizes:
        var table = NameTable(capacity=size)
        assert_equal(table.__len__(), 0)
        for index in range(size + 20):
            assert_true(table.insert(index % 3 - 2, "n" + String(index), index))
        for index in range(size + 20):
            assert_equal(table.find(index % 3 - 2, "n" + String(index)), index)
        assert_equal(table.__len__(), size + 20)


def test_copy_is_independent() raises:
    var table = NameTable()
    _ = table.insert(-1, "a", 1)
    var copy = table.copy()
    _ = table.insert(-1, "b", 2)
    table.assign(-1, "a", 3)
    assert_equal(copy.find(-1, "a"), 1)
    assert_equal(copy.find(-1, "b"), NOT_FOUND)
    assert_equal(copy.__len__(), 1)
    assert_equal(table.find(-1, "a"), 3)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
