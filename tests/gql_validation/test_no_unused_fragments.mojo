# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for NoUnusedFragmentsRule, ported from graphql-js 16.14.2
`src/validation/__tests__/NoUnusedFragmentsRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_all_fragment_names_are_used() raises:
    expect_valid(
        ValidationRule.NO_UNUSED_FRAGMENTS,
        """
      {
        human(id: 4) {
          ...HumanFields1
          ... on Human {
            ...HumanFields2
          }
        }
      }
      fragment HumanFields1 on Human {
        name
        ...HumanFields3
      }
      fragment HumanFields2 on Human {
        name
      }
      fragment HumanFields3 on Human {
        name
      }
    """,
    )


def test_all_fragment_names_are_used_by_multiple_operations() raises:
    expect_valid(
        ValidationRule.NO_UNUSED_FRAGMENTS,
        """
      query Foo {
        human(id: 4) {
          ...HumanFields1
        }
      }
      query Bar {
        human(id: 4) {
          ...HumanFields2
        }
      }
      fragment HumanFields1 on Human {
        name
        ...HumanFields3
      }
      fragment HumanFields2 on Human {
        name
      }
      fragment HumanFields3 on Human {
        name
      }
    """,
    )


def test_contains_unknown_fragments() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_FRAGMENTS,
        """
      query Foo {
        human(id: 4) {
          ...HumanFields1
        }
      }
      query Bar {
        human(id: 4) {
          ...HumanFields2
        }
      }
      fragment HumanFields1 on Human {
        name
        ...HumanFields3
      }
      fragment HumanFields2 on Human {
        name
      }
      fragment HumanFields3 on Human {
        name
      }
      fragment Unused1 on Human {
        name
      }
      fragment Unused2 on Human {
        name
      }
    """,
        [
            'Fragment "Unused1" is never used. (22:7)',
            'Fragment "Unused2" is never used. (25:7)',
        ],
    )


def test_contains_unknown_fragments_with_ref_cycle() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_FRAGMENTS,
        """
      query Foo {
        human(id: 4) {
          ...HumanFields1
        }
      }
      query Bar {
        human(id: 4) {
          ...HumanFields2
        }
      }
      fragment HumanFields1 on Human {
        name
        ...HumanFields3
      }
      fragment HumanFields2 on Human {
        name
      }
      fragment HumanFields3 on Human {
        name
      }
      fragment Unused1 on Human {
        name
        ...Unused2
      }
      fragment Unused2 on Human {
        name
        ...Unused1
      }
    """,
        [
            'Fragment "Unused1" is never used. (22:7)',
            'Fragment "Unused2" is never used. (26:7)',
        ],
    )


def test_contains_unknown_and_undef_fragments() raises:
    expect_errors(
        ValidationRule.NO_UNUSED_FRAGMENTS,
        """
      query Foo {
        human(id: 4) {
          ...bar
        }
      }
      fragment foo on Human {
        name
      }
    """,
        ['Fragment "foo" is never used. (7:7)'],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
