# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.qpack_vas` and `gql_http3.qpack_table`.

Upstream: `h3/src/qpack/vas.rs` (every test; the proptest cases run for
each count from 1 to 300) and the table tests of `h3/src/qpack/dynamic.rs`
(`test_table_size_is_sum_of_its_entries` to `test_eviction_is_fifo`) of
hyperium/h3 h3-v0.0.8. The encoder tests of `dynamic.rs` are in
`test_qpack_encoder.mojo`.
"""

from gql_http3.error import H3ErrorCode
from gql_http3.qpack_table import (
    SETTINGS_MAX_TABLE_CAPACITY_MAX,
    DynamicTable,
)
from gql_http3.qpack_vas import VirtualAddressSpace
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _b(text: StaticString) -> Span[UInt8, ImmStaticOrigin]:
    return text.as_bytes()


def _relative_fails(vas: VirtualAddressSpace, index: Int) raises -> Bool:
    try:
        _ = vas.relative(index)
    except e:
        assert_true(e.code == H3ErrorCode.QPACK_DECOMPRESSION_FAILED)
        return True
    return False


def _relative_base_fails(
    vas: VirtualAddressSpace, base: Int, index: Int
) raises -> Bool:
    try:
        _ = vas.relative_base(base, index)
    except:
        return True
    return False


def _post_base_fails(
    vas: VirtualAddressSpace, base: Int, index: Int
) raises -> Bool:
    try:
        _ = vas.post_base(base, index)
    except:
        return True
    return False


def _index_fails(vas: VirtualAddressSpace, position: Int) raises -> Bool:
    try:
        _ = vas.index(position)
    except:
        return True
    return False


def test_no_relative_index_when_empty() raises:
    var vas = VirtualAddressSpace()
    assert_true(_relative_base_fails(vas, 0, 0))
    _ = vas.add()
    assert_true(_relative_base_fails(vas, 1, 2))


def test_relative_underflow_protected() raises:
    var vas = VirtualAddressSpace()
    _ = vas.add()
    assert_true(_relative_fails(vas, 2))


def test_insertions() raises:
    for count in range(1, 300):
        var vas = VirtualAddressSpace()
        for _ in range(count):
            _ = vas.add()
        # first insertion without drop, last insertion without drop
        assert_equal(vas.relative_base(count, count - 1), 0)
        assert_equal(vas.relative_base(count, 0), count - 1)
    for count in range(2, 300):
        var vas = VirtualAddressSpace()
        for _ in range(count):
            _ = vas.add()
        for _ in range(count - 1):
            vas.drop()
        # first insertion with drop, last insertion with drop
        assert_true(_relative_base_fails(vas, count, count - 1))
        assert_equal(vas.relative_base(count, 0), 0)


def test_post_base_index() raises:
    # Base index: D, target value: B.
    # VAS: ]GFEDCBA], abs 1234567, rel 3210---, pst ----012
    var vas = VirtualAddressSpace()
    for _ in range(7):
        _ = vas.add()
    assert_equal(vas.post_base(4, 1), 5)
    assert_true(_post_base_fails(vas, 4, 3))
    var empty = VirtualAddressSpace()
    assert_true(_post_base_fails(empty, 0, 0))
    vas.drop()
    vas.drop()
    assert_true(_post_base_fails(vas, 0, 1))
    assert_equal(vas.post_base(0, 2), 0)


def test_largest_ref() raises:
    var vas = VirtualAddressSpace()
    for _ in range(7):
        _ = vas.add()
    assert_equal(vas.largest_ref(), 7)
    assert_equal(vas.total_inserted(), 7)


def test_relative() raises:
    var vas = VirtualAddressSpace()
    assert_true(_relative_fails(vas, 0))
    for _ in range(7):
        _ = vas.add()
    assert_equal(vas.relative(0), 6)
    assert_equal(vas.relative(1), 5)
    assert_equal(vas.relative(6), 0)
    assert_true(_relative_fails(vas, 7))
    assert_true(_relative_fails(vas, 8))
    vas.drop()
    assert_true(_relative_fails(vas, 6))
    assert_equal(vas.relative(5), 0)


def test_absolute_from_real_index() raises:
    var vas = VirtualAddressSpace()
    assert_true(_index_fails(vas, 0))
    _ = vas.add()
    assert_equal(vas.index(0), 1)
    _ = vas.add()
    vas.drop()
    assert_equal(vas.index(0), 2)
    vas.drop()
    assert_true(_index_fails(vas, 0))
    _ = vas.add()
    _ = vas.add()
    assert_equal(vas.index(0), 3)
    assert_equal(vas.index(1), 4)
    assert_true(_index_fails(vas, 2))
    assert_equal(String(vas), "inserted 4 dropped 2 live 2")


def test_evicted() raises:
    var vas = VirtualAddressSpace()
    assert_false(vas.evicted(0))
    assert_false(vas.evicted(1))
    _ = vas.add()
    _ = vas.add()
    assert_false(vas.evicted(1))
    vas.drop()
    assert_false(vas.evicted(0))
    assert_true(vas.evicted(1))
    assert_false(vas.evicted(2))
    vas.drop()
    assert_true(vas.evicted(2))


def _table() -> DynamicTable:
    var table = DynamicTable()
    table.set_capacity(4096)
    return table^


def test_table_size_is_sum_of_its_entries() raises:
    var table = _table()
    table.insert(_b("Name"), _b("Value"))
    table.insert(_b("Another-Name"), _b(""))
    assert_equal(table.size, 4 + 5 + 12 + 0 + 32 * 2)
    assert_equal(table.live(), 2)
    assert_equal(table.insert_count(), 2)


def test_capacity_limits() raises:
    # Upstream's set_max_size refuses a size above 2^30 - 1; the coder
    # checks the SETTINGS value instead. The table reaches 0 and the
    # maximum.
    var table = _table()
    table.set_capacity(0)
    assert_equal(table.capacity, 0)
    table.set_capacity(SETTINGS_MAX_TABLE_CAPACITY_MAX)
    assert_equal(table.capacity, SETTINGS_MAX_TABLE_CAPACITY_MAX)


def test_table_supports_duplicated_entries() raises:
    var table = _table()
    table.insert(_b("Name"), _b("Value"))
    table.insert(_b("Name"), _b("Value"))
    assert_equal(table.live(), 2)
    assert_equal(table.find(_b("Name"), _b("Value")), 1)


def test_add_field_drop_older_fields_to_have_enough_space() raises:
    var table = _table()
    table.insert(_b("Name-A"), _b("Value-A"))
    table.insert(_b("Name-B"), _b("Value-B"))
    table.set_capacity(table.size)
    table.insert(_b("Name-Large"), _b("Value-Large"))
    assert_equal(table.live(), 1)
    assert_equal(table.dropped(), 2)
    assert_true(table.name(2) == _b("Name-Large"))
    assert_true(table.value(2) == _b("Value-Large"))


def test_try_add_field_larger_than_maximum_size() raises:
    var table = _table()
    table.insert(_b("Name-A"), _b("Value-A"))
    table.set_capacity(table.size)
    assert_false(table.can_free(10 + 11 + 32))
    assert_true(table.can_free(6 + 7 + 32))


def test_set_maximum_table_size_to_zero_clear_entries() raises:
    var table = _table()
    table.insert(_b("Name"), _b("Value"))
    table.insert(_b("Name"), _b("Value"))
    table.set_capacity(0)
    assert_equal(table.live(), 0)
    assert_equal(table.size, 0)


def test_eviction_is_fifo() raises:
    var table = _table()
    table.insert(_b("Name-A"), _b("Value-A"))
    table.insert(_b("Name-B"), _b("Value-B"))
    table.set_capacity(table.size)
    table.insert(_b("Name-C"), _b("Value-C"))
    assert_equal(table.dropped(), 1)
    assert_true(table.name(1) == _b("Name-B"))
    assert_true(table.name(2) == _b("Name-C"))
    assert_equal(table.live(), 2)
    assert_equal(
        String(table), "capacity 90 size 90 inserted 3 dropped 1 live 2"
    )


def test_indexes() raises:
    var table = _table()
    for i in range(4):
        table.insert(_b("foo"), String("bar", i).as_bytes())
    # Base 2: relative 0 is absolute 1, post-base 0 is absolute 2.
    assert_equal(table.before_base(2, 0), 1)
    assert_equal(table.before_base(2, 1), 0)
    assert_equal(table.after_base(2, 0), 2)
    assert_equal(table.after_base(2, 1), 3)
    assert_equal(table.from_insert_count(0), 3)
    assert_equal(table.from_insert_count(3), 0)
    # A base above the insert count names no entry.
    var failed = False
    try:
        _ = table.before_base(9, 0)
    except:
        failed = True
    assert_true(failed)
    assert_equal(table.find_name(_b("foo")), 3)
    assert_equal(table.find_name(_b("bar")), -1)
    assert_equal(table.find(_b("foo"), _b("bar0")), 0)
    assert_equal(table.find(_b("foo"), _b("nope")), -1)
    assert_equal(table.find(_b("fo"), _b("bar0")), -1)


def test_references_block_eviction() raises:
    var table = DynamicTable()
    table.set_capacity(100)
    table.insert(_b("aaaa"), _b("1111"))
    table.insert(_b("bbbb"), _b("2222"))
    table.add_ref(0, 1)
    assert_equal(table.refs_of(0), 1)
    assert_false(table.can_free(40))
    assert_true(table.can_free(20))
    table.add_ref(0, -1)
    assert_true(table.can_free(40))
    table.add_ref(1, 1)
    assert_false(table.can_free(80))


def test_compaction() raises:
    # Many evictions drop the dead bytes, and keep the live entries.
    var table = DynamicTable()
    table.set_capacity(3 * 40)
    for i in range(500):
        var value = String(1000 + i)
        table.insert(_b("name"), value.as_bytes())
        table.add_ref(i, 1)
        table.add_ref(i, -1)
    assert_equal(table.live(), 3)
    assert_equal(table.insert_count(), 500)
    assert_true(table.value(499) == String(1499).as_bytes())
    assert_true(table.value(497) == String(1497).as_bytes())
    assert_true(table.name(498) == _b("name"))
    assert_equal(table.find(_b("name"), String(1498).as_bytes()), 498)
    assert_equal(table.refs_of(497), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
