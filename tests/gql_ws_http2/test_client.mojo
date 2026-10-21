# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http2.client`: `H2WebSocket` on a `Loop` transport,
whose far end is a `WsH2Session` in memory.

There is no upstream suite. The cases follow the client cases of
`tests/gql_ws/test_client.mojo` (tungstenite 0.30.0 `tests/handshake.rs`
and `tests/connection_reset.rs`), on an HTTP/2 stream as RFC 8441
sections 4 to 6 tell.
"""

from _h2ws import Loop
from gql_http.socket import EAGAIN, ECONNRESET, EINTR
from gql_http2.connection import Config
from gql_ws.client import ClientConfig
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind
from gql_ws_http2.client import H2WebSocket, connect_h2c
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime GTW = "graphql-transport-ws"


def _quick() -> ClientConfig:
    """A configuration with short timeouts, for a `Loop` that cannot
    wake a `poll`."""
    var config = ClientConfig()
    config.connect_timeout_ms = 50
    config.write_timeout_ms = 50
    return config^


def _open(
    var loop: Loop,
    path: StringSlice = "/graphql",
    config: ClientConfig = _quick(),
) raises -> H2WebSocket[Loop]:
    """A WebSocket after its handshake."""
    var socket = H2WebSocket[Loop](loop^, config)
    socket.handshake("http", "localhost", path, [GTW])
    return socket^


def test_echo() raises:
    var socket = _open(Loop())
    assert_equal(socket.protocol, GTW)
    assert_equal(socket.transport.echo.opened, 1)
    socket.send_text("hello")
    var message = Message()
    assert_true(socket.read(message, 0))
    assert_equal(String(message.text()), "hello")
    var data: List[UInt8] = [1, 2, 3]
    socket.send_binary(Span(data))
    assert_true(socket.read(message, 0))
    assert_true(message.kind == MessageKind.BINARY)
    socket.ping("p".as_bytes())
    assert_true(socket.read(message, 0))
    assert_true(message.kind == MessageKind.PONG)
    # Nothing more arrives before the timeout.
    assert_false(socket.read(message, 0))


def test_message_that_the_server_pushes() raises:
    var socket = _open(Loop())
    var id = socket.transport.echo.last
    _ = socket.transport.sockets.send_text(id, "pushed")
    socket.transport.push()
    var message = Message()
    assert_true(socket.read(message, 0))
    assert_equal(String(message.text()), "pushed")


def test_client_closes() raises:
    var socket = _open(Loop())
    socket.close(CloseCode.NORMAL, "done")
    var message = Message()
    assert_true(socket.read(message, 0))
    assert_true(message.kind == MessageKind.CLOSE)
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.CLOSED)
    assert_true(raised)
    assert_equal(socket.transport.echo.code, 1000)
    assert_equal(socket.transport.echo.reason, "done")


def test_client_closes_with_small_reads() raises:
    # The close reply comes before the end of the stream: the client ends
    # its side first.
    var loop = Loop()
    var socket = _open(loop^)
    socket.transport.read_chunk = 1
    socket.close()
    var message = Message()
    assert_true(socket.read(message, 0))
    assert_true(message.kind == MessageKind.CLOSE)
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.CLOSED)
    assert_true(raised)


def test_server_closes() raises:
    var socket = _open(Loop())
    socket.send_text("close")
    var message = Message()
    assert_true(socket.read(message, 0))
    assert_true(message.kind == MessageKind.CLOSE)
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.CLOSED)
    assert_true(raised)
    assert_equal(socket.transport.echo.closed, 1)


def test_end_without_closing_handshake() raises:
    var socket = _open(Loop())
    socket.transport.hang_up = True
    var message = Message()
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.PROTOCOL)
    assert_true(raised)


def test_reset() raises:
    # The server resets a stream whose content is over its limit.
    var config = Config()
    config.max_body_bytes = 100
    var socket = _open(Loop(config=config))
    socket.send_text("x" * 1000)
    var message = Message()
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.PROTOCOL)
    assert_true(raised)


def test_connection_error() raises:
    var socket = _open(Loop())
    var garbage: List[UInt8] = [0, 0, 4, 4, 0, 0, 0, 0, 0, 1, 2, 3, 4]
    socket.transport.inbox.extend(Span(garbage))
    var message = Message()
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.PROTOCOL)
    assert_true(raised)


def test_ended_connection_cannot_send() raises:
    # A stream that cannot send any more fails the send with IO.
    var socket = _open(Loop())
    socket.conn.closed = True
    var raised = False
    try:
        socket.send_text("late")
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.IO)
    assert_true(raised)


def test_invalid_frame() raises:
    # A masked frame from the server fails the WebSocket with 1002, and
    # the close frame goes out.
    var socket = _open(Loop())

    var stream = socket.stream_id
    var frame: List[UInt8] = [0x81, 0x82, 1, 2, 3, 4, 0x69, 0x6B]
    try:
        socket.transport.session.session.conn.send_data(
            stream, Span(frame), False
        )
    except:
        pass

    socket.transport._move()
    var message = Message()
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.PROTOCOL)
    assert_true(raised)
    assert_equal(socket.transport.echo.code, 1002)


def test_small_window() raises:
    # A send waits for the window of the server.
    var config = Config()
    config.initial_window_size = 100
    var socket = _open(Loop(config=config))
    socket.send_text("y" * 1000)
    var message = Message()
    assert_true(socket.read(message, 0))
    assert_equal(message.text().byte_length(), 1000)


def test_send_timeout() raises:
    var config = Config()
    config.initial_window_size = 100
    var socket = _open(Loop(config=config))
    socket.transport.silent = True
    var raised = False
    try:
        socket.send_text("y" * 1000)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.TIMEOUT)
    assert_true(raised)


def test_end_while_a_send_waits() raises:
    var config = Config()
    config.initial_window_size = 100
    var socket = _open(Loop(config=config))
    socket.transport.silent = True
    socket.transport.hang_up = True
    socket.send_text("y" * 1000)
    var message = Message()
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.PROTOCOL)
    assert_true(raised)


def test_transport_faults() raises:
    # EINTR and EAGAIN go on; another error fails the read or the write.
    var socket = _open(Loop(ready=True))
    socket.transport.writes = [-EAGAIN, -EINTR]
    socket.transport.reads = [-EINTR, -EAGAIN]
    socket.send_text("a")
    var message = Message()
    assert_true(socket.read(message, 1000))
    socket.transport.reads = [-ECONNRESET]
    var raised = False
    try:
        _ = socket.read(message, 0)
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.IO)
    assert_true(raised)
    var other = _open(Loop())
    other.transport.writes = [-ECONNRESET]
    raised = False
    try:
        other.send_text("b")
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.IO)
    assert_true(raised)
    var blocked = _open(Loop())
    blocked.transport.writes = [-EAGAIN]
    raised = False
    try:
        blocked.send_text("c")
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.TIMEOUT)
    assert_true(raised)


def _handshake_error(
    var loop: Loop, path: StringSlice = "/graphql"
) raises -> WsError:
    """The error of a handshake that fails."""
    var socket = H2WebSocket[Loop](loop^, _quick())
    try:
        socket.handshake("http", "localhost", path, [GTW])
    except e:
        return e^
    raise Error("the handshake did not fail")


def test_refused_handshakes() raises:
    var refused = _handshake_error(Loop(path="/graphql"), "/other")
    assert_true(refused.kind == WsErrorKind.HANDSHAKE)
    assert_equal(refused.status, 404)
    var disabled = _handshake_error(Loop(connect_protocol=False))
    assert_true(disabled.kind == WsErrorKind.HANDSHAKE)
    var no_streams = Config()
    no_streams.max_concurrent_streams = 0
    var full = _handshake_error(Loop(config=no_streams))
    assert_true(full.kind == WsErrorKind.IO)
    # A bad :path gets a reset before any head.
    var reset = _handshake_error(Loop(), "")
    assert_true(reset.kind == WsErrorKind.HANDSHAKE)


def test_handshake_without_answer() raises:
    var silent = Loop()
    silent.inbox.clear()
    silent.silent = True
    var timeout = _handshake_error(silent^)
    assert_true(timeout.kind == WsErrorKind.TIMEOUT)
    var gone = Loop()
    gone.inbox.clear()
    gone.silent = True
    gone.hang_up = True
    var ended = _handshake_error(gone^)
    assert_true(ended.kind == WsErrorKind.HANDSHAKE)
    # The server ends the connection after its SETTINGS.
    var late = Loop()
    late.hang_up = True
    late.silent = True
    var late_error = _handshake_error(late^)
    assert_true(late_error.kind == WsErrorKind.HANDSHAKE)


def test_head_timeout() raises:
    # The server sends its SETTINGS, then nothing.
    var loop = Loop()
    loop.silent = True
    var error = _handshake_error(loop^)
    assert_true(error.kind == WsErrorKind.TIMEOUT)


def test_connect_errors() raises:
    var kinds = List[String]()
    var urls: List[String] = [
        "http://localhost/graphql",
        "wss://localhost/graphql",
        "no url",
    ]
    var index = 0
    while index < len(urls):
        try:
            _ = connect_h2c(urls[index])
        except e:
            assert_true(e.kind == WsErrorKind.HANDSHAKE)
            kinds.append(String(e.message))
        index += 1
    assert_equal(len(kinds), 3)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
