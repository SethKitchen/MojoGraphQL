# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the subgraph WebSocket pool.

Follows Hive Router `1a29df9`
`bin/router/src/executor/executors/websocket_pool.rs`: operations to one
URL share a connection when `reuse_connections` is set, an idle connection
closes after `pool_idle_timeout`, an `error` message ends its operation,
and a closed connection ends each of its operations with
`WS_CONNECTION_CLOSED`. The subgraph is the `reviews` server of the
end-to-end suites, in a child process.
"""

from _e2e import start_subgraphs
from gql_http.socket import Faults, Sys, SysCall
from gql_router_stream.subgraph_ws import (
    CONNECTION_CLOSED,
    WsPool,
    websocket_url,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime REVIEWS = '{"query":"subscription { reviewAdded { id } }"}'
"""Eleven `next` messages, then `complete`."""


def _url(port: Int) -> String:
    return "ws://127.0.0.1:" + String(port) + "/reviews"


def _wait(mut pool: WsPool, operation: Int, mut events: List[String]) -> Bool:
    """Pump until the operation ends; return whether it ended."""
    var sys = Sys()
    for _ in range(400):
        pool.pump()
        var got = List[List[UInt8]]()
        var done = pool.take(operation, got)
        for item in got:
            events.append(String(unsafe_from_utf8=Span(item)))
        if done:
            return True
        _ = sys.poll(-1, 0, 5)
    return False


def test_websocket_url() raises:
    assert_equal(websocket_url("http://h:1/graphql", ""), "ws://h:1/graphql")
    assert_equal(websocket_url("https://h/graphql", "/ws"), "wss://h/ws")
    assert_equal(websocket_url("http://h:1", "/ws"), "ws://h:1/ws")
    assert_equal(websocket_url("h:1/graphql", ""), "ws://h:1/graphql")


def test_shared_connection_and_idle_timeout() raises:
    var subgraphs = start_subgraphs()
    var url = _url(subgraphs.port)
    var pool = WsPool(True, 1000)
    var first = pool.subscribe(url, REVIEWS)
    var second = pool.subscribe(url, REVIEWS)
    assert_equal(pool.connection_count(), 1)
    assert_equal(len(pool.fds()), 1)
    var events = List[String]()
    assert_true(_wait(pool, first, events))
    assert_true(_wait(pool, second, events))
    assert_equal(len(events), 22)
    assert_equal(events[0], '{"data":{"reviewAdded":{"id":"1"}}}')
    # An error message is the event of its errors, and ends the operation.
    var bad = pool.subscribe(url, '{"query":"subscription { nope }"}')
    var errors = List[String]()
    assert_true(_wait(pool, bad, errors))
    assert_equal(len(errors), 1)
    assert_true(errors[0].startswith('{"errors":['))
    pool.release(first, 100)
    pool.release(first, 100)
    pool.release(second, 100)
    pool.release(bad, 100)
    pool.sweep(500)
    assert_equal(pool.connection_count(), 1)
    pool.sweep(1100)
    assert_equal(pool.connection_count(), 0)
    assert_equal(len(pool.fds()), 0)
    pool.pump()
    # A new connection takes the closed one's place, and an operation the
    # released one's.
    var again = pool.subscribe(url, REVIEWS)
    assert_equal(again, first)
    assert_equal(pool.connection_count(), 1)
    var sys = Sys()
    _ = sys.poll(-1, 0, 50)
    # Released while it runs: `complete` goes out, and the client drops the
    # messages that were on the way.
    pool.release(again)
    pool.pump()
    pool.sweep()
    subgraphs.stop()


def test_a_connection_per_operation() raises:
    var subgraphs = start_subgraphs()
    var url = _url(subgraphs.port)
    var pool = WsPool(False)
    var first = pool.subscribe(url, REVIEWS)
    var second = pool.subscribe(url, REVIEWS)
    assert_equal(pool.connection_count(), 2)
    # A `complete` that fails closes its own connection; the operation on
    # the other one runs on.
    pool._connections[1].client.socket.sys.faults = Faults(
        SysCall.SEND, 32, 0, 1
    )
    pool.release(second)
    assert_equal(pool.connection_count(), 1)
    var events = List[String]()
    assert_true(_wait(pool, first, events))
    assert_equal(len(events), 11)
    pool.release(first)
    assert_equal(pool.connection_count(), 0)
    subgraphs.stop()


def test_an_ended_operation_before_a_running_one() raises:
    var subgraphs = start_subgraphs()
    var url = _url(subgraphs.port)
    var pool = WsPool(True)
    var ended = pool.subscribe(url, REVIEWS)
    var running = pool.subscribe(url, REVIEWS)
    # `ended` keeps its slot before `running`, on the same connection.
    pool.release(ended)
    var events = List[String]()
    assert_true(_wait(pool, running, events))
    assert_equal(len(events), 11)
    pool.release(running)
    subgraphs.stop()


def test_messages_route_by_connection_and_id() raises:
    var subgraphs = start_subgraphs()
    var a = _url(subgraphs.port)
    var b = _url(subgraphs.port) + "?b=1"
    var pool = WsPool(True)
    # Two URLs are two connections.
    var x0 = pool.subscribe(a, REVIEWS)
    var x1 = pool.subscribe(a, REVIEWS)
    var y = pool.subscribe(b, REVIEWS)
    assert_equal(pool.connection_count(), 2)
    var events = List[String]()
    assert_true(_wait(pool, x0, events))
    assert_true(_wait(pool, x1, events))
    assert_true(_wait(pool, y, events))
    assert_equal(len(events), 33)
    # `s` is sent before `r`, but has the later slot: the messages of `s`
    # pass `r`, which runs on the same connection.
    pool.release(x1)
    var s = pool.subscribe(a, REVIEWS)
    assert_equal(s, x1)
    pool.release(x0)
    var r = pool.subscribe(a, REVIEWS)
    assert_equal(r, x0)
    # `c` runs on the other connection, in the slot before `s` and `r`.
    pool.release(y)
    var sys = Sys()
    _ = sys.poll(-1, 0, 50)
    var both = List[String]()
    assert_true(_wait(pool, s, both))
    assert_true(_wait(pool, r, both))
    assert_equal(len(both), 22)
    pool.release(s)
    pool.release(r)
    var c = pool.subscribe(b, REVIEWS)
    var d = pool.subscribe(a, REVIEWS)
    assert_equal(c, 0)
    assert_equal(d, 1)
    var more = List[String]()
    assert_true(_wait(pool, d, more))
    # A `complete` that fails closes the connection of `d` only.
    var e = pool.subscribe(a, REVIEWS)
    pool._connections[0].client.socket.sys.faults = Faults(
        SysCall.SEND, 32, 0, 1
    )
    pool.release(e)
    assert_equal(pool.connection_count(), 1)
    pool.sweep()
    assert_true(_wait(pool, c, more))
    pool.release(c)
    pool.release(d)
    subgraphs.stop()


def test_a_closed_connection_ends_its_operations() raises:
    var subgraphs = start_subgraphs()
    var url = _url(subgraphs.port)
    var pool = WsPool(True)
    var operation = pool.subscribe(url, '{"query":"subscription { x }"}')
    var running = pool.subscribe(url, REVIEWS)
    var errors = List[String]()
    assert_true(_wait(pool, operation, errors))
    var events = List[String]()
    assert_true(_wait(pool, running, events))
    assert_equal(len(events), 11)
    # The subgraph goes away; the next read closes the connection.
    subgraphs.stop()
    var sys = Sys()
    for _ in range(100):
        pool.pump()
        if pool.connection_count() == 0:
            break
        _ = sys.poll(-1, 0, 5)
    assert_equal(pool.connection_count(), 0)
    pool.release(running)
    pool.release(operation)


def test_send_failures_close_the_connection() raises:
    var subgraphs = start_subgraphs()
    var url = _url(subgraphs.port)
    var pool = WsPool(True)
    var running = pool.subscribe(url, REVIEWS)
    pool._connections[0].client.socket.sys.faults = Faults(
        SysCall.SEND, 32, 0, 1
    )
    var failed = False
    try:
        _ = pool.subscribe(url, REVIEWS)
    except:
        failed = True
    assert_true(failed)
    assert_equal(pool.connection_count(), 0)
    var events = List[String]()
    assert_true(_wait(pool, running, events))
    assert_equal(events[len(events) - 1], CONNECTION_CLOSED)
    pool.release(running)
    # A `complete` that fails closes the connection too.
    var other = pool.subscribe(url, REVIEWS)
    pool._connections[0].client.socket.sys.faults = Faults(
        SysCall.SEND, 32, 0, 1
    )
    pool.release(other)
    assert_equal(pool.connection_count(), 0)
    subgraphs.stop()


def test_a_connection_that_cannot_open_is_an_error() raises:
    var pool = WsPool()
    var failed = False
    try:
        _ = pool.subscribe("ws://127.0.0.1:1/reviews", REVIEWS)
    except:
        failed = True
    assert_true(failed)
    assert_false(pool.connection_count() > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
