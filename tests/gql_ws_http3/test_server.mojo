# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http3.server` over real QUIC on loopback: the
handshake, echo, the closing handshake, a FIN or a reset of the peer,
refusals, handler failures, back pressure and the turns. There is no
upstream suite; the cases follow tests/gql_ws_http2/test_server.mojo and
RFC 9220 sections 3 and 4."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _wsh3 import Rig, raw_head
from gql_http3.error import H3ErrorCode
from gql_http3.frame import write_data_frame
from gql_http3.quic import ReadState
from gql_ws.error import WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind, Role
from gql_ws_http3.tunnel import H3Tunnel


def tunnel(mut rig: Rig, stream: Int) raises -> H3Tunnel:
    """Open a WebSocket on a stream, and check the answer."""
    var t = H3Tunnel(Role.CLIENT, rig.quic.stream_id(stream))
    rig.head(stream, t)
    assert_equal(rig.wait_head(stream, t), ReadState.WAIT)
    t.verify(["graphql-transport-ws"])
    return t^


def say(mut rig: Rig, stream: Int, mut t: H3Tunnel, text: StaticString) raises:
    t.ws.send_text(text)
    rig.flush(stream, t)


def answer(mut rig: Rig, stream: Int, mut t: H3Tunnel) raises -> String:
    var message = Message()
    assert_true(rig.next(stream, t, message))
    return String(message.text())


def refused_status(mut rig: Rig, stream: Int, mut t: H3Tunnel) raises -> Int:
    _ = rig.wait_head(stream, t)
    var status = 0
    try:
        t.verify()
    except e:
        assert_equal(e.kind, WsErrorKind.HANDSHAKE)
        status = e.status
    return status


def test_echo_and_server_close() raises:
    var rig = Rig()
    var stream = rig.open()
    var t = tunnel(rig, stream)
    assert_equal(t.protocol, "graphql-transport-ws")
    assert_equal(rig.server.handler.opened, 1)
    say(rig, stream, t, "hello")
    assert_equal(answer(rig, stream, t), "hello")
    say(rig, stream, t, "who")
    assert_equal(answer(rig, stream, t), "graphql-transport-ws /ws")
    var bytes: List[UInt8] = [1, 2, 3]
    t.ws.send_binary(Span(bytes))
    rig.flush(stream, t)
    var message = Message()
    assert_true(rig.next(stream, t, message))
    assert_equal(message.kind, MessageKind.BINARY)
    # The server closes; the client answers, and the server ends the stream.
    say(rig, stream, t, "close")
    assert_true(rig.next(stream, t, message))
    assert_equal(message.kind, MessageKind.CLOSE)
    rig.flush(stream, t)
    assert_equal(rig.until_end(stream, t), ReadState.END)
    rig.pump(3)
    assert_equal(rig.server.handler.closed, 1)
    assert_equal(len(rig.server.tunnels), 0)


def test_client_close() raises:
    var rig = Rig()
    var stream = rig.open()
    var t = tunnel(rig, stream)
    t.ws.close(CloseCode.NORMAL, "done")
    rig.flush(stream, t)
    var message = Message()
    assert_true(rig.next(stream, t, message))
    assert_equal(message.kind, MessageKind.CLOSE)
    assert_equal(rig.until_end(stream, t), ReadState.END)
    rig.pump(3)
    assert_equal(rig.server.handler.code, 1000)
    assert_equal(rig.server.handler.reason, "done")


def test_peer_end_and_reset() raises:
    var rig = Rig()
    var a = rig.open()
    var ta = tunnel(rig, a)
    var b = rig.open()
    var tb = tunnel(rig, b)
    # The second tunnel is found past the first.
    say(rig, b, tb, "hi")
    assert_equal(answer(rig, b, tb), "hi")
    # A FIN without a closing handshake.
    rig.write(a, List[UInt8](), True)
    rig.pump(5)
    assert_equal(rig.server.handler.closed, 1)
    assert_equal(rig.server.handler.code, 1006)
    _ = ta.ws.peer_closed()
    # A reset.
    rig.quic.reset_stream(b, H3ErrorCode.H3_REQUEST_CANCELLED.value)
    rig.quic.handle_events(rig.ssl)
    rig.pump(5)
    assert_equal(rig.server.handler.closed, 2)
    assert_equal(len(rig.server.tunnels), 0)


