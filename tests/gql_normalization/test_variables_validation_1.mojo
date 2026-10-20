# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.variables_validation`, ported from
graphql-go-tools v2 `pkg/variablesvalidation/variablesvalidation_test.go`
`TestVariablesValidation`, part 1. Each docstring is the upstream subtest
name.
"""

from _vv_helpers import (
    INPUT_SCHEMA,
    remap,
    run_test,
    run_test_with_variables_content_enabled,
)
from std.testing import TestSuite, assert_equal


def test_required_field_argument_not_provided() raises:
    """Required field argument not provided."""
    assert_equal(
        run_test(
            "type Query { hello(arg: String!): String }",
            "query Foo($bar: String!) { hello }",
            "{}",
        ),
        'Variable "$bar" of required type "String!" was not provided.',
    )


def test_required_field_argument_not_provided_with_mapping() raises:
    """Required field argument not provided - with mapping."""
    assert_equal(
        run_test(
            "type Query { hello(arg: String!): String }",
            "query Foo($bar: String!) { hello }",
            "{}",
            remap("bar", "bazz"),
        ),
        'Variable "$bazz" of required type "String!" was not provided.',
    )


def test_a_missing_required_input_produces_an_error() raises:
    """A missing required input produces an error."""
    assert_equal(
        run_test(
            INPUT_SCHEMA,
            "query Foo($input: SelfSatisfiedInput!) { satisfied }",
            "{}",
        ),
        (
            'Variable "$input" of required type "SelfSatisfiedInput!" was not'
            " provided."
        ),
    )


def test_provided_required_input_fields_with_default_values_do_not_produce_validation_errors() raises:
    """Provided required input fields with default values do not produce
    validation errors."""
    assert_equal(
        run_test(
            INPUT_SCHEMA,
            (
                "query Foo($input: SelfSatisfiedInput!) { satisfied(input:"
                " $input) }"
            ),
            '{ "input": { } }',
        ),
        "",
    )


def test_unprovided_required_input_fields_1_with_variable_content() raises:
    """Unprovided required input fields without default values produce
    validation errors #1 - with variable content."""
    assert_equal(
        run_test_with_variables_content_enabled(
            INPUT_SCHEMA,
            (
                "query Foo($input: SelfUnsatisfiedInput!) { unsatisfied(input:"
                " $input) }"
            ),
            '{ "input": { } }',
        ),
        (
            'Variable "$input" got invalid value {}; Field "nested" of required'
            ' type "NestedSelfSatisfiedInput!" was not provided.'
        ),
    )


def test_unprovided_required_input_fields_1() raises:
    """Unprovided required input fields without default values produce
    validation errors #1."""
    assert_equal(
        run_test(
            INPUT_SCHEMA,
            (
                "query Foo($input: SelfUnsatisfiedInput!) { unsatisfied(input:"
                " $input) }"
            ),
            '{ "input": { } }',
        ),
        (
            'Variable "$input" got invalid value; Field "nested" of required'
            ' type "NestedSelfSatisfiedInput!" was not provided.'
        ),
    )


def test_unprovided_required_input_fields_2_with_variable_content() raises:
    """Unprovided required input fields without default values produce
    validation errors #2 - with variable content."""
    assert_equal(
        run_test_with_variables_content_enabled(
            INPUT_SCHEMA,
            (
                "query Foo($input: SelfUnsatisfiedInput!) { unsatisfied(input:"
                " $input) }"
            ),
            '{ "input": { "nested": { }, "value": "string" } }',
        ),
        (
            'Variable "$input" got invalid value'
            ' {"nested":{},"value":"string"}; Field "secondNested" of required'
            ' type "NestedSelfSatisfiedInput!" was not provided.'
        ),
    )


def test_unprovided_required_input_fields_2() raises:
    """Unprovided required input fields without default values produce
    validation errors #2."""
    assert_equal(
        run_test(
            INPUT_SCHEMA,
            (
                "query Foo($input: SelfUnsatisfiedInput!) { unsatisfied(input:"
                " $input) }"
            ),
            '{ "input": { "nested": { }, "value": "string" } }',
        ),
        (
            'Variable "$input" got invalid value; Field "secondNested" of'
            ' required type "NestedSelfSatisfiedInput!" was not provided.'
        ),
    )


