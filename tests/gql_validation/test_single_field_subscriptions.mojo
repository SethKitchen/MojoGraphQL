# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for SingleFieldSubscriptionsRule, ported from graphql-js 16.14.2
`src/validation/__tests__/SingleFieldSubscriptionsRule-test.ts`."""

from _harness import (
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
    importantEmails: [String]
    notImportantEmails: [String]
    moreImportantEmails: [String]
    spamEmails: [String]
    deletedEmails: [String]
    newMessage: Message
  }

  type QueryRoot {
    dummy: String
  }

  schema {
    query: QueryRoot
    subscription: SubscriptionRoot
  }
"""
"""The SDL of the upstream `schema` of this file."""

comptime ONLY_ONE = (
    'Subscription "ImportantEmails" must select only one top level field.'
)
"""The upstream message for a named subscription with many fields."""

comptime NO_INTROSPECTION = (
    'Subscription "ImportantEmails" must not select an introspection top'
    " level field."
)
"""The upstream message for a named subscription with an introspection
field."""


def _expect_errors(query: String, expected: List[String]) raises:
    """Check the errors of the rule against the schema of this file.

    Args:
        query: The document.
        expected: The formatted errors, in order.

    Raises:
        Error: When the errors differ.
    """
    var schema = schema_of(TEST_SDL)
    expect_errors_with_schema(
        schema, ValidationRule.SINGLE_FIELD_SUBSCRIPTIONS, query, expected
    )


def _expect_valid(query: String) raises:
    """Check that the rule finds no error against the schema of this file.

    Args:
        query: The document.

    Raises:
        Error: When there is an error.
    """
    var schema = schema_of(TEST_SDL)
    expect_valid_with_schema(
        schema, ValidationRule.SINGLE_FIELD_SUBSCRIPTIONS, query
    )


def test_valid_subscription() raises:
    _expect_valid(
        """
      subscription ImportantEmails {
        importantEmails
      }
    """
    )


def test_valid_subscription_with_fragment() raises:
    # From https://spec.graphql.org/draft/#example-13061
    _expect_valid(
        """
      subscription sub {
        ...newMessageFields
      }

      fragment newMessageFields on SubscriptionRoot {
        newMessage {
          body
          sender
        }
      }
    """
    )


def test_valid_subscription_with_fragment_and_field() raises:
    # From https://spec.graphql.org/draft/#example-13061
    _expect_valid(
        """
      subscription sub {
        newMessage {
          body
        }
        ...newMessageFields
      }

      fragment newMessageFields on SubscriptionRoot {
        newMessage {
          body
          sender
        }
      }
    """
    )


def test_fails_with_more_than_one_root_field() raises:
    _expect_errors(
        """
      subscription ImportantEmails {
        importantEmails
        notImportantEmails
      }
    """,
        [ONLY_ONE + " (4:9)"],
    )


def test_fails_with_more_than_one_root_field_including_introspection() raises:
    _expect_errors(
        """
      subscription ImportantEmails {
        importantEmails
        __typename
      }
    """,
        [ONLY_ONE + " (4:9)", NO_INTROSPECTION + " (4:9)"],
    )


def test_fails_with_more_than_one_root_field_including_aliased_introspection_via_fragment() raises:
    _expect_errors(
        """
      subscription ImportantEmails {
        importantEmails
        ...Introspection
      }
      fragment Introspection on SubscriptionRoot {
        typename: __typename
      }
    """,
        [ONLY_ONE + " (7:9)", NO_INTROSPECTION + " (7:9)"],
    )


def test_fails_with_many_more_than_one_root_field() raises:
    _expect_errors(
        """
      subscription ImportantEmails {
        importantEmails
        notImportantEmails
        spamEmails
      }
    """,
        [ONLY_ONE + " (4:9, 5:9)"],
    )


def test_fails_with_many_more_than_one_root_field_via_fragments() raises:
    _expect_errors(
        """
      subscription ImportantEmails {
        importantEmails
        ... {
          more: moreImportantEmails
        }
        ...NotImportantEmails
      }
      fragment NotImportantEmails on SubscriptionRoot {
        notImportantEmails
        deleted: deletedEmails
        ...SpamEmails
      }
      fragment SpamEmails on SubscriptionRoot {
        spamEmails
      }
    """,
        [ONLY_ONE + " (5:11, 10:9, 11:9, 15:9)"],
    )


def test_does_not_infinite_loop_on_recursive_fragments() raises:
    _expect_errors(
        """
      subscription NoInfiniteLoop {
        ...A
      }
      fragment A on SubscriptionRoot {
        ...A
      }
    """,
        [],
    )


def test_fails_with_many_more_than_one_root_field_via_fragments_anonymous() raises:
    _expect_errors(
        """
      subscription {
        importantEmails
        ... {
          more: moreImportantEmails
          ...NotImportantEmails
        }
        ...NotImportantEmails
      }
      fragment NotImportantEmails on SubscriptionRoot {
        notImportantEmails
        deleted: deletedEmails
        ... {
          ... {
            archivedEmails
          }
        }
        ...SpamEmails
      }
      fragment SpamEmails on SubscriptionRoot {
        spamEmails
        ...NonExistentFragment
      }
    """,
        [
            (
                "Anonymous Subscription must select only one top level field."
                " (5:11, 11:9, 12:9, 15:13, 21:9)"
            ),
        ],
    )


def test_fails_with_more_than_one_root_field_in_anonymous_subscriptions() raises:
    _expect_errors(
        """
      subscription {
        importantEmails
        notImportantEmails
      }
    """,
        ["Anonymous Subscription must select only one top level field. (4:9)"],
    )


def test_fails_with_introspection_field() raises:
    _expect_errors(
        """
      subscription ImportantEmails {
        __typename
      }
    """,
        [NO_INTROSPECTION + " (3:9)"],
    )


def test_fails_with_introspection_field_in_anonymous_subscription() raises:
    _expect_errors(
        """
      subscription {
        __typename
      }
    """,
        [
            (
                "Anonymous Subscription must not select an introspection top"
                " level field. (3:9)"
            ),
        ],
    )


def test_skips_if_not_subscription_type() raises:
    var empty_schema = schema_of(
        """
      type Query {
        dummy: String
      }
    """
    )
    expect_valid_with_schema(
        empty_schema,
        ValidationRule.SINGLE_FIELD_SUBSCRIPTIONS,
        """
        subscription {
          __typename
        }
      """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
