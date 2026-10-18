# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fetch graph optimizer passes that merge and prune steps.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/optimize/`:
`merge_passthrough_child.rs`, `merge_children_with_parents.rs`,
`merge_siblings.rs`, `merge_leafs.rs`,
`deduplicate_and_prune_fetch_steps.rs` and
`turn_mutations_into_sequence.rs`.

The passes visit steps in upstream order: breadth first from the root,
with the edges of a step newest first, and the steps in index order.

**Differences from upstream.** `turn_mutations_into_sequence` collects the
last steps of a group in a `HashSet`, whose order is random. This port
takes them in index order. The order changes only the incoming edge order
of the next group's steps, and no pass depends on that order.
"""

from gql_router.ast import NONE
from gql_router.federation_spec import OperationKind
from gql_router.fetch_optimize_utils import (
    MergedSteps,
    can_merge,
    check_pair,
    has_arguments_conflicts_with,
    is_reachable_via_alternative_upstream_path,
    perform_fetch_step_merge,
    require_step,
    root_index_of,
)
from gql_router.fetch_step import FetchGraph, FetchStepFlags
from gql_router.selection_set import items_are_subset_of
from gql_router.store import Store


# --- merge_passthrough_child ------------------------------------------------


def can_merge_passthrough_child(
    store: Store, fetch_graph: FetchGraph, self_index: Int, other_index: Int
) raises -> Bool:
    """Return True if a child only passes its input through, as upstream
    `can_merge_passthrough_child`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.
        self_index: The parent step.
        other_index: The child step.

    Returns:
        Whether the child has one parent, `self_index`, and its input holds
        what it fetches for every type.

    Raises:
        Error: When a step is missing.
    """
    if self_index == other_index:
        return False
    ref other = fetch_graph.step(other_index)
    if other.flags.contains(FetchStepFlags.USED_FOR_TYPE_CONDITION):
        return False
    var parents = fetch_graph.parent_steps(other_index)
    if len(parents) != 1:
        return False
    if parents[0] != self_index:
        return False
    var index = 0
    while index < len(other.output.types):
        var input_set = other.input.selections_for_definition(
            other.output.types[index]
        )
        if input_set == NONE:
            return False
        if not items_are_subset_of(store, input_set, other.output.sets[index]):
            return False
        index += 1
    return True


def _move_edges_and_remove(
    mut fetch_graph: FetchGraph, self_index: Int, other_index: Int
):
    """Give a step's children and parents to another step, and remove it."""
    var children = fetch_graph.child_steps(other_index)
    var parents = List[Int]()
    var other_parents = fetch_graph.parent_steps(other_index)
    var at = 0
    while at < len(other_parents):
        if other_parents[at] != self_index:
            parents.append(other_parents[at])
        at += 1
    for child in children:
        _ = fetch_graph.connect(self_index, child)
    for parent in parents:
        _ = fetch_graph.connect(parent, self_index)
    _ = fetch_graph.remove_step(other_index)


def perform_passthrough_child_merge(
    mut store: Store,
    self_index: Int,
    other_index: Int,
    mut fetch_graph: FetchGraph,
) raises:
    """Squash a passthrough child into its parent, as upstream
    `perform_passthrough_child_merge`.

    Args:
        store: The store.
        self_index: The parent step.
        other_index: The child step.
        fetch_graph: The fetch graph.

    Raises:
        Error: When a step is missing, or the path is not in the parent.
    """
    check_pair(fetch_graph, self_index, other_index)
    var me = fetch_graph.steps[self_index].copy()
    ref other = fetch_graph.steps[other_index]
    var path = other.response_path.slice_from(len(me.response_path))
    me.output.migrate_from_another(store, other.output, path)
    fetch_graph.steps[self_index] = me^
    _move_edges_and_remove(fetch_graph, self_index, other_index)