def test_provided_but_empty_nested_required_inputs_with_default_values_do_not_produce_validation_errors() raises:
    """Provided but empty nested required inputs with default values do not
    produce validation errors."""
    assert_equal(
        run_test(
            INPUT_SCHEMA,
            (
                "query Foo($input: SelfUnsatisfiedInput!) { unsatisfied(input:"
                " $input) }"
            ),
            '{ "input": { "nested": { }, "secondNested": { } } }',
        ),
        "",
    )


def test_not_required_field_argument_not_provided() raises:
    """Not required field argument not provided."""
    assert_equal(
        run_test(
            "type Query { hello(arg: String): String }",
            "query Foo($bar: String) { hello }",
            "{}",
        ),
        "",
    )


def test_required_field_argument_provided() raises:
    """Required field argument provided."""
    assert_equal(
        run_test(
            "type Query { hello(arg: String!): String }",
            "query Foo($bar: String!) { hello(arg: $bar) }",
            '{"bar": "world"}',
        ),
        "",
    )


def test_nested_argument_is_value_instead_of_list_with_variable_content() raises:
    """Nested argument is value instead of list - with variable content."""
    assert_equal(
        run_test_with_variables_content_enabled(
            (
                "type Query { hello(input: Input): String } input Input { bar:"
                " [String]! }"
            ),
            "query Foo($input: Input) { hello(input: $input) }",
            '{"input":{"bar":"world"}}',
        ),
        (
            'Variable "$input" got invalid value "world" at "input.bar"; Got'
            ' input type "String", want: "[String]"'
        ),
    )


def test_nested_argument_is_value_instead_of_list() raises:
    """Nested argument is value instead of list."""
    assert_equal(
        run_test(
            (
                "type Query { hello(input: Input): String } input Input { bar:"
                " [String]! }"
            ),
            "query Foo($input: Input) { hello(input: $input) }",
            '{"input":{"bar":"world"}}',
        ),
        (
            'Variable "$input" got invalid value at "input.bar"; Got input type'
            ' "String", want: "[String]"'
        ),
    )


def test_nested_argument_is_value_instead_of_list_with_mapping() raises:
    """Nested argument is value instead of list - with mapping."""
    assert_equal(
        run_test(
            (
                "type Query { hello(input: Input): String } input Input { bar:"
                " [String]! }"
            ),
            "query Foo($input: Input) { hello(input: $input) }",
            '{"honeypot":{"bar":"world"}}',
            remap("input", "honeypot"),
        ),
        (
            'Variable "$honeypot" got invalid value at "honeypot.bar"; Got'
            ' input type "String", want: "[String]"'
        ),
    )


def test_nested_enum_argument_is_value_instead_of_list_with_variable_content() raises:
    """Nested enum argument is value instead of list - with variable content."""
    assert_equal(
        run_test_with_variables_content_enabled(
            (
                "type Query { hello(input: Input): String } input Input { bar:"
                " [MyNum]! } enum MyNum { ONE TWO }"
            ),
            "query Foo($input: Input) { hello(input: $input) }",
            '{"input":{"bar":"ONE"}}',
        ),
        (
            'Variable "$input" got invalid value "ONE" at "input.bar"; Got'
            ' input type "MyNum", want: "[MyNum]"'
        ),
    )


def test_nested_enum_argument_is_value_instead_of_list() raises:
    """Nested enum argument is value instead of list."""
    assert_equal(
        run_test(
            (
                "type Query { hello(input: Input): String } input Input { bar:"
                " [MyNum]! } enum MyNum { ONE TWO }"
            ),
            "query Foo($input: Input) { hello(input: $input) }",
            '{"input":{"bar":"ONE"}}',
        ),
        (
            'Variable "$input" got invalid value at "input.bar"; Got input type'
            ' "MyNum", want: "[MyNum]"'
        ),
    )


