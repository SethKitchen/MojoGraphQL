# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.variables_validation`, ported from
graphql-go-tools v2 `pkg/variablesvalidation/variablesvalidation_test.go`
`TestVariablesValidation`: the cases with `withNormalization: true`. The
operation is normalized with `NewNormalizer(true, true)` before the
validation, as upstream `runTestWithOptions` does. Each docstring is the
upstream subtest name.
"""

from gql_language.parser import parse
from gql_normalization.normalize import OperationNormalizer
from gql_normalization.variables_validation import (
    VariablesValidator,
    VariablesValidatorOptions,
)
from gql_schema.build import build_schema
from std.testing import TestSuite, assert_equal


def run_normalized(
    schema: String, operation: String, variables: String, hide: Bool
) raises -> String:
    """Normalize, then validate, as upstream `runTestWithOptions` with
    `withNormalization`.

    Args:
        schema: The SDL.
        operation: The operation text.
        variables: The variables JSON.
        hide: Set `disable_exposing_variables_content`.

    Returns:
        The message, or empty when the variables are valid.

    Raises:
        Error: When a stage fails.
    """
    var definition = build_schema(schema)
    var document = parse(operation)
    var json = variables
    OperationNormalizer.new(True, True).normalize_operation(
        document, definition, json
    )
    var options = VariablesValidatorOptions()
    options.disable_exposing_variables_content = hide
    var validator = VariablesValidator(options)
    var err = validator.validate(document, definition, json)
    if err:
        return err.value().message.copy()
    return String()


comptime STRING_LIST = "type Query { hello(arg: [String]!): String }"
"""The schema with a required list of strings."""
comptime STRING_LIST_QUERY = "query Foo($bar: [String]!) { hello(arg: $bar) }"
"""The operation that takes `$bar: [String]!`."""
comptime ENUM_LIST = (
    "enum Foo { BAR } type Query { hello(arg: [Foo]!): String }"
)
"""The schema with a required list of enums."""
comptime ENUM_LIST_QUERY = "query Foo($bar: [Foo]!) { hello(arg: $bar) }"
"""The operation that takes `$bar: [Foo]!`."""


def test_required_field_argument_provided_with_default_value() raises:
    """Required field argument provided with default value."""
    assert_equal(
        run_normalized(
            "type Query { hello(arg: String!): String }",
            'query Foo($bar: String! = "world") { hello(arg: $bar) }',
            "{}",
            True,
        ),
        "",
    )


def test_required_string_list_field_argument_provided_with_non_list_int_value_with_variable_content() raises:
    """Required string list field argument provided with non list Int value -
    with variable content."""
    assert_equal(
        run_normalized(STRING_LIST, STRING_LIST_QUERY, '{"bar":123}', False),
        (
            'Variable "$bar" got invalid value 123 at "bar.[0]"; String cannot'
            " represent a non string value: 123"
        ),
    )


def test_required_string_list_field_argument_provided_with_non_list_int_value() raises:
    """Required string list field argument provided with non list Int value."""
    assert_equal(
        run_normalized(STRING_LIST, STRING_LIST_QUERY, '{"bar":123}', True),
        (
            'Variable "$bar" got invalid value at "bar.[0]"; String cannot'
            " represent a non string value"
        ),
    )


def test_required_enum_list_argument_provided_with_non_list_int_value_with_variable_content() raises:
    """Required enum list argument provided with non list Int value - with
    variable content."""
    assert_equal(
        run_normalized(ENUM_LIST, ENUM_LIST_QUERY, '{"bar":123}', False),
        (
            'Variable "$bar" got invalid value 123 at "bar.[0]"; Enum "Foo"'
            " cannot represent non-string value: 123."
        ),
    )


def test_required_enum_list_argument_provided_with_non_list_int_value() raises:
    """Required enum list argument provided with non list Int value."""
    assert_equal(
        run_normalized(ENUM_LIST, ENUM_LIST_QUERY, '{"bar":123}', True),
        (
            'Variable "$bar" got invalid value at "bar.[0]"; Enum "Foo" cannot'
            " represent non-string value."
        ),
    )


def test_required_string_list_field_argument_provided_with_int_with_variable_content() raises:
    """Required string list field argument provided with Int - with variable
    content."""
    assert_equal(
        run_normalized(STRING_LIST, STRING_LIST_QUERY, '{"bar":123}', False),
        (
            'Variable "$bar" got invalid value 123 at "bar.[0]"; String cannot'
            " represent a non string value: 123"
        ),
    )


def test_required_string_list_field_argument_provided_with_int() raises:
    """Required string list field argument provided with Int."""
    assert_equal(
        run_normalized(STRING_LIST, STRING_LIST_QUERY, '{"bar":123}', True),
        (
            'Variable "$bar" got invalid value at "bar.[0]"; String cannot'
            " represent a non string value"
        ),
    )


def main() raises:
    """Run the suite."""
    TestSuite.discover_tests[__functions_in_module()]().run()
