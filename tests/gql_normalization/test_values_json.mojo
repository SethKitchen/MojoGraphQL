# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_normalization.values` and `gql_normalization.variables_json`.

These are not from upstream. They check the JSON that graphql-go-tools
`ValueToJSON`, `sjson` v1.0.4 and `jsonparser.Set` write, case by case.
"""

from _norm import schema_of
from gql_language.ast import Document, NO_NODE, Role
from gql_language.parser import parse
from gql_language.printer import print_node
from gql_normalization.values import (
    add_type_node,
    append_json_string,
    contains_variable,
    is_list,
    is_non_null,
    list_or_name,
    list_wraps,
    type_ref_of,
    unwrap,
    value_to_json,
)
from gql_normalization.variables_json import (
    delete_member,
    elements,
    json_kind,
    jsonparser_set,
    members,
    set_path,
    set_raw,
    top_level_member,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _value(document: Document) -> Int:
    """Return the value of the first argument of the first field."""
    var operation = document.first_child(document.root)
    var field = document.first_child(
        document.child(operation, Role.SELECTION_SET)
    )
    return document.child(document.child(field, Role.ARGUMENT), Role.VALUE)


def _json(text: StringSlice, variables: StringSlice = "") raises -> String:
    """Return `{ f(a: <text>) }`'s value as JSON."""
    var document = parse("{ f(a: " + String(text) + ") }")
    return value_to_json(document, _value(document), String(variables))


def test_value_to_json_scalars() raises:
    assert_equal(_json("null"), "null")
    assert_equal(_json("RED"), '"RED"')
    assert_equal(_json("true"), "true")
    assert_equal(_json("false"), "false")
    assert_equal(_json("-12"), "-12")
    assert_equal(_json("1.5e3"), "1.5e3")
    assert_equal(_json('"a\\"b"'), '"a\\"b"')


def test_value_to_json_block_string() raises:
    assert_equal(_json('"""a "q" \\\\ b"""'), '"a \\"q\\" \\\\\\\\ b"')
    var out = String()
    append_json_string(out, "x\n\r\t\x08\x0c\x01\x1f  éy")
    assert_equal(out, '"x\\n\\r\\t\\b\\f\\u0001\\u001f\\u2028\\u2029éy"')
    var plain = String()
    append_json_string(plain, "€†")
    assert_equal(plain, '"€†"')


def test_value_to_json_lists_and_objects() raises:
    assert_equal(_json("[1, [2, 3], []]"), "[1,[2,3],[]]")
    assert_equal(_json('{a: 1, b: {c: "x"}}'), '{"a":1,"b":{"c":"x"}}')
    assert_equal(_json("{a: $x, b: 2}"), '{"b":2}')
    assert_equal(_json("{b: 2, a: $x}"), '{"b":2}')
    assert_equal(_json("{a: $x, b: 2}", '{"x":"s"}'), '{"a":"s","b":2}')
    assert_equal(_json("$x", '{"x":[1,2]}'), "[1,2]")
    assert_equal(_json("$x", '{"y":1}'), "null")


def test_contains_variable() raises:
    var cases: List[String] = ["$a", "[1, $a]", "{x: {y: $a}}"]
    for text in cases:
        var document = parse("{ f(a: " + text + ") }")
        assert_true(contains_variable(document, _value(document)))
    var none: List[String] = ["1", "[1, [2]]", "{x: {y: 1}}"]
    for text in none:
        var document = parse("{ f(a: " + text + ") }")
        assert_false(contains_variable(document, _value(document)))


def test_type_refs() raises:
    var schema = schema_of("type Query { a(i: Int): String }")
    var document = parse("query ($a: [[String!]]!, $b: Int, $c: Unknown) { a }")
    var operation = document.first_child(document.root)
    var definitions = document.children(operation, Role.VARIABLE_DEFINITION)
    var a = type_ref_of(
        schema, document, document.child(definitions[0], Role.TYPE)
    )
    assert_true(is_non_null(a))
    assert_true(is_list(a))
    assert_equal(list_wraps(a), 2)
    assert_false(is_non_null(list_or_name(a)))
    assert_true(is_non_null(unwrap(unwrap(list_or_name(a)))))
    var b = type_ref_of(
        schema, document, document.child(definitions[1], Role.TYPE)
    )
    assert_false(is_non_null(b))
    assert_false(is_list(b))
    assert_equal(list_wraps(b), 0)
    var c = type_ref_of(
        schema, document, document.child(definitions[2], Role.TYPE)
    )
    assert_equal(Int(c.named), -1)
    var wrapped = add_type_node(document, schema, a)
    assert_equal(print_node(document, wrapped), "[[String!]]!")
    var named = add_type_node(document, schema, b)
    assert_equal(print_node(document, named), "Int")


