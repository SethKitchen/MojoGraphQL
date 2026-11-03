# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of gql_http.auth. There is no upstream suite."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_http.auth import bearer_matches, bearer_token, tokens_equal


def test_tokens_equal() raises:
    assert_true(tokens_equal("frg_abc", "frg_abc"))
    assert_true(tokens_equal("", ""))
    assert_false(tokens_equal("frg_abd", "frg_abc"))
    assert_false(tokens_equal("grg_abc", "frg_abc"))
    assert_false(tokens_equal("frg_ab", "frg_abc"))
    assert_false(tokens_equal("frg_abcd", "frg_abc"))
    assert_false(tokens_equal("", "frg_abc"))


def test_bearer_matches() raises:
    assert_true(bearer_matches(Optional[String]("Bearer s3cret"), "s3cret"))
    assert_false(bearer_matches(None, "s3cret"))
    assert_false(bearer_matches(Optional[String]("Basic s3cret"), "s3cret"))
    assert_false(bearer_matches(Optional[String]("Bearer s3cre"), "s3cret"))
    assert_false(bearer_matches(Optional[String]("Bearer "), "s3cret"))
    assert_true(bearer_matches(Optional[String]("bearer s3cret"), "s3cret"))
    assert_false(bearer_matches(Optional[String]("Bear"), "s3cret"))


def test_bearer_token() raises:
    assert_false(bearer_token(None))
    assert_equal(bearer_token(Optional[String]("Bearer abc")).value(), "abc")
    assert_equal(bearer_token(Optional[String]("BEARER abc")).value(), "abc")
    assert_equal(bearer_token(Optional[String]("Bearer ")).value(), "")
    assert_false(bearer_token(Optional[String]("Basic abc")))
    assert_false(bearer_token(Optional[String]("Bear")))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
