# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the query planner graph.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/graph/tests.rs`. The helpers mirror the
upstream `FoundEdges`, `find_node` and `follow`.
"""

from _fixtures import (
    bench_supergraph,
    nested_provides,
    provides_copies,
    provides_on_interface,
    provides_requires_typename,
    provides_typename,
    provides_typename_interface,
    provides_typename_list,
    provides_typename_nested,
    provides_union_progressive_override,
    requires_nested_same_type,
    shared_root,
    simple_interface_object,
    simplest_requires,
    star_stuff,
    supergraph2,
    union_list,
)
from gql_language.parser import parse
from gql_router.ast import NONE
from gql_router.federation_spec import (
    JoinFieldDirective,
    OperationKind,
    OverrideLabel,
    PERCENTAGE_SCALE_FACTOR,
)
from gql_router.graph import (
    Edge,
    EdgeKind,
    Graph,
    NodeKind,
    PlannerOverrideContext,
    ProvidedPool,
    Specialization,
    _field_definition,
    _prune_provided,
    _provided_node,
    _root_of,
    build_graph,
    field_availability,
)
from gql_router.normalize import selection_set_from_text
from gql_router.selection_set import set_text
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState, new_supergraph_state
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_not_equal,
    assert_raises,
    assert_true,
)


def _graph(mut store: Store, sdl: String) raises -> Graph:
    var state = new_supergraph_state(store, parse(sdl))
    return build_graph(store, state)


@fieldwise_init
struct _Found(Movable):
    """The edges of one side of a node, as upstream `FoundEdges`."""

    var edges: List[Int]
    """The edges."""
    var others: List[Int]
    """The node on the other side of each edge."""


def _node(graph: Graph, name: String) raises -> Int:
    var found = graph.find_node(name)
    if found < 0:
        raise Error("failed to find node " + name)
    return found


def _find_node_doesnt_exist(graph: Graph, name: String) raises:
    assert_true(
        graph.find_node(name) < 0,
        "found node " + name + " that should not exist",
    )


def _incoming(graph: Graph, name: String) raises -> _Found:
    var edges = graph.edges_to(_node(graph, name))
    var others = List[Int]()
    for edge in edges:
        others.append(graph.edges[edge].head)
    return _Found(edges^, others^)


def _outgoing(graph: Graph, name: String) raises -> _Found:
    var edges = graph.edges_from(_node(graph, name))
    var others = List[Int]()
    for edge in edges:
        others.append(graph.edges[edge].tail)
    return _Found(edges^, others^)


def _edge(
    graph: Graph, store: Store, found: _Found, key: String, other_side: String
) -> Int:
    """Return the position in `found` of the `key` edge to `other_side`, or
    -1. A copy is named after its plain node, plus what is provided on it.
    """
    for i in range(len(found.edges)):
        ref edge = graph.edges[found.edges[i]]
        ref node = graph.nodes[found.others[i]]
        var formatted = node.display_name(store)
        if edge.display_name(store) != key:
            continue
        if node.is_using_provides():
            if formatted.startswith(other_side + "{"):
                return i
        elif formatted == other_side:
            return i
    return -1


def _assert_field_edge(
    graph: Graph, store: Store, found: _Found, key: String, other_side: String
) raises:
    assert_true(
        _edge(graph, store, found, key, other_side) >= 0,
        "Field edge " + key + " <-> " + other_side + " not found",
    )


def _assert_key_edge(
    graph: Graph, store: Store, found: _Found, key: String, other_side: String
) raises:
    assert_true(
        _edge(graph, store, found, key, other_side) >= 0,
        "Key edge " + key + " <-> " + other_side + " not found",
    )


def _assert_interface_edge(
    graph: Graph, store: Store, found: _Found, key: String, other_side: String
) raises:
    assert_true(
        _edge(graph, store, found, key, other_side) >= 0,
        "Interface edge " + key + " <-> " + other_side + " not found",
    )


def _assert_field_edge_does_not_exist(
    graph: Graph, store: Store, found: _Found, key: String, other_side: String
) raises:
    assert_true(
        _edge(graph, store, found, key, other_side) < 0,
        "Field edge " + key + " <-> " + other_side + " found",
    )


def _no_field_edge(
    graph: Graph, store: Store, found: _Found, key: String
) raises:
    for edge in found.edges:
        assert_true(
            graph.edges[edge].display_name(store) != key,
            "Field edge " + key + " found",
        )


def _edge_field(
    graph: Graph, store: Store, found: _Found, key: String
) raises -> Int:
    """Return the position in `found` of the only edge named `key`."""
    var at = -1
    var count = 0
    var names = String()
    for i in range(len(found.edges)):
        var name = graph.edges[found.edges[i]].display_name(store)
        names += name + " "
        if name == key:
            if at < 0:
                at = i
            count += 1
    assert_equal(
        count,
        1,
        "expected exactly one edge field named '"
        + key
        + "', available fields: "
        + names,
    )
    return at


def _edges_field(
    graph: Graph, store: Store, found: _Found, key: String
) -> List[Int]:
    """Return the positions in `found` of the field moves named `key`."""
    var out = List[Int]()
    for i in range(len(found.edges)):
        ref edge = graph.edges[found.edges[i]]
        if edge.kind == EdgeKind.FIELD_MOVE and store.name(edge.name) == key:
            out.append(i)
    return out^


def _edge_debug(
    graph: Graph,
    store: Store,
    found: _Found,
    positions: List[Int],
    text: String,
) raises -> Int:
    """Return the node at the first of `positions` whose edge has the Debug
    form `text`."""
    for i in positions:
        if graph.edges[found.edges[i]].debug_text(store) == text:
            return found.others[i]
    raise Error("failed to find edge " + text)


def _follow(
    graph: Graph, store: Store, node: String, edge_name: String
) raises -> String:
    """Return the name of the node the only `edge_name` edge of `node`
    leads to."""
    var outgoing = _outgoing(graph, node)
    var at = _edge_field(graph, store, outgoing, edge_name)
    return graph.node_name(store, outgoing.others[at])


def test_nested_provides() raises:
    var store = Store()
    var graph = _graph(store, nested_provides.sdl())
    var outgoing = _outgoing(graph, "Query/category")
    var field_edges = _edges_field(graph, store, outgoing, "products")
    # The field edge points at the copy. There is no second, plain edge.
    assert_equal(len(field_edges), 1)
    # Provided ("viewed") field edge.
    var to = _edge_debug(
        graph, store, outgoing, field_edges, "products @provides"
    )
    assert_true(graph.nodes[to].is_using_provides())
    assert_equal(
        graph.node_name(store, to),
        "Product/category{categories{subCategories}}",
    )
    var viewed_outgoing = _outgoing(graph, graph.node_name(store, to))
    var at = _edge_field(graph, store, viewed_outgoing, "categories")
    var node1 = viewed_outgoing.others[at]
    assert_true(graph.nodes[node1].is_using_provides())
    assert_equal(
        graph.node_name(store, node1), "Category/category{subCategories}"
    )
    # The plain node still exists, and the copy has its fields.
    _assert_field_edge(
        graph, store, _outgoing(graph, "Product/category"), "id", "ID/category"
    )
    _assert_field_edge(
        graph,
        store,
        _outgoing(graph, _follow(graph, store, "Query/category", "products")),
        "id",
        "ID/category",
    )


def test_provides_copies_are_keyed_by_what_they_provide() raises:
    var store = Store()
    var graph = _graph(store, provides_copies.sdl())
    # `User.orders` is handled before `ZOrder.product`, its copy still gets
    # `name`. The plain `ZOrder` and its copy share the one `Product` copy.
    var orders = _follow(graph, store, "User/orders", "orders")
    assert_equal(orders, "ZOrder/orders{sku}")
    assert_equal(
        _follow(graph, store, orders, "product"), "Product/orders{name}"
    )
    assert_equal(
        _follow(graph, store, "ZOrder/orders", "product"),
        "Product/orders{name}",
    )
    # `User.related: User` provides `name` again, so it comes back to the
    # copy it is on.
    var related = _follow(graph, store, "User/social", "related")
    assert_equal(related, "User/social{name}")
    assert_equal(_follow(graph, store, related, "related"), related)


def test_provides_copy_keeps_fields_only_where_they_are_provided() raises:
    # Returning the same type is not enough to keep what is provided.
    # `related` provides `name` again, `other` does not.
    var store = Store()
    var graph = _graph(store, requires_nested_same_type.sdl())
    var related = _follow(graph, store, "User/social", "related")
    assert_equal(related, "User/social{name}")
    assert_equal(_follow(graph, store, related, "related"), related)
    assert_equal(_follow(graph, store, related, "other"), "User/social")


def test_provides_on_union_field_redirects_every_member_edge() raises:
    # A union field has an edge per member. Every one of them goes to its
    # copy, and keeps the field's @override label and @provides.
    var store = Store()
    var graph = _graph(store, provides_union_progressive_override.sdl())
    var outgoing = _outgoing(graph, "User/b")
    var targets = List[String]()
    for i in _edges_field(graph, store, outgoing, "media"):
        ref field_move = graph.edges[outgoing.edges[i]]
        assert_true(Bool(field_move.override_label))
        assert_true(Bool(field_move.join_field.value().provides))
        targets.append(graph.node_name(store, outgoing.others[i]))
    sort(targets)
    assert_equal(len(targets), 2)
    assert_equal(targets[0], "Media/b for User.media:Book{...on Book{title}}")
    assert_equal(targets[1], "Media/b for User.media:Movie{...on Movie{title}}")
    # a's edges are the overridden side.
    var a_outgoing = _outgoing(graph, "User/a")
    for i in _edges_field(graph, store, a_outgoing, "media"):
        ref field_move = graph.edges[a_outgoing.edges[i]]
        assert_true(field_move.overridden_by != NONE)
        assert_equal(store.name(field_move.overridden_by), "b")
        assert_true(Bool(field_move.overridden_label))


def test_star_stuff() raises:
    var store = Store()
    var graph = _graph(store, star_stuff.sdl())
    # Field ownership: make sure fields are defined where they belong.
    _assert_field_edge(
        graph,
        store,
        _outgoing(graph, "Product/reviews"),
        "reviews",
        "Review/reviews",
    )
    _no_field_edge(
        graph, store, _outgoing(graph, "Product/products"), "reviews"
    )

    # external: true
    var outgoing = _outgoing(graph, "Product/products")
    _assert_field_edge(
        graph, store, outgoing, "dimensions", "ProductDimension/products"
    )
    _assert_field_edge_does_not_exist(
        graph, store, outgoing, "dimensions", "ProductDimension/reviews"
    )
    _assert_field_edge_does_not_exist(
        graph, store, outgoing, "dimensions", "ProductDimension/users"
    )
    _assert_field_edge_does_not_exist(
        graph, store, outgoing, "dimensions", "ProductDimension/inventory"
    )

    # User.totalProductsCreated: @shareable. Defined only in the relevant
    # subgraphs, with no nodes for types in other subgraphs.
    _assert_field_edge(
        graph,
        store,
        _outgoing(graph, "User/products"),
        "totalProductsCreated",
        "Int/products",
    )
    _assert_field_edge(
        graph,
        store,
        _outgoing(graph, "User/users"),
        "totalProductsCreated",
        "Int/users",
    )
    _find_node_doesnt_exist(graph, "User/reviews")
    _find_node_doesnt_exist(graph, "User/inventory")
    _find_node_doesnt_exist(graph, "User/PANDAS")

    # Basic override.
    _no_field_edge(
        graph, store, _outgoing(graph, "Product/products"), "reviewsScore"
    )
    _assert_field_edge(
        graph,
        store,
        _outgoing(graph, "Product/reviews"),
        "reviewsScore",
        "Float/reviews",
    )

    # Interface.
    var incoming = _incoming(graph, "ProductItf/products")
    var itf_outgoing = _outgoing(graph, "ProductItf/products")
    _assert_field_edge(graph, store, incoming, "product", "Query/products")
    _assert_field_edge(graph, store, incoming, "allProducts", "Query/products")
    var fields: List[String] = [
        "id",
        "variation",
        "dimensions",
        "hidden",
        "name",
        "oldField",
        "package",
        "sku",
        "createdBy",
        "__typename",
    ]
    var types: List[String] = [
        "ID/products",
        "ProductVariation/products",
        "ProductDimension/products",
        "String/products",
        "String/products",
        "String/products",
        "String/products",
        "String/products",
        "User/products",
        "String/products",
    ]
    for i in range(len(fields)):
        _assert_field_edge(graph, store, itf_outgoing, fields[i], types[i])
    _no_field_edge(graph, store, itf_outgoing, "reviews")
    assert_equal(len(incoming.edges), 3)
    assert_equal(len(itf_outgoing.edges), 12)

    # Requires preserves the selection set in the graph.
    var inventory = _outgoing(graph, "Product/inventory")
    _assert_field_edge(
        graph, store, inventory, "delivery", "DeliveryEstimates/inventory"
    )
    assert_true(
        _edge(
            graph, store, inventory, "delivery", "DeliveryEstimates/inventory"
        )
        >= 0,
        "cant find edge",
    )


def test_star_stuff_snapshot() raises:
    var store = Store()
    var graph = _graph(store, star_stuff.sdl())
    # Validate the root nodes.
    assert_true(graph.query_root != NONE)
    assert_true(graph.nodes[graph.query_root].kind == NodeKind.QUERY_ROOT)
    assert_equal(store.name(graph.nodes[graph.query_root].name), "Query")
    assert_equal(graph.mutation_root, NONE)
    assert_equal(graph.subscription_root, NONE)

    var incoming = _incoming(graph, "Product/products")
    var outgoing = _outgoing(graph, "Product/products")
    assert_equal(len(incoming.edges), 14)
    assert_equal(len(outgoing.edges), 18)

    var keys: List[String] = ["id", "sku package", "sku variation { id }"]
    var subgraphs: List[String] = [
        "Product/inventory",
        "Product/products",
        "Product/reviews",
    ]
    for subgraph in subgraphs:
        for key in keys:
            _assert_key_edge(graph, store, incoming, key, subgraph)
    _assert_interface_edge(
        graph, store, incoming, "Product", "ProductItf/products"
    )
    _assert_interface_edge(graph, store, incoming, "Product", "SkuItf/products")

    _assert_key_edge(graph, store, outgoing, "id", "Product/inventory")
    _assert_key_edge(graph, store, outgoing, "id", "Product/products")
    _assert_key_edge(graph, store, outgoing, "id", "Product/reviews")
    _assert_key_edge(graph, store, outgoing, "sku package", "Product/products")
    _assert_key_edge(
        graph, store, outgoing, "sku variation { id }", "Product/products"
    )
    var fields: List[String] = [
        "id",
        "variation",
        "dimensions",
        "hidden",
        "name",
        "oldField",
        "package",
        "sku",
        "createdBy",
        "__typename",
    ]
    var types: List[String] = [
        "ID/products",
        "ProductVariation/products",
        "ProductDimension/products",
        "String/products",
        "String/products",
        "String/products",
        "String/products",
        "String/products",
        "User/products",
        "String/products",
    ]
    for i in range(len(fields)):
        _assert_field_edge(graph, store, outgoing, fields[i], types[i])


def test_multiple_provides() raises:
    var store = Store()
    var graph = _graph(store, supergraph2.sdl())
    var outgoing = _outgoing(graph, "Group/foo")
    # Multiple provides create multiple edges, one for each "view".
    var node1 = _edge_debug(
        graph,
        store,
        outgoing,
        _edges_field(graph, store, outgoing, "users"),
        "users @provides",
    )
    assert_true(graph.nodes[node1].is_using_provides())

    # A copy has every edge of the plain node, plus the provided fields.
    var plain_edges = len(_outgoing(graph, "User/foo").edges)
    var name1 = graph.node_name(store, node1)
    var viewed_incoming = _incoming(graph, name1)
    var viewed_outgoing = _outgoing(graph, name1)
    _assert_field_edge(graph, store, viewed_outgoing, "id", "String/foo")
    assert_equal(len(viewed_incoming.edges), 2)  # +1 for Selfie
    assert_equal(len(viewed_outgoing.edges), plain_edges + 1)  # +1 for id

    var node2 = _edge_debug(
        graph,
        store,
        outgoing,
        _edges_field(graph, store, outgoing, "user"),
        "user @provides",
    )
    assert_true(graph.nodes[node2].is_using_provides())

    var name2 = graph.node_name(store, node2)
    viewed_incoming = _incoming(graph, name2)
    viewed_outgoing = _outgoing(graph, name2)
    _assert_field_edge(graph, store, viewed_outgoing, "name", "String/foo")
    assert_equal(len(viewed_incoming.edges), 2)  # +1 for Selfie
    # +1 for name, +1 for profile
    assert_equal(len(viewed_outgoing.edges), plain_edges + 2)

    # `Profile.age` is a local field in `foo`, so `profile { age }` adds
    # nothing below `profile`, and it leads to the plain node.
    var at = _edge_field(graph, store, viewed_outgoing, "profile")
    var profile = viewed_outgoing.others[at]
    assert_false(graph.nodes[profile].is_using_provides())
    _assert_field_edge(
        graph,
        store,
        _outgoing(graph, graph.node_name(store, profile)),
        "age",
        "Int/foo",
    )

    # Two different views are different nodes.
    assert_not_equal(node1, node2)
    assert_not_equal(name1, name2)


def test_provides_fieldset_with_typename() raises:
    # https://github.com/graphql-hive/router/issues/1455
    # `__typename` is a meta-field, not part of the fields set in the
    # schema, so a `@provides` fieldset with it must not fail when the
    # graph is built.
    var store = Store()
    var state = new_supergraph_state(store, parse(provides_typename.sdl()))
    try:
        _ = build_graph(store, state)
    except e:
        raise Error(
            "expected __typename inside a @provides fieldset to plan"
            " successfully, got: "
            + String(e)
        )


def test_provides_fieldset_with_nested_typename() raises:
    # __typename at two nested levels of the same @provides fieldset.
    var store = Store()
    var graph = _graph(store, provides_typename_nested.sdl())
    var holder = _follow(graph, store, "Query/provider", "holder")
    var item = _follow(graph, store, holder, "item")
    var item_outgoing = _outgoing(graph, item)
    _assert_field_edge(
        graph, store, item_outgoing, "__typename", "String/provider"
    )
    _assert_field_edge(graph, store, item_outgoing, "nested", "Nested/provider")
    var nested = _outgoing(graph, _follow(graph, store, item, "nested"))
    _assert_field_edge(graph, store, nested, "__typename", "String/provider")
    _assert_field_edge(graph, store, nested, "label", "String/provider")


def test_provides_fieldset_with_typename_on_list() raises:
    # __typename inside a @provides fieldset nested under a list-returning
    # field.
    var store = Store()
    var graph = _graph(store, provides_typename_list.sdl())
    var outgoing = _outgoing(
        graph, _follow(graph, store, "Query/provider", "holder")
    )
    var at = _edge_field(graph, store, outgoing, "items")
    ref items_edge = graph.edges[outgoing.edges[at]]
    assert_true(
        items_edge.kind == EdgeKind.FIELD_MOVE,
        "expected a field move edge, got " + items_edge.debug_text(store),
    )
    assert_true(items_edge.is_list, "expected 'items' field move to be a list")
    var node = outgoing.others[at]
    assert_true(graph.nodes[node].is_using_provides())
    var node_outgoing = _outgoing(graph, graph.node_name(store, node))
    _assert_field_edge(
        graph, store, node_outgoing, "__typename", "String/provider"
    )
    _assert_field_edge(graph, store, node_outgoing, "label", "String/provider")


def test_provides_fieldset_with_typename_on_interface() raises:
    # __typename both at the interface level and inside an inline fragment
    # branch of the same @provides fieldset.
    var store = Store()
    var graph = _graph(store, provides_typename_interface.sdl())
    var book = _follow(graph, store, "Query/a", "book")
    var animals = _follow(graph, store, book, "animals")
    var animals_outgoing = _outgoing(graph, animals)
    _assert_field_edge(graph, store, animals_outgoing, "__typename", "String/a")
    _assert_interface_edge(graph, store, animals_outgoing, "Dog", "Dog/a")
    var dog = _outgoing(graph, _follow(graph, store, animals, "Dog"))
    _assert_field_edge(graph, store, dog, "__typename", "String/a")
    _assert_field_edge(graph, store, dog, "name", "String/a")


def test_provides_fieldset_with_typename_and_requires() raises:
    # __typename inside a @provides fieldset for a field that also has
    # @requires.
    var store = Store()
    var graph = _graph(store, provides_requires_typename.sdl())
    var outgoing = _outgoing(graph, "Review/reviews")
    var node = _edge_debug(
        graph,
        store,
        outgoing,
        _edges_field(graph, store, outgoing, "author"),
        "author @requires(secret) @provides",
    )
    assert_true(graph.nodes[node].is_using_provides())
    var node_outgoing = _outgoing(graph, graph.node_name(store, node))
    _assert_field_edge(
        graph, store, node_outgoing, "username", "String/reviews"
    )
    _assert_field_edge(
        graph, store, node_outgoing, "__typename", "String/reviews"
    )


# --- unit tests of the graph parts ---------------------------------------


def test_kinds_are_valid_in_range() raises:
    assert_true(NodeKind.SUBGRAPH_TYPE.is_valid())
    assert_false(NodeKind(4).is_valid())
    assert_true(Specialization.UNION_MEMBERS.is_valid())
    assert_false(Specialization(3).is_valid())
    assert_true(EdgeKind.INTERFACE_OBJECT_TYPE_MOVE.is_valid())
    assert_false(EdgeKind(7).is_valid())


def test_edge_text_and_debug_text_of_each_kind() raises:
    var store = Store()
    var name = store.sym("me")
    var requirements = selection_set_from_text(store, "{ id }")
    var entity = Edge(EdgeKind.ENTITY_MOVE, NONE)
    entity.key = "id"
    entity.requirements = requirements
    assert_true(entity.has_requirements())
    assert_equal(entity.text(store), "🔑🧩" + set_text(store, requirements))
    assert_equal(entity.debug_text(store), "🔑 id")
    assert_equal(entity.display_name(store), "id")
    var abstract = Edge(EdgeKind.ABSTRACT_MOVE, name)
    assert_false(abstract.has_requirements())
    assert_equal(abstract.text(store), "🔮")
    assert_equal(abstract.debug_text(store), "🔮 me")
    var selfie = Edge(EdgeKind.SELFIE, name)
    assert_equal(selfie.text(store), "🤳")
    assert_equal(selfie.debug_text(store), "🤳")
    assert_equal(selfie.display_name(store), "selfie")
    var type_move = Edge(EdgeKind.INTERFACE_OBJECT_TYPE_MOVE, name)
    assert_equal(type_move.text(store), "🔎 me")
    assert_equal(type_move.debug_text(store), "🔎 me")
    var reentry = Edge(EdgeKind.REENTRY_MOVE, name)
    assert_equal(reentry.text(store), "🔁 me")
    assert_equal(reentry.debug_text(store), "🔁 me")
    var entrypoint = Edge(EdgeKind.SUBGRAPH_ENTRYPOINT, name)
    assert_equal(entrypoint.debug_text(store), "🚪 subgraph(me)")
    var field = Edge(EdgeKind.FIELD_MOVE, name)
    assert_equal(field.text(store), "me")
    assert_equal(field.debug_text(store), "me")


def test_field_move_debug_text_shows_its_join_field() raises:
    var store = Store()
    var field = Edge(EdgeKind.FIELD_MOVE, store.sym("price"))
    field.join_field = JoinFieldDirective(
        store.sym("A"),
        String("id"),
        String("name"),
        None,
        True,
        String("b"),
        OverrideLabel(True, 50 * PERCENTAGE_SCALE_FACTOR, NONE),
        False,
    )
    assert_equal(
        field.debug_text(store),
        (
            "price @requires(id) @provides @external @override(from: b, label:"
            " 50%)"
        ),
    )
    field.join_field = JoinFieldDirective(
        store.sym("A"),
        None,
        None,
        None,
        False,
        String("b"),
        OverrideLabel(False, 0, store.sym("flag")),
        False,
    )
    assert_equal(
        field.debug_text(store), "price @override(from: b, label: flag)"
    )
    field.join_field = JoinFieldDirective(
        store.sym("A"), None, None, None, False, String("b"), None, False
    )
    assert_equal(field.debug_text(store), "price @override(from: b)")
    field.join_field = JoinFieldDirective(
        store.sym("A"), None, None, None, False, None, None, False
    )
    assert_equal(field.debug_text(store), "price")


def test_reentry_moves_compare_name_type_and_list() raises:
    var store = Store()
    var a = Edge(EdgeKind.REENTRY_MOVE, store.sym("me"))
    a.type_name = store.sym("User")
    var b = a.copy()
    assert_true(a.same_as(store, b))
    b.name = store.sym("you")
    assert_false(a.same_as(store, b))
    b = a.copy()
    b.type_name = store.sym("Admin")
    assert_false(a.same_as(store, b))
    b = a.copy()
    b.is_list = True
    assert_false(a.same_as(store, b))


def test_no_flag_is_active_without_flags() raises:
    assert_false(PlannerOverrideContext.default().is_flag_active("x"))
    assert_true(PlannerOverrideContext.from_flag("x").is_flag_active("x"))


def test_provided_trees_merge_entries_of_one_name() raises:
    var store = Store()
    var pool = ProvidedPool()
    var x = store.sym("x")
    var y = store.sym("y")
    var t = store.sym("T")
    var just_y = pool.with_entry(store, 0, y, 0, False)
    var a = pool.with_entry(store, 0, x, 0, False)
    a = pool.with_entry(store, a, t, just_y, True)
    var b = pool.with_entry(store, 0, x, just_y, False)
    var types_only = pool.with_entry(store, 0, t, 0, True)
    assert_equal(pool.text(store, types_only), "{...on T}")
    assert_equal(pool.text(store, pool.merge(store, a, b)), "{x{y} ...on T{y}}")
    assert_equal(
        pool.text(store, pool.merge(store, b, types_only)), "{x{y} ...on T}"
    )
    assert_equal(pool.merge(store, a, 0), a)
    assert_equal(pool.merge(store, 0, b), b)


def test_provided_tree_from_a_set_rejects_spreads_and_bare_fragments() raises:
    var store = Store()
    var pool = ProvidedPool()
    with assert_raises(contains="Inline fragment without type condition"):
        _ = pool.from_set(
            store, selection_set_from_text(store, "{ ... { x } }")
        )
    with assert_raises(contains="Fragment spread detected"):
        _ = pool.from_set(store, selection_set_from_text(store, "{ ...F }"))


def _shared_root(mut store: Store) raises -> Tuple[SupergraphState, Graph]:
    var state = new_supergraph_state(store, parse(shared_root.sdl()))
    var graph = build_graph(store, state)
    return (state^, graph^)


def test_removing_the_last_edge_keeps_the_others() raises:
    var store = Store()
    var built = _shared_root(store)
    ref graph = built[1]
    var count = len(graph.edges)
    var last = graph.edges[count - 1].copy()
    var removed = graph.remove_edge(count - 1)
    assert_equal(len(graph.edges), count - 1)
    assert_true(removed.kind == last.kind)
    assert_equal(removed.head, last.head)


def test_entrypoints_need_their_root() raises:
    var store = Store()
    var built = _shared_root(store)
    with assert_raises(contains="Missing root type subscription"):
        _ = built[1].entrypoints(OperationKind.SUBSCRIPTION)
    with assert_raises(contains="Unexpected missing root type mutation"):
        _ = _root_of(built[1], Int(OperationKind.MUTATION.value))
    var bench_store = Store()
    var bench = _graph(bench_store, bench_supergraph.sdl())
    assert_true(len(bench.entrypoints(OperationKind.SUBSCRIPTION)) > 0)


def test_field_availability_needs_the_parent_in_the_subgraph() raises:
    var store = Store()
    var built = _shared_root(store)
    ref state = built[0]
    var category = state.definition(store.sym("Category"))
    var id = state.definitions[category].field_index(store.sym("id"))
    assert_equal(
        field_availability(state, category, id, store.sym("CATEGORY")), -2
    )
    assert_equal(
        field_availability(state, category, id, store.sym("NAME")), NONE
    )


def test_field_definition_names_what_is_missing() raises:
    var store = Store()
    var built = _shared_root(store)
    with assert_raises(contains="Definition with name 'Nope' was not found"):
        _ = _field_definition(
            store, built[0], store.sym("Nope"), store.sym("id")
        )
    with assert_raises(contains="Field named 'nope' was not found"):
        _ = _field_definition(
            store, built[0], store.sym("Product"), store.sym("nope")
        )


def test_provides_fold_the_own_type_and_keep_other_types() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(shared_root.sdl()))
    var graph = build_graph(store, state)
    var pool = ProvidedPool()
    var product = _node(graph, "Product/category")
    var graph_id = store.sym("CATEGORY")
    var name = store.sym("name")
    var just_name = pool.with_entry(store, 0, name, 0, False)
    var just_id = pool.with_entry(store, 0, store.sym("id"), 0, False)
    # `... on Category { name } ... on Product { id ... on Category { id } }`
    var inner = pool.with_entry(
        store, just_id, store.sym("Category"), just_id, True
    )
    var provided = pool.with_entry(
        store, 0, store.sym("Category"), just_name, True
    )
    provided = pool.with_entry(
        store, provided, store.sym("Product"), inner, True
    )
    var pruned = _prune_provided(
        graph, store, state, pool, product, provided, graph_id
    )
    assert_equal(pool.text(store, pruned), "{...on Category}")
    # `Name` is not in `category`, so its `... on` stays as it is.
    var brand = pool.with_entry(store, 0, store.sym("brand"), 0, False)
    var on_name = pool.with_entry(store, 0, store.sym("Name"), brand, True)
    assert_equal(
        pool.text(
            store,
            _prune_provided(
                graph, store, state, pool, product, on_name, graph_id
            ),
        ),
        "{...on Name{brand}}",
    )
    var provides = Dict[Int, Int]()
    var copies = Dict[String, Int]()
    var copy = _provided_node(
        graph,
        store,
        state,
        pool,
        provides,
        copies,
        product,
        on_name,
        graph_id,
    )
    assert_not_equal(copy, product)
    assert_true(graph.find_node("Name/category") >= 0)
    var abstract_moves = 0
    for edge in graph.edges_from(copy):
        if graph.edges[edge].kind == EdgeKind.ABSTRACT_MOVE:
            abstract_moves += 1
    assert_equal(abstract_moves, 1)


def test_provides_drop_a_type_condition_its_members_resolve() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(provides_on_interface.sdl()))
    var graph = build_graph(store, state)
    var pool = ProvidedPool()
    var id = pool.with_entry(store, 0, store.sym("id"), 0, False)
    var on_book = pool.with_entry(store, 0, store.sym("Book"), id, True)
    var pruned = _prune_provided(
        graph,
        store,
        state,
        pool,
        _node(graph, "Media/b"),
        on_book,
        store.sym("B"),
    )
    assert_true(pool.is_empty(pruned))


def test_graph_build_reports_a_bad_key() raises:
    var store = Store()
    var sdl = simplest_requires.sdl().replace(
        '@join__type(graph: PRODUCTS, key: "upc")',
        '@join__type(graph: PRODUCTS, key: "nope")',
    )
    with assert_raises(contains="Normalization error"):
        _ = _graph(store, sdl)


def test_an_external_field_with_requires_keeps_its_edge() raises:
    var store = Store()
    var graph = _graph(
        store,
        simplest_requires.sdl().replace(
            "@join__field(graph: INVENTORY, external: true)",
            '@join__field(graph: INVENTORY, external: true, requires: "upc")',
        ),
    )
    var found = False
    for edge in graph.edges_from(_node(graph, "Product/inventory")):
        if (
            graph.edges[edge].kind == EdgeKind.FIELD_MOVE
            and store.name(graph.edges[edge].name) == "price"
        ):
            found = graph.edges[edge].has_requirements()
    assert_true(found)


def test_a_repeated_union_member_is_one_member() raises:
    var store = Store()
    var member = '@join__unionMember(graph: A, member: "PaperBook")'
    var graph = _graph(
        store, union_list.sdl().replace(member, member + "\n  " + member)
    )
    var reference_store = Store()
    var reference = _graph(reference_store, union_list.sdl())
    assert_equal(len(graph.edges), len(reference.edges))


def test_interface_objects_without_a_resolvable_key_add_no_type_moves() raises:
    var store = Store()
    var sdl = (
        simple_interface_object.sdl()
        .replace(
            (
                '@join__type(graph: B, key: "id", isInterfaceObject: true)\n '
                ' @join__type(graph: C, key: "id", isInterfaceObject: true)'
            ),
            (
                '@join__type(graph: B, key: "id", resolvable: false,'
                " isInterfaceObject: true)\n  @join__type(graph: C,"
                " isInterfaceObject: true)"
            ),
        )
        .replace(
            (
                '@join__implements(graph: A, interface: "NodeWithName")\n '
                ' @join__type(graph: A, key: "id")'
            ),
            (
                '@join__implements(graph: A, interface: "NodeWithName")\n '
                ' @join__type(graph: A, key: "id")\n  @join__type(graph: B,'
                ' key: "id")'
            ),
        )
    )
    var graph = _graph(store, sdl)
    var type_moves = List[String]()
    for index in range(len(graph.edges)):
        ref edge = graph.edges[index]
        if edge.kind == EdgeKind.INTERFACE_OBJECT_TYPE_MOVE:
            type_moves.append(graph.node_name(store, edge.head))
    # Only `NodeWithName` in `b` keeps its type moves.
    assert_equal(len(type_moves), 1)
    assert_equal(type_moves[0], "NodeWithName/b")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
