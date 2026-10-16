# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueDirectiveNamesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_directive() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """
      type Foo
    """,
    )


def test_one_directive() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """
      directive @foo on SCHEMA
    """,
    )


def test_many_directives() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """
      directive @foo on SCHEMA
      directive @bar on SCHEMA
      directive @baz on SCHEMA
    """,
    )


def test_directive_and_non_directive_definitions_named_the_same() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """
      query foo { __typename }
      fragment foo on foo { __typename }
      type foo

      directive @foo on SCHEMA
    """,
    )


def test_directives_named_the_same() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """
      directive @foo on SCHEMA

      directive @foo on SCHEMA
    """,
        [
            'There can be only one directive named "@foo". (2:18, 4:18)',
        ],
    )


def test_adding_new_directive_to_existing_schema() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """directive @bar on SCHEMA""",
        schema_sdl="""directive @foo on SCHEMA""",
    )


def test_adding_new_directive_with_standard_name_to_existing_schema() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """directive @skip on SCHEMA""",
        [
            (
                'Directive "@skip" already exists in the schema. It cannot be'
                " redefined. (1:12)"
            ),
        ],
        schema_sdl="""type foo""",
    )


def test_adding_new_directive_to_existing_schema_with_same_named_type() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """directive @foo on SCHEMA""",
        schema_sdl="""type foo""",
    )


def test_adding_conflicting_directives_to_existing_schema() raises:
    expect_sdl(
        SDLRule.UNIQUE_DIRECTIVE_NAMES,
        """directive @foo on SCHEMA""",
        [
            (
                'Directive "@foo" already exists in the schema. It cannot be'
                " redefined. (1:12)"
            ),
        ],
        schema_sdl="""directive @foo on SCHEMA""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
