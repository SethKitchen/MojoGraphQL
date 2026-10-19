# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the server side of `gql_http2.connection`: the preface, the
settings exchange, request heads, `PING` and `GOAWAY`.

Ported from h2 v0.4.20 `tests/h2-tests/tests/server.rs`,
`tests/h2-tests/tests/codec_read.rs` and
`tests/h2-tests/tests/ping_pong.rs`. Each test names the upstream test
that it follows. The mock of h2-support becomes `_frames.Peer`.
"""

from _frames import (
    Pair,
    Peer,
    bytes,
    kinds,
    part,
    repeat,
    request,
    response,
    server,
)
from gql_http2.connection import (
    Config,
    Connection,
    EventKind,
    Role,
    check_regular_field,
    StreamState,
)
from gql_http2.error import H2ErrorKind, Reason
from gql_http2.frame import (
    ACK,
    END_HEADERS,
    END_STREAM,
    FrameKind,
    MAX_STREAM_ID,
    PADDED,
    PRIORITY_FLAG,
    PREFACE,
    SHUTDOWN_PING,
)
from gql_http2.hpack import HeaderList
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime EOS = END_HEADERS | END_STREAM
"""The flags of a whole head that ends its stream."""


def _goaway(mut t: Pair, reason: Reason) raises:
    """Check that the connection ended with a `GOAWAY` of a code."""
    var frames = t.read()
    assert_true(t.conn.closed)
    assert_true(len(frames) >= 1)
    var last = len(frames) - 1
    assert_true(frames[last].head.kind == FrameKind.GOAWAY, kinds(frames))
    assert_equal(String(frames[last].reason()), String(reason))
    assert_true(t.conn.error.value().reason == reason)


def _reset(mut t: Pair, id: Int, reason: Reason) raises:
    """Check that the connection reset a stream with a code, and lives."""
    var frames = t.read()
    if t.conn.closed:
        raise Error("the connection ended: " + String(t.conn.error.value()))
    assert_true(len(frames) >= 1)
    var last = len(frames) - 1
    assert_true(frames[last].head.kind == FrameKind.RST_STREAM, kinds(frames))
    assert_equal(frames[last].head.stream_id, id)
    assert_equal(String(frames[last].reason()), String(reason))


def _refused(fields: HeaderList, reason: Reason = Reason.PROTOCOL_ERROR) raises:
    """Check that a request head is refused with `RST_STREAM`."""
    var t = server()
    t.peer.headers(1, fields, EOS)
    t.send()
    _reset(t, 1, reason)
    _no_message(t)
    assert_equal(t.conn.active_streams(), 0)


def _no_message(t: Pair) raises:
    """Check that no request became a `MESSAGE` event."""
    var index = 0
    while index < len(t.conn.events):
        assert_true(t.conn.events[index].kind == EventKind.RESET)
        assert_true(t.conn.events[index].error.kind == H2ErrorKind.STREAM)
        index += 1


def test_serve_request() raises:
    # server.rs serve_request
    var t = server()
    t.peer.headers(1, request("GET", "/"), EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)
    assert_equal(t.conn.events[0].stream_id, 1)
    var slot = t.conn.find(1)
    assert_true(t.conn.streams[slot].state == StreamState.HALF_CLOSED_REMOTE)
    t.conn.send_headers(1, response(200), False)
    t.conn.send_data(1, StaticString("hello").as_bytes(), True)
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS DATA")
    assert_equal(frames[0].field(":status"), "200")
    assert_equal(frames[1].text(), "hello")
    assert_true(frames[1].head.has(END_STREAM))
    assert_equal(t.conn.active_streams(), 0)
    t.conn.release(1)
    assert_equal(t.conn.find(1), -1)
    # A released slot serves the next stream.
    t.peer.headers(3, request("POST", "/graphql"), END_HEADERS)
    t.peer.data(3, "body", END_STREAM)
    t.send()
    slot = t.conn.find(3)
    assert_equal(
        String(unsafe_from_utf8=Span(t.conn.streams[slot].body)), "body"
    )
    assert_equal(len(t.conn.streams), 1)


def test_handshake() raises:
    # A server sends SETTINGS and grows the connection window.
    var conn = Connection(Role.SERVER)
    conn.start()
    var peer = Peer()
    var frames = peer.read(conn)
    assert_equal(kinds(frames), "SETTINGS WINDOW_UPDATE")
    assert_equal(frames[1].u32(0), (1 << 20) - 65535)
    # A client opens with the preface; a window of the default size
    # needs no WINDOW_UPDATE.
    var config = Config()
    config.connection_window_size = 65535
    var client = Connection(Role.CLIENT, config)
    client.start()
    assert_equal(
        String(unsafe_from_utf8=Span(client.out)[:24]), String(PREFACE)
    )
    frames = peer.read(client)
    assert_equal(kinds(frames), "SETTINGS")
    assert_false(client.got_settings())


def test_read_preface_in_multiple_frames() raises:
    # server.rs read_preface_in_multiple_frames
    var conn = Connection(Role.SERVER)
    conn.start()
    var peer = Peer()
    _ = peer.read(conn)
    peer.preface()
    peer.settings()
    var index = 0
    while index < len(peer.out):
        conn.receive(Span(peer.out)[index : index + 1])
        index += 1
    peer.out.clear()
    assert_true(conn.got_settings())
    var frames = peer.read(conn)
    assert_equal(kinds(frames), "SETTINGS")
    assert_true(frames[0].head.has(ACK))


def test_invalid_preface() raises:
    var conn = Connection(Role.SERVER)
    conn.start()
    var peer = Peer()
    _ = peer.read(conn)
    conn.receive(StaticString("GET / HTTP/1.1\r\n").as_bytes())
    assert_true(conn.closed)
    var frames = peer.read(conn)
    assert_equal(kinds(frames), "GOAWAY")
    # A closed connection reads nothing more.
    conn.receive(StaticString(PREFACE).as_bytes())
    assert_equal(len(conn.out), 0)


def test_first_frame_must_be_settings() raises:
    var conn = Connection(Role.SERVER)
    conn.start()
    var peer = Peer()
    _ = peer.read(conn)
    peer.preface()
    peer.ping(1)
    peer.send(conn)
    var t = Pair(conn^, peer^)
    _goaway(t, Reason.PROTOCOL_ERROR)
    # A SETTINGS ACK is not the peer's settings either.
    var conn2 = Connection(Role.SERVER)
    var peer2 = Peer()
    peer2.preface()
    peer2.settings_ack()
    peer2.send(conn2)
    var t2 = Pair(conn2^, peer2^)
    _goaway(t2, Reason.PROTOCOL_ERROR)


def test_frame_too_big() raises:
    # codec_read.rs read_frame_too_big
    var t = server()
    var payload = List[UInt8](length=16385, fill=0)
    t.peer.raw(FrameKind.DATA, 0, 1, payload)
    t.send()
    _goaway(t, Reason.FRAME_SIZE_ERROR)


def test_unknown_frame_is_ignored() raises:
    var t = server()
    t.peer.raw(FrameKind(42), 0, 0, bytes("ignored"))
    t.peer.ping(7)
    t.send()
    var frames = t.read()
    assert_equal(kinds(frames), "PING")
    assert_false(t.conn.closed)


def test_recv_connection_header() raises:
    # server.rs recv_connection_header
    var names: List[String] = [
        "connection",
        "keep-alive",
        "proxy-connection",
        "transfer-encoding",
        "upgrade",
    ]
    for ref name in names:
        var fields = request()
        fields.add_text(name, "x")
        _refused(fields)
    var te = request()
    te.add_text("te", "gzip")
    _refused(te)
    # te: trailers is the one value that a request can have.
    var t = server()
    var ok = request()
    ok.add_text("te", "trailers")
    t.peer.headers(1, ok, EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)


def test_malformed_fields() raises:
    var upper = request()
    upper.add_text("X-Upper", "1")
    _refused(upper)
    var space = request()
    space.add_text("bad name", "1")
    _refused(space)
    # The HPACK decoder refuses an empty name, as h2 does: the block is
    # not valid, so the connection ends.
    var empty = request()
    empty.add_text("", "1")
    var e = server()
    e.peer.headers(1, empty, EOS)
    e.send()
    _goaway(e, Reason.COMPRESSION_ERROR)
    var failed = False
    try:
        _ = check_regular_field(1, List[UInt8](), bytes("1"), True)
    except error:
        failed = error.reason == Reason.PROTOCOL_ERROR
    assert_true(failed)
    var control = request()
    control.add_text("x", "a\x01b")
    _refused(control)
    var delete = request()
    delete.add_text("x", "a\x7fb")
    _refused(delete)
    # HTAB is allowed in a value.
    var t = server()
    var tab = request()
    tab.add_text("x", "a\tb")
    t.peer.headers(1, tab, EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)


def test_server_error_on_status_in_request() raises:
    # server.rs server_error_on_status_in_request
    var fields = request()
    var with_status = HeaderList()
    with_status.add_text(":status", "200")
    var index = 0
    while index < fields.count():
        with_status.add(fields.name(index), fields.value(index))
        index += 1
    _refused(with_status)


def test_pseudo_header_rules() raises:
    # A pseudo-header after a regular field.
    var late = request()
    late.add_text("x", "1")
    late.add_text(":path", "/again")
    _refused(late)
    # A repeated pseudo-header.
    var twice = request()
    twice.add_text(":method", "GET")
    _refused(twice)
    # Missing parts.
    var no_method = HeaderList()
    no_method.add_text(":scheme", "https")
    no_method.add_text(":path", "/")
    _refused(no_method)
    var no_path = HeaderList()
    no_path.add_text(":method", "GET")
    no_path.add_text(":scheme", "https")
    _refused(no_path)
    var no_scheme = HeaderList()
    no_scheme.add_text(":method", "GET")
    no_scheme.add_text(":path", "/")
    _refused(no_scheme)
    _refused(request("GET", ""))
    _refused(request("GET", "/a b"))
    _refused(request("GET", "/\x80"))
    _refused(request("G T", "/"))
    var unknown = request()
    var odd = HeaderList()
    odd.add_text(":method", "GET")
    odd.add_text(":scheme", "https")
    odd.add_text(":path", "/")
    odd.add_text(":foo", "bar")
    _refused(odd)
    _ = unknown^


def test_request_without_authority() raises:
    # server.rs request_without_authority
    var t = server()
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "http")
    fields.add_text(":path", "/just-a-path")
    t.peer.headers(1, fields, EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)
    # HEAD is kept for the response.
    t.peer.headers(3, request("HEAD", "/"), EOS)
    t.send()
    assert_true(t.conn.streams[t.conn.find(3)].head_request)


def test_recv_invalid_authority() raises:
    # server.rs recv_invalid_authority
    _refused(request("GET", "/", "not:a/good authority"))


def test_connect_requests() raises:
    # server.rs serve_connect
    var t = server()
    var connect = HeaderList()
    connect.add_text(":method", "CONNECT")
    connect.add_text(":authority", "example.com:443")
    t.peer.headers(1, connect, EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)
    var no_authority = HeaderList()
    no_authority.add_text(":method", "CONNECT")
    _refused(no_authority)
    var with_path = HeaderList()
    with_path.add_text(":method", "CONNECT")
    with_path.add_text(":authority", "example.com:443")
    with_path.add_text(":path", "/")
    _refused(with_path)
    # server.rs reject_pseudo_protocol_on_non_connect_request and
    # extended_connect_protocol_disabled_by_default
    var protocol = request()
    protocol.add_text(":protocol", "websocket")
    _refused(protocol)
    var extended = HeaderList()
    extended.add_text(":method", "CONNECT")
    extended.add_text(":scheme", "https")
    extended.add_text(":authority", "example.com")
    extended.add_text(":path", "/chat")
    extended.add_text(":protocol", "websocket")
    _refused(extended.copy())
    # server.rs extended_connect_protocol_enabled_during_handshake
    var config = Config()
    config.enable_connect_protocol = True
    var e = server(config)
    e.peer.headers(1, extended, EOS)
    e.send()
    assert_equal(len(e.conn.events), 1)
    # reject_extended_connect_request_without_scheme / _without_path
    var bare = HeaderList()
    bare.add_text(":method", "CONNECT")
    bare.add_text(":authority", "example.com")
    bare.add_text(":protocol", "websocket")
    e.peer.headers(3, bare, EOS)
    e.send()
    _reset(e, 3, Reason.PROTOCOL_ERROR)


def test_too_big_headers_sends_431() raises:
    # server.rs too_big_headers_sends_431
    var config = Config()
    config.max_header_list_size = 64
    var t = server(config)
    var fields = request()
    fields.add_text("some-header", "some-value-that-is-long-enough-to-pass")
    t.peer.headers(1, fields.copy(), EOS)
    t.send()
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS")
    assert_equal(frames[0].field(":status"), "431")
    assert_true(frames[0].head.has(END_STREAM))
    assert_equal(len(t.conn.events), 0)
    # server.rs too_big_headers_sends_reset_after_431_if_not_eos
    t.peer.headers(3, fields, END_HEADERS)
    t.send()
    frames = t.read()
    assert_equal(kinds(frames), "HEADERS RST_STREAM")
    assert_equal(String(frames[1].reason()), "PROTOCOL_ERROR")


def test_continuation_frames() raises:
    # codec_read.rs read_continuation_frames
    var t = server()
    var fields = request("POST", "/graphql")
    fields.add_text("x-a", "1")
    var block = t.peer.block(fields)
    t.peer.raw(FrameKind.HEADERS, END_STREAM, 1, part(block, 0, 3))
    t.peer.raw(FrameKind.CONTINUATION, 0, 1, part(block, 3, 6))
    t.peer.raw(FrameKind.CONTINUATION, END_HEADERS, 1, part(block, 6))
    t.send()
    assert_equal(len(t.conn.events), 1)
    var slot = t.conn.find(1)
    assert_equal(t.conn.streams[slot].headers.count(), 5)
    # Another frame in the middle of a block.
    t.peer.raw(FrameKind.HEADERS, END_STREAM, 3, part(block, 0, 3))
    t.peer.ping(1)
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)


def test_continuation_rules() raises:
    # A CONTINUATION of another stream.
    var t = server()
    var block = t.peer.block(request())
    t.peer.raw(FrameKind.HEADERS, 0, 1, part(block, 0, 2))
    t.peer.raw(FrameKind.CONTINUATION, END_HEADERS, 3, part(block, 2))
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)
    # A CONTINUATION without HEADERS.
    var u = server()
    u.peer.raw(FrameKind.CONTINUATION, END_HEADERS, 1, bytes("x"))
    u.send()
    _goaway(u, Reason.PROTOCOL_ERROR)


def test_too_many_continuation_frames_sends_goaway() raises:
    # server.rs too_many_continuation_frames_sends_goaway
    var t = server()
    var block = t.peer.block(request())
    t.peer.raw(FrameKind.HEADERS, 0, 1, part(block, 0, 1))
    var index = 0
    while index < 6:
        t.peer.raw(FrameKind.CONTINUATION, 0, 1)
        index += 1
    t.send()
    _goaway(t, Reason.ENHANCE_YOUR_CALM)


def test_abusive_headers_send_goaway() raises:
    # server.rs abusive_headers_send_goaway
    var config = Config()
    config.max_header_list_size = 100
    var t = server(config)
    var big = List[UInt8](length=401, fill=0x40)
    t.peer.raw(FrameKind.HEADERS, 0, 1, big)
    t.send()
    _goaway(t, Reason.ENHANCE_YOUR_CALM)


def test_compression_error() raises:
    var t = server()
    # An index that the tables do not have.
    t.peer.raw(FrameKind.HEADERS, EOS, 1, [UInt8(0xFF), UInt8(0x7F)])
    t.send()
    _goaway(t, Reason.COMPRESSION_ERROR)


def test_pending_accept_recv_illegal_content_length_data() raises:
    # server.rs pending_accept_recv_illegal_content_length_data
    var t = server()
    var fields = request("POST", "/")
    fields.add_text("content-length", "1")
    t.peer.headers(1, fields.copy(), END_HEADERS)
    t.peer.data(1, "abc", END_STREAM)
    t.send()
    _reset(t, 1, Reason.PROTOCOL_ERROR)
    # Less content than content-length.
    t.peer.headers(3, fields.copy(), END_HEADERS)
    t.peer.data(3, "", END_STREAM)
    t.send()
    _reset(t, 3, Reason.PROTOCOL_ERROR)
    # A head that ends the stream with a length.
    t.peer.headers(5, fields.copy(), EOS)
    t.send()
    _reset(t, 5, Reason.PROTOCOL_ERROR)
    # The exact length.
    t.conn.events.clear()
    t.peer.headers(7, fields.copy(), END_HEADERS)
    t.peer.data(7, "z", END_STREAM)
    t.send()
    assert_equal(len(t.conn.events), 1)
    # Invalid and conflicting values.
    var bad = request("POST", "/")
    bad.add_text("content-length", "1x")
    _refused(bad)
    var long = request("POST", "/")
    long.add_text("content-length", "1234567890123456")
    _refused(long)
    var none = request("POST", "/")
    none.add_text("content-length", "")
    _refused(none)
    var two = request("POST", "/")
    two.add_text("content-length", "1")
    two.add_text("content-length", "2")
    _refused(two)
    var same = request("POST", "/")
    same.add_text("content-length", "1")
    same.add_text("content-length", "1")
    var s = server()
    s.peer.headers(1, same, END_HEADERS)
    s.peer.data(1, "q", END_STREAM)
    s.send()
    assert_equal(len(s.conn.events), 1)


def test_trailers() raises:
    # trailers.rs recv_trailers_only and recv_trailers_without_eos
    var t = server()
    t.peer.headers(1, request("POST", "/"), END_HEADERS)
    t.peer.data(1, "abc")
    var trailers = HeaderList()
    trailers.add_text("grpc-status", "0")
    t.peer.headers(1, trailers.copy(), EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)
    t.peer.headers(3, request("POST", "/"), END_HEADERS)
    t.peer.headers(3, trailers.copy(), END_HEADERS)
    t.send()
    _reset(t, 3, Reason.PROTOCOL_ERROR)
    var pseudo = HeaderList()
    pseudo.add_text(":path", "/")
    t.peer.headers(5, request("POST", "/"), END_HEADERS)
    t.peer.headers(5, pseudo, EOS)
    t.send()
    _reset(t, 5, Reason.PROTOCOL_ERROR)
    var bad = HeaderList()
    bad.add_text("connection", "close")
    t.peer.headers(7, request("POST", "/"), END_HEADERS)
    t.peer.headers(7, bad, EOS)
    t.send()
    _reset(t, 7, Reason.PROTOCOL_ERROR)
    # Trailers that are too large.
    var config = Config()
    config.max_header_list_size = 200
    var small = server(config)
    small.peer.headers(1, request("POST", "/"), END_HEADERS)
    var big = HeaderList()
    big.add_text("x-big", repeat("x", 300))
    small.peer.headers(1, big, EOS)
    small.send()
    _reset(small, 1, Reason.PROTOCOL_ERROR)


def test_recv_single_ping() raises:
    # ping_pong.rs recv_single_ping and recv_multiple_pings
    var t = server()
    t.peer.ping(0x0102030405060708)
    t.peer.ping(42)
    t.send()
    var frames = t.read()
    assert_equal(kinds(frames), "PING PING")
    assert_true(frames[0].head.has(ACK))
    assert_equal(frames[0].u32(0), 0x01020304)
    assert_equal(frames[0].u32(4), 0x05060708)
    assert_equal(frames[1].u32(4), 42)
    # A PING ACK is counted.
    t.peer.ping(9, True)
    t.send()
    assert_equal(t.conn.pongs, 1)
    assert_equal(len(t.read()), 0)


def test_ping_rules() raises:
    var t = server()
    t.peer.raw(FrameKind.PING, 0, 1, part(List[UInt8](length=8, fill=0), 0))
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)
    var u = server()
    u.peer.raw(FrameKind.PING, 0, 0, bytes("short"))
    u.send()
    _goaway(u, Reason.FRAME_SIZE_ERROR)


def test_graceful_shutdown() raises:
    # server.rs graceful_shutdown
    var t = server()
    t.peer.headers(1, request("POST", "/"), END_HEADERS)
    t.send()
    t.conn.begin_shutdown()
    t.conn.begin_shutdown()
    var frames = t.read()
    assert_equal(kinds(frames), "GOAWAY PING")
    assert_equal(frames[0].u32(0), MAX_STREAM_ID)
    assert_equal(String(frames[0].reason()), "NO_ERROR")
    # A stream that opens before the PING comes back is still served.
    t.peer.headers(3, request(), EOS)
    t.peer.ping(SHUTDOWN_PING, True)
    t.send()
    frames = t.read()
    assert_equal(kinds(frames), "GOAWAY")
    assert_equal(frames[0].u32(0), 3)
    assert_true(t.conn.goaway_sent)
    assert_false(t.conn.is_done())
    # A stream above the last id is ignored.
    t.peer.headers(5, request(), EOS)
    t.send()
    assert_equal(t.conn.find(5), -1)
    assert_equal(t.conn.last_peer_stream, 5)
    t.conn.send_headers(3, response(), True)
    t.peer.data(1, "", END_STREAM)
    t.send()
    t.conn.send_headers(1, response(), True)
    _ = t.read()
    assert_true(t.conn.is_done())
    assert_false(t.conn.closed)


def test_abrupt_shutdown() raises:
    # server.rs abrupt_shutdown
    var t = server()
    t.peer.headers(1, request(), END_HEADERS)
    t.send()
    t.conn.abort(Reason.INTERNAL_ERROR)
    t.conn.abort(Reason.INTERNAL_ERROR)
    var frames = t.read()
    assert_equal(kinds(frames), "GOAWAY")
    assert_equal(frames[0].u32(0), 1)
    assert_equal(String(frames[0].reason()), "INTERNAL_ERROR")
    assert_true(t.conn.closed and t.conn.is_done())
    t.conn.begin_shutdown()
    t.conn.reset_stream(1, Reason.CANCEL)
    assert_equal(len(t.conn.out), 0)


def test_goaway_even_if_client_sent_goaway() raises:
    # server.rs goaway_even_if_client_sent_goaway and
    # client_goaway_does_not_kill_remote_initiated_streams
    var t = server()
    t.peer.headers(1, request(), EOS)
    t.peer.goaway(0, Reason.NO_ERROR)
    t.send()
    assert_true(t.conn.goaway_received)
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)
    assert_false(t.conn.is_done())
    t.conn.send_headers(1, response(), True)
    assert_true(t.conn.is_done())
    t.conn.begin_shutdown()
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS GOAWAY PING")


def test_goaway_rules() raises:
    # codec_read.rs read_goaway_with_debug_data and
    # read_goaway_stream_id_not_zero
    var t = server()
    var payload = List[UInt8](length=8, fill=0)
    payload.extend(StaticString("debug").as_bytes())
    t.peer.raw(FrameKind.GOAWAY, 0, 0, payload)
    t.send()
    assert_true(t.conn.goaway_received)
    assert_false(t.conn.closed)
    var u = server()
    u.peer.raw(FrameKind.GOAWAY, 0, 1, List[UInt8](length=8, fill=0))
    u.send()
    _goaway(u, Reason.PROTOCOL_ERROR)
    var v = server()
    v.peer.raw(FrameKind.GOAWAY, 0, 0, List[UInt8](length=7, fill=0))
    v.send()
    _goaway(v, Reason.FRAME_SIZE_ERROR)


def test_settings_rules() raises:
    # A SETTINGS frame on a stream, of a bad size, or an ACK with a payload.
    var t = server()
    t.peer.raw(FrameKind.SETTINGS, 0, 1)
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)
    var u = server()
    u.peer.raw(FrameKind.SETTINGS, 0, 0, bytes("12345"))
    u.send()
    _goaway(u, Reason.FRAME_SIZE_ERROR)
    var v = server()
    v.peer.raw(FrameKind.SETTINGS, ACK, 0, bytes("123456"))
    v.send()
    _goaway(v, Reason.FRAME_SIZE_ERROR)
    # An ACK that nothing waits for.
    var w = server()
    w.peer.settings_ack()
    w.send()
    _goaway(w, Reason.PROTOCOL_ERROR)


def _bad_setting(id: Int, value: Int, reason: Reason) raises:
    var t = server()
    t.peer.settings([id], [value])
    t.send()
    _goaway(t, reason)


def test_invalid_settings() raises:
    _bad_setting(2, 2, Reason.PROTOCOL_ERROR)
    _bad_setting(4, 0x80000000, Reason.FLOW_CONTROL_ERROR)
    _bad_setting(5, 16383, Reason.PROTOCOL_ERROR)
    _bad_setting(5, 16777216, Reason.PROTOCOL_ERROR)
    _bad_setting(8, 2, Reason.PROTOCOL_ERROR)


def test_peer_settings_apply() raises:
    var t = server()
    t.peer.settings(
        [1, 2, 3, 4, 5, 6, 8, 99],
        [0, 1, 7, 100, 20000, 4096, 1, 5],
    )
    t.send()
    var frames = t.read()
    assert_equal(kinds(frames), "SETTINGS")
    assert_true(frames[0].head.has(ACK))
    assert_equal(t.conn.remote.header_table_size, 0)
    assert_true(t.conn.remote.enable_push)
    assert_equal(t.conn.remote.max_concurrent_streams, 7)
    assert_equal(t.conn.remote.initial_window_size, 100)
    assert_equal(t.conn.remote.max_frame_size, 20000)
    assert_equal(t.conn.remote.max_header_list_size, 4096)
    assert_true(t.conn.remote.enable_connect_protocol)
    # The encoder's table is 0 now, so the next block says so first.
    t.peer.headers(1, request(), EOS)
    t.send()
    t.conn.send_headers(1, response(), True)
    frames = t.read()
    assert_equal(frames[0].field(":status"), "200")


def test_padding() raises:
    # codec_read.rs read_data_padding and read_headers_with_pseudo
    var t = server()
    var block = t.peer.block(request("POST", "/"))
    var padded = List[UInt8]()
    padded.append(2)
    padded.extend(Span(block))
    padded.append(0)
    padded.append(0)
    t.peer.raw(FrameKind.HEADERS, END_HEADERS | PADDED, 1, padded)
    var data = List[UInt8]()
    data.append(3)
    data.extend(StaticString("hey").as_bytes())
    data.extend(List[UInt8](length=3, fill=0))
    t.peer.raw(FrameKind.DATA, END_STREAM | PADDED, 1, data)
    t.send()
    assert_equal(len(t.conn.events), 1)
    var slot = t.conn.find(1)
    assert_equal(
        String(unsafe_from_utf8=Span(t.conn.streams[slot].body)), "hey"
    )
    # Padding as long as the payload, and a padded frame with no length.
    var u = server()
    u.peer.raw(FrameKind.DATA, PADDED, 1, [UInt8(1)])
    u.send()
    _goaway(u, Reason.PROTOCOL_ERROR)
    var v = server()
    v.peer.raw(FrameKind.HEADERS, PADDED | END_HEADERS, 1)
    v.send()
    _goaway(v, Reason.FRAME_SIZE_ERROR)


def test_priority() raises:
    # A HEADERS priority, and PRIORITY frames, are read and ignored.
    var t = server()
    var block = t.peer.block(request())
    var payload = List[UInt8](length=5, fill=0)
    payload[3] = 3
    payload.extend(Span(block))
    t.peer.raw(FrameKind.HEADERS, EOS | PRIORITY_FLAG, 1, payload)
    t.peer.raw(FrameKind.PRIORITY, 0, 9, List[UInt8](length=5, fill=0))
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_equal(t.conn.find(9), -1)
    # A stream that depends on itself; the block is decoded all the same.
    var self_dep = List[UInt8](length=5, fill=0)
    self_dep[3] = 3
    self_dep.extend(Span(t.peer.block(request("GET", "/x"))))
    t.peer.raw(FrameKind.HEADERS, EOS | PRIORITY_FLAG, 3, self_dep)
    t.send()
    _reset(t, 3, Reason.PROTOCOL_ERROR)
    t.peer.headers(5, request("GET", "/x"), EOS)
    t.send()
    assert_equal(t.conn.events[len(t.conn.events) - 1].stream_id, 5)
    # A priority that does not fit.
    t.peer.raw(FrameKind.HEADERS, EOS | PRIORITY_FLAG, 7, bytes("abc"))
    t.send()
    _goaway(t, Reason.FRAME_SIZE_ERROR)


def test_priority_frame_rules() raises:
    var t = server()
    t.peer.raw(FrameKind.PRIORITY, 0, 1, bytes("1234"))
    t.send()
    _reset(t, 1, Reason.FRAME_SIZE_ERROR)
    var same = List[UInt8](length=5, fill=0)
    same[3] = 3
    t.peer.raw(FrameKind.PRIORITY, 0, 3, same)
    t.send()
    _reset(t, 3, Reason.PROTOCOL_ERROR)
    t.peer.raw(FrameKind.PRIORITY, 0, 0, List[UInt8](length=5, fill=0))
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)


def test_push_promise_is_refused() raises:
    # codec_read.rs read_push_promise: a server never takes one, and a
    # client turned push off.
    var t = server()
    t.peer.raw(FrameKind.PUSH_PROMISE, END_HEADERS, 1, bytes("1234"))
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
