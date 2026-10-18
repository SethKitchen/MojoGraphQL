# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fetch graph optimizer passes that work on the types of selections.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/optimize/`:
`normalize_selection_sets.rs` and `type_mismatches.rs`.

**Differences from upstream.** Upstream reads the subgraph of a step from
`SupergraphState::subgraphs_state`. This port's `SupergraphState` does not
hold the subgraphs, so the caller passes them, in the order of
`subgraph_names`.
"""

from gql_router.ast import NONE, ItemKind
from gql_router.fetch_step import (
    FetchGraph,
    FetchNodePathSegment,
    FetchRewrite,
    FetchStepSelections,
)
from gql_router.merge_path import MergePath, SegmentKind
from gql_router.mismatch_finder import Mismatch, find_mismatches_in_node
from gql_router.selection_set import (
    fields_through_fragments,
    find_by_path,
    merge_selection_set,
)
from gql_router.selection_tools import fetch_node_path, field_condition_equal
from gql_router.store import Store
from gql_router.subgraph_state import SubgraphState
from gql_router.supergraph_state import SupergraphState


# --- normalize_selection_sets -----------------------------------------------


def normalize_selection_set(
    mut store: Store,
    supergraph: SupergraphState,
    current_type_name: Int,
    set: Int,
) raises:
    """Flatten the inline fragments on a set's own type, as upstream
    `SelectionSetNormalizer::normalize_selection_set`.

    A fragment on the set's own type with no condition merges into the
    items before it.

    Args:
        store: The store.
        supergraph: The supergraph.
        current_type_name: The type of the set, as a symbol.
        set: The set to change in place.

    Raises:
        Error: When a field is not in its type, or on a fragment spread.
    """
    var normalized = List[Int]()
    for item in store.children(set):
        var found = store.items[item]
        if found.kind == ItemKind.FIELD:
            var child_type = supergraph.field_return_type_name(
                store, current_type_name, found.name
            )
            if child_type == NONE:
                raise Error(
                    "Internal Error: No field found for name '"
                    + store.name(found.name)
                    + "' in type '"
                    + store.name(current_type_name)
                    + "'"
                )
            normalize_selection_set(store, supergraph, child_type, item)
            normalized.append(item)
        elif found.kind == ItemKind.FRAGMENT:
            normalize_selection_set(store, supergraph, found.name, item)
            if (
                found.name == current_type_name
                and found.skip == NONE
                and found.include == NONE
            ):
                var merged = store.new_set()
                store.set_children(merged, normalized)
                merge_selection_set(store, merged, item, False)
                normalized = store.children(merged)
            else:
                normalized.append(item)
        else:
            raise Error(
                "Internal Error: fragment spreads should have been inlined"
                " before selection-set normalization"
            )
    store.set_children(set, normalized)


def normalize_selection_sets(
    mut store: Store, supergraph: SupergraphState, mut fetch_graph: FetchGraph
) raises:
    """Normalize the output of every step, as upstream
    `normalize_selection_sets`.

    Args:
        store: The store.
        supergraph: The supergraph.
        fetch_graph: The fetch graph.

    Raises:
        Error: When a field is not in its type, or on a fragment spread.
    """
    var indices = fetch_graph.step_indices()
    var index = 0
    while index < len(indices):
        var types = fetch_graph.steps[indices[index]].output.types.copy()
        var sets = fetch_graph.steps[indices[index]].output.sets.copy()
        for at in range(len(types)):
            normalize_selection_set(store, supergraph, types[at], sets[at])
        index += 1


# --- fix_conflicting_type_mismatches ----------------------------------------


def free_alias(mut store: Store, selections: Int, path: MergePath) -> Int:
    """Return an alias no field of the object at a path uses yet, as
    upstream `free_alias`.

    Args:
        store: The store.
        selections: The step's selection set for the type.
        path: The path to the set that holds the field.

    Returns:
        The first free `_internal_qp_alias_<n>`, as a symbol.
    """
    var object_path = path.copy()
    while (
        len(object_path.segments) > 0
        and object_path.segments[len(object_path.segments) - 1].kind
        == SegmentKind.TYPE_CONDITION
    ):
        object_path = object_path.without_last()
    var taken = List[Int]()
    var object = find_by_path(store, selections, object_path)
    if object != NONE:
        var fields = List[Int]()
        fields_through_fragments(store, object, fields)
        for field in fields:
            taken.append(store.response_key(field))
    var index = 0
    while True:
        var alias = store.sym("_internal_qp_alias_" + String(index))
        var used = False
        for key in taken:
            if key == alias:
                used = True
                break
        if not used:
            return alias
        index += 1


def subgraph_of(
    supergraph: SupergraphState, subgraphs: List[SubgraphState], name: Int
) -> Int:
    """Return the position of a subgraph's state, as upstream
    `subgraph_state`.

    Args:
        supergraph: The supergraph.
        subgraphs: The subgraph states, in the order of `subgraph_names`.
        name: The subgraph name, as a symbol, or `NONE`.

    Returns:
        The index in `subgraphs`, or `NONE` when it is not known.
    """
    if name == NONE:
        return NONE
    var index = supergraph.subgraph_index(name)
    if index == NONE or index >= len(subgraphs):
        return NONE
    return index


def fix_conflicting_type_mismatches(
    mut store: Store,
    supergraph: SupergraphState,
    subgraphs: List[SubgraphState],
    mut fetch_graph: FetchGraph,
) raises:
    """Alias the fields that share a response key with a field of another
    shape, and rename them back with an output rewrite, as upstream
    `fix_conflicting_type_mismatches`.

    Args:
        store: The store.
        supergraph: The supergraph.
        subgraphs: The subgraph states, in the order of `subgraph_names`.
        fetch_graph: The fetch graph.

    Raises:
        Error: When a step's subgraph, type or field is not known.
    """
    var patch_steps = List[Int]()
    var patches = List[List[Mismatch]]()
    var indices = fetch_graph.step_indices()
    var at = 0
    while at < len(indices):
        var index = indices[at]
        at += 1
        if fetch_graph.root_index == index:
            continue
        var service_name = fetch_graph.steps[index].service_name
        var subgraph = subgraph_of(supergraph, subgraphs, service_name)
        if subgraph == NONE:
            raise Error("Missing subgraph state for step " + String(index))
        var found = find_mismatches_in_node(
            store,
            supergraph,
            subgraphs[subgraph],
            fetch_graph.steps[index].output,
        )
        if len(found) > 0:
            patch_steps.append(index)
            patches.append(found^)

    var rewrite_steps = List[Int]()
    var rewrites = List[FetchRewrite]()
    for patch in range(len(patch_steps)):
        ref found = patches[patch]
        # A step is patched only when it has a mismatch.
        var at = 0
        while at < len(found):
            alias_mismatch(
                store,
                fetch_graph.steps[patch_steps[patch]].output,
                found[at],
                patch_steps[patch],
                rewrite_steps,
                rewrites,
            )
            at += 1

    for index in range(len(rewrite_steps)):
        fetch_graph.steps[rewrite_steps[index]].add_output_rewrite(
            rewrites[index].copy()
        )


def alias_mismatch(
    mut store: Store,
    output: FetchStepSelections,
    mismatch: Mismatch,
    step_index: Int,
    mut rewrite_steps: List[Int],
    mut rewrites: List[FetchRewrite],
) raises:
    """Alias one mismatched field and record the output rewrite that renames
    it back, as the loop body of upstream `fix_conflicting_type_mismatches`.

    Nothing changes when the path does not end with a field, or when the
    field is not there.

    Args:
        store: The store.
        output: The step's output.
        mismatch: The type and the path of the field.
        step_index: The step.
        rewrite_steps: The steps of the recorded rewrites.
        rewrites: The recorded rewrites.

    Raises:
        Error: When the output does not have the mismatch's type.
    """
    var length = len(mismatch.path.segments)
    if length == 0:
        return
    var last = mismatch.path.segments[length - 1]
    if last.kind != SegmentKind.FIELD:
        return
    var lookup_path = mismatch.path.without_last()
    var root_selections = output.selections_for_definition(mismatch.root_type)
    if root_selections == NONE:
        raise Error("missing definition in step")
    var next_alias = free_alias(store, root_selections, lookup_path)
    var set = find_by_path(store, root_selections, lookup_path)
    if set == NONE:
        return
    var item = store.items[set].first
    while item != NONE:
        if (
            store.items[item].kind == ItemKind.FIELD
            and store.response_key(item) == last.response_key()
            and store.items[item].args == last.args
            and field_condition_equal(store, last.cond, item)
        ):
            break
        item = store.items[item].next
    if item == NONE:
        return
    var original_response_key = store.response_key(item)
    var path = fetch_node_path(store, lookup_path)
    path.append(fetch_node_path_key(next_alias))
    rewrite_steps.append(step_index)
    rewrites.append(FetchRewrite(False, path^, original_response_key))
    store.items[item].alias = next_alias


def fetch_node_path_key(key: Int) -> FetchNodePathSegment:
    """Return a `Key` rewrite path segment.

    Args:
        key: The key, as a symbol.

    Returns:
        The segment.
    """
    return FetchNodePathSegment(True, key, NONE)
