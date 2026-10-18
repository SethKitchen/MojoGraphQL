# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.state`.

Upstream has no test file for `src/utils/auth.ts`. The expected groups of
`merge_scope_policies` come from upstream `mergeScopePolicies` in Node.js.
"""

from gql_composition.state import (
    ArgumentKind,
    ExtensionType,
    RootKind,
    TypeKind,
    merge_scope_policies,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _show(groups: List[List[String]]) -> String:
    var parts = List[String]()
    for ref group in groups:
        parts.append("[" + String(",").join(group) + "]")
    return "[" + String(" ").join(parts) + "]"


def _groups(text: String) -> List[List[String]]:
    var out = List[List[String]]()
    if text.byte_length() == 0:
        return out^
    for group in text.split("|"):
        var items = List[String]()
        for item in group.split(","):
            items.append(String(item))
        out.append(items^)
    return out^


def _check(
    left: List[List[String]], right: List[List[String]], expected: String
) raises:
    assert_equal(_show(merge_scope_policies(left, right)), expected)


def test_merge_scope_policies() raises:
    _check(_groups(""), _groups(""), "[]")
    _check(_groups("a"), _groups(""), "[[a]]")
    _check(_groups(""), _groups("b|a,c"), "[[b] [a,c]]")
    _check(_groups("a"), _groups("b"), "[[a,b]]")
    _check(_groups("a,b"), _groups("b,a"), "[[a,b]]")
    _check(_groups("b|a"), _groups("c|a"), "[[a] [b,c]]")
    _check(_groups("x,y|z"), _groups("y|z,w|q"), "[[q,z] [w,z] [x,y] [y,z]]")
    _check(_groups("a|a,b"), _groups("a"), "[[a]]")
    _check(_groups("c,d|b"), _groups("a|b,c"), "[[a,b] [b,c] [a,c,d]]")
    _check(_groups("a|b"), _groups("a|b"), "[[a] [b]]")
    _check(_groups("b,a"), _groups("c|a,b"), "[[a,b]]")
    _check(
        _groups("read:a,write:b"), _groups("read:a|admin"), "[[read:a,write:b]]"
    )


def test_kind_texts() raises:
    assert_equal(String(TypeKind.INPUT_OBJECT), "INPUT_OBJECT")
    assert_true(TypeKind(6).is_valid())
    assert_false(TypeKind(7).is_valid())
    assert_equal(String(TypeKind(7)), "<invalid>")
    assert_equal(String(ArgumentKind(0)), "SCALAR")
    assert_equal(String(ArgumentKind(1)), "OBJECT")
    assert_equal(String(ArgumentKind(2)), "ENUM")
    assert_equal(String(ArgumentKind(3)), "<invalid>")
    assert_true(ArgumentKind(2).is_valid())
    assert_false(ArgumentKind(3).is_valid())
    assert_equal(String(ExtensionType(0)), "")
    assert_equal(String(ExtensionType(1)), "@extends")
    assert_equal(String(ExtensionType(2)), "extend")
    assert_equal(String(ExtensionType(3)), "<invalid>")
    assert_true(ExtensionType(2).is_valid())
    assert_false(ExtensionType(3).is_valid())
    assert_equal(String(RootKind.QUERY), "Query")
    assert_equal(String(RootKind.MUTATION), "Mutation")
    assert_equal(String(RootKind.SUBSCRIPTION), "Subscription")
    assert_equal(String(RootKind(3)), "<invalid>")
    assert_true(RootKind(2).is_valid())
    assert_false(RootKind(3).is_valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
