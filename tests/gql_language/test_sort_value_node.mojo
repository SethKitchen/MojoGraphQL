# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.sort_value_node`, ported from graphql-js
16.14.2 `src/utilities/__tests__/sortValueNode-test.ts`.

More tests cover empty lists and objects, variables, a stable sort of
equal names, and the natural order of `naturalCompare`, which graphql-js
tests in `src/jsutils/__tests__/naturalCompare-test.ts`.
"""

from gql_language.parser import parse_value
from gql_language.printer import print_ast
from gql_language.sort_value_node import sort_value_node
from std.testing import TestSuite, assert_equal


def sorted_value(text: String) raises -> String:
    """Return a value parsed, sorted and printed, as `expectSortedValue`."""
    var document = parse_value(text)
    return print_ast(sort_value_node(document, document.root))


def test_does_not_change_non_object_values() raises:
    assert_equal(sorted_value("1"), "1")
    assert_equal(sorted_value("3.14"), "3.14")
    assert_equal(sorted_value("null"), "null")
    assert_equal(sorted_value("true"), "true")
    assert_equal(sorted_value("false"), "false")
    assert_equal(sorted_value('"cba"'), '"cba"')
    assert_equal(sorted_value('"""cba"""'), '"""cba"""')
    assert_equal(
        sorted_value('[1, 3.14, null, false, "cba"]'),
        '[1, 3.14, null, false, "cba"]',
    )
    assert_equal(
        sorted_value('[[1, 3.14, null, false, "cba"]]'),
        '[[1, 3.14, null, false, "cba"]]',
    )


def test_sorts_input_object_fields() raises:
    assert_equal(sorted_value("{ b: 2, a: 1 }"), "{a: 1, b: 2}")
    assert_equal(sorted_value("{ a: { c: 3, b: 2 } }"), "{a: {b: 2, c: 3}}")
    assert_equal(
        sorted_value("[{ b: 2, a: 1 }, { d: 4, c: 3}]"),
        "[{a: 1, b: 2}, {c: 3, d: 4}]",
    )
    assert_equal(
        sorted_value("{ b: { g: 7, f: 6 }, c: 3 , a: { d: 4, e: 5 } }"),
        "{a: {d: 4, e: 5}, b: {f: 6, g: 7}, c: 3}",
    )


def test_keeps_empty_values_and_variables() raises:
    assert_equal(sorted_value("[]"), "[]")
    assert_equal(sorted_value("{}"), "{}")
    assert_equal(sorted_value("{ b: $x, a: ENUM }"), "{a: ENUM, b: $x}")


def test_sort_is_stable() raises:
    assert_equal(
        sorted_value("{ b: 1, a: 2, b: 3, a: 4 }"), "{a: 2, a: 4, b: 1, b: 3}"
    )


def test_sorts_in_natural_order() raises:
    # Numbers compare as numbers, and a number ends after a leading zero.
    assert_equal(
        sorted_value("{ a10: 1, a9: 2, a: 3, a1b: 4, a1a: 5, b: 6 }"),
        "{a: 3, a1a: 5, a1b: 4, a9: 2, a10: 1, b: 6}",
    )
    assert_equal(
        sorted_value("{ x01: 1, x1: 2, x00: 3, x0: 4 }"),
        "{x0: 4, x00: 3, x01: 1, x1: 2}",
    )
    assert_equal(sorted_value("{ a2: 1, a12: 2 }"), "{a2: 1, a12: 2}")
    # A digit compares as a character with a letter.
    assert_equal(sorted_value("{ a1: 1, ab: 2 }"), "{a1: 1, ab: 2}")
    # A prefix comes first.
    assert_equal(sorted_value("{ ab: 1, a: 2 }"), "{a: 2, ab: 1}")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
