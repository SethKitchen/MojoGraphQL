# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueTypeNamesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_types() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_TYPE_NAMES,
        """
      directive @test on SCHEMA
    """,
    )


def test_one_type() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_TYPE_NAMES,
        """
      type Foo
    """,
    )


def test_many_types() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_TYPE_NAMES,
        """
      type Foo
      type Bar
      type Baz
    """,
    )


def test_type_and_non_type_definitions_named_the_same() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_TYPE_NAMES,
        """
      query Foo { __typename }
      fragment Foo on Query { __typename }
      directive @Foo on SCHEMA

      type Foo
    """,
    )


def test_types_named_the_same() raises:
    expect_sdl(
        SDLRule.UNIQUE_TYPE_NAMES,
        """
      type Foo

      scalar Foo
      type Foo
      interface Foo
      union Foo
      enum Foo
      input Foo
    """,
        [
            'There can be only one type named "Foo". (2:12, 4:14)',
            'There can be only one type named "Foo". (2:12, 5:12)',
            'There can be only one type named "Foo". (2:12, 6:17)',
            'There can be only one type named "Foo". (2:12, 7:13)',
            'There can be only one type named "Foo". (2:12, 8:12)',
            'There can be only one type named "Foo". (2:12, 9:13)',
        ],
    )


def test_adding_new_type_to_existing_schema() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_TYPE_NAMES,
        """type Bar""",
        schema_sdl="""type Foo""",
    )


def test_adding_new_type_to_existing_schema_with_same_named_directive() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_TYPE_NAMES,
        """type Foo""",
        schema_sdl="""directive @Foo on SCHEMA""",
    )


def test_adding_conflicting_types_to_existing_schema() raises:
    expect_sdl(
        SDLRule.UNIQUE_TYPE_NAMES,
        """
      scalar Foo
      type Foo
      interface Foo
      union Foo
      enum Foo
      input Foo
    """,
        [
            (
                'Type "Foo" already exists in the schema. It cannot also be'
                " defined in this type definition. (2:14)"
            ),
            (
                'Type "Foo" already exists in the schema. It cannot also be'
                " defined in this type definition. (3:12)"
            ),
            (
                'Type "Foo" already exists in the schema. It cannot also be'
                " defined in this type definition. (4:17)"
            ),
            (
                'Type "Foo" already exists in the schema. It cannot also be'
                " defined in this type definition. (5:13)"
            ),
            (
                'Type "Foo" already exists in the schema. It cannot also be'
                " defined in this type definition. (6:12)"
            ),
            (
                'Type "Foo" already exists in the schema. It cannot also be'
                " defined in this type definition. (7:13)"
            ),
        ],
        schema_sdl="""type Foo""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
