# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.protocol`: messages, fragments, control frames, the
closing handshake, limits and failures.

Ported from tungstenite 0.30.0 `src/protocol/mod.rs` (`receive_messages`,
`size_limiting_text_fragmented`, `size_limiting_binary`),
`src/protocol/frame/mod.rs` (`read_frames`, `from_partially_read`,
`write_frames`, `size_limit_hit`), `tests/no_send_after_close.rs` and
`tests/receive_after_init_close.rs`. The Autobahn testsuite cases of
sections 1 to 7 that need no network are here too, by case number.
"""

from _wsutil import Seen, close_frame, frames, raw, take_output, text_frame
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


def server() -> WebSocket:
    return WebSocket(Role.SERVER)


def client() -> WebSocket:
    return WebSocket(Role.CLIENT)


def fails(
    mut ws: WebSocket, data: List[UInt8], kind: WsErrorKind, code: Int
) raises:
    """The bytes fail the connection with an error and a close code."""
    ws.receive(data)
    var message = Message()
    try:
        while ws.read(message):
            pass
    except e:
        assert_true(e.kind == kind, String(e))
        assert_equal(Int(e.close_code), code)
        assert_true(ws.should_close())
        var out = frames(take_output(ws))
        if code == 0:
            assert_equal(len(out), 0)
        else:
            assert_true(out[len(out) - 1].opcode == OpCode.CLOSE)
            assert_equal(out[len(out) - 1].code(), code)
        return
    raise Error("no error")


def bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for value in values:
        out.append(UInt8(value))
    return out^


def test_receive_messages() raises:
    # tungstenite `receive_messages`: a client reads unmasked frames.
    var ws = client()
    ws.receive(
        bytes(
            0x89,
            0x02,
            0x01,
            0x02,
            0x8A,
            0x01,
            0x03,
            0x01,
            0x07,
            0x48,
            0x65,
            0x6C,
            0x6C,
            0x6F,
            0x2C,
            0x20,
            0x80,
            0x06,
            0x57,
            0x6F,
            0x72,
            0x6C,
            0x64,
            0x21,
            0x82,
            0x03,
            0x01,
            0x02,
            0x03,
        )
    )
    var m = Message()
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.PING)
    assert_true(m.data == bytes(1, 2))
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.PONG)
    assert_true(m.data == bytes(3))
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.TEXT)
    assert_equal(m.text(), "Hello, World!")
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.BINARY)
    assert_true(m.data == bytes(1, 2, 3))
    assert_false(ws.read(m))
    # The client answered the ping with a masked pong.
    var out = frames(take_output(ws))
    assert_equal(len(out), 1)
    assert_true(out[0].opcode == OpCode.PONG)
    assert_true(out[0].masked)
    assert_true(out[0].payload == bytes(1, 2))


def test_read_frames_partially() raises:
    # tungstenite `read_frames` and `from_partially_read`: one byte at a
    # time, and a tail that stays in the buffer.
    var ws = client()
    var data = bytes(
        0x82,
        0x07,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x82,
        0x03,
        0x03,
        0x02,
        0x01,
        0x99,
    )
    var m = Message()
    var got = 0
    var index = 0
    while index < len(data):
        var one = List[UInt8]()
        one.append(data[index])
        ws.receive(one)
        if ws.read(m):
            got += 1
        index += 1
    assert_equal(got, 2)
    assert_true(m.data == bytes(3, 2, 1))
    assert_equal(ws.buffered(), 1)


def test_write_frames() raises:
    # tungstenite `write_frames`: a server sends unmasked frames.
    var ws = server()
    ws.ping(bytes(0x04, 0x05))
    ws.pong(bytes(0x01))
    assert_true(
        take_output(ws) == bytes(0x89, 0x02, 0x04, 0x05, 0x8A, 0x01, 0x01)
    )
    assert_equal(ws.pending(), 0)


def test_send_messages() raises:
    var ws = server()
    ws.send_text("hi")
    ws.send_binary(bytes(9))
    ws.send_fragment(OpCode.TEXT, False, "a".as_bytes())
    ws.send_fragment(OpCode.CONTINUE, True, "b".as_bytes())
    var out = frames(take_output(ws))
    assert_equal(len(out), 4)
    assert_equal(out[0].text(), "hi")
    assert_true(out[1].opcode == OpCode.BINARY)
    assert_false(out[2].fin)
    assert_true(out[3].opcode == OpCode.CONTINUE)
    assert_false(out[0].masked)
    # The output can go out in parts.
    ws.send_text("hello")
    assert_equal(ws.pending(), 7)
    ws.advance(3)
    assert_equal(ws.pending(), 4)
    assert_equal(Int(ws.output()[unsafe_offset=0]), Int(ord("e")))
    ws.advance(4)
    assert_equal(ws.pending(), 0)


def test_client_masks() raises:
    var ws = client()
    ws.send_text("masked text")
    var data = take_output(ws)
    assert_equal(Int(data[1]) & 0x80, 0x80)
    var out = frames(data)
    assert_equal(out[0].text(), "masked text")
    # A server reads it.
    var peer = server()
    peer.receive(data)
    var m = Message()
    assert_true(peer.read(m))
    assert_equal(m.text(), "masked text")


def test_large_messages() raises:
    # Autobahn 1.1.6 and 1.2.6: 64 KiB and more, through every length form.
    var sizes: List[Int] = [0, 125, 126, 65535, 65536]
    for size in sizes:
        var payload = List[UInt8](length=size, fill=0x2A)
        var ws = server()
        ws.receive(raw(OpCode.BINARY, payload))
        var m = Message()
        assert_true(ws.read(m))
        assert_equal(len(m.data), size)
        assert_true(m.data == payload)


def test_size_limiting_binary() raises:
    # tungstenite `size_limiting_binary`.
    var config = WsConfig()
    config.max_message_size = 2
    var ws = WebSocket(Role.CLIENT, config)
    fails(ws, bytes(0x82, 0x03, 0x01, 0x02, 0x03), WsErrorKind.CAPACITY, 1009)


def test_size_limiting_text_fragmented() raises:
    # tungstenite `size_limiting_text_fragmented`: 13 > 10.
    var config = WsConfig()
    config.max_message_size = 10
    var ws = WebSocket(Role.CLIENT, config)
    var data = bytes(
        0x01,
        0x07,
        0x48,
        0x65,
        0x6C,
        0x6C,
        0x6F,
        0x2C,
        0x20,
        0x80,
        0x06,
        0x57,
        0x6F,
        0x72,
        0x6C,
        0x64,
        0x21,
    )
    ws.receive(data)
    var m = Message()
    var message = String()
    try:
        _ = ws.read(m)
    except e:
        message = e.message
    assert_equal(message, "Message too long: 13 > 10")


def test_frame_size_limit_hit() raises:
    # tungstenite `size_limit_hit`: the header alone is enough.
    var config = WsConfig()
    config.max_frame_size = 5
    var ws = WebSocket(Role.CLIENT, config)
    fails(ws, bytes(0x82, 0x07, 0x01), WsErrorKind.CAPACITY, 1009)
    # A 64-bit length with the top bit set fails too.
    var other = client()
    fails(
        other,
        bytes(0x82, 127, 0x80, 0, 0, 0, 0, 0, 0, 0),
        WsErrorKind.CAPACITY,
        1009,
    )


def test_fragments() raises:
    # Autobahn 5.3 to 5.9: fragments with pings between them.
    var ws = server()
    var data = text_frame("frag", False)
    data.extend(raw(OpCode.PING, "p".as_bytes()))
    data.extend(raw(OpCode.CONTINUE, "men".as_bytes(), False))
    data.extend(raw(OpCode.CONTINUE, "ted".as_bytes(), True))
    ws.receive(data)
    var m = Message()
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.PING)
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.TEXT)
    assert_equal(m.text(), "fragmented")
    # A fragmented binary message.
    var bin = raw(OpCode.BINARY, bytes(1), False)
    bin.extend(raw(OpCode.CONTINUE, bytes(2), True))
    ws.receive(bin)
    assert_true(ws.read(m))
    assert_true(m.kind == MessageKind.BINARY)
    assert_true(m.data == bytes(1, 2))
    var out = frames(take_output(ws))
    assert_true(out[0].opcode == OpCode.PONG)


def test_protocol_errors() raises:
    # Autobahn 3.x: reserved bits.
    var a = server()
    fails(
        a,
        raw(OpCode.TEXT, "x".as_bytes(), True, True, 0x40),
        WsErrorKind.PROTOCOL,
        1002,
    )
    # Autobahn 4.x: reserved opcodes.
    var b = server()
    fails(b, raw(OpCode(3), bytes(), True, True), WsErrorKind.PROTOCOL, 1002)
    # Autobahn 5.1 and 5.2: fragmented control frames.
    var c = server()
    fails(c, raw(OpCode.PING, bytes(), False), WsErrorKind.PROTOCOL, 1002)
    # Autobahn 2.5: a ping of 126 bytes.
    var d = server()
    fails(
        d,
        raw(OpCode.PING, List[UInt8](length=126, fill=1)),
        WsErrorKind.PROTOCOL,
        1002,
    )
    # Autobahn 5.9: a continuation with nothing to continue.
    var e = server()
    fails(e, raw(OpCode.CONTINUE, "x".as_bytes()), WsErrorKind.PROTOCOL, 1002)
    # Autobahn 5.18: a new text frame inside a fragmented message.
    var f = server()
    var two = text_frame("a", False)
    two.extend(text_frame("b"))
    fails(f, two, WsErrorKind.PROTOCOL, 1002)
    # RFC 6455 section 5.1: masking.
    var g = server()
    fails(g, text_frame("a", True, False), WsErrorKind.PROTOCOL, 1002)
    var h = client()
    fails(h, text_frame("a"), WsErrorKind.PROTOCOL, 1002)


def test_accept_unmasked_frames() raises:
    var config = WsConfig()
    config.accept_unmasked_frames = True
    var ws = WebSocket(Role.SERVER, config)
    ws.receive(text_frame("plain", True, False))
    var m = Message()
    assert_true(ws.read(m))
    assert_equal(m.text(), "plain")


def test_invalid_utf8() raises:
    # Autobahn 6.3.1: one frame.
    var a = server()
    fails(
        a,
        raw(
            OpCode.TEXT,
            bytes(
                0xCE,
                0xBA,
                0xE1,
                0xBD,
                0xB9,
                0xCF,
                0x83,
                0xCE,
                0xBC,
                0xCE,
                0xB5,
                0xED,
                0xA0,
                0x80,
                0x65,
                0x64,
                0x69,
                0x74,
                0x65,
                0x64,
            ),
        ),
        WsErrorKind.UTF8,
        1007,
    )
    # Autobahn 6.4.1: fail fast, in the first fragment.
    var b = server()
    fails(b, raw(OpCode.TEXT, bytes(0xF4, 0x90), False), WsErrorKind.UTF8, 1007)
    # A continuation that breaks the text.
    var c = server()
    var cont = raw(OpCode.TEXT, bytes(0xCE), False)
    cont.extend(raw(OpCode.CONTINUE, bytes(0x41)))
    fails(c, cont, WsErrorKind.UTF8, 1007)
    # A text that ends inside a sequence.
    var d = server()
    fails(d, raw(OpCode.TEXT, bytes(0xCE)), WsErrorKind.UTF8, 1007)
    var e = server()
    var tail = raw(OpCode.TEXT, bytes(0x41), False)
    tail.extend(raw(OpCode.CONTINUE, bytes(0xCE)))
    fails(e, tail, WsErrorKind.UTF8, 1007)
    # A binary message is not checked.
    var f = server()
    f.receive(raw(OpCode.BINARY, bytes(0xFF)))
    var m = Message()
    assert_true(f.read(m))


def test_fragmented_limit() raises:
    var config = WsConfig()
    config.max_message_size = 3
    var ws = WebSocket(Role.SERVER, config)
    var data = raw(OpCode.BINARY, bytes(1, 2), False)
    data.extend(raw(OpCode.CONTINUE, bytes(3, 4), True))
    fails(ws, data, WsErrorKind.CAPACITY, 1009)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
