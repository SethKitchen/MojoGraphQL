# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueDirectivesPerLocationRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite
from _sdl_fixtures import (
    TEST_SCHEMA,
    SCHEMA_WITH_DIRECTIVES,
    SCHEMA_WITH_SDL_DIRECTIVES,
    TEST_SCHEMA_WITH_DIRECTIVES,
)


def test_no_directives() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type {
        field
      }
    """,
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_unique_directives_in_different_locations() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type @directiveA {
        field @directiveB
      }
    """,
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_unique_directives_in_same_locations() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type @directiveA @directiveB {
        field @directiveA @directiveB
      }
    """,
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_same_directives_in_different_locations() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type @directiveA {
        field @directiveA
      }
    """,
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_same_directives_in_similar_locations() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type {
        field @directive
        field @directive
      }
    """,
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_repeatable_directives_in_same_location() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type @repeatable @repeatable {
        field @repeatable @repeatable
      }
    """,
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_unknown_directives_must_be_ignored() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      type Test @unknown @unknown {
        field: String! @unknown @unknown
      }

      extend type Test @unknown {
        anotherField: String!
      }
    """,
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_duplicate_directives_in_one_location() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type {
        field @directive @directive
      }
    """,
        [
            (
                'The directive "@directive" can only be used once at this'
                " location. (3:15, 3:26)"
            ),
        ],
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_many_duplicate_directives_in_one_location() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type {
        field @directive @directive @directive
      }
    """,
        [
            (
                'The directive "@directive" can only be used once at this'
                " location. (3:15, 3:26)"
            ),
            (
                'The directive "@directive" can only be used once at this'
                " location. (3:15, 3:37)"
            ),
        ],
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_different_duplicate_directives_in_one_location() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
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
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_duplicate_directives_in_many_locations() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      fragment Test on Type @directive @directive {
        field @directive @directive
      }
    """,
        [
            (
                'The directive "@directive" can only be used once at this'
                " location. (2:29, 2:40)"
            ),
            (
                'The directive "@directive" can only be used once at this'
                " location. (3:15, 3:26)"
            ),
        ],
        schema_sdl=TEST_SCHEMA_WITH_DIRECTIVES,
    )


def test_duplicate_directives_on_sdl_definitions() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on
        SCHEMA | SCALAR | OBJECT | INTERFACE | UNION | INPUT_OBJECT

      schema @nonRepeatable @nonRepeatable { query: Dummy }

      scalar TestScalar @nonRepeatable @nonRepeatable
      type TestObject @nonRepeatable @nonRepeatable
      interface TestInterface @nonRepeatable @nonRepeatable
      union TestUnion @nonRepeatable @nonRepeatable
      input TestInput @nonRepeatable @nonRepeatable
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (5:14, 5:29)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (7:25, 7:40)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (8:23, 8:38)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (9:31, 9:46)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (10:23, 10:38)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (11:23, 11:38)"
            ),
        ],
    )


def test_duplicate_directives_on_sdl_extensions() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on
        SCHEMA | SCALAR | OBJECT | INTERFACE | UNION | INPUT_OBJECT

      extend schema @nonRepeatable @nonRepeatable

      extend scalar TestScalar @nonRepeatable @nonRepeatable
      extend type TestObject @nonRepeatable @nonRepeatable
      extend interface TestInterface @nonRepeatable @nonRepeatable
      extend union TestUnion @nonRepeatable @nonRepeatable
      extend input TestInput @nonRepeatable @nonRepeatable
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (5:21, 5:36)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (7:32, 7:47)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (8:30, 8:45)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (9:38, 9:53)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (10:30, 10:45)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (11:30, 11:45)"
            ),
        ],
    )


def test_duplicate_directives_between_sdl_definitions_and_extensions() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on SCHEMA

      schema @nonRepeatable { query: Dummy }
      extend schema @nonRepeatable
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:14, 5:21)"
            ),
        ],
    )
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on SCALAR

      scalar TestScalar @nonRepeatable
      extend scalar TestScalar @nonRepeatable
      scalar TestScalar @nonRepeatable
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:25, 5:32)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:25, 6:25)"
            ),
        ],
    )
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on OBJECT

      extend type TestObject @nonRepeatable
      type TestObject @nonRepeatable
      extend type TestObject @nonRepeatable
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:30, 5:23)"
            ),
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:30, 6:30)"
            ),
        ],
    )


def test_duplicate_directives_on_directive_definitions() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on DIRECTIVE_DEFINITION

      directive @testDirective @nonRepeatable @nonRepeatable on FIELD_DEFINITION
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:32, 4:47)"
            ),
        ],
        experimental=True,
    )


def test_duplicate_directives_on_directive_extensions() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on DIRECTIVE_DEFINITION

      extend directive @testDirective @nonRepeatable @nonRepeatable
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:39, 4:54)"
            ),
        ],
        experimental=True,
    )


def test_duplicate_directives_between_directive_definitions_and_extensions() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on DIRECTIVE_DEFINITION

      directive @testDirective @nonRepeatable on FIELD_DEFINITION
      extend directive @testDirective @nonRepeatable
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:32, 5:39)"
            ),
        ],
        experimental=True,
    )


def test_duplicate_directives_between_directive_extensions() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION,
        """
      directive @nonRepeatable on DIRECTIVE_DEFINITION

      extend directive @testDirective @nonRepeatable
      extend directive @testDirective @nonRepeatable
    """,
        [
            (
                'The directive "@nonRepeatable" can only be used once at this'
                " location. (4:39, 5:39)"
            ),
        ],
        experimental=True,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