def merge_passthrough_child(
    mut store: Store, mut fetch_graph: FetchGraph
) raises:
    """Squash every child whose input is its output into its parent, as
    upstream `merge_passthrough_child`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.

    Raises:
        Error: When there is no root, a step is missing, or a merge fails.
    """
    var root_index = root_index_of(fetch_graph)
    var queue: List[Int] = [root_index]
    var head = 0
    var merged_steps = MergedSteps()
    while head < len(queue):
        var parent_index = merged_steps.resolve(queue[head])
        head += 1
        var merges = List[Tuple[Int, Int]]()
        var children = fetch_graph.child_steps(parent_index)
        require_step(fetch_graph, parent_index)
        for child_index in children:
            queue.append(child_index)
            require_step(fetch_graph, child_index)
            if can_merge_passthrough_child(
                store, fetch_graph, parent_index, child_index
            ):
                merges.append((parent_index, child_index))
        # Upstream checks each pair again before it merges. Every pair has
        # this parent, each child once, and a merge changes neither the
        # parents nor the selections of the other children, so the check
        # always holds.
        for pair in merges:
            var parent = merged_steps.resolve(pair[0])
            var child = merged_steps.resolve(pair[1])
            require_step(fetch_graph, parent)
            require_step(fetch_graph, child)
            perform_passthrough_child_merge(store, parent, child, fetch_graph)
            merged_steps.record(child, parent)


# --- merge_children_with_parents --------------------------------------------


def merge_children_with_parents(
    mut store: Store, mut fetch_graph: FetchGraph
) raises:
    """Merge each child that can go into its parent, as upstream
    `merge_children_with_parents`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.

    Raises:
        Error: When there is no root, a step is missing, or a merge fails.
    """
    var root_index = root_index_of(fetch_graph)
    var queue: List[Int] = [root_index]
    var head = 0
    var merged_steps = MergedSteps()
    while head < len(queue):
        var parent_index = merged_steps.resolve(queue[head])
        head += 1
        var merges = List[Tuple[Int, Int]]()
        var children = fetch_graph.child_steps(parent_index)
        require_step(fetch_graph, parent_index)
        for child_index in children:
            queue.append(child_index)
            require_step(fetch_graph, child_index)
            if can_merge(store, fetch_graph, parent_index, child_index):
                merges.append((parent_index, child_index))
        # Every pair has this parent and each child once, so a pair never
        # resolves to one step, as upstream checks. A merge can still make
        # the next child conflict with the parent, so that check stays.
        for pair in merges:
            var parent = merged_steps.resolve(pair[0])
            var child = merged_steps.resolve(pair[1])
            require_step(fetch_graph, parent)
            require_step(fetch_graph, child)
            if not can_merge(store, fetch_graph, parent, child):
                continue
            perform_fetch_step_merge(store, parent, child, fetch_graph, False)
            merged_steps.record(child, parent)


# --- merge_siblings ---------------------------------------------------------


def can_merge_siblings(
    store: Store, fetch_graph: FetchGraph, self_index: Int, other_index: Int
) raises -> Bool:
    """Return True if two siblings can merge, as upstream
    `can_merge_siblings`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.
        self_index: The step that would stay.
        other_index: The step that would go.

    Returns:
        Whether `can_merge` holds and neither step depends on the other.

    Raises:
        Error: When a step is missing.
    """
    var can_merge_base = can_merge(store, fetch_graph, self_index, other_index)
    if fetch_graph.is_ancestor_or_descendant(self_index, other_index):
        return False
    return can_merge_base


def merge_siblings(mut store: Store, mut fetch_graph: FetchGraph) raises:
    """Merge the children of a step that can share one fetch, as upstream
    `merge_siblings`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.

    Raises:
        Error: When there is no root, a step is missing, or a merge fails.
    """
    var root_index = root_index_of(fetch_graph)
    var queue: List[Int] = [root_index]
    var head = 0
    var merged_steps = MergedSteps()
    while head < len(queue):
        var parent_index = merged_steps.resolve(queue[head])
        head += 1
        var merges = List[Tuple[Int, Int]]()
        var siblings = fetch_graph.child_steps(parent_index)
        for i in range(len(siblings)):
            var sibling_index = siblings[i]
            queue.append(sibling_index)
            require_step(fetch_graph, sibling_index)
            for j in range(i + 1, len(siblings)):
                var other_index = siblings[j]
                require_step(fetch_graph, other_index)
                if can_merge_siblings(
                    store, fetch_graph, sibling_index, other_index
                ):
                    merges.append((sibling_index, other_index))
                    break
        # Each sibling starts one pair, with a later sibling, so a pair never
        # resolves to one step, as upstream checks; `check_pair` would raise.
        for pair in merges:
            var child = merged_steps.resolve(pair[0])
            var other_child = merged_steps.resolve(pair[1])
            require_step(fetch_graph, child)
            require_step(fetch_graph, other_child)
            if not can_merge_siblings(store, fetch_graph, child, other_child):
                continue
            perform_fetch_step_merge(
                store, child, other_child, fetch_graph, False
            )
            merged_steps.record(other_child, child)


