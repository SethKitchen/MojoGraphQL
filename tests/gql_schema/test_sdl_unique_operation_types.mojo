# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueOperationTypesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_schema_definition() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo
    """,
    )


def test_schema_definition_with_all_types() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo

      schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }
    """,
    )


def test_schema_definition_with_single_extension() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo

      schema { query: Foo }

      extend schema {
        mutation: Foo
        subscription: Foo
      }
    """,
    )


def test_schema_definition_with_separate_extensions() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo

      schema { query: Foo }
      extend schema { mutation: Foo }
      extend schema { subscription: Foo }
    """,
    )


def test_extend_schema_before_definition() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo

      extend schema { mutation: Foo }
      extend schema { subscription: Foo }

      schema { query: Foo }
    """,
    )


def test_duplicate_operation_types_inside_single_schema_definition() raises:
    expect_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo

      schema {
        query: Foo
        mutation: Foo
        subscription: Foo

        query: Foo
        mutation: Foo
        subscription: Foo
      }
    """,
        [
            "There can be only one query type in schema. (5:9, 9:9)",
            "There can be only one mutation type in schema. (6:9, 10:9)",
            "There can be only one subscription type in schema. (7:9, 11:9)",
        ],
    )


def test_duplicate_operation_types_inside_schema_extension() raises:
    expect_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo

      schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }

      extend schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }
    """,
        [
            "There can be only one query type in schema. (5:9, 11:9)",
            "There can be only one mutation type in schema. (6:9, 12:9)",
            "There can be only one subscription type in schema. (7:9, 13:9)",
        ],
    )


def test_duplicate_operation_types_inside_schema_extension_twice() raises:
    expect_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo

      schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }

      extend schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }

      extend schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }
    """,
        [
            "There can be only one query type in schema. (5:9, 11:9)",
            "There can be only one mutation type in schema. (6:9, 12:9)",
            "There can be only one subscription type in schema. (7:9, 13:9)",
            "There can be only one query type in schema. (5:9, 17:9)",
            "There can be only one mutation type in schema. (6:9, 18:9)",
            "There can be only one subscription type in schema. (7:9, 19:9)",
        ],
    )


def test_duplicate_operation_types_inside_second_schema_extension() raises:
    expect_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      type Foo

      schema {
        query: Foo
      }

      extend schema {
        mutation: Foo
        subscription: Foo
      }

      extend schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }
    """,
        [
            "There can be only one query type in schema. (5:9, 14:9)",
            "There can be only one mutation type in schema. (9:9, 15:9)",
            "There can be only one subscription type in schema. (10:9, 16:9)",
        ],
    )


def test_define_schema_inside_extension_sdl() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }
    """,
        schema_sdl="""type Foo""",
    )


def test_define_and_extend_schema_inside_extension_sdl() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      schema { query: Foo }
      extend schema { mutation: Foo }
      extend schema { subscription: Foo }
    """,
        schema_sdl="""type Foo""",
    )


def test_adding_new_operation_types_to_existing_schema() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      extend schema { mutation: Foo }
      extend schema { subscription: Foo }
    """,
        schema_sdl="""type Query""",
    )


def test_adding_conflicting_operation_types_to_existing_schema() raises:
    expect_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      extend schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }
    """,
        [
            (
                "Type for query already defined in the schema. It cannot be"
                " redefined. (3:9)"
            ),
            (
                "Type for mutation already defined in the schema. It cannot be"
                " redefined. (4:9)"
            ),
            (
                "Type for subscription already defined in the schema. It cannot"
                " be redefined. (5:9)"
            ),
        ],
        schema_sdl="""
      type Query
      type Mutation
      type Subscription

      type Foo
    """,
    )


def test_adding_conflicting_operation_types_to_existing_schema_twice() raises:
    expect_sdl(
        SDLRule.UNIQUE_OPERATION_TYPES,
        """
      extend schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }

      extend schema {
        query: Foo
        mutation: Foo
        subscription: Foo
      }
    """,
        [
            (
                "Type for query already defined in the schema. It cannot be"
                " redefined. (3:9)"
            ),
            (
                "Type for mutation already defined in the schema. It cannot be"
                " redefined. (4:9)"
            ),
            (
                "Type for subscription already defined in the schema. It cannot"
                " be redefined. (5:9)"
            ),
            (
                "Type for query already defined in the schema. It cannot be"
                " redefined. (9:9)"
            ),
            (
                "Type for mutation already defined in the schema. It cannot be"
                " redefined. (10:9)"
            ),
            (
                "Type for subscription already defined in the schema. It cannot"
                " be redefined. (11:9)"
            ),
        ],
        schema_sdl="""
      type Query
      type Mutation
      type Subscription
    """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
