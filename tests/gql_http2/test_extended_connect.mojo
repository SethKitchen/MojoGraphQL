# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the extended `CONNECT` of RFC 8441 in `gql_http2.connection`:
`SETTINGS_ENABLE_CONNECT_PROTOCOL`, `:protocol`, and the tunnel streams.

Ported from h2 v0.4.20 `tests/h2-tests/tests/client_request.rs`
(`extended_connect_protocol_disabled_by_default`,
`extended_connect_protocol_enabled_during_handshake`,
`invalid_connect_protocol_enabled_setting` and `extended_connect_request`).
The server tests of `tests/h2-tests/tests/server.rs` are in
`test_connection.mojo`. The tunnel tests are new: h2 gives each `DATA` frame
to the application, and here a tunnel is the only stream that does so.
"""

from _frames import Pair, Peer, bytes, client, kinds, response, server
from gql_http2.connection import Config, Connection, EventKind, Role
from gql_http2.error import Reason
from gql_http2.frame import END_HEADERS, END_STREAM, FrameKind
from gql_http2.hpack import HeaderList
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime EOS = END_HEADERS | END_STREAM
"""The flags of a whole head that ends its stream."""


def _connect(
    authority: StringSlice = "bread",
    path: StringSlice = "/baguette",
    protocol: StringSlice = "the-bread-protocol",
) -> HeaderList:
    """The head of an extended `CONNECT`."""
    var fields = HeaderList()
    fields.add_text(":method", "CONNECT")
    fields.add_text(":scheme", "http")
    fields.add_text(":authority", authority)
    fields.add_text(":path", path)
    fields.add_text(":protocol", protocol)
    return fields^


def _enabled_client() raises -> Pair:
    """A client whose server sent `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`."""
    var conn = Connection(Role.CLIENT)
    conn.start()
    var peer = Peer()
    peer.settings([8], [1])
    peer.settings_ack()
    peer.send(conn)
    _ = peer.read(conn)
    return Pair(conn^, peer^)


def _enabled_server() raises -> Pair:
    """A server that allows the extended `CONNECT`."""
    var config = Config()
    config.enable_connect_protocol = True
    return server(config)


def _body(t: Pair, id: Int) -> String:
    """The content that a stream holds, as text."""
    return String(unsafe_from_utf8=Span(t.conn.streams[t.conn.find(id)].body))


def _take(mut t: Pair, id: Int):
    """Drop the content that a stream holds, as a driver does."""
    t.conn.streams[t.conn.find(id)].body.clear()


def test_extended_connect_protocol_disabled_by_default() raises:
    # client_request.rs extended_connect_protocol_disabled_by_default
    var t = client()
    assert_false(t.conn.is_extended_connect_protocol_enabled())
    var s = server()
    assert_false(s.conn.is_extended_connect_protocol_enabled())
    # A client never sends the setting, even when the config asks.
    var config = Config()
    config.enable_connect_protocol = True
    var c = Connection(Role.CLIENT, config)
    assert_false(c.local.enable_connect_protocol)


def test_extended_connect_protocol_enabled_during_handshake() raises:
    # client_request.rs extended_connect_protocol_enabled_during_handshake
    var t = _enabled_client()
    assert_true(t.conn.is_extended_connect_protocol_enabled())
    var s = _enabled_server()
    assert_true(s.conn.is_extended_connect_protocol_enabled())


def test_invalid_connect_protocol_enabled_setting() raises:
    # client_request.rs invalid_connect_protocol_enabled_setting
    var conn = Connection(Role.CLIENT)
    conn.start()
    var peer = Peer()
    peer.settings([8], [2])
    peer.send(conn)
    var frames = peer.read(conn)
    assert_true(conn.closed)
    assert_true(conn.error.value().reason == Reason.PROTOCOL_ERROR)
    var last = len(frames) - 1
    assert_true(frames[last].head.kind == FrameKind.GOAWAY)
    assert_true(frames[last].reason() == Reason.PROTOCOL_ERROR)


def test_extended_connect_request() raises:
    # client_request.rs extended_connect_request
    var t = _enabled_client()
    var id = t.conn.open_stream()
    t.conn.send_headers(id, _connect(), True)
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS")
    assert_equal(frames[0].field(":method"), "CONNECT")
    assert_equal(frames[0].field(":scheme"), "http")
    assert_equal(frames[0].field(":authority"), "bread")
    assert_equal(frames[0].field(":path"), "/baguette")
    assert_equal(frames[0].field(":protocol"), "the-bread-protocol")
    assert_true(frames[0].head.has(END_STREAM))
    t.peer.headers(id, response(200), EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)


def test_server_tunnel() raises:
    var t = _enabled_server()
    t.peer.headers(1, _connect("example.com", "/chat", "websocket"))
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.HEAD)
    assert_true(t.conn.streams[t.conn.find(1)].tunnel)
    t.conn.events.clear()
    t.conn.send_headers(1, response(200), False)
    t.peer.data(1, "abc")
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.DATA)
    assert_equal(_body(t, 1), "abc")
    _take(t, 1)
    t.conn.events.clear()
    # An empty frame is no event.
    t.peer.data(1, "")
    t.send()
    assert_equal(len(t.conn.events), 0)
    t.conn.send_data(1, bytes("xyz"), False)
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS DATA")
    assert_equal(frames[1].text(), "xyz")
    t.peer.data(1, "de", END_STREAM)
    t.send()
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)
    assert_equal(_body(t, 1), "de")
    t.conn.send_data(1, bytes("!"), True)
    frames = t.read()
    assert_true(frames[0].head.has(END_STREAM))
    assert_equal(t.conn.active_streams(), 0)


def test_server_tunnel_that_ends_at_once() raises:
    # A tunnel head with END_STREAM is a whole message.
    var t = _enabled_server()
    t.peer.headers(1, _connect(), EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)


def test_server_tunnel_over_limit() raises:
    # A tunnel was answered, so too much content resets it without a 413.
    var config = Config()
    config.enable_connect_protocol = True
    config.max_body_bytes = 4
    var t = server(config)
    t.peer.headers(1, _connect())
    t.send()
    t.conn.send_headers(1, response(200), False)
    _ = t.read()
    t.peer.data(1, "abcdef")
    t.send()
    var frames = t.read()
    assert_equal(kinds(frames), "RST_STREAM")
    assert_true(frames[0].reason() == Reason.CANCEL)


def test_client_tunnel() raises:
    var t = _enabled_client()
    var id = t.conn.open_stream()
    t.conn.send_headers(
        id, _connect("example.com", "/chat", "websocket"), False
    )
    assert_true(t.conn.streams[t.conn.find(id)].tunnel)
    _ = t.read()
    t.peer.headers(id, response(200))
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.HEAD)
    t.conn.events.clear()
    t.peer.data(id, "hello")
    t.send()
    assert_true(t.conn.events[0].kind == EventKind.DATA)
    assert_equal(_body(t, id), "hello")
    t.conn.events.clear()
    # A 2xx head with END_STREAM ends the tunnel: a whole message.
    var second = t.conn.open_stream()
    t.conn.send_headers(second, _connect(), False)
    t.peer.headers(second, response(200), EOS)
    t.send()
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)


def test_client_refused_tunnel() raises:
    # A response that is not 2xx is an ordinary, whole response.
    var t = _enabled_client()
    var id = t.conn.open_stream()
    t.conn.send_headers(id, _connect(), False)
    t.peer.headers(id, response(404))
    t.peer.data(id, "no")
    t.send()
    assert_equal(len(t.conn.events), 0)
    assert_false(t.conn.streams[t.conn.find(id)].tunnel)
    t.peer.data(id, "pe", END_STREAM)
    t.send()
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)
    assert_equal(_body(t, id), "nope")


def _get() -> HeaderList:
    """The head of a `GET` without content."""
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "http")
    fields.add_text(":authority", "a")
    fields.add_text(":path", "/")
    return fields^


def test_reset_after_whole_response() raises:
    # A reset with NO_ERROR after a whole response keeps the response
    # (RFC 9113 section 8.1), as a refused tunnel gets it.
    var t = _enabled_client()
    var id = t.conn.open_stream()
    t.conn.send_headers(id, _connect(), False)
    t.peer.headers(id, response(404))
    t.peer.data(id, "no", END_STREAM)
    t.peer.rst(id, Reason.NO_ERROR)
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)
    assert_equal(t.conn.streams[t.conn.find(id)].status, 404)
    assert_equal(_body(t, id), "no")
    assert_equal(t.conn.active_streams(), 0)
    # The same for a stream that both ends have ended.
    var get = t.conn.open_stream()
    t.conn.send_headers(get, _get(), True)
    t.peer.headers(get, response(200), EOS)
    t.peer.rst(get, Reason.NO_ERROR)
    t.send()
    assert_equal(len(t.conn.events), 2)
    assert_equal(t.conn.streams[t.conn.find(get)].status, 200)


def test_other_resets_drop_the_stream() raises:
    # Another code after a whole response, and NO_ERROR before one, drop
    # the stream.
    var t = _enabled_client()
    var get = t.conn.open_stream()
    t.conn.send_headers(get, _get(), True)
    t.peer.headers(get, response(200), EOS)
    t.peer.rst(get, Reason.CANCEL)
    t.send()
    assert_true(t.conn.events[1].kind == EventKind.RESET)
    assert_equal(t.conn.find(get), -1)
    var id = t.conn.open_stream()
    t.conn.send_headers(id, _connect(), False)
    t.peer.rst(id, Reason.NO_ERROR)
    t.send()
    assert_true(t.conn.events[2].kind == EventKind.RESET)
    assert_equal(t.conn.find(id), -1)


def test_client_plain_request_is_no_tunnel() raises:
    # Only the first head of a stream can open a tunnel.
    var t = _enabled_client()
    var id = t.conn.open_stream()
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "http")
    fields.add_text(":authority", "a")
    fields.add_text(":path", "/")
    t.conn.send_headers(id, fields, False)
    assert_false(t.conn.streams[t.conn.find(id)].tunnel)
    var trailers = HeaderList()
    trailers.add_text(":protocol", "x")
    t.conn.send_headers(id, trailers, True)
    assert_false(t.conn.streams[t.conn.find(id)].tunnel)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
