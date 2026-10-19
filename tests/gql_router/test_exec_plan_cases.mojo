# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""More plan execution cases: rewrites, missing entities, bad entity
responses and request failures.

The cases follow `execute_plan_node`, `prepare_job_future`,
`process_job_result` and the error constructors of Hive Router `1a29df9`
`bin/router/src/executor/execution/plan.rs`, beside the ported tests in
`test_exec_plan.mojo`. The subgraphs answer in the same process.
"""

from _exec_harness import run_router, variables_of
from gql_json.value import NO_NODE, JsonDocument
from gql_router.ast import NONE
from gql_router.graphql_error import GraphQLError
from gql_router.pipeline import Router, RouterSchema
from gql_router.plan_nodes import PlanNode, PlanNodeKind
from _fixtures import simple_interface_object, simple_requires
from gql_router.exec_http import (
    CannedTransport,
    SubgraphFailure,
    SubgraphHttpResponse,
)
from gql_router.exec_plan import JobKind, failure_error, plan_error
from gql_router.graphql_error import error_json
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime USERS = "{users{__typename id name}}"
"""The query that the router sends to `a`."""
comptime NAMES = (
    "query($representations:[_Any!]!){_entities(representations:"
    " $representations){...on NodeWithName{username}}}"
)
"""The query that the router sends to `b`."""
comptime PRODUCTS = "{products{__typename upc name price weight}}"
"""The query that the router sends to `products`."""
comptime INVENTORY = (
    "query($representations:[_Any!]!){_entities(representations:"
    " $representations){...on Product{shippingEstimate}}}"
)
"""The query that the router sends to `inventory`."""
comptime QUERY = "{ products { upc name shippingEstimate } }"
"""The client operation of `simple_requires`."""


def _users(data: String, names: String) -> CannedTransport:
    var transport = CannedTransport()
    transport.add("a", USERS, data)
    transport.add("b", NAMES, names)
    return transport^


def test_interface_object_entities_are_rewritten() raises:
    assert_equal(
        run_router(
            simple_interface_object.sdl(),
            _users(
                '{"data":{"users":[{"__typename":"User","id":"u1","name":"n"},'
                + '{"__typename":"User","name":"m"},null]}}',
                '{"data":{"_entities":[{"__typename":"NodeWithName",'
                + '"username":"x"}]}}',
            ),
            "{ users { id name username } }",
        ),
        # The second user has no `id`, so it sends no representation; its
        # null `id` bubbles to `data`.
        '200 {"data":null}',
    )


def test_no_entity_sends_no_request() raises:
    var transport = CannedTransport()
    transport.add("products", PRODUCTS, '{"data":{"products":[]}}')
    assert_equal(
        run_router(simple_requires.sdl(), transport^, QUERY),
        '200 {"data":{"products":[]}}',
    )


def _products(inventory: String, status: Int = 200) -> CannedTransport:
    var transport = CannedTransport()
    transport.add(
        "products",
        PRODUCTS,
        '{"data":{"products":[{"__typename":"Product","upc":"1","name":"T",'
        + '"price":1,"weight":2},{"__typename":"Product","upc":"2","name":"U",'
        + '"price":3,"weight":4}]}}',
    )
    transport.add("inventory", INVENTORY, inventory, status)
    return transport^


def test_bad_entity_responses() raises:
    var short = run_router(
        simple_requires.sdl(),
        _products('{"data":{"_entities":[{"shippingEstimate":5}]}}'),
        QUERY,
    )
    assert_equal(
        short,
        '200 {"data":{"products":[{"upc":"1","name":"T","shippingEstimate":5},'
        + '{"upc":"2","name":"U","shippingEstimate":null}]}}',
    )
    var missing = run_router(
        simple_requires.sdl(), _products('{"data":{}}'), QUERY
    )
    assert_true(missing.startswith('200 {"data":{"products":[{"upc":"1"'))
    var not_list = run_router(
        simple_requires.sdl(), _products('{"data":{"_entities":1}}'), QUERY
    )
    assert_equal(missing, not_list)
    var errors_only = run_router(
        simple_requires.sdl(),
        _products('{"data":null,"errors":[{"message":"down"}]}'),
        QUERY,
    )
    assert_true('"message":"down"' in errors_only)
    var informational = run_router(
        simple_requires.sdl(),
        _products('{"data":{"_entities":[]}}', 100),
        QUERY,
    )
    assert_true("SUBREQUEST_HTTP_ERROR" in informational)


def test_a_root_fetch_with_only_errors() raises:
    var transport = CannedTransport()
    transport.add(
        "products", PRODUCTS, '{"data":null,"errors":[{"message":"no"}]}'
    )
    assert_equal(
        run_router(simple_requires.sdl(), transport^, QUERY),
        '200 {"data":{"products":null},"errors":[{"message":"no",'
        + '"extensions":{"code":"DOWNSTREAM_SERVICE_ERROR","service":'
        + '"products"}}]}',
    )


def test_failure_errors() raises:
    var timeout = SubgraphHttpResponse.failed(
        SubgraphFailure.REQUEST_TIMEOUT, "t"
    )
    assert_equal(
        error_json(failure_error(timeout, "s", "")),
        '{"message":"Request to subgraph timed out","extensions":{"code":'
        + '"SUBGRAPH_REQUEST_TIMEOUT","service":"s"}}',
    )
    var bad = SubgraphHttpResponse.failed(SubgraphFailure.RESPONSE_FAILURE, "x")
    assert_true(
        "SUBGRAPH_RESPONSE_FAILURE" in error_json(failure_error(bad, "s", "a"))
    )
    var unknown = SubgraphHttpResponse.failed(
        SubgraphFailure.UNKNOWN_SUBGRAPH, "none"
    )
    assert_true(
        "SUBGRAPH_STATIC_ENDPOINT_NOT_FOUND"
        in error_json(failure_error(unknown, "s", ""))
    )
    assert_equal(
        error_json(plan_error("m", "C", "s", "")),
        '{"message":"m","extensions":{"code":"C","service":"s"}}',
    )
    assert_true(JobKind.BATCH_FETCH.is_valid())
    assert_false(JobKind(4).is_valid())


def _run_plan(
    mut router: Router[CannedTransport], variables: String
) raises -> String:
    router.executor.transport.reset()
    var output = router.executor.execute(
        router.schema.planner.store,
        router.slots[0].plan,
        router.schema.metadata,
        router.schema.keys,
        variables_of(variables),
        router.slots[0].projection,
        router.slots[0].root_type_name,
        JsonDocument(),
        NO_NODE,
        List[GraphQLError](),
    )
    return String(unsafe_from_utf8=output^.take_body())


def test_conditions_and_other_nodes_in_a_parallel_node() raises:
    var router = Router(
        RouterSchema(simple_requires.sdl()),
        _products(
            '{"data":{"_entities":[{"shippingEstimate":5},{"shippingEstimate":6}]}}'
        ),
    )
    _ = router.execute(QUERY, None, JsonDocument(), NO_NODE, False, True)
    ref plan = router.slots[0].plan
    var fetch = plan.nodes[plan.node].nodes[0]
    var flatten = plan.nodes[plan.node].nodes[1]
    var yes = router.schema.planner.store.sym("yes")
    var no = router.schema.planner.store.sym("no")
    var run = plan.add_condition(yes, flatten, NONE)
    var skip = plan.add_condition(no, flatten, NONE)
    var nested = plan.add_list(PlanNodeKind.SEQUENCE, [flatten])
    var parallel = plan.add_list(PlanNodeKind.PARALLEL, [run, skip, nested])
    var root = plan.add_list(PlanNodeKind.SEQUENCE, [fetch, parallel])
    plan.node = plan.add_condition(yes, root, NONE)
    # `skip` has no variable, and a sequence in a parallel node is not
    # prepared, as upstream `prepare_job_future`: one flatten runs.
    assert_equal(
        _run_plan(router, '{"yes":true}'),
        '{"data":{"products":[{"upc":"1","name":"T","shippingEstimate":5},'
        + '{"upc":"2","name":"U","shippingEstimate":6}]}}',
    )
    # Nothing runs, so the projection writes `null` for the missing field.
    assert_equal(
        _run_plan(router, '{"yes":false}'), '{"data":{"products":null}}'
    )


def test_a_subscription_node_raises() raises:
    var router = Router(RouterSchema(simple_requires.sdl()), _products("{}"))
    _ = router.execute(QUERY, None, JsonDocument(), NO_NODE, False, True)
    ref plan = router.slots[0].plan
    plan.node = plan.add(PlanNode.of(PlanNodeKind.SUBSCRIPTION))
    var failed = False
    try:
        _ = _run_plan(router, "")
    except error:
        failed = True
        assert_equal(
            String(error), "Subscriptions and @defer are not supported"
        )
    assert_true(failed)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
