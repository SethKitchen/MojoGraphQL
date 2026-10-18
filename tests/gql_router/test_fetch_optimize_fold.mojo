# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the pass that folds object selections into an interface.

Hive Router `1a29df9` `bin/router/src/query_planner/planner/fetch/
optimize/fold_concrete_selections_to_interfaces.rs` has no tests of its
own; `issues.rs` checks it on one plan. Each test here folds one selection
set of the `fetch_shapes` supergraph, where `Book` and `Movie` implement
`Media` and make up `Item`, and `Song`, `Album` and `Single` implement
`Track`.
"""

from _fixtures import fetch_shapes
from _plan_harness import _plan
from gql_language.parser import parse
from gql_router.ast import Cond
from gql_router.fetch_optimize_fold import ObjectTypeBranch, StepConverter
from gql_router.fetch_optimize_types import subgraph_of
from gql_router.fetch_step import QueryPlannerOptions
from gql_router.graph import PlannerOverrideContext
from gql_router.normalize import selection_set_from_text
from gql_router.selection_set import set_text
from gql_router.store import Store
from gql_router.subgraph_state import decompose_all
from gql_router.supergraph_state import new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _fold(
    type_name: String, query: String, fold: Bool = False
) raises -> String:
    """Fold a set of a type in the `media` subgraph and print it."""
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var subgraphs = decompose_all(state)
    var media = subgraph_of(state, subgraphs, store.sym("media"))
    var set = selection_set_from_text(store, query)
    _ = StepConverter(fold).rewrite_selection_set(
        store, state, subgraphs[media], store.sym(type_name), set
    )
    return set_text(store, set)


def test_folds_into_the_type_of_the_set() raises:
    assert_equal(
        _fold("Media", "{ ... on Book { id } ... on Movie { id } }"), "{id}"
    )


def test_folds_a_shared_condition_onto_the_interface() raises:
    assert_equal(
        _fold(
            "Media",
            (
                "{ ... on Book @include(if: $x) { id }"
                " ... on Movie @include(if: $x) { id } }"
            ),
        ),
        "{...on Media @include(if: $x){id}}",
    )


def test_folds_a_union_into_an_interface_of_its_members() raises:
    var query = "{ __typename ... on Book { id } ... on Movie { id } }"
    assert_equal(_fold("Item", query, True), "{__typename ...on Media{id}}")
    # Without abstract type folding, only the union itself is tried.
    assert_equal(
        _fold("Item", query), "{__typename ...on Book{id} ...on Movie{id}}"
    )


def test_does_not_fold() raises:
    var cases: List[String] = [
        # The conditions differ.
        "{ ... on Book @include(if: $x) { id } ... on Movie { id } }",
        # A branch is not an object type.
        "{ ... on Book { id } ... on Media { id } }",
        # The fields differ.
        "{ ... on Book { id } ... on Movie { title } }",
        # The interface does not have the field.
        "{ ... on Book { shared } ... on Movie { shared } }",
        # A fragment does not fit its parent type.
        (
            "{ ... on Book { shelf { ... on Book { id } } }"
            " ... on Movie { shelf { ... on Book { id } } } }"
        ),
    ]
    for query in cases:
        var folded = _fold("Media", query)
        assert_true(folded.startswith("{...on Book"), folded)
    # Not every member of `Track` is there.
    assert_equal(
        _fold("Track", "{ ... on Song { id } ... on Album { id } }"),
        "{...on Song{id} ...on Album{id}}",
    )
    # The first branch of a union is an interface.
    assert_equal(
        _fold("Item", "{ ... on Media { id } ... on Book { id } }", True),
        "{...on Media{id} ...on Book{id}}",
    )


def test_folds_nested_fragments_that_fit() raises:
    assert_equal(
        _fold(
            "Media",
            (
                "{ ... on Book { shelf { media { ... on Book { id } } } }"
                " ... on Movie { shelf { media { ... on Book { id } } } } }"
            ),
        ),
        "{shelf{media{...on Book{id}}}}",
    )


def test_unknown_fields_and_spreads_raise() raises:
    var message = String()
    try:
        _ = _fold("Media", "{ ... on Book { shelf { pages } } }")
    except e:
        message = String(e)
    assert_equal(
        message,
        "Internal Error: No field found for name 'pages' in type 'Shelf'",
    )
    try:
        _ = _fold("Media", "{ ...Parts }")
    except e:
        message = String(e)
    assert_equal(
        message,
        (
            "Internal Error: fragment spreads should have been inlined before"
            " abstract type conversion"
        ),
    )


def test_plans_with_abstract_type_folding() raises:
    var plan = _plan(
        fetch_shapes.sdl(),
        "{ items { ... on Book { id } ... on Movie { id } } }",
        PlannerOverrideContext.default(),
        QueryPlannerOptions(True),
    )
    assert_true("... on Media {" in plan, plan)
    assert_false("... on Book" in plan, plan)


def test_does_not_fold_what_the_subgraph_cannot_select() raises:
    var cases: List[String] = [
        # `label` is a field of `Shelf` in the other subgraph only.
        "{ ... on Book { shelf { label } } ... on Movie { shelf { label } } }",
        (
            "{ ... on Book { shelf { ... on Shelf { label } } }"
            " ... on Movie { shelf { ... on Shelf { label } } } }"
        ),
    ]
    for query in cases:
        var folded = _fold("Media", query)
        assert_true(folded.startswith("{...on Book"), folded)
    assert_equal(
        _fold(
            "Media",
            "{ ... on Book { __typename id } ... on Movie { __typename id } }",
        ),
        "{__typename id}",
    )


def _branch(mut store: Store, name: String, set: Int) -> ObjectTypeBranch:
    return ObjectTypeBranch(store.sym(name), set, Cond.none(), 0)


def test_fold_checks_on_branches_made_by_hand() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(fetch_shapes.sdl()))
    var subgraphs = decompose_all(state)
    ref media = subgraphs[subgraph_of(state, subgraphs, store.sym("media"))]
    var converter = StepConverter(True)
    var ids = selection_set_from_text(store, "{ id }")
    var titles = selection_set_from_text(store, "{ title }")
    var book = _branch(store, "Book", ids)
    var movie = _branch(store, "Movie", titles)
    # The first branch is not a known object, implements nothing, or
    # implements its interface only in another subgraph.
    for first in ["Nope", "Shelf", "Podcast"]:
        var branches: List[ObjectTypeBranch] = [
            _branch(store, first, ids),
            book,
        ]
        assert_false(
            converter.try_fold_into_any_matching_interface(
                store, state, media, branches
            ).found
        )
    # No interface of `Book` takes both sets.
    var different: List[ObjectTypeBranch] = [book, movie]
    assert_false(
        converter.try_fold_into_any_matching_interface(
            store, state, media, different
        ).found
    )
    var same: List[ObjectTypeBranch] = [book, _branch(store, "Movie", ids)]
    # Not an interface of this subgraph, no member, or no member here.
    for interface in ["Extra", "Lonely", "Remote"]:
        assert_false(
            converter.try_fold_into_interface(
                store, state, media, store.sym(interface), same
            ).found
        )
    # A branch type of another subgraph.
    var elsewhere: List[ObjectTypeBranch] = [
        book,
        _branch(store, "Podcast", ids),
    ]
    assert_false(
        converter.try_fold_into_interface(
            store, state, media, store.sym("Media"), elsewhere
        ).found
    )
    var interface = store.sym("Media")
    assert_false(
        converter.object_is_interface_member_in_subgraph(
            state, media, store.sym("Nope"), interface
        )
    )
    assert_false(
        converter.object_is_interface_member_in_subgraph(
            state, media, store.sym("Track"), interface
        )
    )
    assert_false(
        converter.object_is_interface_member_in_subgraph(
            state, media, store.sym("Podcast"), interface
        )
    )
    assert_false(
        converter.object_is_interface_member_in_subgraph(
            state, media, store.sym("Shelf"), interface
        )
    )
    assert_true(
        converter.object_is_interface_member_in_subgraph(
            state, media, store.sym("Book"), interface
        )
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