def test_refusals() raises:
    var rig = Rig("/graphql")
    # Another path: 404, and the end of the stream.
    var stream = rig.open()
    var t = H3Tunnel(Role.CLIENT, rig.quic.stream_id(stream))
    rig.head(stream, t, "/ws")
    assert_equal(refused_status(rig, stream, t), 404)
    # The content and the end of a refused tunnel do not matter.
    var payload = List[UInt8]()
    write_data_frame(payload, "late".as_bytes())
    rig.write(stream, payload, True)
    assert_equal(rig.until_end(stream, t), ReadState.END)
    # Another protocol: 400; another version: 426.
    var chat = rig.open()
    var tc = H3Tunnel(Role.CLIENT, rig.quic.stream_id(chat))
    rig.write(chat, raw_head("CONNECT", "chat", "/graphql"), False)
    assert_equal(refused_status(rig, chat, tc), 400)
    var old = rig.open()
    var to = H3Tunnel(Role.CLIENT, rig.quic.stream_id(old))
    rig.write(old, raw_head("CONNECT", "websocket", "/graphql", "12"), False)
    assert_equal(refused_status(rig, old, to), 426)
    # No :path: a malformed extended CONNECT is reset.
    var bad = rig.open()
    var tb = H3Tunnel(Role.CLIENT, rig.quic.stream_id(bad))
    rig.write(bad, raw_head("CONNECT", "websocket", ""), False)
    assert_equal(rig.until_end(bad, tb), ReadState.RESET)
    assert_equal(rig.server.handler.opened, 0)
    # The path of the endpoint.
    var good = rig.open()
    var tg = H3Tunnel(Role.CLIENT, rig.quic.stream_id(good))
    rig.head(good, tg, "/graphql")
    assert_equal(rig.wait_head(good, tg), ReadState.WAIT)
    tg.verify(["graphql-transport-ws"])
    assert_equal(rig.server.handler.opened, 1)


def test_handler_failures() raises:
    var rig = Rig()
    rig.server.handler.fail_open = True
    var stream = rig.open()
    var t = tunnel(rig, stream)
    var message = Message()
    assert_true(rig.next(stream, t, message))
    assert_equal(message.kind, MessageKind.CLOSE)
    assert_equal(message.code, CloseCode.ERROR)
    rig.server.handler.fail_open = False
    var s = rig.open()
    var ts = tunnel(rig, s)
    say(rig, s, ts, "boom")
    assert_true(rig.next(s, ts, message))
    assert_equal(message.code, CloseCode.ERROR)
    # An unmasked frame of a client: the server closes with 1002.
    var g = rig.open()
    var tg = tunnel(rig, g)
    var junk = List[UInt8]()
    var noise: List[UInt8] = [0x81, 0x00]
    write_data_frame(junk, Span(noise))
    rig.write(g, junk, False)
    assert_true(rig.next(g, tg, message))
    assert_equal(message.kind, MessageKind.CLOSE)
    assert_equal(message.code, CloseCode.PROTOCOL)


def test_flood_waits_for_credit() raises:
    var rig = Rig()
    var stream = rig.open()
    var t = tunnel(rig, stream)
    say(rig, stream, t, "flood")
    # The client does not read: the stream runs out of credit.
    rig.pump(20)
    var sent = 64 - rig.server.handler.full
    assert_true(sent > 0)
    # An echo waits while the stream has content that waits for credit.
    say(rig, stream, t, "after")
    rig.pump(5)
    assert_true(rig.server.h3.pending(rig.server.tunnels[0].stream) > 0)
    var got = 0
    var message = Message()
    while got < sent and rig.next(stream, t, message):
        got += 1
    assert_equal(got, sent)
    assert_equal(answer(rig, stream, t), "after")


def test_tick_wait_and_close_all() raises:
    var rig = Rig()
    var stream = rig.open()
    var t = tunnel(rig, stream)
    rig.server.handler.tick = "tick"
    assert_equal(answer(rig, stream, t), "tick")
    rig.server.handler.wait = 0
    _ = rig.server.poll(-1)
    _ = rig.server.poll(5)
    rig.server.handler.wait = 3
    _ = rig.server.poll(0)
    _ = rig.server.poll(1)
    rig.server.handler.wait = -1
    var extra = rig.open()
    _ = tunnel(rig, extra)
    rig.server.close()
    assert_equal(rig.server.handler.closed, 2)
    assert_equal(rig.server.handler.code, 1006)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
