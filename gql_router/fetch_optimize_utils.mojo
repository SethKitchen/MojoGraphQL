# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""What the fetch graph optimizer passes share.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/optimize/utils.rs`, and
`get_pair_of_steps_mut` of `planner/fetch/fetch_graph.rs`.

**Differences from upstream.** Upstream merges two steps through two
mutable references. This port copies both steps out of the graph, changes
the copies, and puts the target back. The selection sets live in the
`Store`, so a copy shares them with the original.
"""

from gql_router.ast import NONE, Cond
from gql_router.fetch_step import (
    FetchGraph,
    FetchRewrite,
    FetchStepData,
    FetchStepKind,
    scope_fetch_conditions_before_merge,
)
from gql_router.merge_path import MergePath, SegmentKind
from gql_router.selection_set import (
    find_arguments_conflicts,
    find_by_path,
    items_are_subset_of,
)
from gql_router.selection_tools import read_as_written
from gql_router.store import Store


struct MergedSteps(Movable):
    """Where merged-away steps went, kept for a whole pass, as upstream
    `MergedSteps`."""

    var merged: Dict[Int, Int]
    """The step each merged step went into."""

    def __init__(out self):
        """Start with no merge."""
        self.merged = Dict[Int, Int]()

    def resolve(self, step: Int) -> Int:
        """Return the step a step went into, following the whole chain.

        Args:
            step: A step.

        Returns:
            The step still in the graph.
        """
        var current = step
        while True:
            var into = self.merged.get(current)
            if not into:
                return current
            current = into.value()

    def record(mut self, merged: Int, into: Int):
        """Record that one step went into another.

        Args:
            merged: The step merged away.
            into: The step it went into.
        """
        self.merged[merged] = into


def edge_count(graph: FetchGraph) -> Int:
    """Return the number of edges, as `petgraph` `edge_count`.

    Args:
        graph: The fetch graph.

    Returns:
        The number of edges.
    """
    return len(graph.edges) - len(graph.free_edges)


def check_pair(graph: FetchGraph, index1: Int, index2: Int) raises:
    """Check two steps as upstream `get_pair_of_steps_mut`.

    Args:
        graph: The fetch graph.
        index1: A step.
        index2: Another step.

    Raises:
        Error: When the indexes are equal, or a step is missing.
    """
    if index1 == index2:
        raise Error("Expected different indexes: " + String(index1))
    if not graph.contains_step(index1):
        raise Error(
            "Missing FetchStep: " + String(index1) + " when checking existence"
        )
    if not graph.contains_step(index2):
        raise Error(
            "Missing FetchStep: " + String(index2) + " when checking existence"
        )


def require_step(graph: FetchGraph, index: Int) raises:
    """Check that a step exists, as upstream `get_step_data` does.

    Args:
        graph: The fetch graph.
        index: The step.

    Raises:
        Error: When there is no such step.
    """
    if not graph.contains_step(index):
        raise Error(
            "Missing FetchStep: " + String(index) + " when getting step data"
        )


def root_index_of(graph: FetchGraph) raises -> Int:
    """Return the root step.

    Args:
        graph: The fetch graph.

    Returns:
        The root index.

    Raises:
        Error: When the graph has no root index.
    """
    if graph.root_index == NONE:
        raise Error("Expected to have one root step, but found: 0")
    return graph.root_index


def _merge_source_condition_into_non_entity_target(
    mut store: Store, target: FetchStepData, mut source: FetchStepData
) raises -> Bool:
    """Keep the condition of an entity call on its own branch when it
    merges into a root fetch, as upstream
    `merge_source_condition_into_non_entity_target`."""
    if not source.condition.is_some():
        return False
    if target.is_entity_call():
        return False
    var condition = source.condition
    var input = source.input.copy_into(store)
    var index = 0
    while index < len(input.sets):
        read_as_written(store, input.sets[index])
        index += 1
    source.output.migrate_from_another(store, input, MergePath())
    var redundant = False
    var length = len(source.response_path.segments)
    if length > 0:
        var last = source.response_path.segments[length - 1]
        if (
            last.kind == SegmentKind.TYPE_CONDITION
            or last.kind == SegmentKind.FIELD
        ) and last.cond.is_some():
            redundant = last.cond == condition
    if not redundant:
        source.output.wrap_with_condition(store, condition)
    return True


def perform_fetch_step_merge(
    mut store: Store,
    target_index: Int,
    source_index: Int,
    mut fetch_graph: FetchGraph,
    force_merge_inputs: Bool,
) raises:
    """Merge one step into another, as upstream `perform_fetch_step_merge`.

    The target takes the source's output, its input rewrites, and its
    input when the inputs line up. The source's children and parents move
    to the target, and the source leaves the graph.

    Args:
        store: The store.
        target_index: The step that stays.
        source_index: The step that goes.
        fetch_graph: The fetch graph.
        force_merge_inputs: Merge the inputs whatever their types.

    Raises:
        Error: When a step is missing, the steps write other types at one
            place, or the inputs have the same types at unrelated paths.
    """
    check_pair(fetch_graph, target_index, source_index)
    var target = fetch_graph.steps[target_index].copy()
    var source = fetch_graph.steps[source_index].copy()

    var merged = _merge_source_condition_into_non_entity_target(
        store, target, source
    )
    if not merged:
        scope_fetch_conditions_before_merge(store, target, source)

    var source_fetch_path = source.response_path.slice_from(
        len(target.response_path)
    )
    if source_fetch_path.is_empty():
        var target_type = target.output.try_as_single()
        if target_type != NONE:
            var at = 0
            while at < len(source.output.types):
                var source_type = source.output.types[at]
                if source_type != target_type:
                    fetch_graph.steps[target_index] = target^
                    raise Error(
                        "Internal Error: can't merge the `"
                        + store.name(source_type)
                        + "` fields of step ["
                        + String(source_index)
                        + "] into the `"
                        + store.name(target_type)
                        + "` fields of step ["
                        + String(target_index)
                        + "]"
                    )
                at += 1
    target.output.migrate_from_another(store, source.output, source_fetch_path)

    if source.has_input_rewrites:
        var at = 0
        while at < len(source.input_rewrites):
            target.add_input_rewrite(source.input_rewrites[at].copy())
            at += 1
        source.input_rewrites = List[FetchRewrite]()
        source.has_input_rewrites = False

    if force_merge_inputs:
        target.input.migrate_from_another(store, source.input, MergePath())
    elif target.input.selecting_same_types(source.input):
        if target.response_path == source.response_path:
            target.input.migrate_from_another(store, source.input, MergePath())
        elif not source.response_path.starts_with(target.response_path):
            fetch_graph.steps[target_index] = target^
            raise Error(
                "Input types are equal but response_path are different!"
            )

    if target.is_entity_call():
        target.lift_shared_output_condition_to_fetch(store)
    fetch_graph.steps[target_index] = target^
    fetch_graph.steps[source_index] = source^

    var children = fetch_graph.child_steps(source_index)
    var parents = List[Int]()
    var source_parents = fetch_graph.parent_steps(source_index)
    var at = 0
    while at < len(source_parents):
        if source_parents[at] != target_index:
            parents.append(source_parents[at])
        at += 1
    for child in children:
        _ = fetch_graph.connect(target_index, child)
    for parent in parents:
        _ = fetch_graph.connect(parent, target_index)
    _ = fetch_graph.remove_step(source_index)


def is_reachable_via_alternative_upstream_path(
    graph: FetchGraph, child_index: Int, target_ancestor_index: Int
) -> Bool:
    """Return True if an ancestor is reachable from a child by going up,
    other than through the direct edge between them, as upstream
    `is_reachable_via_alternative_upstream_path`.

    Args:
        graph: The fetch graph.
        child_index: The step to start from.
        target_ancestor_index: The ancestor to find.

    Returns:
        Whether another path leads up to the ancestor.
    """
    var queue = List[Int]()
    var visited = List[Bool](length=len(graph.alive), fill=False)
    var direct = graph.parent_steps(child_index)
    var at = 0
    while at < len(direct):
        if direct[at] != target_ancestor_index:
            queue.append(direct[at])
            visited[direct[at]] = True
        at += 1
    if len(queue) == 0:
        return False
    var head = 0
    while head < len(queue):
        var current = queue[head]
        head += 1
        if current == target_ancestor_index:
            return True
        var parents = graph.parent_steps(current)
        at = 0
        while at < len(parents):
            if not visited[parents[at]]:
                visited[parents[at]] = True
                queue.append(parents[at])
            at += 1
    return False


def has_arguments_conflicts_with(
    store: Store, step: FetchStepData, other: FetchStepData
) -> Bool:
    """Return True if the inputs of two steps hold a response key with other
    arguments, as upstream `has_arguments_conflicts_with`.

    Args:
        store: The store.
        step: A step.
        other: Another step.

    Returns:
        Whether a type both inputs select has an argument conflict.
    """
    var index = 0
    while index < len(step.input.types):
        var other_set = other.input.selections_for_definition(
            step.input.types[index]
        )
        if other_set != NONE and (
            len(
                find_arguments_conflicts(
                    store, step.input.sets[index], other_set
                )
            )
            > 0
        ):
            return True
        index += 1
    return False


def can_absorb_nested_entity_call(
    store: Store, step: FetchStepData, other: FetchStepData
) -> Bool:
    """Return True if a step already holds the input of a nested entity
    call, as upstream `can_absorb_nested_entity_call`.

    Call it only when `step` is the only parent of `other`.

    Args:
        store: The store.
        step: The parent step.
        other: The nested entity call.

    Returns:
        Whether `other`'s fields can move into `step`'s output.
    """
    if not other.response_path.starts_with(step.response_path):
        return False
    var input_type = other.input.try_as_single()
    if input_type == NONE:
        return False
    # The only type of a selection always has a set.
    var input_selections = other.input.sets[0]
    var output_type = step.output.try_as_single()
    if output_type == NONE:
        return False
    var path = other.response_path.slice_from(len(step.response_path))
    var output = step.output.sets[0]
    var at_path = find_by_path(store, output, path)
    if at_path == NONE:
        return False
    return items_are_subset_of(store, at_path, input_selections)


def can_merge(
    store: Store,
    fetch_graph: FetchGraph,
    self_index: Int,
    other_index: Int,
) raises -> Bool:
    """Return True if one step can take another, as upstream
    `FetchStepData::can_merge`.

    Args:
        store: The store.
        fetch_graph: The fetch graph.
        self_index: The step that would stay.
        other_index: The step that would go.

    Returns:
        Whether the merge keeps the plan correct.

    Raises:
        Error: When a step is missing.
    """
    if self_index == other_index:
        return False
    ref step = fetch_graph.step(self_index)
    ref other = fetch_graph.step(other_index)
    if step.service_name != other.service_name:
        return False

    var other_parents = fetch_graph.parent_steps(other_index)
    var is_only_parent = (
        len(other_parents) == 1 and other_parents[0] == self_index
    )

    if (
        step.is_entity_call()
        and other.is_entity_call()
        and step.condition != other.condition
    ):
        var absorbs_conditional_child = (
            not step.condition.is_some()
            and is_only_parent
            and can_absorb_nested_entity_call(store, step, other)
        )
        var one_call_for_same_objects = (
            step.response_path == other.response_path
            and (not step.condition.is_some() or not other.condition.is_some())
        )
        if not absorbs_conditional_child and not one_call_for_same_objects:
            return False

    if step.kind == FetchStepKind.ENTITY and step.kind == other.kind:
        if step.response_path == other.response_path:
            if not step.output.selecting_same_types(other.output):
                return False
        elif not (
            is_only_parent and can_absorb_nested_entity_call(store, step, other)
        ):
            return False
    else:
        if not other.response_path.starts_with(step.response_path):
            return False

    if has_arguments_conflicts_with(store, step, other):
        return False

    if is_only_parent:
        return True

    var self_parents = fetch_graph.parent_steps(self_index)
    var index = 0
    while index < len(self_parents):
        var shared = False
        var at = 0
        while at < len(other_parents):
            if other_parents[at] == self_parents[index]:
                shared = True
                break
            at += 1
        if not shared:
            return False
        index += 1
    return True
