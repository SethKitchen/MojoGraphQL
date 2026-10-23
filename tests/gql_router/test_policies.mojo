# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for collecting the `@policy` names an operation needs.

The walk follows `collect_required_policies` in Hive Router
`pipeline/authorization/mod.rs`.
"""

from gql_router.policies import (
    AuthVisit,
    PolicyBinding,
    collect_required_policies,
)
from std.testing import TestSuite, assert_equal


def _field(parent: String, field: String, output: String) -> AuthVisit:
    return AuthVisit(False, parent, field, output, String(""))


def _fragment(type_name: String) -> AuthVisit:
    return AuthVisit(True, String(""), String(""), String(""), type_name)


def _type_policy(type_name: String, policy: String) -> PolicyBinding:
    return PolicyBinding(type_name, String(""), policy)


def _field_policy(
    type_name: String, field_name: String, policy: String
) -> PolicyBinding:
    return PolicyBinding(type_name, field_name, policy)


def _joined(names: List[String]) -> String:
    var text = String("")
    for index in range(len(names)):
        if index > 0:
            text += " "
        text += names[index]
    return text


def test_policies_are_skipped_when_directives_are_off() raises:
    var off_visits = List[AuthVisit]()
    off_visits.append(_field("Query", "user", "User"))
    var off_bindings = List[PolicyBinding]()
    off_bindings.append(_type_policy("User", "internal"))
    var off = collect_required_policies(False, True, off_visits, off_bindings)
    var unused_visits = List[AuthVisit]()
    unused_visits.append(_field("Query", "user", "User"))
    var unused_bindings = List[PolicyBinding]()
    unused_bindings.append(_type_policy("User", "internal"))
    var unused = collect_required_policies(
        True, False, unused_visits, unused_bindings
    )
    assert_equal(len(off), 0)
    assert_equal(len(unused), 0)


def test_a_field_collects_parent_field_and_output_policies() raises:
    var visits = List[AuthVisit]()
    visits.append(_field("Query", "user", "User"))
    visits.append(_fragment("Admin"))
    var bindings = List[PolicyBinding]()
    bindings.append(_type_policy("Query", "public"))
    bindings.append(_field_policy("Query", "user", "read"))
    bindings.append(_type_policy("User", "internal"))
    bindings.append(_type_policy("User", "public"))
    bindings.append(_type_policy("Admin", "staff"))
    bindings.append(_type_policy("Other", "secret"))
    var required = collect_required_policies(True, True, visits, bindings)
    assert_equal(_joined(required), "public read internal staff")


def test_no_selections_or_no_bindings_collect_nothing() raises:
    var bindings = List[PolicyBinding]()
    bindings.append(_type_policy("Query", "public"))
    var empty = collect_required_policies(
        True, True, List[AuthVisit](), bindings
    )
    var visits = List[AuthVisit]()
    visits.append(_field("Query", "user", "User"))
    var unbound = collect_required_policies(
        True, True, visits, List[PolicyBinding]()
    )
    assert_equal(len(empty), 0)
    assert_equal(len(unbound), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
