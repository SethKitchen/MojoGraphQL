# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the best combination of leaf paths.

Hive Router `1a29df9` `bin/router/src/query_planner/planner/best.rs` has no
unit tests. The query plan tests in `test_plan_*.mojo` cover the search;
these tests cover the candidate order and the errors.
"""

from gql_router.ast import NONE, Cond
from gql_router.best import _sort_by_cost, find_best_combination
from gql_router.federation_spec import OperationKind
from gql_router.graph import Graph
from gql_router.query_tree import OperationPath, PlanSpace, TreeNode
from gql_router.walker import ResolvedOperation
from std.testing import TestSuite, assert_equal, assert_raises


def _tree(mut space: PlanSpace, cost: Int) -> Int:
    """Add a lone tree node with a cost."""
    space.trees.append(
        TreeNode(
            0,
            NONE,
            List[Int](),
            List[Int](),
            False,
            NONE,
            NONE,
            Cond.none(),
            NONE,
            cost,
        )
    )
    return len(space.trees) - 1


def test_candidates_sort_by_cost_and_keep_equal_costs_in_order() raises:
    var space = PlanSpace()
    var five = _tree(space, 5)
    var three = _tree(space, 3)
    var four = _tree(space, 4)
    var other_four = _tree(space, 4)
    var trees: List[Int] = [five, three, four, other_four]
    _sort_by_cost(space, trees)
    assert_equal(trees, [three, four, other_four, five])


def test_no_leaf_fails() raises:
    var space = PlanSpace()
    var graph = Graph()
    with assert_raises(contains="Failed to build a plan"):
        _ = find_best_combination(
            space,
            graph,
            ResolvedOperation(
                OperationKind.QUERY, List[List[List[OperationPath]]]()
            ),
        )


def test_a_root_field_without_leaves_fails() raises:
    var space = PlanSpace()
    var graph = Graph()
    var groups = List[List[List[OperationPath]]]()
    groups.append(List[List[OperationPath]]())
    with assert_raises(contains="Failed to build a plan"):
        _ = find_best_combination(
            space, graph, ResolvedOperation(OperationKind.MUTATION, groups^)
        )


def test_a_leaf_without_paths_fails() raises:
    var space = PlanSpace()
    var graph = Graph()
    var leaves = List[List[OperationPath]]()
    leaves.append(List[OperationPath]())
    var groups = List[List[List[OperationPath]]]()
    groups.append(leaves^)
    with assert_raises(contains="Failed to build a plan"):
        _ = find_best_combination(
            space, graph, ResolvedOperation(OperationKind.QUERY, groups^)
        )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