# --- merge_leafs ------------------------------------------------------------


def can_merge_leafs(
    store: Store, fetch_graph: FetchGraph, self_index: Int, other_index: Int
) raises -> Bool:
    """Return True if a leaf step can go into another step, as upstream
    `can_merge_leafs`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.
        self_index: The step that would stay.
        other_index: The leaf.

    Returns:
        Whether both fetch the same objects of one subgraph under one
        condition, and the leaf does not depend on the other step.

    Raises:
        Error: When a step is missing.
    """
    if self_index == other_index:
        return False
    ref step = fetch_graph.step(self_index)
    ref other = fetch_graph.step(other_index)
    if step.service_name != other.service_name:
        return False
    if step.response_path != other.response_path:
        return False
    if not step.input.selecting_same_types(other.input):
        return False
    if step.condition != other.condition:
        return False
    if fetch_graph.first_out[other_index] != NONE:
        return False
    if fetch_graph.is_descendant_of(other_index, self_index):
        return False
    if has_arguments_conflicts_with(store, step, other):
        return False
    return True


def _find_merge_candidate(
    store: Store, fetch_graph: FetchGraph
) raises -> Tuple[Int, Int]:
    """Return the first (target, leaf) pair that can merge, or `NONE`s."""
    var all_nodes = List[Int]()
    var indices = fetch_graph.step_indices()
    var at = 0
    while at < len(indices):
        if fetch_graph.root_index != indices[at]:
            all_nodes.append(indices[at])
        at += 1
    var target = 0
    while target < len(all_nodes):
        var leaf = 0
        while leaf < len(all_nodes):
            if can_merge_leafs(
                store, fetch_graph, all_nodes[target], all_nodes[leaf]
            ):
                return (all_nodes[target], all_nodes[leaf])
            leaf += 1
        target += 1
    return (NONE, NONE)


def merge_leafs(mut store: Store, mut fetch_graph: FetchGraph) raises:
    """Merge leaf steps into steps that fetch the same objects, as upstream
    `merge_leafs`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.

    Raises:
        Error: When a step is missing, or a merge fails.
    """
    while True:
        var pair = _find_merge_candidate(store, fetch_graph)
        if pair[0] == NONE:
            return
        perform_fetch_step_merge(store, pair[0], pair[1], fetch_graph, False)


# --- deduplicate_and_prune_fetch_steps --------------------------------------


def deduplicate_and_prune_fetch_steps(
    store: Store, mut fetch_graph: FetchGraph
) raises:
    """Remove empty leaf steps and redundant direct edges, as upstream
    `deduplicate_and_prune_fetch_steps`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.

    Raises:
        Error: Never; the signature follows upstream.
    """
    var steps_to_remove = List[Int]()
    var indices = fetch_graph.step_indices()
    var at = 0
    while at < len(indices):
        var index = indices[at]
        at += 1
        ref step = fetch_graph.steps[index]
        if (
            not step.output.is_empty(store)
            and fetch_graph.first_in[index] != NONE
        ):
            continue
        if fetch_graph.first_out[index] != NONE:
            continue
        steps_to_remove.append(index)
    for index in steps_to_remove:
        _ = fetch_graph.remove_step(index)

    var edges_to_remove = List[Int]()
    indices = fetch_graph.step_indices()
    at = 0
    while at < len(indices):
        var index = indices[at]
        at += 1
        for edge in fetch_graph.parents_of(index):
            var parent = fetch_graph.edges[edge].parent
            if is_reachable_via_alternative_upstream_path(
                fetch_graph, index, parent
            ):
                edges_to_remove.append(edge)
    for edge in edges_to_remove:
        _ = fetch_graph.remove_edge(edge)


# --- turn_mutations_into_sequence -------------------------------------------

comptime _NO_SUBGRAPH = -2
"""Upstream `None` of `single_subgraph`; `NONE` is `SubgraphName::any()`."""


