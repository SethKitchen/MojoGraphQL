# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for FragmentsOnCompositeTypesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/FragmentsOnCompositeTypesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_object_is_valid_fragment_type() raises:
    expect_valid(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment validFragment on Dog {
        barks
      }
    """,
    )


def test_interface_is_valid_fragment_type() raises:
    expect_valid(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment validFragment on Pet {
        name
      }
    """,
    )


def test_object_is_valid_inline_fragment_type() raises:
    expect_valid(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment validFragment on Pet {
        ... on Dog {
          barks
        }
      }
    """,
    )


def test_interface_is_valid_inline_fragment_type() raises:
    expect_valid(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment validFragment on Mammal {
        ... on Canine {
          name
        }
      }
    """,
    )


def test_inline_fragment_without_type_is_valid() raises:
    expect_valid(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment validFragment on Pet {
        ... {
          name
        }
      }
    """,
    )


def test_union_is_valid_fragment_type() raises:
    expect_valid(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment validFragment on CatOrDog {
        __typename
      }
    """,
    )


def test_scalar_is_invalid_fragment_type() raises:
    expect_errors(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment scalarFragment on Boolean {
        bad
      }
    """,
        [
            (
                'Fragment "scalarFragment" cannot condition on non composite'
                ' type "Boolean". (2:34)'
            ),
        ],
    )


def test_enum_is_invalid_fragment_type() raises:
    expect_errors(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment scalarFragment on FurColor {
        bad
      }
    """,
        [
            (
                'Fragment "scalarFragment" cannot condition on non composite'
                ' type "FurColor". (2:34)'
            ),
        ],
    )


def test_input_object_is_invalid_fragment_type() raises:
    expect_errors(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment inputFragment on ComplexInput {
        stringField
      }
    """,
        [
            (
                'Fragment "inputFragment" cannot condition on non composite'
                ' type "ComplexInput". (2:33)'
            ),
        ],
    )


def test_scalar_is_invalid_inline_fragment_type() raises:
    expect_errors(
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        """
      fragment invalidFragment on Pet {
        ... on String {
          barks
        }
      }
    """,
        ['Fragment cannot condition on non composite type "String". (3:16)'],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