def test_required_field_argument_of_custom_scalar_type_not_provided() raises:
    """Required field argument of custom scalar type not provided."""
    assert_equal(
        run_test(
            "type Query { hello(arg: Baz!): String } scalar Baz",
            "query Foo($bar: Baz!) { hello(arg: $bar) }",
            "{}",
        ),
        'Variable "$bar" of required type "Baz!" was not provided.',
    )


def test_required_field_argument_of_custom_scalar_type_was_null() raises:
    """Required field argument of custom scalar type was null."""
    assert_equal(
        run_test(
            "type Query { hello(arg: Baz!): String } scalar Baz",
            "query Foo($bar: Baz!) { hello(arg: $bar) }",
            '{"bar":null}',
        ),
        (
            'Variable "$bar" got invalid value null; Expected non-nullable type'
            ' "Baz!" not to be null.'
        ),
    )


comptime CUSTOM_NESTED = (
    "type Query { hello(arg: Foo!): String } input Foo { bar: Baz! } scalar Baz"
)
"""The schema of the nested custom scalar cases."""


def test_required_nested_field_argument_of_custom_scalar_not_provided_with_variable_content() raises:
    """Required nested field field argument of custom scalar not provided -
    with variable content."""
    assert_equal(
        run_test_with_variables_content_enabled(
            CUSTOM_NESTED,
            "query Foo($bar: Foo!) { hello(arg: $bar) }",
            '{"bar":{}}',
        ),
        (
            'Variable "$bar" got invalid value {}; Field "bar" of required type'
            ' "Baz!" was not provided.'
        ),
    )


def test_required_nested_field_argument_of_custom_scalar_not_provided() raises:
    """Required nested field field argument of custom scalar not provided."""
    assert_equal(
        run_test(
            CUSTOM_NESTED,
            "query Foo($bar: Foo!) { hello(arg: $bar) }",
            '{"bar":{}}',
        ),
        (
            'Variable "$bar" got invalid value; Field "bar" of required type'
            ' "Baz!" was not provided.'
        ),
    )


def test_required_nested_field_argument_of_custom_scalar_not_provided_with_mapping() raises:
    """Required nested field field argument of custom scalar not provided -
    with mapping."""
    assert_equal(
        run_test(
            CUSTOM_NESTED,
            "query Foo($bar: Foo!) { hello(arg: $bar) }",
            '{"abc":{}}',
            remap("bar", "abc"),
        ),
        (
            'Variable "$abc" got invalid value; Field "bar" of required type'
            ' "Baz!" was not provided.'
        ),
    )


def test_required_nested_field_argument_of_custom_scalar_was_null_with_variable_content() raises:
    """Required nested field field argument of custom scalar was null - with
    variable content."""
    assert_equal(
        run_test_with_variables_content_enabled(
            CUSTOM_NESTED,
            "query Foo($bar: Foo!) { hello(arg: $bar) }",
            '{"bar":{"bar":null}}',
        ),
        (
            'Variable "$bar" got invalid value {"bar":null}; Field "bar" of'
            ' required type "Baz!" was not provided.'
        ),
    )


def test_required_nested_field_argument_of_custom_scalar_was_null() raises:
    """Required nested field field argument of custom scalar was null."""
    assert_equal(
        run_test(
            CUSTOM_NESTED,
            "query Foo($bar: Foo!) { hello(arg: $bar) }",
            '{"bar":{"bar":null}}',
        ),
        (
            'Variable "$bar" got invalid value; Field "bar" of required type'
            ' "Baz!" was not provided.'
        ),
    )


def test_required_int_field_argument_not_provided() raises:
    """Required Int field argument not provided."""
    assert_equal(
        run_test(
            "type Query { hello(arg: Int!): String }",
            "query Foo($bar: Int!) { hello }",
            "{}",
        ),
        'Variable "$bar" of required type "Int!" was not provided.',
    )


def test_required_float_field_argument_not_provided() raises:
    """Required Float field argument not provided."""
    assert_equal(
        run_test(
            "type Query { hello(arg: Float!): String }",
            "query Foo($bar: Float!) { hello }",
            "{}",
        ),
        'Variable "$bar" of required type "Float!" was not provided.',
    )


def main() raises:
    """Run the suite."""
    TestSuite.discover_tests[__functions_in_module()]().run()
