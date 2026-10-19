# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `append_vary`.

The cases follow Hive Router `bin/router/src/http_utils/headers.rs`.
"""

from gql_router.headers import HeaderMap, append_vary
from std.testing import TestSuite, assert_equal, assert_false


def test_append_vary_adds_a_new_token() raises:
    var headers = HeaderMap()
    append_vary(headers, "Accept")
    assert_equal(headers.get("Vary").value(), "Accept")
    append_vary(headers, "Origin")
    assert_equal(headers.get("vary").value(), "Accept, Origin")


def test_append_vary_ignores_a_token_already_present() raises:
    var headers = HeaderMap()
    headers.insert("Vary", "Accept, Origin")
    append_vary(headers, "accept")
    append_vary(headers, "origin")
    assert_equal(headers.get("Vary").value(), "Accept, Origin")


def test_append_vary_replaces_an_empty_value() raises:
    var headers = HeaderMap()
    headers.insert("Vary", "")
    append_vary(headers, "Accept")
    assert_equal(headers.get("Vary").value(), "Accept")
    assert_false(headers.get("Accept"))


def test_append_vary_trims_items_and_keeps_other_headers() raises:
    var headers = HeaderMap()
    headers.insert("Content-Type", "application/json")
    headers.insert("Vary", "Accept-Encoding , , Origin")
    append_vary(headers, "accept-encoding")
    append_vary(headers, "Accept")
    assert_equal(
        headers.get("vary").value(), "Accept-Encoding , , Origin, Accept"
    )
    assert_equal(headers.get("content-type").value(), "application/json")


def test_append_vary_finds_an_empty_token_in_an_empty_value() raises:
    var headers = HeaderMap()
    headers.insert("Vary", "")
    append_vary(headers, "")
    assert_equal(headers.get("Vary").value(), "")


def test_header_map_operations() raises:
    var headers = HeaderMap()
    headers.append_value("Set-Cookie", "a=1")
    headers.append_value("set-cookie", "b=2")
    headers.insert("X-Id", "1")
    headers.insert("x-id", "2")
    var cookies = headers.values_of("SET-COOKIE")
    assert_equal(len(cookies), 2)
    assert_equal(cookies[1], "b=2")
    assert_equal(headers.get("X-ID").value(), "2")
    assert_equal(
        headers.joined(), "Set-Cookie: a=1 | set-cookie: b=2 | X-Id: 2"
    )
    headers.remove("set-cookie")
    assert_equal(headers.joined(), "X-Id: 2")


def test_an_empty_map() raises:
    var headers = HeaderMap()
    headers.remove("Vary")
    assert_equal(len(headers.values_of("Vary")), 0)
    assert_equal(headers.joined(), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
