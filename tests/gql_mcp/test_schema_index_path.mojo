# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `PathNode` and `ScoredPath` of `gql_mcp.schema_index`.

Ports of the tests of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-schema-index/src/path.rs`. A path here is a list, so the
upstream tests of `iter`, `iter_mut` and `into_iter` read the list.
"""

from gql_mcp.schema_index import PathNode, PathSegment, ScoredPath
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _no_args() -> List[String]:
    return List[String]()


def _three() -> PathNode:
    return (
        PathNode("Root")
        .add_child(String("child"), _no_args(), "Child")
        .add_child(String("grandchild"), _no_args(), "GrandChild")
    )


def test_add_child() raises:
    var path = PathNode("Root").add_child(String("child"), _no_args(), "Child")
    assert_equal(String(path), "Root -> child -> Child")


def test_add_parent() raises:
    var path = PathNode("Child").add_parent(String("child"), _no_args(), "Root")
    assert_equal(String(path), "Root -> child -> Child")


def test_len() raises:
    var path = PathNode("Root")
    assert_equal(len(path), 1)
    path = path.add_child(String("child"), _no_args(), "Child")
    assert_equal(len(path), 2)
    path = path.add_child(String("grandchild"), _no_args(), "GrandChild")
    assert_equal(len(path), 3)
    path = path.add_child(None, _no_args(), "GreatGrandChild")
    assert_equal(len(path), 4)


def test_display() raises:
    var args = List[String]()
    args.append("Arg1")
    args.append("Arg2")
    var path = (
        PathNode("Root")
        .add_child(String("child"), args^, "Child")
        .add_child(String("grandchild"), _no_args(), "GrandChild")
    )
    assert_equal(
        String(path),
        "Root -> child(Arg1,Arg2) -> Child -> grandchild -> GrandChild",
    )
    var member = PathNode("Union").add_child(None, _no_args(), "Member")
    assert_equal(String(member), "Union -> Member")


def test_has_cycle() raises:
    var path = PathNode("Root").add_child(String("child"), _no_args(), "Child")
    assert_false(path.has_cycle())
    path = path.add_child(String("back_to_root"), _no_args(), "Root")
    assert_true(path.has_cycle())
    assert_false(PathNode("Root").has_cycle())


def test_referencing_type() raises:
    assert_false(Bool(PathNode("Root").referencing_type()))
    var path = PathNode("Root").add_child(String("child"), _no_args(), "Child")
    var found = path.referencing_type().value().copy()
    assert_true(
        found == PathSegment(String("Root"), String("child"), _no_args())
    )
    path = path.add_child(String("grandchild"), _no_args(), "GrandChild")
    found = path.referencing_type().value().copy()
    assert_true(
        found == PathSegment(String("Child"), String("grandchild"), _no_args())
    )
    assert_false(
        found == PathSegment(String("Child"), String("other"), _no_args())
    )
    assert_false(
        found == PathSegment(String("X"), String("grandchild"), _no_args())
    )
    var args = List[String]()
    args.append("A")
    assert_false(
        found == PathSegment(String("Child"), String("grandchild"), args^)
    )


def test_iteration() raises:
    var path = PathNode("Root")
    assert_equal(len(path.segments), 1)
    assert_equal(path.segments[0].node_type, "Root")
    path = path.add_child(String("child"), _no_args(), "Child")
    assert_equal(len(path.segments), 2)
    assert_equal(path.segments[0].node_type, "Root")
    assert_equal(path.segments[1].node_type, "Child")
    assert_equal(path.segments[0].field_name.value(), "child")
    assert_false(Bool(path.segments[1].field_name))
    path = path.add_child(String("grandchild"), _no_args(), "GrandChild")
    assert_equal(len(path.segments), 3)
    assert_equal(path.segments[2].node_type, "GrandChild")
    assert_equal(path.segments[1].field_name.value(), "grandchild")
    assert_false(Bool(path.segments[2].field_name))


def test_iteration_mut() raises:
    var path = _three()
    assert_equal(len(path.segments), 3)
    for segment in path.segments:
        assert_true(segment.node_type.byte_length() > 0)


def test_into_iter() raises:
    var path = _three()
    assert_equal(path.segments[0].node_type, "Root")
    assert_equal(path.segments[1].node_type, "Child")
    assert_equal(path.segments[2].node_type, "GrandChild")


def test_iteration_with_into_iter() raises:
    var path = _three()
    assert_equal(len(path), 3)
    var two = PathNode("Root").add_child(String("child"), _no_args(), "Child")
    assert_equal(len(two), 2)


def test_iteration_empty_path() raises:
    var path = PathNode("Root")
    assert_equal(len(path), 1)
    assert_equal(path.segments[0].node_type, "Root")


def test_scored_display() raises:
    var scored = ScoredPath(PathNode("Root"), 1.5)
    assert_equal(String(scored), "Root (1.5)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
