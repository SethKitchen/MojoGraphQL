# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.suggestions`, ported from graphql-js 16.14.2
`src/jsutils/__tests__/suggestionList-test.ts`, `didYouMean-test.ts` and
`naturalCompare-test.ts`."""

from gql_schema.suggestions import (
    did_you_mean,
    lexical_distance,
    natural_compare,
    suggestion_list,
)
from std.testing import TestSuite, assert_equal


def suggestions(input: String, options: List[String]) -> String:
    """Return `suggestion_list` joined by commas."""
    var out = String("")
    var found = suggestion_list(input, options)
    for index in range(len(found)):
        if index > 0:
            out += ","
        out += found[index]
    return out^


# --- suggestionList -------------------------------------------------------


def test_returns_results_when_input_is_empty() raises:
    assert_equal(suggestions("", ["a"]), "a")


def test_returns_empty_array_when_there_are_no_options() raises:
    assert_equal(suggestions("input", []), "")


def test_returns_options_with_small_lexical_distance() raises:
    assert_equal(suggestions("greenish", ["green"]), "green")
    assert_equal(suggestions("green", ["greenish"]), "greenish")


def test_rejects_options_with_distance_that_exceeds_threshold() raises:
    assert_equal(suggestions("aaaa", ["aaab"]), "aaab")
    assert_equal(suggestions("aaaa", ["aabb"]), "aabb")
    assert_equal(suggestions("aaaa", ["abbb"]), "")
    assert_equal(suggestions("ab", ["ca"]), "")


def test_returns_options_with_different_case() raises:
    assert_equal(
        suggestions("verylongstring", ["VERYLONGSTRING"]), "VERYLONGSTRING"
    )
    assert_equal(
        suggestions("VERYLONGSTRING", ["verylongstring"]), "verylongstring"
    )
    assert_equal(
        suggestions("VERYLONGSTRING", ["VeryLongString"]), "VeryLongString"
    )


def test_returns_options_with_transpositions() raises:
    assert_equal(suggestions("agr", ["arg"]), "arg")
    assert_equal(suggestions("214365879", ["123456789"]), "123456789")


def test_returns_options_sorted_based_on_lexical_distance() raises:
    assert_equal(suggestions("abc", ["a", "ab", "abc"]), "abc,ab,a")


def test_returns_options_with_the_same_lexical_distance_sorted_lexicographically() raises:
    assert_equal(suggestions("a", ["az", "ax", "ay"]), "ax,ay,az")


# Not in graphql-js: the cases its other tests reach through the rules.


def test_keeps_an_option_once() raises:
    assert_equal(suggestions("abc", ["abd", "abc", "abd"]), "abc,abd")


def test_puts_a_farther_option_after_a_closer_one() raises:
    assert_equal(suggestions("abc", ["abc", "ab"]), "abc,ab")


def test_rejects_an_option_much_longer_than_the_input() raises:
    assert_equal(lexical_distance("a", "abcdef", 1), -1)
    assert_equal(lexical_distance("abc", "abc", 1), 0)


def test_compares_a_digit_with_a_letter() raises:
    assert_equal(natural_compare("1", "a"), -1)
    assert_equal(natural_compare("a", "1"), 1)


# --- didYouMean -----------------------------------------------------------


def test_does_accept_an_empty_list() raises:
    assert_equal(did_you_mean(List[String]()), "")


def test_handles_single_suggestion() raises:
    assert_equal(did_you_mean(["A"]), ' Did you mean "A"?')


def test_handles_two_suggestions() raises:
    assert_equal(did_you_mean(["A", "B"]), ' Did you mean "A" or "B"?')


def test_handles_multiple_suggestions() raises:
    assert_equal(
        did_you_mean(["A", "B", "C"]), ' Did you mean "A", "B", or "C"?'
    )


def test_limits_to_five_suggestions() raises:
    assert_equal(
        did_you_mean(["A", "B", "C", "D", "E", "F"]),
        ' Did you mean "A", "B", "C", "D", or "E"?',
    )


def test_adds_sub_message() raises:
    assert_equal(
        did_you_mean("the letter", ["A"]), ' Did you mean the letter "A"?'
    )


# --- naturalCompare -------------------------------------------------------


def test_handles_empty_strings() raises:
    assert_equal(natural_compare("", ""), 0)
    assert_equal(natural_compare("", "a"), -1)
    assert_equal(natural_compare("", "1"), -1)
    assert_equal(natural_compare("a", ""), 1)
    assert_equal(natural_compare("1", ""), 1)


def test_handles_strings_of_different_length() raises:
    assert_equal(natural_compare("A", "A"), 0)
    assert_equal(natural_compare("A1", "A1"), 0)
    assert_equal(natural_compare("A", "AA"), -1)
    assert_equal(natural_compare("A1", "A1A"), -1)
    assert_equal(natural_compare("AA", "A"), 1)
    assert_equal(natural_compare("A1A", "A1"), 1)


def test_handles_numbers() raises:
    assert_equal(natural_compare("0", "0"), 0)
    assert_equal(natural_compare("1", "1"), 0)
    assert_equal(natural_compare("1", "2"), -1)
    assert_equal(natural_compare("2", "1"), 1)
    assert_equal(natural_compare("2", "11"), -1)
    assert_equal(natural_compare("11", "2"), 1)


def test_handles_numbers_with_leading_zeros() raises:
    assert_equal(natural_compare("00", "00"), 0)
    assert_equal(natural_compare("0", "00"), -1)
    assert_equal(natural_compare("00", "0"), 1)
    assert_equal(natural_compare("02", "11"), -1)
    assert_equal(natural_compare("11", "02"), 1)
    assert_equal(natural_compare("011", "200"), -1)
    assert_equal(natural_compare("200", "011"), 1)


def test_handles_numbers_embedded_into_names() raises:
    assert_equal(natural_compare("a0a", "a0a"), 0)
    assert_equal(natural_compare("a0a", "a9a"), -1)
    assert_equal(natural_compare("a9a", "a0a"), 1)
    assert_equal(natural_compare("a00a", "a00a"), 0)
    assert_equal(natural_compare("a00a", "a09a"), -1)
    assert_equal(natural_compare("a09a", "a00a"), 1)
    assert_equal(natural_compare("a0a1", "a0a1"), 0)
    assert_equal(natural_compare("a0a1", "a0a9"), -1)
    assert_equal(natural_compare("a0a9", "a0a1"), 1)
    assert_equal(natural_compare("a10a11a", "a10a11a"), 0)
    assert_equal(natural_compare("a10a11a", "a10a19a"), -1)
    assert_equal(natural_compare("a10a19a", "a10a11a"), 1)
    assert_equal(natural_compare("a10a11a", "a10a11b"), -1)
    assert_equal(natural_compare("a10a11b", "a10a11a"), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
