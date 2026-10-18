# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the subgraph operation name.

The cases follow `OperationNameFactory` in Hive Router.
"""

from gql_router.operation_name import (
    ForwardKind,
    forward_all,
    forward_all_except,
    forward_none,
    forward_only,
    operation_forward,
    should_forward,
    subgraph_operation_name,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _names(first: String, second: String) -> List[String]:
    var names = List[String]()
    names.append(first)
    names.append(second)
    return names^


def test_the_client_name_is_forwarded_with_the_step_id() raises:
    var rule = forward_all()
    assert_equal(
        subgraph_operation_name(rule, True, "Example", "foo", 2), "Example__2"
    )
    assert_equal(
        subgraph_operation_name(rule, True, "Example", "foo-v2", 2),
        "Example__2",
    )
    assert_equal(
        subgraph_operation_name(rule, True, "Example", "foo service", 3),
        "Example__3",
    )
    assert_equal(
        subgraph_operation_name(rule, True, "Example", "123foo", 4),
        "Example__4",
    )
    assert_equal(subgraph_operation_name(rule, True, "", "foo", 2), "__2")
    assert_equal(subgraph_operation_name(rule, False, "Example", "foo", 2), "")


def test_only_the_listed_subgraphs_receive_the_name() raises:
    var names = List[String]()
    names.append("books")
    names.append("books")
    var rule = forward_only(names^)
    assert_true(should_forward(rule, "books"))
    assert_false(should_forward(rule, "users"))
    assert_equal(rule.kind.value, ForwardKind.ONLY.value)
    assert_equal(len(rule.subgraphs), 1)
    var empty = forward_only(List[String]())
    assert_equal(empty.kind.value, ForwardKind.NONE.value)
    assert_false(should_forward(forward_none(), "books"))


def test_all_except_drops_the_excluded_subgraphs() raises:
    var known = _names("books", "users")
    var open = forward_all_except(known, List[String]())
    assert_equal(open.kind.value, ForwardKind.ALL.value)
    var excluded = List[String]()
    excluded.append("books")
    var closed = forward_all_except(_names("books", "users"), excluded^)
    assert_true(should_forward(closed, "users"))
    assert_false(should_forward(closed, "books"))
    var both = _names("books", "users")
    var none = forward_all_except(_names("books", "users"), both^)
    assert_equal(none.kind.value, ForwardKind.NONE.value)


def test_the_all_rule_collects_disabled_subgraphs() raises:
    var known = _names("books", "users")
    var disabled = List[String]()
    disabled.append("books")
    var from_all = operation_forward(True, known^, List[String](), disabled^)
    assert_true(should_forward(from_all, "users"))
    assert_false(should_forward(from_all, "books"))
    var enabled = List[String]()
    enabled.append("reviews")
    var from_off = operation_forward(
        False, List[String](), enabled^, List[String]()
    )
    assert_true(should_forward(from_off, "reviews"))
    assert_false(should_forward(from_off, "books"))
    assert_true(ForwardKind.ALL.is_valid())
    assert_false(ForwardKind(3).is_valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
