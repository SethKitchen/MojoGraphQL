# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/KnownArgumentNamesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_known_arg_on_directive_defined_inside_sdl() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES,
        """
        type Query {
          foo: String @test(arg: "")
        }

        directive @test(arg: String) on FIELD_DEFINITION
      """,
    )


def test_unknown_arg_on_directive_defined_inside_sdl() raises:
    expect_sdl(
        SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES,
        """
        type Query {
          foo: String @test(unknown: "")
        }

        directive @test(arg: String) on FIELD_DEFINITION
      """,
        [
            'Unknown argument "unknown" on directive "@test". (3:29)',
        ],
    )


def test_misspelled_arg_name_is_reported_on_directive_defined_inside_sdl() raises:
    expect_sdl(
        SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES,
        """
        type Query {
          foo: String @test(agr: "")
        }

        directive @test(arg: String) on FIELD_DEFINITION
      """,
        [
            (
                'Unknown argument "agr" on directive "@test". Did you mean'
                ' "arg"? (3:29)'
            ),
        ],
    )


def test_unknown_arg_on_standard_directive() raises:
    expect_sdl(
        SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES,
        """
        type Query {
          foo: String @deprecated(unknown: "")
        }
      """,
        [
            'Unknown argument "unknown" on directive "@deprecated". (3:35)',
        ],
    )


def test_unknown_arg_on_overridden_standard_directive() raises:
    expect_sdl(
        SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES,
        """
        type Query {
          foo: String @deprecated(reason: "")
        }
        directive @deprecated(arg: String) on FIELD
      """,
        [
            'Unknown argument "reason" on directive "@deprecated". (3:35)',
        ],
    )


def test_unknown_arg_on_directive_defined_in_schema_extension() raises:
    expect_sdl(
        SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES,
        """
          directive @test(arg: String) on OBJECT

          extend type Query  @test(unknown: "")
        """,
        [
            'Unknown argument "unknown" on directive "@test". (4:36)',
        ],
        schema_sdl="""
        type Query {
          foo: String
        }
      """,
    )


def test_unknown_arg_on_directive_used_in_schema_extension() raises:
    expect_sdl(
        SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES,
        """
          extend type Query @test(unknown: "")
        """,
        [
            'Unknown argument "unknown" on directive "@test". (2:35)',
        ],
        schema_sdl="""
        directive @test(arg: String) on OBJECT

        type Query {
          foo: String
        }
      """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
