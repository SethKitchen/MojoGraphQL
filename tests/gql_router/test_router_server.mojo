# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the HTTP front of the router, `gql_router.router_server`.

The request decoding cases follow the tests of Hive Router `1a29df9`
`bin/router/src/pipeline/execution_request.rs` and the errors of
`bin/router/src/pipeline/error.rs`. Two cases serve the router and
two subgraphs over HTTP on the loopback interface, so that a request goes
through `RouterHandler` and `HttpTransport`. The parallel case follows
`runs_parallel_jobs_in_parallel` of `bin/router/src/executor/execution/plan.rs`.
"""

from std.time import perf_counter_ns, sleep

from _fixtures import abstract_types, simple_requires
from gql_http.client import Client
from gql_http.parser import Request
from gql_http.server import (
    Handler,
    ResponseWriter,
    ServerConfig,
    start_workers,
)
from gql_http.socket import ECONNRESET, Faults, IPv4Address, SysCall
from gql_http.status import Method, Status
from gql_json.parser import parse_bytes
from gql_json.value import NO_NODE, JsonDocument
from gql_router.exec_http import (
    CannedTransport,
    HttpTransport,
    SubgraphFailure,
)
from gql_router.exec_value import string_text
from gql_router.pipeline import Router, RouterSchema
from gql_router.router_server import (
    RouterHandler,
    prefers_graphql_response,
    read_get_params,
    read_post_params,
    serve_graphql,
)
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
    + '"price":899,"weight":100}]}}'
)
"""The response of `products`."""
comptime INVENTORY_DATA = '{"data":{"_entities":[{"shippingEstimate":50}]}}'
"""The response of `inventory`."""
comptime ANSWER = (
    '{"data":{"products":[{"upc":"1","name":"Table","shippingEstimate":50}]}}'
)
"""The client response."""


def _bytes(text: StringSlice) -> List[UInt8]:
    return List[UInt8](text.as_bytes())


def _error_of(
    get: Bool,
    text: String,
    content_type: Optional[String] = String("application/json"),
) -> String:
    try:
        if get:
            _ = read_get_params(text)
        else:
            _ = read_post_params(content_type, _bytes(text))
    except error:
        return String(error.status) + " " + error.code + " " + error.message
    return "ok"


def test_get_reads_the_query_string() raises:
    var params = read_get_params(
        "query=%7B+a+%7D&operationName=A&variables=%7B%22x%22%3A1%7D&extensions=%7B%7D"
    )
    assert_equal(params.query.value(), "{ a }")
    assert_equal(params.operation_name.value(), "A")
    assert_true(params.variables_root != NO_NODE)
    var none = read_get_params("query=x&variables=null")
    assert_equal(none.variables_root, NO_NODE)
    assert_false(none.operation_name)
    assert_equal(read_get_params("variables=").variables_root, NO_NODE)


def test_get_errors() raises:
    assert_equal(
        _error_of(True, "query=%zz"),
        "400 UNPROCESSABLE_QUERY_PARAMS Failed to parse query parameters",
    )
    var bad = "400 BAD_REQUEST Failed to parse GraphQL variables JSON"
    assert_equal(_error_of(True, "query=x&variables=%7B"), bad)
    assert_equal(_error_of(True, "query=x&variables=%5B1%5D"), bad)


def test_post_reads_the_body() raises:
    var params = read_post_params(
        String("application/json; charset=utf-8"),
        _bytes(
            '{"query":"{ a }","operationName":null,"variables":{"x":1},'
            + '"extensions":{}}'
        ),
    )
    assert_equal(params.query.value(), "{ a }")
    assert_false(params.operation_name)
    assert_equal(
        string_text(
            params.variables, params.variables.first(params.variables_root)
        ),
        "1",
    )
    var empty = read_post_params(
        String("application/json"),
        _bytes('{"variables":null,"operationName":"A"}'),
    )
    assert_false(empty.query)
    assert_equal(empty.operation_name.value(), "A")
    assert_equal(empty.variables_root, NO_NODE)


def test_post_errors() raises:
    assert_equal(
        _error_of(False, "{}", None),
        "406 MISSING_CONTENT_TYPE_HEADER Content-Type header is missing",
    )
    assert_equal(
        _error_of(False, "{}", String("text/plain")),
        "415 UNSUPPORTED_CONTENT_TYPE Content-Type header is not supported",
    )
    var bad = "400 BAD_REQUEST Failed to parse GraphQL request payload"
    assert_equal(_error_of(False, "{"), bad)
    assert_equal(_error_of(False, "[]"), bad)
    assert_equal(_error_of(False, '{"query":"a","query":"b"}'), bad)
    assert_equal(
        _error_of(False, '{"operationName":"a","operationName":"b"}'), bad
    )
    assert_equal(_error_of(False, '{"variables":{},"variables":{}}'), bad)
    assert_equal(_error_of(False, '{"query":1}'), bad)
    assert_equal(_error_of(False, '{"variables":[]}'), bad)


def test_the_response_type_follows_accept() raises:
    assert_false(prefers_graphql_response(None))
    assert_false(prefers_graphql_response(String("application/json")))
    assert_true(
        prefers_graphql_response(String("application/graphql-response+json"))
    )
    assert_true(
        prefers_graphql_response(
            String("application/graphql-response+json, application/json")
        )
    )
    assert_false(
        prefers_graphql_response(
            String("application/json, application/graphql-response+json")
        )
    )
    assert_false(
        prefers_graphql_response(
            String("*/*, application/graphql-response+json")
        )
    )


def _canned() -> CannedTransport:
    var transport = CannedTransport()
    transport.add("products", PRODUCTS, PRODUCTS_DATA)
    transport.add("inventory", INVENTORY, INVENTORY_DATA)
    return transport^


def _serve(
    method: Method,
    query_string: String,
    var body: List[UInt8],
    accept: Optional[String] = None,
) raises -> String:
    var router = Router(RouterSchema(simple_requires.sdl()), _canned())
    var answer = serve_graphql(
        router,
        method,
        query_string,
        String("application/json"),
        accept,
        body^,
    )
    return (
        String(answer.status)
        + " "
        + answer.content_type
        + " "
        + String(unsafe_from_utf8=answer.body^)
    )


def test_serve_graphql_runs_get_and_post() raises:
    assert_equal(
        _serve(
            Method.GET,
            "query=%7B+products+%7B+upc+name+shippingEstimate+%7D+%7D",
            List[UInt8](),
        ),
        "200 application/json " + ANSWER,
    )
    assert_equal(
        _serve(
            Method.POST,
            "",
            _bytes('{"query":"' + QUERY + '"}'),
            String("application/graphql-response+json"),
        ),
        "200 application/graphql-response+json " + ANSWER,
    )


def test_serve_graphql_errors() raises:
    assert_equal(
        _serve(Method.PUT, "", List[UInt8]()),
        '405 application/json {"errors":[{"message":"Unsupported HTTP method:'
        + ' PUT","extensions":{"code":"METHOD_NOT_ALLOWED"}}]}',
    )
    assert_equal(
        _serve(Method.POST, "", _bytes("{}")),
        '400 application/json {"errors":[{"message":"Missing query parameter:'
        + ' query","extensions":{"code":"MISSING_QUERY_PARAM"}}]}',
    )
    var strict = _serve(
        Method.GET,
        "query=%7B",
        List[UInt8](),
        String("application/graphql-response+json"),
    )
    assert_true(strict.startswith("400 application/graphql-response+json "))


struct _Subgraphs(Handler):
    """Answers as the `products` and `inventory` subgraphs, by path."""

    var requests: Int

    def __init__(out self):
        self.requests = 0

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        self.requests += 1
        var body = parse_bytes(List[UInt8](request.body()))
        var query = string_text(body, body.find(body.root, "query"))
        response.add_header("Content-Type", "application/json")
        if request.path() == "/products" and query == PRODUCTS:
            response.write_text(PRODUCTS_DATA)
        else:
            response.write_text(INVENTORY_DATA)


def _loopback() -> ServerConfig:
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.workers = 1
    return config^


def test_the_router_serves_http_with_http_subgraphs() raises:
    var subgraphs = start_workers(_Subgraphs(), _loopback())
    var base = "http://127.0.0.1:" + String(subgraphs.port)
    var names: List[String] = ["inventory", "products"]
    var urls: List[String] = [base + "/inventory", base + "/products"]
    var router = Router(
        RouterSchema(simple_requires.sdl()), HttpTransport(names, urls)
    )
    var front = start_workers(RouterHandler(router^), _loopback())
    var url = "http://127.0.0.1:" + String(front.port)
    var client = Client()
    var answer = client.post(
        url + "/graphql", "application/json", '{"query":"' + QUERY + '"}'
    )
    assert_equal(answer.status, Status(200))
    assert_equal(answer.header("content-type").value(), "application/json")
    assert_equal(answer.text(), ANSWER)
    var missing = client.get(url + "/other")
    assert_equal(missing.status, Status(404))
    # Upstream `health_check_handler` and `readiness_check_handler`. The
    # loaded case of `e2e/src/probes.rs` sends `POST`; any method works.
    var posted = client.post(url + "/health", "text/plain", "")
    assert_equal(posted.status, Status(200))
    posted = client.post(url + "/readiness", "text/plain", "")
    assert_equal(posted.status, Status(200))
    var health = client.get(url + "/health")
    assert_equal(health.status, Status(200))
    assert_equal(health.text(), "")
    var ready = client.get(url + "/readiness")
    assert_equal(ready.status, Status(200))
    assert_equal(ready.text(), "")
    client.close_idle()
    assert_equal(front.stop(), 0)
    assert_equal(subgraphs.stop(), 0)


struct _Slow(Handler):
    """Answers as the `books` or `magazines` subgraph after one second."""

    var field: String

    def __init__(out self, field: String):
        self.field = field

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        sleep(1.0)
        response.add_header("Content-Type", "application/json")
        response.write_text(
            '{"data":{"'
            + self.field
            + '":[{"__typename":"'
            + ("Book" if self.field == "books" else "Magazine")
            + '","id":"'
            + self.field
            + '"}]}}'
        )


def test_a_response_that_fails_to_arrive_is_a_failure() raises:
    var subgraphs = start_workers(_Subgraphs(), _loopback())
    var names: List[String] = ["products"]
    var urls: List[String] = [
        "http://127.0.0.1:" + String(subgraphs.port) + "/products"
    ]
    var transport = HttpTransport(names, urls)
    transport.client.sys.faults = Faults(SysCall.RECV, ECONNRESET, 0, 1)
    var failed = transport.send(
        "products", PRODUCTS, _bytes('{"query":"' + PRODUCTS + '"}')
    )
    assert_true(failed.failure == SubgraphFailure.REQUEST_FAILURE)
    # The client closed the connection, so the worker can fail to write its
    # response; its exit status does not matter here.
    _ = subgraphs.stop()


def test_the_fetches_of_a_parallel_node_are_in_flight_at_once() raises:
    var books = start_workers(_Slow("books"), _loopback())
    var magazines = start_workers(_Slow("magazines"), _loopback())
    var names: List[String] = ["books", "magazines"]
    var urls: List[String] = [
        "http://127.0.0.1:" + String(books.port) + "/",
        "http://127.0.0.1:" + String(magazines.port) + "/",
    ]
    var router = Router(
        RouterSchema(abstract_types.sdl()), HttpTransport(names, urls)
    )
    var started = perf_counter_ns()
    var response = router.execute(
        "{ books { id } magazines { id } }",
        None,
        JsonDocument(),
        NO_NODE,
        False,
        True,
    )
    var elapsed = perf_counter_ns() - started
    assert_equal(
        String(unsafe_from_utf8=response.body^),
        '{"data":{"books":[{"id":"books"}],"magazines":[{"id":"magazines"}]}}',
    )
    # Each subgraph takes one second. One after the other takes two.
    assert_true(elapsed < 1_800_000_000)
    assert_equal(books.stop(), 0)
    assert_equal(magazines.stop(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
