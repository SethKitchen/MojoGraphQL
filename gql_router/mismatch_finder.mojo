# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Find fields that share a response key with fields of another shape.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/ast/mismatch_finder.rs`.

At one level of a selection set, inline fragments included, two fields
with one response key must have the same response shape in the subgraph.
When they do not, the subgraph rejects the query, so the planner aliases
the second field.

**Differences from upstream.** Upstream panics on a type or a field that
the subgraph does not have. This port raises an `Error`.
"""

from gql_router.ast import NONE, Cond, ItemKind
from gql_router.federation_spec import TypeNode
from gql_router.fetch_step import FetchStepSelections
from gql_router.merge_path import MergePath, Segment
from gql_router.store import Store
from gql_router.subgraph_state import SubgraphState
from gql_router.supergraph_state import SupergraphState


@fieldwise_init
struct Mismatch(Copyable, Movable):
    """One field to alias: the step type and the path to the field."""

    var root_type: Int
    """The type of the step's selection set, as a symbol."""
    var path: MergePath
    """The path to the field, from that selection set."""


def same_response_shape(
    supergraph: SupergraphState, left: TypeNode, right: TypeNode
) -> Bool:
    """Return GraphQL's "same response shape" of two types, as upstream
    `same_response_shape`.

    Args:
        supergraph: The supergraph.
        left: A type.
        right: Another type.

    Returns:
        Whether lists and non-nulls line up level by level, and the named
        types are equal or both composite.
    """
    if left.shape != right.shape:
        return False
    if left.name == right.name:
        return True
    var a = supergraph.definition(left.name)
    var b = supergraph.definition(right.name)
    return (
        a != NONE
        and b != NONE
        and supergraph.definitions[a].is_composite_type()
        and supergraph.definitions[b].is_composite_type()
    )


def find_mismatches_in_node(
    mut store: Store,
    supergraph: SupergraphState,
    subgraph: SubgraphState,
    selections: FetchStepSelections,
) raises -> List[Mismatch]:
    """Return the fields of a step to alias, as upstream
    `find_mismatches_in_node`.

    Args:
        store: The store.
        supergraph: The supergraph.
        subgraph: The step's subgraph.
        selections: The step's output.

    Returns:
        The mismatches, in visit order.

    Raises:
        Error: When the subgraph lacks a type or a field of the selections.
    """
    var out = List[Mismatch]()
    for index in range(len(selections.types)):
        var definition_name = selections.types[index]
        var entrypoint = subgraph.definition(definition_name)
        if entrypoint == NONE:
            raise Error(
                "Missing definition '"
                + store.name(definition_name)
                + "' in the subgraph"
            )
        _handle_selection_set(
            store,
            definition_name,
            supergraph,
            subgraph,
            entrypoint,
            selections.sets[index],
            MergePath(),
            out,
        )
    return out^


def _handle_selection_set(
    mut store: Store,
    root_type: Int,
    supergraph: SupergraphState,
    subgraph: SubgraphState,
    parent_def: Int,
    set: Int,
    var parent_path: MergePath,
    mut out: List[Mismatch],
) raises:
    """Visit one level of a set, its inline fragments flattened."""
    var keys = List[Int]()
    var key_types = List[TypeNode]()
    var queue_defs: List[Int] = [parent_def]
    var queue_paths = List[MergePath]()
    queue_paths.append(parent_path^)
    var queue_sets: List[Int] = [set]
    var head = 0
    while head < len(queue_defs):
        var type_def = queue_defs[head]
        var path = queue_paths[head].copy()
        var group = queue_sets[head]
        head += 1
        var item = store.items[group].first
        while item != NONE:
            var found = store.items[item]
            if found.kind == ItemKind.FIELD:
                if store.name(found.name).startswith("__"):
                    item = found.next
                    continue
                var next_path = path.push(
                    Segment.field(
                        found.name,
                        found.alias,
                        found.args,
                        Cond(found.skip, found.include),
                    )
                )
                var next_type = _handle_field(
                    store,
                    root_type,
                    supergraph,
                    subgraph,
                    type_def,
                    item,
                    next_path,
                    keys,
                    key_types,
                    out,
                )
                if next_type != NONE:
                    var next_def = subgraph.definition(next_type)
                    if next_def != NONE:
                        _handle_selection_set(
                            store,
                            root_type,
                            supergraph,
                            subgraph,
                            next_def,
                            item,
                            next_path^,
                            out,
                        )
            elif found.kind == ItemKind.SPREAD:
                raise Error("fragment spread is not expected at this stage")
            else:
                # An inline fragment: a set has no `ROOT` child.
                var fragment_def = subgraph.definition(found.name)
                if fragment_def == NONE:
                    raise Error(
                        "Missing definition '"
                        + store.name(found.name)
                        + "' in the subgraph"
                    )
                queue_defs.append(fragment_def)
                queue_paths.append(
                    path.push(
                        Segment.type_condition(
                            store.single_type_set(found.name),
                            Cond(found.skip, found.include),
                        )
                    )
                )
                queue_sets.append(item)
            item = found.next


def _handle_field(
    store: Store,
    root_type: Int,
    supergraph: SupergraphState,
    subgraph: SubgraphState,
    parent_def: Int,
    field: Int,
    field_path: MergePath,
    mut keys: List[Int],
    mut key_types: List[TypeNode],
    mut out: List[Mismatch],
) raises -> Int:
    """Check one field against the fields seen with its response key, and
    return the type to visit below it, or `NONE`."""
    ref definition = subgraph.definitions[parent_def]
    var name = store.items[field].name
    var index = definition.field(name)
    if index == NONE:
        raise Error(
            "Missing field '"
            + store.name(name)
            + "' in type '"
            + store.name(definition.name)
            + "' of the subgraph"
        )
    ref subgraph_field = definition.fields[index]
    var field_type = subgraph_field.field_type.copy()
    if subgraph_field.join_field:
        ref join_field = subgraph_field.join_field.value()
        if join_field.type_in_graph:
            field_type = join_field.type_in_graph.value().copy()
    var key = store.response_key(field)
    var seen = NONE
    for at in range(len(keys)):
        if keys[at] == key:
            seen = at
            break
    if seen != NONE:
        if not same_response_shape(supergraph, key_types[seen], field_type):
            out.append(Mismatch(root_type, field_path.copy()))
    else:
        keys.append(key)
        key_types.append(field_type.copy())
    if store.items[field].first == NONE:
        return NONE
    return field_type.inner_type()
