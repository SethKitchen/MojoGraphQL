# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.transport_server`, on a `gql_ws.server` loop in this
process with a raw client.

Ported from graphql-ws 6.4.1 `tests/server.test.ts` (the `Connect`,
`Ping/Pong`, `Subscribe` and `Disconnect/close` sections) and
`tests/use.test.ts` (the `ws` cases of the close codes), by test name.
"""

from _gql_util import Scripted, gql_config, gql_server, joined, texts
from _server_util import Peer, Plain, config
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_http.server import Handler
from gql_stream.poll import Event
from gql_ws.frame import CloseCode
from gql_ws.server import Server, WsHandler, listen
from gql_ws.transport_server import (
    OperationKind,
    TransportOptions,
    TransportServer,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime INIT = '{"type":"connection_init"}'
comptime ACK = '{"type":"connection_ack"}'


def open_peer[
    W: WsHandler, H: Handler
](mut server: Server[W, H], init: Bool = True) raises -> Peer:
    var peer = Peer(server.port)
    peer.upgrade(server, "/graphql", [GRAPHQL_TRANSPORT_WS_PROTOCOL])
    if init:
        peer.send_ws_text(INIT)
        peer.pump(server)
        var got = texts(peer)
        if len(got) != 1 or got[0] != ACK:
            raise Error("no ack: " + joined(got))
    return peer^


def subscribe(id: StringSlice, query: StringSlice) -> String:
    return (
        '{"id":"'
        + String(id)
        + '","type":"subscribe","payload":{"query":"'
        + String(query)
        + '"}}'
    )


def exchange[
    W: WsHandler, H: Handler
](mut server: Server[W, H], mut peer: Peer, text: StringSlice) raises -> String:
    peer.send_ws_text(text)
    peer.pump(server)
    return joined(texts(peer))


def test_subprotocol_not_acceptable() raises:
    # use.test.ts: "should close the socket with 4406 without the protocol".
    var server = gql_server()
    var peer = Peer(server.port)
    peer.upgrade(server, "/graphql", [])
    # A message after the refusal is not read.
    peer.send_ws_text(INIT)
    peer.pump(server)
    assert_equal(joined(texts(peer)), "close 4406 Subprotocol not acceptable")
    peer.flush_ws()
    peer.pump(server)
    assert_equal(server.handler.executor.connects, 0)
    assert_equal(server.handler.executor.closes, 1)
    peer.close()


def test_connect() raises:
    # "should acknowledge connection if not implemented, returning `true`
    # or nothing" and "should send optional payload with connection ack".
    var server = gql_server()
    var peer = open_peer(server)
    assert_equal(server.handler.executor.connects, 1)
    var other = open_peer(server, False)
    assert_equal(
        exchange(
            server,
            other,
            '{"type":"connection_init","payload":{"ack":{"x":1}}}',
        ),
        '{"type":"connection_ack","payload":{"x":1}}',
    )
    assert_equal(server.handler.executor.params, '{"ack":{"x":1}}')
    peer.close()
    other.close()


def test_refuse_connection() raises:
    # "should refuse connection and close socket if returning `false`".
    var server = gql_server()
    var peer = open_peer(server, False)
    assert_equal(
        exchange(
            server, peer, '{"type":"connection_init","payload":{"forbid":true}}'
        ),
        "close 4403 Forbidden",
    )
    peer.close()


def test_connect_hook_fails() raises:
    var server = gql_server()
    var peer = open_peer(server, False)
    assert_equal(
        exchange(
            server, peer, '{"type":"connection_init","payload":{"boom":1}}'
        ),
        "close 4500 connect failed",
    )
    peer.close()


def test_init_timeout() raises:
    # "should close the socket after the `connectionInitWaitTimeout` has
    # passed without having received a `ConnectionInit` message".
    var options = TransportOptions()
    options.connection_init_wait_timeout_ms = 10
    var server = gql_server(options)
    var peer = open_peer(server, False)
    var turn = 0
    while turn < 50 and len(peer.data) == 0:
        _ = server.poll(5)
        peer.pump(server, 1)
        turn += 1
    assert_equal(
        joined(texts(peer)), "close 4408 Connection initialisation timeout"
    )
    peer.close()
    # A socket that closes before its deadline stops the wait.
    var early = open_peer(server, False)
    early.ws.close()
    early.flush_ws()
    early.pump(server)
    assert_equal(server.handler.wait_ms(), -1)
    early.close()
    # Without a timeout, nothing closes.
    var never = TransportOptions()
    never.connection_init_wait_timeout_ms = 0
    var calm = gql_server(never)
    var quiet = open_peer(calm, False)
    quiet.pump(calm, 20)
    assert_equal(len(texts(quiet)), 0)
    assert_equal(exchange(calm, quiet, INIT), ACK)
    quiet.close()


def test_too_many_inits() raises:
    # "should close the socket if more than one `ConnectionInit` message is
    # received at any given time".
    var server = gql_server()
    var peer = open_peer(server)
    assert_equal(
        exchange(server, peer, INIT),
        "close 4429 Too many initialisation requests",
    )
    peer.close()


def test_ping_pong() raises:
    # "should respond with a pong to a ping", "should return ping's payload
    # through the pong", "should not react to a pong", and before the ack.
    var server = gql_server()
    var peer = open_peer(server, False)
    assert_equal(exchange(server, peer, '{"type":"ping"}'), '{"type":"pong"}')
    assert_equal(
        exchange(server, peer, '{"type":"ping","payload":{"some":"data"}}'),
        '{"type":"pong","payload":{"some":"data"}}',
    )
    assert_equal(exchange(server, peer, '{"type":"pong"}'), "")
    peer.close()


def test_subscribe_before_ack() raises:
    # "should close the socket on request if connection is not
    # acknowledged".
    var server = gql_server()
    var peer = open_peer(server, False)
    assert_equal(
        exchange(server, peer, subscribe("1", "result")),
        "close 4401 Unauthorized",
    )
    peer.close()


def test_query_next_complete() raises:
    # 'should execute the query of `string` type, "next" the result and
    # then "complete"'.
    var server = gql_server()
    var peer = open_peer(server)
    assert_equal(
        exchange(server, peer, subscribe("1", "result")),
        (
            '{"id":"1","type":"next","payload":{"data":{"hello":"world"}}}\n'
            '{"id":"1","type":"complete"}'
        ),
    )
    # The id can be used again after it completed.
    assert_equal(
        exchange(server, peer, subscribe("1", "errors")),
        (
            '{"id":"1","type":"error","payload":[{"message":"Cannot query'
            ' field"}]}'
        ),
    )
    peer.close()


def test_stream_next_complete() raises:
    # 'should execute the live query, "next" multiple results and then
    # "complete"'.
    var server = gql_server()
    var peer = open_peer(server)
    var got = exchange(server, peer, subscribe("s", "list:3"))
    assert_equal(
        got,
        (
            '{"id":"s","type":"next","payload":{"data":{"n":0}}}\n'
            '{"id":"s","type":"next","payload":{"data":{"n":1}}}\n'
            '{"id":"s","type":"next","payload":{"data":{"n":2}}}\n'
            '{"id":"s","type":"complete"}'
        ),
    )
    peer.close()


def test_stream_error() raises:
    # "should not close connection if a subscription iterable throws" and
    # "should not send complete after error when subscription iterable
    # throws".
    var server = gql_server()
    var peer = open_peer(server)
    assert_equal(
        exchange(server, peer, subscribe("f", "fail")),
        (
            '{"id":"f","type":"next","payload":{"data":{"n":0}}}\n'
            '{"id":"f","type":"error","payload":[{"message":"kaboom"}]}'
        ),
    )
    assert_equal(
        exchange(server, peer, subscribe("f", "result")).count("complete"), 1
    )
    peer.close()


def test_pubsub_subscription() raises:
    # 'should execute the subscription and "next" the published payload',
    # and "should stop dispatching messages after completing a
    # subscription". Many operations share the socket.
    var server = gql_server()
    var peer = open_peer(server)
    _ = exchange(server, peer, subscribe("a", "pubsub"))
    _ = exchange(server, peer, subscribe("b", "pubsub"))
    server.handler.executor.pubsub.publish("T", Event.parse('{"data":{"v":1}}'))
    peer.pump(server)
    assert_equal(
        joined(texts(peer)),
        (
            '{"id":"a","type":"next","payload":{"data":{"v":1}}}\n'
            '{"id":"b","type":"next","payload":{"data":{"v":1}}}'
        ),
    )
    # "should not send a complete message back if the client sent it".
    assert_equal(exchange(server, peer, '{"id":"a","type":"complete"}'), "")
    server.handler.executor.pubsub.publish("T", Event.parse('{"data":{"v":2}}'))
    peer.pump(server)
    assert_equal(
        joined(texts(peer)),
        '{"id":"b","type":"next","payload":{"data":{"v":2}}}',
    )
    # A complete for an unknown id does nothing.
    assert_equal(exchange(server, peer, '{"id":"zz","type":"complete"}'), "")
    peer.close()


def test_duplicate_operation() raises:
    # "should close the socket on duplicate operation requests".
    var server = gql_server()
    var peer = open_peer(server)
    _ = exchange(server, peer, subscribe("not-unique", "pubsub"))
    assert_equal(
        exchange(server, peer, subscribe("not-unique", "pubsub")),
        "close 4409 Subscriber for not-unique already exists",
    )
    peer.close()


def test_invalid_messages() raises:
    # use.test.ts: "should close socket with error on malformed request"
    # and "should close socket with error thrown from the callback".
    var server = gql_server()
    var a = open_peer(server)
    assert_equal(
        exchange(server, a, '{"type":"connection_init","payload":"yes"}'),
        "close 4400 Invalid message received",
    )
    a.close()
    var b = open_peer(server)
    assert_equal(
        exchange(server, b, '{"type":"connection_ack"}'),
        "close 4500 Unexpected message of type connection_ack received",
    )
    b.close()
    var c = open_peer(server)
    assert_equal(exchange(server, c, subscribe("1", "boom")), "close 4500 boom")
    c.close()
    var d = open_peer(server)
    assert_equal(
        exchange(server, d, subscribe("1", "long")),
        "close 4500 Internal server error",
    )
    d.close()
    var options = TransportOptions()
    options.is_prod = True
    var prod = gql_server(options)
    var e = open_peer(prod)
    assert_equal(
        exchange(prod, e, subscribe("1", "boom")),
        "close 4500 Internal server error",
    )
    e.close()


def test_close_disposes_subscriptions() raises:
    # "should dispose of subscriptions on close" and "should report close
    # code and reason to disconnect and close callback".
    var server = gql_server()
    var peer = open_peer(server)
    _ = exchange(server, peer, subscribe("a", "pubsub"))
    _ = exchange(server, peer, subscribe("b", "pubsub"))
    assert_equal(server.handler.loop.stream_count(), 2)
    peer.ws.close(CloseCode(4321), "Byebye")
    peer.flush_ws()
    peer.pump(server)
    assert_equal(server.handler.loop.stream_count(), 0)
    assert_equal(server.handler.executor.closes, 1)
    assert_equal(server.handler.executor.code, 4321)
    assert_equal(server.handler.executor.reason, "Byebye")
    peer.close()


def test_events_after_close_started() raises:
    # A stream event for a socket that is closing is dropped.
    var server = gql_server()
    var peer = open_peer(server)
    _ = exchange(server, peer, subscribe("a", "pubsub"))
    assert_equal(
        exchange(server, peer, "not json"),
        "close 4400 Invalid message received",
    )
    server.handler.executor.pubsub.publish("T", Event.parse('{"data":{}}'))
    peer.pump(server)
    assert_equal(len(texts(peer)), 0)
    peer.close()


def test_write_buffer_full() raises:
    # A slow client: a `next` without room closes the socket with 1013.
    var c = gql_config()
    c.ws.max_write_buffer_size = 1 << 16
    var server = gql_server(TransportOptions(), c)
    var peer = open_peer(server)
    peer.send_ws_text(subscribe("big", "huge"))
    peer.pump(server)
    var got = texts(peer)
    assert_true(got[len(got) - 1].startswith("close 1013"))
    peer.close()


def test_kinds() raises:
    assert_true(OperationKind.STREAM.is_valid())
    assert_false(OperationKind(3).is_valid())
    assert_equal(String(OperationKind.ERRORS), "1")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
