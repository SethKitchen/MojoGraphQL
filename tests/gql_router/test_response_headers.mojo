# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for subgraph response header rules.

The cases follow `apply_subgraph_response_headers` in Hive Router.
"""

from gql_router.response_headers import (
    HeaderAggregateKind,
    ResponseAggregator,
    ResponseHeaderRule,
    apply_response_headers,
    response_header_denied,
)
from gql_router.headers import HeaderMap
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _names(name: String) -> List[String]:
    var names = List[String]()
    names.append(name)
    return names^


def _rule(
    kind: Int,
    subgraph: String,
    var names: List[String],
    value: String,
    has_value: Bool,
    strategy: HeaderAggregateKind,
) -> ResponseHeaderRule:
    return ResponseHeaderRule(
        UInt8(kind), subgraph, names^, value, has_value, "", False, strategy
    )


def test_content_type_stays_and_append_joins_values() raises:
    var rules = List[ResponseHeaderRule]()
    var names = List[String]()
    names.append("X-Cache")
    names.append("Content-Type")
    rules.append(_rule(0, "", names^, "", False, HeaderAggregateKind.APPEND))
    var books = HeaderMap()
    books.insert("X-Cache", "books")
    books.insert("Content-Type", "application/json")
    var aggregated = ResponseAggregator()
    apply_response_headers(rules, "books", books, aggregated)
    var users = HeaderMap()
    users.insert("X-Cache", "users")
    apply_response_headers(rules, "users", users, aggregated)
    assert_equal(aggregated.client_headers().joined(), "X-Cache: books, users")
    assert_true(response_header_denied("Content-Type"))
    assert_false(response_header_denied("X-Cache"))
    assert_true(HeaderAggregateKind.LAST.is_valid())
    assert_false(HeaderAggregateKind(3).is_valid())


def test_first_last_and_set_cookie_follow_their_strategy() raises:
    var first_rules = List[ResponseHeaderRule]()
    first_rules.append(
        _rule(0, "", _names("X-Cache"), "", False, HeaderAggregateKind.FIRST)
    )
    var aggregated = ResponseAggregator()
    var books = HeaderMap()
    books.insert("X-Cache", "books")
    apply_response_headers(first_rules, "books", books, aggregated)
    var later = List[ResponseHeaderRule]()
    later.append(
        _rule(0, "", _names("X-Cache"), "", False, HeaderAggregateKind.APPEND)
    )
    var users = HeaderMap()
    users.insert("X-Cache", "users")
    apply_response_headers(later, "users", users, aggregated)
    assert_equal(aggregated.client_headers().joined(), "X-Cache: books")
    var last = ResponseAggregator()
    var last_rules = List[ResponseHeaderRule]()
    last_rules.append(
        _rule(0, "", _names("X-Cache"), "", False, HeaderAggregateKind.LAST)
    )
    apply_response_headers(last_rules, "books", books, last)
    apply_response_headers(last_rules, "users", users, last)
    assert_equal(last.client_headers().joined(), "X-Cache: users")
    var cookies = ResponseAggregator()
    var cookie_rules = List[ResponseHeaderRule]()
    cookie_rules.append(
        _rule(
            1, "", _names("Set-Cookie"), "a=1", True, HeaderAggregateKind.FIRST
        )
    )
    cookie_rules.append(
        _rule(
            1,
            "books",
            _names("Set-Cookie"),
            "b=2",
            True,
            HeaderAggregateKind.FIRST,
        )
    )
    apply_response_headers(cookie_rules, "books", HeaderMap(), cookies)
    assert_equal(
        cookies.client_headers().joined(), "Set-Cookie: a=1 | Set-Cookie: b=2"
    )
    var removed = ResponseAggregator()
    var remove_rules = List[ResponseHeaderRule]()
    remove_rules.append(
        _rule(
            1, "", _names("X-From"), "router", True, HeaderAggregateKind.FIRST
        )
    )
    remove_rules.append(
        _rule(
            2, "books", _names("X-From"), "", False, HeaderAggregateKind.FIRST
        )
    )
    apply_response_headers(remove_rules, "books", HeaderMap(), removed)
    assert_equal(removed.client_headers().joined(), "")
    var kept = ResponseAggregator()
    apply_response_headers(remove_rules, "users", HeaderMap(), kept)
    assert_equal(kept.client_headers().joined(), "X-From: router")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
