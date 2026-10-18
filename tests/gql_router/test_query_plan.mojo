# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for plan nodes, the query plan and its optimizer.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/planner/query_plan/optimize.rs`,
`ast/minification/mod.rs`, `ast/minification/transform.rs` and
`planner/plan_nodes/path.rs`. The fetch graphs are built by hand from the
fetch graphs that upstream prints for the snapshot tests of
`query_planner/tests/`, and the plans are checked against those
snapshots.
"""

from _fixtures import query_plan_optimize as snapshots
from _fixtures import (
    mutations,
    parent_entity_call_complex,
    simple_include_skip,
    simple_requires,
)
from gql_language.parser import parse
from gql_router.ast import NONE, Cond, ItemKind
from gql_router.federation_spec import OperationKind, type_node_from_text
from gql_router.fetch_operation import (
    FetchDocument,
    FragmentDefinition,
    PlanningFetchOperation,
    inline_fragment_spreads,
    inner_selection_set,
)
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
from gql_router.minification import generate_fragment_name, minify_operation
from gql_router.normalize import selection_set_from_text
from gql_router.operation import OperationDefinition, VariableDefinition
from gql_router.plan_nodes import (
    BatchFetchNode,
    EntityBatchAlias,
    FetchNode,
    FlattenNodePath,
    PathSegmentKind,
    PlanNode,
    PlanNodeKind,
    QueryPlan,
    fetch_node_from_fetch_step,
    representations_type,
)
from gql_router.query_plan import InDegree, build_query_plan_from_fetch_graph
from gql_router.query_plan_optimize import (
    BatchFetchBuilder,
    EntityFetch,
    build_batched_fetch_node,
    can_merge_variable_definitions,
    entity_fetch_from_node,
    merge_variable_definitions,
    next_unique_representations_var_name,
    optimize_plan_sequence,
    optimize_root_node,
    partition_by_shape,
    partition_by_variables_compatibility,
    representations_variable_name,
    rewrites_equal,
)
from gql_router.store import Store
from gql_router.supergraph_state import SupergraphState, new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_false, assert_true


# --- helpers ---------------------------------------------------------------


def _selections(
    mut store: Store, type_name: StringSlice, query: String
) raises -> FetchStepSelections:
    """Return single-type selections read from `{ ... }` text."""
    var set = selection_set_from_text(store, query)
    return FetchStepSelections([store.sym(type_name)], [set])


def _path(mut store: Store, fields: String) -> MergePath:
    """Return a merge path of fields; `@` is a list step."""
    var segments = List[Segment]()
    for part in fields.split("."):
        if part == "@":
            segments.append(Segment.list())
        else:
            segments.append(
                Segment.field(store.sym(part), NONE, NONE, Cond.none())
            )
    return MergePath(segments^)


def _root_step(mut store: Store) -> FetchStepData:
    """Return the root step of a graph."""
    return FetchStepData(
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


def _root_call(
    mut store: Store, id: Int, service: StringSlice, output: String
) raises -> FetchStepData:
    """Return a query root call."""
    return FetchStepData(
        id,
        store.sym(service),
        MergePath(),
        FetchStepSelections([store.sym("Query")], [store.new_set()]),
        _selections(store, "Query", output),
        FetchStepKind.ROOT,
        OperationKind.QUERY,
        FetchStepFlags.EMPTY,
        Cond.none(),
        NONE,
    )


def _entity_call(
    mut store: Store,
    id: Int,
    service: StringSlice,
    path: String,
    type_name: StringSlice,
    input: String,
    output: String,
    cond: Cond,
) raises -> FetchStepData:
    """Return an entity call."""
    return FetchStepData(
        id,
        store.sym(service),
        _path(store, path),
        _selections(store, type_name, input),
        _selections(store, type_name, output),
        FetchStepKind.ENTITY,
        OperationKind.QUERY,
        FetchStepFlags.USED_FOR_REQUIRES,
        cond,
        NONE,
    )


def _variable(
    mut store: Store, name: StringSlice, type_text: String
) raises -> VariableDefinition:
    """Return a variable definition with no default value."""
    return VariableDefinition(
        store.sym(name), type_node_from_text(store, type_text), NONE
    )


# --- query plans -----------------------------------------------------------


def test_include_basic() raises:
    """Upstream `include_skip.rs` `include_basic_test`."""
    var store = Store()
    var state = new_supergraph_state(store, parse(simple_include_skip.sdl()))
    var graph = FetchGraph(OperationKind.QUERY)
    graph.root_index = graph.add_step(_root_step(store))
    var a = _root_call(
        store,
        1,
        "a",
        "{ product { __typename price id ... on Product @include(if: $bool)"
        + " { price __typename id } } }",
    )
    a.variable_definitions = [_variable(store, "bool", "Boolean")]
    a.has_variable_definitions = True
    a.variable_usages = [store.sym("bool")]
    a.has_variable_usages = True
    var condition = Cond(NONE, store.sym("bool"))
    var step_a = graph.add_step(a^)
    var step_b = graph.add_step(
        _entity_call(
            store,
            6,
            "b",
            "product",
            "Product",
            "{ __typename price id }",
            "{ isExpensive }",
            condition,
        )
    )
    var step_c = graph.add_step(
        _entity_call(
            store,
            3,
            "c",
            "product",
            "Product",
            "{ __typename isExpensive id }",
            "{ neverCalledInclude }",
            condition,
        )
    )
    _ = graph.connect(graph.root_index, step_a)
    _ = graph.connect(step_a, step_b)
    _ = graph.connect(step_b, step_c)
    var plan = build_query_plan_from_fetch_graph(store, graph, state)
    assert_equal(
        plan.text(store),
        """QueryPlan {
  Sequence {
    Fetch(service: "a") {
      query ($bool:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @include(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Include(if: $bool) {
      Sequence {
        Flatten(path: "product") {
          Fetch(service: "b") {
            {
              ... on Product {
                __typename
                price
                id
              }
            } =>
            {
              ... on Product {
                isExpensive
              }
            }
          },
        },
        Flatten(path: "product") {
          Fetch(service: "c") {
            {
              ... on Product {
                __typename
                isExpensive
                id
              }
            } =>
            {
              ... on Product {
                neverCalledInclude
              }
            }
          },
        },
      },
    },
  },
},
""",
    )


def test_skip_and_include_fragment_condition() raises:
    """Upstream `include_skip.rs` `skip_and_include_fragment_condition_test`."""
    var store = Store()
    var state = new_supergraph_state(store, parse(simple_include_skip.sdl()))
    var graph = FetchGraph(OperationKind.QUERY)
    graph.root_index = graph.add_step(_root_step(store))
    var a = _root_call(
        store,
        1,
        "a",
        "{ product { price ... on Product @skip(if: $skip)"
        + " @include(if: $include) { __typename id price } } }",
    )
    a.variable_definitions = [
        _variable(store, "include", "Boolean"),
        _variable(store, "skip", "Boolean"),
    ]
    a.has_variable_definitions = True
    var condition = Cond(store.sym("skip"), store.sym("include"))
    var segments = _path(store, "product").segments.copy()
    segments.append(
        Segment.type_condition(
            store.single_type_set(store.sym("Product")), condition
        )
    )
    var b = _entity_call(
        store,
        6,
        "b",
        "product",
        "Product",
        "{ __typename price id }",
        "{ isExpensive }",
        condition,
    )
    b.response_path = MergePath(segments.copy())
    var c = _entity_call(
        store,
        3,
        "c",
        "product",
        "Product",
        "{ __typename isExpensive id }",
        "{ neverCalledInclude }",
        condition,
    )
    c.response_path = MergePath(segments^)
    var step_a = graph.add_step(a^)
    var step_b = graph.add_step(b^)
    var step_c = graph.add_step(c^)
    _ = graph.connect(graph.root_index, step_a)
    _ = graph.connect(step_a, step_b)
    _ = graph.connect(step_b, step_c)
    var plan = build_query_plan_from_fetch_graph(store, graph, state)
    assert_equal(
        plan.text(store),
        """QueryPlan {
  Sequence {
    Fetch(service: "a") {
      query ($include:Boolean,$skip:Boolean) {
        product {
          price
          ... on Product @skip(if: $skip) @include(if: $include) {
            __typename
            id
            price
          }
        }
      }
    },
    Skip(if: $skip) {
      Include(if: $include) {
        Sequence {
          Flatten(path: "product|[Product]") {
            Fetch(service: "b") {
              {
                ... on Product {
                  __typename
                  price
                  id
                }
              } =>
              {
                ... on Product {
                  isExpensive
                }
              }
            },
          },
          Flatten(path: "product|[Product]") {
            Fetch(service: "c") {
              {
                ... on Product {
                  __typename
                  isExpensive
                  id
                }
              } =>
              {
                ... on Product {
                  neverCalledInclude
                }
              }
            },
          },
        },
      },
    },
  },
},
""",
    )


def test_mutations() raises:
    """Upstream `mutations.rs` `mutations`."""
    var store = Store()
    var state = new_supergraph_state(store, parse(mutations.sdl()))
    var graph = FetchGraph(OperationKind.MUTATION)
    graph.root_index = graph.add_step(_root_step(store))
    var a = _root_call(
        store,
        1,
        "a",
        '{ addProduct(input: { name: "new", price: 599.99 })'
        + " { __typename name price id } }",
    )
    a.operation_kind = OperationKind.MUTATION
    a.output = _selections(
        store,
        "Mutation",
        '{ addProduct(input: { name: "new", price: 599.99 })'
        + " { __typename name price id } }",
    )
    var b = _entity_call(
        store,
        3,
        "b",
        "addProduct",
        "Product",
        "{ __typename price id }",
        "{ isExpensive isAvailable }",
        Cond.none(),
    )
    var step_a = graph.add_step(a^)
    var step_b = graph.add_step(b^)
    _ = graph.connect(graph.root_index, step_a)
    _ = graph.connect(step_a, step_b)
    var plan = build_query_plan_from_fetch_graph(store, graph, state)
    assert_equal(
        plan.text(store),
        """QueryPlan {
  Sequence {
    Fetch(service: "a") {
      mutation {
        addProduct(input: {name: "new", price: 599.99}) {
          __typename
          name
          price
          id
        }
      }
    },
    Flatten(path: "addProduct") {
      Fetch(service: "b") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        {
          ... on Product {
            isExpensive
            isAvailable
          }
        }
      },
    },
  },
},
""",
    )
    var executable = plan^.into_executable()
    var text = executable.text(store)
    assert_true(
        'mutation{addProduct(input: {name: "new", price: 599.99})'
        + "{__typename name price id}}\n"
        in text
    )
    assert_true(
        "query($representations:[_Any!]!){_entities(representations:"
        + " $representations){...on Product{isExpensive isAvailable}}}"
        in text
    )


def test_parent_entity_call_complex() raises:
    """Upstream `object_entities.rs` `parent_entity_call_complex`: a wave
    of two steps is a `Parallel` node."""
    var store = Store()
    var state = new_supergraph_state(
        store, parse(parent_entity_call_complex.sdl())
    )
    var graph = FetchGraph(OperationKind.QUERY)
    graph.root_index = graph.add_step(_root_step(store))
    var d = graph.add_step(
        _root_call(
            store, 1, "d", '{ productFromD(id: "1") { __typename id name } }'
        )
    )
    var b = graph.add_step(
        _entity_call(
            store,
            2,
            "b",
            "productFromD",
            "Product",
            "{ __typename id }",
            "{ category { __typename id } }",
            Cond.none(),
        )
    )
    var c = graph.add_step(
        _entity_call(
            store,
            3,
            "c",
            "productFromD.category",
            "Category",
            "{ __typename id }",
            "{ name }",
            Cond.none(),
        )
    )
    var a = graph.add_step(
        _entity_call(
            store,
            4,
            "a",
            "productFromD",
            "Product",
            "{ __typename id }",
            "{ category { details } }",
            Cond.none(),
        )
    )
    _ = graph.connect(graph.root_index, d)
    _ = graph.connect(d, b)
    _ = graph.connect(b, c)
    _ = graph.connect(d, a)
    var plan = build_query_plan_from_fetch_graph(store, graph, state)
    assert_equal(
        plan.text(store),
        """QueryPlan {
  Sequence {
    Fetch(service: "d") {
      {
        productFromD(id: "1") {
          __typename
          id
          name
        }
      }
    },
    Parallel {
      Flatten(path: "productFromD") {
        Fetch(service: "a") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              category {
                details
              }
            }
          }
        },
      },
      Flatten(path: "productFromD") {
        Fetch(service: "b") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              category {
                __typename
                id
              }
            }
          }
        },
      },
    },
    Flatten(path: "productFromD.category") {
      Fetch(service: "c") {
        {
          ... on Category {
            __typename
            id
          }
        } =>
        {
          ... on Category {
            name
          }
        }
      },
    },
  },
},
""",
    )


# --- minification ----------------------------------------------------------


comptime _MINIFICATION_SCHEMA = """
interface Product {
  id: ID!
  name: String
  distributor: BusinessEntity
}

