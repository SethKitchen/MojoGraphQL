# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the fetch graph optimizer.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/optimize/utils.rs`,
`batch_multi_type.rs` and `normalize_selection_sets.rs`, and checks each
pass on small fetch graphs built by hand.
"""

from gql_router.ast import NONE, Cond
from gql_router.federation_spec import OperationKind
from gql_router.fetch_optimize_merge import (
    can_merge_passthrough_child,
    deduplicate_and_prune_fetch_steps,
    merge_children_with_parents,
    merge_leafs,
    merge_passthrough_child,
    merge_siblings,
    turn_mutations_into_sequence,
)
from gql_router.fetch_optimize_utils import (
    MergedSteps,
    can_merge,
    perform_fetch_step_merge,
)
from gql_router.fetch_step import (
    FetchGraph,
    FetchStepData,
    FetchStepFlags,
    FetchStepKind,
    FetchStepSelections,
)
from gql_language.parser import parse
from gql_router.fetch_optimize import optimize_fetch_graph
from gql_router.fetch_optimize_batch import merge_batched_response_paths
from gql_router.fetch_optimize_types import normalize_selection_set
from gql_router.merge_path import MergePath, Segment
from gql_router.normalize import selection_set_from_text
from gql_router.selection_set import set_text
from gql_router.store import Store
from gql_router.supergraph_state import new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _selections(
    mut store: Store, types: List[String], queries: List[String]
) raises -> FetchStepSelections:
    """Selections for one or more types, as upstream `selections`."""
    var out = FetchStepSelections.new_empty()
    for index in range(len(types)):
        var type_name = store.sym(types[index])
        out.declare_known_type(store, type_name)
        var parsed = selection_set_from_text(store, queries[index])
        out.add_at_path_inner(store, type_name, MergePath(), parsed, False)
    return out^


def _path(mut store: Store, fields: List[String]) -> MergePath:
    """A path of fields, with `@` for a list step."""
    var segments = List[Segment]()
    for name in fields:
        if name == "@":
            segments.append(Segment.list())
        else:
            segments.append(
                Segment.field(store.sym(name), NONE, NONE, Cond.none())
            )
    return MergePath(segments^)


def _entity_step(
    mut store: Store,
    service: String,
    var path: MergePath,
    var input: FetchStepSelections,
    var output: FetchStepSelections,
) -> FetchStepData:
    """An entity call, as upstream `entity_step`."""
    return FetchStepData(
        0,
        store.sym(service),
        path^,
        input^,
        output^,
        FetchStepKind.ENTITY,
        OperationKind.QUERY,
        FetchStepFlags.EMPTY,
        Cond.none(),
        NONE,
    )


def test_multi_type_parent_does_not_absorb_nested_call() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var parent = graph.add_step(
        _entity_step(
            store,
            "orders",
            _path(store, ["accounts", "@"]),
            _selections(
                store,
                ["User", "Admin"],
                ["{ __typename id }", "{ __typename id }"],
            ),
            _selections(
                store,
                ["User", "Admin"],
                [
                    "{ orders { __typename id } }",
                    "{ orders { __typename id } }",
                ],
            ),
        )
    )
    var child = graph.add_step(
        _entity_step(
            store,
            "orders",
            _path(store, ["accounts", "@", "orders", "@"]),
            _selections(store, ["Order"], ["{ __typename id }"]),
            _selections(store, ["Order"], ["{ sku }"]),
        )
    )
    _ = graph.connect(parent, child)
    assert_false(can_merge(store, graph, parent, child))


def test_same_type_entity_calls_at_unrelated_paths_do_not_merge() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var a = graph.add_step(
        _entity_step(
            store,
            "catalog",
            _path(store, ["a", "@"]),
            _selections(store, ["Order"], ["{ __typename id }"]),
            _selections(store, ["Order"], ["{ name }"]),
        )
    )
    var b = graph.add_step(
        _entity_step(
            store,
            "catalog",
            _path(store, ["b", "@"]),
            _selections(store, ["Order"], ["{ __typename id }"]),
            _selections(store, ["Order"], ["{ name }"]),
        )
    )
    var message = String()
    try:
        perform_fetch_step_merge(store, a, b, graph, False)
    except e:
        message = String(e)
    assert_equal(
        message, "Input types are equal but response_path are different!"
    )


def test_merged_steps_follow_the_whole_chain() raises:
    var merged = MergedSteps()
    merged.record(98, 144)
    merged.record(144, 104)
    assert_equal(merged.resolve(98), 104)
    assert_equal(merged.resolve(144), 104)
    assert_equal(merged.resolve(104), 104)
    assert_equal(merged.resolve(3), 3)


def test_passthrough_needs_every_type_covered() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var parent = graph.add_step(
        _entity_step(
            store,
            "accounts",
            _path(store, ["accounts", "@"]),
            _selections(store, ["User"], ["{ __typename id }"]),
            _selections(store, ["User"], ["{ id }"]),
        )
    )
    var child = graph.add_step(
        _entity_step(
            store,
            "accounts",
            _path(store, ["accounts", "@"]),
            _selections(
                store,
                ["User", "Admin"],
                ["{ __typename id }", "{ __typename id }"],
            ),
            _selections(store, ["User", "Admin"], ["{ id }", "{ name }"]),
        )
    )
    _ = graph.connect(parent, child)
    assert_false(can_merge_passthrough_child(store, graph, parent, child))


# --- batch_multi_type.rs ----------------------------------------------------


def _products_path(
    mut store: Store, type_names: List[String], condition: Cond
) -> MergePath:
    """`products.@|[types] condition.reviews.@.product`; no type condition
    when `type_names` is empty."""
    var segments = List[Segment]()
    segments.append(
        Segment.field(store.sym("products"), NONE, NONE, Cond.none())
    )
    segments.append(Segment.list())
    if len(type_names) > 0:
        var names = List[Int]()
        for name in type_names:
            names.append(store.sym(name))
        segments.append(
            Segment.type_condition(store.type_set(names), condition)
        )
    segments.append(
        Segment.field(store.sym("reviews"), NONE, NONE, Cond.none())
    )
    segments.append(Segment.list())
    segments.append(
        Segment.field(store.sym("product"), NONE, NONE, Cond.none())
    )
    return MergePath(segments^)


def _possible_at_2(mut store: Store, names: List[String]) -> List[Int]:
    """Possible types at slot 2 only."""
    var out = List[Int](length=7, fill=NONE)
    var symbols = List[Int]()
    for name in names:
        symbols.append(store.sym(name))
    out[2] = store.type_set(symbols)
    return out^


def test_keeps_condition_of_type_condition() raises:
    var store = Store()
    var condition = Cond(NONE, store.sym("a"))
    var me = _products_path(store, ["Book"], condition)
    var other = _products_path(store, ["Book"], condition)
    var merged = merge_batched_response_paths(
        store, me, other, List[Int](length=7, fill=NONE)
    )
    assert_true(merged == me)


def test_keeps_exhaustive_type_list_with_condition() raises:
    var store = Store()
    var condition = Cond(NONE, store.sym("a"))
    var me = _products_path(store, ["Book"], condition)
    var other = _products_path(store, ["User"], condition)
    var possible = _possible_at_2(store, ["Book", "User"])
    var merged = merge_batched_response_paths(store, me, other, possible)
    assert_true(merged == _products_path(store, ["Book", "User"], condition))


def test_keeps_non_exhaustive_type_list_in_flatten_path() raises:
    var store = Store()
    var me = _products_path(store, ["Book"], Cond.none())
    var other = _products_path(store, ["User"], Cond.none())
    var possible = _possible_at_2(store, ["Book", "User", "Magazine"])
    var merged = merge_batched_response_paths(store, me, other, possible)
    assert_true(merged == _products_path(store, ["Book", "User"], Cond.none()))


def test_strips_type_list_when_type_conditions_are_exhaustive() raises:
    var store = Store()
    var me = _products_path(store, ["Book"], Cond.none())
    var other = _products_path(store, ["User"], Cond.none())
    var possible = _possible_at_2(store, ["Book", "User"])
    var merged = merge_batched_response_paths(store, me, other, possible)
    assert_true(merged == _products_path(store, List[String](), Cond.none()))


# --- normalize_selection_sets.rs --------------------------------------------


def test_ensure_deduplication() raises:
    var store = Store()
    var sdl = String(
        "directive @join__type(graph: join__Graph!, key: join__FieldSet)"
        " repeatable on OBJECT\n"
        "scalar join__FieldSet\n"
        'enum join__Graph { A @join__graph(name: "a", url: "") }\n'
        "type Query @join__type(graph: A) { user: User }\n"
        "type User @join__type(graph: A) { id: ID! name: String! }\n"
    )
    var state = new_supergraph_state(store, parse(sdl))
    var set = selection_set_from_text(store, "{ id ... on User { id } }")
    normalize_selection_set(store, state, store.sym("User"), set)
    assert_equal(set_text(store, set), "{id}")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
