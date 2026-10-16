# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for NoSchemaIntrospectionCustomRule, ported from graphql-js 16.14.2
`src/validation/__tests__/NoSchemaIntrospectionCustomRule-test.ts`.

Every upstream case is ported.
"""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.NO_SCHEMA_INTROSPECTION_CUSTOM
"""The rule under test."""

comptime SCHEMA_SDL = """
  type Query {
    someQuery: SomeType
  }

  type SomeType {
    someField: String
    introspectionField: __EnumValue
  }
"""
"""The schema of the upstream test file."""


def test_ignores_valid_fields_including_typename() raises:
    expect_valid_with_schema(
        schema_of(SCHEMA_SDL),
        RULE,
        """
      {
        someQuery {
          __typename
          someField
        }
      }
    """,
    )


def test_ignores_fields_not_in_the_schema() raises:
    expect_valid_with_schema(
        schema_of(SCHEMA_SDL),
        RULE,
        """
      {
        __introspect
      }
    """,
    )


def test_reports_error_when_a_field_with_an_introspection_type_is_requested() raises:
    expect_errors_with_schema(
        schema_of(SCHEMA_SDL),
        RULE,
        """
      {
        __schema {
          queryType {
            name
          }
        }
      }
    """,
        [
            (
                "GraphQL introspection has been disabled, but the requested"
                ' query contained the field "__schema". (3:9)'
            ),
            (
                "GraphQL introspection has been disabled, but the requested"
                ' query contained the field "queryType". (4:11)'
            ),
        ],
    )


def test_reports_error_when_a_field_with_an_introspection_type_is_requested_and_aliased() raises:
    expect_errors_with_schema(
        schema_of(SCHEMA_SDL),
        RULE,
        """
      {
        s: __schema {
          queryType {
            name
          }
        }
      }
      """,
        [
            (
                "GraphQL introspection has been disabled, but the requested"
                ' query contained the field "__schema". (3:9)'
            ),
            (
                "GraphQL introspection has been disabled, but the requested"
                ' query contained the field "queryType". (4:11)'
            ),
        ],
    )


def test_reports_error_when_using_a_fragment_with_a_field_with_an_introspection_type() raises:
    expect_errors_with_schema(
        schema_of(SCHEMA_SDL),
        RULE,
        """
      {
        ...QueryFragment
      }

      fragment QueryFragment on Query {
        __schema {
          queryType {
            name
          }
        }
      }
    """,
        [
            (
                "GraphQL introspection has been disabled, but the requested"
                ' query contained the field "__schema". (7:9)'
            ),
            (
                "GraphQL introspection has been disabled, but the requested"
                ' query contained the field "queryType". (8:11)'
            ),
        ],
    )


def test_reports_error_for_non_standard_introspection_fields() raises:
    expect_errors_with_schema(
        schema_of(SCHEMA_SDL),
        RULE,
        """
      {
        someQuery {
          introspectionField
        }
      }
    """,
        [
            "GraphQL introspection has been disabled, but the requested query"
            ' contained the field "introspectionField". (4:11)'
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
