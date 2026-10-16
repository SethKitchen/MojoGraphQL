# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `coerce_input_value`, ported from graphql-js 16.14.2
`src/utilities/__tests__/coerceInputValue-test.ts`.

The types come from SDL. Each error shows as `path | value | message`.

Upstream cases that are not ported:

- `for GraphQLScalar`: the scalar has a JavaScript `parseValue`; a scalar
  from SDL is the identity, which `test_custom_scalars_are_the_identity`
  checks.
- The internal values of `for GraphQLEnum` (`InternalFoo`, `123456789`):
  an SDL enum value is its name. The error cases are ported.
- `returns no error for a valid iterable input`: an arena has arrays only.
- The `NaN` default value of `for GraphQLInputObject with default value`:
  an SDL default is a literal, and a literal cannot be NaN.
"""

from std.math import nan
from std.testing import TestSuite, assert_equal, assert_true
from _helpers import json_value
from gql_execution.coerce import (
    CoercionError,
    coerce_input_value,
    coerce_input_value_with,
    print_path_array,
)
from gql_execution.value import UNDEFINED, Values, inspect
from gql_schema.build import build_schema
from gql_schema.definition import Schema, TypeRef

comptime TYPES = """
input DeepObject { foo: Int! bar: Int }
input TestInputObject { foo: Int! bar: Int deepObject: DeepObject }
input OneOf @oneOf { foo: Int bar: Int }
input WithDefault { foo: TestScalar = 7 }
input WithNullDefault { foo: TestScalar = null }
input TestObject { length: Int }
enum TestEnum { FOO BAR }
scalar TestScalar
"""


def _schema(type: String) raises -> Schema:
    return build_schema(TYPES + "type Query { f(a: " + type + "): Int }")


def _type(schema: Schema) -> TypeRef:
    var field = schema.field_named(schema.type_named("Query"), "f")
    return schema.input_values[schema.argument_named(field, "a")].type


def coerce_value(type: String, mut values: Values, input: Int) raises -> String:
    var schema = _schema(type)
    var errors = List[CoercionError]()
    var value = coerce_input_value_with(
        schema, values, input, _type(schema), errors
    )
    if len(errors) == 0:
        return "value: " + inspect(values, value)
    var out = String("")
    for ref error in errors:
        out += (
            print_path_array(error.path)
            + " | "
            + inspect(values, error.invalid_value)
            + " | "
            + error.message
            + "\n"
        )
    return out^


def coerce_json(type: String, input: String) raises -> String:
    var values = Values()
    return coerce_value(type, values, json_value(values, input))


def test_non_null_returns_no_error_for_non_null_value() raises:
    assert_equal(coerce_json("Int!", "1"), "value: 1")


def test_non_null_returns_an_error_for_undefined_value() raises:
    var values = Values()
    assert_equal(
        coerce_value("Int!", values, UNDEFINED),
        ' | undefined | Expected non-nullable type "Int!" not to be null.\n',
    )


def test_non_null_returns_an_error_for_null_value() raises:
    assert_equal(
        coerce_json("Int!", "null"),
        ' | null | Expected non-nullable type "Int!" not to be null.\n',
    )


def test_enum_returns_no_error_for_a_known_enum_name() raises:
    assert_equal(coerce_json("TestEnum", '"FOO"'), 'value: "FOO"')
    assert_equal(coerce_json("TestEnum", '"BAR"'), 'value: "BAR"')


def test_enum_returns_an_error_for_misspelled_enum_value() raises:
    assert_equal(
        coerce_json("TestEnum", '"foo"'),
        (
            ' | "foo" | Value "foo" does not exist in "TestEnum" enum. Did you'
            ' mean the enum value "FOO"?\n'
        ),
    )


def test_enum_returns_an_error_for_incorrect_value_type() raises:
    assert_equal(
        coerce_json("TestEnum", "123"),
        ' | 123 | Enum "TestEnum" cannot represent non-string value: 123.\n',
    )
    assert_equal(
        coerce_json("TestEnum", '{"field": "value"}'),
        (
            ' | { field: "value" } | Enum "TestEnum" cannot represent'
            ' non-string value: { field: "value" }.\n'
        ),
    )


def test_input_object_returns_no_error_for_a_valid_input() raises:
    assert_equal(
        coerce_json("TestInputObject", '{"foo": 123}'), "value: { foo: 123 }"
    )


def test_input_object_returns_an_error_for_a_non_object_type() raises:
    assert_equal(
        coerce_json("TestInputObject", "123"),
        ' | 123 | Expected type "TestInputObject" to be an object.\n',
    )


def test_input_object_returns_an_error_for_an_invalid_field() raises:
    var values = Values()
    var input = values.add_object()
    values.add_member(input, "foo", values.add_number(nan[DType.float64]()))
    assert_equal(
        coerce_value("TestInputObject", values, input),
        ".foo | NaN | Int cannot represent non-integer value: NaN\n",
    )


def test_input_object_returns_multiple_errors_for_multiple_invalid_fields() raises:
    assert_equal(
        coerce_json("TestInputObject", '{"foo": "abc", "bar": "def"}'),
        (
            '.foo | "abc" | Int cannot represent non-integer value: "abc"\n'
            '.bar | "def" | Int cannot represent non-integer value: "def"\n'
        ),
    )


def test_input_object_returns_error_for_a_missing_required_field() raises:
    assert_equal(
        coerce_json("TestInputObject", '{"bar": 123}'),
        (
            ' | { bar: 123 } | Field "foo" of required type "Int!" was not'
            " provided.\n"
        ),
    )


def test_input_object_returns_error_for_an_unknown_field() raises:
    assert_equal(
        coerce_json("TestInputObject", '{"foo": 123, "unknownField": 123}'),
        (
            ' | { foo: 123, unknownField: 123 } | Field "unknownField" is not'
            ' defined by type "TestInputObject".\n'
        ),
    )


def test_input_object_returns_error_for_a_misspelled_field() raises:
    assert_equal(
        coerce_json("TestInputObject", '{"foo": 123, "bart": 123}'),
        (
            ' | { foo: 123, bart: 123 } | Field "bart" is not defined by type'
            ' "TestInputObject". Did you mean "bar"?\n'
        ),
    )


def test_input_object_returns_an_error_for_an_array_type() raises:
    assert_equal(
        coerce_json("TestInputObject", '[{"foo": 1}, {"bar": 1}]'),
        (
            ' | [{ foo: 1 }, { bar: 1 }] | Expected type "TestInputObject" to'
            " be an object.\n"
        ),
    )


def test_input_object_returns_an_error_for_an_array_type_on_a_nested_field() raises:
    assert_equal(
        coerce_json("TestInputObject", '{"foo": 1, "deepObject": [1, 2, 3]}'),
        (
            '.deepObject | [1, 2, 3] | Expected type "DeepObject" to be an'
            " object.\n"
        ),
    )


def test_one_of_returns_no_error_for_a_valid_input() raises:
    assert_equal(coerce_json("OneOf", '{"foo": 123}'), "value: { foo: 123 }")


def test_one_of_returns_an_error_if_more_than_one_field_is_specified() raises:
    assert_equal(
        coerce_json("OneOf", '{"foo": 123, "bar": null}'),
        (
            " | { foo: 123, bar: null } | Exactly one key must be specified for"
            ' OneOf type "OneOf".\n'
        ),
    )


def test_one_of_returns_an_error_the_one_field_is_null() raises:
    assert_equal(
        coerce_json("OneOf", '{"bar": null}'),
        '.bar | null | Field "bar" must be non-null.\n',
    )


def test_one_of_returns_an_error_for_an_invalid_field() raises:
    var values = Values()
    var input = values.add_object()
    values.add_member(input, "foo", values.add_number(nan[DType.float64]()))
    assert_equal(
        coerce_value("OneOf", values, input),
        ".foo | NaN | Int cannot represent non-integer value: NaN\n",
    )


def test_one_of_returns_multiple_errors_for_multiple_invalid_fields() raises:
    assert_equal(
        coerce_json("OneOf", '{"foo": "abc", "bar": "def"}'),
        (
            '.foo | "abc" | Int cannot represent non-integer value: "abc"\n.bar'
            ' | "def" | Int cannot represent non-integer value: "def"\n | {'
            ' foo: "abc", bar: "def" } | Exactly one key must be specified for'
            ' OneOf type "OneOf".\n'
        ),
    )


def test_one_of_returns_error_for_an_unknown_field() raises:
    assert_equal(
        coerce_json("OneOf", '{"foo": 123, "unknownField": 123}'),
        (
            ' | { foo: 123, unknownField: 123 } | Field "unknownField" is not'
            ' defined by type "OneOf".\n'
        ),
    )


def test_one_of_returns_error_for_a_misspelled_field() raises:
    assert_equal(
        coerce_json("OneOf", '{"bart": 123}'),
        (
            ' | { bart: 123 } | Field "bart" is not defined by type "OneOf".'
            ' Did you mean "bar"?\n | { bart: 123 } | Exactly one key must be'
            ' specified for OneOf type "OneOf".\n'
        ),
    )


def test_default_value_returns_no_errors_for_valid_input_value() raises:
    assert_equal(coerce_json("WithDefault", '{"foo": 5}'), "value: { foo: 5 }")


def test_default_value_returns_object_with_default_value() raises:
    assert_equal(coerce_json("WithDefault", "{}"), "value: { foo: 7 }")


def test_default_value_returns_null_as_value() raises:
    assert_equal(coerce_json("WithNullDefault", "{}"), "value: { foo: null }")


def test_list_returns_no_error_for_a_valid_input() raises:
    assert_equal(coerce_json("[Int]", "[1, 2, 3]"), "value: [1, 2, 3]")


def test_list_returns_an_error_for_an_invalid_input() raises:
    assert_equal(
        coerce_json("[Int]", '[1, "b", true, 4]'),
        (
            '[1] | "b" | Int cannot represent non-integer value: "b"\n'
            "[2] | true | Int cannot represent non-integer value: true\n"
        ),
    )


def test_list_returns_a_list_for_a_non_list_value() raises:
    assert_equal(coerce_json("[Int]", "42"), "value: [42]")


def test_list_returns_a_list_for_a_non_list_object_value() raises:
    assert_equal(
        coerce_json("[TestObject]", '{"length": 100500}'),
        "value: [{ length: 100500 }]",
    )


def test_list_returns_an_error_for_a_non_list_invalid_value() raises:
    assert_equal(
        coerce_json("[Int]", '"INVALID"'),
        ' | "INVALID" | Int cannot represent non-integer value: "INVALID"\n',
    )


def test_list_returns_null_for_a_null_value() raises:
    assert_equal(coerce_json("[Int]", "null"), "value: null")


def test_nested_list_returns_no_error_for_a_valid_input() raises:
    assert_equal(
        coerce_json("[[Int]]", "[[1], [2, 3]]"), "value: [[1], [2, 3]]"
    )


def test_nested_list_returns_a_list_for_a_non_list_value() raises:
    assert_equal(coerce_json("[[Int]]", "42"), "value: [[42]]")


def test_nested_list_returns_null_for_a_null_value() raises:
    assert_equal(coerce_json("[[Int]]", "null"), "value: null")


def test_nested_list_returns_nested_lists_for_nested_non_list_values() raises:
    assert_equal(coerce_json("[[Int]]", "[1, 2, 3]"), "value: [[1], [2], [3]]")


def test_nested_list_returns_nested_null_for_nested_null_values() raises:
    assert_equal(
        coerce_json("[[Int]]", "[42, [null], null]"),
        "value: [[42], [null], null]",
    )


def _throws(type: String, input: String) raises -> String:
    var schema = _schema(type)
    var values = Values()
    var value = json_value(values, input)
    try:
        _ = coerce_input_value(schema, values, value, _type(schema))
    except e:
        return String(e)
    return String("no error")


def test_default_on_error_throw_error_without_path() raises:
    assert_equal(
        _throws("Int!", "null"),
        'Invalid value null: Expected non-nullable type "Int!" not to be null.',
    )


def test_default_on_error_throw_error_with_path() raises:
    assert_equal(
        _throws("[Int!]", "[null]"),
        (
            'Invalid value null at "value[0]": Expected non-nullable type'
            ' "Int!" not to be null.'
        ),
    )
    assert_equal(_throws("Int", "1"), "no error")


# --- parseValue, from graphql-js src/type/__tests__/scalars-test.ts -------


def _parse_error(type: String, input: String) raises -> String:
    var result = coerce_json(type, input)
    return String(
        result[byte = result.find("| ", 3) + 2 : result.byte_length() - 1]
    )


def test_int_parse_value() raises:
    assert_equal(coerce_json("Int", "1"), "value: 1")
    assert_equal(coerce_json("Int", "-2147483648"), "value: -2147483648")
    assert_equal(
        _parse_error("Int", "2147483648"),
        "Int cannot represent non 32-bit signed integer value: 2147483648",
    )
    assert_equal(
        _parse_error("Int", "-2147483649"),
        "Int cannot represent non 32-bit signed integer value: -2147483649",
    )
    assert_equal(
        _parse_error("Int", "0.1"),
        "Int cannot represent non-integer value: 0.1",
    )
    assert_equal(
        _parse_error("Int", '"1"'),
        'Int cannot represent non-integer value: "1"',
    )
    assert_equal(
        _parse_error("Int", "false"),
        "Int cannot represent non-integer value: false",
    )


def test_float_parse_value() raises:
    assert_equal(coerce_json("Float", "1.5"), "value: 1.5")
    assert_equal(
        _parse_error("Float", '"1"'),
        'Float cannot represent non numeric value: "1"',
    )
    var values = Values()
    var input = values.add_number(nan[DType.float64]())
    assert_equal(
        coerce_value("Float", values, input),
        " | NaN | Float cannot represent non numeric value: NaN\n",
    )


def test_string_parse_value() raises:
    assert_equal(coerce_json("String", '"foo"'), 'value: "foo"')
    assert_equal(
        _parse_error("String", "1"),
        "String cannot represent a non string value: 1",
    )


def test_boolean_parse_value() raises:
    assert_equal(coerce_json("Boolean", "true"), "value: true")
    assert_equal(
        _parse_error("Boolean", "0"),
        "Boolean cannot represent a non boolean value: 0",
    )


def test_id_parse_value() raises:
    assert_equal(coerce_json("ID", '"1"'), 'value: "1"')
    assert_equal(coerce_json("ID", "123"), 'value: "123"')
    assert_equal(_parse_error("ID", "0.1"), "ID cannot represent value: 0.1")
    assert_equal(_parse_error("ID", "true"), "ID cannot represent value: true")


def test_custom_scalars_are_the_identity() raises:
    assert_equal(
        coerce_json("TestScalar", '{"value": [1, "x"]}'),
        'value: { value: [1, "x"] }',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
