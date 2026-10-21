# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for StreamDirectiveOnListFieldRule, ported from graphql-js
v17.0.2 (commit 71606d73)
`src/validation/__tests__/StreamDirectiveOnListFieldRule-test.ts`.

Every upstream case is here. The last two tests are beyond upstream: they
cover `@stream` on a meta field, on an unknown field, and below a field
with no composite type.
"""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    incremental_test_schema,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def _expect_errors(query: String, expected: List[String]) raises:
    """Check the errors of the rule against the upstream test schema.

    Args:
        query: The document.
        expected: The formatted errors, in order.

    Raises:
        Error: When the errors differ.
    """
    expect_errors_with_schema(
        incremental_test_schema(),
        ValidationRule.STREAM_DIRECTIVE_ON_LIST_FIELD,
        query,
        expected,
    )


def _expect_valid(query: String) raises:
    """Check that the rule finds no error against the upstream test schema.

    Args:
        query: The document.

    Raises:
        Error: When there is an error.
    """
    expect_valid_with_schema(
        incremental_test_schema(),
        ValidationRule.STREAM_DIRECTIVE_ON_LIST_FIELD,
        query,
    )


def test_stream_on_list_field() raises:
    _expect_valid(
        """
      fragment objectFieldSelection on Human {
        pets @stream(initialCount: 0) {
          name
        }
      }
    """
    )


def test_stream_on_non_null_list_field() raises:
    _expect_valid(
        """
      fragment objectFieldSelection on Human {
        relatives @stream(initialCount: 0) {
          name
        }
      }
    """
    )


def test_does_not_validate_other_directives_on_list_fields() raises:
    _expect_valid(
        """
    fragment objectFieldSelection on Human {
      pets @include(if: true) {
        name
      }
    }
    """
    )


def test_does_not_validate_other_directives_on_non_list_fields() raises:
    _expect_valid(
        """
      fragment objectFieldSelection on Human {
        pets {
          name @include(if: true)
        }
      }
    """
    )


def test_does_not_validate_misplaced_stream_directives() raises:
    _expect_valid(
        """
      fragment objectFieldSelection on Human {
        ... @stream(initialCount: 0) {
          name
        }
      }
    """
    )


def test_reports_errors_when_stream_is_used_on_non_list_field() raises:
    _expect_errors(
        """
      fragment objectFieldSelection on Human {
        name @stream(initialCount: 0)
      }
    """,
        [
            'Directive "@stream" cannot be used on non-list field'
            ' "Human.name". (3:14)'
        ],
    )


def test_stream_on_meta_field() raises:
    # Beyond upstream: `__typename` is a `String!`, not a list.
    _expect_errors(
        """
      fragment objectFieldSelection on Human {
        __typename @stream
      }
    """,
        [
            'Directive "@stream" cannot be used on non-list field'
            ' "Human.__typename". (3:20)'
        ],
    )


def test_stream_with_no_field_or_no_parent_type() raises:
    # Beyond upstream: an unknown field has no field definition, and the
    # selection set of a `String` field has no parent type.
    _expect_valid(
        """
      fragment objectFieldSelection on Human {
        unknownField @stream
        name {
          ... @stream {
            name
          }
        }
      }
    """
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
