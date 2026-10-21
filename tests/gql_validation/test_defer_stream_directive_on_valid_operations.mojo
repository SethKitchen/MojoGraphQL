# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for DeferStreamDirectiveOnValidOperationsRule, ported from
graphql-js v17.0.2 (commit 71606d73)
`src/validation/__tests__/DeferStreamDirectiveOnValidOperationsRule-test.ts`.

Every upstream case is here. The schema also defines `@defer` and `@stream`.
The expected errors are the output of graphql-js v17.0.2 itself. The
last three tests are beyond upstream: they cover an `if` variable, a
directive that is not `@defer` or `@stream`, a fragment before the
subscription that uses it, and a fragment that is not defined.
"""

from _harness import (
    DEFER_STREAM_SDL,
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime TEST_SDL = """
  type Message {
    body: String
    sender: String
  }

  type SubscriptionRoot {
    subscriptionField: Message
    subscriptionListField: [Message]
  }

  type MutationRoot {
    mutationField: Message
    mutationListField: [Message]
  }

  type QueryRoot {
    message: Message
    messages: [Message]
  }

  schema {
    query: QueryRoot
    mutation: MutationRoot
    subscription: SubscriptionRoot
  }
"""
"""The SDL of the upstream `schema` of this file."""

comptime DEFER = (
    "Defer directive not supported on subscription operations. Disable"
    " `@defer` by setting the `if` argument to `false`."
)
"""The upstream message for `@defer` in a subscription."""

comptime STREAM = (
    "Stream directive not supported on subscription operations. Disable"
    " `@stream` by setting the `if` argument to `false`."
)
"""The upstream message for `@stream` in a subscription."""


def _expect_errors(query: String, expected: List[String]) raises:
    """Check the errors of the rule against the schema of this file.

    Args:
        query: The document.
        expected: The formatted errors, in order.

    Raises:
        Error: When the errors differ.
    """
    expect_errors_with_schema(
        schema_of(String(TEST_SDL) + DEFER_STREAM_SDL),
        ValidationRule.DEFER_STREAM_DIRECTIVE_ON_VALID_OPERATIONS,
        query,
        expected,
    )


def _expect_valid(query: String) raises:
    """Check that the rule finds no error against the schema of this file.

    Args:
        query: The document.

    Raises:
        Error: When there is an error.
    """
    expect_valid_with_schema(
        schema_of(String(TEST_SDL) + DEFER_STREAM_SDL),
        ValidationRule.DEFER_STREAM_DIRECTIVE_ON_VALID_OPERATIONS,
        query,
    )


def test_defer_fragment_spread_nested_in_query_operation() raises:
    _expect_valid(
        """
      {
        message {
          ...myFragment @defer
        }
      }
      fragment myFragment on Message {
        message {
          body
        }
      }
    """
    )


def test_defer_inline_fragment_spread_in_query_operation() raises:
    _expect_valid(
        """
      {
        ... @defer {
          message {
            body
          }
        }
      }
    """
    )


def test_defer_fragment_spread_on_mutation_field() raises:
    _expect_valid(
        """
      mutation {
        mutationField {
          ...myFragment @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_inline_fragment_spread_on_mutation_field() raises:
    _expect_valid(
        """
      mutation {
        mutationField {
          ... @defer {
            body
          }
        }
      }
    """
    )


def test_defer_fragment_spread_on_subscription_field() raises:
    _expect_errors(
        """
      subscription {
        subscriptionField {
          ...myFragment @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (4:25)",
        ],
    )


def test_defer_fragment_spread_with_boolean_true_if_argument() raises:
    _expect_errors(
        """
      subscription {
        subscriptionField {
          ...myFragment @defer(if: true)
        }
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (4:25)",
        ],
    )


def test_defer_fragment_spread_with_boolean_false_if_argument() raises:
    _expect_valid(
        """
      subscription {
        subscriptionField {
          ...myFragment @defer(if: false)
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_fragment_spread_on_query_in_multi_operation_document() raises:
    _expect_valid(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment
        }
      }
      query MyQuery {
        message {
          ...myFragment @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_fragment_spread_on_subscription_in_multi_operation_document() raises:
    _expect_errors(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment @defer
        }
      }
      query MyQuery {
        message {
          ...myFragment @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (4:25)",
        ],
    )


def test_defer_fragment_spread_with_invalid_if_argument() raises:
    _expect_errors(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment @defer(if: "Oops")
        }
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (4:25)",
        ],
    )


def test_defer_fragment_spread_with_skip_directive() raises:
    _expect_valid(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment @skip @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_fragment_spread_with_skip_if_true_directive() raises:
    _expect_valid(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment @skip(if: true) @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_fragment_spread_with_skip_if_false_directive() raises:
    _expect_errors(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment @skip(if: false) @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (4:42)",
        ],
    )


def test_defer_in_fragment_spread_nested_under_skip_if_true_directive() raises:
    _expect_valid(
        """
      subscription MySubscription {
        subscriptionField {
          ...outerFragment @skip(if: true)
        }
      }
      fragment outerFragment on Message {
        ...myFragment @defer
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_in_fragment_spread_nested_under_skip_if_false_directive() raises:
    _expect_errors(
        """
      subscription MySubscription {
        subscriptionField {
          ...outerFragment @skip(if: false)
        }
      }
      fragment outerFragment on Message {
        ...myFragment @defer
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (8:23, 4:11)",
        ],
    )


def test_defer_in_fragment_spread_nested_under_skip_if_variable_directive() raises:
    _expect_valid(
        """
      subscription MySubscription($variable: Boolean) {
        subscriptionField {
          ...outerFragment @skip(if: $variable)
        }
      }
      fragment outerFragment on Message {
        ...myFragment @defer
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_fragment_spread_with_skip_if_variable_directive() raises:
    _expect_valid(
        """
      subscription MySubscription($variable: Boolean) {
        subscriptionField {
          ...myFragment @skip(if: $variable) @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_fragment_spread_with_include_directive() raises:
    _expect_errors(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment @include @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (4:34)",
        ],
    )


def test_defer_fragment_spread_with_include_if_true_directive() raises:
    _expect_errors(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment @include(if: true) @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (4:44)",
        ],
    )


def test_defer_fragment_spread_with_include_if_false_directive() raises:
    _expect_valid(
        """
      subscription MySubscription {
        subscriptionField {
          ...myFragment @include(if: false) @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_in_fragment_spread_nested_under_include_if_true_directive() raises:
    _expect_errors(
        """
      subscription MySubscription {
        subscriptionField {
          ...outerFragment @include(if: true)
        }
      }
      fragment outerFragment on Message {
        ...myFragment @defer
      }
      fragment myFragment on Message {
        body
      }
    """,
        [
            String(DEFER) + " (8:23, 4:11)",
        ],
    )


def test_defer_in_fragment_spread_nested_under_include_if_false_directive() raises:
    _expect_valid(
        """
      subscription MySubscription {
        subscriptionField {
          ...outerFragment @include(if: false)
        }
      }
      fragment outerFragment on Message {
        ...myFragment @defer
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_in_fragment_spread_nested_under_include_if_variable_directive() raises:
    _expect_valid(
        """
      subscription MySubscription($variable: Boolean) {
        subscriptionField {
          ...outerFragment @include(if: $variable)
        }
      }
      fragment outerFragment on Message {
        ...myFragment @defer
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_defer_fragment_spread_with_include_if_variable_directive() raises:
    _expect_valid(
        """
      subscription MySubscription ($variable: Boolean) {
        subscriptionField {
          ...myFragment @include(if: $variable) @defer
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_stream_on_query_field() raises:
    _expect_valid(
        """
      {
        messages @stream {
          name
        }
      }
    """
    )


def test_stream_on_mutation_field() raises:
    _expect_valid(
        """
      mutation {
        mutationField {
          messages @stream
        }
      }
    """
    )


def test_stream_on_fragment_on_mutation_field() raises:
    _expect_valid(
        """
      mutation {
        mutationField {
          ...myFragment
        }
      }
      fragment myFragment on Message {
        messages @stream
      }
    """
    )


def test_stream_on_subscription_field() raises:
    _expect_errors(
        """
      subscription {
        subscriptionField {
          messages @stream
        }
      }
    """,
        [
            String(STREAM) + " (4:20)",
        ],
    )


def test_stream_on_fragment_on_subscription_field() raises:
    _expect_errors(
        """
      subscription {
        subscriptionField {
          ...myFragment
        }
      }
      fragment myFragment on Message {
        messages @stream
      }
    """,
        [
            String(STREAM) + " (8:18, 4:11)",
        ],
    )


def test_stream_on_fragment_on_query_in_multi_operation_document() raises:
    _expect_valid(
        """
      subscription MySubscription {
        subscriptionField {
          message
        }
      }
      query MyQuery {
        message {
          ...myFragment
        }
      }
      fragment myFragment on Message {
        messages @stream
      }
    """
    )


def test_stream_on_subscription_in_multi_operation_document() raises:
    _expect_errors(
        """
      query MyQuery {
        message {
          ...myFragment
        }
      }
      subscription MySubscription {
        subscriptionField {
          message {
            ...myFragment
          }
        }
      }
      fragment myFragment on Message {
        messages @stream
      }
    """,
        [
            String(STREAM) + " (15:18, 10:13)",
        ],
    )


def test_stream_on_subscription_in_document_with_fragment_used_multiple_times() raises:
    _expect_errors(
        """
      subscription MySubscription {
        subscriptionField {
          message {
            ...myOtherFragment
            ...myFragment  # not visited twice
          }
        }
      }
      fragment myOtherFragment on Message {
        ...myFragment
      }
      fragment myFragment on Message {
        messages @stream
      }
    """,
        [
            String(STREAM) + " (14:18, 11:9, 5:13)",
        ],
    )


def test_variable_if_argument_and_other_directives() raises:
    # Beyond upstream: an `if` variable can be `false`, and the rule checks
    # only `@defer` and `@stream`.
    _expect_valid(
        """
      subscription ($enabled: Boolean!) {
        subscriptionField @include(if: true) {
          ...myFragment @defer(if: $enabled)
          sender @stream(if: $enabled)
        }
      }
      fragment myFragment on Message {
        body
      }
    """
    )


def test_fragment_before_its_subscription() raises:
    # Beyond upstream: the rule walks from the subscription, so a fragment
    # before the subscription is checked too.
    _expect_errors(
        """
      fragment myFragment on Message {
        sender @stream
      }
      subscription {
        subscriptionField {
          ...myFragment
        }
      }
    """,
        [String(STREAM) + " (3:16, 7:11)"],
    )


def test_unknown_fragment_in_subscription() raises:
    # Beyond upstream: a spread of an unknown fragment has nothing to walk.
    _expect_valid(
        """
      subscription {
        subscriptionField {
          ...unknownFragment
        }
      }
    """
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
