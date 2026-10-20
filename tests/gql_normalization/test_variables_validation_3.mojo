# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.variables_validation`, ported from
graphql-go-tools v2 `pkg/variablesvalidation/variablesvalidation_test.go`
`TestVariablesValidation`, part 3: the enum cases. Each docstring is the
upstream subtest name.
"""

from _vv_helpers import expect_hidden, expect_shown
from std.testing import TestSuite

comptime ENUM_SCHEMA = (
    "enum Foo { BAR } type Query { hello(arg: Foo!): String }"
)
"""The schema with a required enum argument."""
comptime ENUM_QUERY = "query Foo($bar: Foo!) { hello(arg: $bar) }"
"""The operation that takes `$bar: Foo!`."""
comptime NESTED_ENUM = (
    "enum Foo { BAR } input Bar { foo: Foo! } type Query { hello(arg: Bar!):"
    " String }"
)
"""The schema with a required enum input field."""
comptime NESTED_QUERY = "query Foo($input: Bar!) { hello(arg: $input) }"
"""The operation that takes `$input: Bar!`."""
comptime OPTIONAL_NESTED_ENUM = (
    "enum Foo { BAR } input Bar { foo: Foo } type Query { hello(arg: Bar):"
    " String }"
)
"""The schema with an optional enum input field."""
comptime OPTIONAL_NESTED_QUERY = "query Foo($input: Bar) { hello(arg: $input) }"
"""The operation that takes `$input: Bar`."""


def test_required_enum_argument_provided_with_correct_value() raises:
    """Required enum argument provided with correct value."""
    expect_hidden(ENUM_SCHEMA, ENUM_QUERY, '{"bar":"BAR"}', "")


def test_required_enum_argument_provided_with_wrong_value_with_variable_content() raises:
    """Required enum argument provided with wrong value - with variable
    content."""
    expect_shown(
        ENUM_SCHEMA,
        ENUM_QUERY,
        '{"bar":"BAZ"}',
        (
            'Variable "$bar" got invalid value "BAZ"; Value "BAZ" does not'
            ' exist in "Foo" enum.'
        ),
    )


def test_required_enum_argument_provided_with_wrong_value() raises:
    """Required enum argument provided with wrong value."""
    expect_hidden(
        ENUM_SCHEMA,
        ENUM_QUERY,
        '{"bar":"BAZ"}',
        (
            'Variable "$bar" got invalid value; Value does not exist in "Foo"'
            " enum."
        ),
    )


def test_required_enum_argument_provided_with_int_value_with_variable_content() raises:
    """Required enum argument provided with Int value - with variable
    content."""
    expect_shown(
        ENUM_SCHEMA,
        ENUM_QUERY,
        '{"bar":123}',
        (
            'Variable "$bar" got invalid value 123; Enum "Foo" cannot represent'
            " non-string value: 123."
        ),
    )


def test_required_enum_argument_provided_with_int_value() raises:
    """Required enum argument provided with Int value."""
    expect_hidden(
        ENUM_SCHEMA,
        ENUM_QUERY,
        '{"bar":123}',
        (
            'Variable "$bar" got invalid value; Enum "Foo" cannot represent'
            " non-string value."
        ),
    )


def test_required_enum_argument_provided_with_null() raises:
    """Required enum argument provided with null."""
    expect_hidden(
        ENUM_SCHEMA,
        ENUM_QUERY,
        '{"bar":null}',
        (
            'Variable "$bar" got invalid value null; Expected non-nullable type'
            ' "Foo!" not to be null.'
        ),
    )


def test_required_nested_enum_argument_provided_with_null_with_variable_content() raises:
    """Required nested enum argument provided with null - with variable
    content."""
    expect_shown(
        NESTED_ENUM,
        NESTED_QUERY,
        '{"input":{"foo":null}}',
        (
            'Variable "$input" got invalid value {"foo":null}; Field "foo" of'
            ' required type "Foo!" was not provided.'
        ),
    )


def test_required_nested_enum_argument_provided_with_null() raises:
    """Required nested enum argument provided with null."""
    expect_hidden(
        NESTED_ENUM,
        NESTED_QUERY,
        '{"input":{"foo":null}}',
        (
            'Variable "$input" got invalid value; Field "foo" of required type'
            ' "Foo!" was not provided.'
        ),
    )


def test_required_nested_enum_argument_provided_with_correct_value() raises:
    """Required nested enum argument provided with correct value."""
    expect_hidden(NESTED_ENUM, NESTED_QUERY, '{"input":{"foo":"BAR"}}', "")


def test_required_nested_enum_argument_provided_with_wrong_value_with_variable_content() raises:
    """Required nested enum argument provided with wrong value - with
    variable content."""
    expect_shown(
        NESTED_ENUM,
        NESTED_QUERY,
        '{"input":{"foo":"BAZ"}}',
        (
            'Variable "$input" got invalid value {"foo":"BAZ"} at "input.foo";'
            ' Value "BAZ" does not exist in "Foo" enum.'
        ),
    )


def test_required_nested_enum_argument_provided_with_wrong_value() raises:
    """Required nested enum argument provided with wrong value."""
    expect_hidden(
        NESTED_ENUM,
        NESTED_QUERY,
        '{"input":{"foo":"BAZ"}}',
        (
            'Variable "$input" got invalid value at "input.foo"; Value does not'
            ' exist in "Foo" enum.'
        ),
    )


def test_optional_enum_argument_provided_with_null() raises:
    """Optional enum argument provided with null."""
    expect_hidden(
        "enum Foo { BAR } type Query { hello(arg: Foo): String }",
        "query Foo($bar: Foo) { hello(arg: $bar) }",
        '{"bar":null}',
        "",
    )


def test_optional_nested_enum_argument_provided_with_null() raises:
    """Optional nested enum argument provided with null."""
    expect_hidden(
        OPTIONAL_NESTED_ENUM,
        OPTIONAL_NESTED_QUERY,
        '{"input":{"foo":null}}',
        "",
    )


def test_optional_nested_enum_argument_provided_with_incorrect_value_with_variable_content() raises:
    """Optional nested enum argument provided with incorrect value - with
    variable content."""
    expect_shown(
        OPTIONAL_NESTED_ENUM,
        OPTIONAL_NESTED_QUERY,
        '{"input":{"foo":"BAZ"}}',
        (
            'Variable "$input" got invalid value {"foo":"BAZ"} at "input.foo";'
            ' Value "BAZ" does not exist in "Foo" enum.'
        ),
    )


def test_optional_nested_enum_argument_provided_with_incorrect_value() raises:
    """Optional nested enum argument provided with incorrect value."""
    expect_hidden(
        OPTIONAL_NESTED_ENUM,
        OPTIONAL_NESTED_QUERY,
        '{"input":{"foo":"BAZ"}}',
        (
            'Variable "$input" got invalid value at "input.foo"; Value does not'
            ' exist in "Foo" enum.'
        ),
    )


def test_optional_enum_argument_provided_with_correct_value() raises:
    """Optional enum argument provided with correct value."""
    expect_hidden(
        "enum Foo { BAR } type Query { hello(arg: Foo): String }",
        "query Foo($bar: Foo) { hello(arg: $bar) }",
        '{"bar":"BAR"}',
        "",
    )


def test_optional_enum_argument_provided_with_wrong_value_with_variable_content() raises:
    """Optional enum argument provided with wrong value - with variable
    content."""
    expect_shown(
        "enum Foo { BAR } type Query { hello(arg: Foo): String }",
        "query Foo($bar: Foo) { hello(arg: $bar) }",
        '{"bar":"BAZ"}',
        (
            'Variable "$bar" got invalid value "BAZ"; Value "BAZ" does not'
            ' exist in "Foo" enum.'
        ),
    )


def test_optional_enum_argument_provided_with_wrong_value() raises:
    """Optional enum argument provided with wrong value."""
    expect_hidden(
        "enum Foo { BAR } type Query { hello(arg: Foo): String }",
        "query Foo($bar: Foo) { hello(arg: $bar) }",
        '{"bar":"BAZ"}',
        (
            'Variable "$bar" got invalid value; Value does not exist in "Foo"'
            " enum."
        ),
    )


def test_required_string_list_field_argument_provided_with_null() raises:
    """Required string list field argument provided with null."""
    expect_hidden(
        "type Query { hello(arg: [String]!): String }",
        "query Foo($bar: [String]!) { hello(arg: $bar) }",
        '{"bar":null}',
        (
            'Variable "$bar" got invalid value null; Expected non-nullable type'
            ' "[String]!" not to be null.'
        ),
    )


comptime FOO_LIST = (
    "input Foo { bar: String! } type Query { hello(arg: [Foo!]!): String }"
)
"""The schema with a required list of input objects."""
comptime FOO_LIST_QUERY = "query Foo($bar: [Foo!]!) { hello(arg: $bar) }"
"""The operation that takes `$bar: [Foo!]!`."""


def test_required_string_argument_on_input_object_list_provided_with_correct_value() raises:
    """Required string argument on input object list provided with correct
    value."""
    expect_hidden(FOO_LIST, FOO_LIST_QUERY, '{"bar":[{"bar":"hello"}]}', "")


def test_required_string_argument_on_input_object_list_provided_with_wrong_value() raises:
    """Required string argument on input object list provided with wrong
    value."""
    expect_hidden(
        FOO_LIST,
        FOO_LIST_QUERY,
        '{"bar":[{"bar":123}]}',
        (
            'Variable "$bar" got invalid value at "bar.[0].bar"; String cannot'
            " represent a non string value"
        ),
    )


def test_required_string_argument_on_input_object_list_provided_with_wrong_value_with_variable_content() raises:
    """Required string argument on input object list provided with wrong
    value - with variable content."""
    expect_shown(
        FOO_LIST,
        FOO_LIST_QUERY,
        '{"bar":[{"bar":123}]}',
        (
            'Variable "$bar" got invalid value 123 at "bar.[0].bar"; String'
            " cannot represent a non string value: 123"
        ),
    )


def test_required_string_argument_provided_with_string_list() raises:
    """Required string argument provided with string list."""
    expect_hidden(
        "type Query { hello(arg: String!): String }",
        "query Foo($bar: String!) { hello(arg: $bar) }",
        '{"bar":["hello"]}',
        (
            'Variable "$bar" got invalid value; String cannot represent a non'
            " string value"
        ),
    )


def test_required_input_object_list_field_argument_provided_with_non_list_int_value_with_variable_content() raises:
    """Required input object list field argument provided with non list Int
    value - with variable content."""
    expect_shown(
        FOO_LIST,
        FOO_LIST_QUERY,
        '{"bar":123}',
        (
            'Variable "$bar" got invalid value 123; Expected type "Foo" to be'
            " an object."
        ),
    )


def test_required_input_object_list_field_argument_provided_with_non_list_int_value() raises:
    """Required input object list field argument provided with non list Int
    value."""
    expect_hidden(
        FOO_LIST,
        FOO_LIST_QUERY,
        '{"bar":123}',
        (
            'Variable "$bar" got invalid value; Expected type "Foo" to be an'
            " object."
        ),
    )


def test_required_input_object_field_argument_provided_with_list_input_object_value_with_variable_content() raises:
    """Required input object field argument provided with list input object
    value - with variable content."""
    expect_shown(
        "input Foo { bar: String! } type Query { hello(arg: Foo!): String }",
        "query Foo($bar: Foo!) { hello(arg: $bar) }",
        '{"bar":[{"bar":"hello"}]}',
        (
            'Variable "$bar" got invalid value [{"bar":"hello"}]; Expected type'
            ' "Foo" to be an object.'
        ),
    )


def test_required_input_object_field_argument_provided_with_list_input_object_value() raises:
    """Required input object field argument provided with list input object
    value."""
    expect_hidden(
        "input Foo { bar: String! } type Query { hello(arg: Foo!): String }",
        "query Foo($bar: Foo!) { hello(arg: $bar) }",
        '{"bar":[{"bar":"hello"}]}',
        (
            'Variable "$bar" got invalid value; Expected type "Foo" to be an'
            " object."
        ),
    )


def main() raises:
    """Run the suite."""
    TestSuite.discover_tests[__functions_in_module()]().run()
