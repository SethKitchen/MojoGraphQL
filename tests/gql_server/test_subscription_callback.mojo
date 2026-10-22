# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `SubscriptionCallbackPlugin`, ported from Apollo Server 5.5.1
`src/__tests__/plugin/subscriptionCallback/subscriptionCallbackPlugin.test.ts`.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_http.server import (
    Handler,
    Request,
    ResponseWriter,
    ServerConfig,
    start_workers,
)
from gql_http.socket import IPv4Address
from gql_http.status import Status
from gql_schema.build import build_schema
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.subscription_callback import (
    SubscriptionCallbackOptions,
    SubscriptionCallbackPlugin,
)
from gql_server.types import GraphQLRequest
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream, ListStream

comptime SDL = """
type Query { hello: String }
type Subscription {
  countdown: Int
  failing: Int
  broken: Int
}
"""


struct CallbackHandler(Handler):
    """A mock router HTTP server that answers 204 or 404."""

    var status: Status

    def __init__(out self, status: Status = Status.NO_CONTENT):
        self.status = status

    def handle(mut self, request: Request, mut response: ResponseWriter):
        response.status = self.status


def _subscribe_countdown(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var items: List[String] = [
        '{"countdown":2}',
        '{"countdown":1}',
    ]
    return values.add_stream(AnyStream(ListStream.of_json(items)))


def _subscribe_failing(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var items = List[String]()
    return values.add_stream(
        AnyStream(ListStream.of_json(items, "stream exploded"))
    )


def _subscribe_broken(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    raise Error("subscribe resolver failed")


def _worker_config() -> ServerConfig:
    var cfg = ServerConfig()
    cfg.host = IPv4Address.LOOPBACK
    cfg.port = 0
    cfg.workers = 1
    return cfg^


def _make_server() raises -> ApolloServer[SubscriptionCallbackPlugin]:
    var schema = build_schema(SDL)
    var resolvers = Resolvers()
    resolvers.subscribe("Subscription", "countdown", _subscribe_countdown)
    resolvers.subscribe("Subscription", "failing", _subscribe_failing)
    resolvers.subscribe("Subscription", "broken", _subscribe_broken)
    var cb_opts = SubscriptionCallbackOptions(0, 0)
    var plugin = SubscriptionCallbackPlugin(schema, resolvers, cb_opts)
    var server = ApolloServer(
        schema.copy(), resolvers.copy(), ApolloServerOptions(), plugin^
    )
    server.start()
    return server^


def test_subscription_callback_next_and_complete() raises:
    var pool = start_workers(
        CallbackHandler(Status.NO_CONTENT), _worker_config()
    )
    var cb_url = "http://127.0.0.1:" + String(pool.port) + "/callback"
    var server = _make_server()

    # Non-subscription operation ignores the callback plugin.
    var req_plain = GraphQLRequest(String("{ hello }"))
    var resp_plain = server.execute_operation(req_plain^)
    assert_false(resp_plain.has_errors)

    # Successful subscription handshake and next + complete events.
    var req_ok = GraphQLRequest(String("subscription { countdown }"))
    req_ok.set_extensions(
        '{"subscription":{"callbackUrl":"'
        + cb_url
        + '","subscriptionId":"sub-ok","verifier":"ver-ok","heartbeatIntervalMs":0}}'
    )
    var resp_ok = server.execute_operation(req_ok^)
    assert_false(resp_ok.has_errors)
    assert_equal(resp_ok.to_json(), '{"data":null}')
    assert_equal(
        resp_ok.http.headers.get("content-type").value(),
        "application/json; callbackSpec=1.0; charset=utf-8",
    )
    assert_equal(len(server.plugin.active), 1)
    assert_equal(server.plugin.poll(), 3)
    assert_equal(len(server.plugin.active), 0)

    # Stream that emits an error sends complete with errors.
    var req_err_stream = GraphQLRequest(String("subscription { failing }"))
    req_err_stream.set_extensions(
        '{"subscription":{"callbackUrl":"'
        + cb_url
        + '","subscriptionId":"sub-fail"}}'
    )
    var resp_err_stream = server.execute_operation(req_err_stream^)
    assert_false(resp_err_stream.has_errors)
    assert_equal(server.plugin.poll(), 1)
    assert_equal(len(server.plugin.active), 0)

    server.stop()
    assert_equal(server.plugin.poll(), 0)
    assert_equal(pool.stop(), 0)


def test_subscription_callback_errors() raises:
    var server = _make_server()

    # A subscription against an unreachable port fails the handshake check.
    var req_fail = GraphQLRequest(String("subscription { countdown }"))
    req_fail.set_extensions(
        '{"subscription":{"callbackUrl":"http://127.0.0.1:1/cb",'
        '"subscriptionId":"sub-1","verifier":"v-1","heartbeatIntervalMs":10}}'
    )
    var resp_fail = server.execute_operation(req_fail^)
    assert_true(resp_fail.has_errors)
    assert_equal(resp_fail.http.status, 500)
    assert_true("SUBSCRIPTION_HANDSHAKE_FAILED" in resp_fail.to_json())

    # A subscription resolver that throws returns the error in the response.
    var req_broken = GraphQLRequest(String("subscription { broken }"))
    req_broken.set_extensions(
        '{"subscription":{"callbackUrl":"http://127.0.0.1:1/cb",'
        '"subscriptionId":"sub-err"}}'
    )
    var resp_broken = server.execute_operation(req_broken^)
    assert_true(resp_broken.has_errors)
    assert_true("subscribe resolver failed" in resp_broken.to_json())
    server.stop()


def test_subscription_callback_helpers() raises:
    var schema = build_schema(SDL)
    var resolvers = Resolvers()
    var plugin = SubscriptionCallbackPlugin(schema, resolvers)

    assert_equal(
        plugin._check_body("id1", "ver1"),
        '{"kind":"subscription","action":"check","id":"id1","verifier":"ver1"}',
    )
    assert_equal(
        plugin._check_body("id1", ""),
        '{"kind":"subscription","action":"check","id":"id1"}',
    )
    assert_equal(
        plugin._next_body("id1", "ver1", '{"data":{"countdown":1}}'),
        '{"kind":"subscription","action":"next","id":"id1","verifier":"ver1","payload":{"data":{"countdown":1}}}',
    )
    assert_equal(
        plugin._complete_body("id1", "", None),
        '{"kind":"subscription","action":"complete","id":"id1"}',
    )
    assert_equal(
        plugin._complete_body("id1", "v", String("boom")),
        '{"kind":"subscription","action":"complete","id":"id1","verifier":"v","errors":[{"message":"boom"}]}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
