# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for router authorization rules.

The cases follow `is_rule_satisfied` in Hive Router
`pipeline/authorization/mod.rs`. Scopes and policies are an OR of AND
groups.
"""

from gql_router.authorization import (
    AuthRule,
    UserAuth,
    authorization_allows,
    element_authorized,
)
from std.testing import TestSuite, assert_false, assert_true


def _group(left: String, right: String) -> List[String]:
    var names = List[String]()
    if left.byte_length() > 0:
        names.append(left)
    if right.byte_length() > 0:
        names.append(right)
    return names^


def _one(name: String) -> List[String]:
    return _group(name, "")


def _user(
    authenticated: Bool, var scopes: List[String], var policies: List[String]
) -> UserAuth:
    return UserAuth(authenticated, scopes^, policies^)


def test_jwt_rules_apply_only_when_enforced() raises:
    var scopes = List[List[String]]()
    var policies = List[List[String]]()
    var rule = AuthRule(True, False, scopes^, False, policies^)
    var anonymous = _user(False, List[String](), List[String]())
    var signed = _user(True, List[String](), List[String]())
    assert_false(authorization_allows(rule.copy(), anonymous^, True))
    assert_true(authorization_allows(rule.copy(), signed^, True))
    assert_true(
        authorization_allows(
            rule^, _user(False, List[String](), List[String]()), False
        )
    )


def test_one_scope_group_must_match_entirely() raises:
    var scopes = List[List[String]]()
    scopes.append(_group("read", "write"))
    scopes.append(_one("admin"))
    var policies = List[List[String]]()
    var rule = AuthRule(False, True, scopes^, False, policies^)
    assert_true(
        authorization_allows(
            rule.copy(), _user(False, _one("admin"), List[String]()), True
        )
    )
    assert_true(
        authorization_allows(
            rule.copy(),
            _user(False, _group("read", "write"), List[String]()),
            True,
        )
    )
    assert_false(
        authorization_allows(
            rule.copy(), _user(False, _one("read"), List[String]()), True
        )
    )
    assert_true(
        authorization_allows(
            rule^, _user(False, _one("read"), List[String]()), False
        )
    )


def test_policies_apply_even_when_jwt_is_off() raises:
    var scopes = List[List[String]]()
    var policies = List[List[String]]()
    policies.append(_one("internal"))
    var rule = AuthRule(False, False, scopes^, True, policies^)
    assert_false(
        authorization_allows(
            rule.copy(), _user(True, List[String](), List[String]()), False
        )
    )
    assert_true(
        authorization_allows(
            rule^, _user(True, List[String](), _one("internal")), False
        )
    )


def test_no_groups_do_not_match_and_an_empty_group_matches() raises:
    var no_groups = AuthRule(
        False, True, List[List[String]](), False, List[List[String]]()
    )
    assert_false(
        authorization_allows(
            no_groups^, _user(False, _one("read"), List[String]()), True
        )
    )
    var empty = List[List[String]]()
    empty.append(List[String]())
    var empty_group = AuthRule(False, True, empty^, False, List[List[String]]())
    assert_true(
        authorization_allows(
            empty_group^, _user(False, List[String](), List[String]()), True
        )
    )


def test_an_element_without_a_rule_is_allowed() raises:
    var scopes = List[List[String]]()
    var policies = List[List[String]]()
    var rule = AuthRule(True, False, scopes^, False, policies^)
    var user = _user(False, List[String](), List[String]())
    assert_true(element_authorized(False, rule.copy(), user.copy(), True))
    assert_false(element_authorized(True, rule^, user^, True))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
