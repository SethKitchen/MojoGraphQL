# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.qpack_static` and `gql_http3.qpack_field`.

Upstream: `h3/src/qpack/static_.rs` (`test_static_table_index_is_0_based`,
`test_static_table_is_full`, `test_static_table_can_get_field`,
`invalid_index`, `find_by_name`, `find`) and `h3/src/qpack/field.rs`
(`test_field_size_is_offset_by_32`, `with_value`) of hyperium/h3
h3-v0.0.8. The lookup is also checked against a linear search of every
entry.
"""

from gql_http3.qpack_field import ENTRY_OVERHEAD, FieldList, field_size
from gql_http3.qpack_static import (
    STATIC_TABLE_SIZE,
    StaticMatch,
    static_find,
    static_find_name,
    static_name,
    static_value,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _b(text: StaticString) -> Span[UInt8, ImmStaticOrigin]:
    return text.as_bytes()


def test_static_table_index_is_0_based() raises:
    assert_equal(static_name(0), ":authority")
    assert_equal(static_value(0), "")


def test_static_table_is_full() raises:
    assert_equal(STATIC_TABLE_SIZE, 99)


def test_static_table_can_get_field() raises:
    assert_equal(static_name(98), "x-frame-options")
    assert_equal(static_value(98), "sameorigin")


def test_find_by_name() raises:
    assert_equal(static_find_name(_b("last-modified")), 10)
    assert_equal(static_find_name(_b("does-not-exist")), -1)
    assert_equal(static_find_name(_b("")), -1)
    assert_equal(static_find_name(_b(":status")), 24)
    assert_equal(static_find_name(_b("content-type")), 44)


def test_find() raises:
    var hit = static_find(_b(":method"), _b("GET"))
    assert_equal(hit.exact, 17)
    assert_equal(hit.name, 15)
    hit = static_find(_b("foo"), _b("bar"))
    assert_equal(hit.exact, -1)
    assert_equal(hit.name, -1)
    hit = static_find(_b(":status"), _b("500"))
    assert_equal(hit.exact, 71)
    hit = static_find(_b(":status"), _b("201"))
    assert_equal(hit.exact, -1)
    assert_equal(hit.name, 24)
    assert_equal(String(StaticMatch(1, 2)), "exact 1 name 2")


def test_find_every_entry() raises:
    # Each entry finds itself, and its name finds the first entry with it.
    for index in range(STATIC_TABLE_SIZE):
        var name = static_name(index)
        var first = 0
        while static_name(first) != name:
            first += 1
        var hit = static_find(name.as_bytes(), static_value(index).as_bytes())
        assert_equal(hit.exact, index, String(index))
        assert_equal(hit.name, first, String(index))


def test_field_size_is_offset_by_32() raises:
    assert_equal(field_size(4, 5), 4 + 5 + 32)
    assert_equal(ENTRY_OVERHEAD, 32)


def test_field_list() raises:
    var fields = FieldList(64)
    assert_equal(len(fields), 0)
    fields.add_text("Name", "Value")
    fields.add(_b(":path"), _b("/"))
    fields.add_text("empty", "")
    assert_equal(fields.count(), 3)
    assert_equal(len(fields), 3)
    assert_equal(fields.name_text(0), "Name")
    assert_equal(fields.value_text(0), "Value")
    assert_equal(fields.name_text(1), ":path")
    assert_equal(fields.value_text(1), "/")
    assert_equal(fields.value_text(2), "")
    assert_true(fields.name(2) == _b("empty"))
    assert_equal(fields.size(), 9 + 32 + 6 + 32 + 5 + 32)
    assert_equal(fields.find("empty"), 2)
    assert_equal(fields.find("other"), -1)
    assert_equal(String(fields), "Name: Value\n:path: /\nempty: \n")
    var copy = fields.copy()
    fields.clear()
    assert_equal(fields.count(), 0)
    assert_equal(copy.count(), 3)


def test_with_value() raises:
    # Upstream `with_value`: the same name with a new value.
    var fields = FieldList()
    fields.add_text("Name", "Value")
    var name = List[UInt8](fields.name(0))
    fields.add(Span(name), _b("New value"))
    assert_equal(fields.name_text(1), "Name")
    assert_equal(fields.value_text(1), "New value")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
