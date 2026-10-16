# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for KnownFragmentNamesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/KnownFragmentNamesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_known_fragment_names_are_valid() raises:
    expect_valid(
        ValidationRule.KNOWN_FRAGMENT_NAMES,
        """
      {
        human(id: 4) {
          ...HumanFields1
          ... on Human {
            ...HumanFields2
          }
          ... {
            name
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


def test_unknown_fragment_names_are_invalid() raises:
    expect_errors(
        ValidationRule.KNOWN_FRAGMENT_NAMES,
        """
      {
        human(id: 4) {
          ...UnknownFragment1
          ... on Human {
            ...UnknownFragment2
          }
        }
      }
      fragment HumanFields on Human {
        name
        ...UnknownFragment3
      }
    """,
        [
            'Unknown fragment "UnknownFragment1". (4:14)',
            'Unknown fragment "UnknownFragment2". (6:16)',
            'Unknown fragment "UnknownFragment3". (12:12)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
