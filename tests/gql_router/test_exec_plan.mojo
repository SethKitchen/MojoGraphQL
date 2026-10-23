# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan execution tests, with subgraphs in the same process.

The cases follow the plan execution and error handling of Hive Router
`1a29df9` `bin/router/src/executor/execution/plan.rs`: a root fetch, an
`_entities` fetch under a flatten node, entity errors moved to the entity
paths, and each kind of failed subgraph request. The supergraph is the
`simple-requires` fixture: `products` resolves the products, and
`inventory` resolves `shippingEstimate` from `price` and `weight`.

The tests after those are the ports of the `#[cfg(test)]` tests of the
same upstream file: `select_fetch_variables`, `normalize_entity_errors_correctly`,
`prepare_batch_fetch_job_state_deduplicates_shared_variable_payloads`
and `runs_parallel_jobs_in_parallel`, and tests of `condition_target`.

**Differences from upstream.** Upstream `select_fetch_variables` returns
`Option<HashMap>`. This port returns False for `None`, and fills two
parallel lists. Upstream `runs_parallel_jobs_in_parallel` checks that the
data of `subgraph_a` is merged while `subgraph_b` still sleeps. This port
sends the children of a `Parallel` node one at a time, in plan order. So
the port plans `{ from_a from_b }`, and checks that the requests go in
plan order and that both results merge.
"""

from _exec_harness import run_router
from _fixtures import simple_requires
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE, JsonDocument
from gql_language.parser import parse
from gql_router.ast import NONE, Cond
from gql_router.entity_keys import EntityKeys
from gql_router.exec_http import CannedTransport
from gql_router.exec_plan import (
    ExecutionContext,
    _prepare_batch,
    condition_target,
    select_fetch_variables,
)
from gql_router.exec_variables import CoerceVariablesPayload
from gql_router.federation_spec import OperationKind
from gql_router.fetch_operation import (
    FetchDocument,
    FragmentDefinition,
    PlanningFetchOperation,
)
from gql_router.graphql_error import (
    ErrorPath,
    ErrorSegment,
    ErrorSegmentKind,
    GraphQLError,
    field_segment,
    graphql_error,
    index_segment,
)
from gql_router.merge_path import MergePath, Segment
from gql_router.normalize import selection_set_from_text
from gql_router.operation import OperationDefinition, VariableDefinition
from gql_router.pipeline import Router, RouterSchema
from gql_router.plan_nodes import (
    FetchNode,
    FlattenNodePath,
    PlanNodeKind,
    QueryPlan,
    representations_type,
)
from gql_router.query_plan_optimize import optimize_root_node
from gql_router.schema_metadata import SchemaMetadata
from gql_router.store import Store
from gql_router.supergraph_state import new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime QUERY = "{ products { upc name shippingEstimate } }"
"""The client operation."""
comptime PRODUCTS = "{products{__typename upc name price weight}}"
"""The query that the router sends to `products`."""
comptime INVENTORY = (
    "query($representations:[_Any!]!){_entities(representations:"
    " $representations){...on Product{shippingEstimate}}}"
)
"""The query that the router sends to `inventory`."""
comptime PRODUCTS_DATA = (
    '{"data":{"products":[{"__typename":"Product","upc":"1","name":"Table",'
    + '"price":899,"weight":100},{"__typename":"Product","upc":"2",'
    + '"name":"Couch","price":1299,"weight":1000},null]}}'
)
"""The response of `products`."""


def _transport(inventory: String, status: Int = 200) -> CannedTransport:
    var transport = CannedTransport(True)
    transport.add("products", PRODUCTS, PRODUCTS_DATA)
    transport.add("inventory", INVENTORY, inventory, status)
    return transport^


def test_fetch_then_flatten_merges_entities() raises:
    assert_equal(
        run_router(
            simple_requires.sdl(),
            _transport(
                '{"data":{"_entities":[{"shippingEstimate":50},'
                + '{"shippingEstimate":20}]}}'
            ),
            QUERY,
        ),
        '200 {"data":{"products":[{"upc":"1","name":"Table","shippingEstimate":50},'
        + '{"upc":"2","name":"Couch","shippingEstimate":20},null]}}',
    )


def test_entity_errors_move_to_the_entity_path() raises:
    assert_equal(
        run_router(
            simple_requires.sdl(),
            _transport(
                '{"data":{"_entities":[{"shippingEstimate":50},null]},'
                + '"errors":[{"message":"boom","path":["_entities",1,'
                + '"shippingEstimate"],"extensions":{"code":"X","retry":true}}]}'
            ),
            QUERY,
        ),
        '200 {"data":{"products":[{"upc":"1","name":"Table","shippingEstimate":50},'
        + '{"upc":"2","name":"Couch","shippingEstimate":null},null]},'
        + '"errors":[{"message":"boom","path":["products",1,"shippingEstimate"],'
        + '"extensions":{"code":"X","service":"inventory",'
        + '"affectedPath":"products.@","retry":true}}]}',
    )


def test_a_failed_subgraph_does_not_fail_the_operation() raises:
    var transport = CannedTransport()
    transport.add("products", PRODUCTS, PRODUCTS_DATA)
    assert_equal(
        run_router(simple_requires.sdl(), transport^, QUERY),
        '200 {"data":{"products":[{"upc":"1","name":"Table","shippingEstimate":null},'
        + '{"upc":"2","name":"Couch","shippingEstimate":null},null]},'
        + '"errors":[{"message":"Failed to send request to subgraph: no canned'
        + ' response for subgraph inventory","extensions":{"code":'
        + '"SUBREQUEST_HTTP_ERROR","service":"inventory","affectedPath":'
        + '"products.@"}}]}',
    )


def test_an_error_status_adds_an_error() raises:
    assert_equal(
        run_router(
            simple_requires.sdl(),
            _transport(
                '{"data":{"_entities":[{"shippingEstimate":1},'
                + '{"shippingEstimate":2}]}}',
                500,
            ),
            QUERY,
        ),
        '200 {"data":{"products":[{"upc":"1","name":"Table","shippingEstimate":1},'
        + '{"upc":"2","name":"Couch","shippingEstimate":2},null]},'
        + '"errors":[{"message":"Subgraph \'inventory\' responded with an'
        " invalid"
        + " HTTP status code '500 Internal Server"
        ' Error\'","extensions":{"code":'
        + '"SUBREQUEST_HTTP_ERROR","service":"inventory","affectedPath":'
        + '"products.@","http":{"status":500}}}]}',
    )


def _failure(
    inventory: String, content_type: String = "application/json"
) raises -> String:
    var transport = CannedTransport()
    transport.add("products", PRODUCTS, PRODUCTS_DATA)
    transport.add("inventory", INVENTORY, inventory, 200, content_type)
    var out = run_router(simple_requires.sdl(), transport^, QUERY)
    var start = out.find('"errors":')
    return String(out[byte=start:])


def test_bad_responses_are_errors() raises:
    assert_equal(
        _failure(""),
        '"errors":[{"message":"Received empty response body from subgraph'
        + ' \\"inventory\\"","extensions":{"code":"SUBGRAPH_RESPONSE_BODY_EMPTY",'
        + '"service":"inventory","affectedPath":"products.@"}}]}',
    )
    assert_equal(
        _failure("{}", "text/html"),
        '"errors":[{"message":"Invalid content type returned from subgraph'
        + ' \'inventory\': \'text/html\'","extensions":{"code":'
        + '"SUBREQUEST_MALFORMED_RESPONSE","service":"inventory",'
        + '"affectedPath":"products.@"}}]}',
    )
    assert_equal(
        _failure("{}", ""),
        '"errors":[{"message":"Invalid content type returned from subgraph'
        + ' \'inventory\': \'\'","extensions":{"code":'
        + '"SUBREQUEST_MALFORMED_RESPONSE","service":"inventory",'
        + '"affectedPath":"products.@"}}]}',
    )
    assert_equal(
        _failure('{"data":null}'),
        '"errors":[{"message":"Subgraph returned malformed response",'
        + '"extensions":{"code":"SUBREQUEST_MALFORMED_RESPONSE","service":'
        + '"inventory","affectedPath":"products.@"}}]}',
    )


# --- the #[cfg(test)] tests of plan.rs ------------------------------------


def _variables(text: String) raises -> CoerceVariablesPayload:
    """Read a JSON object as a variable map."""
    var payload = CoerceVariablesPayload()
    payload.document = parse_json(text)
    var child = payload.document.first(payload.document.root)
    while child != NO_NODE:
        payload.insert(payload.document.key(child), child)
        child = payload.document.next(child)
    return payload^


def _syms(mut store: Store, names: List[String]) -> List[Int]:
    """Return the symbols of names."""
    var out = List[Int]()
    for name in names:
        out.append(store.sym(name))
    return out^


def test_select_fetch_variables_only_used_variables() raises:
    var store = Store()
    var variables = _variables('{"used":1,"unused":2}')
    var names = List[String]()
    var nodes = List[Int]()
    assert_true(
        select_fetch_variables(
            store, _syms(store, ["used"]), True, variables, names, nodes
        )
    )
    assert_equal(len(names), 1)
    assert_equal(names[0], "used")
    assert_equal(len(nodes), 1)
    assert_equal(String(variables.document.text(nodes[0])), "1")


def test_select_fetch_variables_ignores_missing_usage_entries() raises:
    var store = Store()
    var variables = _variables('{"present":3}')
    var names = List[String]()
    var nodes = List[Int]()
    assert_true(
        select_fetch_variables(
            store,
            _syms(store, ["missing", "present"]),
            True,
            variables,
            names,
            nodes,
        )
    )
    assert_equal(len(names), 1)
    assert_equal(names[0], "present")
    assert_equal(String(variables.document.text(nodes[0])), "3")


def test_select_fetch_variables_for_no_usage_entries() raises:
    var store = Store()
    var variables = _variables('{"unused_1":1,"unused_2":2}')
    var names = List[String]()
    var nodes = List[Int]()
    assert_false(
        select_fetch_variables(
            store, List[Int](), False, variables, names, nodes
        )
    )
    assert_equal(len(names), 0)
    # No variable map is upstream `None` too.
    assert_false(
        select_fetch_variables(
            store,
            _syms(store, ["used"]),
            True,
            CoerceVariablesPayload(),
            names,
            nodes,
        )
    )
    assert_equal(len(nodes), 0)


def _error_path(field: String, index: Int) -> ErrorPath:
    """Make the error path `field.index`."""
    var segments = List[ErrorSegment]()
    segments.append(field_segment(field))
    segments.append(index_segment(index))
    return ErrorPath(segments^)


def _path_text(path: ErrorPath) -> String:
    """Write an error path as `a.0.b`."""
    var out = String()
    for index in range(len(path.segments)):
        if index > 0:
            out += "."
        ref segment = path.segments[index]
        if segment.kind == ErrorSegmentKind.INDEX:
            out += String(segment.index)
        else:
            out += segment.field
    return out^


def test_normalize_entity_errors_correctly() raises:
    # The same entity is at ["a", 0] and at ["b", 1], so its error is
    # copied to both paths.
    var arena = JsonDocument()
    var data = arena.add_object()
    var ctx = ExecutionContext(arena^, data, List[GraphQLError]())
    var error = graphql_error("Error 1")
    error.has_path = True
    error.path = _error_path("_entities", 0)
    error.path.segments.append(field_segment("field1"))
    var errors = List[GraphQLError]()
    errors.append(error^)
    var paths = List[ErrorPath]()
    paths.append(_error_path("a", 0))
    paths.append(_error_path("b", 1))

    ctx.handle_errors("subgraph_a", "", False, errors^, True, [0, 0], paths)

    assert_equal(len(ctx.errors), 2)
    assert_equal(ctx.errors[0].message, "Error 1")
    assert_equal(_path_text(ctx.errors[0].path), "a.0.field1")
    assert_equal(ctx.errors[1].message, "Error 1")
    assert_equal(_path_text(ctx.errors[1].path), "b.1.field1")
    assert_equal(ctx.errors[0].service, "subgraph_a")
    assert_equal(ctx.errors[0].affected_path, "")


def _entity_fetch(
    mut store: Store,
    mut plan: QueryPlan,
    id: Int,
    entities_query: String,
) raises -> Int:
    """Add a `Flatten(Fetch)` to `inventory` at `products.@`, with the
    requires `... on Product { upc }`."""
    var requires = selection_set_from_text(store, "{ ... on Product { upc } }")
    var set = selection_set_from_text(store, entities_query)
    var operation = OperationDefinition(OperationKind.QUERY, set)
    var representations = store.sym("representations")
    operation.variables = [
        VariableDefinition(representations, representations_type(store), NONE)
    ]
    operation.has_variables = True
    var document = FetchDocument(operation^, List[FragmentDefinition]())
    var fetch = FetchNode(
        id,
        store.sym("inventory"),
        OperationKind.QUERY,
        PlanningFetchOperation(document^, store),
        requires,
    )
    var child = plan.add_fetch(fetch^)
    var path = MergePath(
        [
            Segment.field(store.sym("products"), NONE, NONE, Cond.none()),
            Segment.list(),
        ]
    )
    return plan.add_flatten(FlattenNodePath.from_merge_path(path), child)


def _count(text: String, part: StringSlice) -> Int:
    """Count the places of a text in another."""
    var count = 0
    var at = text.find(part)
    while at >= 0:
        count += 1
        at = text.find(part, at + part.byte_length())
    return count


def test_prepare_batch_fetch_job_state_deduplicates_shared_variable_payloads() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(simple_requires.sdl()))
    var plan = QueryPlan()
    var a = _entity_fetch(
        store,
        plan,
        1,
        "{ _entities(representations: $representations)"
        + " { ... on Product { shippingEstimate } } }",
    )
    var b = _entity_fetch(
        store,
        plan,
        2,
        "{ _entities(representations: $representations)"
        + " { ... on Product { inStock } } }",
    )
    var root = plan.parallel([a, b])
    plan.node = optimize_root_node(store, plan, root, state)
    assert_true(plan.nodes[plan.node].kind == PlanNodeKind.BATCH_FETCH)
    var keys = EntityKeys.new(store, state)

    var arena = parse_json(
        '{"products":[{"__typename":"Product","upc":"1"},'
        + '{"__typename":"Product","upc":"2"}]}'
    )
    var ctx = ExecutionContext(arena^, 0, List[GraphQLError]())
    var job = _prepare_batch(
        ctx,
        store,
        plan,
        SchemaMetadata(),
        keys,
        CoerceVariablesPayload(),
        plan.node,
    )

    assert_equal(len(job.aliases), 2)
    assert_equal(job.aliases[0].count, 2)
    assert_equal(job.aliases[1].count, 2)
    var body = String(unsafe_from_utf8=job.body)
    # One variable payload, shared by both aliases.
    assert_equal(_count(body, '"__batch_reps_0":'), 1)
    assert_equal(_count(body, "__batch_reps_1"), 0)
    assert_equal(
        _count(
            body,
            '[{"__typename":"Product","upc":"1"},'
            + '{"__typename":"Product","upc":"2"}]',
        ),
        1,
    )


comptime TWO_ROOTS_SDL = """
schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
  query: Query
}

directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE
directive @join__field(
  graph: join__Graph
  requires: join__FieldSet
  provides: join__FieldSet
  type: String
  external: Boolean
  override: String
  usedOverridden: Boolean
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION
directive @join__graph(name: String!, url: String!) on ENUM_VALUE
directive @join__implements(
  graph: join__Graph!
  interface: String!
) repeatable on OBJECT | INTERFACE
directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR
directive @join__unionMember(
  graph: join__Graph!
  member: String!
) repeatable on UNION
directive @link(
  url: String
  as: String
  for: link__Purpose
  import: [link__Import]
) repeatable on SCHEMA

scalar join__FieldSet
scalar link__Import

enum join__Graph {
  SUBGRAPH_A @join__graph(name: "subgraph_a", url: "http://a.example.com/graphql")
  SUBGRAPH_B @join__graph(name: "subgraph_b", url: "http://b.example.com/graphql")
}

enum link__Purpose {
  SECURITY
  EXECUTION
}

type Query @join__type(graph: SUBGRAPH_A) @join__type(graph: SUBGRAPH_B) {
  from_a: String @join__field(graph: SUBGRAPH_A)
  from_b: String @join__field(graph: SUBGRAPH_B)
}
"""
"""Two subgraphs, each with one root field."""


def test_runs_parallel_jobs_in_parallel() raises:
    var transport = CannedTransport(True)
    transport.add("subgraph_a", "{from_a}", '{"data":{"from_a":"value_a"}}')
    transport.add("subgraph_b", "{from_b}", '{"data":{"from_b":"value_b"}}')
    var router = Router(RouterSchema(TWO_ROOTS_SDL), transport^)
    var response = router.execute(
        "{ from_a from_b }", None, JsonDocument(), NO_NODE, False, True
    )
    assert_equal(response.status, 200)
    assert_equal(
        String(unsafe_from_utf8=response.body),
        '{"data":{"from_a":"value_a","from_b":"value_b"}}',
    )
    ref requests = router.executor.transport.requests
    assert_equal(len(requests), 2)
    # The plan is `Parallel { Fetch(subgraph_b), Fetch(subgraph_a) }`, and
    # this port sends the children in plan order.
    assert_equal(requests[0], '{"query":"{from_b}"}')
    assert_equal(requests[1], '{"query":"{from_a}"}')


def test_condition_target_picks_a_branch() raises:
    var store = Store()
    var plan = QueryPlan()
    var flag = store.sym("flag")
    var node = plan.add_condition(flag, 10, 20)
    assert_equal(
        condition_target(plan, store, node, CoerceVariablesPayload()), NONE
    )
    assert_equal(
        condition_target(plan, store, node, _variables('{"other":true}')), NONE
    )
    assert_equal(
        condition_target(plan, store, node, _variables('{"flag":true}')), 10
    )
    assert_equal(
        condition_target(plan, store, node, _variables('{"flag":false}')), 20
    )
    # Only the boolean `true` meets the condition, as upstream.
    assert_equal(
        condition_target(plan, store, node, _variables('{"flag":"true"}')), 20
    )
    assert_equal(
        condition_target(plan, store, node, _variables('{"flag":null}')), 20
    )
    var no_else = plan.add_condition(flag, 10, NONE)
    assert_equal(
        condition_target(plan, store, no_else, _variables('{"flag":false}')),
        NONE,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
