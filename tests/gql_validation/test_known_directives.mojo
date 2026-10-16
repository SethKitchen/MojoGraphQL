# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for KnownDirectivesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/KnownDirectivesRule-test.ts`.

Not ported here: the `within SDL` cases. They use `expectSDLErrors` and are
ported in `tests/gql_schema/test_sdl_known_directives.mojo`.
"""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_schema.definition import Schema
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.KNOWN_DIRECTIVES
"""The rule under test."""

comptime SCHEMA_WITH_DIRECTIVES = """
  type Query {
    dummy: String
  }

  directive @onQuery on QUERY
  directive @onMutation on MUTATION
  directive @onSubscription on SUBSCRIPTION
  directive @onField on FIELD
  directive @onFragmentDefinition on FRAGMENT_DEFINITION
  directive @onFragmentSpread on FRAGMENT_SPREAD
  directive @onInlineFragment on INLINE_FRAGMENT
  directive @onVariableDefinition on VARIABLE_DEFINITION
"""
"""The SDL of graphql-js `schemaWithDirectives`."""


def schema_with_directives() raises -> Schema:
    """Build graphql-js `schemaWithDirectives`.

    Returns:
        The schema.

    Raises:
        Error: Never; the SDL is valid.
    """
    return schema_of(SCHEMA_WITH_DIRECTIVES)


def expect_errors(query: String, expected: List[String]) raises:
    """Check the errors of the rule over a document.

    Args:
        query: The document.
        expected: The formatted errors, in order.

    Raises:
        Error: When the errors differ.
    """
    expect_errors_with_schema(schema_with_directives(), RULE, query, expected)


def expect_valid(query: String) raises:
    """Check that the rule finds no error in a document.

    Args:
        query: The document.

    Raises:
        Error: When there is an error.
    """
    expect_valid_with_schema(schema_with_directives(), RULE, query)


def test_with_no_directives() raises:
    expect_valid(
        """
      query Foo {
        name
        ...Frag
      }

      fragment Frag on Dog {
        name
      }
    """
    )


def test_with_standard_directives() raises:
    expect_valid(
        """
      {
        human @skip(if: false) {
          name
          pets {
            ... on Dog @include(if: true) {
              name
            }
          }
        }
      }
    """
    )


def test_with_unknown_directive() raises:
    expect_errors(
        """
      {
        human @unknown(directive: "value") {
          name
        }
      }
    """,
        ['Unknown directive "@unknown". (3:15)'],
    )


def test_with_many_unknown_directives() raises:
    expect_errors(
        """
      {
        __typename @unknown
        human @unknown {
          name
          pets @unknown {
            name
          }
        }
      }
    """,
        [
            'Unknown directive "@unknown". (3:20)',
            'Unknown directive "@unknown". (4:15)',
            'Unknown directive "@unknown". (6:16)',
        ],
    )


def test_with_well_placed_directives() raises:
    expect_valid(
        """
      query ($var: Boolean @onVariableDefinition) @onQuery {
        human @onField {
          ...Frag @onFragmentSpread
          ... @onInlineFragment {
            name @onField
          }
        }
      }

      mutation @onMutation {
        someField @onField
      }

      subscription @onSubscription {
        someField @onField
      }

      fragment Frag on Human @onFragmentDefinition {
        name @onField
      }
    """
    )


def test_with_misplaced_directives() raises:
    expect_errors(
        """
      query ($var: Boolean @onQuery) @onMutation {
        human @onQuery {
          ...Frag @onQuery
          ... @onQuery {
            name @onQuery
          }
        }
      }

      mutation @onQuery {
        someField @onQuery
      }

      subscription @onQuery {
        someField @onQuery
      }

      fragment Frag on Human @onQuery {
        name @onQuery
      }
    """,
        [
            (
                'Directive "@onQuery" may not be used on VARIABLE_DEFINITION.'
                " (2:28)"
            ),
            'Directive "@onMutation" may not be used on QUERY. (2:38)',
            'Directive "@onQuery" may not be used on FIELD. (3:15)',
            'Directive "@onQuery" may not be used on FRAGMENT_SPREAD. (4:19)',
            'Directive "@onQuery" may not be used on INLINE_FRAGMENT. (5:15)',
            'Directive "@onQuery" may not be used on FIELD. (6:18)',
            'Directive "@onQuery" may not be used on MUTATION. (11:16)',
            'Directive "@onQuery" may not be used on FIELD. (12:19)',
            'Directive "@onQuery" may not be used on SUBSCRIPTION. (15:20)',
            'Directive "@onQuery" may not be used on FIELD. (16:19)',
            (
                'Directive "@onQuery" may not be used on FRAGMENT_DEFINITION.'
                " (19:30)"
            ),
            'Directive "@onQuery" may not be used on FIELD. (20:14)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
