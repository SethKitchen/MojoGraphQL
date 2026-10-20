# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.variables_validation`, ported from
graphql-go-tools v2 `pkg/variablesvalidation/variablesvalidation_test.go`
`TestVariablesValidation`, part 2. Each docstring is the upstream subtest
name.
"""

from _vv_helpers import expect_hidden, expect_shown, remap
from std.testing import TestSuite

comptime FOO_INPUT = (
    "input Foo { bar: String! } type Query { hello(arg: Foo!): String }"
)
"""The schema with the input object `Foo { bar: String! }`."""
comptime FOO_QUERY = "query Foo($bar: Foo!) { hello(arg: $bar) }"
"""The operation that takes `$bar: Foo!`."""


def test_required_boolean_field_argument_not_provided() raises:
    """Required Boolean field argument not provided."""
    expect_hidden(
        "type Query { hello(arg: Boolean!): String }",
        "query Foo($bar: Boolean!) { hello }",
        "{}",
        'Variable "$bar" of required type "Boolean!" was not provided.',
    )


def test_required_id_field_argument_not_provided() raises:
    """Required ID field argument not provided."""
    expect_hidden(
        "type Query { hello(arg: ID!): String }",
        "query Foo($bar: ID!) { hello }",
        "{}",
        'Variable "$bar" of required type "ID!" was not provided.',
    )


def test_required_id_field_argument_provided_with_int() raises:
    """Required ID field argument provided with Int."""
    expect_hidden(
        "type Query { hello(arg: ID!): String }",
        "query Foo($bar: ID!) { hello(arg: $bar) }",
        '{"bar":123}',
        "",
    )


def test_required_id_field_argument_provided_with_string() raises:
    """Required ID field argument provided with String."""
    expect_hidden(
        "type Query { hello(arg: ID!): String }",
        "query Foo($bar: ID!) { hello(arg: $bar) }",
        '{"bar":"hello"}',
        "",
    )


def test_required_enum_field_argument_not_provided() raises:
    """Required Enum field argument not provided."""
    expect_hidden(
        "enum Foo { BAR } type Query { hello(arg: Foo!): String }",
        "query Foo($bar: Foo!) { hello }",
        "{}",
        'Variable "$bar" of required type "Foo!" was not provided.',
    )


def test_required_input_object_field_argument_not_provided() raises:
    """Required input object field argument not provided."""
    expect_hidden(
        FOO_INPUT,
        "query Foo($bar: Foo!) { hello }",
        "{}",
        'Variable "$bar" of required type "Foo!" was not provided.',
    )


def test_required_string_list_field_argument_not_provided() raises:
    """Required string list field argument not provided."""
    expect_hidden(
        "type Query { hello(arg: [String]!): String }",
        "query Foo($bar: [String]!) { hello }",
        "{}",
        'Variable "$bar" of required type "[String]!" was not provided.',
    )


def test_wrong_boolean_value_for_input_object_field_with_variable_content() raises:
    """Wrong Boolean value for input object field - with variable content."""
    expect_shown(
        FOO_INPUT,
        FOO_QUERY,
        '{"bar":true}',
        (
            'Variable "$bar" got invalid value true; Expected type "Foo" to be'
            " an object."
        ),
    )


def test_wrong_boolean_value_for_input_object_field() raises:
    """Wrong Boolean value for input object field."""
    expect_hidden(
        FOO_INPUT,
        FOO_QUERY,
        '{"bar":true}',
        (
            'Variable "$bar" got invalid value; Expected type "Foo" to be an'
            " object."
        ),
    )


def test_wrong_integer_value_for_input_object_field_with_variable_content() raises:
    """Wrong Integer value for input object field - with variable content."""
    expect_shown(
        FOO_INPUT,
        FOO_QUERY,
        '{"bar":123}',
        (
            'Variable "$bar" got invalid value 123; Expected type "Foo" to be'
            " an object."
        ),
    )


def test_wrong_integer_value_for_input_object_field() raises:
    """Wrong Integer value for input object field."""
    expect_hidden(
        FOO_INPUT,
        FOO_QUERY,
        '{"bar":123}',
        (
            'Variable "$bar" got invalid value; Expected type "Foo" to be an'
            " object."
        ),
    )


def test_required_field_on_present_input_object_not_provided_with_variable_content() raises:
    """Required field on present input object not provided - with variable
    content."""
    expect_shown(
        FOO_INPUT,
        FOO_QUERY,
        '{"bar":{}}',
        (
            'Variable "$bar" got invalid value {}; Field "bar" of required type'
            ' "String!" was not provided.'
        ),
    )


def test_required_field_on_present_input_object_not_provided() raises:
    """Required field on present input object not provided."""
    expect_hidden(
        FOO_INPUT,
        FOO_QUERY,
        '{"bar":{}}',
        (
            'Variable "$bar" got invalid value; Field "bar" of required type'
            ' "String!" was not provided.'
        ),
    )


def test_required_field_on_present_input_object_provided_with_correct_type() raises:
    """Required field on present input object provided with correct type."""
    expect_hidden(FOO_INPUT, FOO_QUERY, '{"bar":{"bar":"hello"}}', "")


comptime INPUT_QUERY = "query Foo($input: Foo!) { hello(arg: $input) }"
"""The operation that takes `$input: Foo!`."""


def test_required_field_on_present_input_object_provided_with_wrong_type_with_variable_content() raises:
    """Required field on present input object provided with wrong type -
    with variable content."""
    expect_shown(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":123}}',
        (
            'Variable "$input" got invalid value 123 at "input.bar"; String'
            " cannot represent a non string value: 123"
        ),
    )


def test_required_field_on_present_input_object_provided_with_wrong_type() raises:
    """Required field on present input object provided with wrong type."""
    expect_hidden(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":123}}',
        (
            'Variable "$input" got invalid value at "input.bar"; String cannot'
            " represent a non string value"
        ),
    )


def test_required_field_on_present_input_object_not_provided_with_variable_content_input() raises:
    """Required field on present input object not provided - with variable
    content (the second upstream case, with `$input`)."""
    expect_shown(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{}}',
        (
            'Variable "$input" got invalid value {}; Field "bar" of required'
            ' type "String!" was not provided.'
        ),
    )


def test_required_field_on_present_input_object_not_provided_input() raises:
    """Required field on present input object not provided (the second
    upstream case, with `$input`)."""
    expect_hidden(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{}}',
        (
            'Variable "$input" got invalid value; Field "bar" of required type'
            ' "String!" was not provided.'
        ),
    )


def test_required_string_field_on_input_object_provided_with_null_with_variable_content() raises:
    """Required string field on input object provided with null - with
    variable content."""
    expect_shown(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":null}}',
        (
            'Variable "$input" got invalid value {"bar":null}; Field "bar" of'
            ' required type "String!" was not provided.'
        ),
    )


def test_required_string_field_on_input_object_provided_with_null() raises:
    """Required string field on input object provided with null."""
    expect_hidden(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":null}}',
        (
            'Variable "$input" got invalid value; Field "bar" of required type'
            ' "String!" was not provided.'
        ),
    )


def test_required_string_field_on_input_object_provided_with_int_with_variable_content() raises:
    """Required string field on input object provided with Int - with
    variable content."""
    expect_shown(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":123}}',
        (
            'Variable "$input" got invalid value 123 at "input.bar"; String'
            " cannot represent a non string value: 123"
        ),
    )


def test_required_string_field_on_input_object_provided_with_int() raises:
    """Required string field on input object provided with Int."""
    expect_hidden(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":123}}',
        (
            'Variable "$input" got invalid value at "input.bar"; String cannot'
            " represent a non string value"
        ),
    )


def test_required_string_field_on_input_object_provided_with_float_with_variable_content() raises:
    """Required string field on input object provided with Float - with
    variable content."""
    expect_shown(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":123.456}}',
        (
            'Variable "$input" got invalid value 123.456 at "input.bar"; String'
            " cannot represent a non string value: 123.456"
        ),
    )


def test_required_string_field_on_input_object_provided_with_float() raises:
    """Required string field on input object provided with Float."""
    expect_hidden(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":123.456}}',
        (
            'Variable "$input" got invalid value at "input.bar"; String cannot'
            " represent a non string value"
        ),
    )


def test_required_string_field_on_input_object_provided_with_boolean_with_variable_content() raises:
    """Required string field on input object provided with Boolean - with
    variable content."""
    expect_shown(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":true}}',
        (
            'Variable "$input" got invalid value true at "input.bar"; String'
            " cannot represent a non string value: true"
        ),
    )


def test_required_string_field_on_input_object_provided_with_boolean() raises:
    """Required string field on input object provided with Boolean."""
    expect_hidden(
        FOO_INPUT,
        INPUT_QUERY,
        '{"input":{"bar":true}}',
        (
            'Variable "$input" got invalid value at "input.bar"; String cannot'
            " represent a non string value"
        ),
    )


comptime BAR_INPUT = (
    "input Foo { bar: String! } input Bar { foo: Foo! } type Query {"
    " hello(arg: Bar!): String }"
)
"""The schema with `Bar { foo: Foo! }` around `Foo { bar: String! }`."""
comptime BAR_QUERY = "query Foo($input: Bar!) { hello(arg: $input) }"
"""The operation that takes `$input: Bar!`."""


def test_required_string_field_on_nested_input_object_not_provided_with_variable_content() raises:
    """Required string field on nested input object not provided - with
    variable content."""
    expect_shown(
        BAR_INPUT,
        BAR_QUERY,
        '{"input":{"foo":{}}}',
        (
            'Variable "$input" got invalid value {"foo":{}}; Field "bar" of'
            ' required type "String!" was not provided.'
        ),
    )


def test_required_string_field_on_nested_input_object_not_provided() raises:
    """Required string field on nested input object not provided."""
    expect_hidden(
        BAR_INPUT,
        BAR_QUERY,
        '{"input":{"foo":{}}}',
        (
            'Variable "$input" got invalid value; Field "bar" of required type'
            ' "String!" was not provided.'
        ),
    )


def test_required_string_field_on_nested_input_object_provided_with_null_with_variable_content() raises:
    """Required string field on nested input object provided with null -
    with variable content."""
    expect_shown(
        BAR_INPUT,
        BAR_QUERY,
        '{"input":{"foo":{"bar":null}}}',
        (
            'Variable "$input" got invalid value {"foo":{"bar":null}}; Field'
            ' "bar" of required type "String!" was not provided.'
        ),
    )


def test_required_string_field_on_nested_input_object_provided_with_null() raises:
    """Required string field on nested input object provided with null."""
    expect_hidden(
        BAR_INPUT,
        BAR_QUERY,
        '{"input":{"foo":{"bar":null}}}',
        (
            'Variable "$input" got invalid value; Field "bar" of required type'
            ' "String!" was not provided.'
        ),
    )


def test_required_string_field_on_nested_input_object_provided_with_int_with_variable_content() raises:
    """Required string field on nested input object provided with Int - with
    variable content."""
    expect_shown(
        BAR_INPUT,
        BAR_QUERY,
        '{"input":{"foo":{"bar":123}}}',
        (
            'Variable "$input" got invalid value 123 at "input.foo.bar"; String'
            " cannot represent a non string value: 123"
        ),
    )


def test_required_string_field_on_nested_input_object_provided_with_int() raises:
    """Required string field on nested input object provided with Int."""
    expect_hidden(
        BAR_INPUT,
        BAR_QUERY,
        '{"input":{"foo":{"bar":123}}}',
        (
            'Variable "$input" got invalid value at "input.foo.bar"; String'
            " cannot represent a non string value"
        ),
    )


comptime BAR_LIST_INPUT = (
    "input Foo { bar: String! } input Bar { foo: [Foo!]! } type Query {"
    " hello(arg: Bar!): String }"
)
"""The schema with `Bar { foo: [Foo!]! }`."""


def test_required_string_field_on_nested_input_object_array_provided_with_int_with_variable_content() raises:
    """Required string field on nested input object array provided with Int
    - with variable content."""
    expect_shown(
        BAR_LIST_INPUT,
        BAR_QUERY,
        '{"input":{"foo":[{"bar":123}]}}',
        (
            'Variable "$input" got invalid value 123 at "input.foo.[0].bar";'
            " String cannot represent a non string value: 123"
        ),
    )


def test_required_string_field_on_nested_input_object_array_provided_with_int() raises:
    """Required string field on nested input object array provided with Int."""
    expect_hidden(
        BAR_LIST_INPUT,
        BAR_QUERY,
        '{"input":{"foo":[{"bar":123}]}}',
        (
            'Variable "$input" got invalid value at "input.foo.[0].bar"; String'
            " cannot represent a non string value"
        ),
    )


def test_required_string_field_on_nested_input_object_array_index_1_provided_with_int_with_variable_content() raises:
    """Required string field on nested input object array index 1 provided
    with Int - with variable content."""
    expect_shown(
        BAR_LIST_INPUT,
        BAR_QUERY,
        '{"input":{"foo":[{"bar":"hello"},{"bar":123}]}}',
        (
            'Variable "$input" got invalid value 123 at "input.foo.[1].bar";'
            " String cannot represent a non string value: 123"
        ),
    )


def test_required_string_field_on_nested_input_object_array_index_1_provided_with_int() raises:
    """Required string field on nested input object array index 1 provided
    with Int."""
    expect_hidden(
        BAR_LIST_INPUT,
        BAR_QUERY,
        '{"input":{"foo":[{"bar":"hello"},{"bar":123}]}}',
        (
            'Variable "$input" got invalid value at "input.foo.[1].bar"; String'
            " cannot represent a non string value"
        ),
    )


def test_non_existing_field_on_nested_input_object_with_variable_content() raises:
    """Non existing field on nested input object - with variable content."""
    expect_shown(
        BAR_INPUT,
        BAR_QUERY,
        '{"input":{"foo":{"bar":"hello","baz":"world"}}}',
        (
            'Variable "$input" got invalid value'
            ' {"foo":{"bar":"hello","baz":"world"}} at "input.foo"; Field "baz"'
            ' is not defined by type "Foo".'
        ),
    )


def test_non_existing_field_on_nested_input_object() raises:
    """Non existing field on nested input object."""
    expect_hidden(
        BAR_INPUT,
        BAR_QUERY,
        '{"input":{"foo":{"bar":"hello","baz":"world"}}}',
        (
            'Variable "$input" got invalid value at "input.foo"; Field "baz" is'
            ' not defined by type "Foo".'
        ),
    )


def main() raises:
    """Run the suite."""
    TestSuite.discover_tests[__functions_in_module()]().run()
