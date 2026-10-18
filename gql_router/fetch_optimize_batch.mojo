# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fetch graph optimizer pass that batches entity calls of many types.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/optimize/batch_multi_type.rs`.

Sibling entity calls to one subgraph whose response paths differ only by
type conditions merge into one call with a selection set per type.

**Differences from upstream.** Upstream keys the possible types of each
path slot by a hash of the path without type conditions and by the slot.
The hash is always the hash of the same path, so this port keys them by
the slot alone: `possible_types_by_position` returns one type set id per
slot, or `NONE`.
"""

from gql_router.ast import NONE, Cond
from gql_router.fetch_optimize_utils import (
    MergedSteps,
    has_arguments_conflicts_with,
    perform_fetch_step_merge,
    require_step,
    root_index_of,
)
from gql_router.fetch_step import (
    FetchGraph,
    FetchStepData,
    FetchStepFlags,
    type_condition_types,
)
from gql_router.merge_path import MergePath, Segment, SegmentKind
from gql_router.selection_set import response_keys_conflict
from gql_router.selection_tools import insert_sorted_once, sorted_union
from gql_router.store import Store
from gql_router.supergraph_state import DefinitionKind, SupergraphState


def possible_object_types(
    mut store: Store, supergraph: SupergraphState, type_name: Int
) -> Int:
    """Return the object types a value of a type can be, as upstream
    `possible_object_types`.

    Args:
        store: The store.
        supergraph: The supergraph.
        type_name: The type, as a symbol.

    Returns:
        A type set id: the type for an object, the implementations of an
        interface, the members of a union; `NONE` for another type.
    """
    var index = supergraph.definition(type_name)
    if index == NONE:
        return NONE
    ref definition = supergraph.definitions[index]
    if definition.kind == DefinitionKind.OBJECT:
        return store.single_type_set(type_name)
    if definition.kind == DefinitionKind.INTERFACE:
        if not supergraph.has_interface_members(type_name):
            return NONE
        return store.type_set(supergraph.interface_members(type_name))
    if definition.kind == DefinitionKind.UNION:
        # A union always has a member.
        var members = List[Int]()
        var at = 0
        while at < len(definition.union_members):
            members.append(definition.union_members[at].member)
            at += 1
        return store.type_set(members)
    return NONE


def possible_types_by_position(
    mut store: Store,
    supergraph: SupergraphState,
    root_type: Int,
    path: MergePath,
) -> List[Int]:
    """Return every object type the value at each slot of a path can be, as
    upstream `possible_types_by_position`.

    Args:
        store: The store.
        supergraph: The supergraph.
        root_type: The root type, as a symbol.
        path: The response path.

    Returns:
        One type set id per slot, indexed by the number of steps that are
        not type conditions; `NONE` when the type is not known.
    """
    var result = List[Int](length=len(path.segments) + 1, fill=NONE)
    var current_type = root_type
    var type_condition = NONE
    var position = 0
    var at = 0
    while at < len(path.segments):
        ref segment = path.segments[at]
        at += 1
        if segment.kind == SegmentKind.TYPE_CONDITION:
            type_condition = segment.types
            continue
        if segment.kind == SegmentKind.LIST:
            position += 1
        else:
            var parent_type = current_type
            if (
                type_condition != NONE
                and len(store.type_sets[type_condition]) > 0
            ):
                parent_type = store.type_sets[type_condition][0]
            if parent_type != NONE:
                current_type = supergraph.field_return_type_name(
                    store, parent_type, segment.name
                )
            else:
                current_type = NONE
            type_condition = NONE
            position += 1
        if current_type != NONE:
            var possible = possible_object_types(
                store, supergraph, current_type
            )
            if possible != NONE:
                result[position] = possible
    return result^


def _consume_type_conditions(
    store: Store,
    path: MergePath,
    mut index: Int,
    mut members: List[Int],
    mut condition: Cond,
) -> Bool:
    """Read the type conditions at a slot; return whether there was one."""
    var had_type_condition = False
    while (
        index < len(path.segments)
        and path.segments[index].kind == SegmentKind.TYPE_CONDITION
    ):
        had_type_condition = True
        ref names = store.type_sets[path.segments[index].types]
        var at = 0
        while at < len(names):
            insert_sorted_once(store, members, names[at])
            at += 1
        if not condition.is_some():
            condition = path.segments[index].cond
        index += 1
    return had_type_condition


def merge_batched_response_paths(
    mut store: Store,
    me: MergePath,
    other: MergePath,
    possible_types: List[Int],
) -> MergePath:
    """Return the response path of two batched entity calls, as upstream
    `merge_batched_response_paths`.

    At each slot the type conditions of both paths join. The type condition
    goes away when the joined types are every type the value can be and it
    has no condition.

    Args:
        store: The store.
        me: The path of the step that stays.
        other: The path of the step merged into it.
        possible_types: The result of `possible_types_by_position` for `me`.

    Returns:
        The merged path, or `me` when the paths differ outside type
        conditions.
    """
    if me.without_type_castings() != other.without_type_castings():
        return me.copy()
    var merged = List[Segment]()
    var me_index = 0
    var other_index = 0
    var position = 0
    while True:
        var me_members = List[Int]()
        var other_members = List[Int]()
        var condition = Cond.none()
        var unused = Cond.none()
        var me_had = _consume_type_conditions(
            store, me, me_index, me_members, condition
        )
        var other_had = _consume_type_conditions(
            store, other, other_index, other_members, unused
        )
        var changed = me_members != other_members
        var members = sorted_union(store, me_members, other_members)
        if me_had and other_had and len(members) > 0:
            var keep = True
            if changed and not condition.is_some():
                var possible = (
                    possible_types[position] if position
                    < len(possible_types) else NONE
                )
                if possible != NONE:
                    var all_in = True
                    ref names = store.type_sets[possible]
                    var at = 0
                    while at < len(names):
                        var found = False
                        var member = 0
                        while member < len(members):
                            if members[member] == names[at]:
                                found = True
                                break
                            member += 1
                        if not found:
                            all_in = False
                            break
                        at += 1
                    if all_in:
                        keep = False
            if keep:
                merged.append(
                    Segment.type_condition(store.type_set(members), condition)
                )
        # Without type conditions the paths are equal, so after the type
        # conditions of a slot both end, or both have the same next step.
        # Upstream also checks that.
        if me_index >= len(me.segments):
            break
        merged.append(me.segments[me_index])
        me_index += 1
        other_index += 1
        position += 1
    return MergePath(merged^)


def _has_stacked_type_conditions(path: MergePath) -> Bool:
    """Return True if two type conditions follow each other."""
    for index in range(len(path.segments) - 1):
        if (
            path.segments[index].kind == SegmentKind.TYPE_CONDITION
            and path.segments[index + 1].kind == SegmentKind.TYPE_CONDITION
        ):
            return True
    return False


def can_be_batched_with(
    store: Store, step: FetchStepData, other: FetchStepData
) -> Bool:
    """Return True if two entity calls can go in one multi-type call, as
    upstream `can_be_batched_with`.

    Args:
        store: The store.
        step: A step.
        other: Another step.

    Returns:
        Whether the steps call one subgraph at paths that differ only by
        the types of one type condition, with no conflict.
    """
    if step.kind != other.kind:
        return False
    if step.service_name != other.service_name:
        return False
    # Both steps have the same kind.
    if not step.is_entity_call():
        return False
    if (
        step.response_path.without_type_castings()
        != other.response_path.without_type_castings()
    ):
        return False
    if len(step.response_path) != len(other.response_path):
        return False
    var length = len(step.response_path)
    var index = 0
    while index < length:
        var left = step.response_path.segments[index]
        var right = other.response_path.segments[index]
        if (left.kind == SegmentKind.TYPE_CONDITION) != (
            right.kind == SegmentKind.TYPE_CONDITION
        ):
            return False
        index += 1
    # From here on, both paths have their type conditions at the same
    # places, so upstream's checks of the other path's kinds always hold.
    index = 0
    while index < length:
        var left = step.response_path.segments[index]
        var right = other.response_path.segments[index]
        if left.kind == SegmentKind.TYPE_CONDITION and left.cond != right.cond:
            return False
        index += 1
    if _has_stacked_type_conditions(step.response_path):
        return False
    var slots_with_other_types = 0
    index = 0
    while index < length:
        var left = step.response_path.segments[index]
        var right = other.response_path.segments[index]
        if (
            left.kind == SegmentKind.TYPE_CONDITION
            and left.types != right.types
        ):
            slots_with_other_types += 1
        index += 1
    if slots_with_other_types > 1:
        return False
    if has_arguments_conflicts_with(store, step, other):
        return False
    index = 0
    while index < len(step.output.types):
        var other_set = other.output.selections_for_definition(
            step.output.types[index]
        )
        if other_set != NONE and response_keys_conflict(
            store, step.output.sets[index], other_set
        ):
            return False
        index += 1
    var self_requires = step.flags.contains(FetchStepFlags.USED_FOR_REQUIRES)
    var other_requires = other.flags.contains(FetchStepFlags.USED_FOR_REQUIRES)
    if self_requires != other_requires:
        return False
    return True


def batch_multi_type(
    mut store: Store, supergraph: SupergraphState, mut fetch_graph: FetchGraph
) raises:
    """Batch sibling entity calls that differ only by type conditions, as
    upstream `batch_multi_type`.

    Args:
        store: The store.
        supergraph: The supergraph.
        fetch_graph: The fetch graph.

    Raises:
        Error: When there is no root type or root step, a step is missing,
            or a merge fails.
    """
    var root_type: Int
    try:
        root_type = supergraph.root_type_name(fetch_graph.operation_kind)
    except e:
        raise Error("Internal Error: " + String(e))
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
                if can_be_batched_with(
                    store,
                    fetch_graph.steps[sibling_index],
                    fetch_graph.steps[other_index],
                ):
                    merges.append((sibling_index, other_index))
        for pair in merges:
            var child = merged_steps.resolve(pair[0])
            var other_child = merged_steps.resolve(pair[1])
            if child == other_child:
                continue
            if fetch_graph.is_ancestor_or_descendant(child, other_child):
                continue
            require_step(fetch_graph, child)
            require_step(fetch_graph, other_child)
            if not can_be_batched_with(
                store, fetch_graph.steps[child], fetch_graph.steps[other_child]
            ):
                continue
            _batch_pair(
                store, supergraph, root_type, fetch_graph, child, other_child
            )
            merged_steps.record(other_child, child)


def _batch_pair(
    mut store: Store,
    supergraph: SupergraphState,
    root_type: Int,
    mut fetch_graph: FetchGraph,
    child: Int,
    other_child: Int,
) raises:
    """Merge one batchable pair and fix the merged response path."""
    var original_me_path = fetch_graph.steps[child].response_path.copy()
    var original_other_path = fetch_graph.steps[
        other_child
    ].response_path.copy()
    var possible = possible_types_by_position(
        store, supergraph, root_type, original_me_path
    )
    var other_input_types = fetch_graph.steps[other_child].input.types.copy()
    var other_output_types = fetch_graph.steps[other_child].output.types.copy()
    # An entity call has an input type and an output type.
    var at = 0
    while at < len(other_input_types):
        fetch_graph.steps[child].input.declare_known_type(
            store, other_input_types[at]
        )
        at += 1
    at = 0
    while at < len(other_output_types):
        fetch_graph.steps[child].output.declare_known_type(
            store, other_output_types[at]
        )
        at += 1
    perform_fetch_step_merge(store, child, other_child, fetch_graph, True)
    var merged_path = merge_batched_response_paths(
        store, original_me_path, original_other_path, possible
    )
    fetch_graph.steps[child].response_path = merged_path^
    if not fetch_graph.steps[child].is_fetching_multiple_types():
        return
    var condition = fetch_graph.steps[child].condition
    if not condition.is_some():
        return
    var types = type_condition_types(
        store, fetch_graph.steps[child].response_path
    )
    if len(types) == 0:
        return
    fetch_graph.steps[child].output.wrap_with_condition_for_types(
        store, condition, types
    )
    fetch_graph.steps[child].condition = Cond.none()
