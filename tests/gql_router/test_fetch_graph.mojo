# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the fetch graph builder.

Hive Router `1a29df9` has no separate tests for
`planner/fetch/fetch_graph.rs`; its query plan tests in
`query_planner/tests/` cover it. Each test here takes the operation of one
upstream test (named in the test), builds the fetch graph, and compares it
with the upstream trace "fetch graph before optimizations".
"""

from _fixtures import (
    abstract_types,
    mutations,
    parent_entity_call_complex,
    requires_alias_entity_interface,
    shared_root,
    simple_include_skip,
    simple_interface_object,
    simple_provides,
    simple_requires,
    testing,
    union_intersection,
)
from _fixtures import fetch_lists
from _plan_harness import _plan
from gql_language.parser import parse
from gql_router.ast import NONE, Cond, ItemKind
from gql_router.best import find_best_combination
from gql_router.federation_spec import OperationKind, TypeNode
from gql_router.fetch_graph import (
    FetchGraphBuilder,
    TypeAwareSelection,
    add_variables_to_fetch_steps,
    build_fetch_graph,
    requirements_resolve_in_place,
)
from gql_router.fetch_optimize import optimize_fetch_graph
from gql_router.fetch_step import (
    FetchGraph,
    FetchStepFlags,
    QueryPlannerOptions,
)
from gql_router.graph import (
    EdgeKind,
    Graph,
    PlannerOverrideContext,
    build_graph,
)
from gql_router.merge_path import MergePath
from gql_router.normalize import normalize_operation, selection_set_from_text
from gql_router.operation import VariableDefinition
from gql_router.query_tree import PlanSpace, TreeNode
from gql_router.store import Store
from gql_router.supergraph_state import new_supergraph_state
from gql_router.walker import Walker, requirement_ids
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _build(mut store: Store, sdl: String, query: String) raises -> FetchGraph:
    var state = new_supergraph_state(store, parse(sdl))
    var graph = build_graph(store, state)
    var operation = normalize_operation(store, state, parse(query))
    var typename = store.add_item(ItemKind.FIELD, store.sym("__typename"))
    var walker = Walker(requirement_ids(graph, store), typename)
    var ctx = PlannerOverrideContext.default()
    var resolved = walker.walk_operation(
        graph, store, state, ctx, operation.kind, operation.selection_set
    )
    var tree = find_best_combination(walker.space, graph, resolved)
    var fetch_graph = build_fetch_graph(
        store, graph, state, ctx, walker.space, tree, operation
    )
    return fetch_graph^


def _fetch_graph_text(sdl: String, query: String) raises -> String:
    var store = Store()
    var fetch_graph = _build(store, sdl, query)
    return fetch_graph.text(store)


def test_shared_root() raises:
    """Upstream `root_types.rs` `shared_root`."""
    var text = _fetch_graph_text(
        shared_root.sdl(),
        (
            "query { product { id name { id brand model } category { id name }"
            " price { id amount currency } } }"
        ),
    )
    assert_equal(
        text,
        (
            "Nodes:\n[1] [name]: Query/ -> Query/{product{name{id brand"
            " model}}} at $.\n[2] [category]: Query/ ->"
            " Query/{product{category{id name} id}} at $.\n[3] [price]: Query/"
            " -> Query/{product{price{id amount currency}}} at"
            " $.\n\nTree:\n[3]\n[2]\n[1]\n"
        ),
    )


def test_entity_call() raises:
    """Upstream `object_entities.rs` `testing`."""
    var text = _fetch_graph_text(
        testing.sdl(),
        "query { products { price { amount currency } isAvailable } }",
    )
    assert_equal(
        text,
        (
            "Nodes:\n"
            "[1] [store]: Query/ -> Query/{products{__typename id}} at $.\n"
            "[2] [cost]: Product/{__typename uuid} ->"
            " Product/{price{amount currency}} at $.products\n"
            "[3] [info]: Product/{__typename id} -> Product/{uuid} at"
            " $.products [@requires]\n"
            "[4] [info]: Product/{__typename id} -> Product/{isAvailable} at"
            " $.products\n"
            "\nTree:\n[1]\n  [2]\n  [3]\n    [2]\n  [4]\n"
        ),
    )


def test_simple_requires() raises:
    """Upstream `requires.rs` `simple_requires`."""
    var text = _fetch_graph_text(
        simple_requires.sdl(), "query { products { shippingEstimate } }"
    )
    assert_equal(
        text,
        (
            "Nodes:\n"
            "[1] [products]: Query/ -> Query/{products{__typename upc}} at $.\n"
            "[2] [inventory]: Product/{__typename upc} -> Product/ at"
            " $.products.@\n"
            "[3] [inventory]: Product/{__typename price weight upc} ->"
            " Product/{shippingEstimate} at $.products.@ [@requires]\n"
            "[4] [inventory]: Product/{__typename upc} ->"
            " Product/{__typename upc} at $.products.@ [@requires]\n"
            "[5] [products]: Product/{__typename upc} ->"
            " Product/{price weight} at $.products.@ [@requires]\n"
            "\nTree:\n[1]\n  [2]\n  [4]\n    [5]\n      [3]\n"
        ),
    )


def test_simple_provides() raises:
    """Upstream `provides.rs` `simple_provides`."""
    var text = _fetch_graph_text(
        simple_provides.sdl(),
        "query { products { reviews { author { username } } } }",
    )
    assert_equal(
        text,
        (
            "Nodes:\n"
            "[1] [products]: Query/ -> Query/{products{__typename upc}} at $.\n"
            "[2] [reviews]: Product/{__typename upc} ->"
            " Product/{reviews{author{username}}} at $.products.@\n"
            "\nTree:\n[1]\n  [2]\n"
        ),
    )


def test_interface() raises:
    """Upstream `interface.rs` `type_expand_interface_field`."""
    var text = _fetch_graph_text(
        abstract_types.sdl(), "query { products { id reviews { id } } }"
    )
    assert_equal(
        text,
        (
            "Nodes:\n"
            "[1] [products]: Query/ -> Query/{products{id __typename ...on"
            " Book{__typename id} ...on Magazine{__typename id}}} at $.\n"
            "[2] [reviews]: Book/{__typename id} -> Book/{reviews{id}} at"
            " $.products.@.|[Book]\n"
            "[3] [reviews]: Magazine/{__typename id} -> Magazine/{reviews{id}}"
            " at $.products.@.|[Magazine]\n"
            "\nTree:\n[1]\n  [2]\n  [3]\n"
        ),
    )


def test_union() raises:
    """Upstream `union.rs` `union_member_entity_call`."""
    var text = _fetch_graph_text(
        union_intersection.sdl(),
        "query { aMedia { __typename ... on Book { title aTitle bTitle } } }",
    )
    assert_equal(
        text,
        (
            "Nodes:\n"
            "[1] [a]: Query/ -> Query/{aMedia{__typename ...on"
            " Book{__typename title aTitle id}}} at $.\n"
            "[2] [b]: Book/{__typename id} -> Book/{bTitle} at"
            " $.aMedia.|[Book]\n"
            "\nTree:\n[1]\n  [2]\n"
        ),
    )


def test_include() raises:
    """Upstream `include_skip.rs` `include_basic_test`."""
    var text = _fetch_graph_text(
        simple_include_skip.sdl(),
        (
            "query ($bool: Boolean) { product { price neverCalledInclude"
            " @include(if: $bool) } }"
        ),
    )
    comptime C = " at $.product [@requires] [@include(if: $bool)]\n"
    assert_equal(
        text,
        (
            "Nodes:\n"
            "[1] [a]: Query/ -> Query/{product{__typename price id}} at $.\n"
            "[2] [c]: Product/{__typename id} -> Product/ at $.product"
            " [@include(if: $bool)]\n"
            "[3] [c]: Product/{__typename isExpensive id} ->"
            " Product/{neverCalledInclude}"
            + C
            + "[4] [c]: Product/{__typename id} -> Product/{__typename id}"
            + C
            + "[5] [b]: Product/{__typename id} -> Product/"
            + C
            + "[6] [b]: Product/{__typename price id} -> Product/{isExpensive}"
            + C
            + "[7] [b]: Product/{__typename id} -> Product/{__typename id}"
            + C
            + "[8] [a]: Product/{__typename id} -> Product/{price}"
            + C
            + "\nTree:\n[1]\n  [2]\n  [4]\n    [5]\n    [7]\n      [8]\n"
            "        [6]\n          [3]\n"
        ),
    )


def test_mutation() raises:
    """Upstream `mutations.rs` `mutations`."""
    var text = _fetch_graph_text(
        mutations.sdl(),
        (
            'mutation { addProduct(input: { name: "new", price: 599.99 }) {'
            " name price isExpensive isAvailable } }"
        ),
    )
    assert_equal(
        text,
        (
            "Nodes:\n"
            '[1] [a]: Mutation/ -> Mutation/{addProduct(input: {name: "new",'
            " price: 599.99}){__typename name price id}} at $.\n"
            "[2] [b]: Product/{__typename id} -> Product/{isAvailable} at"
            " $.addProduct\n"
            "[3] [b]: Product/{__typename price id} -> Product/{isExpensive}"
            " at $.addProduct [@requires]\n"
            "[4] [b]: Product/{__typename id} -> Product/{__typename id} at"
            " $.addProduct [@requires]\n"
            "[5] [a]: Product/{__typename id} -> Product/{price} at"
            " $.addProduct [@requires]\n"
            "\nTree:\n[1]\n  [2]\n  [4]\n    [5]\n      [3]\n"
        ),
    )


def test_requires_gets_a_wire_key() raises:
    """Upstream `alias.rs` `client_alias_named_internal_requires`."""
    var text = _fetch_graph_text(
        requires_alias_entity_interface.sdl(),
        (
            '{ things { _internal_qp_alias_0: id price(currency: "GBP") ... on'
            " Cat { eur } } }"
        ),
    )
    comptime P = " at $.things.@.|[Cat]"
    assert_equal(
        text,
        (
            "Nodes:\n"
            "[1] [shop]: Query/ -> Query/{things{_internal_qp_alias_0: id"
            ' __typename ...on Cat{__typename price(currency: "GBP") id}'
            ' ...on Dog{price(currency: "GBP")}}} at $.\n'
            "[2] [pricing]: Cat/{__typename id} -> Cat/"
            + P
            + "\n[3] [pricing]: Cat/{__typename price:"
            ' _internal_qp_alias_1(currency: "EUR") id} -> Cat/{eur}'
            + P
            + " [@requires]\n"
            "[4] [pricing]: Cat/{__typename id} -> Cat/{__typename id}"
            + P
            + " [@requires]\n"
            "[5] [shop]: Cat/{__typename id} -> Cat/{_internal_qp_alias_1:"
            ' price(currency: "EUR")}'
            + P
            + " [@requires]\n\nTree:\n[1]\n  [2]\n  [4]\n    [5]\n      [3]\n"
        ),
    )


def test_interface_object_type_move() raises:
    """Upstream `interface_object.rs`
    `interface_object_with_inline_fragment_resolving_remote_interface_field_simple`.
    """
    var text = _fetch_graph_text(
        simple_interface_object.sdl(),
        "query { anotherUsers { ... on User { username } } }",
    )
    assert_equal(
        text,
        (
            "Nodes:\n"
            "[1] [b]: Query/ -> Query/{anotherUsers{__typename}} at $.\n"
            "[2] [b]: User/{__typename id} -> NodeWithName/{username} at"
            " $.anotherUsers.@\n"
            "[3] [b]: User/{__typename id} -> NodeWithName/{__typename id} at"
            " $.anotherUsers.@\n"
            "[4] [a]: NodeWithName/{__typename id} ->"
            " NodeWithName/{__typename} at $.anotherUsers.@ [@requires]"
            " [no_pass_through]\n"
            "\nTree:\n[1]\n  [3]\n    [4]\n      [2]\n"
        ),
    )


def test_add_variables_to_fetch_steps() raises:
    """Upstream `arguments.rs` `arguments_variables_mixed`: only the step
    that uses `$secondProductId` gets its definition."""
    var store = Store()
    var query = String(
        "query test($secondProductId: ID!) { firstProduct: productFromD(id:"
        ' "1") { id name category { id name details } } secondProduct:'
        " productFromD(id: $secondProductId) { id name category { id name"
        " details } } }"
    )
    var fetch_graph = _build(store, parent_entity_call_complex.sdl(), query)
    var state = new_supergraph_state(
        store, parse(parent_entity_call_complex.sdl())
    )
    var operation = normalize_operation(store, state, parse(query))
    fetch_graph.collect_variable_usages(store)
    add_variables_to_fetch_steps(
        fetch_graph, operation.variables, operation.has_variables
    )
    assert_true(fetch_graph.steps[1].has_variable_definitions)
    assert_equal(len(fetch_graph.steps[1].variable_definitions), 1)
    var out = String()
    fetch_graph.steps[1].variable_definitions[0].write(store, out)
    assert_equal(out, "$secondProductId:ID!")
    for index in range(2, 8):
        assert_false(fetch_graph.steps[index].has_variable_definitions)


def test_add_variables_skips_unknown_usages() raises:
    var store = Store()
    var builder = FetchGraphBuilder(OperationKind.QUERY)
    var root = builder.create_noop_fetch_step(False)
    var used = builder.create_noop_fetch_step(False)
    builder.fetch_graph.steps[used].variable_usages = [
        store.sym("a"),
        store.sym("z"),
    ]
    builder.fetch_graph.steps[used].has_variable_usages = True
    var variables: List[VariableDefinition] = [
        VariableDefinition(
            store.sym("b"), TypeNode(store.sym("ID"), "%"), NONE
        ),
        VariableDefinition(
            store.sym("a"), TypeNode(store.sym("ID"), "%"), NONE
        ),
    ]
    var fetch_graph = builder^.into_fetch_graph()
    add_variables_to_fetch_steps(fetch_graph, variables, True)
    assert_false(fetch_graph.steps[root].has_variable_definitions)
    assert_equal(len(fetch_graph.steps[used].variable_definitions), 1)
    assert_equal(
        fetch_graph.steps[used].variable_definitions[0].name, store.sym("a")
    )


def _tree(edge: Int, var requirements: List[Int]) -> TreeNode:
    return TreeNode(
        0,
        edge,
        requirements^,
        List[Int](),
        False,
        NONE,
        NONE,
        Cond.none(),
        NONE,
        0,
    )


def _edge_of(graph: Graph, kind: EdgeKind) raises -> Int:
    for index in range(len(graph.edges)):
        if graph.edges[index].kind == kind:
            return index
    raise Error("no edge of that kind")


def _resolves_in_place(graph: Graph, edge: Int) -> Bool:
    var space = PlanSpace()
    space.trees.append(_tree(edge, List[Int]()))
    space.trees.append(_tree(NONE, [0]))
    return requirements_resolve_in_place(graph, space, 1)


def test_requirements_resolve_in_place() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(abstract_types.sdl()))
    var graph = build_graph(store, state)
    assert_true(_resolves_in_place(graph, _edge_of(graph, EdgeKind.FIELD_MOVE)))
    assert_true(
        _resolves_in_place(graph, _edge_of(graph, EdgeKind.ABSTRACT_MOVE))
    )
    assert_true(_resolves_in_place(graph, _edge_of(graph, EdgeKind.SELFIE)))
    assert_false(
        _resolves_in_place(graph, _edge_of(graph, EdgeKind.ENTITY_MOVE))
    )
    # A requirement with requirements of its own leaves the subgraph.
    var space = PlanSpace()
    space.trees.append(_tree(NONE, List[Int]()))
    space.trees.append(_tree(NONE, [0]))
    space.trees.append(_tree(NONE, [1]))
    assert_false(requirements_resolve_in_place(graph, space, 2))


def test_builder_reuses_a_step_for_the_same_key() raises:
    var store = Store()
    var builder = FetchGraphBuilder(OperationKind.QUERY)
    var root = builder.create_noop_fetch_step(True)
    assert_true(
        builder.fetch_graph.steps[root].flags.contains(
            FetchStepFlags.USED_FOR_REQUIRES
        )
    )
    var book = store.sym("Book")
    var service = store.sym("s")
    var at = MergePath()
    var by_id = TypeAwareSelection(
        book, selection_set_from_text(store, "{ id }")
    )
    var by_isbn = TypeAwareSelection(
        book, selection_set_from_text(store, "{ isbn }")
    )
    var by_film = TypeAwareSelection(
        store.sym("Film"), selection_set_from_text(store, "{ id }")
    )
    var no_selection = TypeAwareSelection(NONE, NONE)
    var first = builder.ensure_fetch_step_for_subgraph(
        store,
        root,
        service,
        book,
        book,
        at,
        by_id,
        no_selection,
        Cond.none(),
        False,
    )
    # The caller connects a new call to its parent.
    _ = builder.fetch_graph.connect(root, first)
    assert_equal(
        builder.ensure_fetch_step_for_subgraph(
            store,
            root,
            service,
            book,
            book,
            at,
            by_id,
            no_selection,
            Cond.none(),
            False,
        ),
        first,
    )
    # Without a key any matching call does.
    assert_equal(
        builder.ensure_fetch_step_for_subgraph(
            store,
            root,
            service,
            book,
            book,
            at,
            no_selection,
            no_selection,
            Cond.none(),
            False,
        ),
        first,
    )
    # Another key, a key of another type, or a requirement: a new call.
    var other_key = builder.ensure_fetch_step_for_subgraph(
        store,
        root,
        service,
        book,
        book,
        at,
        by_isbn,
        no_selection,
        Cond.none(),
        False,
    )
    assert_true(other_key != first)
    var other_type = builder.ensure_fetch_step_for_subgraph(
        store,
        root,
        service,
        book,
        book,
        at,
        by_film,
        no_selection,
        Cond.none(),
        False,
    )
    assert_true(other_type != first and other_type != other_key)
    var requires = builder.ensure_fetch_step_for_subgraph(
        store,
        root,
        service,
        book,
        book,
        at,
        no_selection,
        by_id,
        Cond.none(),
        False,
    )
    assert_true(
        builder.fetch_graph.steps[requires].flags.contains(
            FetchStepFlags.USED_FOR_REQUIRES
        )
    )
    # A requirement reuses a call whose input already has it.
    var holder = builder.ensure_fetch_step_for_requirement(
        store, root, service, book, at, Cond.none(), by_id
    )
    _ = builder.fetch_graph.connect(root, holder)
    builder.fetch_graph.steps[holder].input.add(store, by_id.selection_set)
    assert_equal(
        builder.ensure_fetch_step_for_requirement(
            store, root, service, book, at, Cond.none(), by_id
        ),
        holder,
    )


def test_no_satisfiable_key_raises() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(abstract_types.sdl()))
    var graph = build_graph(store, state)
    var space = PlanSpace()
    var tree = _tree(NONE, List[Int]())
    tree.node_index = graph.query_root
    space.trees.append(tree^)
    var builder = FetchGraphBuilder(OperationKind.QUERY)
    var message = String()
    try:
        _ = builder.find_satisfiable_key(
            store, graph, state, PlannerOverrideContext.default(), space, 0
        )
    except e:
        message = String(e)
    assert_equal(message, "Internal Error: Failed to find Satisfiable Key")


def test_optimize_fetch_graph_cuts_the_subgraphs_itself() raises:
    var store = Store()
    var fetch_graph = _build(
        store, shared_root.sdl(), "query { product { id name { id brand } } }"
    )
    var state = new_supergraph_state(store, parse(shared_root.sdl()))
    optimize_fetch_graph(
        store, state, fetch_graph, QueryPlannerOptions.default()
    )
    assert_true(fetch_graph.step_count > 0)


def test_lists_below_requires_and_root_reentries() raises:
    var requires = _plan(fetch_lists.sdl(), "{ products { parcels { size } } }")
    assert_true('Flatten(path: "products.@")' in requires, requires)
    var reentry = _plan(fetch_lists.sdl(), "{ products { queries { top } } }")
    assert_true('Flatten(path: "products.@.queries.@")' in reentry, reentry)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
