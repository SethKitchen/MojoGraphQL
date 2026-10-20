# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the `gql_normalization.variables_validation` tests: the
`runTest` family of graphql-go-tools v2
`pkg/variablesvalidation/variablesvalidation_test.go`."""

from std.collections import Dict, Optional

from gql_language.parser import parse
from gql_normalization.variables_validation import (
    InvalidVariableError,
    VariablesValidator,
    VariablesValidatorOptions,
)
from gql_schema.build import build_schema
from std.testing import assert_equal


comptime INPUT_SCHEMA = """
    type Query {
        satisfied(input: SelfSatisfiedInput!): Boolean
        unsatisfied(input: SelfUnsatisfiedInput!): Boolean
    }

    input NestedSelfSatisfiedInput {
        a: String
        b: Int! = 1
    }

    input SelfSatisfiedInput {
        nested: NestedSelfSatisfiedInput
        value: String
    }

    input SelfUnsatisfiedInput {
        nested: NestedSelfSatisfiedInput!
        secondNested: NestedSelfSatisfiedInput!
        value: String
    }
"""
"""The upstream `inputSchema` fixture."""


def run_with_options(
    schema: String,
    operation: String,
    variables: String,
    options: VariablesValidatorOptions,
    mapping: Optional[Dict[String, String]] = None,
) raises -> Optional[InvalidVariableError]:
    """Validate variables, as upstream `runTestWithOptions`.

    Args:
        schema: The SDL.
        operation: The operation text.
        variables: The variables JSON.
        options: The validator options.
        mapping: The variables map of `ValidateWithRemap`, or None.

    Returns:
        The error, or None.

    Raises:
        Error: When the SDL, the operation or the JSON does not parse.
    """
    var definition = build_schema(schema)
    var document = parse(operation)
    var validator = VariablesValidator(options)
    if mapping:
        return validator.validate_with_remap(
            document, definition, variables, mapping.value()
        )
    return validator.validate(document, definition, variables)


def _message(error: Optional[InvalidVariableError]) -> String:
    """Return the message of an error, or empty for None.

    Args:
        error: The error, or None.

    Returns:
        The message, as upstream `err.Error()`.
    """
    if error:
        return error.value().message.copy()
    return String()


def run_test(
    schema: String,
    operation: String,
    variables: String,
    mapping: Optional[Dict[String, String]] = None,
) raises -> String:
    """Validate with the values hidden, as upstream `runTest`.

    Args:
        schema: The SDL.
        operation: The operation text.
        variables: The variables JSON.
        mapping: The variables map, or None.

    Returns:
        The message, or empty when the variables are valid.

    Raises:
        Error: When the SDL, the operation or the JSON does not parse.
    """
    var options = VariablesValidatorOptions()
    options.disable_exposing_variables_content = True
    return _message(
        run_with_options(schema, operation, variables, options, mapping)
    )


def run_test_with_variables_content_enabled(
    schema: String,
    operation: String,
    variables: String,
    mapping: Optional[Dict[String, String]] = None,
) raises -> String:
    """Validate with the values shown, as upstream
    `runTestWithVariablesContentEnabled`.

    Args:
        schema: The SDL.
        operation: The operation text.
        variables: The variables JSON.
        mapping: The variables map, or None.

    Returns:
        The message, or empty when the variables are valid.

    Raises:
        Error: When the SDL, the operation or the JSON does not parse.
    """
    return _message(
        run_with_options(
            schema, operation, variables, VariablesValidatorOptions(), mapping
        )
    )


def expect_hidden(
    schema: String,
    operation: String,
    variables: String,
    want: String,
    mapping: Optional[Dict[String, String]] = None,
) raises:
    """Assert the `runTest` message; empty means no error.

    Args:
        schema: The SDL.
        operation: The operation text.
        variables: The variables JSON.
        want: The expected message, or empty.
        mapping: The variables map, or None.

    Raises:
        Error: When the message differs.
    """
    assert_equal(run_test(schema, operation, variables, mapping), want)


def expect_shown(
    schema: String,
    operation: String,
    variables: String,
    want: String,
    mapping: Optional[Dict[String, String]] = None,
) raises:
    """Assert the `runTestWithVariablesContentEnabled` message; empty means
    no error.

    Args:
        schema: The SDL.
        operation: The operation text.
        variables: The variables JSON.
        want: The expected message, or empty.
        mapping: The variables map, or None.

    Raises:
        Error: When the message differs.
    """
    assert_equal(
        run_test_with_variables_content_enabled(
            schema, operation, variables, mapping
        ),
        want,
    )


def remap(key: String, value: String) -> Dict[String, String]:
    """Make a variables map with one entry.

    Args:
        key: The operation variable name.
        value: The request variable name.

    Returns:
        The map.
    """
    var out = Dict[String, String]()
    out[key] = value
    return out^