def test_members() raises:
    var text = (
        ' { "a" : 1 , "b\\"c": "x\\"y", "d": [1, {"e": "]"}], "f": {"g":'
        " [true]} } "
    )
    var found = members(text)
    assert_equal(len(found), 4)
    assert_equal(found[0].key(text), "a")
    assert_equal(found[0].value(text), "1")
    assert_equal(found[1].value(text), '"x\\"y"')
    assert_true(found[1].is_string(text))
    assert_false(found[0].is_string(text))
    assert_equal(found[2].value(text), '[1, {"e": "]"}]')
    assert_equal(found[3].value(text), '{"g": [true]}')
    assert_equal(len(members("[1]")), 0)
    assert_equal(len(members("")), 0)
    assert_equal(len(members("{}")), 0)
    assert_equal(top_level_member(text, "d"), 2)
    assert_equal(top_level_member(text, "z"), -1)


def test_set_raw() raises:
    assert_equal(set_raw("", "a", "1"), '{"a":1}')
    assert_equal(set_raw("null", "a", "1"), '{"a":1}')
    assert_equal(set_raw("{}", "a", "1"), '{"a":1}')
    assert_equal(set_raw(' {"b":2}', "a", "1"), '{"a":1,"b":2}')
    assert_equal(set_raw('{"a":2,"b":3}', "a", "[1]"), '{"a":[1],"b":3}')


def test_jsonparser_set() raises:
    assert_equal(jsonparser_set("{}", "a", "1"), '{"a":1}')
    assert_equal(jsonparser_set('{"b":2} ', "a", "1"), '{"b":2,"a":1} ')
    assert_equal(jsonparser_set('{"a":2}', "a", "3"), '{"a":3}')


def test_delete_member() raises:
    assert_equal(delete_member('{"a":1,"b":2,"c":3}', "a"), '{"b":2,"c":3}')
    assert_equal(delete_member('{"a":1 , "b":2}', "a"), '{ "b":2}')
    assert_equal(delete_member('{"a":1,"b":2,"c":3}', "b"), '{"a":1,"c":3}')
    assert_equal(delete_member('{"a":1, "b":2}', "b"), '{"a":1}')
    assert_equal(delete_member('{"a":1}', "a"), "{}")
    assert_equal(delete_member('{"a":1}', "z"), '{"a":1}')


def test_json_kind_and_elements() raises:
    assert_equal(json_kind("  [1]"), UInt8(ord("[")))
    assert_equal(json_kind("   "), 0)
    var text = '[ 1 , "a,b" ,[2], {"x": 1} ]'
    var items = elements(text)
    assert_equal(len(items), 4)
    assert_equal(String(text[byte = items[1][0] : items[1][1]]), '"a,b"')
    assert_equal(String(text[byte = items[3][0] : items[3][1]]), '{"x": 1}')
    assert_equal(len(elements("{}")), 0)
    assert_equal(len(elements("")), 0)
    assert_equal(len(elements("[]")), 0)


def test_set_path() raises:
    assert_equal(
        set_path('{"a":{"b":[1,{"c":2}]}}', ["a", "b", "1", "c"], "[2]"),
        '{"a":{"b":[1,{"c":[2]}]}}',
    )
    assert_equal(set_path('{"a":[1]}', ["a", "5"], "2"), '{"a":[1]}')
    assert_equal(set_path('{"a":[1]}', ["a", "x"], "2"), '{"a":[1]}')
    assert_equal(set_path('{"a":[1]}', ["a", ""], "2"), '{"a":[1]}')
    assert_equal(set_path('{"a":1}', ["b", "c"], "2"), '{"b":{"c":2},"a":1}')
    assert_equal(set_path("[1,2]", ["1"], "3"), "[1,3]")


def test_white_space_and_truncated_text() raises:
    var spaced = '{\n\t"a"\r:\t1\n,"b": 2\r, "c": 3\t, "d": 4 }'
    var found = members(spaced)
    assert_equal(len(found), 4)
    assert_equal(found[0].value(spaced), "1")
    assert_equal(found[1].value(spaced), "2")
    assert_equal(found[2].value(spaced), "3")
    assert_equal(found[3].value(spaced), "4")
    assert_equal(len(members('{"a":"x')), 1)
    assert_equal(len(members('{"a":[1, 2')), 1)
    assert_equal(len(members('{"a":1')), 1)
    assert_equal(len(members('{"a":1,')), 1)
    assert_equal(len(members("{")), 0)
    assert_equal(len(elements("[1, 2")), 2)
    assert_equal(len(elements("[1,")), 1)
    assert_equal(delete_member('{"a":1', "a"), "{")
    assert_equal(set_path("[1]", ["-1"], "2"), "[1]")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
