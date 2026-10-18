# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the selection set normalization and the type mismatch fix of
the fetch graph optimizer.

Hive Router `1a29df9` `bin/router/src/query_planner/planner/fetch/
optimize/type_mismatches.rs` has no tests of its own; its query plan tests
cover it. Each test here checks one rule on the `fetch_shapes` supergraph.
"""

from _fetch_steps import noop_root, path, root_step, selections
from _fixtures import fetch_shapes
from gql_language.parser import parse
from gql_router.ast import NONE, Cond
from gql_router.federation_spec import OperationKind
from gql_router.fetch_optimize_types import (
    alias_mismatch,
    fix_conflicting_type_mismatches,
    free_alias,
    normalize_selection_set,
    subgraph_of,
)
from gql_router.fetch_step import FetchGraph, FetchRewrite
from gql_router.merge_path import MergePath, Segment
from gql_router.mismatch_finder import Mismatch
from gql_router.normalize import selection_set_from_text
from gql_router.selection_set import set_text
from gql_router.store import Store
from gql_router.subgraph_state import SubgraphState, decompose_all
from gql_router.supergraph_state import new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_true


def _normalize_error(query: String) raises -> String:
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var set = selection_set_from_text(store, query)
    try:
        normalize_selection_set(store, state, store.sym("Media"), set)
    except e:
        return String(e)
    return String()


def test_normalize_rejects_unknown_fields_and_spreads() raises:
    assert_equal(
        _normalize_error("{ pages }"),
        "Internal Error: No field found for name 'pages' in type 'Media'",
    )
    assert_equal(
        _normalize_error("{ ...Parts }"),
        (
            "Internal Error: fragment spreads should have been inlined"
            " before selection-set normalization"
        ),
    )


def test_free_alias() raises:
    var store = Store()
    var empty = store.new_set()
    var first = store.sym("_internal_qp_alias_0")
    var second = store.sym("_internal_qp_alias_1")
    assert_equal(free_alias(store, empty, MergePath()), first)
    var set = selection_set_from_text(
        store, "{ media { ... on Book { _internal_qp_alias_0: id } } }"
    )
    assert_equal(
        free_alias(store, set, path(store, ["media", "|Book"])), second
    )
    assert_equal(free_alias(store, set, path(store, ["shelf"])), first)


def test_subgraph_of_unknown_names() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var subgraphs = decompose_all(state)
    assert_equal(subgraph_of(state, subgraphs, NONE), NONE)
    assert_equal(subgraph_of(state, subgraphs, store.sym("nope")), NONE)
    assert_equal(
        subgraph_of(state, List[SubgraphState](), store.sym("media")), NONE
    )


def test_alias_mismatch() raises:
    var store = Store()
    var output = selections(
        store,
        ["Query"],
        [
            "{ media { ... on Book { id } id price(c: 1)"
            " price(c: 2) @include(if: $x) price(c: 2) } }"
        ],
    )
    var media = store.children(output.sets[0])[0]
    var children = store.children(media)
    var args = store.items[children[len(children) - 1]].args
    var price = Segment.field(store.sym("price"), NONE, args, Cond.none())
    var query = store.sym("Query")
    var steps = List[Int]()
    var rewrites = List[FetchRewrite]()
    # Not a path to a field, or not a field that is there: no change.
    var none: List[Mismatch] = [
        Mismatch(query, MergePath()),
        Mismatch(query, path(store, ["media", "|Book"])),
        Mismatch(query, path(store, ["shelf", "price"])),
        Mismatch(query, MergePath([price])),
    ]
    for mismatch in none:
        alias_mismatch(store, output, mismatch, 3, steps, rewrites)
    assert_equal(len(steps), 0)
    var message = String()
    try:
        alias_mismatch(
            store,
            output,
            Mismatch(store.sym("Book"), MergePath([price])),
            3,
            steps,
            rewrites,
        )
    except e:
        message = String(e)
    assert_equal(message, "missing definition in step")
    alias_mismatch(
        store,
        output,
        Mismatch(query, path(store, ["media"]).push(price)),
        3,
        steps,
        rewrites,
    )
    assert_equal(len(steps), 1)
    assert_true(
        "_internal_qp_alias_0: price(c: 2)}" in set_text(store, output.sets[0])
    )


def test_fix_needs_the_state_of_each_subgraph() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    _ = graph.connect(root, graph.add_step(root_step(store, "nope")))
    var message = String()
    try:
        fix_conflicting_type_mismatches(
            store, state, decompose_all(state), graph
        )
    except e:
        message = String(e)
    assert_equal(message, "Missing subgraph state for step 1")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
