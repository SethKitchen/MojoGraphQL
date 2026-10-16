# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for UniqueDirectivesPerLocationRule, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueDirectivesPerLocationRule-test.ts`.

Upstream builds `schemaWithDirectives` with `extendSchema(testSchema,
parse(extensionSDL))`. The port builds the same schema from the text of
`testSchema` and `extensionSDL` together.

Not ported here: the cases from `duplicate directives on SDL definitions`
to the end. They use `expectSDLErrors` or `validateSDL` and are ported in
`tests/gql_schema/test_sdl_unique_directives_per_location.mojo`.
"""

from _harness import (
    TEST_SCHEMA,
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_schema.definition import Schema
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.UNIQUE_DIRECTIVES_PER_LOCATION
"""The rule under test."""

comptime EXTENSION_SDL = """
  directive @directive on FIELD | FRAGMENT_DEFINITION
  directive @directiveA on FIELD | FRAGMENT_DEFINITION
  directive @directiveB on FIELD | FRAGMENT_DEFINITION
  directive @repeatable repeatable on FIELD | FRAGMENT_DEFINITION
"""
"""The SDL of graphql-js `extensionSDL`."""


def schema_with_directives() raises -> Schema:
    """Build graphql-js `schemaWithDirectives`.

    Returns:
        The schema.

    Raises:
        Error: Never; the SDL is valid.
    """
    return schema_of(String(TEST_SCHEMA) + EXTENSION_SDL)


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


comptime MESSAGE_DIRECTIVE = (
    'The directive "@directive" can only be used once at this location.'
)
"""The error message for `@directive`."""


def test_no_directives() raises:
    expect_valid(
        """
      fragment Test on Type {
        field
      }
    """
    )


def test_unique_directives_in_different_locations() raises:
    expect_valid(
        """
      fragment Test on Type @directiveA {
        field @directiveB
      }
    """
    )


def test_unique_directives_in_same_locations() raises:
    expect_valid(
        """
      fragment Test on Type @directiveA @directiveB {
        field @directiveA @directiveB
      }
    """
    )


def test_same_directives_in_different_locations() raises:
    expect_valid(
        """
      fragment Test on Type @directiveA {
        field @directiveA
      }
    """
    )


def test_same_directives_in_similar_locations() raises:
    expect_valid(
        """
      fragment Test on Type {
        field @directive
        field @directive
      }
    """
    )


def test_repeatable_directives_in_same_location() raises:
    expect_valid(
        """
      fragment Test on Type @repeatable @repeatable {
        field @repeatable @repeatable
      }
    """
    )


def test_unknown_directives_must_be_ignored() raises:
    expect_valid(
        """
      type Test @unknown @unknown {
        field: String! @unknown @unknown
      }

      extend type Test @unknown {
        anotherField: String!
      }
    """
    )


def test_duplicate_directives_in_one_location() raises:
    expect_errors(
        """
      fragment Test on Type {
        field @directive @directive
      }
    """,
        [String(MESSAGE_DIRECTIVE) + " (3:15, 3:26)"],
    )


def test_many_duplicate_directives_in_one_location() raises:
    expect_errors(
        """
      fragment Test on Type {
        field @directive @directive @directive
      }
    """,
        [
            String(MESSAGE_DIRECTIVE) + " (3:15, 3:26)",
            String(MESSAGE_DIRECTIVE) + " (3:15, 3:37)",
        ],
    )


def test_different_duplicate_directives_in_one_location() raises:
    expect_errors(
        """
      fragment Test on Type {
        field @directiveA @directiveB @directiveA @directiveB
      }
    """,
        [
            (
                'The directive "@directiveA" can only be used once at this'
                " location. (3:15, 3:39)"
            ),
            (
                'The directive "@directiveB" can only be used once at this'
                " location. (3:27, 3:51)"
            ),
        ],
    )


def test_duplicate_directives_in_many_locations() raises:
    expect_errors(
        """
      fragment Test on Type @directive @directive {
        field @directive @directive
      }
    """,
        [
            String(MESSAGE_DIRECTIVE) + " (2:29, 2:40)",
            String(MESSAGE_DIRECTIVE) + " (3:15, 3:26)",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
