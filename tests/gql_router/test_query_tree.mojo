# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for operation paths and query trees.

Upstream `walker/path.rs` and `tree/query_tree_node.rs` have no unit tests;
these tests check the cases that the plan tests do not reach: empty paths,
paths that diverge, and trees with no children.
"""

from _fixtures import shared_root
from gql_router.ast import NONE, Cond
from gql_router.graph import EdgeKind
from gql_router.planner import Planner
from gql_router.query_tree import (
    OperationPath,
    PathSegment,
    PlanSpace,
    TreeNode,
    UnionContext,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _segment(prev: Int, edge: Int, tail: Int, cost: Int) -> PathSegment:
    return PathSegment(
        prev, edge, tail, cost, NONE, False, NONE, NONE, Cond.none()
    )


def _leaf(node: Int, edge: Int) -> TreeNode:
    return TreeNode(
        node,
        edge,
        List[Int](),
        List[Int](),
        False,
        NONE,
        NONE,
        Cond.none(),
        NONE,
        0,
    )


def test_union_context_resolves_only_its_members() raises:
    var context = UnionContext(0, 0, 0, 0, [1, 2])
    assert_true(context.can_resolve_member(2))
    assert_false(context.can_resolve_member(3))
    assert_false(UnionContext(0, 0, 0, 0, List[Int]()).can_resolve_member(1))
    var space = PlanSpace()
    space.unions.append(context^)
    assert_true(
        space.can_resolve_union_member(OperationPath(0, NONE, 0, NONE), 9)
    )
    assert_false(
        space.can_resolve_union_member(OperationPath(0, NONE, 0, 0), 9)
    )


def test_path_text_of_an_empty_and_a_longer_path() raises:
    var planner = Planner(shared_root.sdl())
    var entry = NONE
    var index = 0
    while index < len(planner.graph.edges):
        if planner.graph.edges[index].kind == EdgeKind.SUBGRAPH_ENTRYPOINT:
            entry = index
            break
        index += 1
    var field = NONE
    index = 0
    while index < len(planner.graph.edges):
        if (
            planner.graph.edges[index].kind == EdgeKind.FIELD_MOVE
            and planner.graph.edges[index].head
            == planner.graph.edges[entry].tail
        ):
            field = index
            break
        index += 1
    var space = PlanSpace()
    var root = planner.graph.edges[entry].head
    var empty = OperationPath(root, NONE, 0, NONE)
    assert_equal(
        space.path_text(planner.graph, planner.store, empty),
        planner.graph.node_name(planner.store, root),
    )
    var path = space.new_entrypoint(planner.graph, planner.store, entry)
    var one = space.path_text(planner.graph, planner.store, path)
    var longer = space.advance(
        planner.graph, planner.store, path, field, NONE, NONE, Cond.none()
    )
    var two = space.path_text(planner.graph, planner.store, longer)
    assert_true(two.startswith(one + " "))
    assert_equal(space.tail(empty), root)


def test_requirement_continuation_of_an_empty_source() raises:
    var space = PlanSpace()
    space.segments.append(_segment(NONE, 5, 50, 3))
    space.segments.append(_segment(0, 6, 60, 4))
    var target = OperationPath(1, 1, 4, NONE)
    var result = space.requirement_continuation(
        OperationPath(1, NONE, 0, NONE), target
    )
    assert_equal(result.root_node, 1)
    assert_equal(result.cost, 4)
    assert_equal(len(space.edges_of(result)), 2)


def test_requirement_continuation_after_a_divergence() raises:
    var space = PlanSpace()
    space.segments.append(_segment(NONE, 5, 50, 3))
    space.segments.append(_segment(0, 6, 60, 4))
    space.segments.append(_segment(0, 7, 70, 10))
    var source = OperationPath(1, 1, 4, NONE)
    var target = OperationPath(1, 2, 10, 3)
    var result = space.requirement_continuation(source, target)
    assert_equal(result.root_node, 50)
    assert_equal(result.cost, 7)
    assert_equal(result.union_context, 3)
    var edges = space.edges_of(result)
    assert_equal(len(edges), 1)
    assert_equal(edges[0], 7)


def test_requirement_continuation_of_a_prefix() raises:
    var space = PlanSpace()
    space.segments.append(_segment(NONE, 5, 50, 3))
    space.segments.append(_segment(0, 6, 60, 4))
    var source = OperationPath(1, 1, 4, NONE)
    var target = OperationPath(1, 0, 3, NONE)
    var result = space.requirement_continuation(source, target)
    assert_equal(result.root_node, 50)
    assert_equal(result.last_segment, NONE)
    assert_equal(result.cost, 0)


def test_trees_without_children_and_merges() raises:
    var planner = Planner(shared_root.sdl())
    var space = PlanSpace()
    assert_equal(
        space.tree_from_paths(planner.graph, List[OperationPath](), NONE), NONE
    )
    # An empty path makes a root with no children.
    var root = space.tree_from_path(
        planner.graph, OperationPath(0, NONE, 0, NONE), NONE
    )
    assert_equal(len(space.trees[root].children), 0)
    assert_equal(space.trees[root].cost, 1)
    # A child with no parent edge adds no cross-subgraph cost.
    var parent = _leaf(0, NONE)
    parent.children.append(root)
    var with_child = space.add_tree(planner.graph, parent^)
    assert_equal(space.trees[with_child].cost, 2)
    # A source with requirements and no children still merges.
    var requirement = space.add_tree(planner.graph, _leaf(1, NONE))
    var source = _leaf(0, NONE)
    source.requirements.append(requirement)
    var source_id = space.add_tree(planner.graph, source^)
    var merged = space.merge(planner.graph, with_child, source_id)
    assert_equal(len(space.trees[merged].children), 1)
    assert_equal(len(space.trees[merged].requirements), 1)
    # A source with nothing returns the target.
    var nothing = space.add_tree(planner.graph, _leaf(0, NONE))
    assert_equal(space.merge(planner.graph, merged, nothing), merged)
    # Equal children merge into one.
    var again = space.merge(planner.graph, with_child, with_child)
    assert_equal(len(space.trees[again].children), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
