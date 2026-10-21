# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for DeferStreamDirectiveLabelRule, ported from graphql-js
v17.0.2 (commit 71606d73)
`src/validation/__tests__/DeferStreamDirectiveLabelRule-test.ts`.

Every upstream case is here. The last test is beyond upstream: it covers a
directive that is not `@defer` or `@stream`.
"""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    incremental_test_schema,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime UNIQUE = (
    'Value for arguments "defer(label:)" and "stream(label:)" must be unique'
    " across all Defer/Stream directive usages."
)
"""The upstream message for a label that is used twice."""


def _expect_errors(query: String, expected: List[String]) raises:
    """Check the errors of the rule against the upstream test schema.

    Args:
        query: The document.
        expected: The formatted errors, in order.

    Raises:
        Error: When the errors differ.
    """
    expect_errors_with_schema(
        incremental_test_schema(),
        ValidationRule.DEFER_STREAM_DIRECTIVE_LABEL,
        query,
        expected,
    )


def _expect_valid(query: String) raises:
    """Check that the rule finds no error against the upstream test schema.

    Args:
        query: The document.

    Raises:
        Error: When there is an error.
    """
    expect_valid_with_schema(
        incremental_test_schema(),
        ValidationRule.DEFER_STREAM_DIRECTIVE_LABEL,
        query,
    )


def test_defer_fragments_with_no_label() raises:
    _expect_valid(
        """
      {
        dog {
          ...dogFragmentA @defer
          ...dogFragmentB @defer
        }
      }
      fragment dogFragmentA on Dog {
        name
      }
      fragment dogFragmentB on Dog {
        nickname
      }
    """
    )


def test_defer_fragments_one_with_label_one_without() raises:
    _expect_valid(
        """
      {
        dog {
          ...dogFragmentA @defer(label: "fragA")
          ...dogFragmentB @defer
        }
      }
      fragment dogFragmentA on Dog {
        name
      }
      fragment dogFragmentB on Dog {
        nickname
      }
    """
    )


def test_defer_fragment_with_null_label() raises:
    _expect_valid(
        """
      {
        dog {
          ...dogFragmentA @defer(label: null)
        }
      }
      fragment dogFragmentA on Dog {
        name
      }
    """
    )


def test_defer_fragment_with_variable_label() raises:
    _expect_errors(
        """
    query($label: String) {
      dog {
        ...dogFragmentA @defer(label: $label)
        ...dogFragmentB @defer(label: "fragA")
      }
    }
    fragment dogFragmentA on Dog {
      name
    }
    fragment dogFragmentB on Dog {
      nickname
    }
    """,
        ['Argument "@defer(label:)" must be a static string. (4:25)'],
    )


def test_defer_fragments_with_different_labels() raises:
    _expect_valid(
        """
    {
      dog {
        ...dogFragmentA @defer(label: "fragB")
        ...dogFragmentB @defer(label: "fragA")
      }
    }
    fragment dogFragmentA on Dog {
      name
    }
    fragment dogFragmentB on Dog {
      nickname
    }
    """
    )


def test_defer_fragments_with_same_label() raises:
    _expect_errors(
        """
    {
      dog {
        ...dogFragmentA @defer(label: "fragA")
        ...dogFragmentB @defer(label: "fragA")
      }
    }
    fragment dogFragmentA on Dog {
      name
    }
    fragment dogFragmentB on Dog {
      nickname
    }
    """,
        [String(UNIQUE) + " (4:25, 5:25)"],
    )


def test_defer_and_stream_with_no_label() raises:
    _expect_valid(
        """
      {
        dog {
          ...dogFragment @defer
        }
        pets @stream(initialCount: 0) @stream {
          name
        }
      }
      fragment dogFragment on Dog {
        name
      }
    """
    )


def test_stream_with_null_label() raises:
    _expect_valid(
        """
      {
        pets @stream(label: null) {
          name
        }
      }
    """
    )


def test_stream_with_variable_label() raises:
    _expect_errors(
        """
      query ($label: String!) {
        dog {
          ...dogFragment @defer
        }
        pets @stream(initialCount: 0) @stream(label: $label) {
          name
        }
      }
      fragment dogFragment on Dog {
        name
      }
      """,
        ['Argument "@stream(label:)" must be a static string. (6:39)'],
    )


def test_defer_and_stream_with_the_same_label() raises:
    _expect_errors(
        """
      {
        dog {
          ...dogFragment @defer(label: "MyLabel")
        }
        pets @stream(initialCount: 0) @stream(label: "MyLabel") {
          name
        }
      }
      fragment dogFragment on Dog {
        name
      }
      """,
        [String(UNIQUE) + " (4:26, 6:39)"],
    )


def test_other_directives() raises:
    # Beyond upstream: `@include` has no label to check.
    _expect_valid(
        """
      {
        dog @include(if: true) {
          ...dogFragment @defer(label: "a")
        }
      }
      fragment dogFragment on Dog {
        name
      }
      """
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
