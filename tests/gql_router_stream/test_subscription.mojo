# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the stream hub and of one router subscription.

Follows the failure cases of Hive Router `1a29df9`
`executor/execution/plan.rs` and `executors/websocket_pool.rs`: a callback
subgraph, a WebSocket that cannot connect, a subgraph stream that breaks,
an event that is not JSON, and a client that goes away. The subgraphs run
in a child process; the router runs here.
"""

from std.memory import ArcPointer

from _e2e import start_subgraphs
from _supergraph import sdl
from gql_http.body import BodyPoll
from gql_http.server import open_listener
from gql_http.socket import POLLIN, Faults, IPv4Address, Sys, SysCall
from gql_json.value import NO_NODE, JsonDocument
from gql_router.exec_http import CannedTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router_stream.config import (
    SubscriptionsConfig,
    subscriptions_config_from_json,
)
from gql_router_stream.subgraph_http import HttpSubscription
from gql_router_stream.subscription import (
    RouterSubscription,
    StreamHub,
    event_poll,
    open_subscription,
)
from gql_stream.poll import PollState
from gql_stream.waker import Waker
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime REVIEWS = "subscription { reviewAdded { id } }"
comptime WS_NO_REUSE = (
    '{"subscriptions":{"enabled":true,"websocket":{"all":{}}},'
    + '"traffic_shaping":{"all":{"websocket":{"reuse_connections":false}}}}'
)


def _hub(
    base: String, config: String = '{"subscriptions":{"enabled":true}}'
) raises -> ArcPointer[StreamHub[CannedTransport]]:
    return ArcPointer(
        StreamHub(
            Router(RouterSchema(sdl(base)), CannedTransport()),
            subscriptions_config_from_json(config),
        )
    )


def _open(
    hub: ArcPointer[StreamHub[CannedTransport]],
) raises -> RouterSubscription[CannedTransport]:
    var prepared = hub[].router.prepare_request(
        REVIEWS, None, JsonDocument(), NO_NODE, False, True
    )
    return open_subscription(hub, prepared)


def _drain(
    hub: ArcPointer[StreamHub[CannedTransport]],
    mut subscription: RouterSubscription[CannedTransport],
) -> List[String]:
    """Read the responses until the end; at most two seconds."""
    var bodies = List[String]()
    var sys = Sys()
    for _ in range(400):
        hub[].pump()
        var out = List[UInt8]()
        var state = subscription.next_body(out)
        if state == BodyPoll.DONE:
            return bodies^
        if state == BodyPoll.READY:
            bodies.append(String(unsafe_from_utf8=Span(out)))
            continue
        _ = sys.poll(-1, 0, 5)
    bodies.append("did not end")
    return bodies^


def test_a_hub_without_an_epoll_is_an_error() raises:
    var sys = Sys()
    sys.faults = Faults(SysCall.EPOLL_CREATE, 24, 0, 1)
    var message = String("no error")
    try:
        _ = StreamHub(
            Router(RouterSchema(sdl("http://x")), CannedTransport()),
            SubscriptionsConfig(),
            sys^,
        )
    except error:
        message = String(error)
    assert_equal(message, "epoll_create failed: 24")


def test_the_url_of_a_subgraph() raises:
    var hub = _hub("http://x")
    assert_equal(hub[].url_of("reviews"), "http://x/reviews")
    assert_equal(hub[].url_of("nope"), "")


def test_a_callback_subgraph_fails_at_once() raises:
    var hub = _hub(
        "http://x",
        '{"subscriptions":{"enabled":true,"callback":{"public_url":'
        + '"http://x/callback","subgraphs":["reviews"]}}}',
    )
    var subscription = _open(hub)
    var bodies = _drain(hub, subscription)
    assert_equal(len(bodies), 1)
    assert_true("SUBGRAPH_HTTP_CALLBACK_NOT_SUPPORTED" in bodies[0], bodies[0])
    assert_equal(hub[].active, 0)


def test_a_websocket_that_cannot_connect_fails() raises:
    var hub = _hub(
        "http://127.0.0.1:1",
        '{"subscriptions":{"enabled":true,"websocket":{"all":{}}}}',
    )
    var subscription = _open(hub)
    var bodies = _drain(hub, subscription)
    assert_equal(len(bodies), 1)
    assert_true("SUBGRAPH_WEBSOCKET_CONNECT_FAILURE" in bodies[0], bodies[0])


def test_a_client_that_goes_away_closes_the_subgraph_stream() raises:
    var subgraphs = start_subgraphs()
    var hub = _hub("http://127.0.0.1:" + String(subgraphs.port), WS_NO_REUSE)
    var subscription = _open(hub)
    assert_true(subscription.ws_operation >= 0)
    assert_equal(len(hub[].watched), 1)
    # The connection is not shared: it closes with its operation, and the
    # hub stops watching it.
    subscription.close()
    assert_equal(len(hub[].watched), 0)
    assert_equal(hub[].active, 0)
    var out = List[UInt8]()
    assert_true(subscription.next_body(out) == BodyPoll.DONE)
    subscription.close()
    subgraphs.stop()


def test_an_event_that_is_not_json_fails() raises:
    var hub = _hub("http://x")
    var prepared = hub[].router.prepare_request(
        REVIEWS, None, JsonDocument(), NO_NODE, False, True
    )
    var subscription = RouterSubscription[CannedTransport](
        hub, prepared.slot, prepared.variables.copy(), "reviews"
    )
    subscription.queue.append(List[UInt8]("nope".as_bytes()))
    var bodies = _drain(hub, subscription)
    assert_equal(len(bodies), 1)
    assert_true("SUBREQUEST_MALFORMED_RESPONSE" in bodies[0], bodies[0])


def test_a_subgraph_stream_that_breaks_fails() raises:
    # A child answers one request: the head of an SSE stream, then a chunk
    # size that is not hexadecimal.
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 8, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        for _ in range(400):
            if sys.poll(listener.fd, POLLIN, 5) <= 0:
                continue
            var fd = sys.accept(listener.fd)
            if fd < 0:
                continue
            var buffer = List[UInt8](length=4096, fill=0)
            _ = sys.poll(fd, POLLIN, 1000)
            _ = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
            var reply = String(
                "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n"
                "Transfer-Encoding: chunked\r\n\r\nzz\r\n"
            )
            _ = sys.send(fd, reply.unsafe_ptr(), reply.byte_length())
            _ = sys.poll(-1, 0, 200)
            sys.close(fd)
            break
        sys.exit_now(0)
    sys.close(listener.fd)
    var hub = _hub("http://x")
    var prepared = hub[].router.prepare_request(
        REVIEWS, None, JsonDocument(), NO_NODE, False, True
    )
    var subscription = RouterSubscription[CannedTransport](
        hub, prepared.slot, prepared.variables.copy(), "reviews"
    )
    subscription.http = HttpSubscription.open(
        "http://127.0.0.1:" + String(listener.port) + "/reviews",
        List[UInt8]("{}".as_bytes()),
        2000,
    )
    var bodies = _drain(hub, subscription)
    _ = sys.wait(pid, True)
    assert_equal(len(bodies), 1)
    assert_true("Stream read error" in bodies[0], bodies[0])


def test_the_event_of_a_response() raises:
    var ready = event_poll(List[UInt8]('{"data":{}}'.as_bytes()))
    assert_true(ready.state == PollState.READY)
    var error = event_poll(List[UInt8]("{".as_bytes()))
    assert_true(error.state == PollState.ERROR)
    assert_false(error.message == "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
