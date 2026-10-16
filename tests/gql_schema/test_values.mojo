# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.values`, ported from graphql-js 16.14.2
`src/utilities/__tests__/valueFromAST-test.ts`,
`src/utilities/__tests__/valueFromASTUntyped-test.ts`,
`src/utilities/__tests__/astFromValue-test.ts` and the `parseLiteral` and
`serialize` cases of `src/type/__tests__/scalars-test.ts`.

The types come from SDL, so an enum value's internal value is its name and
a custom scalar behaves as one built from SDL. A `serialize` case runs
through `print_ast_from_value`, which serializes and then prints. The
cases that are not upstream were checked against graphql-js 16.14.2 in
Node.js.

Upstream cases that are not ported:

- Every case with variable values (`{ var: true }`, `{ testVariable:
  'foo' }`): the Mojo API has no variables. The cases with no or empty
  variables are ported.
- `valueFromAST(null, ...)`: there is always a node.
- Custom scalars with JavaScript `parseLiteral` or `serialize` functions
  (`passthroughScalar`, `throwScalar`, `returnUndefinedScalar`,
  `returnNullScalar`, `returnCustomClassScalar`): an SDL scalar uses
  `valueFromASTUntyped` and the identity. The `NaN`, `Infinity` and object
  cases of the identity are ported.
- Enum values with custom internal values (`RED: { value: 1 }`, `NULL`,
  `NAN`, `COMPLEX: { value: complexValue }`): SDL enum values are their
  names. The cases are ported with the names as the values.
- A generator as a list value, and objects with `valueOf` or `toJSON`: a
  `JsValues` tree has none of them.
- The `parseValue` cases of `scalars-test.ts`: input coercion of variable
  values is not in this module.
