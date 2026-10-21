# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http2.session`: WebSockets on the tunnels of one
HTTP/2 connection, with requests on the same connection, in memory.

There is no upstream suite. The cases follow the server cases of
`tests/gql_ws/test_server.mojo` (tungstenite 0.30.0 `tests/handshake.rs`
and `tests/connection_reset.rs`), on an HTTP/2 stream as RFC 8441
sections 4 to 6 tell.
"""

from _h2ws import Echo, Plain, Rig, client_ws
from gql_http2.connection import Config, Connection, EventKind, Role
from gql_http2.error import Reason
from gql_http2.hpack import HeaderList
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind, WsConfig
from gql_ws_http2.handshake import client_head
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _has(rig: Rig, id: Int, kind: EventKind) -> Bool:
    """Whether the client got an event of a kind on a stream."""
    var index = 0
    while index < len(rig.client.events):
        if (
            rig.client.events[index].stream_id == id
            and rig.client.events[index].kind == kind
        ):
            return True
        index += 1
    return False


def test_echo() raises:
    var rig = Rig()
    assert_true(rig.session.session.conn.local.enable_connect_protocol)
    assert_true(rig.client.is_extended_connect_protocol_enabled())
    var id = rig.open()
    assert_equal(rig.status(id), 200)
    assert_true(_has(rig, id, EventKind.HEAD))
    assert_equal(rig.echo.opened, 1)
    assert_equal(len(rig.session.tunnels), 1)
    var ws = client_ws()
    ws.send_text("hello")
    ws.send_text("who")
    rig.send(id, ws)
    var got = rig.texts(id, ws)
    assert_equal(len(got), 2)
    assert_equal(got[0], "hello")
    assert_equal(got[1], "graphql-transport-ws /graphql")
    assert_true(rig.session.owns(rig.session.tunnels[0].slot))
    assert_false(rig.session.owns(99))
    assert_false(rig.session.is_done())


def test_requests_on_the_same_connection() raises:
    var rig = Rig()
    var tunnel = rig.open()
    var id = rig.client.open_stream()
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "http")
    fields.add_text(":authority", "localhost")
    fields.add_text(":path", "/x")
    rig.client.send_headers(id, fields, True)
    rig.pump()
    assert_true(_has(rig, id, EventKind.MESSAGE))
    var slot = rig.client.find(id)
    assert_equal(
        String(unsafe_from_utf8=Span(rig.client.streams[slot].body)), "http /x"
    )
    assert_equal(rig.status(tunnel), 200)


def test_refusals() raises:
    var rig = Rig(path="/graphql")
    var other = rig.open("/other")
    assert_equal(rig.status(other), 404)
    assert_equal(rig.echo.opened, 0)
    var bad = rig.client.open_stream()
    var fields = client_head("http", "localhost", "/graphql", [])
    # Another :protocol is a 400.
    var head = HeaderList()
    var index = 0
    while index < fields.count():
        if fields.name_text(index) == ":protocol":
            head.add_text(":protocol", "the-bread-protocol")
        else:
            head.add(fields.name(index), fields.value(index))
        index += 1
    rig.client.send_headers(bad, head, False)
    rig.pump()
    assert_equal(rig.echo.opened, 0)
    assert_equal(len(rig.session.tunnels), 0)
    # The path of the session opens a WebSocket.
    var good = rig.open("/graphql")
    assert_equal(rig.status(good), 200)
    assert_equal(rig.echo.opened, 1)


def test_refusal_statuses() raises:
    # The status of a refusal comes before its reset.
    var rig = Rig(path="/graphql")
    var id = rig.client.open_stream()
    rig.client.send_headers(
        id, client_head("http", "localhost", "/other", []), False
    )
    rig.to_server()
    var out = rig.session.session.conn.out.copy()
    rig.to_client()
    assert_true(len(out) > 0)
    assert_true(_has(rig, id, EventKind.MESSAGE))
    assert_equal(rig.status(id), 404)


def test_tunnel_that_ends_at_once() raises:
    var rig = Rig()
    var id = rig.client.open_stream()
    rig.client.send_headers(
        id, client_head("http", "localhost", "/graphql", []), True
    )
    rig.pump()
    assert_equal(rig.echo.opened, 0)
    assert_true(_has(rig, id, EventKind.MESSAGE))


def test_client_closes() raises:
    var rig = Rig()
    var id = rig.open()
    var ws = client_ws()
    ws.close(CloseCode.NORMAL, "done")
    rig.send(id, ws)
    assert_equal(rig.echo.closed, 1)
    assert_equal(rig.echo.code, 1000)
    assert_equal(rig.echo.reason, "done")
    assert_equal(len(rig.session.tunnels), 0)
    # The server ended its side; the reply is on the stream.
    var got = rig.texts(id, ws)
    assert_equal(len(got), 0)
    assert_true(ws.should_close())
    # Late content of the ended tunnel is dropped.
    rig.client.send_data(id, "late".as_bytes(), False)
    rig.pump()
    assert_equal(rig.echo.closed, 1)
    rig.client.send_data(id, "last".as_bytes(), True)
    rig.pump()
    assert_equal(rig.echo.closed, 1)


def test_server_closes() raises:
    var rig = Rig()
    var id = rig.open()
    var ws = client_ws()
    ws.send_text("close")
    rig.send(id, ws)
    _ = rig.texts(id, ws)
    assert_equal(rig.echo.closed, 0)
    # The reply of the client ends the WebSocket.
    rig.send(id, ws)
    assert_equal(rig.echo.closed, 1)
    assert_equal(rig.echo.code, 1000)


def test_reset_and_end_of_stream() raises:
    var rig = Rig()
    var first = rig.open()
    rig.client.reset_stream(first, Reason.CANCEL)
    rig.pump()
    assert_equal(rig.echo.closed, 1)
    assert_equal(rig.echo.code, 1006)
    var second = rig.open()
    var ws = client_ws()
    ws.send_text("last")
    var data = List[UInt8]()
    data.extend(Span(unsafe_ptr=ws.output(), length=ws.pending()))
    ws.advance(ws.pending())
    rig.client.send_data(second, Span(data), True)
    rig.pump()
    assert_equal(rig.echo.closed, 2)
    assert_equal(rig.echo.code, 1006)


def test_handler_errors() raises:
    var rig = Rig()
    rig.echo.fail_open = True
    var id = rig.open()
    var ws = client_ws()
    var got = rig.texts(id, ws)
    assert_equal(len(got), 0)
    rig.echo.fail_open = False
    var second = rig.open()
    var other = client_ws()
    other.send_text("boom")
    rig.send(second, other)
    var message = Message()
    rig.take(second, other)
    assert_true(other.read(message))
    assert_true(message.kind == MessageKind.CLOSE)
    assert_equal(message.code.value, 1011)


def test_invalid_frame() raises:
    # An unmasked frame fails the WebSocket with 1002.
    var rig = Rig()
    var id = rig.open()
    var frame: List[UInt8] = [0x81, 0x02, 0x68, 0x69]
    rig.client.send_data(id, Span(frame), False)
    rig.pump()
    var ws = client_ws()
    var message = Message()
    rig.take(id, ws)
    assert_true(ws.read(message))
    assert_equal(message.code.value, 1002)
    assert_equal(rig.echo.closed, 1)


def test_back_pressure() raises:
    var config = WsConfig()
    config.max_write_buffer_size = 1 << 17
    var rig = Rig(ws=config)
    var id = rig.open()
    var ws = client_ws()
    ws.send_text("flood")
    rig.send(id, ws)
    assert_true(rig.echo.full > 0)
    var got = rig.texts(id, ws)
    assert_true(len(got) > 0 and len(got) < 64)


def test_small_window() raises:
    # A WebSocket waits while its stream has content for a window.
    var client = Config()
    client.initial_window_size = 1000
    var rig = Rig(client=client)
    var id = rig.open()
    var ws = client_ws()
    ws.send_text("x" * 3000)
    ws.send_text("y")
    var data = List[UInt8]()
    data.extend(Span(unsafe_ptr=ws.output(), length=ws.pending()))
    rig.client.send_data(id, Span(data[:2000]), False)
    rig.to_server()
    # The client does not read, so its window stays closed.
    rig.client.send_data(id, Span(data[2000:]), False)
    rig.to_server()
    ws.advance(ws.pending())
    ws.send_text("z")
    data.clear()
    data.extend(Span(unsafe_ptr=ws.output(), length=ws.pending()))
    rig.client.send_data(id, Span(data), False)
    rig.to_server()
    assert_true(rig.session.session.conn.pending_output() > 0)
    var slot = rig.session.tunnels[0].slot
    assert_true(rig.sockets.conns[slot].ws.pending() > 0)


def test_connection_error() raises:
    var rig = Rig()
    _ = rig.open()
    _ = rig.open()
    var garbage: List[UInt8] = [0, 0, 4, 99, 0, 0, 0, 0, 0, 1, 2, 3, 4]
    garbage[3] = 4  # A SETTINGS frame of 4 bytes is a FRAME_SIZE_ERROR.
    rig.session.receive(rig.plain, rig.echo, rig.sockets, Span(garbage))
    assert_true(rig.session.session.conn.closed)
    assert_equal(rig.echo.closed, 2)
    assert_equal(len(rig.session.tunnels), 0)
    assert_true(rig.session.is_done())
    # The connection cannot send: the output is dropped.
    rig.session.flush(rig.echo, rig.sockets)


def test_ping() raises:
    # A ping gets a pong, and the handler sees no message.
    var rig = Rig()
    var id = rig.open()
    var ws = client_ws()
    ws.ping("hi".as_bytes())
    rig.send(id, ws)
    rig.take(id, ws)
    var message = Message()
    assert_true(ws.read(message))
    assert_true(message.kind == MessageKind.PONG)
    assert_equal(len(rig.session.tunnels), 1)


def test_head_and_reset_together() raises:
    # A tunnel that the client resets before the server reads it opens no
    # WebSocket.
    var rig = Rig()
    var id = rig.client.open_stream()
    rig.client.send_headers(
        id, client_head("http", "localhost", "/graphql", []), False
    )
    rig.client.reset_stream(id, Reason.CANCEL)
    rig.pump()
    assert_equal(rig.echo.opened, 0)
    assert_equal(len(rig.session.tunnels), 0)


def test_connection_error_after_head() raises:
    # The connection fails in the read that opens a WebSocket: nothing
    # can be sent, and the WebSocket ends.
    var rig = Rig()
    rig.echo.fail_open = True
    var id = rig.client.open_stream()
    rig.client.send_headers(
        id, client_head("http", "localhost", "/graphql", []), False
    )
    var data = rig.client.out.copy()
    rig.client.out.clear()
    var garbage: List[UInt8] = [0, 0, 4, 4, 0, 0, 0, 0, 0, 1, 2, 3, 4]
    data.extend(Span(garbage))
    rig.session.receive(rig.plain, rig.echo, rig.sockets, Span(data))
    assert_true(rig.session.session.conn.closed)
    assert_equal(rig.echo.opened, 1)
    assert_equal(rig.echo.closed, 1)
    assert_equal(len(rig.session.tunnels), 0)


def test_binary() raises:
    var rig = Rig()
    var id = rig.open()
    var ws = client_ws()
    var data: List[UInt8] = [1, 2, 3]
    ws.send_binary(Span(data))
    rig.send(id, ws)
    rig.take(id, ws)
    var message = Message()
    assert_true(ws.read(message))
    assert_true(message.kind == MessageKind.BINARY)
    assert_equal(len(message.data), 3)


def test_close_and_connection_error() raises:
    # A close and a connection error in one read: the WebSocket ends, and
    # its stream cannot send the end.
    var rig = Rig()
    var id = rig.open()
    var ws = client_ws()
    ws.close(CloseCode.NORMAL, "done")
    var frame = List[UInt8]()
    frame.extend(Span(unsafe_ptr=ws.output(), length=ws.pending()))
    rig.client.send_data(id, Span(frame), False)
    var data = rig.client.out.copy()
    rig.client.out.clear()
    var garbage: List[UInt8] = [0, 0, 4, 4, 0, 0, 0, 0, 0, 1, 2, 3, 4]
    data.extend(Span(garbage))
    rig.session.receive(rig.plain, rig.echo, rig.sockets, Span(data))
    assert_true(rig.session.session.conn.closed)
    assert_equal(rig.echo.closed, 1)
    assert_equal(rig.echo.code, 1000)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
