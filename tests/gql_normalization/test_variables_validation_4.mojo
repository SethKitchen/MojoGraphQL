# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.variables_validation`, ported from
graphql-go-tools v2 `pkg/variablesvalidation/variablesvalidation_test.go`
`TestVariablesValidation`, part 4: nested lists and fields. Each docstring
is the upstream subtest name.
"""

from _vv_helpers import expect_hidden, expect_shown
from std.testing import TestSuite

comptime BARS_INPUT = (
    "input Foo { bars : [String] bat: Int! } type Query { hello(arg: Foo):"
    " String }"
)
"""The schema with an optional list field and a required Int field."""
comptime FOO_QUERY = "query Foo($input: Foo) { hello(arg: $input) }"
"""The operation that takes `$input: Foo`."""
comptime BAT_INPUT = (
    "input Foo { bar: String! } input Bar { foo: Foo bat: Int! } type Query {"
    " hello(arg: Bar): String }"
)
"""The schema with an optional object field and a required Int field."""
comptime BAR_QUERY = "query Foo($input: Bar) { hello(arg: $input) }"
"""The operation that takes `$input: Bar`."""


def test_optional_nested_list_argument_provided_with_null() raises:
    """Optional nested list argument provided with null."""
    expect_hidden(BARS_INPUT, FOO_QUERY, '{"input":{"bars":null,"bat":1}}', "")


def test_optional_nested_list_argument_provided_with_empty_list() raises:
    """Optional nested list argument provided with empty list."""
    expect_hidden(BARS_INPUT, FOO_QUERY, '{"input":{"bars":[],"bat":1}}', "")


def test_optional_nested_list_argument_provided_with_empty_list_and_missing_int_with_variable_content() raises:
    """Optional nested list argument provided with empty list and missing Int
    - with variable content."""
    expect_shown(
        BARS_INPUT,
        FOO_QUERY,
        '{"input":{"bars":[]}}',
        (
            'Variable "$input" got invalid value {"bars":[]}; Field "bat" of'
            ' required type "Int!" was not provided.'
        ),
    )


def test_optional_nested_list_argument_provided_with_empty_list_and_missing_int() raises:
    """Optional nested list argument provided with empty list and missing
    Int."""
    expect_hidden(
        BARS_INPUT,
        FOO_QUERY,
        '{"input":{"bars":[]}}',
        (
            'Variable "$input" got invalid value; Field "bat" of required type'
            ' "Int!" was not provided.'
        ),
    )


def test_optional_nested_field_is_null_followed_by_required_nested_field_of_wrong_type_with_variable_content() raises:
    """Optional nested field is null followed by required nested field of
    wrong type - with variable content."""
    expect_shown(
        BAT_INPUT,
        BAR_QUERY,
        '{"input":{"foo":null,"bat":"hello"}}',
        (
            'Variable "$input" got invalid value "hello" at "input.bat"; Int'
            ' cannot represent non-integer value: "hello"'
        ),
    )


def test_optional_nested_field_is_null_followed_by_required_nested_field_of_wrong_type() raises:
    """Optional nested field is null followed by required nested field of
    wrong type."""
    expect_hidden(
        BAT_INPUT,
        BAR_QUERY,
        '{"input":{"foo":null,"bat":"hello"}}',
        (
            'Variable "$input" got invalid value at "input.bat"; Int cannot'
            " represent non-integer value"
        ),
    )


def test_input_field_is_a_double_nested_list() raises:
    """Input field is a double nested list."""
    expect_hidden(
        (
            "input Filter { option: String! } input FilterWrapper { filters:"
            " [[Filter!]!] } type Query { hello(filter: FilterWrapper):"
            " String }"
        ),
        "query Foo($input: FilterWrapper) { hello(filter: $input) }",
        '{"input":{"filters":[[{"option": "a"}]]}}',
        "",
    )


comptime DOUBLE_LIST = "type Query { hello(filter: [[String]]): String }"
"""The schema with a double nested list argument."""
comptime DOUBLE_QUERY = (
    "query Foo($input: [[String]]) { hello(filter: $input) }"
)
"""The operation that takes `$input: [[String]]`."""


def test_variable_of_double_nested_list_type() raises:
    """Variable of double nested list type."""
    expect_hidden(DOUBLE_LIST, DOUBLE_QUERY, '{"input":[["value"]]}', "")


def test_triple_nested_value_into_variable_of_double_nested_list_type_with_variable_content() raises:
    """Triple nested value into variable of double nested list type - with
    variable content."""
    expect_shown(
        DOUBLE_LIST,
        DOUBLE_QUERY,
        '{"input":[[["value"]]]}',
        (
            'Variable "$input" got invalid value ["value"] at "input.[0].[0]";'
            ' String cannot represent a non string value: ["value"]'
        ),
    )


def test_triple_nested_value_into_variable_of_double_nested_list_type() raises:
    """Triple nested value into variable of double nested list type."""
    expect_hidden(
        DOUBLE_LIST,
        DOUBLE_QUERY,
        '{"input":[[["value"]]]}',
        (
            'Variable "$input" got invalid value at "input.[0].[0]"; String'
            " cannot represent a non string value"
        ),
    )


def test_null_into_non_required_list_value() raises:
    """Null into non required list value."""
    expect_hidden(
        "type Query { hello(filter: [String]): String }",
        "query Foo($input: [String]) { hello(filter: $input) }",
        '{"input":[null]}',
        "",
    )


def test_value_and_null_into_non_required_list_value() raises:
    """Value and null into non required list value."""
    expect_hidden(
        "type Query { hello(filter: [String]): String }",
        "query Foo($input: [String]) { hello(filter: $input) }",
        '{"input":["ok", null]}',
        "",
    )


def test_null_into_non_required_value() raises:
    """Null into non required value."""
    expect_hidden(
        "type Query { hello(filter: String): String }",
        "query Foo($input: String) { hello(filter: $input) }",
        '{"input":null}',
        "",
    )


def scalar_input(scalar: String) -> String:
    """Return the schema `input Foo { bar: <scalar> }`."""
    return (
        "input Foo { bar: "
        + scalar
        + " } type Query { hello(arg: Foo): String }"
    )


def test_optional_int_input_object_field_provided_with_1() raises:
    """Optional Int input object field provided with 1."""
    expect_hidden(scalar_input("Int"), FOO_QUERY, '{"input":{"bar":1}}', "")


def test_optional_float_input_object_field_provided_with_1_1() raises:
    """Optional Float input object field provided with 1.1."""
    expect_hidden(scalar_input("Float"), FOO_QUERY, '{"input":{"bar":1.1}}', "")


def test_optional_float_input_object_field_provided_with_true() raises:
    """Optional Float input object field provided with true."""
    expect_hidden(
        scalar_input("Float"),
        FOO_QUERY,
        '{"input":{"bar":true}}',
        (
            'Variable "$input" got invalid value at "input.bar"; Float cannot'
            " represent non numeric value"
        ),
    )


def test_optional_boolean_input_object_field_provided_with_true() raises:
    """Optional Boolean input object field provided with true."""
    expect_hidden(
        scalar_input("Boolean"), FOO_QUERY, '{"input":{"bar":true}}', ""
    )


def test_optional_boolean_input_object_field_provided_with_false() raises:
    """Optional Boolean input object field provided with false."""
    expect_hidden(
        scalar_input("Boolean"), FOO_QUERY, '{"input":{"bar":false}}', ""
    )


def test_optional_boolean_input_object_field_provided_with_1() raises:
    """Optional Boolean input object field provided with 1."""
    expect_hidden(
        scalar_input("Boolean"),
        FOO_QUERY,
        '{"input":{"bar":1}}',
        (
            'Variable "$input" got invalid value at "input.bar"; Boolean cannot'
            " represent a non boolean value"
        ),
    )


def test_optional_id_input_object_field_provided_with_1() raises:
    """Optional ID input object field provided with 1."""
    expect_hidden(scalar_input("ID"), FOO_QUERY, '{"input":{"bar":1}}', "")


def test_optional_id_input_object_field_provided_with_string_123() raises:
    """Optional ID input object field provided with string 123."""
    expect_hidden(scalar_input("ID"), FOO_QUERY, '{"input":{"bar":"123"}}', "")


def test_optional_id_input_object_field_provided_with_string_hello() raises:
    """Optional ID input object field provided with string hello."""
    expect_hidden(
        scalar_input("ID"), FOO_QUERY, '{"input":{"bar":"hello"}}', ""
    )


def test_optional_id_input_object_field_provided_with_true() raises:
    """Optional ID input object field provided with true."""
    expect_hidden(
        scalar_input("ID"),
        FOO_QUERY,
        '{"input":{"bar":true}}',
        (
            'Variable "$input" got invalid value at "input.bar"; ID cannot'
            " represent a non-string and non-integer value"
        ),
    )


def test_optional_id_input_object_field_provided_with_null() raises:
    """Optional ID input object field provided with null."""
    expect_hidden(scalar_input("ID"), FOO_QUERY, '{"input":{"bar":null}}', "")


def test_nested_input_object_on_nested_input_object_provided_with_incorrect_value_1() raises:
    """Nested input object on nested input object provided with incorrect
    value 1."""
    expect_hidden(
        (
            "input Foo { bar: String! } input Bar { foo: Foo! } type Query {"
            " hello(arg: Bar!): String }"
        ),
        "query Foo($input: Bar!) { hello(arg: $input) }",
        '{"input":{"foo":{"bar":1}}}',
        (
            'Variable "$input" got invalid value at "input.foo.bar"; String'
            " cannot represent a non string value"
        ),
    )


def test_nested_input_object_provided_with_null_for_upload() raises:
    """Nested input object provided with null for Upload.

    The schema declares `scalar Upload`: `build_schema` refuses an unknown
    type, and the upstream definition document does not.
    """
    expect_hidden(
        (
            "scalar Upload input Foo { file: Upload! } type Query { hello(arg:"
            " Foo!): String }"
        ),
        "query Foo($input: Foo!) { hello(arg: $input) }",
        '{"input":{"file":null}}',
        "",
    )


def test_nested_input_object_on_nested_input_object_provided_with_null_for_upload() raises:
    """Nested input object on nested input object provided with null for
    Upload. The schema declares `scalar Upload`."""
    expect_hidden(
        (
            "scalar Upload input Foo { bar: Upload! } input Bar { foo: Foo! }"
            " type Query { hello(arg: Bar!): String }"
        ),
        "query Foo($input: Bar!) { hello(arg: $input) }",
        '{"input":{"foo":{"bar":null}}}',
        "",
    )


def main() raises:
    """Run the suite."""
    TestSuite.discover_tests[__functions_in_module()]().run()
