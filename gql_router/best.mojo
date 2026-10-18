# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The cheapest combination of leaf paths.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/planner/best.rs`.

`find_best_combination` picks one path per leaf so that the merged query
tree costs the least. The leaves with the fewest candidates come first,
and the candidates of a leaf are sorted by cost. A greedy pass then picks,
leaf by leaf, the candidate that adds the least cost.

**Differences from upstream.** Upstream builds each candidate's tree on
first use. This port builds them all at once, because the first step,
the lowest cost per leaf, needs every one of them anyway.

After the greedy pass, upstream runs a branch and bound search. Its bound
for the whole search is the sum of the cheapest tree of each leaf. Merging
two trees never costs more than the two trees apart, so the greedy plan
never costs more than that bound, and the search always stops at its root.
This port leaves the search out; the plan is the same.
"""

from gql_router.ast import NONE
from gql_router.federation_spec import OperationKind
from gql_router.graph import Graph
from gql_router.query_tree import PlanSpace
from gql_router.walker import ResolvedOperation


def _sort_by_len(mut groups: List[List[Int]]):
    """Sort groups by length, keeping equal lengths in order."""
    for index in range(1, len(groups)):
        var at = index
        while at > 0 and len(groups[at - 1]) > len(groups[at]):
            groups.swap_elements(at - 1, at)
            at -= 1


def _sort_by_cost(space: PlanSpace, mut trees: List[Int]):
    """Sort trees by cost, keeping equal costs in order."""
    for index in range(1, len(trees)):
        var at = index
        while (
            at > 0
            and space.trees[trees[at - 1]].cost > space.trees[trees[at]].cost
        ):
            trees.swap_elements(at - 1, at)
            at -= 1


def find_best_combination(
    mut space: PlanSpace, graph: Graph, operation: ResolvedOperation
) raises -> Int:
    """Return the cheapest query tree, as upstream `find_best_combination`.

    Args:
        space: The plan space with the paths.
        graph: The graph.
        operation: The best paths of each leaf.

    Returns:
        The root tree node.

    Raises:
        Error: When there is no leaf, or a leaf has no path.
    """
    if len(operation.root_field_groups) == 0:
        raise Error("Failed to build a plan")
    var is_mutation = operation.operation_kind == OperationKind.MUTATION
    var groups = List[List[Int]]()
    var index = 0
    while index < len(operation.root_field_groups):
        var position = index if is_mutation else NONE
        for ref paths in operation.root_field_groups[index]:
            if len(paths) == 0:
                raise Error("Failed to build a plan")
            var trees = List[Int]()
            var at = 0
            while at < len(paths):
                trees.append(space.tree_from_path(graph, paths[at], position))
                at += 1
            _sort_by_cost(space, trees)
            groups.append(trees^)
        index += 1
    if len(groups) == 0:
        raise Error("Failed to build a plan")
    _sort_by_len(groups)
    return _find_initial_plan(space, graph, groups)


def _merged(
    mut space: PlanSpace, graph: Graph, tree_so_far: Int, candidate: Int
) -> Int:
    """Merge a candidate into the tree so far."""
    if tree_so_far == NONE:
        return candidate
    return space.merge(graph, tree_so_far, candidate)


def _find_initial_plan(
    mut space: PlanSpace, graph: Graph, groups: List[List[Int]]
) -> Int:
    """Pick the candidate that adds the least cost, leaf by leaf, as
    upstream `find_initial_plan`. Every group has a candidate."""
    var current = NONE
    var current_cost = 0
    var group = 0
    while group < len(groups):
        var best_delta = Int.MAX
        var best_next = NONE
        var at = 0
        while at < len(groups[group]):
            var next_tree = _merged(space, graph, current, groups[group][at])
            var next_cost = space.trees[next_tree].cost
            var delta = max(next_cost - current_cost, 0)
            if delta < best_delta:
                best_delta = delta
                best_next = next_tree
            at += 1
        current = best_next
        current_cost = space.trees[best_next].cost
        group += 1
    return current
