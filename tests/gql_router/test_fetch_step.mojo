# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for fetch steps and the fetch graph.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/fetch/selections.rs`. The fetch
graph tests check the `petgraph` `StableDiGraph` behavior the planner
depends on.
"""

from gql_router.ast import NONE, Cond
from gql_router.federation_spec import OperationKind
from gql_router.fetch_step import (
    FetchGraph,
    FetchNodePathSegment,
    FetchRewrite,
    FetchStepData,
    FetchStepFlags,
    FetchStepKind,
    FetchStepSelections,
)
from gql_router.merge_path import MergePath, Segment
from gql_router.normalize import selection_set_from_text
from gql_router.selection_set import pretty_set
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _multi_type(mut store: Store, query: String) raises -> FetchStepSelections:
    var parsed = selection_set_from_text(store, query)
    var selections = FetchStepSelections.new_empty()
    for item in store.children(parsed):
        var type_name = store.items[item].name
        selections.declare_known_type(store, type_name)
        var set = selections.selections_for_definition(type_name)
        store.items[item].next = NONE
        store.append(set, item)
    return selections^


def _pretty(mut store: Store, selections: FetchStepSelections) -> String:
    var set = selections.to_non_root_selection_set(store)
    var out = String()
    pretty_set(store, out, set, 0)
    return out^


def test_lifts_single_conditional_fragment_without_extra_nesting() raises:
    var store = Store()
    var selections = _multi_type(
        store, "{ ... on Book @skip(if: $title) { sku } }"
    )
    assert_equal(
        _pretty(store, selections),
        "... on Book @skip(if: $title) {\n  sku\n}\n",
    )


def test_lifts_shared_condition_from_multiple_fragments() raises:
    var store = Store()
    var selections = _multi_type(
        store,
        (
            "{ ... on Book @include(if: $x) { title }"
            " ... on Book @include(if: $x) { author } }"
        ),
    )
    assert_equal(
        _pretty(store, selections),
        (
            "... on Book @include(if: $x) {\n  ... on Book {\n    title\n  }\n"
            "  ... on Book {\n    author\n  }\n}\n"
        ),
    )


def test_does_not_lift_when_conditions_are_mixed() raises:
    var store = Store()
    var selections = _multi_type(
        store, "{ ... on Book @include(if: $x) { title } ... on Book { sku } }"
    )
    assert_equal(
        _pretty(store, selections),
        (
            "... on Book {\n  ... on Book @include(if: $x) {\n    title\n  }\n"
            "  ... on Book {\n    sku\n  }\n}\n"
        ),
    )


def test_does_not_lift_when_top_level_fragments_have_different_types() raises:
    var store = Store()
    var selections = _multi_type(
        store,
        (
            "{ ... on Book @include(if: $x) { title }"
            " ... on Magazine @include(if: $x) { sku } }"
        ),
    )
    assert_equal(
        _pretty(store, selections),
        (
            "... on Book @include(if: $x) {\n  title\n}\n"
            "... on Magazine @include(if: $x) {\n  sku\n}\n"
        ),
    )


def _step(mut store: Store, graph: FetchGraph, name: String) -> FetchStepData:
    return FetchStepData(
        graph.create_fetch_id(),
        store.sym(name),
        MergePath(),
        FetchStepSelections.new(store, store.sym("Query")),
        FetchStepSelections.new(store, store.sym("Query")),
        FetchStepKind.ROOT,
        OperationKind.QUERY,
        FetchStepFlags.EMPTY,
        Cond.none(),
        NONE,
    )


def test_fetch_graph_reuses_the_last_freed_slot() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var root = graph.add_step(_step(store, graph, "root"))
    var a = graph.add_step(_step(store, graph, "a"))
    var b = graph.add_step(_step(store, graph, "b"))
    _ = graph.connect(root, a)
    _ = graph.connect(root, b)
    assert_equal(graph.connect(root, a), graph.find_edge(root, a))
    # Newest edge first.
    assert_equal(graph.child_steps(root)[0], b)
    assert_true(graph.is_descendant_of(b, root))
    assert_false(graph.is_descendant_of(root, b))
    assert_true(graph.remove_step(a))
    assert_false(graph.remove_step(a))
    assert_equal(len(graph.child_steps(root)), 1)
    var c = graph.add_step(_step(store, graph, "c"))
    assert_equal(c, a)
    assert_equal(graph.bfs_order(root)[0], root)
    assert_equal(len(graph.roots()), 2)


def test_kinds_and_flags_are_valid() raises:
    assert_true(FetchStepKind.ENTITY.is_valid())
    assert_true(FetchStepKind.ROOT.is_valid())
    assert_false(FetchStepKind(2).is_valid())
    var flags = FetchStepFlags.USED_FOR_REQUIRES.with_flag(
        FetchStepFlags.USED_FOR_TYPE_CONDITION
    )
    assert_true(flags.is_valid())
    assert_false(FetchStepFlags(4).is_valid())


def _single(
    mut store: Store, type_name: String, query: String
) raises -> FetchStepSelections:
    var out = FetchStepSelections.new(store, store.sym(type_name))
    out.add(store, selection_set_from_text(store, query))
    return out^


def test_selections_of_a_missing_type() raises:
    var store = Store()
    var selections = _single(store, "Book", "{ id }")
    assert_equal(selections.definition_name(), store.sym("Book"))
    var other = selection_set_from_text(store, "{ id }")
    assert_true(selections.contains(store, store.sym("Book"), other))
    assert_false(selections.contains(store, store.sym("Film"), other))
    var message = String()
    try:
        selections.add_at_path_inner(
            store, store.sym("Film"), MergePath(), other, False
        )
    except e:
        message = String(e)
    assert_equal(message, "Unexpected missing definition: Film")
    var path = MergePath(
        [Segment.field(store.sym("author"), NONE, NONE, Cond.none())]
    )
    try:
        selections.add_at_path(store, path, other)
    except e:
        message = String(e)
    assert_equal(
        message,
        "Path 'author' cannot be found in selection set of type Book",
    )


def test_empty_selections() raises:
    var store = Store()
    var empty = FetchStepSelections.new_empty()
    assert_true(empty.is_empty(store))
    assert_false(
        empty.take_shared_top_level_fragment_condition(store).is_some()
    )
    var copy = empty.copy_into(store)
    assert_equal(len(copy.sets), 0)
    var target = _single(store, "Book", "{ id }")
    target.migrate_from_another(store, empty, MergePath())
    target.wrap_with_condition_for_types(
        store, Cond(store.sym("x"), NONE), List[Int]()
    )
    assert_equal(target.text(store), "{id}")


def test_shared_top_level_fragment_condition() raises:
    var store = Store()
    # Two types under different conditions share none.
    var mixed = _multi_type(
        store,
        (
            "{ ... on Book @include(if: $x) { title }"
            " ... on Film @include(if: $y) { title } }"
        ),
    )
    assert_false(
        mixed.take_shared_top_level_fragment_condition(store).is_some()
    )
    # A fragment with no condition, or on another type, shares none.
    var plain = _single(store, "Book", "{ ... on Book { title } }")
    assert_false(
        plain.take_shared_top_level_fragment_condition(store).is_some()
    )
    var other = _single(
        store, "Book", "{ ... on Film @include(if: $x) { title } }"
    )
    assert_false(
        other.take_shared_top_level_fragment_condition(store).is_some()
    )
    # Two fragments with one condition share it, and lose it.
    var shared = _single(
        store,
        "Book",
        (
            "{ ... on Book @include(if: $x) { title }"
            " ... on Book @include(if: $x) { sku } }"
        ),
    )
    var cond = shared.take_shared_top_level_fragment_condition(store)
    assert_true(cond == Cond(NONE, store.sym("x")))
    assert_equal(shared.text(store), "{...on Book{title} ...on Book{sku}}")


def test_wrap_in_type_fragments_keeps_unliftable_sets() raises:
    var store = Store()
    var empty = FetchStepSelections.new(store, store.sym("Book"))
    assert_equal(_pretty(store, empty), "... on Book {\n}\n")
    var plain = _single(store, "Book", "{ ... on Book { title } }")
    assert_equal(
        _pretty(store, plain),
        "... on Book {\n  ... on Book {\n    title\n  }\n}\n",
    )
    var other = _single(
        store, "Book", "{ ... on Film @include(if: $x) { title } }"
    )
    assert_equal(
        _pretty(store, other),
        "... on Book {\n  ... on Film @include(if: $x) {\n    title\n  }\n}\n",
    )


def test_to_root_selection_set_wraps_other_types() raises:
    var store = Store()
    var query = store.sym("Query")
    var root = _single(store, "Query", "{ me }")
    var out = String()
    pretty_set(store, out, root.to_root_selection_set(store, query), 0)
    assert_equal(out, "me\n")
    var book = _single(store, "Book", "{ id }")
    out = String()
    pretty_set(store, out, book.to_root_selection_set(store, query), 0)
    assert_equal(out, "... on Book {\n  id\n}\n")
    var two = _multi_type(store, "{ ... on Query { me } ... on Book { id } }")
    out = String()
    pretty_set(store, out, two.to_root_selection_set(store, query), 0)
    assert_equal(
        out,
        (
            "... on Book {\n  ... on Book {\n    id\n  }\n}\n"
            "... on Query {\n  ... on Query {\n    me\n  }\n}\n"
        ),
    )


def test_step_rewrites_and_text() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var step = _step(store, graph, "a")
    var a = FetchRewrite(True, List[FetchNodePathSegment](), store.sym("A"))
    var b = FetchRewrite(True, List[FetchNodePathSegment](), store.sym("B"))
    step.add_input_rewrite(a.copy())
    step.add_input_rewrite(b.copy())
    step.add_input_rewrite(a.copy())
    assert_equal(len(step.input_rewrites), 2)
    step.add_output_rewrite(a.copy())
    step.add_output_rewrite(a.copy())
    assert_equal(len(step.output_rewrites), 1)
    step.condition = Cond(store.sym("s"), NONE)
    assert_equal(
        step.text(store), "[a]: Query/ -> Query/ at $. [@skip(if: $s)]"
    )
    step.condition = Cond(store.sym("s"), store.sym("i"))
    assert_equal(
        step.text(store),
        "[a]: Query/ -> Query/ at $. [@skip(if: $s) @include(if: $i)]",
    )
    var anywhere = FetchStepData(
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
    assert_equal(anywhere.text(store), "[]: -> at $.")


def test_fetch_graph_edges_and_errors() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    assert_equal(len(graph.step_indices()), 0)
    graph.collect_variable_usages(store)
    assert_equal(
        graph.text(store),
        "Nodes:\n\nTree:\nFetch step graph is empty or has no roots.\n",
    )
    var message = String()
    try:
        _ = graph.step(3)
    except e:
        message = String(e)
    assert_equal(message, "Missing FetchStep: 3 when getting step data")
    assert_equal(len(graph.bfs_order(3)), 0)
    assert_false(graph.is_condition_on_step(3, NONE, Cond.none()))
    var root = graph.add_step(_step(store, graph, "root"))
    assert_equal(graph.text(store), "Nodes:\n\nTree:\n")
    var a = graph.add_step(_step(store, graph, "a"))
    var b = graph.add_step(_step(store, graph, "b"))
    var c = graph.add_step(_step(store, graph, "c"))
    assert_true("multiple roots" in graph.text(store))
    var edge = graph.connect(root, a)
    _ = graph.connect(root, b)
    _ = graph.connect(a, c)
    _ = graph.connect(b, c)
    # `c` is reached twice.
    assert_true(graph.is_descendant_of(c, root))
    assert_equal(len(graph.bfs_order(root)), 4)
    var d = graph.add_step(_step(store, graph, "d"))
    assert_false(graph.is_descendant_of(d, root))
    assert_false(graph.remove_edge(-1))
    assert_false(graph.remove_edge(100))
    assert_true(graph.remove_edge(edge))
    assert_false(graph.remove_edge(edge))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