"""

from std.math import inf, nan
from std.memory import bitcast
from _js_values import Js, js, js_number, js_string, js_undefined, show, ref_of
from gql_language.error import GraphQLError
from gql_language.parser import parse_value
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_schema.values import (
    UNDEFINED,
    JsKind,
    JsValues,
    default_value,
    inspect,
    js_number_to_string,
    parse_literal,
    print_ast_from_value,
    print_default,
    value_from_ast,
    value_from_ast_untyped,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


comptime SDL = """
scalar Custom
enum TestColor { RED GREEN BLUE NULL NAN NO_CUSTOM_VALUE }
enum MyEnum { HELLO GOODBYE COMPLEX }
input TestInput { int: Int = 42 bool: Boolean requiredBool: Boolean! }
input TestOneOfInput @oneOf { a: String b: String }
input MyInputObj { foo: Float bar: MyEnum }
input BadDefault { a: Int! = "x" }
input Empty
enum NoValues
type Query {
  f(a: Int, b: Float, c: String, d: Boolean, e: ID, g: Custom,
    h: TestColor, i: TestInput, j: TestOneOfInput, k: MyInputObj,
    l: BadDefault, m: Empty): Int
}
"""


def make_schema() raises -> Schema:
    """Build the schema the tests use."""
    return build_schema(SDL)


def expect_value(
    schema: Schema, text: String, type: String, expected: String
) raises:
    """Assert `valueFromAST(parseValue(text), type)`, shown in full."""
    var document = parse_value(text)
    var values = JsValues()
    var got = value_from_ast(
        schema, document, document.root, ref_of(schema, type), values
    )
    assert_equal(show(values, got), expected, text + " as " + type)


def expect_untyped(text: String, expected: String) raises:
    """Assert `valueFromASTUntyped(parseValue(text))`, shown in full."""
    var value = js(text)
    assert_equal(show(value.values, value.root), expected, text)


def expect_literal(
    schema: Schema, text: String, type: String, expected: String
) raises:
    """Assert `type.parseLiteral(parseValue(text))`, or its error message."""
    var document = parse_value(text)
    var values = JsValues()
    var got: String
    try:
        var value = parse_literal(
            schema, document, document.root, schema.type_named(type), values
        )
        got = show(values, value)
    except error:
        got = "THROWS " + error.message
    assert_equal(got, expected, text + " as " + type)


def expect_ast(
    schema: Schema, value: Js, type: String, expected: String
) raises:
    """Assert `print(astFromValue(value, type))`: `<null>` for null, and
    `THROWS message` for an error."""
    var got: String
    try:
        var printed = print_ast_from_value(
            schema, value.values, value.root, ref_of(schema, type)
        )
        if printed:
            got = printed.value()
        else:
            got = "<null>"
    except error:
        got = "THROWS " + String(error)
    assert_equal(got, expected, show(value.values, value.root) + " as " + type)


# valueFromAST-test.ts


def test_converts_according_to_input_coercion_rules() raises:
    var s = make_schema()
    expect_value(s, "true", "Boolean", "true")
    expect_value(s, "false", "Boolean", "false")
    expect_value(s, "123", "Int", "123")
    expect_value(s, "123", "Float", "123")
    expect_value(s, "123.456", "Float", "123.456")
    expect_value(s, '"abc123"', "String", '"abc123"')
    expect_value(s, "123456", "ID", '"123456"')
    expect_value(s, '"123456"', "ID", '"123456"')


def test_does_not_convert_when_input_coercion_rules_reject_a_value() raises:
    var s = make_schema()
    expect_value(s, "123", "Boolean", "undefined")
    expect_value(s, "123.456", "Int", "undefined")
    expect_value(s, "true", "Int", "undefined")
    expect_value(s, '"123"', "Int", "undefined")
    expect_value(s, '"123"', "Float", "undefined")
    expect_value(s, "123", "String", "undefined")
    expect_value(s, "true", "String", "undefined")
    expect_value(s, "123.456", "String", "undefined")
    # Not upstream: the Int bounds, and Float overflow to Infinity.
    expect_value(s, "2147483647", "Int", "2147483647")
    expect_value(s, "-2147483648", "Int", "-2147483648")
    expect_value(s, "2147483648", "Int", "undefined")
    expect_value(s, "-2147483649", "Int", "undefined")
    expect_value(s, "1e400", "Float", "Infinity")
    expect_value(s, "ENUM", "ID", "undefined")


def test_convert_using_parse_literal_from_a_custom_scalar_type() raises:
    var s = make_schema()
    expect_value(s, '"value"', "Custom", '"value"')
    expect_value(s, "value", "Custom", '"value"')
    # Not upstream: an object repeats a key; a variable is undefined.
    expect_value(
        s, "{a: 1, b: [x, $v], a: 2}", "Custom", '{a: 2, b: ["x", undefined]}'
    )
    expect_value(s, "[$v]", "Custom", "[undefined]")


def test_converts_enum_values_according_to_input_coercion_rules() raises:
    var s = make_schema()
    expect_value(s, "RED", "TestColor", '"RED"')
    expect_value(s, "BLUE", "TestColor", '"BLUE"')
    expect_value(s, "3", "TestColor", "undefined")
    expect_value(s, '"BLUE"', "TestColor", "undefined")
    expect_value(s, "null", "TestColor", "null")
    expect_value(s, "NULL", "TestColor", '"NULL"')
    expect_value(s, "NULL", "TestColor!", '"NULL"')
    expect_value(s, "NAN", "TestColor", '"NAN"')
    expect_value(s, "NO_CUSTOM_VALUE", "TestColor", '"NO_CUSTOM_VALUE"')
    expect_value(s, "PURPLE", "TestColor", "undefined")


def test_coerces_to_null_unless_non_null() raises:
    var s = make_schema()
    expect_value(s, "null", "Boolean", "null")
    expect_value(s, "null", "Boolean!", "undefined")


def test_coerces_lists_of_values() raises:
    var s = make_schema()
    expect_value(s, "true", "[Boolean]", "[true]")
    expect_value(s, "123", "[Boolean]", "undefined")
    expect_value(s, "null", "[Boolean]", "null")
    expect_value(s, "[true, false]", "[Boolean]", "[true, false]")
    expect_value(s, "[true, 123]", "[Boolean]", "undefined")
    expect_value(s, "[true, null]", "[Boolean]", "[true, null]")
    expect_value(s, "{ true: true }", "[Boolean]", "undefined")
    expect_value(s, "[]", "[Int]", "[]")


def test_coerces_non_null_lists_of_values() raises:
    var s = make_schema()
    expect_value(s, "true", "[Boolean]!", "[true]")
    expect_value(s, "123", "[Boolean]!", "undefined")
    expect_value(s, "null", "[Boolean]!", "undefined")
    expect_value(s, "[true, false]", "[Boolean]!", "[true, false]")
    expect_value(s, "[true, 123]", "[Boolean]!", "undefined")
    expect_value(s, "[true, null]", "[Boolean]!", "[true, null]")


def test_coerces_lists_of_non_null_values() raises:
    var s = make_schema()
    expect_value(s, "true", "[Boolean!]", "[true]")
    expect_value(s, "123", "[Boolean!]", "undefined")
    expect_value(s, "null", "[Boolean!]", "null")
    expect_value(s, "[true, false]", "[Boolean!]", "[true, false]")
    expect_value(s, "[true, 123]", "[Boolean!]", "undefined")
    expect_value(s, "[true, null]", "[Boolean!]", "undefined")


def test_coerces_non_null_lists_of_non_null_values() raises:
    var s = make_schema()
    expect_value(s, "true", "[Boolean!]!", "[true]")
    expect_value(s, "123", "[Boolean!]!", "undefined")
    expect_value(s, "null", "[Boolean!]!", "undefined")
    expect_value(s, "[true, false]", "[Boolean!]!", "[true, false]")
    expect_value(s, "[true, 123]", "[Boolean!]!", "undefined")
    expect_value(s, "[true, null]", "[Boolean!]!", "undefined")


def test_coerces_input_objects_according_to_input_coercion_rules() raises:
    var s = make_schema()
    expect_value(s, "null", "TestInput", "null")
    expect_value(s, "123", "TestInput", "undefined")
    expect_value(s, "[]", "TestInput", "undefined")
    expect_value(
        s,
        "{ int: 123, requiredBool: false }",
        "TestInput",
        "{int: 123, requiredBool: false}",
    )
    expect_value(
        s,
        "{ bool: true, requiredBool: false }",
        "TestInput",
        "{int: 42, bool: true, requiredBool: false}",
    )
    expect_value(
        s, "{ int: true, requiredBool: true }", "TestInput", "undefined"
    )
    expect_value(s, "{ requiredBool: null }", "TestInput", "undefined")
    expect_value(s, "{ bool: true }", "TestInput", "undefined")
    expect_value(s, '{ a: "abc" }', "TestOneOfInput", '{a: "abc"}')
    expect_value(s, '{ b: "def" }', "TestOneOfInput", '{b: "def"}')
    expect_value(s, '{ a: "abc", b: null }', "TestOneOfInput", "undefined")
    expect_value(s, "{ a: null }", "TestOneOfInput", "undefined")
    expect_value(s, "{ a: 1 }", "TestOneOfInput", "undefined")
    expect_value(s, '{ a: "abc", b: "def" }', "TestOneOfInput", "undefined")
    expect_value(s, "{}", "TestOneOfInput", "undefined")
    expect_value(s, '{ c: "abc" }', "TestOneOfInput", "undefined")


def test_coerces_input_objects_not_upstream() raises:
    var s = make_schema()
    # An invalid default is no default, so a non-null field is missing.
    expect_value(s, "{}", "BadDefault", "undefined")
    expect_value(s, "{ a: 1 }", "BadDefault", "{a: 1}")
    expect_value(s, "{}", "Empty", "{}")
    expect_value(s, "{ x: 1 }", "Empty", "{}")
    # The last of repeated fields wins, as `keyMap` keeps it.
    expect_value(
        s,
        "{ int: 1, int: 2, requiredBool: true }",
        "TestInput",
        "{int: 2, requiredBool: true}",
    )


def test_accepts_variable_values_assuming_already_coerced() raises:
    var s = make_schema()
    expect_value(s, "$var", "Boolean", "undefined")
    expect_value(s, "$var", "Boolean!", "undefined")
    expect_value(s, "$toString", "Boolean", "undefined")


def test_asserts_variables_are_provided_as_items_in_lists() raises:
    var s = make_schema()
    expect_value(s, "[ $foo ]", "[Boolean]", "[null]")
    expect_value(s, "[ $foo ]", "[Boolean!]", "undefined")
    expect_value(s, "[ $toString ]", "[Boolean]", "[null]")


def test_omits_input_object_fields_for_unprovided_variables() raises:
    var s = make_schema()
    expect_value(
        s,
        "{ int: $foo, bool: $foo, requiredBool: true }",
        "TestInput",
        "{int: 42, requiredBool: true}",
    )
    expect_value(s, "{ requiredBool: $foo }", "TestInput", "undefined")
    expect_value(
        s,
        "{ int: $toString, requiredBool: true }",
        "TestInput",
        "{int: 42, requiredBool: true}",
    )


def test_value_from_ast_refuses_an_output_type() raises:
    var s = make_schema()
    var document = parse_value("1")
    var values = JsValues()
    var message = String("")
    try:
        _ = value_from_ast(
            s, document, document.root, ref_of(s, "Query"), values
        )
    except error:
        message = String(error)
    assert_equal(message, "Unexpected input type: Query")
    expect_value(s, "null", "[Query]", "null")


def test_default_value() raises:
    var s = make_schema()
    var input = s.type_named("TestInput")
    var values = JsValues()
    var int_field = s.input_field_named(input, "int")
    assert_equal(show(values, default_value(s, int_field, values)), "42")
    var bool_field = s.input_field_named(input, "bool")
    assert_equal(default_value(s, bool_field, values), UNDEFINED)


# valueFromASTUntyped-test.ts


def test_untyped_parses_simple_values() raises:
    expect_untyped("null", "null")
    expect_untyped("true", "true")
    expect_untyped("false", "false")
    expect_untyped("123", "123")
    expect_untyped("123.456", "123.456")
    expect_untyped('"abc123"', '"abc123"')


def test_untyped_parses_lists_of_values() raises:
    expect_untyped("[true, false]", "[true, false]")
    expect_untyped("[true, 123.45]", "[true, 123.45]")
    expect_untyped("[true, null]", "[true, null]")
    expect_untyped('[true, ["foo", 1.2]]', '[true, ["foo", 1.2]]')


def test_untyped_parses_input_objects() raises:
    expect_untyped("{ int: 123, bool: false }", "{int: 123, bool: false}")
    expect_untyped('{ foo: [ { bar: "baz"} ] }', '{foo: [{bar: "baz"}]}')


def test_untyped_parses_enum_values_as_plain_strings() raises:
    expect_untyped("TEST_ENUM_VALUE", '"TEST_ENUM_VALUE"')
    expect_untyped("[TEST_ENUM_VALUE]", '["TEST_ENUM_VALUE"]')


def test_untyped_parses_variables() raises:
    expect_untyped("$testVariable", "undefined")
    expect_untyped("[$testVariable]", "[undefined]")
    expect_untyped("{a:[$testVariable]}", "{a: [undefined]}")


# scalars-test.ts: parseLiteral


def test_int_parse_literal() raises:
    var s = make_schema()
    expect_literal(s, "1", "Int", "1")
    expect_literal(s, "0", "Int", "0")
    expect_literal(s, "-1", "Int", "-1")
    expect_literal(
        s,
        "9876504321",
        "Int",
        (
            "THROWS Int cannot represent non 32-bit signed integer value:"
            " 9876504321"
        ),
    )
    expect_literal(
        s,
        "-9876504321",
        "Int",
        (
            "THROWS Int cannot represent non 32-bit signed integer value:"
            " -9876504321"
        ),
    )
    # A literal of more than 19 digits is still a number, and out of range.
    expect_literal(
        s,
        "1234567890123456789012345",
        "Int",
        (
            "THROWS Int cannot represent non 32-bit signed integer value:"
            " 1234567890123456789012345"
        ),
    )
    expect_literal(
        s, "123456789012345678901234.5", "Float", "1.2345678901234569e+23"
    )
    comptime M = "THROWS Int cannot represent non-integer value: "
    expect_literal(s, "1.0", "Int", M + "1.0")
    expect_literal(s, "null", "Int", M + "null")
    expect_literal(s, '""', "Int", M + '""')
    expect_literal(s, '"123"', "Int", M + '"123"')
    expect_literal(s, "false", "Int", M + "false")
    expect_literal(s, "[1]", "Int", M + "[1]")
    expect_literal(s, "{ value: 1 }", "Int", M + "{value: 1}")
    expect_literal(s, "ENUM_VALUE", "Int", M + "ENUM_VALUE")
    expect_literal(s, "$var", "Int", M + "$var")
    expect_literal(s, '"""x"""', "Int", M + '"""x"""')


def test_float_parse_literal() raises:
    var s = make_schema()
    expect_literal(s, "1", "Float", "1")
    expect_literal(s, "0", "Float", "0")
    expect_literal(s, "-1", "Float", "-1")
    expect_literal(s, "0.1", "Float", "0.1")
    expect_literal(s, "3.141592653589793", "Float", "3.141592653589793")
    comptime M = "THROWS Float cannot represent non numeric value: "
    expect_literal(s, "null", "Float", M + "null")
    expect_literal(s, '""', "Float", M + '""')
    expect_literal(s, '"123"', "Float", M + '"123"')
    expect_literal(s, '"123.5"', "Float", M + '"123.5"')
    expect_literal(s, "false", "Float", M + "false")
    expect_literal(s, "[0.1]", "Float", M + "[0.1]")
    expect_literal(s, "{ value: 0.1 }", "Float", M + "{value: 0.1}")
    expect_literal(s, "ENUM_VALUE", "Float", M + "ENUM_VALUE")
    expect_literal(s, "$var", "Float", M + "$var")


def test_string_parse_literal() raises:
    var s = make_schema()
    expect_literal(s, '"foo"', "String", '"foo"')
    expect_literal(s, '"""bar"""', "String", '"bar"')
    comptime M = "THROWS String cannot represent a non string value: "
    expect_literal(s, "null", "String", M + "null")
    expect_literal(s, "1", "String", M + "1")
    expect_literal(s, "0.1", "String", M + "0.1")
    expect_literal(s, "false", "String", M + "false")
    expect_literal(s, '["foo"]', "String", M + '["foo"]')
    expect_literal(s, '{ value: "foo" }', "String", M + '{value: "foo"}')
    expect_literal(s, "ENUM_VALUE", "String", M + "ENUM_VALUE")
    expect_literal(s, "$var", "String", M + "$var")


def test_boolean_parse_literal() raises:
    var s = make_schema()
    expect_literal(s, "true", "Boolean", "true")
    expect_literal(s, "false", "Boolean", "false")
    comptime M = "THROWS Boolean cannot represent a non boolean value: "
    expect_literal(s, "null", "Boolean", M + "null")
    expect_literal(s, "0", "Boolean", M + "0")
    expect_literal(s, "1", "Boolean", M + "1")
    expect_literal(s, "0.1", "Boolean", M + "0.1")
    expect_literal(s, '""', "Boolean", M + '""')
    expect_literal(s, '"false"', "Boolean", M + '"false"')
    expect_literal(s, "[false]", "Boolean", M + "[false]")
    expect_literal(s, "{ value: false }", "Boolean", M + "{value: false}")
    expect_literal(s, "ENUM_VALUE", "Boolean", M + "ENUM_VALUE")
    expect_literal(s, "$var", "Boolean", M + "$var")


def test_id_parse_literal() raises:
    var s = make_schema()
    expect_literal(s, '""', "ID", '""')
    expect_literal(s, '"1"', "ID", '"1"')
    expect_literal(s, '"foo"', "ID", '"foo"')
    expect_literal(s, '"""foo"""', "ID", '"foo"')
    expect_literal(s, "1", "ID", '"1"')
    expect_literal(s, "0", "ID", '"0"')
    expect_literal(s, "-1", "ID", '"-1"')
    expect_literal(s, "90071992547409910", "ID", '"90071992547409910"')
    expect_literal(s, "-90071992547409910", "ID", '"-90071992547409910"')
    comptime M = (
        "THROWS ID cannot represent a non-string and non-integer value: "
    )
    expect_literal(s, "null", "ID", M + "null")
    expect_literal(s, "0.1", "ID", M + "0.1")
    expect_literal(s, "false", "ID", M + "false")
    expect_literal(s, '["1"]', "ID", M + '["1"]')
    expect_literal(s, '{ value: "1" }', "ID", M + '{value: "1"}')
    expect_literal(s, "ENUM_VALUE", "ID", M + "ENUM_VALUE")
    expect_literal(s, "$var", "ID", M + "$var")


def test_enum_and_custom_parse_literal() raises:
    # Not upstream; checked against graphql-js `GraphQLEnumType.parseLiteral`.
    var s = make_schema()
    expect_literal(s, "GREEN", "TestColor", '"GREEN"')
    expect_literal(
        s,
        '"RED"',
        "TestColor",
        (
            'THROWS Enum "TestColor" cannot represent non-enum value: "RED".'
            ' Did you mean the enum value "RED" or "GREEN"?'
        ),
    )
    expect_literal(
        s,
        "1",
        "TestColor",
        'THROWS Enum "TestColor" cannot represent non-enum value: 1.',
    )
    expect_literal(
        s,
        "PURPLE",
        "TestColor",
        'THROWS Value "PURPLE" does not exist in "TestColor" enum.',
    )
    expect_literal(
        s,
        "RAD",
        "TestColor",
        (
            'THROWS Value "RAD" does not exist in "TestColor" enum. Did you'
            ' mean the enum value "RED" or "NAN"?'
        ),
    )
    expect_literal(s, "$var", "Custom", "undefined")
    expect_literal(
        s,
        '"x"',
        "NoValues",
        'THROWS Enum "NoValues" cannot represent non-enum value: "x".',
    )
    expect_literal(s, "[1, x]", "Custom", '[1, "x"]')
    expect_literal(
        s, "{ int: 1 }", "TestInput", "THROWS Unexpected input type: TestInput"
    )


def literal_error(s: Schema, text: String) raises -> GraphQLError:
    """Return the error of `GraphQLInt.parseLiteral(parseValue(text))`."""
    var document = parse_value(text)
    var values = JsValues()
    try:
        _ = parse_literal(
            s, document, document.root, s.type_named("Int"), values
        )
    except error:
        return error^
    raise Error("parse_literal must raise")


def test_parse_literal_error_locations() raises:
    # Checked against graphql-js `GraphQLError.locations`.
    var s = make_schema()
    var nested = literal_error(s, "\n  {a: 1}")
    assert_equal(len(nested.locations), 1)
    assert_equal(nested.locations[0].line, 2)
    assert_equal(nested.locations[0].column, 3)
    var spaced = literal_error(s, "  1.5")
    assert_equal(spaced.locations[0].line, 1)
    assert_equal(spaced.locations[0].column, 3)
    assert_equal(
        String(spaced),
        (
            "Int cannot represent non-integer value: 1.5\n\nGraphQL"
            " request:1:3\n1 |   1.5\n  |   ^"
        ),
    )


# astFromValue-test.ts


def test_converts_boolean_values_to_asts() raises:
    var s = make_schema()
    expect_ast(s, js("true"), "Boolean", "true")
    expect_ast(s, js("false"), "Boolean", "false")
    expect_ast(s, js_undefined(), "Boolean", "<null>")
    expect_ast(s, js("null"), "Boolean", "null")
    expect_ast(s, js("0"), "Boolean", "false")
    expect_ast(s, js("1"), "Boolean", "true")
    expect_ast(s, js("0"), "Boolean!", "false")


def test_converts_int_values_to_int_asts() raises:
    var s = make_schema()
    expect_ast(s, js("-1"), "Int", "-1")
    expect_ast(s, js("123.0"), "Int", "123")
    expect_ast(s, js("1e4"), "Int", "10000")
    expect_ast(
        s,
        js("123.5"),
        "Int",
        "THROWS Int cannot represent non-integer value: 123.5",
    )
    expect_ast(
        s,
        js("1e40"),
        "Int",
        "THROWS Int cannot represent non 32-bit signed integer value: 1e+40",
    )
    expect_ast(
        s,
        js_number(nan[DType.float64]()),
        "Int",
        "THROWS Int cannot represent non-integer value: NaN",
    )


def test_converts_float_values_to_int_float_asts() raises:
    var s = make_schema()
    expect_ast(s, js("-1"), "Float", "-1")
    expect_ast(s, js("123.0"), "Float", "123")
    expect_ast(s, js("123.5"), "Float", "123.5")
    expect_ast(s, js("1e4"), "Float", "10000")
    expect_ast(s, js("1e40"), "Float", "1e+40")


def test_converts_string_values_to_string_asts() raises:
    var s = make_schema()
    expect_ast(s, js('"hello"'), "String", '"hello"')
    expect_ast(s, js('"VALUE"'), "String", '"VALUE"')
    expect_ast(s, js('"VA\\nLUE"'), "String", '"VA\\nLUE"')
    expect_ast(s, js("123"), "String", '"123"')
    expect_ast(s, js("false"), "String", '"false"')
    expect_ast(s, js("null"), "String", "null")
    expect_ast(s, js_undefined(), "String", "<null>")


def test_converts_id_values_to_int_string_asts() raises:
    var s = make_schema()
    expect_ast(s, js('"hello"'), "ID", '"hello"')
    expect_ast(s, js('"VALUE"'), "ID", '"VALUE"')
    expect_ast(s, js('"VA\\nLUE"'), "ID", '"VA\\nLUE"')
    expect_ast(s, js("-1"), "ID", "-1")
    expect_ast(s, js("123"), "ID", "123")
    expect_ast(s, js('"123"'), "ID", "123")
    expect_ast(s, js('"01"'), "ID", '"01"')
    expect_ast(s, js("false"), "ID", "THROWS ID cannot represent value: false")
    expect_ast(s, js("null"), "ID", "null")
    expect_ast(s, js_undefined(), "ID", "<null>")


def test_converts_using_serialize_from_a_custom_scalar_type() raises:
    var s = make_schema()
    expect_ast(s, js('"value"'), "Custom", '"value"')
    expect_ast(
        s,
        js_number(nan[DType.float64]()),
        "Custom",
        "THROWS Cannot convert value to AST: NaN.",
    )
    expect_ast(
        s,
        js_number(inf[DType.float64]()),
        "Custom",
        "THROWS Cannot convert value to AST: Infinity.",
    )
    expect_ast(s, js("{}"), "Custom", "THROWS Cannot convert value to AST: {}.")
    # Not upstream: the identity passes booleans and numbers.
    expect_ast(s, js("true"), "Custom", "true")
    expect_ast(s, js("false"), "Custom", "false")
    expect_ast(s, js("2.5"), "Custom", "2.5")


def test_does_not_converts_non_null_values_to_null_value() raises:
    var s = make_schema()
    expect_ast(s, js("null"), "Boolean!", "<null>")
    expect_ast(s, js("null"), "[Int!]!", "<null>")


def test_converts_string_values_to_enum_asts_if_possible() raises:
    var s = make_schema()
    expect_ast(s, js("HELLO"), "MyEnum", "HELLO")
    expect_ast(
        s,
        js('"hello"'),
        "MyEnum",
        'THROWS Enum "MyEnum" cannot represent value: "hello"',
    )
    expect_ast(
        s,
        js('"UNKNOWN_VALUE"'),
        "MyEnum",
        'THROWS Enum "MyEnum" cannot represent value: "UNKNOWN_VALUE"',
    )
    expect_ast(
        s,
        js("1"),
        "TestColor",
        'THROWS Enum "TestColor" cannot represent value: 1',
    )
    expect_ast(s, js("RED"), "[TestColor!]!", "RED")


def test_converts_array_values_to_list_asts() raises:
    var s = make_schema()
    expect_ast(s, js('["FOO", "BAR"]'), "[String]", '["FOO", "BAR"]')
    expect_ast(s, js("[HELLO, GOODBYE]"), "[MyEnum]", "[HELLO, GOODBYE]")
    expect_ast(s, js("[1, 2, 3]"), "[Int]", "[1, 2, 3]")
    expect_ast(s, js("[]"), "[Int]", "[]")
    # Not upstream: an undefined item is skipped.
    expect_ast(s, js("[$v, 1]"), "[Custom]", "[1]")


def test_converts_list_singletons() raises:
    var s = make_schema()
    expect_ast(s, js('"FOO"'), "[String]", '"FOO"')


def test_skip_invalid_list_items() raises:
    var s = make_schema()
    expect_ast(s, js('["FOO", null, "BAR"]'), "[String!]", '["FOO", "BAR"]')


def test_converts_input_objects() raises:
    var s = make_schema()
    expect_ast(
        s, js("{ foo: 3, bar: HELLO }"), "MyInputObj", "{foo: 3, bar: HELLO}"
    )


def test_converts_input_objects_with_explicit_nulls() raises:
    var s = make_schema()
    expect_ast(s, js("{ foo: null }"), "MyInputObj", "{foo: null}")


def test_does_not_converts_non_object_values_as_input_objects() raises:
    var s = make_schema()
    expect_ast(s, js("5"), "MyInputObj", "<null>")
    # Not upstream: an array is object-like, with no input fields.
    expect_ast(s, js("[]"), "MyInputObj", "{}")
    expect_ast(s, js("{ x: 1 }"), "Empty", "{}")


def test_ast_from_value_refuses_an_output_type() raises:
    var s = make_schema()
    expect_ast(s, js("1"), "Query", "THROWS Unexpected input type: Query")


# scalars-test.ts: serialize, through astFromValue


def test_int_serialize() raises:
    var s = make_schema()
    expect_ast(s, js("1"), "Int", "1")
    expect_ast(s, js('"123"'), "Int", "123")
    expect_ast(s, js("0"), "Int", "0")
    expect_ast(s, js("-1"), "Int", "-1")
    expect_ast(s, js("1e5"), "Int", "100000")
    expect_ast(s, js("false"), "Int", "0")
    expect_ast(s, js("true"), "Int", "1")
    comptime M = "THROWS Int cannot represent non-integer value: "
    comptime R = "THROWS Int cannot represent non 32-bit signed integer value: "
    expect_ast(s, js("0.1"), "Int", M + "0.1")
    expect_ast(s, js("1.1"), "Int", M + "1.1")
    expect_ast(s, js("-1.1"), "Int", M + "-1.1")
    expect_ast(s, js('"-1.1"'), "Int", M + '"-1.1"')
    expect_ast(s, js("9876504321"), "Int", R + "9876504321")
    expect_ast(s, js("-9876504321"), "Int", R + "-9876504321")
    expect_ast(s, js("1e100"), "Int", R + "1e+100")
    expect_ast(s, js("-1e100"), "Int", R + "-1e+100")
    expect_ast(s, js('"one"'), "Int", M + '"one"')
    expect_ast(s, js('""'), "Int", M + '""')
    expect_ast(s, js_number(nan[DType.float64]()), "Int", M + "NaN")
    expect_ast(s, js_number(inf[DType.float64]()), "Int", M + "Infinity")
    expect_ast(s, js("[5]"), "Int", M + "[5]")
    # Not upstream: the bounds, and `Number(string)`.
    expect_ast(s, js("2147483647"), "Int", "2147483647")
    expect_ast(s, js("-2147483648"), "Int", "-2147483648")
    expect_ast(s, js("3e9"), "Int", R + "3000000000")
    expect_ast(s, js("-3e9"), "Int", R + "-3000000000")
    expect_ast(s, js('" 0x10 "'), "Int", "16")
    expect_ast(s, js('"   "'), "Int", "0")
    expect_ast(s, js('"1.5"'), "Int", M + '"1.5"')
    expect_ast(s, js("-0.0"), "Int", "0")


def test_float_serialize() raises:
    var s = make_schema()
    expect_ast(s, js("1"), "Float", "1")
    expect_ast(s, js("0"), "Float", "0")
    expect_ast(s, js('"123.5"'), "Float", "123.5")
    expect_ast(s, js("-1"), "Float", "-1")
    expect_ast(s, js("0.1"), "Float", "0.1")
    expect_ast(s, js("1.1"), "Float", "1.1")
    expect_ast(s, js("-1.1"), "Float", "-1.1")
    expect_ast(s, js('"-1.1"'), "Float", "-1.1")
    expect_ast(s, js("false"), "Float", "0")
    expect_ast(s, js("true"), "Float", "1")
    comptime M = "THROWS Float cannot represent non numeric value: "
    expect_ast(s, js_number(nan[DType.float64]()), "Float", M + "NaN")
    expect_ast(s, js_number(inf[DType.float64]()), "Float", M + "Infinity")
    expect_ast(s, js('"one"'), "Float", M + '"one"')
    expect_ast(s, js('""'), "Float", M + '""')
    expect_ast(s, js("[5]"), "Float", M + "[5]")
    expect_ast(s, js("1e21"), "Float", "1e+21")
    expect_ast(s, js("1e-7"), "Float", "1e-7")


def number_of(text: String) raises -> String:
    """Return `print(astFromValue(text, GraphQLFloat))`, which serializes
    the string with `Number(text)`; `NaN` for the error."""
    var s = make_schema()
    var value = js_string(text)
    try:
        var printed = print_ast_from_value(
            s, value.values, value.root, ref_of(s, "Float")
        )
        return printed.value()
    except error:
        assert_equal(
            String(error),
            "Float cannot represent non numeric value: "
            + inspect(value.values, value.root),
        )
        return String("NaN")


def test_number_of_string() raises:
    # ECMAScript `Number(string)`, checked against Node.js.
    assert_equal(number_of("  12  "), "12")
    assert_equal(number_of("0x1F"), "31")
    assert_equal(number_of("0X1f"), "31")
    assert_equal(number_of("0o17"), "15")
    assert_equal(number_of("0O7"), "7")
    assert_equal(number_of("0b101"), "5")
    assert_equal(number_of("0B1"), "1")
    assert_equal(number_of("0x"), "NaN")
    assert_equal(number_of("0xg"), "NaN")
    assert_equal(number_of("0x!"), "NaN")
    assert_equal(number_of("0b2"), "NaN")
    assert_equal(number_of("0o8"), "NaN")
    assert_equal(number_of("-0x10"), "NaN")
    assert_equal(number_of("0x1FFFFFFFFFFFFF1"), "144115188075855860")
    assert_equal(number_of("0x200000000000010000001"), "2.417851639229259e+24")
    assert_equal(number_of("0x200000000000010000000"), "2.4178516392292583e+24")
    assert_equal(number_of("0x" + "f" * 300), "NaN")
    assert_equal(number_of("0b" + "1" * 70), "1.1805916207174113e+21")
    assert_equal(number_of("0o" + "7" * 25), "3.777893186295716e+22")
    assert_equal(number_of("0x0000000000000000000000001"), "1")
    assert_equal(number_of("Infinity"), "NaN")
    assert_equal(number_of("-Infinity"), "NaN")
    assert_equal(number_of("+Infinity"), "NaN")


def test_number_of_string_white_space() raises:
    assert_equal(number_of("\u00a012\u3000"), "12")
    assert_equal(number_of("\ufeff1"), "1")
    assert_equal(number_of("1\u2028"), "1")
    assert_equal(number_of("\t\n\x0b\x0c\r 1"), "1")
    assert_equal(number_of("\u2029\u205f\u202f\u1680\u2000\u200a 1"), "1")
    assert_equal(number_of("\u0085 1"), "NaN")
    assert_equal(number_of("   "), "0")
    assert_equal(number_of("1\u00a1"), "NaN")
    assert_equal(number_of("1\u20ac"), "NaN")
    assert_equal(number_of("1😀"), "NaN")


def test_number_of_string_decimal() raises:
    assert_equal(number_of("5."), "5")
    assert_equal(number_of(".5"), "0.5")
    assert_equal(number_of("+.5"), "0.5")
    assert_equal(number_of("-.5e-3"), "-0.0005")
    assert_equal(number_of("5.e3"), "5000")
    assert_equal(number_of("00012"), "12")
    assert_equal(number_of("1E5"), "100000")
    assert_equal(number_of("1e+5"), "100000")
    assert_equal(number_of("1e-5"), "0.00001")
    assert_equal(number_of("-0"), "0")
    assert_equal(number_of("0"), "0")
    assert_equal(number_of("05"), "5")
    assert_equal(number_of("0.5"), "0.5")
    assert_equal(
        number_of("-000123456789012345678901234"), "-1.2345678901234569e+23"
    )
    var invalid: List[String] = [
        "1e",
        "1e+",
        "1e-",
        ".",
        "+",
        "-",
        "1x",
        "1.5x",
        "1e5x",
        "e5",
        "1.e-",
        ".5E",
        "+-1",
        "--1",
        "1..2",
        "1.2.3",
        "1e5.5",
        "1e++5",
    ]
    for text in invalid:
        assert_equal(number_of(text), "NaN", text)


def test_string_serialize() raises:
    var s = make_schema()
    expect_ast(s, js('"string"'), "String", '"string"')
    expect_ast(s, js("1"), "String", '"1"')
    expect_ast(s, js("-1.1"), "String", '"-1.1"')
    expect_ast(s, js("true"), "String", '"true"')
    expect_ast(s, js("false"), "String", '"false"')
    comptime M = "THROWS String cannot represent value: "
    expect_ast(s, js_number(nan[DType.float64]()), "String", M + "NaN")
    expect_ast(s, js_number(inf[DType.float64]()), "String", M + "Infinity")
    expect_ast(s, js("[1]"), "String", M + "[1]")
    expect_ast(s, js("{}"), "String", M + "{}")
    expect_ast(
        s,
        js('{ valueOf: "valueOf string" }'),
        "String",
        M + '{ valueOf: "valueOf string" }',
    )


def test_boolean_serialize() raises:
    var s = make_schema()
    expect_ast(s, js("1"), "Boolean", "true")
    expect_ast(s, js("0"), "Boolean", "false")
    expect_ast(s, js("true"), "Boolean", "true")
    expect_ast(s, js("false"), "Boolean", "false")
    expect_ast(s, js("1.5"), "Boolean", "true")
    expect_ast(s, js("-0.0"), "Boolean", "false")
    comptime M = "THROWS Boolean cannot represent a non boolean value: "
    expect_ast(s, js_number(nan[DType.float64]()), "Boolean", M + "NaN")
    expect_ast(s, js_number(inf[DType.float64]()), "Boolean", M + "Infinity")
    expect_ast(s, js('""'), "Boolean", M + '""')
    expect_ast(s, js('"true"'), "Boolean", M + '"true"')
    expect_ast(s, js("[false]"), "Boolean", M + "[false]")
    expect_ast(s, js("{}"), "Boolean", M + "{}")


def test_id_serialize() raises:
    var s = make_schema()
    expect_ast(s, js('"string"'), "ID", '"string"')
    expect_ast(s, js('"false"'), "ID", '"false"')
    expect_ast(s, js('""'), "ID", '""')
    expect_ast(s, js("123"), "ID", "123")
    expect_ast(s, js("0"), "ID", "0")
    expect_ast(s, js("-1"), "ID", "-1")
    comptime M = "THROWS ID cannot represent value: "
    expect_ast(s, js("true"), "ID", M + "true")
    expect_ast(s, js("3.14"), "ID", M + "3.14")
    expect_ast(s, js("{}"), "ID", M + "{}")
    expect_ast(s, js('["abc"]'), "ID", M + '["abc"]')
    # Not upstream.
    expect_ast(s, js("1e21"), "ID", '"1e+21"')
    expect_ast(s, js("-0.0"), "ID", "0")
    expect_ast(s, js_number(inf[DType.float64]()), "ID", M + "Infinity")
    expect_ast(s, js('"-"'), "ID", '"-"')
    expect_ast(s, js('"-0"'), "ID", "-0")
    expect_ast(s, js('"1a"'), "ID", '"1a"')


# jsutils/inspect.ts, through the custom scalar error


def test_inspect() raises:
    var s = make_schema()
    comptime M = "THROWS Cannot convert value to AST: "
    expect_ast(
        s, js("{a: {b: {c: 1}}}"), "Custom", M + "{ a: { b: [Object] } }."
    )
    expect_ast(s, js("[[[1]]]"), "Custom", M + "[[[Array]]].")
    expect_ast(s, js("[[[]]]"), "Custom", M + "[[[]]].")
    expect_ast(s, js("{a: {b: {}}}"), "Custom", M + "{ a: { b: {} } }.")
    expect_ast(
        s,
        js("[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]"),
        "Custom",
        M + "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ... 1 more item].",
    )
    expect_ast(
        s,
        js("[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]"),
        "Custom",
        M + "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ... 2 more items].",
    )
    expect_ast(
        s,
        js('["\\u0001\\u007f\\"\\\\\\n"]'),
        "Custom",
        M + '["\\u0001\x7f\\"\\\\\\n"].',
    )
    expect_ast(
        s,
        js("[$v, null, true, false, -0.0]"),
        "Custom",
        M + "[undefined, null, true, false, 0].",
    )
    expect_ast(
        s,
        js("{a: {}, b: [{c: []}]}"),
        "Custom",
        M + "{ a: {}, b: [[Object]] }.",
    )
    var values = JsValues()
    assert_equal(inspect(values, UNDEFINED), "undefined")


def test_js_kind() raises:
    assert_true(JsKind.OBJECT.is_valid())
    assert_false(JsKind(7).is_valid())
    assert_equal(String(JsKind.UNDEFINED), "undefined")
    assert_equal(String(JsKind.LIST), "array")
    assert_equal(String(JsKind(9)), "<invalid>")


# printSchema of default values


def test_print_default() raises:
    var s = build_schema(
        """
        scalar C
        input I { x: Int! }
        type Query {
          f(a: Int = 2147483648, b: I = {}, c: [Int] = 1, d: Int, e: Float = 1e400,
            g: C = 1e400, h: C = {a: {b: {c: 1}}}, i: Float = 1.23e4): Int
        }
        """
    )
    assert_equal(printed_default(s, "a"), "<none>")
    assert_equal(printed_default(s, "b"), "<none>")
    assert_equal(printed_default(s, "c"), "[1]")
    assert_equal(printed_default(s, "d"), "<none>")
    assert_equal(printed_default(s, "i"), "12300")
    assert_equal(
        printed_default(s, "e"),
        "THROWS Float cannot represent non numeric value: Infinity",
    )
    assert_equal(
        printed_default(s, "g"), "THROWS Cannot convert value to AST: Infinity."
    )
    assert_equal(
        printed_default(s, "h"),
        "THROWS Cannot convert value to AST: { a: { b: [Object] } }.",
    )


def printed_default(s: Schema, name: String) raises -> String:
    """Return `print_default` for an argument of `Query.f`: `<none>` for
    none, and `THROWS message` for an error."""
    var field = s.field_named(s.type_named("Query"), "f")
    try:
        var printed = print_default(s, s.argument_named(field, name))
        if printed:
            return printed.value()
        return String("<none>")
    except error:
        return "THROWS " + String(error)


# Number.prototype.toString


def check_bits(bits: UInt64, expected: String) raises:
    """Assert the text of the double with these bits, from Node.js."""
    assert_equal(js_number_to_string(bitcast[DType.float64](bits)), expected)


def test_js_number_to_string_special() raises:
    assert_equal(js_number_to_string(0), "0")
    assert_equal(js_number_to_string(-0.0), "0")
    assert_equal(js_number_to_string(nan[DType.float64]()), "NaN")
    assert_equal(js_number_to_string(inf[DType.float64]()), "Infinity")
    assert_equal(js_number_to_string(-inf[DType.float64]()), "-Infinity")
    assert_equal(js_number_to_string(1), "1")
    assert_equal(js_number_to_string(-12300), "-12300")
    assert_equal(js_number_to_string(1e20), "100000000000000000000")
    assert_equal(js_number_to_string(1e21), "1e+21")
    assert_equal(js_number_to_string(1.5e21), "1.5e+21")
    assert_equal(js_number_to_string(1e-6), "0.000001")
    assert_equal(js_number_to_string(1e-7), "1e-7")
    assert_equal(js_number_to_string(1.25e-7), "1.25e-7")
    assert_equal(js_number_to_string(0.001), "0.001")
    assert_equal(js_number_to_string(123.456), "123.456")


def test_js_number_to_string_from_node() raises:
    check_bits(0x444B1AE4D6E2EF50, "1e+21")
    check_bits(0x444B1AE4D6E2EF50, "1e+21")
    check_bits(0x444B1AE4D6E2EF4F, "999999999999999900000")
    check_bits(0x3E7AD7F29ABCAF48, "1e-7")
    check_bits(0x3E8421F5F40D8376, "1.5e-7")
    check_bits(0x3EB0C6F7A0B5ED8D, "0.000001")
    check_bits(0x3EB4B3FD5942CD96, "0.000001234")
    check_bits(0x3C36B082C2148B8E, "1.23e-18")
    check_bits(0x7FEFFFFFFFFFFFFF, "1.7976931348623157e+308")
    check_bits(0x0000000000000001, "5e-324")
    check_bits(0x0010000000000000, "2.2250738585072014e-308")
    check_bits(0x3FD3333333333334, "0.30000000000000004")
    check_bits(0x3FD5555555555555, "0.3333333333333333")
    check_bits(0xBFD5555555555555, "-0.3333333333333333")
    check_bits(0x4059000000000000, "100")
    check_bits(0x441AC53A7E04BCDA, "123456789012345680000")
    check_bits(0x4484E9CA52EB182A, "1.2345e+22")
    check_bits(0x4340000000000000, "9007199254740992")
    check_bits(0x4340000000000001, "9007199254740994")
    check_bits(0x40C8060000000000, "12300")
    check_bits(0x3FE0000000000000, "0.5")
    check_bits(0xFE41EB2D66005835, "-1.5e+300")
    check_bits(0x4011666666666666, "4.35")
    check_bits(0x430C6BF526340000, "1000000000000000")
    check_bits(0x4340000000000000, "9007199254740992")
    check_bits(0x43FA703AFCD78978, "30481400000000000000")
    check_bits(0x46C0C0007317CB55, "6.79461e+32")
    check_bits(0x3FEC42F1ED17C5EF, "0.883172")
    check_bits(0xC5831D10827887E7, "-7.39419e+26")
    check_bits(0x44F97053FF205BED, "1.9221e+24")
    check_bits(0x406A1E5604189375, "208.948")
    check_bits(0xC5BB454BFD7989FC, "-8.43987e+27")
    check_bits(0xC26548DAFF680000, "-731333000000")
    check_bits(0x40E1FB3000000000, "36825.5")
    check_bits(0xC5AB18350C742292, "-4.19268e+27")
    check_bits(0xC52C933B0B60E629, "-1.72726e+25")
    check_bits(0x4117024800000000, "376978")
    check_bits(0x468270E310685183, "4.67534e+31")
    check_bits(0x407B4045A1CAC083, "436.017")
    check_bits(0x4539775BC5AE7EC9, "3.07868e+25")
    check_bits(0xC58219AC83C49AED, "-7.00221e+26")
    check_bits(0x43405D5C26FF2400, "9212500000000000")
    check_bits(0xC1C4D9FB70000000, "-699660000")
    check_bits(0xC1B7DD67D0000000, "-400386000")
    check_bits(0xC64B2B8E12E4F5B7, "-4.3052800000000004e+30")
    check_bits(0x4094C41EB851EB85, "1329.03")
    check_bits(0xBE9335E8CB553062, "-2.8625999999999997e-7")
    check_bits(0x41E03E274E000000, "2180070000")
    check_bits(0x429394C28B5A0000, "5382410000000")
    check_bits(0xC3A369735C685780, "-699388000000000000")
    check_bits(0x432FE175B8730800, "4486810000000000")
    check_bits(0xC3F95037639966EC, "-29184300000000000000")
    check_bits(0x466FCC186B1D58F8, "2.0153899999999998e+31")
    check_bits(0xC61EC6505029E15D, "-6.09555e+29")
    check_bits(0xC3D68398136DF3B8, "-6489230000000000000")
    check_bits(0xCDFF3400AF818400, "-5.2577179242223457e+67")
    check_bits(0x485D9400CAF06400, "4.025967400070332e+40")
    check_bits(0xFED2F4007E2A4400, "-8.123377851339912e+302")
    check_bits(0x30B7540091A72480, "5.15752178047954e-74")
    check_bits(0xAC49EA00DCC50200, "-2.4264263053187216e-95")
    check_bits(0x927E3A00B16B1200, "-1.3379259768592756e-219")
    check_bits(0x16130A00EF27A280, "2.4290072282033477e-202")
    check_bits(0x166390003E44B080, "7.986515485650973e-201")
    check_bits(0x74068700CDE9DB00, "8.064484808643206e+250")
    check_bits(0x4F4CA000DC608000, "1.0115204087536643e+74")
    check_bits(0x3C16E000CDFDC080, "3.1001422509345513e-19")
    check_bits(0x68B256006E22FE00, "2.141610392653954e+196")
    check_bits(0x024A8600528F6E70, "1.2673722290668507e-297")
    check_bits(0xB5588600D3856E00, "-1.0241470627722563e-51")
    check_bits(0xCB543600FF4F5E00, "-7.74329872911767e+54")
    check_bits(0x976F6800DC1FA800, "-8.402898086510483e-196")
    check_bits(0x4EAAE80001752800, "9.285005662148629e+70")
    check_bits(0x411268708748F800, "301596.1321142912")
    check_bits(0xA5A1F800AF86F800, "-2.07381476419943e-127")
    check_bits(0xAC07F8007CF4F800, "-1.4026745624463895e-96")
    check_bits(0xA7DDF800EB12F800, "-1.1884215624600905e-116")
    check_bits(0xAEA3F8002160F800, "-5.139515042795645e-84")
    check_bits(0x91D9F88036862E00, "-1.122605018736864e-222")
    check_bits(0xAD25F68071455400, "-3.3693098746817697e-91")
    check_bits(0x521D2400AF60B400, "3.6230787836717484e+87")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
