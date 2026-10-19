# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the client side of `gql_http2.connection`: requests,
responses, informational responses, `GOAWAY` and the stream limits.

Ported from h2 v0.4.20 `tests/h2-tests/tests/client_request.rs` and
`tests/h2-tests/tests/informational_responses.rs`. Each test names the
upstream test that it follows.
"""

from _frames import Pair, bytes, client, kinds, request, response
from gql_http2.connection import Config, EventKind, StreamState
from gql_http2.error import H2ErrorKind, Reason
from gql_http2.frame import END_HEADERS, END_STREAM, FrameKind, MAX_STREAM_ID
from gql_http2.hpack import HeaderList
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime EOS = END_HEADERS | END_STREAM
"""The flags of a whole head that ends its stream."""


def _open(mut t: Pair, end_stream: Bool = True) raises -> Int:
    """Open a stream and send a request head on it."""
    var id = t.conn.open_stream()
    t.conn.send_headers(id, request("POST", "/graphql"), end_stream)
    _ = t.read()
    return id


def _last_reset(t: Pair) raises -> Reason:
    """The code of the last `RESET` event."""
    var last = len(t.conn.events) - 1
    assert_true(t.conn.events[last].kind == EventKind.RESET)
    return t.conn.events[last].error.reason


def test_send_request() raises:
    # client_request.rs handshake and recv_data
    var t = client()
    var id = t.conn.open_stream()
    assert_equal(id, 1)
    t.conn.send_headers(id, request("POST", "/graphql"), False)
    t.conn.send_data(id, StaticString("{}").as_bytes(), True)
    var frames = t.read()
    assert_equal(kinds(frames), "HEADERS DATA")
    assert_equal(frames[0].field(":path"), "/graphql")
    assert_true(
        t.conn.streams[t.conn.find(id)].state == StreamState.HALF_CLOSED_LOCAL
    )
    var head = response(200)
    head.add_text("content-type", "application/json")
    t.peer.headers(1, head, END_HEADERS)
    t.peer.data(1, '{"data":1}', END_STREAM)
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)
    var slot = t.conn.find(1)
    assert_equal(t.conn.streams[slot].status, 200)
    assert_equal(
        String(unsafe_from_utf8=Span(t.conn.streams[slot].body)), '{"data":1}'
    )
    assert_equal(t.conn.active_streams(), 0)
    t.conn.release(1)
    assert_equal(t.conn.open_stream(), 3)


def test_informational_responses() raises:
    # informational_responses.rs send_100_continue and
    # send_multiple_informational_responses
    var t = client()
    var id = _open(t)
    t.peer.headers(id, response(100))
    t.peer.headers(id, response(103))
    t.peer.headers(id, response(204), EOS)
    t.send()
    assert_equal(len(t.conn.events), 1)
    assert_equal(t.conn.streams[t.conn.find(id)].status, 204)
    # An informational response cannot end the stream.
    id = _open(t)
    t.peer.headers(id, response(100), EOS)
    t.send()
    assert_true(_last_reset(t) == Reason.PROTOCOL_ERROR)
    # 101 is not allowed in HTTP/2.
    id = _open(t)
    t.peer.headers(id, response(101), EOS)
    t.send()
    assert_true(_last_reset(t) == Reason.PROTOCOL_ERROR)


def _bad_response(fields: HeaderList) raises:
    var t = client()
    var id = _open(t)
    t.peer.headers(id, fields, EOS)
    t.send()
    assert_true(_last_reset(t) == Reason.PROTOCOL_ERROR)
    var frames = t.read()
    assert_equal(kinds(frames), "RST_STREAM")


def test_malformed_responses() raises:
    _bad_response(HeaderList())
    _bad_response(response(20))
    _bad_response(response(99))
    var twice = response(200)
    twice.add_text(":status", "200")
    _bad_response(twice)
    var path = response(200)
    path.add_text(":path", "/")
    _bad_response(path)
    var late = HeaderList()
    late.add_text("x", "1")
    late.add_text(":status", "200")
    _bad_response(late)
    var conn = response(200)
    conn.add_text("connection", "close")
    _bad_response(conn)
    var length = response(200)
    length.add_text("content-length", "x")
    _bad_response(length)
    var te = response(200)
    te.add_text("te", "trailers")
    _bad_response(te)
    # A response head over the header list limit.
    var config = Config()
    config.max_header_list_size = 50
    var t = client(config)
    var id = _open(t)
    var big = response(200)
    big.add_text("x-big", "a value that makes the list too large")
    t.peer.headers(id, big, EOS)
    t.send()
    assert_true(_last_reset(t) == Reason.PROTOCOL_ERROR)


def test_response_content_length() raises:
    var t = client()
    var id = _open(t)
    var head = response(200)
    head.add_text("content-length", "2")
    t.peer.headers(id, head, END_HEADERS)
    t.peer.data(id, "ab", END_STREAM)
    t.send()
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)
    # Content larger than max_body_bytes.
    var config = Config()
    config.max_body_bytes = 3
    var u = client(config)
    id = _open(u)
    u.peer.headers(id, response(200), END_HEADERS)
    u.peer.data(id, "abcd", END_STREAM)
    u.send()
    assert_true(_last_reset(u) == Reason.CANCEL)


def test_trailers_on_response() raises:
    # trailers.rs recv_trailers_only
    var t = client()
    var id = _open(t)
    t.peer.headers(id, response(200), END_HEADERS)
    var trailers = HeaderList()
    trailers.add_text("grpc-status", "0")
    t.peer.headers(id, trailers, EOS)
    t.send()
    assert_true(t.conn.events[0].kind == EventKind.MESSAGE)


def test_server_cannot_open_streams() raises:
    # client_request.rs recv_push_promise without push: a stream of the
    # server, and HEADERS on an idle stream of the client.
    var t = client()
    t.peer.headers(2, response(200), EOS)
    t.send()
    assert_true(t.conn.closed)
    assert_true(t.conn.error.value().reason == Reason.PROTOCOL_ERROR)
    var u = client()
    u.peer.headers(5, response(200), EOS)
    u.send()
    assert_true(u.conn.closed)
    # A PUSH_PROMISE.
    var v = client()
    var id = _open(v)
    v.peer.raw(FrameKind.PUSH_PROMISE, END_HEADERS, id, bytes("1234"))
    v.send()
    assert_true(v.conn.closed)


def test_headers_on_closed_stream() raises:
    var t = client()
    var id = _open(t)
    t.peer.headers(id, response(200), EOS)
    t.send()
    t.conn.release(id)
    t.conn.events.clear()
    t.peer.headers(id, response(200), EOS)
    t.send()
    var frames = t.read()
    assert_equal(kinds(frames), "RST_STREAM")
    assert_equal(String(frames[0].reason()), "STREAM_CLOSED")
    assert_false(t.conn.closed)
    # A head after the end of the stream, before the slot is free.
    id = _open(t)
    t.peer.headers(id, response(200), EOS)
    t.peer.headers(id, response(200), EOS)
    t.send()
    frames = t.read()
    assert_equal(kinds(frames), "RST_STREAM")


def test_recv_goaway_finishes_processed_streams() raises:
    # stream_states.rs recv_goaway_finishes_processed_streams
    var t = client()
    var first = _open(t)
    var second = _open(t)
    t.peer.goaway(first, Reason.NO_ERROR)
    t.send()
    assert_true(t.conn.goaway_received)
    assert_equal(len(t.conn.events), 1)
    assert_equal(t.conn.events[0].stream_id, second)
    assert_true(t.conn.events[0].error.kind == H2ErrorKind.REMOTE_GOAWAY)
    assert_false(t.conn.is_done())
    var failed = False
    try:
        _ = t.conn.open_stream()
    except e:
        failed = e.kind == H2ErrorKind.REMOTE_GOAWAY
    assert_true(failed)
    t.peer.headers(first, response(200), EOS)
    t.send()
    assert_true(t.conn.is_done())
    # A second GOAWAY can lower the last id, not raise it.
    t.peer.goaway(MAX_STREAM_ID, Reason.NO_ERROR)
    t.send()
    assert_equal(t.conn.remote_last_stream, first)


def test_remote_reset() raises:
    # client_request.rs request_stream_id_overflows and recv reset
    var t = client()
    var id = _open(t, False)
    t.peer.rst(id, Reason.REFUSED_STREAM)
    t.send()
    assert_true(t.conn.events[0].error.kind == H2ErrorKind.REMOTE_RESET)
    assert_true(_last_reset(t) == Reason.REFUSED_STREAM)
    assert_equal(t.conn.find(id), -1)
    # A reset of a closed stream is ignored.
    t.peer.rst(id, Reason.CANCEL)
    t.send()
    assert_false(t.conn.closed)


def test_stream_limits() raises:
    # client_request.rs request_over_max_concurrent_streams
    var t = client()
    t.peer.settings([3], [1])
    t.send()
    _ = t.read()
    _ = _open(t, False)
    var failed = False
    try:
        _ = t.conn.open_stream()
    except e:
        failed = e.kind == H2ErrorKind.USAGE
    assert_true(failed)
    # client_request.rs request_stream_id_overflows
    var u = client()
    u.conn.next_stream_id = MAX_STREAM_ID + 2
    failed = False
    try:
        _ = u.conn.open_stream()
    except e:
        failed = e.kind == H2ErrorKind.USAGE
    assert_true(failed)
    # A connection that has ended opens nothing.
    u.conn.abort(Reason.NO_ERROR)
    failed = False
    try:
        _ = u.conn.open_stream()
    except e:
        failed = e.kind == H2ErrorKind.IO
    assert_true(failed)


def test_server_enable_push_is_refused() raises:
    var t = client()
    t.peer.settings([2], [1])
    t.send()
    assert_true(t.conn.closed)
    # ENABLE_PUSH = 0 from a server is allowed.
    var u = client()
    u.peer.settings([2], [0])
    u.send()
    assert_false(u.conn.closed)
    assert_false(u.conn.remote.enable_push)


def test_send_rules() raises:
    var t = client()
    var failed = False
    try:
        t.conn.send_data(7, StaticString("x").as_bytes(), True)
    except e:
        failed = e.kind == H2ErrorKind.USAGE
    assert_true(failed)
    var id = _open(t)
    failed = False
    try:
        t.conn.send_headers(id, request(), True)
    except e:
        failed = e.kind == H2ErrorKind.USAGE
    assert_true(failed)
    # Content after the end of the message, while it waits for a window.
    var u = client()
    u.conn.send_window = 0
    id = _open(u, False)
    u.conn.send_data(id, StaticString("abc").as_bytes(), True)
    failed = False
    try:
        u.conn.send_data(id, StaticString("d").as_bytes(), False)
    except e:
        failed = e.kind == H2ErrorKind.USAGE
    assert_true(failed)
    assert_equal(u.conn.pending_output(), 3)
    # Resetting and releasing a stream that is not active does nothing.
    u.conn.reset_stream(99, Reason.CANCEL)
    u.conn.release(99)
    assert_equal(len(u.conn.out), 0)
    # A client's graceful shutdown sends its final GOAWAY at once.
    u.conn.begin_shutdown()
    var frames = u.read()
    assert_equal(kinds(frames), "GOAWAY")
    assert_true(u.conn.goaway_sent)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
