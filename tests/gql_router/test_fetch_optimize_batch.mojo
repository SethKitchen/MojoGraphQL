# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the pass that batches entity calls by type condition.

`test_fetch_optimize.mojo` ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/optimize/batch_multi_type.rs`.
The tests here check the other rules of that file on the `fetch_shapes`
supergraph and on fetch graphs built by hand.
"""

from _fetch_steps import entity_step, noop_root, path, root_step, selections
from _fixtures import fetch_shapes
from gql_language.parser import parse
from gql_router.ast import NONE, Cond
from gql_router.federation_spec import OperationKind
from gql_router.fetch_optimize_batch import (
    batch_multi_type,
    can_be_batched_with,
    merge_batched_response_paths,
    possible_object_types,
    possible_types_by_position,
)
from gql_router.fetch_step import FetchGraph, FetchStepData
from gql_router.store import Store
from gql_router.supergraph_state import new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_possible_object_types() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var book = possible_object_types(store, state, store.sym("Book"))
    assert_equal(len(store.type_sets[book]), 1)
    var media = possible_object_types(store, state, store.sym("Media"))
    assert_equal(len(store.type_sets[media]), 3)
    var item = possible_object_types(store, state, store.sym("Item"))
    assert_equal(len(store.type_sets[item]), 2)
    assert_equal(possible_object_types(store, state, store.sym("Lonely")), NONE)
    assert_equal(possible_object_types(store, state, store.sym("Kind")), NONE)
    assert_equal(possible_object_types(store, state, store.sym("Nope")), NONE)


def test_possible_types_by_position() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var possible = possible_types_by_position(
        store,
        state,
        store.sym("Query"),
        path(store, ["media", "@", "|Book", "shelf", "nope", "name"]),
    )
    assert_equal(len(store.type_sets[possible[1]]), 3)
    assert_equal(len(store.type_sets[possible[3]]), 1)
    assert_equal(possible[4], NONE)
    assert_equal(possible[5], NONE)
    var scalar = possible_types_by_position(
        store, state, store.sym("Query"), path(store, ["kind"])
    )
    assert_equal(scalar[1], NONE)
    var empty = possible_types_by_position(
        store, state, store.sym("Query"), path(store, ["media", "|", "title"])
    )
    assert_equal(empty[2], NONE)


def test_merge_batched_response_paths() raises:
    var store = Store()
    var me = path(store, ["a", "@", "|Book"])
    # The paths differ outside type conditions.
    var far = merge_batched_response_paths(
        store, me, path(store, ["b", "@", "|Movie"]), List[Int]()
    )
    assert_true(far == me)
    # With no possible types known, the joined type condition stays.
    var joined = merge_batched_response_paths(
        store, me, path(store, ["a", "@", "|Movie"]), List[Int]()
    )
    assert_equal(joined.text(store), "a.@.|[Book|Movie]")
    # Only one path has a type condition, or both have empty ones.
    var one = merge_batched_response_paths(
        store, me, path(store, ["a", "@"]), List[Int]()
    )
    assert_equal(one.text(store), "a.@")
    var empty = merge_batched_response_paths(
        store, path(store, ["a", "|"]), path(store, ["a", "|"]), List[Int]()
    )
    assert_equal(empty.text(store), "a")
    # Two type conditions in a row keep the condition of the first one.
    var x = Cond(store.sym("x"), NONE)
    var stacked = merge_batched_response_paths(
        store,
        path(store, ["a", "|Book", "|Book"], x),
        path(store, ["a", "|Movie"], x),
        List[Int](),
    )
    assert_equal(stacked.text(store), "a.|[Book|Movie] @skip(if: $x)")


def _entity(
    mut store: Store, service: String, names: List[String]
) raises -> FetchStepData:
    return entity_step(
        store,
        service,
        path(store, names),
        selections(store, ["Book"], ["{ __typename id }"]),
        selections(store, ["Book"], ["{ title }"]),
    )


def test_can_be_batched_with() raises:
    var store = Store()
    var book = _entity(store, "s", ["a", "@", "|Book"])
    assert_true(
        can_be_batched_with(
            store, book, _entity(store, "s", ["a", "@", "|Film"])
        )
    )
    assert_false(can_be_batched_with(store, book, root_step(store, "s")))
    assert_false(
        can_be_batched_with(store, root_step(store, "s"), root_step(store, "s"))
    )
    # The type conditions are at other places.
    assert_false(
        can_be_batched_with(
            store,
            _entity(store, "s", ["a", "|Book", "@"]),
            _entity(store, "s", ["|Book", "a", "@"]),
        )
    )
    # Two type conditions in a row.
    assert_false(
        can_be_batched_with(
            store,
            _entity(store, "s", ["a", "|Book", "|Book"]),
            _entity(store, "s", ["a", "|Film", "|Film"]),
        )
    )


def test_batch_multi_type_needs_the_root_type() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var graph = FetchGraph(OperationKind.MUTATION)
    _ = noop_root(graph)
    var message = String()
    try:
        batch_multi_type(store, state, graph)
    except e:
        message = String(e)
    assert_equal(
        message,
        "Internal Error: Root type not found for operation kind: 'mutation'",
    )


def test_batch_multi_type_skips_merged_and_related_pairs() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    var x = Cond(store.sym("x"), NONE)
    var steps = List[Int]()
    for name in ["Book", "Film", "Song", "Album"]:
        var step = entity_step(
            store,
            "s",
            path(store, ["a", "@", "|" + name]),
            selections(store, [name], ["{ __typename id }"]),
            selections(store, [name], ["{ title }"]),
            x,
        )
        steps.append(graph.add_step(step^))
    # The children of the root come newest first.
    var at = len(steps) - 1
    while at >= 0:
        _ = graph.connect(root, steps[at])
        at -= 1
    # The last call also depends on the second one.
    _ = graph.connect(steps[1], steps[3])
    batch_multi_type(store, state, graph)
    assert_false(graph.contains_step(steps[1]))
    assert_false(graph.contains_step(steps[2]))
    assert_true(graph.contains_step(steps[3]))
    ref batched = graph.steps[steps[0]]
    assert_equal(batched.response_path.text(store), "a.@.|[Book|Film|Song]")
    # The condition moved into the output of each type.
    assert_false(batched.condition.is_some())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
