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
"""

from _exec_harness import run_router
from _fixtures import simple_requires
from gql_router.exec_http import CannedTransport
from std.testing import TestSuite, assert_equal

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
        + '"errors":[{"message":"Subgraph \'inventory\' responded with an invalid'
        + ' HTTP status code \'500 Internal Server Error\'","extensions":{"code":'
        + '"SUBREQUEST_HTTP_ERROR","service":"inventory","affectedPath":'
        + '"products.@","http":{"status":500}}}]}',
    )


def _failure(inventory: String, content_type: String = "application/json") raises -> String:
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
        + " 'inventory': 'text/html'\",\"extensions\":{\"code\":"
        + '"SUBREQUEST_MALFORMED_RESPONSE","service":"inventory",'
        + '"affectedPath":"products.@"}}]}',
    )
    assert_equal(
        _failure("{}", ""),
        '"errors":[{"message":"Invalid content type returned from subgraph'
        + " 'inventory': ''\",\"extensions\":{\"code\":"
        + '"SUBREQUEST_MALFORMED_RESPONSE","service":"inventory",'
        + '"affectedPath":"products.@"}}]}',
    )
    assert_equal(
        _failure('{"data":null}'),
        '"errors":[{"message":"Subgraph returned malformed response",'
        + '"extensions":{"code":"SUBREQUEST_MALFORMED_RESPONSE","service":'
        + '"inventory","affectedPath":"products.@"}}]}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
