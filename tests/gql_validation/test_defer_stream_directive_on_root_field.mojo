# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for DeferStreamDirectiveOnRootFieldRule, ported from graphql-js
v17.0.2 (commit 71606d73)
`src/validation/__tests__/DeferStreamDirectiveOnRootFieldRule-test.ts`.

Every upstream case is here. The schema also defines `@defer` and `@stream`.
The last tests are beyond upstream: a directive that is not `@defer` or
`@stream`, a fragment that is not defined, a schema with no root mutation
type, and a fragment cycle, for which graphql-js v17.0.2 raises
`RangeError` (see the module docstring of `rules_incremental.mojo`).
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

  interface Root {
    rootField: Message
  }

  type SubscriptionRoot implements Root {
    subscriptionField: Message
    subscriptionListField: [Message]
    rootField: Message
  }

  type MutationRoot implements Root {
    mutationField: Message
    mutationListField: [Message]
    rootField: Message
  }

  type QueryRoot implements Root {
    message: Message
    messages: [Message]
    rootField: Message
  }

  schema {
    query: QueryRoot
    mutation: MutationRoot
    subscription: SubscriptionRoot
  }
"""
"""The SDL of the upstream `schema` of this file."""

comptime DEFER_MUTATION = (
    'Defer directive cannot be used on root mutation type "MutationRoot".'
)
"""The upstream message for `@defer` on the root mutation type."""

comptime DEFER_SUBSCRIPTION = (
    "Defer directive cannot be used on root subscription type"
    ' "SubscriptionRoot".'
)
"""The upstream message for `@defer` on the root subscription type."""

comptime STREAM_MUTATION = (
    'Stream directive cannot be used on root mutation type "MutationRoot".'
)
"""The upstream message for `@stream` on the root mutation type."""

comptime STREAM_SUBSCRIPTION = (
    "Stream directive cannot be used on root subscription type"
    ' "SubscriptionRoot".'
)
"""The upstream message for `@stream` on the root subscription type."""


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
        ValidationRule.DEFER_STREAM_DIRECTIVE_ON_ROOT_FIELD,
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
        ValidationRule.DEFER_STREAM_DIRECTIVE_ON_ROOT_FIELD,
        query,
    )


def test_defer_fragment_spread_on_root_query_field() raises:
    _expect_valid(
        """
      {
        ...rootQueryFragment @defer
      }
      fragment rootQueryFragment on QueryRoot {
        message {
          body
        }
      }
    """
    )


def test_defer_inline_fragment_spread_on_root_query_field() raises:
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


def test_defer_fragment_spread_on_root_mutation_field() raises:
    _expect_errors(
        """
      mutation {
        ...rootFragment @defer
        ...otherFragment
      }
      fragment otherFragment on MutationRoot {
        ...rootFragment
        mutationListField {
          body
        }
      }
      fragment rootFragment on MutationRoot {
        mutationField {
          body
        }
      }
    """,
        [String(DEFER_MUTATION) + " (3:25)"],
    )


def test_defer_inline_fragment_spread_on_root_mutation_field() raises:
    _expect_errors(
        """
      mutation {
        ... @defer {
          mutationField {
            body
          }
        }
      }
    """,
        [String(DEFER_MUTATION) + " (3:13)"],
    )


def test_defer_fragment_spread_on_root_mutation_field_interface() raises:
    _expect_errors(
        """
      mutation {
        ...rootFragment
      }
      fragment rootFragment on Root {
        ... @defer {
          rootField {
            body
          }
        }
      }
    """,
        [String(DEFER_MUTATION) + " (6:13)"],
    )


def test_defer_fragment_spread_on_nested_mutation_field() raises:
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


def test_defer_fragment_spread_on_root_subscription_field_interface() raises:
    _expect_errors(
        """
      subscription {
        ...rootFragment
      }
      fragment rootFragment on Root {
        ... @defer {
            rootField {
              body
            }
        }
      }
    """,
        [String(DEFER_SUBSCRIPTION) + " (6:13)"],
    )


def test_defer_fragment_spread_on_root_subscription_field() raises:
    _expect_errors(
        """
      subscription {
        ...rootFragment @defer
      }
      fragment rootFragment on SubscriptionRoot {
        subscriptionField {
          body
        }
      }
    """,
        [String(DEFER_SUBSCRIPTION) + " (3:25)"],
    )


def test_defer_inline_fragment_spread_on_root_subscription_field() raises:
    _expect_errors(
        """
      subscription {
        ... @defer {
          subscriptionField {
            body
          }
        }
      }
    """,
        [String(DEFER_SUBSCRIPTION) + " (3:13)"],
    )


def test_defer_fragment_spread_on_nested_subscription_field() raises:
    _expect_valid(
        """
      subscription {
        subscriptionField {
          ...nestedFragment @defer
        }
      }
      fragment nestedFragment on Message {
        body
      }
    """
    )


def test_stream_field_on_root_query_field() raises:
    _expect_valid(
        """
      {
        messages @stream {
          name
        }
      }
    """
    )


def test_stream_field_on_fragment_on_root_query_field() raises:
    _expect_valid(
        """
      {
        ...rootFragment
      }
      fragment rootFragment on QueryType {
        messages @stream {
          name
        }
      }
    """
    )


def test_stream_field_on_root_mutation_field() raises:
    _expect_errors(
        """
      mutation {
        mutationListField @stream {
          name
        }
      }
    """,
        [String(STREAM_MUTATION) + " (3:27)"],
    )


def test_stream_field_on_fragment_on_root_mutation_field() raises:
    _expect_errors(
        """
      mutation {
        ...rootFragment
      }
      fragment rootFragment on MutationRoot {
        mutationListField @stream {
          name
        }
      }
    """,
        [String(STREAM_MUTATION) + " (6:27)"],
    )


def test_stream_field_on_root_subscription_field() raises:
    _expect_errors(
        """
      subscription {
        subscriptionListField @stream {
          name
        }
      }
    """,
        [String(STREAM_SUBSCRIPTION) + " (3:31)"],
    )


def test_stream_field_on_fragment_on_root_subscription_field() raises:
    _expect_errors(
        """
      subscription {
        ...rootFragment
      }
      fragment rootFragment on SubscriptionRoot {
        subscriptionListField @stream {
          name
        }
      }
    """,
        [String(STREAM_SUBSCRIPTION) + " (6:31)"],
    )


def test_other_directives_on_root_fields() raises:
    # Beyond upstream: the rule checks only `@defer` and `@stream`.
    _expect_valid(
        """
      mutation {
        mutationListField @include(if: true) {
          body
        }
      }
    """
    )


def test_unknown_fragment_on_root_mutation_field() raises:
    # Beyond upstream: a spread of an unknown fragment has nothing to walk.
    _expect_valid(
        """
      mutation {
        ...unknownFragment @defer
      }
    """
    )


def test_mutation_without_root_mutation_type() raises:
    # Beyond upstream: with no root mutation type, the rule finds nothing.
    expect_valid_with_schema(
        schema_of("type Query { a: [String] }" + DEFER_STREAM_SDL),
        ValidationRule.DEFER_STREAM_DIRECTIVE_ON_ROOT_FIELD,
        "mutation { a @stream ... @defer { a } }",
    )


def test_fragment_cycle_on_root_mutation_field() raises:
    # Beyond upstream: graphql-js v17.0.2 overflows its stack here. Each
    # fragment is walked once, so the cycle ends.
    _expect_errors(
        """
      mutation {
        ...rootFragment
      }
      fragment rootFragment on MutationRoot {
        ... @defer { mutationField { body } }
        ...rootFragment
      }
    """,
        [String(DEFER_MUTATION) + " (6:13)"],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
