# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_client.values`.

`Values` has no upstream test file: upstream keeps plain JavaScript
values. The expected texts of `canonical_stringify` and of the key order
are the Node.js output of Apollo Client 4.3.3 `canonicalStringify` and of
`JSON.stringify`.
"""

from gql_client.values import (
    FALSE_VALUE,
    Interner,
    Member,
    NO_VALUE,
    NULL_VALUE,
    TRUE_VALUE,
    TYPENAME,
    UNDEFINED_VALUE,
    ValueKind,
    Values,
    array_index,
    utf16_less,
)
from gql_json.value import JsonDocument
from gql_json.writer import stringify
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_true,
)

from _helpers import json


def _value(mut values: Values, text: StringSlice) raises -> Int:
    """Add a JSON text to an arena."""
    var document = json(text)
    return values.from_json(document, document.root)


def test_value_kind() raises:
    assert_true(ValueKind.OBJECT.is_valid())
    assert_false(ValueKind(9).is_valid())
    assert_equal(ValueKind.REFERENCE.text(), "REFERENCE")
    assert_equal(ValueKind(9).text(), "INVALID")
    assert_equal(String(ValueKind.ARRAY), "ARRAY")


def test_interner() raises:
    var table = Interner()
    assert_equal(table.intern("a"), 0)
    assert_equal(table.intern("b"), 1)
    assert_equal(table.intern("a"), 0)
    assert_equal(table.find("b"), 1)
    assert_equal(table.find("c"), -1)
    assert_equal(String(table.text(1)), "b")
    assert_equal(table.__len__(), 2)
    var values = Values()
    assert_equal(String(values.names.text(TYPENAME)), "__typename")


def test_array_index() raises:
    assert_equal(array_index("0"), 0)
    assert_equal(array_index("42"), 42)
    assert_equal(array_index("4294967294"), 4294967294)
    assert_equal(array_index("4294967295"), -1)
    assert_equal(array_index("01"), -1)
    assert_equal(array_index(""), -1)
    assert_equal(array_index("12345678901"), -1)
    assert_equal(array_index("1a"), -1)


def test_utf16_order() raises:
    assert_true(utf16_less("a", "b"))
    assert_true(utf16_less("a", "ab"))
    assert_false(utf16_less("ab", "a"))
    assert_false(utf16_less("a", "a"))
    # U+1F600 is a surrogate pair, so it sorts before U+FF61 in JavaScript,
    # though its UTF-8 bytes sort after.
    assert_true(utf16_less("\U0001F600", "｡"))
    assert_false(utf16_less("｡", "\U0001F600"))
    assert_true(utf16_less("é", "\U0001F600"))
    assert_true(utf16_less("x\U0001F600", "x\U0001F601"))


def test_canonical_stringify_sorts_keys() raises:
    var values = Values()
    var object = _value(values, '{"b":1,"10":2,"9":3,"a":4}')
    assert_equal(
        values.canonical_stringify(object), '{"9":3,"10":2,"a":4,"b":1}'
    )
    assert_equal(values.stringify(object), '{"9":3,"10":2,"b":1,"a":4}')
    var text = '{"\\uff61":1,"\\ud83d\\ude00":2,"a":3,"\\u00e9":4}'
    assert_equal(
        values.canonical_stringify(_value(values, text)),
        '{"a":3,"é":4,"\U0001F600":2,"｡":1}',
    )
    assert_equal(
        values.canonical_stringify(
            _value(values, '{"z":[{"y":1,"x":2}],"a":null}')
        ),
        '{"a":null,"z":[{"x":2,"y":1}]}',
    )
    var keys = _value(values, '{"4294967294":1,"4294967295":2,"01":3,"0":4}')
    assert_equal(
        values.stringify(keys), '{"0":4,"4294967294":1,"4294967295":2,"01":3}'
    )


def test_undefined_is_left_out_of_objects_and_null_in_arrays() raises:
    var values = Values()
    var members = List[Member]()
    members.append(
        Member(Int32(values.names.intern("a")), Int32(UNDEFINED_VALUE))
    )
    members.append(Member(Int32(values.names.intern("b")), Int32(TRUE_VALUE)))
    var object = values.add_object(members)
    assert_equal(values.stringify(object), '{"b":true}')
    assert_equal(values.canonical_stringify(object), '{"b":true}')
    var items: List[Int] = [UNDEFINED_VALUE, FALSE_VALUE, NULL_VALUE]
    var array = values.add_array(items)
    assert_equal(values.stringify(array), "[null,false,null]")
    assert_equal(values.stringify(NO_VALUE), "null")
    var document = JsonDocument()
    document.root = values.to_json(document, object)
    assert_equal(stringify(document, document.root), '{"b":true}')
    document.root = values.to_json(document, array)
    assert_equal(stringify(document, document.root), "[null,false,null]")


def test_display_keeps_undefined_and_truncates() raises:
    var values = Values()
    var members = List[Member]()
    members.append(
        Member(Int32(values.names.intern("a")), Int32(UNDEFINED_VALUE))
    )
    var object = values.add_object(members)
    assert_equal(values.display(object), '{\n  "a": <undefined>\n}')
    assert_equal(values.display(values.add_string("as is")), "as is")
    var long = String("")
    var index = 0
    while index < 600:
        long += "é"
        index += 1
    var shown = values.display(values.add_array([values.add_string(long)]))
    assert_true(shown.byte_length() <= 1000)
    assert_true(shown.startswith('[\n  "é'))
    assert_equal(shown.byte_length(), 999)


def test_numbers_take_their_javascript_text() raises:
    var values = Values()
    assert_equal(String(values.text(_value(values, "1.50"))), "1.5")
    assert_equal(String(values.text(_value(values, "1e21"))), "1e+21")
    assert_equal(String(values.text(values.add_int(-3))), "-3")
    assert_equal(
        String(values.text(values.add_number_text("2.0".as_bytes()))), "2"
    )
    var zero: Float64 = 0.0
    assert_equal(values.add_float(zero / zero), NULL_VALUE)
    assert_true(values.text_equals(values.add_int(7), "7"))
    assert_false(values.text_equals(TRUE_VALUE, "true"))
    assert_equal(String(values.text(_value(values, '"a\\nb"'))), "a\nb")


def test_truthy_follows_javascript() raises:
    var values = Values()
    assert_false(values.truthy(NULL_VALUE))
    assert_false(values.truthy(NO_VALUE))
    assert_false(values.truthy(UNDEFINED_VALUE))
    assert_false(values.truthy(FALSE_VALUE))
    assert_true(values.truthy(TRUE_VALUE))
    assert_false(values.truthy(values.add_int(0)))
    assert_true(values.truthy(values.add_int(10)))
    assert_true(values.truthy(values.add_float(0.5)))
    assert_false(values.truthy(values.add_string("")))
    assert_true(values.truthy(values.add_string("0")))
    assert_true(values.truthy(_value(values, "[]")))
    assert_true(values.truthy(_value(values, "{}")))
    assert_true(values.truthy(values.add_reference("X")))


def test_equal_is_deep() raises:
    var values = Values()
    var a = _value(values, '{"x": [1, {"y": "z"}], "r": {"__ref": "T:1"}}')
    var b = _value(values, '{"r": {"__ref": "T:1"}, "x": [1, {"y": "z"}]}')
    assert_true(values.equal(a, b))
    assert_false(
        values.equal(
            a, _value(values, '{"x": [1, {"y": "w"}], "r": {"__ref": "T:1"}}')
        )
    )
    assert_false(
        values.equal(a, _value(values, '{"x": [1], "r": {"__ref": "T:1"}}'))
    )
    assert_false(
        values.equal(a, _value(values, '{"x": [1, {"y": "z"}], "s": 1}'))
    )
    assert_false(
        values.equal(_value(values, "[1, 2]"), _value(values, "[1, 3]"))
    )
    assert_false(values.equal(_value(values, "[1, 2]"), _value(values, "[1]")))
    assert_false(values.equal(values.add_int(1), values.add_string("1")))
    assert_true(values.equal(NULL_VALUE, NULL_VALUE))
    assert_true(
        values.equal(values.add_reference("A"), values.add_reference("A"))
    )
    assert_false(
        values.equal(values.add_reference("A"), values.add_reference("B"))
    )
    var extras = _value(values, '{"__ref": "A", "id": 1}')
    assert_false(values.equal(values.add_reference("A"), extras))
    assert_true(values.equal(extras, _value(values, '{"__ref": "A", "id": 1}')))


def test_merge_is_the_default_deep_merger() raises:
    var values = Values()
    var target = _value(values, '{"a": 1, "b": {"c": 2, "d": [1, 2]}}')
    var source = _value(values, '{"b": {"d": [3], "e": 4}, "f": 5}')
    var merged = values.merge(target, source)
    assert_equal(
        values.stringify(merged), '{"a":1,"b":{"c":2,"d":[3,2],"e":4},"f":5}'
    )
    assert_true(
        values.equal(values.merge(target, _value(values, '{"a": 1}')), target)
    )
    var longer = values.merge(_value(values, "[1]"), _value(values, "[1, 2]"))
    assert_equal(values.stringify(longer), "[1,2]")
    var same = _value(values, "[1, 2]")
    assert_true(values.equal(values.merge(same, _value(values, "[1]")), same))
    var scalar = values.add_int(9)
    assert_equal(values.merge(target, scalar), scalar)
    assert_equal(values.merge(NO_VALUE, target), target)


def test_merge_into_a_reference_keeps_the_extra_members() raises:
    var values = Values()
    var reference = values.add_reference("Gene:1")
    var merged = values.merge(reference, _value(values, '{"id": "1"}'))
    assert_true(values.is_reference(merged))
    assert_equal(values.stringify(merged), '{"__ref":"Gene:1","id":"1"}')
    assert_equal(
        values.merge(reference, values.add_reference("Gene:1")), reference
    )
    var other = values.merge(merged, values.add_reference("Gene:2"))
    assert_equal(values.stringify(other), '{"__ref":"Gene:2","id":"1"}')
    var both = values.merge(
        merged, _value(values, '{"__ref": "Gene:1", "x": 2}')
    )
    assert_equal(values.stringify(both), '{"__ref":"Gene:1","id":"1","x":2}')
    assert_equal(
        values.merge(merged, _value(values, '{"__ref": "Gene:1"}')), merged
    )
    var plain = _value(values, '{"a": 1}')
    var replaced = values.merge(plain, reference)
    assert_equal(replaced, reference)


def test_references_with_extra_members_round_trip() raises:
    var values = Values()
    var value = _value(values, '{"__ref": "T:1", "id": 1}')
    assert_true(values.is_reference(value))
    assert_equal(String(values.ref_text(value)), "T:1")
    assert_equal(values.stringify(value), '{"__ref":"T:1","id":1}')
    assert_equal(values.display(value), '{\n  "__ref": "T:1",\n  "id": 1\n}')
    var document = JsonDocument()
    document.root = values.to_json(document, value)
    assert_equal(stringify(document, document.root), '{"__ref":"T:1","id":1}')
    var plain = _value(values, '{"__ref": "T:2"}')
    assert_equal(values.ref_extras(plain), NO_VALUE)
    var not_a_reference = _value(values, '{"__ref": 3}')
    assert_true(values.is_object(not_a_reference))


def test_members_and_items() raises:
    var values = Values()
    var object = _value(values, '{"a": 1, "b": 2, "a": 3}')
    assert_equal(values.length(object), 2)
    assert_equal(values.stringify(values.get(object, "a")), "3")
    assert_equal(values.get(object, "missing"), NO_VALUE)
    assert_equal(values.get(object, "never interned"), NO_VALUE)
    assert_equal(values.find(values.add_int(1), TYPENAME), NO_VALUE)
    assert_equal(len(values.members(object)), 2)
    assert_equal(len(values.members(values.add_int(1))), 0)
    assert_equal(len(values.array_items(_value(values, "[1, 2, 3]"))), 3)
    assert_equal(len(values.array_items(object)), 0)
    assert_equal(values.length(values.add_string("abc")), 0)
    assert_true(values.is_non_null_object(object))
    assert_false(values.is_non_null_object(NULL_VALUE))
    var order = values.sorted_members(
        _value(values, '{"b": 1, "2": 2, "a": 3, "1": 4}')
    )
    assert_equal(len(order), 4)
    assert_equal(order[0], 3)
    assert_equal(order[1], 1)
    assert_equal(order[2], 2)
    assert_equal(order[3], 0)


def test_copy_into_keeps_sharing() raises:
    var values = Values()
    var shared = _value(values, '{"x": 1}')
    var items: List[Int] = [shared, shared, values.add_reference("R")]
    var array = values.add_array(items)
    var extras = _value(values, '{"__ref": "S", "k": [true]}')
    var target = Values()
    swap(target.names, values.names)
    swap(target.ids, values.ids)
    var moved = List[Int32](length=len(values.nodes), fill=-1)
    var copy = values.copy_into(target, array, moved)
    var copied_extras = values.copy_into(target, extras, moved)
    assert_equal(target.item(copy, 0), target.item(copy, 1))
    assert_equal(target.stringify(copy), '[{"x":1},{"x":1},{"__ref":"R"}]')
    assert_equal(target.stringify(copied_extras), '{"__ref":"S","k":[true]}')
    assert_equal(values.copy_into(target, NULL_VALUE, moved), NULL_VALUE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
