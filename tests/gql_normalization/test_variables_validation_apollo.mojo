# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.variables_validation`, ported from
graphql-go-tools v2 `pkg/variablesvalidation/variablesvalidation_test.go`
`TestVariablesValidationApolloCompatibility`.
"""

from _vv_helpers import run_with_options
from gql_normalization.variables_validation import (
    BAD_USER_INPUT,
    VALIDATION_INVALID_TYPE_VARIABLE,
    InvalidVariableError,
    VariablesValidatorOptions,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def router_options() -> VariablesValidatorOptions:
    """Return the options with the Apollo Router error replacement."""
    var options = VariablesValidatorOptions()
    options.apollo_router_compatibility_flags.replace_invalid_var_error = True
    return options


def expect_router_error(
    schema: String, operation: String, variables: String, name: String
) raises:
    """Assert the short Apollo Router error for a variable."""
    var err = run_with_options(schema, operation, variables, router_options())
    assert_true(Bool(err))
    assert_true(
        err.value()
        == InvalidVariableError(
            String(VALIDATION_INVALID_TYPE_VARIABLE),
            "invalid type for variable: '" + name + "'",
        )
    )


def test_extension_code_is_propagated_with_apollo_compatibility_flag() raises:
    """Extension code is propagated with apollo compatibility flag."""
    var options = VariablesValidatorOptions()
    options.apollo_compatibility_flags.replace_invalid_var_error = True
    var err = run_with_options(
        "type Query { hello(filter: String!): String }",
        "query Foo($input: String!) { hello(filter: $input) }",
        '{"input":null}',
        options,
    )
    assert_true(Bool(err))
    assert_equal(err.value().extension_code, String(BAD_USER_INPUT))
    assert_equal(
        err.value().message,
        (
            'Variable "$input" got invalid value null; Expected non-nullable'
            ' type "String!" not to be null.'
        ),
    )
    assert_equal(String(err.value()), err.value().message)


def test_apollo_router_compatibility_overrides_apollo_gateway_compatibility() raises:
    """Apollo router compatibility overrides apollo gateway compatibility."""
    var options = router_options()
    options.apollo_compatibility_flags.replace_invalid_var_error = True
    var err = run_with_options(
        "type Query { hello(filter: String!): String }",
        "query Foo($input: String!) { hello(filter: $input) }",
        '{"input":null}',
        options,
    )
    assert_true(
        err.value()
        == InvalidVariableError(
            String(VALIDATION_INVALID_TYPE_VARIABLE),
            "invalid type for variable: 'input'",
        )
    )
    assert_false(
        err.value()
        == InvalidVariableError(
            String(VALIDATION_INVALID_TYPE_VARIABLE), "other"
        )
    )
    assert_false(
        err.value()
        == InvalidVariableError(
            String(BAD_USER_INPUT), "invalid type for variable: 'input'"
        )
    )


def test_router_variable_required() raises:
    """Extension code and reduced error ... / variableRequired."""
    expect_router_error(
        "type Query { hello(arg: String!): String }",
        "query Foo($bar: String!) { hello }",
        "{}",
        "bar",
    )


def test_router_variable_required_not_provided() raises:
    """Extension code and reduced error ... / variableRequiredNotProvided."""
    expect_router_error(
        "input Foo { bar: String! } type Query { hello(arg: Foo!): String }",
        "query Foo($bar: Foo!) { hello(arg: $bar) }",
        '{"bar":{}}',
        "bar",
    )


def test_router_variable_invalid_object_type() raises:
    """Extension code and reduced error ... / variableInvalidObjectType."""
    expect_router_error(
        "input Foo { bar: String! } type Query { hello(arg: Foo!): String }",
        "query Foo($bar: Foo!) { hello(arg: $bar) }",
        '{"bar":true}',
        "bar",
    )


def test_router_variable_invalid_nested_type() raises:
    """Extension code and reduced error ... / variableInvalidNestedType."""
    expect_router_error(
        "input Foo { bar: String! } type Query { hello(arg: Foo!): String }",
        "query Foo($input: Foo!) { hello(arg: $input) }",
        '{"input":{"bar":123}}',
        "input",
    )


def test_router_variable_field_not_defined() raises:
    """Extension code and reduced error ... / variableFieldNotDefined."""
    expect_router_error(
        (
            "input Foo { bar: String! } input Bar { foo: Foo! } type Query {"
            " hello(arg: Bar!): String }"
        ),
        "query Foo($input: Bar!) { hello(arg: $input) }",
        '{"input":{"foo":{"bar":"hello","baz":"world"}}}',
        "input",
    )


def test_router_variable_enum_value_does_not_exist() raises:
    """Extension code and reduced error ... / variableEnumValueDoesNotExist."""
    expect_router_error(
        "enum Foo { BAR } type Query { hello(arg: Foo!): String }",
        "query Foo($bar: Foo!) { hello(arg: $bar) }",
        '{"bar":"BAZ"}',
        "bar",
    )


def test_router_variable_invalid_null() raises:
    """Extension code and reduced error ... / variableInvalidNull."""
    expect_router_error(
        "enum Foo { BAR } type Query { hello(arg: Foo!): String }",
        "query Foo($bar: Foo!) { hello(arg: $bar) }",
        '{"bar":null}',
        "bar",
    )


def test_apollo_router_compatibility_ignore_null_variables() raises:
    """Apollo router compatibility ignore null variables."""
    var options = VariablesValidatorOptions()
    options.apollo_router_compatibility_flags.skip_null_variables_error = True
    var err = run_with_options(
        "type Query { hello(filter: String!): String }",
        "query Foo($input: String!) { hello(filter: $input) }",
        '{"input":null}',
        options,
    )
    assert_false(Bool(err))


def main() raises:
    """Run the suite."""
    TestSuite.discover_tests[__functions_in_module()]().run()
