# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""End-to-end subscriptions over HTTP streams: a client, the router and
the Mojo subgraphs, each in its own process.

Ports the cases of Hive Router `1a29df9` `e2e/src/subscriptions.rs`:
`subscription_not_allowed_when_disabled`,
`subscription_no_entity_resolution_sse_subgraph`,
`subscription_no_entity_resolution_multipart_subgraph`,
`subscription_yes_entity_resolution`, the multipart and incremental
delivery client cases, `subscription_with_variable_forwarding`,
`subscription_stream_failed_source_subgraph_requests` and
`subscription_stream_failed_entity_resolution_requests`.
"""

from _client import names, names_of_reviews, post, sse_of
from _e2e import start_router, start_subgraphs
from std.testing import TestSuite, assert_equal, assert_true

comptime ENABLED = '{"subscriptions":{"enabled":true}}'
comptime UPCS = '{"data":{"reviewAdded":{"product":{"upc":"'


def _upcs() -> String:
    var payloads = List[String]()
    for upc in ["1", "1", "1", "1", "2", "2", "2", "2", "3", "4", "4"]:
        payloads.append(UPCS + upc + '"}}}}')
    return sse_of(payloads)


def test_subscription_not_allowed_when_disabled() raises:
    var subgraphs = start_subgraphs()
    var router = start_router(subgraphs.port, "{}")
    var answer = post(
        router.port,
        "subscription { reviewAdded(intervalInMs: 0) { product { upc } } }",
        "text/event-stream",
    )
    router.stop()
    subgraphs.stop()
    assert_equal(answer.status, 200)
    assert_equal(
        answer.body,
        sse_of(
            [
                '{"errors":[{"message":"Subscriptions are not supported",'
                + '"extensions":{"code":"SUBSCRIPTIONS_NOT_SUPPORTED"}}]}'
            ]
        ),
    )


def test_no_entity_resolution_sse_and_multipart_subgraphs() raises:
    for multipart in [False, True]:
        var subgraphs = start_subgraphs(multipart)
        var router = start_router(subgraphs.port, ENABLED)
        var answer = post(
            router.port,
            "subscription { reviewAdded(intervalInMs: 0) { product { upc } } }",
            "text/event-stream",
        )
        router.stop()
        subgraphs.stop()
        assert_equal(answer.status, 200)
        assert_equal(answer.content_type, "text/event-stream")
        assert_equal(answer.body, _upcs())


def test_yes_entity_resolution() raises:
    var subgraphs = start_subgraphs()
    var router = start_router(subgraphs.port, ENABLED)
    var query = (
        "subscription { reviewAdded(intervalInMs: 0) { id product { name } } }"
    )
    var sse = post(router.port, query, "text/event-stream")
    var apollo = post(
        router.port, query, "multipart/mixed;subscriptionSpec=1.0"
    )
    var quoted = post(
        router.port, query, 'multipart/mixed;subscriptionSpec="1.0"'
    )
    var incremental = post(router.port, query, "multipart/mixed")
    router.stop()
    subgraphs.stop()
    var payloads = names_of_reviews(names())
    assert_equal(sse.body, sse_of(payloads))
    var parts = String()
    var plain = String()
    for payload in payloads:
        parts += "--graphql\r\nContent-Type: application/json\r\n\r\n"
        parts += '{"payload":' + payload + "}\r\n"
        plain += "---\r\nContent-Type: application/json\r\n\r\n"
        plain += payload + "\r\n"
    assert_equal(
        apollo.content_type,
        'multipart/mixed;boundary="graphql";subscriptionSpec=1.0',
    )
    assert_equal(apollo.body, parts + "--graphql--")
    assert_equal(quoted.body, parts + "--graphql--")
    assert_equal(incremental.content_type, 'multipart/mixed;boundary="-"')
    assert_equal(incremental.body, plain + "-----")


def test_with_variable_forwarding() raises:
    var subgraphs = start_subgraphs()
    var router = start_router(subgraphs.port, ENABLED)
    var answer = post(
        router.port,
        "subscription ($upc: String!) { reviewAddedForProduct(productUpc:"
        + " $upc, intervalInMs: 0) { id product { upc name } } }",
        "text/event-stream",
        '{"upc":"2"}',
    )
    router.stop()
    subgraphs.stop()
    var payloads = List[String]()
    for id in ["5", "6", "7", "8"]:
        payloads.append(
            '{"data":{"reviewAddedForProduct":{"id":"'
            + id
            + '","product":{"upc":"2","name":"Couch"}}}}'
        )
    assert_equal(answer.body, sse_of(payloads))


def test_failed_source_and_entity_requests() raises:
    var subgraphs = start_subgraphs(fail_reviews=True)
    var router = start_router(subgraphs.port, ENABLED)
    var answer = post(
        router.port,
        "subscription { reviewAdded(intervalInMs: 0) { id } }",
        "text/event-stream",
    )
    router.stop()
    subgraphs.stop()
    assert_true(
        answer.body.find("SUBGRAPH_STREAM_STATUS_CODE_NOT_OK") >= 0,
        answer.body,
    )
    subgraphs = start_subgraphs(fail_products=True)
    router = start_router(subgraphs.port, ENABLED)
    answer = post(
        router.port,
        "subscription ($upc: String!) { reviewAddedForProduct(productUpc:"
        + " $upc, intervalInMs: 0) { product { name } } }",
        "text/event-stream",
        '{"upc":"2"}',
    )
    router.stop()
    subgraphs.stop()
    var event = (
        '{"data":{"reviewAddedForProduct":{"product":{"name":null}}},'
        + '"errors":[{"message":"Something Went Wrong!","extensions":'
        + '{"code":"DOWNSTREAM_SERVICE_ERROR","service":"products",'
        + '"affectedPath":"reviewAddedForProduct.product"}},'
        + '{"message":"Subgraph \'products\' responded with an invalid'
        + ' HTTP status code \'500 Internal Server Error\'","extensions":'
        + '{"code":"SUBREQUEST_HTTP_ERROR","service":"products",'
        + '"affectedPath":"reviewAddedForProduct.product","http":'
        + '{"status":500}}}]}'
    )
    assert_equal(answer.body, sse_of([event, event, event, event]))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
