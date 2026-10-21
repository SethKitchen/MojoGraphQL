# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""End-to-end subscriptions over WebSocket: a `graphql-transport-ws`
client, the router and the Mojo subgraphs, each in its own process.

Ports the cases of Hive Router `1a29df9` `e2e/src/websocket.rs`
(`query_over_websocket`, `subscription_over_websocket`,
`multiple_subscriptions_in_parallel`,
`should_not_steal_non_upgrade_get_requests_on_same_graphql_path`) and
`subscription_yes_entity_resolution_websocket_subgraph` of
`e2e/src/subscriptions.rs`.
"""

from _client import (
    graphql_body,
    names,
    names_of_reviews,
    post,
    sse_of,
    ws_results,
    ws_url,
)
from _e2e import start_router, start_subgraphs
from gql_http.client import Client
from gql_ws.graphql_ws import MessageType
from gql_ws.transport_client import ClientEvent, TransportClient
from std.testing import TestSuite, assert_equal, assert_true

comptime WS = '{"websocket":{"enabled":true},"subscriptions":{"enabled":true}}'
comptime WS_SUBGRAPH = (
    '{"websocket":{"enabled":true},"subscriptions":{"enabled":true,'
    + '"websocket":{"all":{}}}}'
)


def _subscribe(mut client: TransportClient, query: String) raises -> String:
    var body = graphql_body(query)
    return client.subscribe(StringSlice(unsafe_from_utf8=Span(body)))


def test_query_over_websocket() raises:
    var subgraphs = start_subgraphs()
    var router = start_router(subgraphs.port, '{"websocket":{"enabled":true}}')
    var client = TransportClient.connect(ws_url(router.port), "", 3000)
    var id = _subscribe(client, "query { topProducts { name upc } }")
    var results = ws_results(client, id)
    router.stop()
    subgraphs.stop()
    assert_equal(
        results, ['{"data":{"topProducts":[{"name":"Table","upc":"1"}]}}']
    )


def test_subscription_over_websocket() raises:
    for config in [WS, WS_SUBGRAPH]:
        var subgraphs = start_subgraphs()
        var router = start_router(subgraphs.port, config)
        var client = TransportClient.connect(ws_url(router.port), "", 3000)
        var id = _subscribe(
            client,
            (
                "subscription { reviewAdded(step: 1, intervalInMs: 0) { id"
                " body } }"
            ),
        )
        var results = ws_results(client, id)
        router.stop()
        subgraphs.stop()
        assert_equal(len(results), 11)
        assert_equal(
            results[10],
            '{"data":{"reviewAdded":{"id":"11","body":"Review 11"}}}',
        )


def test_multiple_subscriptions_in_parallel() raises:
    var subgraphs = start_subgraphs()
    var router = start_router(subgraphs.port, WS_SUBGRAPH)
    var client = TransportClient.connect(ws_url(router.port), "", 3000)
    var query = (
        "subscription { reviewAdded(intervalInMs: 0) { id product { name } } }"
    )
    var first = _subscribe(client, query)
    var second = _subscribe(client, query)
    var one = List[String]()
    var two = List[String]()
    var completed = 0
    var event = ClientEvent()
    while completed < 2:
        assert_true(client.next(event, 4000))
        if event.type == MessageType.COMPLETE:
            completed += 1
        elif event.id == first:
            one.append(event.payload)
        else:
            assert_equal(event.id, second)
            two.append(event.payload)
    router.stop()
    subgraphs.stop()
    var expected = names_of_reviews(names())
    assert_equal(one, expected)
    assert_equal(two, expected)


def test_entity_resolution_websocket_subgraph() raises:
    var subgraphs = start_subgraphs()
    var router = start_router(subgraphs.port, WS_SUBGRAPH)
    var answer = post(
        router.port,
        "subscription { reviewAdded(intervalInMs: 0) { id product { name } } }",
        "text/event-stream",
    )
    router.stop()
    subgraphs.stop()
    assert_equal(answer.body, sse_of(names_of_reviews(names())))


def test_plain_get_on_the_graphql_path() raises:
    var subgraphs = start_subgraphs()
    var router = start_router(subgraphs.port, WS)
    var client = Client()
    var response = client.get(
        "http://127.0.0.1:"
        + String(router.port)
        + "/graphql?query=%7BtopProducts%7Bupc%7D%7D"
    )
    router.stop()
    subgraphs.stop()
    assert_equal(response.status.code, 200)
    assert_equal(response.text(), '{"data":{"topProducts":[{"upc":"1"}]}}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
