# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the supergraph and subgraph states.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/state/supergraph_state.rs` and
`state/subgraph_state.rs`.
"""

from _fixtures import override_requires, star_stuff
from gql_language.ast import Document
from gql_language.parser import parse
from gql_router.ast import NONE
from gql_router.federation_spec import OperationKind
from gql_router.store import Store
from gql_router.subgraph_state import SubgraphState, decompose_all
from gql_router.supergraph_state import (
    DefinitionKind,
    SupergraphState,
    new_supergraph_state,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def _resolvable_in(
    mut store: Store, state: SupergraphState, field: String
) -> String:
    var user = store.sym("User")
    var definition = state.definition(user)
    var index = state.field(user, store.sym(field))
    var out = String()
    for subgraph in state.definitions[definition].fields[index].resolvable_in:
        out += store.name(state.subgraph_names[subgraph])
    return out^


def test_resolvable_in_skips_external_fields() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(override_requires.sdl()))
    # No @join__field, so wherever `User` is.
    assert_equal(_resolvable_in(store, state, "id"), "abc")
    # External in `a` and `c`.
    assert_equal(_resolvable_in(store, state, "name"), "b")
    assert_equal(_resolvable_in(store, state, "aName"), "a")


def _fields_of(
    mut store: Store,
    state: SupergraphState,
    subgraphs: List[SubgraphState],
    subgraph: String,
    type_name: String,
) -> String:
    ref sub = subgraphs[state.subgraph_index(store.sym(subgraph))]
    var definition = sub.definition(store.sym(type_name))
    var out = List[String]()
    if definition >= 0:
        for field in sub.definitions[definition].fields:
            out.append(store.name(field.name))
    sort(out)
    return String(", ").join(out)


def _count_of(
    mut store: Store,
    state: SupergraphState,
    subgraphs: List[SubgraphState],
    subgraph: String,
) -> Int:
    return len(subgraphs[state.subgraph_index(store.sym(subgraph))].definitions)


def test_decompose_supergraph_into_subgraphs() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(star_stuff.sdl()))
    var subgraphs = decompose_all(state)
    assert_equal(len(subgraphs), 5)
    var names = List[String]()
    for name in state.subgraph_names:
        names.append(store.name(name))
    assert_equal(
        String(", ").join(names), "inventory, pandas, products, reviews, users"
    )
    # Query, Panda
    assert_equal(_count_of(store, state, subgraphs, "pandas"), 2)
    assert_equal(
        _fields_of(store, state, subgraphs, "pandas", "Query"),
        "allPandas, panda",
    )
    assert_equal(
        _fields_of(store, state, subgraphs, "pandas", "Panda"),
        "favoriteFood, name",
    )
    assert_equal(_count_of(store, state, subgraphs, "users"), 1)
    assert_equal(_fields_of(store, state, subgraphs, "users", "Query"), "")
    assert_equal(
        _fields_of(store, state, subgraphs, "users", "User"),
        "email, name, totalProductsCreated",
    )
    assert_equal(_count_of(store, state, subgraphs, "reviews"), 4)
    assert_equal(
        _fields_of(store, state, subgraphs, "reviews", "Product"),
        "id, reviews, reviewsCount, reviewsScore",
    )
    assert_equal(_count_of(store, state, subgraphs, "products"), 8)
    assert_equal(
        _fields_of(store, state, subgraphs, "products", "Query"),
        "allProducts, product",
    )
    assert_equal(
        _fields_of(store, state, subgraphs, "products", "Product"),
        (
            "createdBy, dimensions, hidden, id, name, oldField, package, sku,"
            " variation"
        ),
    )
    assert_equal(_count_of(store, state, subgraphs, "inventory"), 5)


# The tests below have no upstream counterpart. They check the lookups and
# the directive orders that the fixtures do not reach.


def test_definition_kind_is_valid() raises:
    assert_true(DefinitionKind(5).is_valid())
    assert_false(DefinitionKind(6).is_valid())


def test_empty_document() raises:
    var store = Store()
    var state = new_supergraph_state(store, Document())
    assert_equal(len(state.definitions), 0)
    assert_equal(len(state.known_scalars), 5)
    assert_equal(state.query_type, store.sym("Query"))
    assert_equal(state.subgraph_index(store.sym("a")), NONE)
    with assert_raises(contains="Subgraph not found"):
        _ = state.resolve_graph_id(store.sym("A"))


def test_schema_definition_without_a_query() raises:
    var store = Store()
    var state = new_supergraph_state(
        store,
        parse(
            """
            schema { mutation: M }
            type M { a: Int }
            type Query { b: Int }
            """
        ),
    )
    assert_equal(state.query_type, store.sym("Query"))
    assert_equal(state.mutation_type, store.sym("M"))
    assert_equal(state.subscription_type, NONE)
    with assert_raises(contains="'subscription'"):
        _ = state.root_type_name(OperationKind.SUBSCRIPTION)
    assert_equal(state.root_type_name(OperationKind.MUTATION), store.sym("M"))


def test_root_types_by_name_and_lookups() raises:
    var store = Store()
    var state = new_supergraph_state(
        store,
        parse(
            """
            type Query { b: Int }
            type Subscription { s: Int }
            interface Node { id: ID }
            """
        ),
    )
    var subscription = store.sym("Subscription")
    assert_equal(state.subscription_type, subscription)
    assert_equal(state.mutation_type, NONE)
    with assert_raises(contains="'mutation'"):
        _ = state.root_type_name(OperationKind.MUTATION)
    assert_equal(state.root_type_name(OperationKind.SUBSCRIPTION), subscription)
    assert_equal(state.root_type_name(OperationKind.QUERY), store.sym("Query"))
    assert_equal(state.maybe_root_type(NONE), NONE)
    assert_equal(
        state.maybe_root_type(subscription),
        Int(OperationKind.SUBSCRIPTION.value),
    )
    assert_equal(state.maybe_root_type(store.sym("Node")), NONE)
    var node = store.sym("Node")
    assert_equal(len(state.interface_members(node)), 0)
    assert_false(state.has_interface_members(node))
    assert_false(state.is_interface_object_in_subgraph(node, store.sym("A")))
    var query = store.sym("Query")
    assert_equal(
        state.field_return_type_name(store, query, store.sym("__typename")),
        store.sym("String"),
    )
    assert_equal(
        state.field_return_type_name(store, store.sym("Nope"), store.sym("b")),
        NONE,
    )
    assert_equal(
        state.field_return_type_name(store, query, store.sym("nope")), NONE
    )
    assert_equal(
        state.field_return_type_name(store, query, store.sym("b")),
        store.sym("Int"),
    )
    assert_false(state.subgraph_exists_by_name(store, "a"))
    assert_false(state.subgraph_exists_by_name(store, "never-seen"))


def test_join_directive_orders() raises:
    var store = Store()
    var state = new_supergraph_state(
        store,
        parse(
            """
            scalar ID
            enum join__Graph {
              A @join__graph(name: "a", url: "http://a")
              B @join__graph(name: "b", url: "http://b")
                @join__graph(name: "a2", url: "http://a2")
              C @join__graph(name: "c", url: "http://c")
                @join__graph(name: "d", url: "http://d")
              D
              E @join__graph(name: "a", url: "http://e")
            }
            type Query @join__type(graph: B) @join__type(graph: A) {
              a: Int @join__field(graph: A) @join__field
              b: Int @join__field @join__field(graph: A)
              c: Int @join__field @join__field
            }
            type Empty @join__type(graph: A)
            type Dup { x: Int }
            type Dup { y: Int }
            union U @join__type(graph: A) = Query
            enum Color @join__type(graph: A) {
              RED @join__enumValue(graph: B) @join__enumValue(graph: A)
            }
            """
        ),
    )
    assert_equal(len(state.subgraph_names), 3)
    assert_equal(store.name(state.subgraph_names[0]), "a")
    assert_equal(store.name(state.subgraph_names[1]), "a2")
    assert_equal(store.name(state.subgraph_names[2]), "c")
    assert_equal(state.resolve_graph_id(store.sym("B")), store.sym("a2"))
    assert_equal(state.resolve_graph_id(store.sym("C")), store.sym("c"))
    assert_true(state.subgraph_exists_by_name(store, "a2"))
    assert_equal(state.subgraph_index(store.sym("c")), 2)
    var query = state.definition(store.sym("Query"))
    var subgraphs = state.definitions[query].subgraphs(store)
    assert_equal(len(subgraphs), 2)
    assert_equal(store.name(subgraphs[0]), "A")
    ref fields = state.definitions[query].fields
    assert_equal(fields[0].join_field[0].graph_id, NONE)
    assert_equal(fields[0].join_field[1].graph_id, store.sym("A"))
    assert_equal(fields[1].join_field[0].graph_id, NONE)
    assert_equal(fields[2].join_field[1].graph_id, NONE)
    var color = state.definition(store.sym("Color"))
    ref graphs = state.definitions[color].enum_values[0].graphs
    assert_equal(store.name(graphs[0]), "A")
    assert_equal(store.name(graphs[1]), "B")
    var dup = store.sym("Dup")
    assert_equal(len(state.definitions[state.definition(dup)].fields), 1)
    assert_true(state.field(dup, store.sym("y")) != NONE)
    assert_equal(len(state.known_scalars), 5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
