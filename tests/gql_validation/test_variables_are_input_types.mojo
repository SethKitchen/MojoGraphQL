# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for VariablesAreInputTypesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/VariablesAreInputTypesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_unknown_types_are_ignored() raises:
    expect_valid(
        ValidationRule.VARIABLES_ARE_INPUT_TYPES,
        """
      query Foo($a: Unknown, $b: [[Unknown!]]!) {
        field(a: $a, b: $b)
      }
    """,
    )


def test_input_types_are_valid() raises:
    expect_valid(
        ValidationRule.VARIABLES_ARE_INPUT_TYPES,
        """
      query Foo($a: String, $b: [Boolean!]!, $c: ComplexInput) {
        field(a: $a, b: $b, c: $c)
      }
    """,
    )


def test_output_types_are_invalid() raises:
    expect_errors(
        ValidationRule.VARIABLES_ARE_INPUT_TYPES,
        """
      query Foo($a: Dog, $b: [[CatOrDog!]]!, $c: Pet) {
        field(a: $a, b: $b, c: $c)
      }
    """,
        [
            'Variable "$a" cannot be non-input type "Dog". (2:21)',
            'Variable "$b" cannot be non-input type "[[CatOrDog!]]!". (2:30)',
            'Variable "$c" cannot be non-input type "Pet". (2:50)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
