# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Unit tests of the value, kind and specifier helpers of gql_client.

These cases have no upstream test file. They reach the paths of the port
that the ported upstream cases do not reach: the kinds and their names,
the interner under many keys, the merge and the order of the values, and
the key paths through `null`. The expected texts follow `JSON.stringify`
and `stringifyForDisplay`.
"""

from gql_client.fuzzy import compile_pattern
from gql_client.key_extractor import extract_key_path, normalize
from gql_client.policies import KeyMode, MergeMode
from gql_client.read import DataState, MissingFieldError
from gql_client.values import (
    Interner,
    Member,
    NO_VALUE,
    NULL_VALUE,
    UNDEFINED_VALUE,
    ValueKind,
    Values,
)
from gql_json.value import JsonDocument
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_kinds_have_names_and_validity() raises:
    assert_true(ValueKind.OBJECT.is_valid())
    assert_false(ValueKind(9).is_valid())
    assert_equal(String(ValueKind.REFERENCE), "REFERENCE")
    assert_equal(String(ValueKind(9)), "INVALID")
    assert_true(KeyMode.FUNCTION.is_valid())
    assert_false(KeyMode(4).is_valid())
    assert_equal(String(KeyMode.FALSE), "KeyMode(1)")
    assert_true(MergeMode.FUNCTION.is_valid())
    assert_false(MergeMode(4).is_valid())
    assert_equal(String(MergeMode.TRUE), "MergeMode(1)")
    assert_true(DataState.COMPLETE.is_valid())
    assert_false(DataState(4).is_valid())
    assert_equal(String(DataState.PARTIAL), "DataState(2)")
    var error = MissingFieldError("Can't find field 'a'", JsonDocument())
    assert_equal(String(error), "Can't find field 'a'")


def test_the_interner_finds_every_key_of_a_large_table() raises:
    var table = Interner()
    var count = 1500
    var index = 0
    while index < count:
        # Keys of many lengths, so a probe meets other lengths and bytes.
        var key = String("k") * (index % 7 + 1) + String(index)
        assert_equal(table.intern(key), index)
        index += 1
    index = 0
    while index < count:
        var key = String("k") * (index % 7 + 1) + String(index)
        assert_equal(table.find(key), index)
        assert_equal(table.intern(key), index)
        index += 1
    assert_equal(table.find("absent"), -1)
    assert_equal(table.find("kk0"), -1)
    assert_equal(table.__len__(), count)


def test_equal_undefined_forms() raises:
    var values = Values()
    assert_true(values.equal(NO_VALUE, UNDEFINED_VALUE))
    assert_false(values.equal(NULL_VALUE, UNDEFINED_VALUE))


def test_merge_of_a_reference_and_a_scalar_and_of_equal_arrays() raises:
    var values = Values()
    var reference = values.add_reference("A:1")
    var number = values.add_int(5)
    assert_equal(values.merge(reference, number), number)
    var items = List[Int]()
    items.append(values.add_int(1))
    var array = values.add_array(items)
    assert_equal(values.merge(array, array), array)


def _object(mut values: Values, keys: List[String]) -> Int:
    """Return an object whose members are the keys with the value 1."""
    var members = List[Member]()
    var index = 0
    while index < len(keys):
        members.append(
            Member(
                Int32(values.names.intern(keys[index])),
                Int32(values.add_int(index + 1)),
            )
        )
        index += 1
    return values.add_object(members)


def test_index_keys_come_first_in_numeric_order() raises:
    var values = Values()
    var reversed: List[String] = ["x", "2", "1"]
    assert_equal(
        values.stringify(_object(values, reversed)), '{"1":3,"2":2,"x":1}'
    )
    var ordered: List[String] = ["1", "2"]
    assert_equal(values.stringify(_object(values, ordered)), '{"1":1,"2":2}')


def test_display_keeps_null_and_shows_undefined() raises:
    var values = Values()
    var members = List[Member]()
    members.append(Member(Int32(values.names.intern("a")), Int32(NULL_VALUE)))
    members.append(
        Member(Int32(values.names.intern("b")), Int32(UNDEFINED_VALUE))
    )
    var object = values.add_object(members)
    assert_equal(
        values.display(object), '{\n  "a": null,\n  "b": <undefined>\n}'
    )
    assert_equal(values.stringify(object), '{"a":null}')


def test_normalize_leaves_out_undefined_members() raises:
    var values = Values()
    var members = List[Member]()
    members.append(
        Member(Int32(values.names.intern("b")), Int32(UNDEFINED_VALUE))
    )
    members.append(Member(Int32(values.names.intern("a")), Int32(NULL_VALUE)))
    var normalized = normalize(values, values.add_object(members))
    assert_equal(values.stringify(normalized), '{"a":null}')


def test_a_key_path_stops_at_null() raises:
    var values = Values()
    var members = List[Member]()
    members.append(Member(Int32(values.names.intern("a")), Int32(NULL_VALUE)))
    var object = values.add_object(members)
    var path: List[String] = ["a", "b"]
    assert_equal(extract_key_path(values, object, path), NULL_VALUE)


def test_a_class_with_two_bytes_before_more_text() raises:
    var pattern = compile_pattern("[ab]c")
    assert_true(pattern.first_match_is_whole("ac"))
    assert_true(pattern.first_match_is_whole("bc"))
    assert_false(pattern.first_match_is_whole("cc"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
