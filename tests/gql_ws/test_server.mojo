# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.server`: the handshake, messages, the closing
handshake both ways, HTTP/1.1 on the same port, and back pressure, with
raw loopback clients in this process.

Ported from tungstenite 0.30.0 `tests/handshake.rs`,
`tests/connection_reset.rs` (`test_server_close`, `test_close_rx`,
`test_close_tx`) and `tests/write.rs`, on the event loop of this
package.
"""

from _net import connect, drain, send_text, text_of
from _server_util import KEY, Echo, Held, Peer, Plain, config
from _wsutil import close_frame, frames, raw, text_frame
from gql_http.socket import Sys
from gql_ws.frame import CloseCode, OpCode
from gql_ws.handshake import client_request
from gql_ws.protocol import Message, MessageKind
from gql_ws.server import Server, Sockets, UpgradeRequired, listen
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_echo() raises:
    var c = config()
    c.path = "/graphql"
    var server = listen(Echo(), Plain(), c)
    var peer = Peer(server.port)
    peer.upgrade(server)
    assert_equal(server.handler.opened, 1)
    peer.send_ws_text("hello")
    peer.ws.send_binary("bin".as_bytes())
    peer.flush_ws()
    peer.pump(server)
    var got = peer.messages()
    assert_equal(len(got), 2)
    assert_equal(got[0].text(), "hello")
    assert_true(got[1].kind == MessageKind.BINARY)
    # The client closes: the server answers and closes the socket.
    peer.ws.close(CloseCode.NORMAL, "done")
    peer.flush_ws()
    peer.pump(server)
    assert_true(peer.closed)
    var answer = peer.messages()
    assert_true(answer[0].kind == MessageKind.CLOSE)
    assert_equal(Int(answer[0].code.value), 1000)
    assert_equal(server.handler.closed, 1)
    assert_equal(server.handler.code, 1000)
    assert_equal(server.handler.reason, "done")
    assert_equal(server.open_connections, 0)
    assert_true(server.handler.ticks > 0)
    peer.close()


def test_server_closes() raises:
    # tungstenite `test_server_close`: the server sends a close, the client
    # answers, and the server closes the socket.
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    peer.send_ws_text("close")
    peer.pump(server)
    var got = peer.messages()
    assert_true(got[0].kind == MessageKind.CLOSE)
    assert_equal(got[0].text(), "bye")
    assert_false(peer.closed)
    var stale = server.handler.last
    assert_false(server.sockets.is_open(stale))
    peer.flush_ws()
    peer.pump(server)
    assert_true(peer.closed)
    assert_equal(server.handler.code, 1000)
    # The id is not open any more.
    assert_false(server.sockets.send_text(stale, "x"))
    assert_false(server.sockets.send_binary(stale, "x".as_bytes()))
    assert_false(server.sockets.ping(stale, "x".as_bytes()))
    assert_false(server.sockets.close(stale, CloseCode.NORMAL))
    assert_equal(server.sockets.protocol(stale), "")
    assert_equal(server.sockets.path(stale), "")
    assert_equal(server.sockets.pending(stale), 0)
    assert_false(server.sockets.is_open(-1))
    assert_false(server.sockets.is_open(1 << 40))
    peer.close()


def test_handler_errors() raises:
    # An error in a handler closes the connection with 1011.
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    peer.send_ws_text("boom")
    peer.pump(server)
    var got = peer.messages()
    assert_equal(Int(got[0].code.value), 1011)
    peer.close()
    var handler = Echo()
    handler.fail_open = True
    var other = listen(handler^, Plain(), config())
    var second = Peer(other.port)
    second.upgrade(other)
    var closing = second.messages()
    assert_equal(Int(closing[0].code.value), 1011)
    second.close()


def test_who_and_protocols() raises:
    var c = config()
    c.protocols = ["graphql-transport-ws"]
    var server = listen(Echo(), Plain(), c)
    var peer = Peer(server.port)
    peer.upgrade(server, "/any/path", ["chat", "graphql-transport-ws"])
    peer.send_ws_text("who")
    peer.pump(server)
    var got = peer.messages()
    assert_equal(got[0].text(), "graphql-transport-ws /any/path")
    peer.send_ws_text("ping")
    peer.pump(server)
    var ping = peer.messages()
    assert_true(ping[0].kind == MessageKind.PING)
    assert_true(server.sockets.is_open(server.handler.last))
    peer.close()


def test_frames_with_the_request() raises:
    # The first frame comes in the same packet as the request.
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    var data = client_request("x", "/", KEY, [])
    data.extend(text_frame("early"))
    peer.send(data)
    peer.pump(server)
    var text = peer.text()
    assert_true(text.startswith("HTTP/1.1 101"))
    var end = text.find("\r\n\r\n")
    peer.data = List[UInt8](Span(peer.data)[end + 4 :])
    var got = peer.messages()
    assert_equal(got[0].text(), "early")
    peer.close()


def test_handshake_in_parts() raises:
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    var data = client_request("x", "/", KEY, [])
    peer.send(Span(data)[:10])
    peer.pump(server, 3)
    assert_equal(len(peer.data), 0)
    peer.send(Span(data)[10:])
    peer.pump(server)
    assert_true(peer.text().startswith("HTTP/1.1 101"))
    peer.close()


def test_http_on_the_same_port() raises:
    var c = config()
    c.path = "/graphql"
    var server = listen(Echo(), Plain(), c)
    var peer = Peer(server.port)
    peer.send("GET /health HTTP/1.1\r\nHost: x\r\n\r\n".as_bytes())
    peer.pump(server)
    assert_true(peer.text().startswith("HTTP/1.1 200"), peer.text())
    assert_true(peer.text().endswith("http /health"))
    peer.close()
    # An Upgrade on another path goes to HTTP/1.1 too.
    var other = Peer(server.port)
    other.send(client_request("x", "/elsewhere", KEY, []))
    other.pump(server)
    assert_true(other.text().startswith("HTTP/1.1 200"))
    other.close()
    # A malformed request goes to HTTP/1.1, which answers 400.
    var bad = Peer(server.port)
    bad.send("GET / HTTP/1.1\r\n\r\n".as_bytes())
    bad.pump(server)
    assert_true(bad.text().startswith("HTTP/1.1 400"))
    bad.close()


def test_a_held_http_response() raises:
    # The loop polls a held HTTP/1.1 response on each turn, between the
    # events of the WebSocket connections.
    var server = listen(Echo(), Held(), config())
    var peer = Peer(server.port)
    peer.send("GET /stream HTTP/1.1\r\nHost: x\r\n\r\n".as_bytes())
    peer.pump(server, 30)
    assert_true(peer.text().startswith("HTTP/1.1 200"), peer.text())
    assert_true(
        peer.text().endswith("\r\n\r\n1\r\na\r\n1\r\nb\r\n0\r\n\r\n"),
        peer.text(),
    )
    assert_equal(server.http1.streams(), 0)
    peer.close()


def test_upgrade_required() raises:
    var server = listen(Echo(), UpgradeRequired(), config())
    var peer = Peer(server.port)
    peer.send(
        "POST /graphql HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\n\r\n"
        .as_bytes()
    )
    peer.pump(server)
    assert_true(peer.text().startswith("HTTP/1.1 426"), peer.text())
    assert_true("Upgrade: websocket\r\n" in peer.text())
    peer.close()


def test_bad_handshake() raises:
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.send(
        "GET / HTTP/1.1\r\nHost: x\r\nConnection: Upgrade\r\nUpgrade:"
        " websocket\r\nSec-WebSocket-Version: 8\r\nSec-WebSocket-Key: "
        "dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n".as_bytes()
    )
    peer.pump(server)
    assert_true(peer.text().startswith("HTTP/1.1 426"))
    assert_true(peer.closed)
    assert_equal(server.handler.opened, 0)
    assert_equal(server.open_connections, 0)
    peer.close()


def test_protocol_error_from_client() raises:
    # An unmasked frame fails the connection with 1002, and the handler
    # gets 1006: no close frame came.
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    peer.send(text_frame("plain", True, False))
    peer.pump(server)
    assert_true(peer.closed)
    var got = peer.messages()
    assert_equal(Int(got[0].code.value), 1002)
    assert_equal(server.handler.code, 1006)
    peer.close()


def test_client_drops() raises:
    # tungstenite `test_close_rx`: the peer goes away without a close.
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    peer.close()
    var turn = 0
    while turn < 50 and server.handler.closed == 0:
        _ = server.poll(5)
        turn += 1
    assert_equal(server.handler.closed, 1)
    assert_equal(server.handler.code, 1006)
    # A handshake that is dropped too.
    var half = Peer(server.port)
    half.send("GET / HT".as_bytes())
    half.pump(server, 3)
    half.close()
    turn = 0
    while turn < 50 and server.open_connections > 0:
        _ = server.poll(5)
        turn += 1
    assert_equal(server.open_connections, 0)


def test_back_pressure() raises:
    # A client that does not read: the output waits for EPOLLOUT, and the
    # sends over the write limit fail.
    var c = config()
    c.ws.max_write_buffer_size = 8 << 20
    var server = listen(Echo(), Plain(), c)
    var peer = Peer(server.port)
    peer.upgrade(server)
    peer.send_ws_text("flood")
    var turn = 0
    while turn < 20:
        _ = server.poll(1)
        turn += 1
    assert_true(server.handler.full > 0)
    assert_true(server.sockets.pending(server.handler.last) > 0)
    # Now the client reads it all.
    var total = 0
    turn = 0
    while turn < 400 and server.sockets.pending(server.handler.last) > 0:
        _ = server.poll(1)
        _ = drain(peer.sys, peer.fd, peer.data)
        total += len(peer.data)
        peer.data.clear()
        turn += 1
    assert_equal(server.sockets.pending(server.handler.last), 0)
    assert_true(total >= (64 - server.handler.full) << 20)
    peer.close()


def test_shutdown() raises:
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    var idle = Peer(server.port)
    idle.send("GET".as_bytes())
    peer.pump(server, 3)
    server.begin_shutdown()
    server.begin_shutdown()
    peer.pump(server)
    var got = peer.messages()
    assert_equal(Int(got[0].code.value), 1001)
    peer.flush_ws()
    var turn = 0
    while turn < 100 and not server.stopped():
        _ = server.poll(5)
        turn += 1
    assert_true(server.stopped())
    server.run()
    peer.close()
    idle.close()


def test_timeouts() raises:
    # A handshake that does not come, and a close that gets no reply, end
    # at their deadlines.
    var c = config()
    c.http.idle_timeout_ms = 20
    c.close_timeout_ms = 20
    var server = listen(Echo(), Plain(), c)
    var quiet = Peer(server.port)
    var peer = Peer(server.port)
    peer.upgrade(server)
    peer.send_ws_text("close")
    var turn = 0
    while turn < 300 and server.open_connections > 0:
        _ = server.poll(10)
        turn += 1
    assert_equal(server.open_connections, 0)
    assert_equal(server.handler.code, 1006)
    quiet.close()
    peer.close()


def test_close_all() raises:
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    var waiting = Peer(server.port)
    waiting.send("GET".as_bytes())
    peer.pump(server, 3)
    server.close()
    assert_equal(server.handler.closed, 1)
    server.close()
    peer.close()
    waiting.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
