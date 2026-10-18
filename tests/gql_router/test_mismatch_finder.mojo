# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the response shape mismatch finder.

Upstream `bin/router/src/query_planner/ast/mismatch_finder.rs` has no tests
of its own. Upstream panics where this port raises; the messages are the
upstream panic messages.
"""

from _infra_supergraph import sdl
from gql_language.parser import parse
from gql_router.fetch_step import FetchStepSelections
from gql_router.mismatch_finder import find_mismatches_in_node
from gql_router.normalize import selection_set_from_text
from gql_router.store import Store
from gql_router.subgraph_state import SubgraphState, decompose_from_supergraph
from gql_router.supergraph_state import SupergraphState, new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_raises


def _find(
    mut store: Store,
    supergraph: SupergraphState,
    subgraph: SubgraphState,
    type_name: String,
    text: String,
) raises -> Int:
    """Return how many mismatches a selection set of a type has."""
    var selections = FetchStepSelections(
        [store.sym(type_name)], [selection_set_from_text(store, text)]
    )
    return len(find_mismatches_in_node(store, supergraph, subgraph, selections))


def test_mismatches_and_missing_parts() raises:
    var store = Store()
    var supergraph = new_supergraph_state(store, parse(sdl()))
    var a = decompose_from_supergraph(supergraph, store.sym("A"))
    assert_equal(
        len(
            find_mismatches_in_node(
                store, supergraph, a, FetchStepSelections.new_empty()
            )
        ),
        0,
    )
    assert_equal(
        _find(store, supergraph, a, "Query", "{ pet { name name: age } }"), 1
    )
    # A scalar has no definition to visit below it.
    assert_equal(_find(store, supergraph, a, "Query", "{ name { x } }"), 0)
    with assert_raises(contains="Missing definition 'Nope'"):
        _ = _find(store, supergraph, a, "Nope", "{ a }")
    with assert_raises(contains="Missing definition 'Nope'"):
        _ = _find(store, supergraph, a, "Query", "{ ... on Nope { a } }")
    with assert_raises(contains="Missing field 'nope'"):
        _ = _find(store, supergraph, a, "Query", "{ nope }")
    with assert_raises(contains="fragment spread is not expected"):
        _ = _find(store, supergraph, a, "Query", "{ ...F }")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
