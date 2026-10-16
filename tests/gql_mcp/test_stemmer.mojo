# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.stemmer`: the Snowball English stemmer of
rust-stemmers 1.2.0 `src/snowball/algorithms/english.rs`.

rust-stemmers has no test of its own for English. The expected stems come
from rust-stemmers 1.2.0 itself, run on the words of `_stem_vocab.mojo`.
"""

from gql_mcp.stemmer import stem_english
from std.testing import TestSuite, assert_equal

from _stem_vocab import VOCAB


def test_vocabulary() raises:
    var lines = String(VOCAB).split("\n")
    var checked = 0
    var wrong = String()
    var i = 0
    while i < len(lines):
        var parts = lines[i].split(" ")
        i += 1
        if len(parts) != 2:
            continue
        var stem = stem_english(String(parts[0]))
        if stem != parts[1]:
            wrong += String(parts[0]) + " -> " + stem + "\n"
        checked += 1
    assert_equal(wrong, "")
    assert_equal(checked, 3848)


def test_non_ascii() raises:
    assert_equal(stem_english("cafés"), "café")
    assert_equal(stem_english("naïvety"), "naïveti")
    assert_equal(stem_english("résumés"), "résumé")
    assert_equal(stem_english("überly"), "über")
    assert_equal(stem_english("ñandúes"), "ñandú")
    assert_equal(stem_english("ŷes"), "ŷes")
    assert_equal(stem_english("aéy"), "aéi")
    assert_equal(stem_english("éb"), "éb")
    assert_equal(stem_english("ébing"), "ébing")
    assert_equal(stem_english("日本語s"), "日本語s")
    assert_equal(stem_english("größte"), "größte")
    assert_equal(stem_english("\U0001F600s"), "\U0001F600s")


def test_rare_rules() raises:
    assert_equal(stem_english("nervousness"), "nervous")
    assert_equal(stem_english("decisiveness"), "decis")
    assert_equal(stem_english("callousness"), "callous")
    assert_equal(stem_english("activity"), "activ")
    assert_equal(stem_english("possibly"), "possibl")
    assert_equal(stem_english("probably"), "probabl")
    assert_equal(stem_english("pedagogy"), "pedagogi")
    assert_equal(stem_english("operationalism"), "oper")
    assert_equal(stem_english("sensationalism"), "sensat")
    assert_equal(stem_english("opinion"), "opinion")
    assert_equal(stem_english("champion"), "champion")
    assert_equal(stem_english("a\U0001F600s"), "a\U0001F600")


def test_apostrophes() raises:
    assert_equal(stem_english("s's"), "s")
    assert_equal(stem_english("ss's"), "ss")
    assert_equal(stem_english("'abc"), "abc")
    assert_equal(stem_english("dog's"), "dog")
    assert_equal(stem_english("dogs'"), "dog")
    assert_equal(stem_english("dog's'"), "dog")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
