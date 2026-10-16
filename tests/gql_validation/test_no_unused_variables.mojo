# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for NoUnusedVariablesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/NoUnusedVariablesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_uses_all_variables() raises:
    expect_valid(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query ($a: String, $b: String, $c: String) {
        field(a: $a, b: $b, c: $c)
      }
    """,
    )


def test_uses_all_variables_deeply() raises:
    expect_valid(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($a: String, $b: String, $c: String) {
        field(a: $a) {
          field(b: $b) {
            field(c: $c)
          }
        }
      }
    """,
    )


def test_uses_all_variables_deeply_in_inline_fragments() raises:
    expect_valid(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($a: String, $b: String, $c: String) {
        ... on Type {
          field(a: $a) {
            field(b: $b) {
              ... on Type {
                field(c: $c)
              }
            }
          }
        }
      }
    """,
    )


def test_uses_all_variables_in_fragments() raises:
    expect_valid(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($a: String, $b: String, $c: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a) {
          ...FragB
        }
      }
      fragment FragB on Type {
        field(b: $b) {
          ...FragC
        }
      }
      fragment FragC on Type {
        field(c: $c)
      }
    """,
    )


def test_variable_used_by_fragment_in_multiple_operations() raises:
    expect_valid(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($a: String) {
        ...FragA
      }
      query Bar($b: String) {
        ...FragB
      }
      fragment FragA on Type {
        field(a: $a)
      }
      fragment FragB on Type {
        field(b: $b)
      }
    """,
    )


def test_variable_used_by_recursive_fragment() raises:
    expect_valid(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($a: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a) {
          ...FragA
        }
      }
    """,
    )


def test_variable_not_used() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query ($a: String, $b: String, $c: String) {
        field(a: $a, b: $b)
      }
    """,
        ['Variable "$c" is never used. (2:38)'],
    )


def test_multiple_variables_not_used() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($a: String, $b: String, $c: String) {
        field(b: $b)
      }
    """,
        [
            'Variable "$a" is never used in operation "Foo". (2:17)',
            'Variable "$c" is never used in operation "Foo". (2:41)',
        ],
    )


def test_variable_not_used_in_fragments() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($a: String, $b: String, $c: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a) {
          ...FragB
        }
      }
      fragment FragB on Type {
        field(b: $b) {
          ...FragC
        }
      }
      fragment FragC on Type {
        field
      }
    """,
        ['Variable "$c" is never used in operation "Foo". (2:41)'],
    )


def test_multiple_variables_not_used_in_fragments() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($a: String, $b: String, $c: String) {
        ...FragA
      }
      fragment FragA on Type {
        field {
          ...FragB
        }
      }
      fragment FragB on Type {
        field(b: $b) {
          ...FragC
        }
      }
      fragment FragC on Type {
        field
      }
    """,
        [
            'Variable "$a" is never used in operation "Foo". (2:17)',
            'Variable "$c" is never used in operation "Foo". (2:41)',
        ],
    )


def test_variable_not_used_by_unreferenced_fragment() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($b: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a)
      }
      fragment FragB on Type {
        field(b: $b)
      }
    """,
        ['Variable "$b" is never used in operation "Foo". (2:17)'],
    )


def test_variable_not_used_by_fragment_used_by_other_operation() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_VARIABLES,
        """
      query Foo($b: String) {
        ...FragA
      }
      query Bar($a: String) {
        ...FragB
      }
      fragment FragA on Type {
        field(a: $a)
      }
      fragment FragB on Type {
        field(b: $b)
      }
    """,
        [
            'Variable "$b" is never used in operation "Foo". (2:17)',
            'Variable "$a" is never used in operation "Bar". (5:17)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
