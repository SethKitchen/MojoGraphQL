# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the stream states and the flow control of
`gql_http2.connection`.

Ported from h2 v0.4.20 `tests/h2-tests/tests/stream_states.rs` and
`tests/h2-tests/tests/flow_control.rs`. Each test names the upstream test
that it follows.
"""

from _frames import Pair, Peer, bytes, client, kinds, request, response, server
from gql_http2.connection import (
    Config,
    Connection,
    EventKind,
    Role,
    StreamState,
    calc_max_continuation_frames,
    check_request_head,
    check_response_head,
    check_trailers,
)
from gql_http2.error import H2ErrorKind, Reason
from gql_http2.frame import (
    END_HEADERS,
    END_STREAM,
    FrameKind,
    MAX_WINDOW_SIZE,
    write_u32,
)
from gql_http2.hpack import HeaderList
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime EOS = END_HEADERS | END_STREAM
"""The flags of a whole head that ends its stream."""


def _goaway(mut t: Pair, reason: Reason) raises:
    var frames = t.read()
    assert_true(t.conn.closed, kinds(frames))
    assert_true(frames[len(frames) - 1].head.kind == FrameKind.GOAWAY)
    assert_equal(String(frames[len(frames) - 1].reason()), String(reason))


def _reset(mut t: Pair, id: Int, reason: Reason) raises:
    var frames = t.read()
    if t.conn.closed:
        raise Error("the connection ended: " + String(t.conn.error.value()))
    var last = len(frames) - 1
    assert_true(frames[last].head.kind == FrameKind.RST_STREAM, kinds(frames))
    assert_equal(frames[last].head.stream_id, id)
    assert_equal(String(frames[last].reason()), String(reason))


def _open(mut t: Pair, id: Int) raises:
    """Open a request stream that stays open."""
    t.peer.headers(id, request("POST", "/"), END_HEADERS)
    t.send()


def test_send_recv_data_split() raises:
    # stream_states.rs send_recv_data: frames split anywhere.
    var t = server()
    t.peer.headers(1, request("POST", "/"), END_HEADERS)
    t.peer.data(1, "hello", END_STREAM)
    var all = t.peer.out.copy()
    t.peer.out.clear()
    t.conn.receive(Span(all)[:5])
    t.conn.receive(Span(all)[5 : len(all) - 2])
    assert_equal(len(t.conn.events), 0)
    t.conn.receive(Span(all)[len(all) - 2 :])
    assert_equal(len(t.conn.events), 1)
    var slot = t.conn.find(1)
    assert_equal(
        String(unsafe_from_utf8=Span(t.conn.streams[slot].body)), "hello"
    )


def test_data_rules() raises:
    # stream_states.rs: DATA on stream 0, on an idle stream, after the end
    # of the stream, and on a closed stream.
    var t = server()
    t.peer.data(0, "x")
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)
    var u = server()
    u.peer.data(1, "x")
    u.send()
    _goaway(u, Reason.PROTOCOL_ERROR)
    var v = server()
    v.peer.headers(1, request(), EOS)
    v.peer.data(1, "x")
    v.send()
    _reset(v, 1, Reason.STREAM_CLOSED)
    v.conn.release(1)
    v.peer.data(1, "x")
    v.send()
    _reset(v, 1, Reason.STREAM_CLOSED)


def test_too_many_empty_data_frames_sends_goaway() raises:
    # stream_states.rs too_many_empty_data_frames_sends_goaway
    var config = Config()
    config.max_empty_data_frames = 3
    var t = server(config)
    _open(t, 1)
    var index = 0
    while index < 4:
        t.peer.data(1, "")
        index += 1
    t.send()
    _goaway(t, Reason.ENHANCE_YOUR_CALM)


def test_recv_data_overflows_connection_window() raises:
    # flow_control.rs recv_data_overflows_connection_window
    # The window comes back at half, so only a frame larger than the
    # window overflows it.
    var config = Config()
    config.connection_window_size = 65535
    config.initial_window_size = 1 << 20
    config.max_frame_size = 100000
    var t = server(config)
    _open(t, 1)
    t.peer.raw(FrameKind.DATA, 0, 1, List[UInt8](length=65536, fill=0x61))
    t.send()
    _goaway(t, Reason.FLOW_CONTROL_ERROR)


def test_recv_data_overflows_stream_window() raises:
    # flow_control.rs recv_data_overflows_stream_window
    var config = Config()
    config.initial_window_size = 16384
    config.max_frame_size = 100000
    var t = server(config)
    _open(t, 1)
    t.peer.raw(FrameKind.DATA, 0, 1, List[UInt8](length=16384, fill=0x61))
    t.send()
    var frames = t.read()
    # Half of the stream window came back.
    assert_equal(kinds(frames), "WINDOW_UPDATE")
    assert_equal(frames[0].head.stream_id, 1)
    assert_equal(frames[0].u32(0), 16384)
    t.peer.raw(FrameKind.DATA, 0, 1, List[UInt8](length=16385, fill=0x61))
    t.send()
    _reset(t, 1, Reason.FLOW_CONTROL_ERROR)


def test_release_capacity_sends_window_update() raises:
    # flow_control.rs release_capacity_sends_window_update: the
    # connection window comes back at half.
    var config = Config()
    config.connection_window_size = 65535
    var t = server(config)
    _open(t, 1)
    var chunk = List[UInt8](length=16384, fill=0x61)
    t.peer.raw(FrameKind.DATA, 0, 1, chunk)
    t.peer.raw(FrameKind.DATA, 0, 1, chunk)
    t.send()
    var frames = t.read()
    assert_equal(kinds(frames), "WINDOW_UPDATE")
    assert_equal(frames[0].head.stream_id, 0)
    assert_equal(frames[0].u32(0), 32768)


def test_send_data_waits_for_window() raises:
    # flow_control.rs send_data_without_requesting_capacity and
    # recv_window_update_causes_overflow
    var t = server()
    t.peer.headers(1, request(), EOS)
    t.send()
    t.conn.send_headers(1, response(), False)
    var body = List[UInt8](length=70000, fill=0x62)
    t.conn.send_data(1, body, True)
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS DATA DATA DATA DATA")
    assert_equal(t.conn.pending_output(), 70000 - 65535)
    assert_equal(t.conn.send_window, 0)
    # The connection window grows; the stream window is still 0.
    t.peer.window_update(0, 10000)
    t.send()
    assert_equal(len(t.read()), 0)
    t.peer.window_update(1, 100)
    t.send()
    frames = t.read()
    assert_equal(kinds(frames), "DATA")
    assert_equal(frames[0].head.length, 100)
    t.peer.window_update(1, 10000)
    t.send()
    frames = t.read()
    assert_equal(kinds(frames), "DATA")
    assert_true(frames[0].head.has(END_STREAM))
    assert_equal(t.conn.active_streams(), 0)
    # A WINDOW_UPDATE on a closed stream is ignored.
    t.peer.window_update(1, 5)
    t.send()
    assert_false(t.conn.closed)


def test_window_update_rules() raises:
    var t = server()
    t.peer.window_update(0, 0)
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)
    var u = server()
    u.peer.window_update(0, MAX_WINDOW_SIZE)
    u.send()
    _goaway(u, Reason.FLOW_CONTROL_ERROR)
    var v = server()
    v.peer.window_update(1, 1)
    v.send()
    _goaway(v, Reason.PROTOCOL_ERROR)
    var w = server()
    w.peer.raw(FrameKind.WINDOW_UPDATE, 0, 0, bytes("12345"))
    w.send()
    _goaway(w, Reason.FRAME_SIZE_ERROR)
    var x = server()
    _open(x, 1)
    x.peer.window_update(1, 0)
    x.send()
    _reset(x, 1, Reason.PROTOCOL_ERROR)
    _open(x, 3)
    x.peer.window_update(3, MAX_WINDOW_SIZE)
    x.send()
    _reset(x, 3, Reason.FLOW_CONTROL_ERROR)


def test_rst_stream_rules() raises:
    var t = server()
    t.peer.rst(1, Reason.CANCEL)
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)
    var u = server()
    u.peer.rst(0, Reason.CANCEL)
    u.send()
    _goaway(u, Reason.PROTOCOL_ERROR)
    var v = server()
    _open(v, 1)
    v.peer.raw(FrameKind.RST_STREAM, 0, 1, bytes("123"))
    v.send()
    _goaway(v, Reason.FRAME_SIZE_ERROR)


def test_reset_streams_dont_grow_memory_continuously() raises:
    # stream_states.rs reset_streams_dont_grow_memory_continuously and
    # the rapid reset limit
    var config = Config()
    config.max_remote_resets = 3
    var t = server(config)
    var id = 1
    while id <= 5:
        _open(t, id)
        t.peer.rst(id, Reason.CANCEL)
        t.send()
        id += 2
    assert_equal(len(t.conn.streams), 1)
    assert_false(t.conn.closed)
    _open(t, 7)
    t.peer.rst(7, Reason.CANCEL)
    t.send()
    _goaway(t, Reason.ENHANCE_YOUR_CALM)
    # A response sets the count back to 0.
    var u = server(config)
    id = 1
    while id <= 21:
        _open(u, id)
        u.conn.send_headers(id, response(), False)
        u.peer.rst(id, Reason.CANCEL)
        u.send()
        id += 2
    assert_false(u.conn.closed)


def test_exceed_max_streams() raises:
    # stream_states.rs exceed_max_streams
    var config = Config()
    config.max_concurrent_streams = 1
    var t = server(config)
    _open(t, 1)
    _open(t, 3)
    _reset(t, 3, Reason.REFUSED_STREAM)
    # Without a limit, more streams open.
    config.max_concurrent_streams = -1
    var u = server(config)
    _open(u, 1)
    _open(u, 3)
    assert_equal(u.conn.active_streams(), 2)


def test_stream_ids() raises:
    # stream_states.rs skipped_stream_ids_are_implicitly_closed
    var t = server()
    _open(t, 5)
    t.peer.headers(3, request(), EOS)
    t.send()
    _reset(t, 3, Reason.STREAM_CLOSED)
    # An even id from a client.
    t.peer.headers(4, request(), EOS)
    t.send()
    _goaway(t, Reason.PROTOCOL_ERROR)
    var u = server()
    u.peer.headers(0, request(), EOS)
    u.send()
    _goaway(u, Reason.PROTOCOL_ERROR)


def test_content_too_large() raises:
    var config = Config()
    config.max_body_bytes = 4
    var t = server(config)
    _open(t, 1)
    t.peer.data(1, "12345")
    t.send()
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS RST_STREAM")
    assert_equal(frames[0].field(":status"), "413")
    assert_equal(String(frames[1].reason()), "CANCEL")
    assert_equal(t.conn.active_streams(), 0)


def test_settings_change_windows() raises:
    # flow_control.rs recv_settings_increase_window_size_after_using_some
    # and client_decrease_initial_window_size
    var t = server()
    t.peer.headers(1, request(), EOS)
    t.send()
    t.conn.send_headers(1, response(), False)
    t.conn.send_data(1, List[UInt8](length=10, fill=0x63), False)
    t.peer.settings([4], [100])
    t.send()
    var slot = t.conn.find(1)
    assert_equal(t.conn.streams[slot].send_window, 100 - 10)
    t.peer.settings([4], [5])
    t.send()
    assert_equal(t.conn.streams[slot].send_window, -5)
    # A window that a WINDOW_UPDATE grew overflows when the setting grows.
    t.peer.window_update(1, MAX_WINDOW_SIZE - 10)
    t.send()
    assert_equal(t.conn.streams[slot].send_window, MAX_WINDOW_SIZE - 15)
    t.peer.settings([4], [25])
    t.send()
    _goaway(t, Reason.FLOW_CONTROL_ERROR)


def test_local_settings_ack() raises:
    # server.rs init_window_size_smaller_than_default_should_use_default_before_ack
    var config = Config()
    config.initial_window_size = 1000
    config.header_table_size = 1024
    var conn = Connection(Role.SERVER, config)
    conn.start()
    var t = Pair(conn^, Peer())
    _ = t.read()
    t.peer.preface()
    t.peer.settings()
    t.peer.headers(1, request("POST", "/"), END_HEADERS)
    t.send()
    var slot = t.conn.find(1)
    assert_equal(t.conn.streams[slot].recv_window, 65535)
    t.peer.settings_ack()
    t.send()
    assert_equal(t.conn.streams[slot].recv_window, 1000)
    assert_false(t.conn.settings_pending)
    assert_equal(t.conn.local_acked.header_table_size, 1024)


def test_upgrade() raises:
    var conn = Connection(Role.SERVER)
    var payload = List[UInt8]()
    payload.append(0)
    payload.append(3)
    write_u32(payload, 7)
    var slot = conn.upgrade(payload, True)
    assert_equal(conn.streams[slot].id, 1)
    assert_true(conn.streams[slot].state == StreamState.HALF_CLOSED_REMOTE)
    assert_true(conn.streams[slot].head_request)
    assert_equal(conn.remote.max_concurrent_streams, 7)
    assert_equal(conn.last_peer_stream, 1)
    var failed = False
    var other = Connection(Role.SERVER)
    try:
        _ = other.upgrade(bytes("12345"), False)
    except e:
        failed = e.reason == Reason.FRAME_SIZE_ERROR
    assert_true(failed)


def test_types() raises:
    assert_equal(String(Role.CLIENT), "client")
    assert_equal(String(Role.SERVER), "server")
    assert_equal(String(Role(5)), "invalid")
    assert_true(Role.SERVER.is_valid() and not Role(2).is_valid())
    assert_equal(String(StreamState.OPEN), "open")
    assert_equal(String(StreamState.HALF_CLOSED_REMOTE), "half-closed (remote)")
    assert_equal(String(StreamState(9)), "invalid")
    assert_false(StreamState(5).is_valid())
    assert_equal(String(EventKind.MESSAGE), "message")
    assert_equal(String(EventKind.RESET), "reset")
    assert_equal(String(EventKind(4)), "invalid")
    assert_true(EventKind.RESET.is_valid() and not EventKind(2).is_valid())
    assert_equal(calc_max_continuation_frames(16384, 16384), 5)
    assert_equal(calc_max_continuation_frames(1 << 20, 16384), 80)


def test_free_slots_in_window_changes() raises:
    # A free slot is skipped when settings change the windows.
    var t = server()
    t.peer.headers(1, request(), EOS)
    t.peer.headers(3, request(), EOS)
    t.send()
    t.conn.send_headers(1, response(), True)
    t.conn.release(1)
    t.conn.send_headers(3, response(), False)
    t.conn.send_window = 0
    t.conn.send_data(3, bytes("waiting"), True)
    assert_equal(t.conn.pending_output(), 7)
    t.peer.settings([4], [100])
    t.send()
    assert_equal(t.conn.streams[t.conn.find(3)].send_window, 100)
    # A stream released before it closes is freed when it closes.
    t.conn.release(3)
    assert_equal(t.conn.find(3), 1)
    t.peer.window_update(0, 50)
    t.send()
    assert_equal(t.conn.find(3), -1)
    # Our settings apply on their ACK, past free slots too.
    var config = Config()
    config.initial_window_size = 1000
    var conn = Connection(Role.SERVER, config)
    conn.start()
    var u = Pair(conn^, Peer())
    _ = u.read()
    u.peer.preface()
    u.peer.settings()
    u.peer.headers(1, request(), EOS)
    u.peer.headers(3, request("POST", "/"), END_HEADERS)
    u.send()
    u.conn.send_headers(1, response(), True)
    u.conn.release(1)
    u.peer.settings_ack()
    u.send()
    assert_equal(u.conn.streams[u.conn.find(3)].recv_window, 1000)


def test_end_after_content() raises:
    # The end of a message after its content went out: an empty DATA.
    var t = server()
    t.peer.headers(1, request(), EOS)
    t.send()
    t.conn.send_headers(1, response(), False)
    t.conn.send_data(1, bytes("abc"), False)
    t.conn.send_data(1, List[UInt8](), True)
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS DATA DATA")
    assert_equal(frames[2].head.length, 0)
    assert_true(frames[2].head.has(END_STREAM))


def test_shutdown_ping_without_shutdown() raises:
    var t = server()
    t.peer.ping(0x0B7BA2F08B9BFE54, True)
    t.send()
    assert_equal(t.conn.pongs, 1)
    assert_false(t.conn.goaway_sent)
    # A shutdown after a connection error sends nothing more.
    t.peer.window_update(0, 0)
    t.send()
    _ = t.read()
    t.conn.begin_shutdown()
    assert_equal(len(t.conn.out), 0)


def test_window_update_on_released_stream() raises:
    var t = server()
    t.peer.headers(1, request(), EOS)
    t.send()
    t.conn.send_headers(1, response(), True)
    t.conn.release(1)
    _ = t.read()
    t.peer.window_update(1, 5)
    t.send()
    assert_false(t.conn.closed)
    assert_equal(len(t.read()), 0)


def test_head_checks_directly() raises:
    # Lists that a decoder never gives: an empty name.
    var empty = HeaderList()
    empty.add_text("", "x")
    var failed = 0
    try:
        check_trailers(empty, 1)
    except:
        failed += 1
    var request_head = HeaderList()
    request_head.add_text(":method", "GET")
    request_head.add_text("", "x")
    try:
        _ = check_request_head(request_head, 1, False)
    except:
        failed += 1
    var response_head = HeaderList()
    response_head.add_text("", "x")
    try:
        _ = check_response_head(response_head, 1)
    except:
        failed += 1
    assert_equal(failed, 3)
    var minus = HeaderList()
    minus.add_text(":method", "POST")
    minus.add_text(":scheme", "http")
    minus.add_text(":path", "/")
    minus.add_text("content-length", "-1")
    failed = 0
    try:
        _ = check_request_head(minus, 1, False)
    except:
        failed += 1
    var scheme_only = HeaderList()
    scheme_only.add_text(":method", "CONNECT")
    scheme_only.add_text(":scheme", "https")
    scheme_only.add_text(":authority", "a:1")
    try:
        _ = check_request_head(scheme_only, 1, False)
    except:
        failed += 1
    var low = HeaderList()
    low.add_text(":status", "099")
    try:
        _ = check_response_head(low, 1)
    except:
        failed += 1
    assert_equal(failed, 3)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
