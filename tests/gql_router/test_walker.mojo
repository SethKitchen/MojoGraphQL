# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the operation walk and the best combination.

Hive Router `1a29df9` has no separate tests for
`planner/walker/` and `planner/best.rs`; its query plan tests in
`query_planner/tests/` cover them. These tests check the paths that the
walk finds for the `root_types.rs` fixture.
"""

from _fixtures import (
    provides_on_interface,
    shared_root,
    simple_interface_object,
    simplest_requires,
)
from gql_language.parser import parse
from gql_router.ast import NONE, Cond, ItemKind
from gql_router.best import find_best_combination
from gql_router.federation_spec import OperationKind
from gql_router.graph import (
    EdgeKind,
    Graph,
    Node,
    PlannerOverrideContext,
    build_graph,
)
from gql_router.normalize import normalize_operation, selection_set_from_text
from gql_router.query_tree import OperationPath, PlanSpace, UnionContext
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState, new_supergraph_state
from gql_router.walker import (
    Target,
    Walker,
    find_best_paths,
    pick_shared_paths,
    requirement_ids,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_shared_root_paths() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(shared_root.sdl()))
    var graph = build_graph(store, state)
    var operation = normalize_operation(
        store,
        state,
        parse(
            """
            query {
              product {
                id
                name { id brand model }
                category { id name }
                price { id amount currency }
              }
            }
            """
        ),
    )
    var typename = store.add_item(ItemKind.FIELD, store.sym("__typename"))
    var walker = Walker(requirement_ids(graph, store), typename)
    var resolved = walker.walk_operation(
        graph,
        store,
        state,
        PlannerOverrideContext.default(),
        operation.kind,
        operation.selection_set,
    )
    assert_equal(len(resolved.root_field_groups), 1)
    # id, name.{id brand model}, category.{id name}, price.{id amount currency}
    assert_equal(len(resolved.root_field_groups[0]), 9)
    var texts = List[String]()
    for path in resolved.root_field_groups[0][0]:
        texts.append(walker.space.path_text(graph, store, path))
    assert_equal(
        String(", ").join(texts),
        (
            "root(Query) -(category)- Query/category -(product)-"
            " Product/category -(id)- ID/category, root(Query) -(name)-"
            " Query/name -(product)- Product/name -(id)- ID/name, root(Query)"
            " -(price)- Query/price -(product)- Product/price -(id)- ID/price"
        ),
    )
    var tree = find_best_combination(walker.space, graph, resolved)
    assert_equal(len(walker.space.trees[tree].children), 3)


# --- unit tests of the walk parts ----------------------------------------


def _walker(mut store: Store, graph: Graph) -> Walker:
    var typename = store.add_item(ItemKind.FIELD, store.sym("__typename"))
    return Walker(requirement_ids(graph, store), typename)


def test_no_paths_have_no_best_paths() raises:
    assert_equal(len(find_best_paths(List[OperationPath]())), 0)


def test_shared_paths_skip_leaves_without_paths() raises:
    var space = PlanSpace()
    assert_equal(len(pick_shared_paths(space, List[List[OperationPath]]())), 0)
    var empty = OperationPath(0, NONE, 0, NONE)
    var tied = List[List[OperationPath]]()
    tied.append(List[OperationPath]())
    tied.append([empty, empty])
    var picked = pick_shared_paths(space, tied)
    assert_equal(len(picked), 1)


def test_partial_union_paths_narrow_to_shared_members() raises:
    var store = Store()
    var graph = Graph()
    var walker = _walker(store, graph)
    var parent = store.sym("Query")
    var field = store.sym("item")
    var a = store.sym("A")
    var b = store.sym("B")
    ref unions = walker.space.unions
    unions.append(UnionContext(parent, field, 1, a, [a, b]))  # 0
    unions.append(UnionContext(parent, field, 2, a, [a]))  # 1
    unions.append(UnionContext(parent, field, 2, b, [a]))  # 2
    unions.append(UnionContext(parent, field, 3, a, List[Int]()))  # 3
    unions.append(UnionContext(store.sym("Other"), field, 2, a, [a]))  # 4
    unions.append(UnionContext(parent, store.sym("other"), 2, a, [a]))  # 5

    def _path(context: Int) -> OperationPath:
        return OperationPath(0, NONE, 0, context)

    var paths: List[OperationPath] = [_path(0), _path(NONE)]
    walker._narrow_partial_union_paths(paths)
    assert_equal(len(paths), 2)
    paths = [_path(0), _path(4)]
    walker._narrow_partial_union_paths(paths)
    assert_equal(len(paths), 2)
    paths = [_path(0), _path(5)]
    walker._narrow_partial_union_paths(paths)
    assert_equal(len(paths), 2)
    paths = [_path(0), _path(1), _path(2)]
    walker._narrow_partial_union_paths(paths)
    assert_equal(len(paths), 2)
    paths = [_path(0), _path(3)]
    walker._narrow_partial_union_paths(paths)
    assert_equal(len(paths), 0)


def test_path_searches_report_what_they_cannot_reach() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(shared_root.sdl()))
    var graph = build_graph(store, state)
    var walker = _walker(store, graph)
    var ctx = PlannerOverrideContext.default()
    var entrypoint = walker.space.new_entrypoint(
        graph, store, graph.entrypoints(OperationKind.QUERY)[0]
    )
    with assert_raises(contains="No paths found for selection item: Product"):
        _ = walker.find_self_referencing_direct_path(
            graph,
            store,
            state,
            ctx,
            entrypoint,
            store.sym("Product"),
            Cond.none(),
        )
    with assert_raises(contains="Tail node missing info"):
        _ = walker.find_indirect_paths(
            graph,
            store,
            state,
            ctx,
            OperationPath(graph.query_root, NONE, 0, NONE),
            Target.for_field(walker.typename_field),
            List[Int](),
            List[Int](),
        )
    var id = store.add_item(ItemKind.FIELD, store.sym("id"))
    assert_false(
        walker.field_target_subgraph_ids(
            graph, store, state, id, List[OperationPath]()
        )
    )
    var ghost = graph.upsert_node(
        store,
        Node.subgraph_type(store.sym("Ghost"), store.sym("category"), False),
    )
    assert_false(
        walker.field_target_subgraph_ids(
            graph, store, state, id, [OperationPath(ghost, NONE, 0, NONE)]
        )
    )
    # A path that ends at an entrypoint resolves nothing locally.
    assert_equal(
        len(
            walker._fields_to_resolve_locally(
                graph, store, state, id, [entrypoint]
            )
        ),
        0,
    )


def _id_leaf_path(
    mut store: Store,
    mut walker: Walker,
    graph: Graph,
    state: SupergraphState,
) raises -> OperationPath:
    """Return a path that ends with the `id` field of `Product`."""
    var operation = normalize_operation(
        store, state, parse("{ product { id } }")
    )
    var resolved = walker.walk_operation(
        graph,
        store,
        state,
        PlannerOverrideContext.default(),
        operation.kind,
        operation.selection_set,
    )
    return resolved.root_field_groups[0][0][0]


def test_local_resolution_needs_the_types_and_the_field() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(shared_root.sdl()))
    var graph = build_graph(store, state)
    var walker = _walker(store, graph)
    var path = _id_leaf_path(store, walker, graph, state)
    var edge = walker.space.segments[path.last_segment].edge
    assert_true(graph.edges[edge].kind == EdgeKind.FIELD_MOVE)
    var nope = store.add_item(ItemKind.FIELD, store.sym("nope"))
    with assert_raises(contains="Field 'nope' not found in type 'Product'"):
        _ = walker._fields_to_resolve_locally(graph, store, state, nope, [path])
    var id = store.add_item(ItemKind.FIELD, store.sym("id"))
    var tail_name = graph.nodes[graph.edges[edge].tail].name
    graph.nodes[graph.edges[edge].tail].name = store.sym("Ghost")
    with assert_raises(contains="Type Definition of 'Ghost' not found"):
        _ = walker._fields_to_resolve_locally(graph, store, state, id, [path])
    graph.nodes[graph.edges[edge].tail].name = tail_name
    graph.nodes[graph.edges[edge].head].name = store.sym("Ghost")
    with assert_raises(contains="Type Definition of 'Ghost' not found"):
        _ = walker._fields_to_resolve_locally(graph, store, state, id, [path])


def test_a_type_condition_requirement_nothing_reaches_fails() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(simplest_requires.sdl()))
    var graph = build_graph(store, state)
    var walker = _walker(store, graph)
    var found = NONE
    for index in range(len(graph.edges)):
        if (
            graph.edges[index].kind == EdgeKind.FIELD_MOVE
            and store.name(graph.edges[index].name) == "isExpensive"
            and graph.edges[index].requirements != NONE
        ):
            found = index
    assert_true(found != NONE)
    graph.edges[found].requirements = selection_set_from_text(
        store, "{ ... on Nope { upc } }"
    )
    var satisfied = walker.can_satisfy_edge(
        graph,
        store,
        state,
        PlannerOverrideContext.default(),
        found,
        OperationPath(graph.edges[found].head, NONE, 0, NONE),
        List[Int](),
        List[Int](),
        False,
    )
    assert_false(satisfied)


def test_requirement_dependencies_follow_type_conditions() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(simplest_requires.sdl()))
    var graph = build_graph(store, state)
    var walker = _walker(store, graph)
    var product = store.sym("Product")
    var query = store.sym("Query")
    var set = selection_set_from_text(
        store,
        (
            "{ price ... on Product { upc } ... on Query { upc } upc { a }"
            " products }"
        ),
    )
    var items = store.children(set)
    var price = items[0]
    var on_product = items[1]
    var on_query = items[2]
    var upc_with_children = items[3]
    var products = items[4]
    var upc = store.children(on_product)[0]
    # The requirement type must match the current type.
    assert_false(
        walker._requirements_depend_on_target_field(
            store, state, product, query, set, upc
        )
    )
    assert_true(
        walker._requirements_depend_on_target_field(
            store, state, product, product, set, upc
        )
    )
    assert_false(walker._item_depends(store, state, product, on_query, upc))
    assert_false(
        walker._item_depends(store, state, product, on_product, products)
    )
    # A leaf requirement overlaps any selection of the same field.
    assert_true(
        walker._sets_overlap(store, state, product, upc, upc_with_children)
    )
    # A field against a fragment, and the other way round.
    assert_true(walker._items_overlap(store, state, product, on_product, upc))
    assert_false(
        walker._items_overlap(store, state, product, on_product, price)
    )
    assert_false(walker._items_overlap(store, state, product, on_query, upc))
    assert_true(walker._items_overlap(store, state, product, upc, on_product))
    assert_false(
        walker._items_overlap(store, state, product, price, on_product)
    )
    assert_false(walker._items_overlap(store, state, product, upc, on_query))
    # Two fragments.
    assert_false(
        walker._items_overlap(store, state, product, on_query, on_product)
    )
    assert_true(
        walker._items_overlap(store, state, product, on_product, on_product)
    )


def _walk_text(
    sdl: String, query: String, clear_last_fragment: Bool = False
) raises:
    """Walk an operation as it is written, without normalization."""
    var store = Store()
    var state = new_supergraph_state(store, parse(sdl))
    var graph = build_graph(store, state)
    var walker = _walker(store, graph)
    var set = selection_set_from_text(store, query)
    if clear_last_fragment:
        var field = store.items[set].first
        store.clear(store.items[field].last)
    _ = walker.walk_operation(
        graph,
        store,
        state,
        PlannerOverrideContext.default(),
        OperationKind.QUERY,
        set,
    )


def test_walks_of_type_conditions() raises:
    # A condition on the type itself, with no `@skip` or `@include`.
    _walk_text(provides_on_interface.sdl(), "{ media { ... on Media { id } } }")
    # A shared interface field resolves its fragments in one subgraph.
    _walk_text(
        provides_on_interface.sdl(),
        "{ media { ... on Book { animals { id } } ... on Book { id } } }",
    )
    with assert_raises(contains="No paths found for selection item: media"):
        _walk_text(
            provides_on_interface.sdl(),
            "{ media { ... on Book { id } ... on Book { id } } }",
            True,
        )
    # An object type of an `@interfaceObject`.
    _walk_text(
        simple_interface_object.sdl(),
        "{ accounts { ... on Admin { isMain } } }",
    )
    # An `@interfaceObject` has no `__typename` to fall back to.
    with assert_raises(
        contains="No paths found for selection item: __typename"
    ):
        _walk_text(
            simple_interface_object.sdl(), "{ accounts { ... on Nope { id } } }"
        )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
