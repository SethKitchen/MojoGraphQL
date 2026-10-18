# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for null bubbling of a removed non-null field.

The cases follow `visit_field` in Hive Router `operation_filter.rs`.
"""

from gql_router.null_bubble import BubbleNode, bubble_null_removals
from std.testing import TestSuite, assert_equal


def _node(
    name: String, parent: Int, non_null: Bool, denied: Bool
) -> BubbleNode:
    return BubbleNode(name, parent, non_null, denied)


def _joined(names: List[String]) -> String:
    var text = String("")
    for index in range(len(names)):
        if index > 0:
            text += " "
        text += names[index]
    return text


def test_a_nullable_denial_does_not_remove_its_parent() raises:
    var nodes = List[BubbleNode]()
    nodes.append(_node("user", -1, False, False))
    nodes.append(_node("nickname", 0, False, True))
    nodes.append(_node("name", 0, False, False))
    assert_equal(_joined(bubble_null_removals(nodes^)), "nickname")


def test_a_non_null_denial_stops_at_the_nullable_ancestor() raises:
    var nodes = List[BubbleNode]()
    nodes.append(_node("viewer", -1, False, False))
    nodes.append(_node("user", 0, False, False))
    nodes.append(_node("profile", 1, True, False))
    nodes.append(_node("email", 2, True, True))
    nodes.append(_node("name", 1, False, False))
    var removed = bubble_null_removals(nodes^)
    assert_equal(_joined(removed), "user profile email")


def test_typename_and_a_non_null_root_follow_the_filter() raises:
    var skipped = List[BubbleNode]()
    skipped.append(_node("user", -1, False, False))
    skipped.append(_node("__typename", 0, True, True))
    assert_equal(len(bubble_null_removals(skipped^)), 0)
    var root = List[BubbleNode]()
    root.append(_node("id", -1, True, True))
    root.append(_node("name", -1, False, False))
    assert_equal(_joined(bubble_null_removals(root^)), "id")


def test_an_empty_selection_removes_nothing() raises:
    assert_equal(len(bubble_null_removals(List[BubbleNode]())), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