def _single_subgraph(fetch_graph: FetchGraph, steps: List[Int]) raises -> Int:
    """Return the subgraph every step goes to, or `_NO_SUBGRAPH`."""
    var subgraph = _NO_SUBGRAPH
    var index = 0
    while index < len(steps):
        var service_name = fetch_graph.step(steps[index]).service_name
        if subgraph != _NO_SUBGRAPH and subgraph != service_name:
            return _NO_SUBGRAPH
        subgraph = service_name
        index += 1
    return subgraph


def _reachable_from(fetch_graph: FetchGraph, starts: List[Int]) -> List[Bool]:
    """Return which steps a breadth-first walk from the starts reaches."""
    var reachable = List[Bool](length=len(fetch_graph.alive), fill=False)
    var index = 0
    while index < len(starts):
        var order = fetch_graph.bfs_order(starts[index])
        var at = 0
        while at < len(order):
            reachable[order[at]] = True
            at += 1
        index += 1
    return reachable^


def _wait_for(
    mut fetch_graph: FetchGraph,
    root_index: Int,
    previous: List[Int],
    next: List[Int],
):
    """Make the `next` steps wait for the `previous` ones, not the root."""
    if len(previous) == 0:
        return
    var index = 0
    while index < len(next):
        # `remove_edge` ignores `NONE`, as upstream skips a missing edge.
        _ = fetch_graph.remove_edge(
            fetch_graph.find_edge(root_index, next[index])
        )
        var at = 0
        while at < len(previous):
            _ = fetch_graph.connect(previous[at], next[index])
            at += 1
        index += 1


def turn_mutations_into_sequence(mut fetch_graph: FetchGraph) raises:
    """Make the root mutation fields run one after another, as upstream
    `turn_mutations_into_sequence`.

    Consecutive fields of one subgraph form a group. In a group, a field
    waits for the root fetch of the field before it. The first field of the
    next group waits for the last steps of the group.

    Args:
        fetch_graph: The fetch graph.

    Raises:
        Error: When there is no root, or a root step has no field position.
    """
    if fetch_graph.operation_kind != OperationKind.MUTATION:
        return
    var root_index = root_index_of(fetch_graph)

    # BTreeMap<position, Vec<step>>, as sorted parallel lists.
    var positions = List[Int]()
    var fields = List[List[Int]]()
    var root_children = fetch_graph.child_steps(root_index)
    var child = 0
    while child < len(root_children):
        var step_index = root_children[child]
        child += 1
        var position = fetch_graph.step(step_index).mutation_field_position
        if position == NONE:
            raise Error(
                "Expected a FetchStep with Mutation to have its order defined"
            )
        var at = 0
        while at < len(positions) and positions[at] < position:
            at += 1
        if at < len(positions) and positions[at] == position:
            fields[at].append(step_index)
        else:
            positions.insert(at, position)
            var steps: List[Int] = [step_index]
            fields.insert(at, steps^)

    var groups = List[List[List[Int]]]()
    var group_subgraph = _NO_SUBGRAPH
    var field = 0
    while field < len(fields):
        ref steps = fields[field]
        field += 1
        var subgraph = _single_subgraph(fetch_graph, steps)
        if (
            len(groups) > 0
            and subgraph != _NO_SUBGRAPH
            and subgraph == group_subgraph
        ):
            groups[len(groups) - 1].append(steps.copy())
        else:
            group_subgraph = subgraph
            var group = List[List[Int]]()
            group.append(steps.copy())
            groups.append(group^)

    var at_group = 0
    while at_group < len(groups):
        ref group = groups[at_group]
        at_group += 1
        for index in range(len(group) - 1):
            _wait_for(fetch_graph, root_index, group[index], group[index + 1])

    for index in range(len(groups) - 1):
        var previous = List[Int]()
        ref group = groups[index]
        var at = 0
        while at < len(group):
            previous.extend(group[at].copy())
            at += 1
        var next = groups[index + 1][0].copy()
        var next_steps = _reachable_from(fetch_graph, next)
        var reached = _reachable_from(fetch_graph, previous)
        var last_steps = List[Int]()
        var step = 0
        while step < len(reached):
            if (
                reached[step]
                and fetch_graph.first_out[step] == NONE
                and not next_steps[step]
            ):
                last_steps.append(step)
            step += 1
        _wait_for(fetch_graph, root_index, last_steps, next)
