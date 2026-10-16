# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for UniqueOperationNamesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueOperationNamesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_no_operations() raises:
    expect_valid(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      fragment fragA on Type {
        field
      }
    """,
    )


def test_one_anon_operation() raises:
    expect_valid(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      {
        field
      }
    """,
    )


def test_one_named_operation() raises:
    expect_valid(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      query Foo {
        field
      }
    """,
    )


def test_multiple_operations() raises:
    expect_valid(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      query Foo {
        field
      }

      query Bar {
        field
      }
    """,
    )


def test_multiple_operations_of_different_types() raises:
    expect_valid(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      query Foo {
        field
      }

      mutation Bar {
        field
      }

      subscription Baz {
        field
      }
    """,
    )


def test_fragment_and_operation_named_the_same() raises:
    expect_valid(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      query Foo {
        ...Foo
      }
      fragment Foo on Type {
        field
      }
    """,
    )


def test_multiple_operations_of_same_name() raises:
    expect_errors(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      query Foo {
        fieldA
      }
      query Foo {
        fieldB
      }
    """,
        ['There can be only one operation named "Foo". (2:13, 5:13)'],
    )


def test_multiple_ops_of_same_name_of_different_types_mutation() raises:
    expect_errors(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      query Foo {
        fieldA
      }
      mutation Foo {
        fieldB
      }
    """,
        ['There can be only one operation named "Foo". (2:13, 5:16)'],
    )


def test_multiple_ops_of_same_name_of_different_types_subscription() raises:
    expect_errors(
        ValidationRule.UNIQUE_OPERATION_NAMES,
        """
      query Foo {
        fieldA
      }
      subscription Foo {
        fieldB
      }
    """,
        ['There can be only one operation named "Foo". (2:13, 5:20)'],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
