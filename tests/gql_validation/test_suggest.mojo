# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_validation.suggest`, beyond upstream.

`Suggester` must give the same list as `gql_schema.suggestions.
suggestion_list`, the port of graphql-js `suggestionList`. Each test
compares the two for one input and a list of options.
"""

from gql_schema.suggestions import suggestion_list
from gql_validation.suggest import Suggester
from std.testing import TestSuite, assert_equal


def _joined(items: List[String]) -> String:
    var out = String("")
    for ref item in items:
        out += item + ","
    return out^


def _expect_same(input: String, options: List[String]) raises:
    var suggester = Suggester(input)
    for ref option in options:
        suggester.consider(option)
    assert_equal(
        _joined(suggester^.take()), _joined(suggestion_list(input, options))
    )


def test_equal_and_case_only() raises:
    _expect_same("name", ["name", "NAME", "Name", "nam", "names"])


def test_duplicates_count_once() raises:
    _expect_same("hello", ["hallo", "hallo", "hello", "jello", "hello"])


def test_ties_in_natural_order() raises:
    _expect_same("item", ["item2", "item10", "item1", "itex", "iteb"])


def test_transpositions() raises:
    _expect_same("abcd", ["bacd", "abdc", "badc", "acbd", "dcba"])
    _expect_same("ab", ["ba", "aab", "b"])


def test_far_options() raises:
    _expect_same(
        "unknownType",
        [
            "UnknownTypes",
            "known",
            "TypeUnknown",
            "unknownTypeXY",
            "xxxxxxxxxxx",
        ],
    )
    _expect_same("abc", ["xyz", "abcdefgh", "cab", "acb", "bca"])


def test_a_last_cell_above_the_threshold() raises:
    # Each row has a small cell, but the distance is above the threshold.
    _expect_same("abcde", ["abxyz", "xbcdy", "aebcd", "edcba"])


def test_empty_texts() raises:
    _expect_same("", ["", "a", "ab"])
    _expect_same("a", ["", "b", "A"])


def test_non_letters() raises:
    _expect_same("_A1", ["_a1", "_B1", "[A1", "@A1", "_A2"])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
