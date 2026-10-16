# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_execution.value`: the arena and `inspect`.

The `inspect` cases are those of graphql-js 16.14.2
`src/jsutils/__tests__/inspect-test.ts` that a JSON-like value can hold.
The cases for functions, classes, symbols, `toJSON` and circular values
are not ported: an arena holds none of them.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _helpers import json_value
from gql_execution.value import UNDEFINED, ValueKind, Values, inspect


def show(text: String) raises -> String:
    var values = Values()
    return inspect(values, json_value(values, text))


def test_value_kind() raises:
    assert_true(ValueKind.ERROR.is_valid())
    assert_false(ValueKind(9).is_valid())
    assert_equal(ValueKind.HANDLE.text(), "handle")
    assert_equal(ValueKind(9).text(), "<invalid>")
    assert_equal(String(ValueKind.OBJECT), "object")


def test_inspect_undefined_and_null() raises:
    var values = Values()
    assert_equal(inspect(values, UNDEFINED), "undefined")
    assert_equal(inspect(values, values.add_undefined()), "undefined")
    assert_equal(show("null"), "null")


def test_inspect_booleans_numbers_and_strings() raises:
    assert_equal(show("true"), "true")
    assert_equal(show("false"), "false")
    assert_equal(show("0"), "0")
    assert_equal(show("3.14"), "3.14")
    assert_equal(show("-0.5e30"), "-5e+29")
    assert_equal(show('""'), '""')
    assert_equal(show('"abc"'), '"abc"')
    assert_equal(show('"\\""'), '"\\""')


def test_inspect_arrays() raises:
    assert_equal(show("[]"), "[]")
    assert_equal(show("[null]"), "[null]")
    assert_equal(show("[1, null]"), "[1, null]")
    assert_equal(show('[["a", "b"], "c"]'), '[["a", "b"], "c"]')
    assert_equal(show("[[[]]]"), "[[[]]]")
    assert_equal(show('[[["a"]]]'), "[[[Array]]]")


def test_inspect_overflowing_arrays() raises:
    assert_equal(
        show("[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]"),
        "[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]",
    )
    assert_equal(
        show("[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"),
        "[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, ... 1 more item]",
    )
    assert_equal(
        show("[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]"),
        "[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, ... 2 more items]",
    )


def test_inspect_objects() raises:
    assert_equal(show("{}"), "{}")
    assert_equal(show('{"a": 1}'), "{ a: 1 }")
    assert_equal(show('{"a": 1, "b": 2}'), "{ a: 1, b: 2 }")
    assert_equal(show('{"array": [null, 0]}'), "{ array: [null, 0] }")
    assert_equal(show('{"a": {"b": {}}}'), "{ a: { b: {} } }")
    assert_equal(show('{"a": {"b": {"c": 1}}}'), "{ a: { b: [Object] } }")


def test_inspect_handles_and_errors() raises:
    var values = Values()
    assert_equal(inspect(values, values.add_handle(3, 4)), "{}")
    assert_equal(inspect(values, values.add_error("bad")), "{}")


def test_build_and_read() raises:
    var values = Values()
    var list = json_value(values, '[1, "two", true]')
    assert_equal(values.length(list), 3)
    assert_equal(values.string(values.item(list, 1)), "two")
    assert_equal(values.item(list, 3), UNDEFINED)
    assert_equal(values.length(values.add_number(1)), 0)
    var handle = values.add_handle(-2, 7, 1, 2)
    assert_equal(values.tag(handle), -2)
    assert_equal(values.id(handle), 7)
    assert_equal(values.handle_first(handle), 1)
    assert_equal(values.handle_second(handle), 2)
    assert_equal(values.get(list, "x"), UNDEFINED)
    assert_true(values.is_nullish(UNDEFINED))
    assert_true(values.is_nullish(values.add_null()))
    assert_false(values.is_nullish(list))


def test_set_replaces_a_member_in_place() raises:
    var values = Values()
    var object = json_value(values, '{"a": 1, "b": 2}')
    values.set(object, "a", values.add_string("x"))
    values.set(object, "c", values.add_bool(False))
    assert_equal(inspect(values, object), '{ a: "x", b: 2, c: false }')


def test_member_compares_keys() raises:
    var values = Values()
    var object = json_value(values, '{"ab": 1, "ac": 2, "a": 3}')
    assert_equal(values.number(values.member(object, "ac")), 2)
    assert_equal(values.number(values.member(object, "a")), 3)
    assert_equal(values.member(object, "ad"), UNDEFINED)


def test_copy() raises:
    var values = Values()
    assert_equal(values.copy(UNDEFINED), UNDEFINED)
    var object = json_value(values, '{"a": [1, {"b": "c"}], "d": null}')
    var copy = values.copy(object)
    assert_true(copy != object)
    assert_equal(inspect(values, copy), "{ a: [1, [Object]], d: null }")
    var list = values.add_list()
    values.append(list, values.copy(values.get(object, "d")))
    assert_equal(inspect(values, list), "[null]")
    assert_equal(inspect(values, object), "{ a: [1, [Object]], d: null }")


def test_add_json_keeps_the_last_duplicate_key() raises:
    assert_equal(show('{"a": 1, "b": 2, "a": 3}'), "{ a: 3, b: 2 }")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
