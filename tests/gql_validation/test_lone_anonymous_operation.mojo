# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for LoneAnonymousOperationRule, ported from graphql-js 16.14.2
`src/validation/__tests__/LoneAnonymousOperationRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_no_operations() raises:
    expect_valid(
        ValidationRule.LONE_ANONYMOUS_OPERATION,
        """
      fragment fragA on Type {
        field
      }
    """,
    )


def test_one_anon_operation() raises:
    expect_valid(
        ValidationRule.LONE_ANONYMOUS_OPERATION,
        """
      {
        field
      }
    """,
    )


def test_multiple_named_operations() raises:
    expect_valid(
        ValidationRule.LONE_ANONYMOUS_OPERATION,
        """
      query Foo {
        field
      }

      query Bar {
        field
      }
    """,
    )


def test_anon_operation_with_fragment() raises:
    expect_valid(
        ValidationRule.LONE_ANONYMOUS_OPERATION,
        """
      {
        ...Foo
      }
      fragment Foo on Type {
        field
      }
    """,
    )


def test_multiple_anon_operations() raises:
    expect_errors(
        ValidationRule.LONE_ANONYMOUS_OPERATION,
        """
      {
        fieldA
      }
      {
        fieldB
      }
    """,
        [
            (
                "This anonymous operation must be the only defined operation."
                " (2:7)"
            ),
            (
                "This anonymous operation must be the only defined operation."
                " (5:7)"
            ),
        ],
    )


def test_anon_operation_with_a_mutation() raises:
    expect_errors(
        ValidationRule.LONE_ANONYMOUS_OPERATION,
        """
      {
        fieldA
      }
      mutation Foo {
        fieldB
      }
    """,
        [
            (
                "This anonymous operation must be the only defined operation."
                " (2:7)"
            ),
        ],
    )


def test_anon_operation_with_a_subscription() raises:
    expect_errors(
        ValidationRule.LONE_ANONYMOUS_OPERATION,
        """
      {
        fieldA
      }
      subscription Foo {
        fieldB
      }
    """,
        [
            (
                "This anonymous operation must be the only defined operation."
                " (2:7)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
