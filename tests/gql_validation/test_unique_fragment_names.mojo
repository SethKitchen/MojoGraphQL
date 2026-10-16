# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for UniqueFragmentNamesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueFragmentNamesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_no_fragments() raises:
    expect_valid(
        ValidationRule.UNIQUE_FRAGMENT_NAMES,
        """
      {
        field
      }
    """,
    )


def test_one_fragment() raises:
    expect_valid(
        ValidationRule.UNIQUE_FRAGMENT_NAMES,
        """
      {
        ...fragA
      }

      fragment fragA on Type {
        field
      }
    """,
    )


def test_many_fragments() raises:
    expect_valid(
        ValidationRule.UNIQUE_FRAGMENT_NAMES,
        """
      {
        ...fragA
        ...fragB
        ...fragC
      }
      fragment fragA on Type {
        fieldA
      }
      fragment fragB on Type {
        fieldB
      }
      fragment fragC on Type {
        fieldC
      }
    """,
    )


def test_inline_fragments_are_always_unique() raises:
    expect_valid(
        ValidationRule.UNIQUE_FRAGMENT_NAMES,
        """
      {
        ...on Type {
          fieldA
        }
        ...on Type {
          fieldB
        }
      }
    """,
    )


def test_fragment_and_operation_named_the_same() raises:
    expect_valid(
        ValidationRule.UNIQUE_FRAGMENT_NAMES,
        """
      query Foo {
        ...Foo
      }
      fragment Foo on Type {
        field
      }
    """,
    )


def test_fragments_named_the_same() raises:
    expect_errors(
        ValidationRule.UNIQUE_FRAGMENT_NAMES,
        """
      {
        ...fragA
      }
      fragment fragA on Type {
        fieldA
      }
      fragment fragA on Type {
        fieldB
      }
    """,
        ['There can be only one fragment named "fragA". (5:16, 8:16)'],
    )


def test_fragments_named_the_same_without_being_referenced() raises:
    expect_errors(
        ValidationRule.UNIQUE_FRAGMENT_NAMES,
        """
      fragment fragA on Type {
        fieldA
      }
      fragment fragA on Type {
        fieldB
      }
    """,
        ['There can be only one fragment named "fragA". (2:16, 5:16)'],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
