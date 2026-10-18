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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
