# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.names`."""

from gql_forge.names import (
    ascii_lower,
    contains_folded,
    endpoint_error,
    fnv1a,
    hex16,
    is_http_endpoint,
    is_valid_endpoint_url,
    is_valid_slug,
    make_ingest_token,
    slug_error,
    sort_strings,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_slugs() raises:
    assert_true(is_valid_slug("acme"))
    assert_true(is_valid_slug("Shop_v2-eu"))
    assert_true(is_valid_slug("a"))
    assert_true(is_valid_slug("Z9"))
    assert_true(is_valid_slug("a" * 64))
    assert_false(is_valid_slug(""))
    assert_false(is_valid_slug("a" * 65))
    assert_false(is_valid_slug("9acme"))
    assert_false(is_valid_slug("_acme"))
    assert_false(is_valid_slug("ac me"))
    assert_false(is_valid_slug("ac.me"))
    assert_true(is_valid_slug("AZaz"))
    assert_false(is_valid_slug("@"))
    assert_false(is_valid_slug("["))
    assert_false(is_valid_slug("`"))
    assert_false(is_valid_slug("{"))
    assert_false(is_valid_slug("a:"))
    assert_false(is_valid_slug("a/"))
    assert_true(slug_error("graph", "9").startswith("Invalid graph name '9'"))


def test_endpoints() raises:
    assert_true(is_valid_endpoint_url("http://localhost:4000/graphql"))
    assert_true(is_valid_endpoint_url("https://graph.example/g"))
    assert_true(is_valid_endpoint_url("http://a"))
    assert_true(is_valid_endpoint_url("https://a"))
    assert_false(is_valid_endpoint_url("http://"))
    assert_false(is_valid_endpoint_url("https://"))
    assert_false(is_valid_endpoint_url("ftp://x"))
    assert_false(is_valid_endpoint_url("localhost"))
    assert_true(is_http_endpoint("http://10.0.0.5:4000/"))
    assert_false(is_http_endpoint("https://10.0.0.5:4000/"))
    assert_false(is_http_endpoint("http://"))
    assert_true(endpoint_error("ftp://x").find("http://") >= 0)


def test_folding() raises:
    assert_equal(ascii_lower("AbC-12"), "abc-12")
    assert_equal(ascii_lower(""), "")
    assert_true(contains_folded("What broke Between staging", "between"))
    assert_false(contains_folded("latency", "error"))
    assert_false(contains_folded("hello", ""))


def test_hash_and_sort() raises:
    assert_equal(hex16(0), "0000000000000000")
    assert_equal(hex16(0xFFFFFFFFFFFFFFFF), "ffffffffffffffff")
    assert_equal(hex16(0x10), "0000000000000010")
    var token = make_ingest_token("acme", "shop", "prod", 1)
    assert_true(token.startswith("frg_"))
    assert_equal(token.byte_length(), 4 + 32)
    assert_equal(token, make_ingest_token("acme", "shop", "prod", 1))
    assert_true(token != make_ingest_token("acme", "shop", "prod", 2))
    _ = fnv1a("", 0)
    var names = List[String]()
    names.append("shop")
    names.append("acme")
    names.append("shop")
    names.append("a")
    names.append("ab")
    sort_strings(names)
    assert_equal(names[0], "a")
    assert_equal(names[1], "ab")
    assert_equal(names[2], "acme")
    var empty = List[String]()
    sort_strings(empty)
    assert_equal(len(empty), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
