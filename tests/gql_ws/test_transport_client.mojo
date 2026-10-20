# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.transport_client`, against a `TransportServer` and a
scripted peer in child processes.

Ported from graphql-ws 6.4.1 `tests/client.test.ts`: "should use the
provided connection params", "should close with 4004 if the first
message is not connection_ack", "should close with 4504 on ack timeout",
"should respond with a pong to a ping", "should not send the complete
message if the subscription ended", and the `subscribe` cases, by name.
"""

from _fork import Child, script_in_child, serve_in_child
from _gql_util import Scripted, gql_config
from _wsutil import raw
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import OpCode
from gql_ws.graphql_ws import MessageType
from gql_ws.transport_client import (
    ClientEvent,
    TransportClient,
    generate_id,
    subscribe_payload,
)
from gql_ws.transport_server import TransportServer
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def url(port: Int) -> String:
    return "ws://127.0.0.1:" + String(port) + "/graphql"


def server_frames(*texts: String) -> String:
    var out = List[UInt8]()
    for text in texts:
        out.extend(raw(OpCode.TEXT, text.as_bytes(), True, False))
    return String(unsafe_from_utf8=out^)


def connect_error(
    port: Int, params: StringSlice = "", timeout: Int = 0
) -> WsError:
    try:
        var client = TransportClient.connect(url(port), params, timeout)
        _ = client^
    except e:
        return e^
    return WsError.of(WsErrorKind(255), "connected")


def test_operations() raises:
    var child = serve_in_child(TransportServer(Scripted()), gql_config())
    var client = TransportClient.connect(url(child.port), '{"ack":{"hi":1}}')
    assert_equal(client.ack_payload, '{"hi":1}')
    var event = ClientEvent()
    # A query: one next, then complete.
    var id = client.subscribe(subscribe_payload("result"))
    assert_true(client.next(event, 2000))
    assert_true(event.type == MessageType.NEXT)
    assert_equal(event.id, id)
    assert_equal(event.payload, '{"data":{"hello":"world"}}')
    assert_true(client.next(event, 2000))
    assert_true(event.type == MessageType.COMPLETE)
    assert_equal(len(client.active), 0)
    # Errors.
    _ = client.subscribe(subscribe_payload("errors", '{"a":1}', "Op", "{}"))
    assert_true(client.next(event, 2000))
    assert_true(event.type == MessageType.ERROR)
    assert_equal(event.payload, '[{"message":"Cannot query field"}]')
    # Two streams on one socket.
    var a = client.subscribe(subscribe_payload("list:2"))
    var b = client.subscribe(subscribe_payload("list:2"))
    var nexts = 0
    var completes = 0
    while completes < 2:
        assert_true(client.next(event, 2000))
        if event.type == MessageType.NEXT:
            nexts += 1
        else:
            completes += 1
    assert_equal(nexts, 4)
    assert_true(a != b)
    # A protocol ping gets the pong of the server, which is dropped.
    client.ping()
    assert_false(client.next(event, 50))
    # A complete of an ended or unknown id sends nothing.
    client.complete(a)
    client.close()
    var kind = WsErrorKind(255)
    try:
        _ = client.next(event, 2000)
    except e:
        kind = e.kind
    assert_true(kind == WsErrorKind.CLOSED)
    child.stop()


def test_complete_stops_a_stream() raises:
    var child = serve_in_child(TransportServer(Scripted()), gql_config())
    var client = TransportClient.connect(url(child.port))
    var event = ClientEvent()
    var id = client.subscribe(subscribe_payload("pubsub"))
    client.complete(id)
    assert_equal(len(client.active), 0)
    assert_false(client.next(event, 50))
    child.stop()


def test_forbidden() raises:
    var child = serve_in_child(TransportServer(Scripted()), gql_config())
    var error = connect_error(child.port, '{"forbid":true}')
    assert_true(error.kind == WsErrorKind.CLOSED)
    assert_equal(Int(error.close_code), 4403)
    assert_equal(error.message, "Forbidden")
    child.stop()


def test_first_message_not_ack() raises:
    var child = script_in_child(
        server_frames('{"id":"1","type":"complete"}'), 500, True
    )
    var error = connect_error(child.port)
    assert_equal(Int(error.close_code), 4004)
    assert_equal(error.message, "First message cannot be of type complete")
    child.stop()


def test_bad_response() raises:
    var child = script_in_child(server_frames('{"type":"nuxt"}'), 500, True)
    var error = connect_error(child.port)
    assert_equal(Int(error.close_code), 4004)
    assert_equal(error.message, "Invalid message 'type' property \"nuxt\"")
    child.stop()


def test_ack_timeout() raises:
    var child = script_in_child("", 500, True)
    var error = connect_error(child.port, "", 20)
    assert_equal(Int(error.close_code), 4504)
    assert_equal(error.message, "Connection acknowledgement timeout")
    child.stop()


def test_ping_pong_and_drops() raises:
    # The client answers a ping, drops a pong, a second ack, a binary
    # frame of a known type, and messages of unknown ids.
    var frames = server_frames(
        '{"type":"ping","payload":{"x":1}}',
        '{"type":"pong"}',
        '{"type":"connection_ack","payload":{"v":2}}',
        '{"type":"connection_ack"}',
        '{"id":"other","type":"next","payload":{}}',
    )
    var extra = raw(OpCode.PING, "p".as_bytes(), True, False)
    extra.extend(raw(OpCode.BINARY, '{"type":"pong"}'.as_bytes(), True, False))
    frames += String(unsafe_from_utf8=extra)
    var child = script_in_child(frames, 500, True)
    var client = TransportClient.connect(url(child.port))
    assert_equal(client.ack_payload, '{"v":2}')
    var event = ClientEvent()
    assert_false(client.next(event, 50))
    child.stop()


def test_generate_id() raises:
    var id = generate_id()
    assert_equal(id.byte_length(), 36)
    assert_equal(String(id[byte=14]), "4")
    var variant = String(id[byte=19])
    assert_true(variant in "89ab", variant)
    assert_equal(String(id[byte=8]), "-")
    assert_true(generate_id() != id)


def test_subscribe_payload() raises:
    assert_equal(subscribe_payload("{ a }"), '{"query":"{ a }"}')
    assert_equal(
        subscribe_payload('q "x"', '{"v":1}', "Op", '{"e":2}'),
        (
            '{"query":"q \\"x\\"","variables":{"v":1},"operationName":"Op",'
            '"extensions":{"e":2}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
