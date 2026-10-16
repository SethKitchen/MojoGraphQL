# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_client.fuzzy`, the patterns of fuzzy `possibleTypes`.

The module has no upstream test file: upstream uses ECMAScript `RegExp`.
Each expectation is what `text.match(new RegExp(pattern))` and
`RegExp.test` give in JavaScript.
"""

from gql_client.fuzzy import (
    compile_pattern,
    is_name_byte,
    is_plain_name,
)
from std.testing import TestSuite, assert_false, assert_raises, assert_true


def _whole(pattern: StringSlice, text: StringSlice) raises -> Bool:
    """Return `text.match(new RegExp(pattern))?.[0] === text`."""
    return compile_pattern(pattern).first_match_is_whole(text)


def _test(pattern: StringSlice, text: StringSlice) raises -> Bool:
    """Return `new RegExp(pattern).test(text)`."""
    return compile_pattern(pattern).test(text)


def test_plain_names() raises:
    assert_true(is_plain_name("Book"))
    assert_true(is_plain_name("_a9"))
    assert_false(is_plain_name("9a"))
    assert_false(is_plain_name(""))
    assert_false(is_plain_name(".*Entity"))
    assert_false(is_plain_name("[E-Z]"))
    assert_true(is_name_byte(UInt8(ord("Z")), 0))
    assert_true(is_name_byte(UInt8(ord("5")), 1))
    assert_false(is_name_byte(UInt8(ord("5")), 0))
    assert_false(is_name_byte(UInt8(ord("-")), 3))


def test_first_match_must_be_the_whole_type_name() raises:
    assert_true(_whole(".*Entity", "UserEntity"))
    assert_true(_whole(".*Entity", "Entity"))
    assert_false(_whole(".*Entity", "EntityX"))
    assert_false(_whole(".*Entity", "User"))
    assert_true(_whole("[E-Z]", "E"))
    assert_false(_whole("[E-Z]", "TooLong"))
    assert_false(_whole("[E-Z]", "D"))
    assert_false(_whole("a*", "baa"))
    assert_true(_whole("a*", ""))
    assert_true(_whole("Ab?c+", "Acc"))
    assert_false(_whole("Ab?c+", "Ab"))
    assert_true(_whole("^A$", "A"))
    assert_false(_whole("^A$", "AA"))
    assert_false(_whole("A^", "A"))
    assert_true(_whole("[^0-9]x", "ax"))
    assert_false(_whole("[^0-9]x", "1x"))
    assert_true(_whole("a\\.b", "a.b"))
    assert_false(_whole("a\\.b", "axb"))
    assert_false(_whole(".", "\n"))
    assert_true(_whole("[a-]", "-"))


def test_test_matches_anywhere() raises:
    assert_true(_test("[E-Z]", "aE"))
    assert_false(_test("[E-Z]", "abc"))
    assert_true(_test("Entity$", "UserEntity"))
    assert_false(_test("^Entity", "UserEntity"))
    assert_true(_test("", "anything"))


def test_refuses_unsupported_syntax() raises:
    with assert_raises(contains="Unsupported possibleTypes pattern: (a)"):
        _ = compile_pattern("(a)")
    with assert_raises(contains="Unsupported possibleTypes pattern: a|b"):
        _ = compile_pattern("a|b")
    with assert_raises(contains="Unsupported possibleTypes pattern: a{2}"):
        _ = compile_pattern("a{2}")
    with assert_raises(contains="Unsupported possibleTypes pattern: *a"):
        _ = compile_pattern("*a")
    with assert_raises(contains="Unsupported possibleTypes pattern: a]"):
        _ = compile_pattern("a]")
    with assert_raises(contains="Unsupported possibleTypes pattern: a\\"):
        _ = compile_pattern("a\\")
    with assert_raises(contains="an unclosed class"):
        _ = compile_pattern("[ab")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
