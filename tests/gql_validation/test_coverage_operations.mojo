# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests beyond upstream for the operation and variable rules: they cover
the `@skip` and `@include` evaluation and the type conditions of
SingleFieldSubscriptionsRule, the default values and OneOf parents of
VariablesInAllowedPositionRule, and an operation with no variable usage in
NoUnusedVariablesRule.

The expected errors come from graphql-js 16.14.2: each document was run
through `validate` with the same schema and rule. When graphql-js throws,
`validate` raises an `Error` with the same message.
"""

from _harness import (
    errors_with_schema,
    expect_errors,
    expect_errors_with_schema,
    expect_valid,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite, assert_equal

comptime SUBSCRIPTION_SDL = """
type Query { a: String }
interface Node { id: ID }
type Sub implements Node { id: ID a: String b: String }
type Other { a: String }
union SubUnion = Sub | Other
union OtherUnion = Other
schema { query: Query subscription: Sub }
"""
"""A schema whose subscription type implements an interface and is in a
union."""

comptime RULE = ValidationRule.SINGLE_FIELD_SUBSCRIPTIONS
"""The rule of the subscription tests."""

comptime ONLY_ONE = (
    "Anonymous Subscription must select only one top level field."
)
"""The graphql-js message for an anonymous subscription with many fields."""


def _valid(query: String) raises:
    """Check that the subscription rule finds no error.

    Args:
        query: The document.

    Raises:
        Error: When there is an error.
    """
    expect_valid_with_schema(schema_of(SUBSCRIPTION_SDL), RULE, query)


def _errors(query: String, expected: List[String]) raises:
    """Check the errors of the subscription rule.

    Args:
        query: The document.
        expected: The formatted errors.

    Raises:
        Error: When the errors differ.
    """
    expect_errors_with_schema(
        schema_of(SUBSCRIPTION_SDL), RULE, query, expected
    )


def _raises(query: String, message: String) raises:
    """Check that the subscription rule raises, as graphql-js throws.

    Args:
        query: The document.
        message: The graphql-js message.

    Raises:
        Error: When the rule does not raise this message.
    """
    var raised = String("")
    try:
        _ = errors_with_schema(schema_of(SUBSCRIPTION_SDL), RULE, query)
    except error:
        raised = String(error)
    assert_equal(raised, message)


# --- @skip and @include -----------------------------------------------------


def test_skip_true_removes_a_field() raises:
    _valid("subscription { a b @skip(if: true) }")


def test_skip_false_keeps_a_field() raises:
    _errors("subscription { a b @skip(if: false) }", [ONLY_ONE + " (1:18)"])


def test_include_false_removes_a_field() raises:
    _valid("subscription { a b @include(if: false) }")


def test_include_true_keeps_a_field() raises:
    _errors("subscription { a b @include(if: true) }", [ONLY_ONE + " (1:18)"])


def test_first_skip_wins() raises:
    _valid("subscription { a b @other @skip(if: true) @skip(if: false) }")


def test_first_include_wins() raises:
    _valid("subscription { a b @include(if: false) @include(if: true) }")


def test_skip_false_and_include_true() raises:
    _errors(
        "subscription { a b @skip(if: false) @include(if: true) }",
        [ONLY_ONE + " (1:18)"],
    )


def test_skip_false_and_include_false() raises:
    _valid("subscription { a b @skip(if: false) @include(if: false) }")


def test_last_if_argument_wins() raises:
    _valid("subscription { a b @skip(foo: 1, if: false, if: true) }")


def test_raises_for_a_missing_if() raises:
    _raises(
        "subscription { a @skip }",
        'Argument "if" of required type "Boolean!" was not provided.',
    )
    _raises(
        "subscription { a @include(foo: true) }",
        'Argument "if" of required type "Boolean!" was not provided.',
    )


def test_raises_for_a_variable_if() raises:
    _raises(
        "subscription ($v: Boolean!) { a @skip(if: $v) }",
        (
            'Argument "if" of required type "Boolean!" was provided the'
            ' variable "$v" which was not provided a runtime value.'
        ),
    )


def test_raises_for_a_null_if() raises:
    _raises(
        "subscription { a @include(if: null) }",
        'Argument "if" of non-null type "Boolean!" must not be null.',
    )


def test_raises_for_a_non_boolean_if() raises:
    _raises(
        'subscription { a @include(if: "yes") }',
        'Argument "if" has invalid value "yes".',
    )
    _raises(
        "subscription { a @skip(if: TRUE) }",
        'Argument "if" has invalid value TRUE.',
    )


# --- fragments --------------------------------------------------------------


def test_skipped_inline_fragment() raises:
    _valid("subscription { a ... @skip(if: true) { b } }")


def test_included_inline_fragment() raises:
    _errors(
        "subscription { a ... @include(if: true) { b } }",
        [ONLY_ONE + " (1:43)"],
    )


def test_inline_fragment_on_another_object_type() raises:
    _valid("subscription { a ... on Other { a } }")


def test_inline_fragments_on_abstract_types_of_the_subscription_type() raises:
    _errors(
        "subscription { a ... on SubUnion { b } ... on Node { id } }",
        [ONLY_ONE + " (1:36, 1:54)"],
    )


def test_inline_fragment_on_an_abstract_type_without_the_subscription() raises:
    _valid("subscription { a ... on OtherUnion { b } }")


def test_inline_fragment_on_an_unknown_type() raises:
    _valid("subscription { a ... on Unknown { b } }")


def test_skipped_fragment_spread() raises:
    _valid("subscription { a ...F @skip(if: true) } fragment F on Sub { b }")


def test_fragment_spread_on_another_object_type() raises:
    _valid("subscription { a ...F } fragment F on Other { a }")


def test_fragment_spread_twice() raises:
    _errors(
        "subscription Named { a ...F ...F } fragment F on Sub { b }",
        ['Subscription "Named" must select only one top level field. (1:56)'],
    )


# --- variables --------------------------------------------------------------


def test_nullable_variable_in_a_non_null_argument_with_a_default() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        (
            "query Q($a: Int) { complicatedArgs { nonNullFieldWithDefault(arg:"
            " $a) } }"
        ),
    )


def test_variable_of_an_unknown_type() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        "query Q($a: Foo) { dog { isAtLocation(x: $a) } }",
    )


def test_nullable_variable_in_an_input_object_that_is_not_one_of() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        (
            "query Q($a: Int) { complicatedArgs { complexArgField(complexArg:"
            " {requiredField: true, intField: $a}) } }"
        ),
    )


def test_variable_in_a_list_at_a_scalar_position() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        "query Q($a: Int) { complicatedArgs { intArgField(intArg: [$a]) } }",
    )
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        "query Q($a: [Int]) { complicatedArgs { intArgField(intArg: [$a]) } }",
        [
            'Variable "$a" of type "[Int]" used in position expecting type'
            ' "Int". (1:9, 1:61)'
        ],
    )


def test_nullable_variable_in_a_one_of_input_object() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        (
            "query Q($a: String) { complicatedArgs { oneOfArgField(oneOfArg:"
            " {stringField: $a}) } }"
        ),
        [
            'Variable "$a" is of type "String" but must be non-nullable to'
            ' be used for OneOf Input Object "OneOfInput". (1:9, 1:79)'
        ],
    )


def test_operation_with_no_variable_usage() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_VARIABLES,
        "query Q($a: Int) { dog { name } }",
        ['Variable "$a" is never used in operation "Q". (1:9)'],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
