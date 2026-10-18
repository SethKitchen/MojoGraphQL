# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the merge checks of the fetch graph optimizer.

Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/optimize/utils.rs` has no
tests for these functions; its query plan tests cover them. Each test here
checks one rule on a fetch graph built by hand.
"""

from _fetch_steps import entity_step, noop_root, path, root_step, selections
from gql_router.ast import NONE, Cond
from gql_router.federation_spec import OperationKind
from gql_router.fetch_optimize_utils import (
    can_absorb_nested_entity_call,
    can_merge,
    check_pair,
    is_reachable_via_alternative_upstream_path,
    perform_fetch_step_merge,
    require_step,
    root_index_of,
)
from gql_router.fetch_step import FetchGraph
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _error_of_pair(graph: FetchGraph, a: Int, b: Int) -> String:
    try:
        check_pair(graph, a, b)
    except e:
        return String(e)
    return String()


def test_missing_and_equal_steps_raise() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var message = String()
    try:
        _ = root_index_of(graph)
    except e:
        message = String(e)
    assert_equal(message, "Expected to have one root step, but found: 0")
    var a = graph.add_step(root_step(store, "s"))
    assert_equal(_error_of_pair(graph, a, a), "Expected different indexes: 0")
    assert_equal(
        _error_of_pair(graph, a, 5),
        "Missing FetchStep: 5 when checking existence",
    )
    assert_equal(
        _error_of_pair(graph, 5, a),
        "Missing FetchStep: 5 when checking existence",
    )
    try:
        require_step(graph, 7)
    except e:
        message = String(e)
    assert_equal(message, "Missing FetchStep: 7 when getting step data")


def test_merge_rejects_other_types_at_one_place() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var target = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a", "@"]),
            selections(store, ["Book"], ["{ __typename id }"]),
            selections(store, ["Book"], ["{ title }"]),
        )
    )
    var source = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a", "@"]),
            selections(store, ["Film"], ["{ __typename id }"]),
            selections(store, ["Film"], ["{ title }"]),
        )
    )
    var message = String()
    try:
        perform_fetch_step_merge(store, target, source, graph, False)
    except e:
        message = String(e)
    assert_equal(
        message,
        (
            "Internal Error: can't merge the `Film` fields of step [1] into"
            " the `Book` fields of step [0]"
        ),
    )


def test_merge_keeps_the_condition_of_a_root_source() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    var target = graph.add_step(root_step(store, "s", "{ a }"))
    var source = graph.add_step(
        root_step(store, "s", "{ b }", Cond(store.sym("x"), NONE))
    )
    _ = graph.connect(root, target)
    _ = graph.connect(root, source)
    perform_fetch_step_merge(store, target, source, graph, False)
    assert_true("@skip(if: $x)" in graph.steps[target].output.text(store))
    assert_false(graph.contains_step(source))


def test_can_absorb_nested_entity_call() raises:
    var store = Store()
    var step = entity_step(
        store,
        "s",
        path(store, ["a", "@"]),
        selections(store, ["Book"], ["{ __typename id }"]),
        selections(store, ["Book"], ["{ author { __typename id } }"]),
    )
    var nested = entity_step(
        store,
        "s",
        path(store, ["a", "@", "author"]),
        selections(store, ["Author"], ["{ __typename id }"]),
        selections(store, ["Author"], ["{ name }"]),
    )
    assert_true(can_absorb_nested_entity_call(store, step, nested))
    var elsewhere = entity_step(
        store,
        "s",
        path(store, ["z"]),
        selections(store, ["Author"], ["{ __typename id }"]),
        selections(store, ["Author"], ["{ name }"]),
    )
    assert_false(can_absorb_nested_entity_call(store, step, elsewhere))
    var two_types = entity_step(
        store,
        "s",
        path(store, ["a", "@", "author"]),
        selections(
            store, ["Author", "Editor"], ["{ __typename id }", "{ id }"]
        ),
        selections(store, ["Author"], ["{ name }"]),
    )
    assert_false(can_absorb_nested_entity_call(store, step, two_types))
    var missing = entity_step(
        store,
        "s",
        path(store, ["a", "@", "editor"]),
        selections(store, ["Author"], ["{ __typename id }"]),
        selections(store, ["Author"], ["{ name }"]),
    )
    assert_false(can_absorb_nested_entity_call(store, step, missing))


def test_can_merge_checks() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    var book = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a", "@"]),
            selections(store, ["Book"], ["{ __typename id }"]),
            selections(store, ["Book"], ["{ author { __typename id } }"]),
        )
    )
    var film = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a", "@"]),
            selections(store, ["Book"], ["{ __typename id }"]),
            selections(store, ["Film"], ["{ title }"]),
        )
    )
    var author = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a", "@", "author"]),
            selections(store, ["Author"], ["{ __typename id }"]),
            selections(store, ["Author"], ["{ name }"]),
        )
    )
    var editor = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a", "@", "editor"]),
            selections(store, ["Author"], ["{ __typename id }"]),
            selections(store, ["Author"], ["{ name }"]),
        )
    )
    _ = graph.connect(root, book)
    _ = graph.connect(root, film)
    _ = graph.connect(book, author)
    _ = graph.connect(book, editor)
    assert_false(can_merge(store, graph, book, book))
    # The same objects, but other output types.
    assert_false(can_merge(store, graph, book, film))
    # The only parent already holds the input of the nested call.
    assert_true(can_merge(store, graph, book, author))
    # It does not hold the input of this one.
    assert_false(can_merge(store, graph, book, editor))


def test_alternative_upstream_path_visits_each_step_once() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    var a = graph.add_step(root_step(store, "a"))
    var b = graph.add_step(root_step(store, "b"))
    var c = graph.add_step(root_step(store, "c"))
    var other = graph.add_step(root_step(store, "d"))
    _ = graph.connect(root, a)
    _ = graph.connect(root, b)
    _ = graph.connect(root, other)
    _ = graph.connect(a, c)
    _ = graph.connect(b, c)
    # Both parents lead up to the root, which is visited once.
    assert_false(is_reachable_via_alternative_upstream_path(graph, c, other))
    assert_true(is_reachable_via_alternative_upstream_path(graph, c, root))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
