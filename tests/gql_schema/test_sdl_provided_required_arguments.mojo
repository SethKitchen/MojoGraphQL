# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/ProvidedRequiredArgumentsRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_ignores_unknown_directives() raises:
    expect_valid_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
        {
          dog @unknown
        }
      """,
    )


def test_with_directives_of_valid_types() raises:
    expect_valid_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
        {
          dog @include(if: true) {
            name
          }
          human @skip(if: false) {
            name
          }
        }
      """,
    )


def test_with_directive_with_missing_types() raises:
    expect_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
        {
          dog @include {
            name @skip
          }
        }
      """,
        [
            (
                'Directive "@include" argument "if" of type "Boolean!" is'
                " required, but it was not provided. (3:15)"
            ),
            (
                'Directive "@skip" argument "if" of type "Boolean!" is'
                " required, but it was not provided. (4:18)"
            ),
        ],
    )


def test_missing_optional_args_on_directive_defined_inside_sdl() raises:
    expect_valid_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
        type Query {
          foo: String @test
        }

        directive @test(arg1: String, arg2: String! = "") on FIELD_DEFINITION
      """,
    )


def test_missing_arg_on_directive_defined_inside_sdl() raises:
    expect_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
        type Query {
          foo: String @test
        }

        directive @test(arg: String!) on FIELD_DEFINITION
      """,
        [
            (
                'Directive "@test" argument "arg" of type "String!" is'
                " required, but it was not provided. (3:23)"
            ),
        ],
    )


def test_missing_arg_on_standard_directive() raises:
    expect_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
        type Query {
          foo: String @include
        }
      """,
        [
            (
                'Directive "@include" argument "if" of type "Boolean!" is'
                " required, but it was not provided. (3:23)"
            ),
        ],
    )


def test_missing_arg_on_overridden_standard_directive() raises:
    expect_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
        type Query {
          foo: String @deprecated
        }
        directive @deprecated(reason: String!) on FIELD
      """,
        [
            (
                'Directive "@deprecated" argument "reason" of type "String!" is'
                " required, but it was not provided. (3:23)"
            ),
        ],
    )


def test_missing_arg_on_directive_defined_in_schema_extension() raises:
    expect_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
          directive @test(arg: String!) on OBJECT

          extend type Query  @test
        """,
        [
            (
                'Directive "@test" argument "arg" of type "String!" is'
                " required, but it was not provided. (4:30)"
            ),
        ],
        schema_sdl="""
        type Query {
          foo: String
        }
      """,
    )


def test_missing_arg_on_directive_used_in_schema_extension() raises:
    expect_sdl(
        SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES,
        """
          extend type Query @test
        """,
        [
            (
                'Directive "@test" argument "arg" of type "String!" is'
                " required, but it was not provided. (2:29)"
            ),
        ],
        schema_sdl="""
        directive @test(arg: String!) on OBJECT

        type Query {
          foo: String
        }
      """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
