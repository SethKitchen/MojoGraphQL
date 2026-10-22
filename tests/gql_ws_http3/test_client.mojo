# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http3.client` over real QUIC on loopback: echo, the
closing handshake both ways, `graphql-transport-ws`, refusals, servers
that fail the tunnel, and failed streams. There is no upstream suite; the
cases follow tests/gql_ws_http2/test_client.mojo and RFC 9220 section 3."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _wsh3 import (
    h3_client,
    start_silent_server,
    start_stub_server,
    start_ws_server,
    stop,
)
from gql_http3.quic import QuicCall, QuicFaults
from gql_ws.client import ClientConfig
from gql_ws.error import WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind
from gql_ws_http3.client import H3WebSocket, connect_h3, connect_transport_h3

comptime GTW = "graphql-transport-ws"


def url(port: Int, path: StaticString = "/ws") -> String:
    return "wss://localhost:" + String(port) + path


def short(ms: Int = 300) -> ClientConfig:
    var c = ClientConfig()
    c.connect_timeout_ms = ms
    c.write_timeout_ms = ms
    return c^


def closed_kind(mut socket: H3WebSocket) -> WsErrorKind:
    """Read until an error; return its kind."""
    var message = Message()
    var turns = 0
    while turns < 10:
        try:
            _ = socket.read(message, 2000)
        except e:
            return e.kind
        turns += 1
    return WsErrorKind.TIMEOUT


def connect_kind(
    port: Int, path: StaticString = "/ws", ms: Int = 300
) raises -> WsErrorKind:
    var c = h3_client()
    try:
        var socket = connect_h3(c^, url(port, path), [GTW], short(ms))
        _ = socket.protocol
    except e:
        return e.kind
    return WsErrorKind.IO


def test_echo_and_server_close() raises:
    var server = start_ws_server()
    var socket = connect_h3(h3_client(), url(server[1], "/ws?a=1"), [GTW])
    assert_equal(socket.protocol, GTW)
    socket.send_text("who")
    var message = Message()
    assert_true(socket.read(message, 2000))
    assert_equal(String(message.text()), GTW + " /ws?a=1")
    var bytes: List[UInt8] = [7, 8]
    socket.send_binary(Span(bytes))
    assert_true(socket.read(message, 2000))
    assert_equal(message.kind, MessageKind.BINARY)
    socket.ping(Span(bytes))
    assert_true(socket.read(message, 2000))
    assert_equal(message.kind, MessageKind.PONG)
    assert_false(socket.read(message, 0))
    socket.send_text("close")
    assert_equal(closed_kind(socket), WsErrorKind.CLOSED)
    stop(server[0])


def test_client_close_and_transport() raises:
    var server = start_ws_server()
    var socket = connect_h3(h3_client(), url(server[1]), [GTW])
    socket.close(CloseCode.NORMAL, "bye")
    assert_equal(closed_kind(socket), WsErrorKind.CLOSED)
    # graphql-transport-ws: the Echo handler acks `connection_init`.
    var client = connect_transport_h3(h3_client(), url(server[1]), "", 2000)
    assert_equal(client.socket.protocol, GTW)
    client.close()
    stop(server[0])


def test_server_goes_away() raises:
    """The server ends the QUIC connection without a closing handshake."""
    var server = start_ws_server()
    var socket = connect_h3(h3_client(), url(server[1]), [GTW])
    socket.send_text("stop")
    var kind = closed_kind(socket)
    assert_true(kind == WsErrorKind.PROTOCOL or kind == WsErrorKind.IO)
    stop(server[0])


def test_refusals() raises:
    var server = start_ws_server("/graphql")
    var raised = False
    var c = h3_client()
    try:
        _ = connect_h3(c^, url(server[1]), [GTW])
    except e:
        raised = True
        assert_equal(e.kind, WsErrorKind.HANDSHAKE)
        assert_equal(e.status, 404)
    assert_true(raised)
    stop(server[0])
    var bad = False
    var c2 = h3_client()
    try:
        _ = connect_h3(c2^, "nonsense")
    except e:
        bad = e.kind == WsErrorKind.HANDSHAKE
    assert_true(bad)
    var plain = False
    var c3 = h3_client()
    try:
        _ = connect_h3(c3^, "ws://localhost:1/")
    except e:
        plain = e.kind == WsErrorKind.HANDSHAKE
    assert_true(plain)


def test_default_port() raises:
    """Nothing answers on UDP 443: the QUIC handshake fails."""
    var failed = False
    var c = h3_client()
    try:
        _ = connect_h3(c^, "wss://127.0.0.1/", [], short(200))
    except e:
        failed = e.kind != WsErrorKind.HANDSHAKE
    assert_true(failed)


def test_servers_that_fail() raises:
    var never = start_stub_server(0)
    assert_equal(connect_kind(never[1]), WsErrorKind.TIMEOUT)
    stop(never[0])
    var reset = start_stub_server(1)
    assert_equal(connect_kind(reset[1], ms=2000), WsErrorKind.HANDSHAKE)
    stop(reset[0])
    var disabled = start_stub_server(2)
    assert_equal(connect_kind(disabled[1], ms=2000), WsErrorKind.HANDSHAKE)
    stop(disabled[0])
    var data = start_stub_server(3)
    assert_equal(connect_kind(data[1], ms=2000), WsErrorKind.PROTOCOL)
    stop(data[0])
    var silent = start_silent_server()
    assert_equal(connect_kind(silent[1]), WsErrorKind.TIMEOUT)
    stop(silent[0])


def test_failed_streams() raises:
    var server = start_ws_server()
    var socket = connect_h3(h3_client(), url(server[1]), [GTW])
    socket.client.quic.faults = QuicFaults(QuicCall.WRITE, 0, 1)
    var kind = WsErrorKind.CLOSED
    try:
        socket.send_text("lost")
    except e:
        kind = e.kind
    assert_equal(kind, WsErrorKind.IO)
    socket.client.quic.faults = QuicFaults()
    socket.tunnel.out.clear()
    # A connection that has closed.
    socket.client.close_stream(socket.stream)
    socket.stream.ssl = 0
    socket.client.close()
    var message = Message()
    kind = WsErrorKind.CLOSED
    try:
        _ = socket.read(message, 0)
    except e:
        kind = e.kind
    assert_equal(kind, WsErrorKind.IO)
    stop(server[0])


def test_masked_frame_of_a_server() raises:
    """A server must not mask: the client fails the WebSocket, and sends
    its close frame first."""
    var server = start_stub_server(4)
    var socket = connect_h3(h3_client(), url(server[1]))
    assert_equal(closed_kind(socket), WsErrorKind.PROTOCOL)
    stop(server[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
