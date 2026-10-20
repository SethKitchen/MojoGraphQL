# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the closing handshake, the write limit and the buffers of
`gql_ws.protocol`, and for `gql_ws.error`.

Ported from tungstenite 0.30.0 `tests/no_send_after_close.rs`,
`tests/receive_after_init_close.rs`, `tests/auto_pong_flush.rs` and the
`do_close` and `set_additional` rules of `src/protocol/mod.rs`, with
Autobahn sections 7.1 to 7.13.
"""

from _wsutil import close_frame, frames, raw, take_output, text_frame
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode, OpCode
from gql_ws.protocol import (
    Message,
    MessageKind,
    Role,
    WebSocket,
    WsConfig,
    WsState,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for value in values:
        out.append(UInt8(value))
    return out^


def kind_of_send(mut ws: WebSocket) -> WsErrorKind:
    try:
        ws.send_text("x")
    except e:
        return e.kind
    return WsErrorKind(255)


def test_peer_closes() raises:
    # Autobahn 7.1.1 and 7.3.6: the server answers a close with its code.
    var ws = WebSocket(Role.SERVER)
    ws.receive(close_frame(1000, "bye"))
    var m = Message()
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.CLOSE)
    assert_true(m.code == CloseCode.NORMAL)
    assert_equal(m.text(), "bye")
    assert_true(ws.state == WsState.CLOSED_BY_PEER)
    assert_false(ws.can_read())
    assert_false(ws.can_write())
    assert_true(ws.should_close())
    var out = frames(take_output(ws))
    assert_equal(len(out), 1)
    assert_equal(out[0].code(), 1000)
    assert_equal(out[0].text()[byte=2:], "bye")
    assert_false(ws.read(m))
    assert_true(kind_of_send(ws) == WsErrorKind.SEND_AFTER_CLOSING)
    assert_true(ws.peer_closed())
    assert_true(ws.state == WsState.TERMINATED)


def test_empty_close() raises:
    # Autobahn 7.3.1: a close without a payload gets one without a payload.
    var ws = WebSocket(Role.SERVER)
    ws.receive(raw(OpCode.CLOSE, bytes()))
    var m = Message()
    assert_true(ws.read(m))
    assert_true(m.code == CloseCode.STATUS)
    var out = frames(take_output(ws))
    assert_equal(len(out[0].payload), 0)


def test_close_errors() raises:
    # Autobahn 7.3.2: a close payload of one byte.
    var a = WebSocket(Role.SERVER)
    a.receive(raw(OpCode.CLOSE, bytes(3)))
    var m = Message()
    var kind = WsErrorKind(255)
    try:
        _ = a.read(m)
    except e:
        kind = e.kind
    assert_true(kind == WsErrorKind.PROTOCOL)
    assert_equal(frames(take_output(a))[0].code(), 1002)
    # Autobahn 7.5.1: a reason that is not UTF-8.
    var b = WebSocket(Role.SERVER)
    b.receive(raw(OpCode.CLOSE, bytes(0x03, 0xE8, 0xCE, 0xBA, 0xFF)))
    kind = WsErrorKind(255)
    try:
        _ = b.read(m)
    except e:
        kind = e.kind
    assert_true(kind == WsErrorKind.UTF8)
    assert_equal(frames(take_output(b))[0].code(), 1007)


def test_close_code_not_allowed() raises:
    # Autobahn 7.9.x: an invalid code gets 1002 "Protocol violation".
    var codes: List[Int] = [
        0,
        999,
        1004,
        1005,
        1006,
        1014,
        1015,
        1016,
        2999,
        5000,
    ]
    for code in codes:
        var ws = WebSocket(Role.SERVER)
        ws.receive(close_frame(code))
        var m = Message()
        assert_true(ws.read(m))
        assert_equal(Int(m.code.value), code)
        var out = frames(take_output(ws))
        assert_equal(out[0].code(), 1002)
        assert_equal(out[0].text()[byte=2:], "Protocol violation")


def test_after_peer_close() raises:
    # Autobahn 7.1.3 to 7.1.5: frames after the close are an error, and
    # no second close goes out.
    var ws = WebSocket(Role.SERVER)
    var data = close_frame(1000)
    data.extend(text_frame("late"))
    ws.receive(data)
    var m = Message()
    assert_true(ws.read(m))
    _ = take_output(ws)
    var message = String()
    try:
        _ = ws.read(m)
    except e:
        message = e.message
    assert_equal(message, "Remote sent after having closed")
    assert_equal(ws.pending(), 0)
    assert_true(ws.should_close())


def test_we_close_first() raises:
    # tungstenite `receive_after_init_close`: after our close, the peer can
    # still send data, and a ping gets no pong.
    var ws = WebSocket(Role.CLIENT)
    ws.close(CloseCode.NORMAL, "done")
    assert_true(ws.state == WsState.CLOSED_BY_US)
    assert_false(ws.can_write())
    assert_true(ws.can_read())
    assert_false(ws.should_close())
    var out = frames(take_output(ws))
    assert_equal(out[0].code(), 1000)
    assert_true(out[0].masked)
    # tungstenite `no_send_after_close`.
    assert_true(kind_of_send(ws) == WsErrorKind.SEND_AFTER_CLOSING)
    var failed = False
    try:
        ws.ping(bytes())
    except:
        failed = True
    assert_true(failed)
    # A second close does nothing.
    ws.close()
    assert_equal(ws.pending(), 0)
    var data = text_frame("still here", True, False)
    data.extend(raw(OpCode.PING, bytes(7), True, False))
    data.extend(close_frame(1000, "", False))
    ws.receive(data)
    var m = Message()
    assert_true(ws.read(m))
    assert_equal(m.text(), "still here")
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.PING)
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.CLOSE)
    assert_true(ws.state == WsState.CLOSE_ACKNOWLEDGED)
    assert_true(ws.should_close())
    assert_equal(ws.pending(), 0)
    assert_true(ws.peer_closed())


def test_server_close_waits_for_reply() raises:
    var ws = WebSocket(Role.SERVER)
    ws.close(CloseCode.AWAY, "")
    assert_false(ws.should_close())
    ws.receive(close_frame(1001))
    var m = Message()
    assert_true(ws.read(m))
    assert_true(ws.should_close())


def test_close_without_code() raises:
    var ws = WebSocket(Role.SERVER)
    ws.close(CloseCode.STATUS)
    var out = frames(take_output(ws))
    assert_equal(len(out[0].payload), 0)


def test_reset_and_terminated() raises:
    var ws = WebSocket(Role.SERVER)
    assert_false(ws.peer_closed())
    assert_true(ws.should_close())
    var m = Message()
    var kinds = List[WsErrorKind]()
    try:
        _ = ws.read(m)
    except e:
        kinds.append(e.kind)
    try:
        ws.send_binary(bytes(1))
    except e:
        kinds.append(e.kind)
    try:
        ws.close()
    except e:
        kinds.append(e.kind)
    assert_equal(len(kinds), 3)
    for kind in kinds:
        assert_true(kind == WsErrorKind.ALREADY_CLOSED)


def test_usage_limits() raises:
    var ws = WebSocket(Role.SERVER)
    var kinds = List[WsErrorKind]()
    try:
        ws.close(CloseCode.NORMAL, String("r") * 124)
    except e:
        kinds.append(e.kind)
    try:
        ws.pong(List[UInt8](length=126, fill=0))
    except e:
        kinds.append(e.kind)
    assert_equal(len(kinds), 2)
    assert_true(kinds[0] == WsErrorKind.PROTOCOL)
    assert_true(kinds[1] == WsErrorKind.PROTOCOL)
    assert_true(ws.can_write())


def test_write_buffer_full() raises:
    # Back pressure: the output that waits for the peer has a limit, and
    # an automatic pong goes in anyway, as tungstenite `auto_pong_flush`.
    var config = WsConfig()
    config.max_write_buffer_size = 16
    var ws = WebSocket(Role.SERVER, config)
    ws.send_text("0123456789")
    assert_true(kind_of_send(ws) == WsErrorKind.WRITE_BUFFER_FULL)
    ws.receive(raw(OpCode.PING, bytes(1, 2, 3)))
    var m = Message()
    assert_true(ws.read(m))
    var out = frames(take_output(ws))
    assert_equal(len(out), 2)
    assert_true(out[1].opcode == OpCode.PONG)
    ws.send_text("fits now")


def test_buffers() raises:
    var ws = WebSocket(Role.CLIENT)
    ws.reserve(100)
    assert_true(ws.space() >= 100)
    var frame = text_frame("abc", True, False)
    frame.extend(text_frame("de", True, False))
    var at = ws.write_pointer()
    var index = 0
    while index < len(frame) - 2:
        at[unsafe_offset=index] = frame[index]
        index += 1
    ws.commit(len(frame) - 2)
    var m = Message()
    assert_true(ws.read(m))
    assert_equal(m.text(), "abc")
    assert_false(ws.read(m))
    assert_equal(ws.buffered(), 2)
    # A large reserve moves the unread bytes to the front.
    ws.reserve(1 << 16)
    ws.receive(Span(frame)[len(frame) - 2 :])
    assert_true(ws.read(m))
    assert_equal(m.text(), "de")
    # With nothing unread, the buffer starts again at the front.
    ws.receive(text_frame("f", True, False))
    assert_true(ws.read(m))
    ws.reserve(1)
    assert_equal(ws.buffered(), 0)
    # A move to the front can make enough room without a larger buffer.
    var other = WebSocket(Role.CLIENT)
    other.receive(text_frame(String("x") * 60, True, False))
    other.receive(bytes(0x81, 0x05))
    assert_true(other.read(m))
    var size = len(other.input)
    other.reserve(other.space() + 1)
    assert_equal(len(other.input), size)
    assert_equal(other.buffered(), 2)


def test_types() raises:
    assert_true(Role.SERVER.is_valid())
    assert_false(Role(2).is_valid())
    assert_equal(String(Role.SERVER), "server")
    assert_equal(String(Role.CLIENT), "client")
    assert_true(WsState.TERMINATED.is_valid())
    assert_false(WsState(5).is_valid())
    assert_equal(String(WsState.CLOSED_BY_US), "1")
    assert_true(MessageKind.CLOSE.is_valid())
    assert_false(MessageKind(5).is_valid())
    assert_equal(String(MessageKind.TEXT), "text")
    assert_equal(String(MessageKind.PONG), "pong")
    var m = Message()
    assert_true(m.kind == MessageKind.TEXT)
    assert_equal(m.text(), "")


def test_errors() raises:
    assert_equal(String(WsErrorKind.PROTOCOL), "protocol")
    assert_equal(WsErrorKind.TIMEOUT.text(), "timeout")
    assert_equal(WsErrorKind(10).text(), "invalid")
    assert_true(WsErrorKind.IO.is_valid())
    assert_false(WsErrorKind(10).is_valid())
    var e = WsError.protocol("bad")
    assert_equal(Int(e.close_code), 1002)
    assert_equal(String(e), "protocol: bad")
    var other = WsError.of(WsErrorKind.TIMEOUT, "late")
    assert_equal(Int(other.close_code), 0)
    assert_equal(other.status, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
