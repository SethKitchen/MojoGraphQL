# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Builders for fetch steps and fetch graphs made by hand, as the helpers
of the Hive Router `1a29df9` optimizer tests (`entity_step`, `selections`).

A path is a list of names: `@` is a list step, `|A|B` a type condition on
`A` and `B`, and any other name a field.
"""

from gql_router.ast import NONE, Cond
from gql_router.federation_spec import OperationKind
from gql_router.fetch_step import (
    FetchGraph,
    FetchStepData,
    FetchStepFlags,
    FetchStepKind,
    FetchStepSelections,
)
from gql_router.merge_path import MergePath, Segment
from gql_router.normalize import selection_set_from_text
from gql_router.store import Store


def selections(
    mut store: Store, types: List[String], queries: List[String]
) raises -> FetchStepSelections:
    """Return selections for one or more types, as upstream `selections`.

    Args:
        store: The store.
        types: The type names.
        queries: One `{ ... }` set per type.

    Returns:
        The selections.

    Raises:
        Error: When a set does not parse.
    """
    var out = FetchStepSelections.new_empty()
    for index in range(len(types)):
        var type_name = store.sym(types[index])
        out.declare_known_type(store, type_name)
        var parsed = selection_set_from_text(store, queries[index])
        out.add_at_path_inner(store, type_name, MergePath(), parsed, False)
    return out^


def path(
    mut store: Store, names: List[String], cond: Cond = Cond.none()
) -> MergePath:
    """Return a response path; `cond` goes on each type condition.

    Args:
        store: The store.
        names: The steps.
        cond: The condition of the type conditions.

    Returns:
        The path.
    """
    var segments = List[Segment]()
    for name in names:
        if name == "@":
            segments.append(Segment.list())
        elif name.startswith("|"):
            var types = List[Int]()
            var parts = name.split("|")
            for part in parts:
                if part.byte_length() > 0:
                    types.append(store.sym(String(part)))
            segments.append(Segment.type_condition(store.type_set(types), cond))
        else:
            segments.append(
                Segment.field(store.sym(name), NONE, NONE, Cond.none())
            )
    return MergePath(segments^)


def entity_step(
    mut store: Store,
    service: String,
    var response_path: MergePath,
    var input: FetchStepSelections,
    var output: FetchStepSelections,
    condition: Cond = Cond.none(),
) -> FetchStepData:
    """Return an entity call, as upstream `entity_step`.

    Args:
        store: The store.
        service: The subgraph.
        response_path: The response path.
        input: The representations.
        output: The output.
        condition: The condition.

    Returns:
        The step.
    """
    return FetchStepData(
        0,
        store.sym(service),
        response_path^,
        input^,
        output^,
        FetchStepKind.ENTITY,
        OperationKind.QUERY,
        FetchStepFlags.EMPTY,
        condition,
        NONE,
    )


def root_step(
    mut store: Store,
    service: String,
    query: String = "{ a }",
    condition: Cond = Cond.none(),
    position: Int = NONE,
) raises -> FetchStepData:
    """Return a root call with an empty input and a `Query` output.

    Args:
        store: The store.
        service: The subgraph.
        query: The output set.
        condition: The condition.
        position: The mutation field position, or `NONE`.

    Returns:
        The step.

    Raises:
        Error: When the set does not parse.
    """
    return FetchStepData(
        0,
        store.sym(service),
        MergePath(),
        FetchStepSelections.new(store, store.sym("Query")),
        selections(store, ["Query"], [query]),
        FetchStepKind.ROOT,
        OperationKind.QUERY,
        FetchStepFlags.EMPTY,
        condition,
        position,
    )


def noop_root(mut graph: FetchGraph) -> Int:
    """Add the step that fetches nothing and make it the root.

    Args:
        graph: The fetch graph.

    Returns:
        The root index.
    """
    var root = graph.add_step(
        FetchStepData(
            0,
            NONE,
            MergePath(),
            FetchStepSelections.new_empty(),
            FetchStepSelections.new_empty(),
            FetchStepKind.ROOT,
            OperationKind.QUERY,
            FetchStepFlags.EMPTY,
            Cond.none(),
            NONE,
        )
    )
    graph.root_index = root
    return root
