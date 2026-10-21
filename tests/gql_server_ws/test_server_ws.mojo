# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of an Apollo Server with HTTP and graphql-transport-ws on one port.

The setup is that of Apollo Server 5.5.1
`docs/source/data/subscriptions.mdx`, which has no test of its own: the
schema, a subscription of a PubSub, and the drain on `stop`. The messages
are those of the graphql-ws server tests in `tests/gql_ws_execution`.
"""

from std.testing import TestSuite, assert_equal, assert_raises, assert_true
from _peer import Peer
from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_http.socket import Faults, IPv4Address, SysCall
from gql_server.plugin import ServerPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server_ws.server import ApolloWsServer, start_server_ws
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub
from gql_ws.server import ServerConfig
from gql_ws_execution.executor import DefaultHooks, Hooks, PubSubRoot

comptime SDL = """
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT
type Query { hello: String }
type Subscription { greetings: String }
"""
"""The schema: a query, `@defer` of graphql-js 17, and a subscription."""

comptime INIT = '{"type":"connection_init"}'


struct Recorder(ServerPlugin):
    """A plugin that records the server hooks."""

    var log: List[String]

    def __init__(out self):
        self.log = List[String]()

    def server_will_start(mut self) raises:
        self.log.append("start")

    def server_will_stop(mut self) raises:
        self.log.append("stop")


def _hello(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("world")


def _config() -> ServerConfig:
    var out = ServerConfig()
    out.http.host = IPv4Address.LOOPBACK
    out.http.port = 0
    return out^


def _start[
    K: Hooks
](var hooks: K, var config: ServerConfig = _config()) raises -> ApolloWsServer[
    Recorder, K
]:
    var resolvers = Resolvers()
    resolvers.field("Query", "hello", _hello)
    var options = ApolloServerOptions()
    options.node_env = String("test")
    var server = ApolloServer.from_type_defs(
        SDL, resolvers^, options^, Recorder()
    )
    return start_server_ws(server^, hooks^, config^)


def _post(body: String, accept: String = "") -> String:
    var out = String(
        "POST / HTTP/1.1\r\nhost: x\r\ncontent-type: application/json\r\n"
    )
    if accept.byte_length() > 0:
        out += "accept: " + accept + "\r\n"
    out += "content-length: " + String(body.byte_length()) + "\r\n\r\n"
    return out + body


def _subscribe(id: StringSlice, query: StringSlice) -> String:
    return (
        '{"id":"'
        + String(id)
        + '","type":"subscribe","payload":{"query":"'
        + String(query)
        + '"}}'
    )


def test_http_and_websocket_on_one_port() raises:
    var pubsub = PubSub()
    var hooks = PubSubRoot(pubsub)
    hooks.add("greetings", "GREET")
    var server = _start(hooks^)
    assert_equal(server.url, "http://localhost:" + String(server.port()) + "/")
    assert_equal(server.server().plugin.log[0], "start")
    # HTTP goes through the request pipeline of Apollo Server.
    var http = Peer(server.port())
    var text = http.http(server, _post('{"query":"{ hello }"}'))
    assert_true(text.startswith("HTTP/1.1 200"), text)
    assert_true('{"data":{"hello":"world"}}' in text, text)
    http.close()
    # A WebSocket on the same port runs queries and subscriptions.
    var peer = Peer(server.port())
    peer.open(server)
    assert_equal(peer.send(server, INIT)[0], '{"type":"connection_ack"}')
    var got = peer.send(server, _subscribe("q", "{ hello }"))
    assert_equal(
        got[0], '{"id":"q","type":"next","payload":{"data":{"hello":"world"}}}'
    )
    assert_equal(got[1], '{"id":"q","type":"complete"}')
    assert_equal(
        len(peer.send(server, _subscribe("s", "subscription { greetings }"))),
        0,
    )
    pubsub.publish("GREET", Event.parse('{"greetings":"hi"}'))
    assert_equal(
        peer.read(server)[0],
        '{"id":"s","type":"next","payload":{"data":{"greetings":"hi"}}}',
    )
    peer.close()


def test_defer_over_http() raises:
    var server = _start(DefaultHooks())
    var peer = Peer(server.port())
    var text = peer.http(
        server,
        _post(
            '{"query":"{ hello ... @defer { again: hello } }"}',
            "multipart/mixed; incrementalSpec=v0.2",
        ),
    )
    assert_true("incrementalSpec=v0.2" in text, text)
    assert_true(
        '"pending":[{"id":"0","path":[]}],"hasNext":true}' in text, text
    )
    assert_true(
        '{"hasNext":false,"incremental":[{"id":"0","data":{"again":"world"}}]'
        in text,
        text,
    )
    peer.close()


def test_drain_closes_each_websocket_then_stops() raises:
    var config = _config()
    config.protocols = ["graphql-transport-ws"]
    var server = _start(DefaultHooks(), config^)
    var peer = Peer(server.port())
    peer.open(server)
    _ = peer.send(server, INIT)
    server.begin_shutdown()
    assert_equal(peer.read(server)[0], "close 1001")
    # The client answers the close frame; the drain ends.
    peer.flush()
    var turns = 0
    while not server.stopped() and turns < 500:
        _ = server.poll(2)
        turns += 1
    assert_true(server.stopped())
    server.stop()
    assert_equal(server.server().plugin.log[1], "stop")
    peer.close()


def test_stop_closes_what_is_still_open() raises:
    var server = _start(DefaultHooks())
    var peer = Peer(server.port())
    peer.open(server)
    _ = peer.send(server, INIT)
    # The client never answers the close frame.
    server.stop(50)
    assert_equal(server.server().plugin.log[1], "stop")
    peer.close()


def test_run_until_the_drain_ends() raises:
    var server = _start(DefaultHooks())
    server.begin_shutdown()
    server.run()
    assert_equal(server.server().plugin.log[1], "stop")


def test_listen_signals_failure() raises:
    var server = _start(DefaultHooks())
    server.loop.http1.sys.faults = Faults(SysCall.SIGNALFD, 24, 0, 1)
    with assert_raises():
        server.listen_signals()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
