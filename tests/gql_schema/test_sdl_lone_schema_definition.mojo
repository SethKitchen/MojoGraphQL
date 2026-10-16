# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/LoneSchemaDefinitionRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_schema() raises:
    expect_valid_sdl(
        SDLRule.LONE_SCHEMA_DEFINITION,
        """
      type Query {
        foo: String
      }
    """,
    )


def test_one_schema_definition() raises:
    expect_valid_sdl(
        SDLRule.LONE_SCHEMA_DEFINITION,
        """
      schema {
        query: Foo
      }

      type Foo {
        foo: String
      }
    """,
    )


def test_multiple_schema_definitions() raises:
    expect_sdl(
        SDLRule.LONE_SCHEMA_DEFINITION,
        """
      schema {
        query: Foo
      }

      type Foo {
        foo: String
      }

      schema {
        mutation: Foo
      }

      schema {
        subscription: Foo
      }
    """,
        [
            "Must provide only one schema definition. (10:7)",
            "Must provide only one schema definition. (14:7)",
        ],
    )


def test_define_schema_in_schema_extension() raises:
    expect_valid_sdl(
        SDLRule.LONE_SCHEMA_DEFINITION,
        """
        schema {
          query: Foo
        }
      """,
        schema_sdl="""
      type Foo {
        foo: String
      }
    """,
    )


def test_redefine_schema_in_schema_extension() raises:
    expect_sdl(
        SDLRule.LONE_SCHEMA_DEFINITION,
        """
        schema {
          mutation: Foo
        }
      """,
        [
            "Cannot define a new schema within a schema extension. (2:9)",
        ],
        schema_sdl="""
      schema {
        query: Foo
      }

      type Foo {
        foo: String
      }
    """,
    )


def test_redefine_implicit_schema_in_schema_extension() raises:
    expect_sdl(
        SDLRule.LONE_SCHEMA_DEFINITION,
        """
        schema {
          mutation: Foo
        }
      """,
        [
            "Cannot define a new schema within a schema extension. (2:9)",
        ],
        schema_sdl="""
      type Query {
        fooField: Foo
      }

      type Foo {
        foo: String
      }
    """,
    )


def test_extend_schema_in_schema_extension() raises:
    expect_valid_sdl(
        SDLRule.LONE_SCHEMA_DEFINITION,
        """
        extend schema {
          mutation: Foo
        }
      """,
        schema_sdl="""
      type Query {
        fooField: Foo
      }

      type Foo {
        foo: String
      }
    """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