interface BusinessEntity {
  id: ID!
  name: String
}

type Query {
  product(id: ID!): Product
}

type Book implements Product {
  id: ID!
  name: String
  distributor: BusinessEntity
  relatedProducts: [Product]
}

type Electronic implements Product {
  id: ID!
  name: String
  distributor: BusinessEntity
}

type Supplier implements BusinessEntity {
  id: ID!
  name: String
  licenseNumber: String
}

type Vendor implements BusinessEntity {
  id: ID!
  name: String
  preferred: Boolean
}

type Manufacturer implements BusinessEntity {
  id: ID!
  name: String
  country: String
}
"""

comptime _FULL = (
    "{ id name ... on Supplier { licenseNumber __typename }"
    " ... on Vendor { preferred __typename }"
    " ... on Manufacturer { country __typename } }"
)
comptime _PARTIAL = "{ id name ... on Manufacturer { country __typename } }"


def test_minification() raises:
    """Upstream `minification/mod.rs` `minification_test`, from the
    normalized operation of its first snapshot."""
    var store = Store()
    var state = new_supergraph_state(store, parse(_MINIFICATION_SCHEMA))
    var set = selection_set_from_text(
        store,
        "{ product(id: $id) { id name distributor "
        + _FULL
        + " ... on Book { relatedProducts { id name distributor "
        + _FULL
        + " ... on Book { relatedProducts { id distributor "
        + _PARTIAL
        + " } } } } ... on Electronic { distributor "
        + _PARTIAL
        + " } } }",
    )
    var operation = OperationDefinition(OperationKind.QUERY, set)
    operation.variables = [_variable(store, "id", "ID!")]
    operation.has_variables = True
    var document = minify_operation(store, operation^, state)
    assert_equal(
        document.text(store),
        "query($id:ID!){product(id: $id){id name distributor{...a}"
        + " ...on Book{relatedProducts{id name distributor{...a}"
        + " ...on Book{relatedProducts{id distributor{...c}}}}}"
        + " ...on Electronic{distributor{...c}}}}\n\n"
        + "fragment a on BusinessEntity {id name"
        + " ...on Supplier{licenseNumber __typename}"
        + " ...on Vendor{preferred __typename}"
        + " ...on Manufacturer{...b}}\n"
        + "fragment b on Manufacturer {country __typename}\n"
        + "fragment c on BusinessEntity {id name ...on Manufacturer{...b}}\n",
    )
    var fetch = PlanningFetchOperation(document^, store)
    assert_equal(fetch.name_write_position, 5)
    var out = String()
    fetch.pretty(store, out, 0)
    assert_true(out.startswith("  query ($id:ID!) {\n    product(id: $id) {\n"))
    assert_true(
        "  fragment b on Manufacturer {\n    country\n    __typename\n  }\n"
        in out
    )


def test_minification_without_duplicates_keeps_operation() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(_MINIFICATION_SCHEMA))
    var set = selection_set_from_text(store, "{ product(id: 1) { id } }")
    var document = minify_operation(
        store, OperationDefinition(OperationKind.QUERY, set), state
    )
    assert_equal(len(document.fragments), 0)
    assert_equal(document.text(store), "{product(id: 1){id}}")


def test_minification_errors() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(_MINIFICATION_SCHEMA))
    var cases: List[String] = [
        "{ missing }",
        "{ ...spread }",
        "{ _entities { name } }",
        "{ _entities { ...spread } }",
        "{ ... on Unknown { id } }",
    ]
    var messages: List[String] = [
        "Field 'missing' not found in type 'Query'",
        "Unsupported fragment spread",
        "Unsupported field in `_entities`: Query.name",
        "Unsupported fragment spread",
        "Type not found: Unknown",
    ]
    for index in range(len(cases)):
        var set = selection_set_from_text(store, cases[index])
        var message = String()
        try:
            _ = minify_operation(
                store, OperationDefinition(OperationKind.QUERY, set), state
            )
        except error:
            message = String(error)
        assert_equal(message, messages[index])
    var message = String()
    try:
        _ = minify_operation(
            store,
            OperationDefinition(OperationKind.MUTATION, store.new_set()),
            state,
        )
    except error:
        message = String(error)
    assert_equal(message, "Type not found for operation kind: mutation")


def test_subscription() raises:
    """A root subscription call is a `Subscription` node."""
    var store = Store()
    var sdl = simple_include_skip.sdl().replace(
        "  query: Query\n", "  query: Query\n  subscription: Query\n"
    )
    var state = new_supergraph_state(store, parse(sdl))
    var graph = FetchGraph(OperationKind.SUBSCRIPTION)
    graph.root_index = graph.add_step(_root_step(store))
    var a = _root_call(store, 1, "a", "{ product { price } }")
    a.operation_kind = OperationKind.SUBSCRIPTION
    var step_a = graph.add_step(a^)
    _ = graph.connect(graph.root_index, step_a)
    var plan = build_query_plan_from_fetch_graph(store, graph, state)
    assert_equal(
        plan.text(store),
        """QueryPlan {
  Subscription {
    Fetch(service: "a") {
      subscription {
        product {
          price
        }
      }
    },
  },
},
""",
    )
    assert_equal(plan.fetches[0].operation.name_write_position, 12)


def _plan_error(
    mut store: Store, graph: FetchGraph, state: SupergraphState
) -> String:
    """Return the error of building a plan, or an empty text."""
    try:
        _ = build_query_plan_from_fetch_graph(store, graph, state)
    except error:
        return String(error)
    return String()


def test_build_errors() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(simple_include_skip.sdl()))
    var no_root = FetchGraph(OperationKind.QUERY)
    assert_equal(_plan_error(store, no_root, state), "Root fetch is missing")
    var empty = FetchGraph(OperationKind.QUERY)
    empty.root_index = empty.add_step(_root_step(store))
    assert_equal(_plan_error(store, empty, state), "Failed to build a plan")
    # A step the root does not reach is never planned.
    var unreachable = FetchGraph(OperationKind.QUERY)
    unreachable.root_index = unreachable.add_step(_root_step(store))
    var one = unreachable.add_step(
        _root_call(store, 1, "a", "{ product { price } }")
    )
    _ = unreachable.add_step(_root_call(store, 2, "a", "{ product { price } }"))
    _ = unreachable.connect(unreachable.root_index, one)
    assert_equal(
        _plan_error(store, unreachable, state), "Internal Error: Cycle detected"
    )
    # A root child with another parent.
    var shared = FetchGraph(OperationKind.QUERY)
    shared.root_index = shared.add_step(_root_step(store))
    var first = shared.add_step(
        _root_call(store, 1, "a", "{ product { price } }")
    )
    var second = shared.add_step(
        _root_call(store, 2, "a", "{ product { price } }")
    )
    _ = shared.connect(shared.root_index, first)
    _ = shared.connect(shared.root_index, second)
    _ = shared.connect(second, first)
    assert_equal(
        _plan_error(store, shared, state),
        "Internal Error: Root's child (1) has more than one parent",
    )
    # A cycle below the root.
    var cycle = FetchGraph(OperationKind.QUERY)
    cycle.root_index = cycle.add_step(_root_step(store))
    var x = cycle.add_step(_root_call(store, 1, "a", "{ product { price } }"))
    var y = cycle.add_step(_root_call(store, 2, "a", "{ product { price } }"))
    var z = cycle.add_step(_root_call(store, 3, "a", "{ product { price } }"))
    _ = cycle.connect(cycle.root_index, x)
    _ = cycle.connect(x, y)
    _ = cycle.connect(y, z)
    _ = cycle.connect(z, y)
    assert_equal(
        _plan_error(store, cycle, state), "Internal Error: Cycle detected"
    )


def test_condition_node_text_errors() raises:
    var store = Store()
    var plan = QueryPlan()
    var flag = store.sym("flag")
    var both = plan.add_condition(
        flag,
        plan.add_list(PlanNodeKind.SEQUENCE, []),
        plan.add_list(PlanNodeKind.SEQUENCE, []),
    )
    var message = String()
    try:
        _ = plan.node_text(store, both)
    except error:
        message = String(error)
    assert_equal(
        message,
        "not yet implemented: Implement pretty_fmt for ConditionNode with"
        + " both if and else clauses",
    )
    plan.node = plan.add_condition(flag, NONE, NONE)
    message = String()
    try:
        _ = plan.text(store)
    except error:
        message = String(error)
    assert_equal(message, "Invalid condition node")
    var empty = QueryPlan()
    assert_equal(empty.text(store), "QueryPlan {\n  None,\n},\n")


def test_merges_adjacent_skip_conditions() raises:
    var store = Store()
    var plan = QueryPlan()
    var flag = store.sym("flag")
    var a = plan.add_list(PlanNodeKind.PARALLEL, [])
    var b = plan.add_list(PlanNodeKind.PARALLEL, [])
    var first = plan.under_condition(a, Cond(flag, NONE))
    var second = plan.under_condition(b, Cond(flag, NONE))
    var other = plan.under_condition(b, Cond(NONE, flag))
    assert_true(plan.can_merge_with(first, second))
    assert_true(not plan.can_merge_with(first, other))
    assert_true(
        not plan.can_merge_with(
            first, plan.add_condition(store.sym("x"), NONE, a)
        )
    )
    plan.merge_condition(first, second)
    assert_equal(plan.nodes[first].if_clause, NONE)
    assert_equal(len(plan.nodes[plan.nodes[first].else_clause].nodes), 2)
    assert_equal(plan.into_nodes(first), [first])
    assert_equal(len(plan.into_nodes(a)), 0)
    assert_equal(plan.nodes[a].kind.name(), "Parallel")


def test_flatten_node_path_text() raises:
    """Upstream `path.rs` `names_are_sorted_and_deduplicated`: a type
    condition is sorted and has each name once."""
    var store = Store()
    var media = Segment.field(store.sym("media"), NONE, NONE, Cond.none())
    var types = store.type_set(
        [store.sym("User"), store.sym("Book"), store.sym("User")]
    )
    var path = FlattenNodePath.from_merge_path(
        MergePath(
            [
                media,
                Segment.type_condition(types, Cond.none()),
                Segment.list(),
                Segment.field(
                    store.sym("id"), store.sym("key"), NONE, Cond.none()
                ),
            ]
        )
    )
    assert_equal(path.text(store), "media|[Book|User].@.key")
    assert_equal(len(path), 4)
    assert_true(not path.is_empty())
    var tidy = FlattenNodePath.from_merge_path(
        MergePath(
            [
                media,
                Segment.type_condition(
                    store.type_set([store.sym("Book"), store.sym("User")]),
                    Cond.none(),
                ),
                Segment.list(),
                Segment.field(
                    store.sym("id"), store.sym("key"), NONE, Cond.none()
                ),
            ]
        )
    )
    assert_true(path == tidy)
    assert_true(path != FlattenNodePath())


def test_inline_fragment_spread_errors() raises:
    var store = Store()
    var set = selection_set_from_text(store, "{ ...A }")
    var message = String()
    try:
        _ = inline_fragment_spreads(store, set, List[FragmentDefinition]())
    except error:
        message = String(error)
    assert_equal(message, "Could not find fragment definition 'A'")
    var fragments: List[FragmentDefinition] = [
        _fragment(store, "A", "User", "{ id ...A }")
    ]
    message = String()
    try:
        _ = inline_fragment_spreads(store, set, fragments)
    except error:
        message = String(error)
    assert_equal(message, "Detected cycle while expanding fragment spread 'A'")


def test_optimize_flatten_must_wrap_fetch() raises:
    var f = _Fixture()
    var inner = f.plan.add_list(PlanNodeKind.SEQUENCE, [])
    var flatten = f.plan.add_flatten(FlattenNodePath(), inner)
    var message = String()
    try:
        _ = optimize_root_node(f.store, f.plan, flatten, f.state)
    except error:
        message = String(error)
    assert_equal(
        message,
        "Internal Error: FlattenNode is expected to wrap a FetchNode, got"
        + " Sequence",
    )


def test_generate_fragment_name() raises:
    """Upstream `transform.rs` `generate_fragment_name_test`."""
    var size = 52
    var index = 0
    assert_equal(generate_fragment_name(index), "a")
    assert_equal(index, 1)
    assert_equal(generate_fragment_name(index), "b")
    index = 26
    assert_equal(generate_fragment_name(index), "A")
    index = size - 1
    assert_equal(generate_fragment_name(index), "Z")
    index = size
    assert_equal(generate_fragment_name(index), "ab")
    index = size + 1
    assert_equal(generate_fragment_name(index), "bb")
    index = size * 2
    assert_equal(generate_fragment_name(index), "ac")
    index = size * size - 1
    assert_equal(generate_fragment_name(index), "ZZ")
    index = size * size
    assert_equal(generate_fragment_name(index), "aab")
    index = size * size + 1
    assert_equal(generate_fragment_name(index), "bab")
    index = size * size * 2
    assert_equal(generate_fragment_name(index), "aac")
    index = size * size * size - 1
    assert_equal(generate_fragment_name(index), "ZZZ")


# --- optimizer -------------------------------------------------------------

comptime _REQUIRES_UPC = "{ ... on Product { upc } }"
comptime _SHIPPING = (
    "{ _entities(representations: $representations)"
    " { ... on Product { shippingEstimate } } }"
)
comptime _IN_STOCK = (
    "{ _entities(representations: $representations)"
    " { ... on Product { inStock } } }"
)


struct _Fixture(Movable):
    """A store, a supergraph and a plan, as the upstream optimizer tests
    use."""

    var store: Store
    """The store."""
    var state: SupergraphState
    """The `simple-requires` supergraph, upstream `test_supergraph_state`."""
    var plan: QueryPlan
    """The plan that holds the nodes."""

    def __init__(out self) raises:
        """Read the supergraph."""
        self.store = Store()
        self.state = new_supergraph_state(
            self.store, parse(simple_requires.sdl())
        )
        self.plan = QueryPlan()

    def entity(
        mut self,
        id: Int,
        service: StringSlice,
        root_path_field: String,
        requires_query: String,
        entities_query: String,
        var extra_variables: List[VariableDefinition] = [],
        var fragments: List[FragmentDefinition] = [],
    ) raises -> Int:
        """Return upstream `flatten_entity_fetch_node`.

        Args:
            id: The fetch id.
            service: The subgraph.
            root_path_field: The field of the path `field.@`.
            requires_query: The representations selection.
            entities_query: The `_entities` operation set.
            extra_variables: The variables after `$representations`.
            fragments: The fragments of the document.

        Returns:
            The `Flatten` node.
        """
        var requires = selection_set_from_text(self.store, requires_query)
        var set = selection_set_from_text(self.store, entities_query)
        var operation = OperationDefinition(OperationKind.QUERY, set)
        var representations = self.store.sym("representations")
        operation.variables = [
            VariableDefinition(
                representations, representations_type(self.store), NONE
            )
        ]
        var usages = List[Int]()
        for variable in extra_variables:
            operation.variables.append(variable.copy())
            var at = len(usages)
            while at > 0 and self.store.less(variable.name, usages[at - 1]):
                at -= 1
            usages.insert(at, variable.name)
        operation.has_variables = True
        var document = FetchDocument(operation^, fragments^)
        var fetch = FetchNode(
            id,
            self.store.sym(service),
            OperationKind.QUERY,
            PlanningFetchOperation(document^, self.store),
            requires,
        )
        fetch.variable_usages = usages^
        fetch.has_variable_usages = len(fetch.variable_usages) > 0
        var child = self.plan.add_fetch(fetch^)
        return self.plan.add_flatten(
            FlattenNodePath.from_merge_path(
                _path(self.store, root_path_field + ".@")
            ),
            child,
        )

    def non_entity(mut self, id: Int, service: StringSlice) raises -> Int:
        """Return upstream `non_entity_fetch_node`, as a `Fetch` node.

        Args:
            id: The fetch id.
            service: The subgraph.

        Returns:
            The node.
        """
        var set = selection_set_from_text(self.store, "{ products { upc } }")
        var document = FetchDocument(
            OperationDefinition(OperationKind.QUERY, set),
            List[FragmentDefinition](),
        )
        return self.plan.add_fetch(
            FetchNode(
                id,
                self.store.sym(service),
                OperationKind.QUERY,
                PlanningFetchOperation(document^, self.store),
                NONE,
            )
        )

    def with_rewrite(mut self, node: Int, input: Bool) -> Int:
        """Set a `ValueSetter` on `upc`, as upstream `with_input_rewrite`
        and `with_output_rewrite`.

        Args:
            node: A `Flatten(Fetch)` node.
            input: True for an input rewrite, False for an output one.

        Returns:
            The node.
        """
        var fetch = self.plan.nodes[self.plan.nodes[node].node].fetch
        var rewrite = FetchRewrite(
            True,
            [FetchNodePathSegment(True, self.store.sym("upc"), NONE)],
            self.store.sym("constant"),
        )
        if input:
            self.plan.fetches[fetch].input_rewrites = [rewrite^]
            self.plan.fetches[fetch].has_input_rewrites = True
        else:
            self.plan.fetches[fetch].output_rewrites = [rewrite^]
            self.plan.fetches[fetch].has_output_rewrites = True
        return node

    def optimize(mut self, var nodes: List[Int]) raises -> String:
        """Optimize a parallel node of nodes and print the plan.

        Args:
            nodes: The children.

        Returns:
            The plan text.
        """
        var root = self.plan.parallel(nodes^)
        self.plan.node = optimize_root_node(
            self.store, self.plan, root, self.state
        )
        return self.plan.text(self.store)


def test_next_unique_representations_variable_name_skips_used_values() raises:
    var store = Store()
    var used: List[Int] = [
        store.sym("__batch_reps_0"),
        store.sym("__batch_reps_2"),
    ]
    var next_index = 0
    var first = next_unique_representations_var_name(store, used, next_index)
    var second = next_unique_representations_var_name(store, used, next_index)
    assert_equal(store.name(first), "__batch_reps_1")
    assert_equal(store.name(second), "__batch_reps_3")


def test_optimize_parallel_node_batches_compatible_fetches_and_keeps_order() raises:
    var f = _Fixture()
    var passthrough = f.non_entity(100, "products")
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(2, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    assert_equal(
        f.optimize([passthrough, a, b]),
        snapshots.optimize_parallel_node_batches_compatible_fetches_and_keeps_order(),
    )


def test_optimize_parallel_node_does_not_batch_incompatible_variables() raises:
    var f = _Fixture()
    var a = f.entity(
        1,
        "inventory",
        "products",
        _REQUIRES_UPC,
        _SHIPPING,
        [_variable(f.store, "locale", "String")],
    )
    var b = f.entity(
        2,
        "inventory",
        "products",
        _REQUIRES_UPC,
        _SHIPPING,
        [_variable(f.store, "locale", "String!")],
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_does_not_batch_incompatible_variables(),
    )


def test_optimize_parallel_node_avoids_representations_variable_collision() raises:
    var f = _Fixture()
    var a = f.entity(
        1,
        "inventory",
        "products",
        _REQUIRES_UPC,
        _SHIPPING,
        [_variable(f.store, "__batch_reps_0", "String")],
    )
    var b = f.entity(
        2,
        "inventory",
        "products",
        _REQUIRES_UPC,
        _SHIPPING,
        [_variable(f.store, "__batch_reps_0", "String")],
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_avoids_representations_variable_collision(),
    )


def test_optimize_parallel_node_does_not_batch_across_subgraphs() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(2, "products", "products", _REQUIRES_UPC, _SHIPPING)
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_does_not_batch_across_subgraphs(),
    )


def test_optimize_parallel_node_batches_same_shape_with_different_merge_paths() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(2, "inventory", "topProducts", _REQUIRES_UPC, _SHIPPING)
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_batches_same_shape_with_different_merge_paths(),
    )


def test_optimize_parallel_node_splits_aliases_when_entities_query_differs() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(2, "inventory", "topProducts", _REQUIRES_UPC, _IN_STOCK)
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_splits_aliases_when_entities_query_differs(),
    )


def test_optimize_parallel_node_shares_representations_variable_when_input_and_paths_match() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(2, "inventory", "products", _REQUIRES_UPC, _IN_STOCK)
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_shares_representations_variable_when_input_and_paths_match(),
    )


def test_optimize_parallel_node_does_not_share_representations_variable_when_requires_differs() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(
        2, "inventory", "products", "{ ... on Product { name } }", _SHIPPING
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_does_not_share_representations_variable_when_requires_differs(),
    )


def test_optimize_parallel_node_does_not_share_representations_variable_when_input_rewrites_differ() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.with_rewrite(
        f.entity(2, "inventory", "products", _REQUIRES_UPC, _SHIPPING), True
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_does_not_share_representations_variable_when_input_rewrites_differ(),
    )


def test_optimize_parallel_node_splits_aliases_when_requires_differs() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(
        2, "inventory", "topProducts", "{ ... on Product { name } }", _SHIPPING
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_splits_aliases_when_requires_differs(),
    )


def test_optimize_parallel_node_splits_aliases_when_input_rewrites_differ() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.with_rewrite(
        f.entity(2, "inventory", "topProducts", _REQUIRES_UPC, _SHIPPING), True
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_splits_aliases_when_input_rewrites_differ(),
    )
    ref batch = f.plan.batches[f.plan.nodes[f.plan.node].fetch]
    assert_true(not batch.aliases[0].has_input_rewrites)
    assert_true(batch.aliases[1].has_input_rewrites)


def test_optimize_parallel_node_splits_aliases_when_output_rewrites_differ() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.with_rewrite(
        f.entity(2, "inventory", "topProducts", _REQUIRES_UPC, _SHIPPING),
        False,
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_splits_aliases_when_output_rewrites_differ(),
    )


def test_optimize_parallel_node_shares_representations_variable_when_only_output_rewrites_differ() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.with_rewrite(
        f.entity(2, "inventory", "products", _REQUIRES_UPC, _SHIPPING), False
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_shares_representations_variable_when_only_output_rewrites_differ(),
    )


def test_optimize_parallel_node_alias_order_is_deterministic() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(2, "inventory", "topProducts", _REQUIRES_UPC, _IN_STOCK)
    var c = f.entity(3, "inventory", "products2", _REQUIRES_UPC, _SHIPPING)
    assert_equal(
        f.optimize([a, b, c]),
        snapshots.optimize_parallel_node_alias_order_is_deterministic(),
    )


def _fragment(
    mut store: Store, name: StringSlice, type_name: StringSlice, body: String
) raises -> FragmentDefinition:
    """Return a fragment definition read from `{ ... }` text."""
    return FragmentDefinition(
        store.sym(name),
        selection_set_from_text(store, body),
        store.sym(type_name),
    )


def test_optimize_parallel_node_batches_entities_query_with_fragment_spread() raises:
    var f = _Fixture()
    var a = f.entity(
        1,
        "inventory",
        "products",
        _REQUIRES_UPC,
        "{ _entities(representations: $representations)"
        + " { ... on Product { ...A } } }",
        [],
        [_fragment(f.store, "A", "Product", "{ shippingEstimate }")],
    )
    var b = f.entity(
        2,
        "inventory",
        "topProducts",
        _REQUIRES_UPC,
        "{ _entities(representations: $representations)"
        + " { ... on Product { ...B } } }",
        [],
        [_fragment(f.store, "B", "Product", "{ shippingEstimate }")],
    )
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_batches_entities_query_with_fragment_spread(),
    )


def test_optimize_parallel_node_returns_original_when_no_entity_candidates() raises:
    var f = _Fixture()
    var a = f.non_entity(1, "products")
    var b = f.non_entity(2, "inventory")
    assert_equal(
        f.optimize([a, b]),
        snapshots.optimize_parallel_node_returns_original_when_no_entity_candidates(),
    )


def test_optimize_parallel_node_does_not_batch_single_candidate() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    assert_equal(
        f.optimize([a]),
        snapshots.optimize_parallel_node_does_not_batch_single_candidate(),
    )


def test_optimize_parallel_node_creates_multiple_batch_nodes_for_multiple_services() raises:
    var f = _Fixture()
    var a = f.entity(1, "inventory", "products", _REQUIRES_UPC, _SHIPPING)
    var b = f.entity(2, "inventory", "topProducts", _REQUIRES_UPC, _SHIPPING)
    var c = f.entity(3, "products", "products", _REQUIRES_UPC, _SHIPPING)
    var d = f.entity(4, "products", "topProducts", _REQUIRES_UPC, _SHIPPING)
    assert_equal(
        f.optimize([a, b, c, d]),
        snapshots.optimize_parallel_node_creates_multiple_batch_nodes_for_multiple_services(),
    )


# --- edge cases ------------------------------------------------------------


def _document(mut store: Store, query: String) raises -> FetchDocument:
    """Return a query document with no fragments."""
    var set = selection_set_from_text(store, query)
    return FetchDocument(
        OperationDefinition(OperationKind.QUERY, set),
        List[FragmentDefinition](),
    )


def test_fetch_operation_edge_cases() raises:
    var store = Store()
    # An empty operation prints its own set.
    var empty = FetchDocument(
        OperationDefinition(OperationKind.QUERY, store.new_set()),
        List[FragmentDefinition](),
    )
    assert_equal(
        inner_selection_set(store, empty), empty.operation.selection_set
    )
    # A named operation has no place to write a name.
    var named = OperationDefinition(
        OperationKind.QUERY, selection_set_from_text(store, "{ a }")
    )
    named.name = store.sym("Named")
    var fetch = PlanningFetchOperation(
        FetchDocument(named^, List[FragmentDefinition]()), store
    )
    assert_true(fetch.document_str.startswith("query Named"))
    assert_equal(fetch.name_write_position, 0)
    # Two variables are joined by a comma.
    var operation = OperationDefinition(
        OperationKind.QUERY, selection_set_from_text(store, "{ a }")
    )
    operation.variables = [
        _variable(store, "x", "Int"),
        _variable(store, "y", "Int"),
    ]
    operation.has_variables = True
    var two = PlanningFetchOperation(
        FetchDocument(operation^, List[FragmentDefinition]()), store
    )
    var out = String()
    two.pretty(store, out, 0)
    assert_true(out.startswith("  query ($x:Int,$y:Int) {\n"))
    # An empty set expands to an empty set, and a spread at the top level
    # becomes an inline fragment.
    assert_true(
        store.is_empty(inline_fragment_spreads(store, store.new_set(), []))
    )
    var outer = FragmentDefinition(
        store.sym("F"),
        selection_set_from_text(store, "{ ...G }"),
        store.sym("T"),
    )
    var inner = FragmentDefinition(
        store.sym("G"), selection_set_from_text(store, "{ b }"), store.sym("T")
    )
    var expanded = inline_fragment_spreads(
        store, selection_set_from_text(store, "{ ...G ...F }"), [outer^, inner^]
    )
    var first = store.items[expanded].first
    assert_true(store.items[first].kind == ItemKind.FRAGMENT)
    assert_equal(store.name(store.items[first].name), "T")
    var second = store.items[store.items[first].next].first
    assert_true(store.items[second].kind == ItemKind.FRAGMENT)


comptime _ENUM_SCHEMA = """
enum Color {
  RED
}

