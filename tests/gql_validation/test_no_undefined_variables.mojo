# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for NoUndefinedVariablesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/NoUndefinedVariablesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_all_variables_defined() raises:
    expect_valid(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($a: String, $b: String, $c: String) {
        field(a: $a, b: $b, c: $c)
      }
    """,
    )


def test_all_variables_deeply_defined() raises:
    expect_valid(
        ValidationRule.NO_UNDEFINED_VARIABLES,
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


def test_all_variables_deeply_in_inline_fragments_defined() raises:
    expect_valid(
        ValidationRule.NO_UNDEFINED_VARIABLES,
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


def test_all_variables_in_fragments_deeply_defined() raises:
    expect_valid(
        ValidationRule.NO_UNDEFINED_VARIABLES,
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


def test_variable_within_single_fragment_defined_in_multiple_operations() raises:
    expect_valid(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($a: String) {
        ...FragA
      }
      query Bar($a: String) {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a)
      }
    """,
    )


def test_variable_within_fragments_defined_in_operations() raises:
    expect_valid(
        ValidationRule.NO_UNDEFINED_VARIABLES,
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


def test_variable_within_recursive_fragment_defined() raises:
    expect_valid(
        ValidationRule.NO_UNDEFINED_VARIABLES,
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


def test_variable_not_defined() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($a: String, $b: String, $c: String) {
        field(a: $a, b: $b, c: $c, d: $d)
      }
    """,
        ['Variable "$d" is not defined by operation "Foo". (3:39, 2:7)'],
    )


def test_variable_not_defined_by_un_named_query() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      {
        field(a: $a)
      }
    """,
        ['Variable "$a" is not defined. (3:18, 2:7)'],
    )


def test_multiple_variables_not_defined() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($b: String) {
        field(a: $a, b: $b, c: $c)
      }
    """,
        [
            'Variable "$a" is not defined by operation "Foo". (3:18, 2:7)',
            'Variable "$c" is not defined by operation "Foo". (3:32, 2:7)',
        ],
    )


def test_variable_in_fragment_not_defined_by_un_named_query() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      {
        ...FragA
      }
      fragment FragA on Type {
        field(a: $a)
      }
    """,
        ['Variable "$a" is not defined. (6:18, 2:7)'],
    )


def test_variable_in_fragment_not_defined_by_operation() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($a: String, $b: String) {
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
        ['Variable "$c" is not defined by operation "Foo". (16:18, 2:7)'],
    )


def test_multiple_variables_in_fragments_not_defined() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($b: String) {
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
        [
            'Variable "$a" is not defined by operation "Foo". (6:18, 2:7)',
            'Variable "$c" is not defined by operation "Foo". (16:18, 2:7)',
        ],
    )


def test_single_variable_in_fragment_not_defined_by_multiple_operations() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($a: String) {
        ...FragAB
      }
      query Bar($a: String) {
        ...FragAB
      }
      fragment FragAB on Type {
        field(a: $a, b: $b)
      }
    """,
        [
            'Variable "$b" is not defined by operation "Foo". (9:25, 2:7)',
            'Variable "$b" is not defined by operation "Bar". (9:25, 5:7)',
        ],
    )


def test_variables_in_fragment_not_defined_by_multiple_operations() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($b: String) {
        ...FragAB
      }
      query Bar($a: String) {
        ...FragAB
      }
      fragment FragAB on Type {
        field(a: $a, b: $b)
      }
    """,
        [
            'Variable "$a" is not defined by operation "Foo". (9:18, 2:7)',
            'Variable "$b" is not defined by operation "Bar". (9:25, 5:7)',
        ],
    )


def test_variable_in_fragment_used_by_other_operation() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
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
            'Variable "$a" is not defined by operation "Foo". (9:18, 2:7)',
            'Variable "$b" is not defined by operation "Bar". (12:18, 5:7)',
        ],
    )


def test_multiple_undefined_variables_produce_multiple_errors() raises:
    expect_errors(
        ValidationRule.NO_UNDEFINED_VARIABLES,
        """
      query Foo($b: String) {
        ...FragAB
      }
      query Bar($a: String) {
        ...FragAB
      }
      fragment FragAB on Type {
        field1(a: $a, b: $b)
        ...FragC
        field3(a: $a, b: $b)
      }
      fragment FragC on Type {
        field2(c: $c)
      }
    """,
        [
            'Variable "$a" is not defined by operation "Foo". (9:19, 2:7)',
            'Variable "$a" is not defined by operation "Foo". (11:19, 2:7)',
            'Variable "$c" is not defined by operation "Foo". (14:19, 2:7)',
            'Variable "$b" is not defined by operation "Bar". (9:26, 5:7)',
            'Variable "$b" is not defined by operation "Bar". (11:26, 5:7)',
            'Variable "$c" is not defined by operation "Bar". (14:19, 5:7)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
