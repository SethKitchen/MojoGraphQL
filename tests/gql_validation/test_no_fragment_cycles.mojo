# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for NoFragmentCyclesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/NoFragmentCyclesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_single_reference_is_valid() raises:
    expect_valid(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragB }
      fragment fragB on Dog { name }
    """,
    )


def test_spreading_twice_is_not_circular() raises:
    expect_valid(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragB, ...fragB }
      fragment fragB on Dog { name }
    """,
    )


def test_spreading_twice_indirectly_is_not_circular() raises:
    expect_valid(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragB, ...fragC }
      fragment fragB on Dog { ...fragC }
      fragment fragC on Dog { name }
    """,
    )


def test_double_spread_within_abstract_types() raises:
    expect_valid(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment nameFragment on Pet {
        ... on Dog { name }
        ... on Cat { name }
      }

      fragment spreadsInAnon on Pet {
        ... on Dog { ...nameFragment }
        ... on Cat { ...nameFragment }
      }
    """,
    )


def test_does_not_false_positive_on_unknown_fragment() raises:
    expect_valid(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment nameFragment on Pet {
        ...UnknownFragment
      }
    """,
    )


def test_spreading_recursively_within_field_fails() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Human { relatives { ...fragA } },
    """,
        ['Cannot spread fragment "fragA" within itself. (2:45)'],
    )


def test_no_spreading_itself_directly() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragA }
    """,
        ['Cannot spread fragment "fragA" within itself. (2:31)'],
    )


def test_no_spreading_itself_directly_within_inline_fragment() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Pet {
        ... on Dog {
          ...fragA
        }
      }
    """,
        ['Cannot spread fragment "fragA" within itself. (4:11)'],
    )


def test_no_spreading_itself_indirectly() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragB }
      fragment fragB on Dog { ...fragA }
    """,
        [
            (
                'Cannot spread fragment "fragA" within itself via "fragB".'
                " (2:31, 3:31)"
            ),
        ],
    )


def test_no_spreading_itself_indirectly_reports_opposite_order() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragB on Dog { ...fragA }
      fragment fragA on Dog { ...fragB }
    """,
        [
            (
                'Cannot spread fragment "fragB" within itself via "fragA".'
                " (2:31, 3:31)"
            ),
        ],
    )


def test_no_spreading_itself_indirectly_within_inline_fragment() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Pet {
        ... on Dog {
          ...fragB
        }
      }
      fragment fragB on Pet {
        ... on Dog {
          ...fragA
        }
      }
    """,
        [
            (
                'Cannot spread fragment "fragA" within itself via "fragB".'
                " (4:11, 9:11)"
            ),
        ],
    )


def test_no_spreading_itself_deeply() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragB }
      fragment fragB on Dog { ...fragC }
      fragment fragC on Dog { ...fragO }
      fragment fragX on Dog { ...fragY }
      fragment fragY on Dog { ...fragZ }
      fragment fragZ on Dog { ...fragO }
      fragment fragO on Dog { ...fragP }
      fragment fragP on Dog { ...fragA, ...fragX }
    """,
        [
            (
                'Cannot spread fragment "fragA" within itself via "fragB",'
                ' "fragC", "fragO", "fragP". (2:31, 3:31, 4:31, 8:31, 9:31)'
            ),
            (
                'Cannot spread fragment "fragO" within itself via "fragP",'
                ' "fragX", "fragY", "fragZ". (8:31, 9:41, 5:31, 6:31, 7:31)'
            ),
        ],
    )


def test_no_spreading_itself_deeply_two_paths() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragB, ...fragC }
      fragment fragB on Dog { ...fragA }
      fragment fragC on Dog { ...fragA }
    """,
        [
            (
                'Cannot spread fragment "fragA" within itself via "fragB".'
                " (2:31, 3:31)"
            ),
            (
                'Cannot spread fragment "fragA" within itself via "fragC".'
                " (2:41, 4:31)"
            ),
        ],
    )


def test_no_spreading_itself_deeply_two_paths_alt_traverse_order() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragC }
      fragment fragB on Dog { ...fragC }
      fragment fragC on Dog { ...fragA, ...fragB }
    """,
        [
            (
                'Cannot spread fragment "fragA" within itself via "fragC".'
                " (2:31, 4:31)"
            ),
            (
                'Cannot spread fragment "fragC" within itself via "fragB".'
                " (4:41, 3:31)"
            ),
        ],
    )


def test_no_spreading_itself_deeply_and_immediately() raises:
    expect_errors(
        ValidationRule.NO_FRAGMENT_CYCLES,
        """
      fragment fragA on Dog { ...fragB }
      fragment fragB on Dog { ...fragB, ...fragC }
      fragment fragC on Dog { ...fragA, ...fragB }
    """,
        [
            'Cannot spread fragment "fragB" within itself. (3:31)',
            (
                'Cannot spread fragment "fragA" within itself via "fragB",'
                ' "fragC". (2:31, 3:41, 4:31)'
            ),
            (
                'Cannot spread fragment "fragB" within itself via "fragC".'
                " (3:41, 4:41)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
