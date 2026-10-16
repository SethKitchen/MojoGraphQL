# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueArgumentDefinitionNamesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_args() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_DEFINITION_NAMES,
        """
      type SomeObject {
        someField: String
      }

      interface SomeInterface {
        someField: String
      }

      directive @someDirective on QUERY
    """,
    )


def test_one_argument() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_DEFINITION_NAMES,
        """
      type SomeObject {
        someField(foo: String): String
      }

      interface SomeInterface {
        someField(foo: String): String
      }

      extend type SomeObject {
        anotherField(foo: String): String
      }

      extend interface SomeInterface {
        anotherField(foo: String): String
      }

      directive @someDirective(foo: String) on QUERY
    """,
    )


def test_multiple_arguments() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_DEFINITION_NAMES,
        """
      type SomeObject {
        someField(
          foo: String
          bar: String
        ): String
      }

      interface SomeInterface {
        someField(
          foo: String
          bar: String
        ): String
      }

      extend type SomeObject {
        anotherField(
          foo: String
          bar: String
        ): String
      }

      extend interface SomeInterface {
        anotherField(
          foo: String
          bar: String
        ): String
      }

      directive @someDirective(
        foo: String
        bar: String
      ) on QUERY
    """,
    )


def test_duplicating_arguments() raises:
    expect_sdl(
        SDLRule.UNIQUE_ARGUMENT_DEFINITION_NAMES,
        """
      type SomeObject {
        someField(
          foo: String
          bar: String
          foo: String
        ): String
      }

      interface SomeInterface {
        someField(
          foo: String
          bar: String
          foo: String
        ): String
      }

      extend type SomeObject {
        anotherField(
          foo: String
          bar: String
          bar: String
        ): String
      }

      extend interface SomeInterface {
        anotherField(
          bar: String
          foo: String
          foo: String
        ): String
      }

      directive @someDirective(
        foo: String
        bar: String
        foo: String
      ) on QUERY
    """,
        [
            (
                'Argument "SomeObject.someField(foo:)" can only be defined'
                " once. (4:11, 6:11)"
            ),
            (
                'Argument "SomeInterface.someField(foo:)" can only be defined'
                " once. (12:11, 14:11)"
            ),
            (
                'Argument "SomeObject.anotherField(bar:)" can only be defined'
                " once. (21:11, 22:11)"
            ),
            (
                'Argument "SomeInterface.anotherField(foo:)" can only be'
                " defined once. (29:11, 30:11)"
            ),
            (
                'Argument "@someDirective(foo:)" can only be defined once.'
                " (35:9, 37:9)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
