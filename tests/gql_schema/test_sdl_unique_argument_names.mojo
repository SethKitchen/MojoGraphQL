# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueArgumentNamesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_arguments_on_field() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field
      }
    """,
    )


def test_no_arguments_on_directive() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field @directive
      }
    """,
    )


def test_argument_on_field() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field(arg: "value")
      }
    """,
    )


def test_argument_on_directive() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field @directive(arg: "value")
      }
    """,
    )


def test_same_argument_on_two_fields() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        one: field(arg: "value")
        two: field(arg: "value")
      }
    """,
    )


def test_same_argument_on_field_and_directive() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field(arg: "value") @directive(arg: "value")
      }
    """,
    )


def test_same_argument_on_two_directives() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field @directive1(arg: "value") @directive2(arg: "value")
      }
    """,
    )


def test_multiple_field_arguments() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field(arg1: "value", arg2: "value", arg3: "value")
      }
    """,
    )


def test_multiple_directive_arguments() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field @directive(arg1: "value", arg2: "value", arg3: "value")
      }
    """,
    )


def test_duplicate_field_arguments() raises:
    expect_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field(arg1: "value", arg1: "value")
      }
    """,
        [
            'There can be only one argument named "arg1". (3:15, 3:30)',
        ],
    )


def test_many_duplicate_field_arguments() raises:
    expect_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field(arg1: "value", arg1: "value", arg1: "value")
      }
    """,
        [
            'There can be only one argument named "arg1". (3:15, 3:30, 3:45)',
        ],
    )


def test_duplicate_directive_arguments() raises:
    expect_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field @directive(arg1: "value", arg1: "value")
      }
    """,
        [
            'There can be only one argument named "arg1". (3:26, 3:41)',
        ],
    )


def test_many_duplicate_directive_arguments() raises:
    expect_sdl(
        SDLRule.UNIQUE_ARGUMENT_NAMES,
        """
      {
        field @directive(arg1: "value", arg1: "value", arg1: "value")
      }
    """,
        [
            'There can be only one argument named "arg1". (3:26, 3:41, 3:56)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
