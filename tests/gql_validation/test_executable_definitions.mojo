# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for ExecutableDefinitionsRule, ported from graphql-js 16.14.2
`src/validation/__tests__/ExecutableDefinitionsRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_with_only_operation() raises:
    expect_valid(
        ValidationRule.EXECUTABLE_DEFINITIONS,
        """
      query Foo {
        dog {
          name
        }
      }
    """,
    )


def test_with_operation_and_fragment() raises:
    expect_valid(
        ValidationRule.EXECUTABLE_DEFINITIONS,
        """
      query Foo {
        dog {
          name
          ...Frag
        }
      }

      fragment Frag on Dog {
        name
      }
    """,
    )


def test_with_type_definition() raises:
    expect_errors(
        ValidationRule.EXECUTABLE_DEFINITIONS,
        """
      query Foo {
        dog {
          name
        }
      }

      type Cow {
        name: String
      }

      extend type Dog {
        color: String
      }
    """,
        [
            'The "Cow" definition is not executable. (8:7)',
            'The "Dog" definition is not executable. (12:7)',
        ],
    )


def test_with_schema_definition() raises:
    expect_errors(
        ValidationRule.EXECUTABLE_DEFINITIONS,
        """
      schema {
        query: Query
      }

      type Query {
        test: String
      }

      extend schema @directive
    """,
        [
            "The schema definition is not executable. (2:7)",
            'The "Query" definition is not executable. (6:7)',
            "The schema definition is not executable. (10:7)",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
