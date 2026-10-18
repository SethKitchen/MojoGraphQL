# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for cutting a subgraph out of the supergraph.

Upstream `bin/router/src/query_planner/state/subgraph_state.rs` has no tests
of its own. The cases follow its `decompose_from_supergraph`.
"""

from _infra_supergraph import sdl
from gql_language.parser import parse
from gql_router.ast import NONE
from gql_router.store import Store
from gql_router.subgraph_state import decompose_all, decompose_from_supergraph
from gql_router.supergraph_state import new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_enum_and_union_without_values_are_left_out() raises:
    var store = Store()
    var supergraph = new_supergraph_state(store, parse(sdl()))
    var b = decompose_from_supergraph(supergraph, store.sym("B"))
    assert_equal(b.definition(store.sym("Kind")), NONE)
    assert_equal(b.definition(store.sym("Any")), NONE)
    assert_true(b.definition(store.sym("Query")) != NONE)


def test_union_members_are_kept_once() raises:
    var store = Store()
    var supergraph = new_supergraph_state(store, parse(sdl()))
    var a = decompose_from_supergraph(supergraph, store.sym("A"))
    ref any = a.definitions[a.definition(store.sym("Any"))]
    assert_equal(len(any.types), 1)
    ref kind = a.definitions[a.definition(store.sym("Kind"))]
    assert_equal(len(kind.types), 1)
    ref pet = a.definitions[a.definition(store.sym("Pet"))]
    assert_true(pet.is_entity_type())
    assert_false(any.is_entity_type())
    assert_equal(pet.field(store.sym("nope")), NONE)
    assert_equal(len(a.entity_type_names), 1)
    assert_equal(len(decompose_all(supergraph)), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
