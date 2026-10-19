# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Router pipeline tests: one request from the document to the response.

The end-to-end case runs the Hive Router `1a29df9` benchmark operation,
`bench/operation.graphql`, against `bench/supergraph.graphql` with the
canned subgraph responses of the `hive-router/execute` benchmark, and
compares the response with the upstream `expected_response.json` byte for
byte. The error cases follow `bin/router/src/pipeline/error.rs` and the
checks of `bin/router/src/pipeline/mod.rs`.
"""

from _exec_harness import run_router
from _fixtures import (
    abstract_types,
    bench_exec,
    bench_supergraph,
    corrupted_supergraph_node_id,
    mutations,
    simple_requires,
)
from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument
from gql_json.writer import stringify
from gql_router.cache import default_cache_limits
from gql_router.exec_http import CannedTransport
from gql_router.exec_value import string_text
from gql_router.pipeline import (
    PipelineError,
    PipelineErrorKind,
    Router,
    RouterSchema,
    client_error,
    client_error_prefer_ok,
    internal_error,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _bench_transport() raises -> CannedTransport:
    var canned = parse(bench_exec.responses())
    var transport = CannedTransport()
    var item = canned.first(canned.root)
    while item != NO_NODE:
        transport.add(
            string_text(canned, canned.find(item, "subgraph")),
            string_text(canned, canned.find(item, "query")),
            stringify(canned, canned.find(item, "response")),
        )
        item = canned.next(item)
    return transport^


def _body(var bytes: List[UInt8]) -> String:
    return String(unsafe_from_utf8=bytes^)


def test_bench_operation_matches_the_upstream_response() raises:
    var router = Router(RouterSchema(bench_supergraph.sdl()), _bench_transport())
    var query = bench_supergraph.operation()
    for _ in range(2):
        router.executor.transport.reset()
        var response = router.execute(
            query, String("TestQuery"), JsonDocument(), NO_NODE, False, True
        )
        assert_equal(response.status, 200)
        assert_equal(_body(response^.take_body()), bench_exec.expected_response())


def test_a_parse_error_is_a_client_error() raises:
    var expected = (
        '{"errors":[{"message":"Failed to parse GraphQL operation: '
    )
    var ok = run_router(simple_requires.sdl(), CannedTransport(), "{ products")
    assert_true(ok.startswith("200 " + expected))
    assert_true("GRAPHQL_PARSE_FAILED" in ok)
    var strict = run_router(
        simple_requires.sdl(), CannedTransport(), "{ products", prefer_ok=False
    )
    assert_true(strict.startswith("400 " + expected))


def test_an_unknown_operation_does_not_normalize() raises:
    assert_equal(
        run_router(
            simple_requires.sdl(),
            CannedTransport(),
            "query A { products { upc } }",
            operation_name=String("B"),
        ),
        '400 {"errors":[{"message":"Failed to normalize GraphQL operation",'
        + '"extensions":{"code":"OPERATION_RESOLUTION_FAILURE"}}]}',
    )


def test_a_subscription_is_not_supported() raises:
    assert_equal(
        run_router(
            bench_supergraph.sdl(),
            CannedTransport(),
            "subscription { reviewAdded { id } }",
        ),
        '415 {"errors":[{"message":"Subscriptions are not supported",'
        + '"extensions":{"code":"SUBSCRIPTIONS_NOT_SUPPORTED"}}]}',
    )


def test_a_mutation_over_get_is_not_allowed() raises:
    assert_equal(
        run_router(
            mutations.sdl(), CannedTransport(), "mutation { delete }", is_get=True
        ),
        '405 {"errors":[{"message":"Cannot perform mutations over GET",'
        + '"extensions":{"code":"MUTATION_NOT_ALLOWED_OVER_HTTP_GET"}}]}',
    )


def test_bad_variables_are_bad_user_input() raises:
    var out = run_router(
        mutations.sdl(),
        CannedTransport(),
        "mutation ($by: Int!) { multiply(by: $by) }",
        variables='{"by":"x"}',
    )
    assert_true(out.startswith('200 {"errors":[{"message":'))
    assert_true("BAD_USER_INPUT" in out)


def test_the_cache_reuses_and_replaces_slots() raises:
    var transport = CannedTransport()
    transport.add(
        "products",
        "{products{__typename upc}}",
        '{"data":{"products":[{"__typename":"Product","upc":"1"}]}}',
    )
    var router = Router(
        RouterSchema(simple_requires.sdl()),
        transport^,
        default_cache_limits().with_max_entries(1),
    )
    var first = router.prepare("{ products { upc } }", None)
    assert_equal(router.prepare("{ products { upc } }", None), first)
    # The new operation takes a new slot; the cache then drops the first.
    assert_equal(router.prepare("{ products { name } }", None), 1)
    # The next one takes the slot whose operation left the cache.
    assert_equal(router.prepare("{ products { price } }", None), first)
    assert_equal(len(router.slots), 2)


def test_a_cached_operation_is_found_in_a_later_slot() raises:
    var router = Router(RouterSchema(simple_requires.sdl()), CannedTransport())
    assert_equal(router.prepare("{ products { upc } }", None), 0)
    assert_equal(router.prepare("{ products { name } }", None), 1)
    assert_equal(router.prepare("{ products { name } }", None), 1)


def test_introspection_is_resolved_with_the_downstream_part() raises:
    var transport = CannedTransport()
    transport.add(
        "products",
        "{__typename products{upc}}",
        '{"data":{"products":[{"__typename":"Product","upc":"1"}]}}',
    )
    assert_equal(
        run_router(
            simple_requires.sdl(),
            transport^,
            "{ __typename products { upc } }",
        ),
        '200 {"data":{"__typename":"Query","products":[{"upc":"1"}]}}',
    )


def test_an_introspection_only_operation_sends_nothing() raises:
    assert_equal(
        run_router(
            simple_requires.sdl(),
            CannedTransport(),
            '{ __type(name: "Product") { name } }',
        ),
        '200 {"data":{"__type":{"name":"Product"}}}',
    )
    var router = Router(RouterSchema(simple_requires.sdl()), CannedTransport())
    for _ in range(2):
        var response = router.execute(
            "{ __schema { queryType { name } } }",
            None,
            JsonDocument(),
            NO_NODE,
            False,
            True,
        )
        assert_equal(
            _body(response^.take_body()),
            '{"data":{"__schema":{"queryType":{"name":"Query"}}}}',
        )


def test_a_plan_that_cannot_be_built_is_an_internal_error() raises:
    var query = 'query { node(id: "a1") { id } }'
    assert_equal(
        run_router(corrupted_supergraph_node_id.sdl(), CannedTransport(), query),
        '200 {"errors":[{"message":"Internal server error",'
        + '"extensions":{"code":"QUERY_PLAN_BUILD_FAILED"}}]}',
    )
    assert_true(
        run_router(
            corrupted_supergraph_node_id.sdl(),
            CannedTransport(),
            query,
            prefer_ok=False,
        ).startswith("500 ")
    )


def test_a_projection_failure_is_an_internal_error() raises:
    var transport = CannedTransport()
    transport.add(
        "reviews",
        "{review(id: 1){product{__typename ...on Book{__typename id}}}}",
        '{"data":{"review":{"__typename":"Ghost","product":{"id":"1"}}}}',
    )
    assert_equal(
        run_router(
            abstract_types.sdl(),
            transport^,
            "{ review(id: 1) { product { ... on Book { sku } } } }",
        ),
        '200 {"errors":[{"message":"Internal server error",'
        + '"extensions":{"code":"PLAN_EXECUTION_FAILED"}}]}',
    )


def test_pipeline_errors_report_their_kind_and_status() raises:
    var internal = internal_error("plan broke", "QUERY_PLAN_BUILD_FAILED")
    assert_equal(internal.client_message(), "Internal server error")
    assert_equal(internal.status_code(True), 200)
    assert_equal(internal.status_code(False), 500)
    assert_equal(String(internal), "QUERY_PLAN_BUILD_FAILED: plan broke")
    var client = client_error("no", "X", 404)
    assert_equal(client.status_code(True), 404)
    assert_equal(client_error_prefer_ok("no", "X").status_code(False), 400)
    assert_true(PipelineErrorKind.INTERNAL.is_valid())
    assert_false(PipelineErrorKind(3).is_valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