type Query {
  color: Color
}
"""


def _minify_error(
    mut store: Store,
    kind: OperationKind,
    query: String,
    state: SupergraphState,
) -> String:
    """Return the error of minifying an operation, or an empty text."""
    try:
        var set = selection_set_from_text(store, query)
        _ = minify_operation(store, OperationDefinition(kind, set), state)
    except error:
        return String(error)
    return String()


def test_minification_edge_cases() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(_MINIFICATION_SCHEMA))
    assert_equal(
        _minify_error(store, OperationKind.SUBSCRIPTION, "{ a }", state),
        "Type not found for operation kind: subscription",
    )
    var enums = new_supergraph_state(store, parse(_ENUM_SCHEMA))
    assert_equal(
        _minify_error(store, OperationKind.QUERY, "{ color { x } }", enums),
        "Field 'x' not found in type 'Color'",
    )
    # An introspection field in `_entities` stays, and the repeated set
    # becomes a fragment.
    var set = selection_set_from_text(
        store,
        (
            "{ _entities { __typename ... on Book { a: id } }"
            " product(id: 1) { ... on Book { a: id } } }"
        ),
    )
    var document = minify_operation(
        store, OperationDefinition(OperationKind.QUERY, set), state
    )
    assert_equal(
        document.text(store),
        (
            "{_entities{__typename ...on Book{...a}}"
            " product(id: 1){...on Book{...a}}}\n\nfragment a on Book {a: id}\n"
        ),
    )
    # The 27th fragment is `A`, and it sorts before `a`.
    var query = String("{")
    for index in range(27):
        for copy in range(2):
            query += (
                " p"
                + String(index)
                + "_"
                + String(copy)
                + ": product(id: 1) { k"
                + String(index)
                + ": id }"
            )
    query += " }"
    var many = minify_operation(
        store,
        OperationDefinition(
            OperationKind.QUERY, selection_set_from_text(store, query)
        ),
        state,
    )
    assert_equal(len(many.fragments), 27)
    assert_equal(store.name(many.fragments[0].name), "A")
    assert_equal(store.name(many.fragments[1].name), "a")


def test_plan_node_helpers() raises:
    var store = Store()
    assert_true(PathSegmentKind(2).is_valid())
    assert_false(PathSegmentKind(3).is_valid())
    assert_true(PlanNodeKind(7).is_valid())
    assert_false(PlanNodeKind(8).is_valid())
    var names = List[String]()
    for value in range(8):
        names.append(String(PlanNodeKind(UInt8(value)).name()))
    assert_equal(
        names,
        [
            "Fetch",
            "BatchFetch",
            "Sequence",
            "Parallel",
            "Flatten",
            "Condition",
            "Subscription",
            "Defer",
        ],
    )
    var plan = QueryPlan()
    var a = plan.add_fetch(
        FetchNode(
            1,
            NONE,
            OperationKind.QUERY,
            PlanningFetchOperation(_document(store, "{ a }"), store),
            NONE,
        )
    )
    var b = plan.add_fetch(
        FetchNode(
            2,
            store.sym("b"),
            OperationKind.QUERY,
            PlanningFetchOperation(_document(store, "{ b }"), store),
            NONE,
        )
    )
    # A list of one node is that node.
    assert_equal(plan.sequence([a]), a)
    assert_equal(plan.parallel([a]), a)
    var sequence = plan.sequence([a, b])
    var parallel = plan.parallel([a, b])
    assert_equal(plan.into_nodes(sequence), [a, b])
    assert_equal(plan.into_nodes(parallel), [a, b])
    assert_equal(plan.flatten_sequence(sequence), [a, b])
    assert_equal(plan.flatten_sequence(a), [a])
    assert_equal(plan.flatten_parallel([parallel, a]), [a, b, a])
    # A service of `NONE` prints as `*`.
    assert_true('Fetch(service: "*")' in plan.node_text(store, a))
    var batch = plan.add_batch_fetch(
        BatchFetchNode(
            3,
            store.sym("b"),
            List[Int](),
            False,
            OperationKind.QUERY,
            PlanningFetchOperation(_document(store, "{ b }"), store),
            List[EntityBatchAlias](),
        )
    )
    assert_true(plan.is_fetching_node(batch))
    # A condition with no clause adds nothing to a merge.
    var variable = store.sym("v")
    var with_if = plan.add_condition(variable, a, NONE)
    var without = plan.add_condition(variable, NONE, NONE)
    plan.merge_condition(with_if, without)
    assert_equal(plan.nodes[with_if].if_clause, a)
    # A `Defer` node prints nothing.
    plan.node = plan.add(PlanNode.of(PlanNodeKind.DEFER))
    assert_equal(plan.text(store), "QueryPlan {\n},\n")
    # An empty path.
    var path = FlattenNodePath.from_merge_path(MergePath())
    assert_true(path.is_empty())
    assert_true(path == FlattenNodePath())
    assert_equal(path.text(store), "")


def test_fetch_node_reports_a_failed_minification() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(simple_requires.sdl()))
    var step = _entity_call(
        store,
        1,
        "inventory",
        "products.@",
        "Product",
        "{ upc }",
        "{ missing }",
        Cond.none(),
    )
    var message = String()
    try:
        _ = fetch_node_from_fetch_step(store, step, state)
    except error:
        message = String(error)
    assert_equal(
        message,
        "Failed to minify: Field 'missing' not found in type 'Product'",
    )


def test_in_degree_errors() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(simple_include_skip.sdl()))
    var message = String()
    try:
        _ = InDegree(FetchGraph(OperationKind.QUERY))
    except error:
        message = String(error)
    assert_equal(message, "Root fetch is missing")
    var graph = FetchGraph(OperationKind.QUERY)
    graph.root_index = graph.add_step(_root_step(store))
    var x = graph.add_step(_root_call(store, 1, "a", "{ product { price } }"))
    var w = graph.add_step(_root_call(store, 2, "a", "{ product { price } }"))
    var y = graph.add_step(_root_call(store, 3, "a", "{ product { price } }"))
    var z = graph.add_step(_root_call(store, 4, "a", "{ product { price } }"))
    _ = graph.connect(graph.root_index, x)
    _ = graph.connect(x, w)
    _ = graph.connect(y, z)
    var degrees = InDegree(graph)
    message = String()
    try:
        degrees.mark_as_processed(graph, y)
    except error:
        message = String(error)
    assert_equal(
        message, "Attempt to decrease an in-degree of a non-existing step"
    )
    degrees.mark_as_processed(graph, x)
    message = String()
    try:
        degrees.mark_as_processed(graph, x)
    except error:
        message = String(error)
    assert_equal(message, "In-degree was 0")
    message = String()
    try:
        _ = degrees.is_fulfilled(y)
    except error:
        message = String(error)
    assert_equal(message, "In-degree record missing")
    # A step whose child is the root.
    var back = FetchGraph(OperationKind.QUERY)
    back.root_index = back.add_step(_root_step(store))
    var only = back.add_step(_root_call(store, 1, "a", "{ product { price } }"))
    _ = back.connect(back.root_index, only)
    _ = back.connect(only, back.root_index)
    assert_equal(
        _plan_error(store, back, state),
        (
            "Internal Error: Visited child step is a root step. It should not"
            " happen"
        ),
    )


def test_optimizer_helpers() raises:
    var f = _Fixture()
    var rewrite = FetchRewrite(
        True,
        [FetchNodePathSegment(True, f.store.sym("upc"), NONE)],
        f.store.sym("one"),
    )
    var other = FetchRewrite(
        True,
        [FetchNodePathSegment(True, f.store.sym("upc"), NONE)],
        f.store.sym("two"),
    )
    var none = List[FetchRewrite]()
    assert_false(rewrites_equal(True, none, False, none))
    assert_false(rewrites_equal(True, [rewrite.copy()], True, none))
    assert_true(rewrites_equal(True, [rewrite.copy()], True, [rewrite.copy()]))
    assert_false(rewrites_equal(True, [rewrite.copy()], True, [other^]))
    # `representations` must be a variable argument.
    var fresh = Store()
    var bare = fresh.add_item(ItemKind.FIELD, fresh.sym("_entities"))
    assert_equal(representations_variable_name(fresh, bare), NONE)
    _ = fresh.sym("representations")
    assert_equal(representations_variable_name(fresh, bare), NONE)
    var literal = selection_set_from_text(
        f.store, "{ _entities(representations: 1) { __typename } }"
    )
    assert_equal(
        representations_variable_name(f.store, f.store.items[literal].first),
        NONE,
    )
    # Variables.
    var a_int = _variable(f.store, "a", "Int")
    var a_text = _variable(f.store, "a", "String")
    var b_int = _variable(f.store, "b", "Int")
    var empty = List[VariableDefinition]()
    assert_true(can_merge_variable_definitions(f.store, empty, [a_int.copy()]))
    assert_true(
        can_merge_variable_definitions(f.store, [a_int.copy()], [b_int.copy()])
    )
    assert_false(
        can_merge_variable_definitions(f.store, [a_int.copy()], [a_text.copy()])
    )
    var merged = List[VariableDefinition]()
    merge_variable_definitions(merged, [a_int.copy()])
    merge_variable_definitions(merged, [a_int.copy(), b_int.copy()])
    assert_equal(len(merged), 2)
    assert_equal(
        len(partition_by_variables_compatibility(f.store, List[EntityFetch]())),
        0,
    )
    assert_equal(len(partition_by_shape(f.store, List[EntityFetch]())), 0)


def _optimizer_error(mut f: _Fixture, node: Int) -> String:
    """Return the error of reading an entity fetch, or an empty text."""
    try:
        _ = entity_fetch_from_node(f.store, f.plan, 0, node)
    except error:
        return String(error)
    return String()


def test_entity_fetch_from_node_skips_other_nodes() raises:
    var f = _Fixture()
    var root = f.non_entity(1, "products")
    var sequence = f.plan.add_list(PlanNodeKind.SEQUENCE, [root, root])
    var path = FlattenNodePath.from_merge_path(_path(f.store, "products.@"))
    var over_sequence = f.plan.add_flatten(path.copy(), sequence)
    assert_false(entity_fetch_from_node(f.store, f.plan, 0, over_sequence))
    var over_root = f.plan.add_flatten(path.copy(), root)
    assert_false(entity_fetch_from_node(f.store, f.plan, 0, over_root))
    var literal = f.entity(
        2,
        "inventory",
        "products",
        _REQUIRES_UPC,
        "{ _entities(representations: 1) { ... on Product { inStock } } }",
    )
    assert_false(entity_fetch_from_node(f.store, f.plan, 0, literal))
    var no_requires = f.entity(
        3, "inventory", "products", _REQUIRES_UPC, _IN_STOCK
    )
    var fetch = f.plan.nodes[f.plan.nodes[no_requires].node].fetch
    f.plan.fetches[fetch].planner_requires = NONE
    assert_false(entity_fetch_from_node(f.store, f.plan, 0, no_requires))
    var spread = f.entity(
        4, "inventory", "products", "{ ...Missing }", _IN_STOCK
    )
    assert_equal(
        _optimizer_error(f, spread),
        (
            "Fragment expansion error: Could not find fragment definition"
            " 'Missing'"
        ),
    )


def _candidate(
    mut f: _Fixture, index: Int, requires: String, entities: String
) raises -> EntityFetch:
    """Return an entity fetch candidate at `products.@`."""
    var out = EntityFetch(index, index, f.store.sym("inventory"))
    out.requires = selection_set_from_text(f.store, requires)
    out.entities_selection = selection_set_from_text(f.store, entities)
    out.flatten_path = FlattenNodePath.from_merge_path(
        _path(f.store, "products.@")
    )
    return out^


def _batch_error(mut f: _Fixture, groups: List[List[EntityFetch]]) -> String:
    """Return the error of building a batch, or an empty text."""
    try:
        _ = build_batched_fetch_node(
            f.store, groups, List[VariableDefinition](), f.state
        )
    except error:
        return String(error)
    return String()


def test_batch_builder_edge_cases() raises:
    var f = _Fixture()
    var builder = BatchFetchBuilder(List[VariableDefinition]())
    var message = String()
    try:
        builder.add_shape_group(f.store, 0, List[EntityFetch]())
    except error:
        message = String(error)
    assert_equal(
        message, "Internal Error: Batched entities shape group cannot be empty"
    )
    var empty_group: List[List[EntityFetch]] = [List[EntityFetch]()]
    assert_equal(
        _batch_error(f, List[List[EntityFetch]]()),
        "Internal Error: Batched entities candidates were empty",
    )
    assert_equal(
        _batch_error(f, empty_group),
        "Internal Error: Batched entities candidates were empty",
    )
    # Usages are sorted and kept once.
    var entities = "{ ... on Product { inStock } }"
    var first = _candidate(f, 0, "{ upc }", entities)
    first.variable_usages = [f.store.sym("b"), f.store.sym("c")]
    var second = _candidate(f, 1, "{ upc }", entities)
    second.variable_usages = [f.store.sym("c"), f.store.sym("a")]
    builder.add_shape_group(f.store, 0, [first.copy(), second.copy()])
    var usages = List[String]()
    for name in builder.variable_usages:
        usages.append(String(f.store.name(name)))
    assert_equal(usages, ["a", "b", "c"])
    # Requires that differ only in arguments or aliases get their own
    # variable; the same requires share one.
    var requires: List[String] = [
        "{ upc(a: 1) }",
        "{ u: upc }",
        "{ ... on Product { upc } }",
        "{ ... on Product { upc(a: 1) } }",
        "{ upc }",
    ]
    for index in range(len(requires)):
        builder.add_shape_group(
            f.store,
            index + 1,
            [_candidate(f, index + 2, requires[index], entities)],
        )
    var variables = List[String]()
    for ref alias in builder.batched_aliases:
        variables.append(
            String(f.store.name(alias.representations_variable_name))
        )
    assert_equal(
        variables,
        [
            "__batch_reps_0",
            "__batch_reps_1",
            "__batch_reps_2",
            "__batch_reps_3",
            "__batch_reps_4",
            "__batch_reps_0",
        ],
    )
    # A field in `_entities` fails the minification.
    var bad = BatchFetchBuilder(List[VariableDefinition]())
    bad.add_shape_group(f.store, 0, [_candidate(f, 0, "{ upc }", "{ upc }")])
    message = String()
    try:
        _ = bad.finish(f.store, first, f.state)
    except error:
        message = String(error)
    assert_equal(
        message,
        (
            "Internal Error: Failed to minify batched entities operation:"
            " Unsupported field in `_entities`: Query.upc"
        ),
    )


def test_optimize_plan_sequence_and_batch_nodes() raises:
    var f = _Fixture()
    var a = f.non_entity(1, "a")
    var b = f.non_entity(2, "b")
    var c = f.non_entity(3, "c")
    var d = f.non_entity(4, "d")
    var nested = f.plan.add_list(PlanNodeKind.SEQUENCE, [a, b])
    var first = f.plan.add_condition(f.store.sym("x"), c, NONE)
    var second = f.plan.add_condition(f.store.sym("y"), d, NONE)
    assert_equal(
        optimize_plan_sequence(f.plan, [nested, first, second]),
        [a, b, first, second],
    )
    var batch = f.plan.add_batch_fetch(
        BatchFetchNode(
            5,
            f.store.sym("b"),
            List[Int](),
            False,
            OperationKind.QUERY,
            PlanningFetchOperation(_document(f.store, "{ b }"), f.store),
            List[EntityBatchAlias](),
        )
    )
    assert_equal(optimize_root_node(f.store, f.plan, batch, f.state), batch)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
