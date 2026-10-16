# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `value_from_ast` and `value_from_ast_untyped`, ported from
graphql-js 16.14.2 `src/utilities/__tests__/valueFromAST-test.ts` and
`src/utilities/__tests__/valueFromASTUntyped-test.ts`.

The types come from SDL. A result shows as `inspect` writes it.

Upstream cases that are not ported:

- `rejects empty input`: there is always a node.
- `convert using parseLiteral from a custom scalar type`: an SDL scalar
  uses `valueFromASTUntyped`, which `test_custom_scalar_literals` checks.
- The internal values of `converts enum values according to input
  coercion rules` (`RED` is 1, `NULL` is null, `NAN` is NaN): an SDL enum
  value is its name. The other checks of the case are ported.
- The variable values `undefined` and `NaN`, which JSON cannot hold, are
  added to the arena directly.
"""

from std.math import nan
from std.testing import TestSuite, assert_equal
from _helpers import json_value
from gql_execution.coerce import value_from_ast, value_from_ast_untyped
from gql_execution.value import UNDEFINED, Values, inspect
from gql_language.parser import parse_value
from gql_schema.build import build_schema
from gql_schema.definition import Schema, TypeRef

comptime TYPES = """
enum TestColor { RED GREEN BLUE NULL NAN NO_CUSTOM_VALUE }
input TestInput { int: Int = 42 bool: Boolean requiredBool: Boolean! }
input TestOneOfInput @oneOf { a: String b: String }
scalar Custom
"""


def _type(type: String) raises -> Tuple[Schema, TypeRef]:
    var schema = build_schema(TYPES + "type Query { f(a: " + type + "): Int }")
    var field = schema.field_named(schema.type_named("Query"), "f")
    var ref_ = schema.input_values[schema.argument_named(field, "a")].type
    return (schema^, ref_)


def value_from(
    text: String, type: String, variables: String = ""
) raises -> String:
    var found = _type(type)
    var values = Values()
    var vars = UNDEFINED
    if variables != "":
        vars = json_value(values, variables)
    var document = parse_value(text)
    var result = value_from_ast(
        found[0], document, document.root, found[1], values, vars
    )
    return inspect(values, result)


def test_converts_according_to_input_coercion_rules() raises:
    assert_equal(value_from("true", "Boolean"), "true")
    assert_equal(value_from("false", "Boolean"), "false")
    assert_equal(value_from("123", "Int"), "123")
    assert_equal(value_from("123", "Float"), "123")
    assert_equal(value_from("123.456", "Float"), "123.456")
    assert_equal(value_from('"abc123"', "String"), '"abc123"')
    assert_equal(value_from("123456", "ID"), '"123456"')
    assert_equal(value_from('"123456"', "ID"), '"123456"')


def test_does_not_convert_when_input_coercion_rules_reject_a_value() raises:
    assert_equal(value_from("123", "Boolean"), "undefined")
    assert_equal(value_from("123.456", "Int"), "undefined")
    assert_equal(value_from("true", "Int"), "undefined")
    assert_equal(value_from('"123"', "Int"), "undefined")
    assert_equal(value_from('"123"', "Float"), "undefined")
    assert_equal(value_from("123", "String"), "undefined")
    assert_equal(value_from("true", "String"), "undefined")
    assert_equal(value_from("123.456", "String"), "undefined")


def test_converts_enum_values_according_to_input_coercion_rules() raises:
    assert_equal(value_from("RED", "TestColor"), '"RED"')
    assert_equal(value_from("BLUE", "TestColor"), '"BLUE"')
    assert_equal(value_from("3", "TestColor"), "undefined")
    assert_equal(value_from('"BLUE"', "TestColor"), "undefined")
    assert_equal(value_from("null", "TestColor"), "null")
    assert_equal(
        value_from("NO_CUSTOM_VALUE", "TestColor"), '"NO_CUSTOM_VALUE"'
    )
    assert_equal(value_from("PURPLE", "TestColor"), "undefined")


def test_coerces_to_null_unless_non_null() raises:
    assert_equal(value_from("null", "Boolean"), "null")
    assert_equal(value_from("null", "Boolean!"), "undefined")


def test_coerces_lists_of_values() raises:
    assert_equal(value_from("true", "[Boolean]"), "[true]")
    assert_equal(value_from("123", "[Boolean]"), "undefined")
    assert_equal(value_from("null", "[Boolean]"), "null")
    assert_equal(value_from("[true, false]", "[Boolean]"), "[true, false]")
    assert_equal(value_from("[true, 123]", "[Boolean]"), "undefined")
    assert_equal(value_from("[true, null]", "[Boolean]"), "[true, null]")
    assert_equal(value_from("{ true: true }", "[Boolean]"), "undefined")


def test_coerces_non_null_lists_of_values() raises:
    assert_equal(value_from("true", "[Boolean]!"), "[true]")
    assert_equal(value_from("123", "[Boolean]!"), "undefined")
    assert_equal(value_from("null", "[Boolean]!"), "undefined")
    assert_equal(value_from("[true, false]", "[Boolean]!"), "[true, false]")
    assert_equal(value_from("[true, 123]", "[Boolean]!"), "undefined")
    assert_equal(value_from("[true, null]", "[Boolean]!"), "[true, null]")


def test_coerces_lists_of_non_null_values() raises:
    assert_equal(value_from("true", "[Boolean!]"), "[true]")
    assert_equal(value_from("123", "[Boolean!]"), "undefined")
    assert_equal(value_from("null", "[Boolean!]"), "null")
    assert_equal(value_from("[true, false]", "[Boolean!]"), "[true, false]")
    assert_equal(value_from("[true, 123]", "[Boolean!]"), "undefined")
    assert_equal(value_from("[true, null]", "[Boolean!]"), "undefined")


def test_coerces_non_null_lists_of_non_null_values() raises:
    assert_equal(value_from("true", "[Boolean!]!"), "[true]")
    assert_equal(value_from("123", "[Boolean!]!"), "undefined")
    assert_equal(value_from("null", "[Boolean!]!"), "undefined")
    assert_equal(value_from("[true, false]", "[Boolean!]!"), "[true, false]")
    assert_equal(value_from("[true, 123]", "[Boolean!]!"), "undefined")
    assert_equal(value_from("[true, null]", "[Boolean!]!"), "undefined")


def test_coerces_input_objects_according_to_input_coercion_rules() raises:
    assert_equal(value_from("null", "TestInput"), "null")
    assert_equal(value_from("123", "TestInput"), "undefined")
    assert_equal(value_from("[]", "TestInput"), "undefined")
    assert_equal(
        value_from("{ int: 123, requiredBool: false }", "TestInput"),
        "{ int: 123, requiredBool: false }",
    )
    assert_equal(
        value_from("{ bool: true, requiredBool: false }", "TestInput"),
        "{ int: 42, bool: true, requiredBool: false }",
    )
    assert_equal(
        value_from("{ int: true, requiredBool: true }", "TestInput"),
        "undefined",
    )
    assert_equal(value_from("{ requiredBool: null }", "TestInput"), "undefined")
    assert_equal(value_from("{ bool: true }", "TestInput"), "undefined")
    assert_equal(value_from('{ a: "abc" }', "TestOneOfInput"), '{ a: "abc" }')
    assert_equal(value_from('{ b: "def" }', "TestOneOfInput"), '{ b: "def" }')
    assert_equal(
        value_from('{ a: "abc", b: null }', "TestOneOfInput"), "undefined"
    )
    assert_equal(value_from("{ a: null }", "TestOneOfInput"), "undefined")
    assert_equal(value_from("{ a: 1 }", "TestOneOfInput"), "undefined")
    assert_equal(
        value_from('{ a: "abc", b: "def" }', "TestOneOfInput"), "undefined"
    )
    assert_equal(value_from("{}", "TestOneOfInput"), "undefined")
    assert_equal(value_from('{ c: "abc" }', "TestOneOfInput"), "undefined")


def _with_undefined(text: String, type: String) raises -> String:
    """Run `value_from` with the variables `{ var: undefined, foo:
    undefined }`."""
    var found = _type(type)
    var values = Values()
    var vars = values.add_object()
    values.add_member(vars, "var", values.add_undefined())
    values.add_member(vars, "foo", values.add_undefined())
    var document = parse_value(text)
    return inspect(
        values,
        value_from_ast(
            found[0], document, document.root, found[1], values, vars
        ),
    )


def test_accepts_variable_values_assuming_already_coerced() raises:
    assert_equal(value_from("$var", "Boolean", "{}"), "undefined")
    assert_equal(value_from("$var", "Boolean", '{"var": true}'), "true")
    assert_equal(value_from("$var", "Boolean", '{"var": null}'), "null")
    assert_equal(value_from("$var", "Boolean!", '{"var": null}'), "undefined")
    assert_equal(value_from("$toString", "Boolean", "{}"), "undefined")
    assert_equal(_with_undefined("$var", "Boolean"), "undefined")
    assert_equal(value_from("$var", "Boolean"), "undefined")


def test_asserts_variables_are_provided_as_items_in_lists() raises:
    assert_equal(value_from("[ $foo ]", "[Boolean]", "{}"), "[null]")
    assert_equal(_with_undefined("[ $foo ]", "[Boolean]"), "[null]")
    assert_equal(value_from("[ $foo ]", "[Boolean!]", "{}"), "undefined")
    assert_equal(value_from("[ $toString ]", "[Boolean]", "{}"), "[null]")
    assert_equal(
        value_from("[ $foo ]", "[Boolean!]", '{"foo": true}'), "[true]"
    )
    assert_equal(value_from("$foo", "[Boolean!]", '{"foo": true}'), "true")
    assert_equal(value_from("$foo", "[Boolean!]", '{"foo": [true]}'), "[true]")


def test_omits_input_object_fields_for_unprovided_variables() raises:
    assert_equal(
        value_from(
            "{ int: $foo, bool: $foo, requiredBool: true }", "TestInput", "{}"
        ),
        "{ int: 42, requiredBool: true }",
    )
    assert_equal(
        value_from("{ requiredBool: $foo }", "TestInput", "{}"), "undefined"
    )
    assert_equal(
        value_from("{ requiredBool: $foo }", "TestInput", '{"foo": true}'),
        "{ int: 42, requiredBool: true }",
    )
    assert_equal(
        value_from("{ int: $toString, requiredBool: true }", "TestInput", "{}"),
        "{ int: 42, requiredBool: true }",
    )


def test_custom_scalar_literals() raises:
    assert_equal(
        value_from(
            '{ a: [1, "x", B, null, true], a: $v }', "Custom", '{"v": 2}'
        ),
        "{ a: 2 }",
    )


def test_an_output_type_raises() raises:
    var schema = build_schema("type Query { f: Int }")
    var values = Values()
    var document = parse_value("{}")
    var raised = False
    try:
        _ = value_from_ast(
            schema,
            document,
            document.root,
            TypeRef.of(schema.type_named("Query")),
            values,
            UNDEFINED,
        )
    except e:
        raised = True
        assert_equal(String(e), "Unexpected input type: Query")
    assert_equal(raised, True)


# --- valueFromASTUntyped-test.ts -------------------------------------------


def untyped(text: String, variables: String = "") raises -> String:
    var values = Values()
    var vars = UNDEFINED
    if variables != "":
        vars = json_value(values, variables)
    var document = parse_value(text)
    return inspect(
        values, value_from_ast_untyped(document, document.root, values, vars)
    )


def test_parses_simple_values() raises:
    assert_equal(untyped("null"), "null")
    assert_equal(untyped("true"), "true")
    assert_equal(untyped("false"), "false")
    assert_equal(untyped("123"), "123")
    assert_equal(untyped("123.456"), "123.456")
    assert_equal(untyped('"abc123"'), '"abc123"')


def test_parses_lists_of_values() raises:
    assert_equal(untyped("[true, false]"), "[true, false]")
    assert_equal(untyped("[true, 123.45]"), "[true, 123.45]")
    assert_equal(untyped("[true, null]"), "[true, null]")
    assert_equal(untyped('[true, ["foo", 1.2]]'), '[true, ["foo", 1.2]]')


def test_parses_input_objects() raises:
    assert_equal(
        untyped("{ int: 123, bool: false }"), "{ int: 123, bool: false }"
    )
    assert_equal(untyped('{ foo: [ { bar: "baz"} ] }'), "{ foo: [[Object]] }")


def test_parses_enum_values_as_plain_strings() raises:
    assert_equal(untyped("TEST_ENUM_VALUE"), '"TEST_ENUM_VALUE"')
    assert_equal(untyped("[TEST_ENUM_VALUE]"), '["TEST_ENUM_VALUE"]')


def test_parses_variables() raises:
    assert_equal(untyped("$testVariable", '{"testVariable": "foo"}'), '"foo"')
    assert_equal(
        untyped("[$testVariable]", '{"testVariable": "foo"}'), '["foo"]'
    )
    assert_equal(
        untyped("{a:[$testVariable]}", '{"testVariable": "foo"}'),
        '{ a: ["foo"] }',
    )
    assert_equal(untyped("$testVariable", '{"testVariable": null}'), "null")
    var values = Values()
    var vars = values.add_object()
    values.add_member(
        vars, "testVariable", values.add_number(nan[DType.float64]())
    )
    var document = parse_value("$testVariable")
    assert_equal(
        inspect(
            values,
            value_from_ast_untyped(document, document.root, values, vars),
        ),
        "NaN",
    )
    assert_equal(untyped("$testVariable", "{}"), "undefined")
    assert_equal(untyped("$testVariable"), "undefined")
    assert_equal(untyped("[$testVariable]", "{}"), "[undefined]")


def test_int_and_id_literals_out_of_range_or_of_another_kind() raises:
    assert_equal(value_from("2147483648", "Int"), "undefined")
    assert_equal(value_from("-2147483649", "Int"), "undefined")
    assert_equal(value_from("1.5", "ID"), "undefined")
    assert_equal(value_from("true", "ID"), "undefined")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
