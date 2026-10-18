# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for subgraph request header rules.

The cases follow `modify_subgraph_request_headers` in Hive Router.
"""

from gql_router.header_rules import (
    HeaderRule,
    HeaderRuleKind,
    apply_request_headers,
    header_denied,
)
from gql_router.headers import HeaderMap
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _names(name: String) -> List[String]:
    var names = List[String]()
    names.append(name)
    return names^


def _rule(
    kind: HeaderRuleKind,
    subgraph: String,
    var names: List[String],
    value: String,
    has_value: Bool,
    rename: String,
    has_rename: Bool,
) -> HeaderRule:
    return HeaderRule(
        kind, subgraph, names^, value, has_value, rename, has_rename
    )


def test_named_headers_propagate_and_hop_by_hop_headers_stay() raises:
    var client = HeaderMap()
    client.insert("Authorization", "Bearer a")
    client.insert("Connection", "close")
    var rules = List[HeaderRule]()
    var names = List[String]()
    names.append("Authorization")
    names.append("Connection")
    rules.append(
        _rule(HeaderRuleKind.PROPAGATE, "", names^, "", False, "", False)
    )
    var output = HeaderMap()
    apply_request_headers(rules^, "books", client, output)
    assert_equal(output.joined(), "Authorization: Bearer a")
    assert_true(header_denied("Host"))
    assert_false(header_denied("Authorization"))
    assert_true(HeaderRuleKind.REMOVE.is_valid())
    assert_false(HeaderRuleKind(3).is_valid())


def test_a_default_a_rename_and_a_subgraph_remove_apply_in_order() raises:
    var client = HeaderMap()
    client.insert("X-User", "ada")
    var rules = List[HeaderRule]()
    rules.append(
        _rule(
            HeaderRuleKind.PROPAGATE,
            "",
            _names("X-Missing"),
            "guest",
            True,
            "X-Who",
            True,
        )
    )
    rules.append(
        _rule(
            HeaderRuleKind.PROPAGATE,
            "",
            _names("X-User"),
            "",
            False,
            "X-Who",
            True,
        )
    )
    rules.append(
        _rule(
            HeaderRuleKind.INSERT,
            "",
            _names("X-From"),
            "router",
            True,
            "",
            False,
        )
    )
    rules.append(
        _rule(
            HeaderRuleKind.INSERT,
            "",
            _names("Set-Cookie"),
            "a=1",
            True,
            "",
            False,
        )
    )
    rules.append(
        _rule(
            HeaderRuleKind.INSERT,
            "",
            _names("Set-Cookie"),
            "b=2",
            True,
            "",
            False,
        )
    )
    rules.append(
        _rule(
            HeaderRuleKind.REMOVE,
            "books",
            _names("X-From"),
            "",
            False,
            "",
            False,
        )
    )
    var output = HeaderMap()
    apply_request_headers(rules^, "books", client, output)
    assert_equal(
        output.joined(),
        "X-Who: guest | X-Who: ada | Set-Cookie: a=1 | Set-Cookie: b=2",
    )
    var users = HeaderMap()
    var again = List[HeaderRule]()
    again.append(
        _rule(
            HeaderRuleKind.INSERT,
            "",
            _names("X-From"),
            "router",
            True,
            "",
            False,
        )
    )
    again.append(
        _rule(
            HeaderRuleKind.REMOVE,
            "books",
            _names("X-From"),
            "",
            False,
            "",
            False,
        )
    )
    apply_request_headers(again^, "users", client, users)
    assert_equal(users.joined(), "X-From: router")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
