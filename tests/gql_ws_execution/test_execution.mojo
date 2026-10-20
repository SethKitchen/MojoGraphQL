# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_execution.executor`: queries, validation errors and
subscriptions over graphql-transport-ws, with a `PubSub`.

Ported from graphql-ws 6.4.1 `tests/server.test.ts`: 'should execute the
query of `string` type, "next" the result and then "complete"', 'should
execute the query and "error" out because of validation errors', 'should
execute the subscription and "next" the published payload', 'should stop
dispatching messages after completing a subscription', and "should use
the provided roots as resolvers".
"""

from _peer import Peer
from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_http.server import Handler, ResponseWriter
from gql_http.parser import Request
from gql_http.socket import IPv4Address
from gql_schema.build import build_schema
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.server import Server, ServerConfig, UpgradeRequired, listen
from gql_ws.transport_server import TransportServer
from gql_ws_execution.executor import (
    DefaultHooks,
    GraphQLExecution,
    Hooks,
    PubSubRoot,
)
from std.testing import TestSuite, assert_equal, assert_true

comptime SDL = (
    "type Query { hello(name: String): String, count: Int }"
    " type Subscription { greetings(n: Int): String, plain: String }"
)
comptime INIT = '{"type":"connection_init"}'


def _hello(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("world")


def resolvers() -> Resolvers:
    var r = Resolvers()
    r.field("Query", "hello", _hello)
    return r^


def config() -> ServerConfig:
    var c = ServerConfig()
    c.http.host = IPv4Address.LOOPBACK
    c.http.port = 0
    c.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
    return c^


def serve[
    K: Hooks
](var hooks: K) raises -> Server[
    TransportServer[GraphQLExecution[K]], UpgradeRequired
]:
    var executor = GraphQLExecution(build_schema(SDL), resolvers(), hooks^)
    return listen(TransportServer(executor^), UpgradeRequired(), config())


def subscribe(id: StringSlice, payload: StringSlice) -> String:
    return (
        '{"id":"'
        + String(id)
        + '","type":"subscribe","payload":'
        + String(payload)
        + "}"
    )


def joined(items: List[String]) -> String:
    return "\n".join(items)


def test_query() raises:
    var server = serve(DefaultHooks())
    var peer = Peer(server.port)
    peer.open(server)
    assert_equal(joined(peer.send(server, INIT)), '{"type":"connection_ack"}')
    assert_equal(
        joined(peer.send(server, subscribe("1", '{"query":"{ hello }"}'))),
        (
            '{"id":"1","type":"next","payload":{"data":{"hello":"world"}}}\n'
            '{"id":"1","type":"complete"}'
        ),
    )
    # Variables and the operation name.
    assert_equal(
        joined(
            peer.send(
                server,
                subscribe(
                    "2",
                    (
                        '{"query":"query A { hello } query B($x: String) {'
                        " hello(name: $x)"
                        ' }","operationName":"B","variables":{"x":"y"}}'
                    ),
                ),
            )
        ),
        (
            '{"id":"2","type":"next","payload":{"data":{"hello":"world"}}}\n'
            '{"id":"2","type":"complete"}'
        ),
    )
    assert_equal(
        joined(
            peer.send(
                server,
                subscribe(
                    "3", '{"query":"query A { hello }","operationName":"C"}'
                ),
            )
        ),
        (
            '{"id":"3","type":"error","payload":[{"message":"Unable to identify'
            ' operation"}]}'
        ),
    )
    peer.close()


def test_validation_errors() raises:
    var server = serve(DefaultHooks())
    var peer = Peer(server.port)
    peer.open(server)
    _ = peer.send(server, INIT)
    var got = joined(
        peer.send(server, subscribe("1", '{"query":"{ notExists }"}'))
    )
    assert_equal(
        got,
        (
            '{"id":"1","type":"error","payload":[{"message":"Cannot query field'
            ' \\"notExists\\" on type'
            ' \\"Query\\".","locations":[{"line":1,"column":3}]}]}'
        ),
    )
    peer.close()


def test_syntax_error() raises:
    var server = serve(DefaultHooks())
    var peer = Peer(server.port)
    peer.open(server)
    _ = peer.send(server, INIT)
    var got = joined(peer.send(server, subscribe("1", '{"query":"{"}')))
    assert_true(got.startswith("close 4500 Syntax Error: "), got)
    peer.close()


def test_subscription() raises:
    var pubsub = PubSub()
    var hooks = PubSubRoot(pubsub)
    hooks.add("greetings", "GREET")
    var server = serve(hooks^)
    var peer = Peer(server.port)
    peer.open(server)
    _ = peer.send(server, INIT)
    assert_equal(
        len(
            peer.send(
                server, subscribe("s", '{"query":"subscription { greetings }"}')
            )
        ),
        0,
    )
    pubsub.publish("GREET", Event.parse('{"greetings":"hi"}'))
    pubsub.publish("GREET", Event.parse('{"greetings":"hey"}'))
    assert_equal(
        joined(peer.read(server)),
        (
            '{"id":"s","type":"next","payload":{"data":{"greetings":"hi"}}}\n'
            '{"id":"s","type":"next","payload":{"data":{"greetings":"hey"}}}'
        ),
    )
    # A query runs while the subscription is open.
    assert_equal(
        len(peer.send(server, subscribe("q", '{"query":"{ hello }"}'))), 2
    )
    # The client completes; no more events come.
    assert_equal(len(peer.send(server, '{"id":"s","type":"complete"}')), 0)
    pubsub.publish("GREET", Event.parse('{"greetings":"late"}'))
    assert_equal(len(peer.read(server)), 0)
    peer.close()


def test_subscription_failures() raises:
    var pubsub = PubSub()
    var hooks = PubSubRoot(pubsub)
    hooks.add("greetings", "GREET")
    var server = serve(hooks^)
    var peer = Peer(server.port)
    peer.open(server)
    _ = peer.send(server, INIT)
    # Errors of `subscribe`: a variable without a value.
    var errors = joined(
        peer.send(
            server,
            subscribe(
                "1",
                '{"query":"subscription ($n: Int!) { greetings(n: $n) }"}',
            ),
        )
    )
    assert_true(
        errors.startswith('{"id":"1","type":"next","payload":{"errors":'),
        errors,
    )
    assert_true(errors.endswith('{"id":"1","type":"complete"}'), errors)
    # A field without a stream: `subscribe` raises, the socket closes.
    var closed = joined(
        peer.send(server, subscribe("2", '{"query":"subscription { plain }"}'))
    )
    assert_true(
        closed.startswith(
            "close 4500 Subscription field must return Async Iterable"
        ),
        closed,
    )
    peer.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
