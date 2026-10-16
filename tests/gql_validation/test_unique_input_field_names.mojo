# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for UniqueInputFieldNamesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueInputFieldNamesRule-test.ts`.

Every upstream case is ported.
"""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_input_object_with_fields() raises:
    expect_valid(
        ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
        """
      {
        field(arg: { f: true })
      }
    """,
    )


def test_same_input_object_within_two_args() raises:
    expect_valid(
        ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
        """
      {
        field(arg1: { f: true }, arg2: { f: true })
      }
    """,
    )


def test_multiple_input_object_fields() raises:
    expect_valid(
        ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
        """
      {
        field(arg: { f1: "value", f2: "value", f3: "value" })
      }
    """,
    )


def test_allows_for_nested_input_objects_with_similar_fields() raises:
    expect_valid(
        ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
        """
      {
        field(arg: {
          deep: {
            deep: {
              id: 1
            }
            id: 1
          }
          id: 1
        })
      }
    """,
    )


def test_duplicate_input_object_fields() raises:
    expect_errors(
        ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
        """
      {
        field(arg: { f1: "value", f1: "value" })
      }
    """,
        ['There can be only one input field named "f1". (3:22, 3:35)'],
    )


def test_many_duplicate_input_object_fields() raises:
    expect_errors(
        ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
        """
      {
        field(arg: { f1: "value", f1: "value", f1: "value" })
      }
    """,
        [
            'There can be only one input field named "f1". (3:22, 3:35)',
            'There can be only one input field named "f1". (3:22, 3:48)',
        ],
    )


def test_nested_duplicate_input_object_fields() raises:
    expect_errors(
        ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
        """
      {
        field(arg: { f1: {f2: "value", f2: "value" }})
      }
    """,
        ['There can be only one input field named "f2". (3:27, 3:40)'],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
