# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for UniqueVariableNamesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueVariableNamesRule-test.ts`."""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_unique_variable_names() raises:
    expect_valid(
        ValidationRule.UNIQUE_VARIABLE_NAMES,
        """
      query A($x: Int, $y: String) { __typename }
      query B($x: String, $y: Int) { __typename }
    """,
    )


def test_duplicate_variable_names() raises:
    expect_errors(
        ValidationRule.UNIQUE_VARIABLE_NAMES,
        """
      query A($x: Int, $x: Int, $x: String) { __typename }
      query B($x: String, $x: Int) { __typename }
      query C($x: Int, $x: Int) { __typename }
    """,
        [
            'There can be only one variable named "$x". (2:16, 2:25, 2:34)',
            'There can be only one variable named "$x". (3:16, 3:28)',
            'There can be only one variable named "$x". (4:16, 4:25)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
