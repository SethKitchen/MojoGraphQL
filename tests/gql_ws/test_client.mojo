# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws.client`, against a gql_ws server and a scripted peer
in child processes.

Ported from tungstenite 0.30.0 `tests/handshake.rs`,
`tests/connection_reset.rs` (`test_close_rx`, `test_close_tx`,
`test_ping_pong`), `tests/client_headers.rs`, `tests/url_feature.rs` and
`tests/wss_fails_when_no_tls.rs`.
"""

from _fork import Child, script_in_child, serve_in_child
from _server_util import Echo, config
from _wsutil import raw
from gql_http.server import open_listener
from gql_http.socket import (
    ECONNREFUSED,
    EINTR,
    Faults,
    IPv4Address,
    Sys,
    SysCall,
)
from gql_ws.client import ClientConfig, WsClient
from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode, OpCode
from gql_ws.protocol import Message, MessageKind
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def url(port: Int, path: StringSlice = "/graphql") -> String:
    return "ws://127.0.0.1:" + String(port) + String(path)


def failure(
    target: String,
    config: ClientConfig = ClientConfig(),
    var sys: Sys = Sys(),
    protocols: List[String] = [],
) -> WsError:
    try:
        var client = WsClient.connect(target, protocols, config, sys^)
        _ = client^
    except e:
        return e^
    return WsError.of(WsErrorKind(255), "connected")


def test_echo() raises:
    var c = config()
    c.protocols = ["graphql-transport-ws"]
    var child = serve_in_child(Echo(), c)
    var client = WsClient.connect(
        url(child.port, "/graphql?x=1"), ["graphql-transport-ws"]
    )
    assert_equal(client.protocol, "graphql-transport-ws")
    var m = Message()
    client.send_text("hello")
    assert_true(client.read(m, 2000))
    assert_equal(m.text(), "hello")
    client.send_binary("bin".as_bytes())
    assert_true(client.read(m, 2000))
    assert_true(m.kind == MessageKind.BINARY)
    client.send_text("who")
    assert_true(client.read(m, 2000))
    assert_equal(m.text(), "graphql-transport-ws /graphql")
    # tungstenite `test_ping_pong`: a ping from the server gets its pong.
    client.send_text("ping")
    assert_true(client.read(m, 2000))
    assert_true(m.kind == MessageKind.PING)
    client.ping("x".as_bytes())
    assert_true(client.read(m, 2000))
    assert_true(m.kind == MessageKind.PONG)
    # Nothing more comes.
    assert_false(client.read(m, 20))
    assert_false(client.read(m, 0))
    # tungstenite `test_close_tx`: the client closes.
    client.close()
    assert_true(client.read(m, 2000))
    assert_true(m.kind == MessageKind.CLOSE)
    var kind = WsErrorKind(255)
    try:
        _ = client.read(m, 2000)
    except e:
        kind = e.kind
    assert_true(kind == WsErrorKind.CLOSED)
    child.stop()


def test_server_closes() raises:
    # tungstenite `test_close_rx`: the server closes, the client answers.
    var child = serve_in_child(Echo(), config())
    var client = WsClient.connect(url(child.port))
    client.send_text("close")
    var m = Message()
    assert_true(client.read(m, 2000))
    assert_true(m.kind == MessageKind.CLOSE)
    assert_equal(m.text(), "bye")
    var kind = WsErrorKind(255)
    try:
        while client.read(m, 2000):
            pass
    except e:
        kind = e.kind
    assert_true(kind == WsErrorKind.CLOSED)
    client.disconnect()
    client.disconnect()
    child.stop()


def test_url_errors() raises:
    # tungstenite `url_feature` and `wss_fails_when_no_tls`.
    assert_equal(
        failure("wss://localhost/").message,
        "URL error: TLS support not compiled in",
    )
    assert_equal(
        failure("http://localhost/").message,
        "URL error: URL scheme not supported",
    )
    assert_true(failure("no url").message.startswith("URL error: "))


def test_connect_errors() raises:
    # A port that nobody listens on.
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 1, False)
    var port = listener.port
    sys.close(listener.fd)
    assert_true(failure(url(port)).kind == WsErrorKind.IO)
    var a = Sys()
    a.faults = Faults(SysCall.RESOLVE, 2, 0, 1)
    assert_true(
        failure("ws://localhost:1/", ClientConfig(), a^).kind == WsErrorKind.IO
    )
    var b = Sys()
    b.faults = Faults(SysCall.SOCKET, 24, 0, 1)
    assert_true(failure(url(1), ClientConfig(), b^).kind == WsErrorKind.IO)
    var c = Sys()
    c.faults = Faults(SysCall.CONNECT, ECONNREFUSED, 0, 1)
    assert_true(failure(url(1), ClientConfig(), c^).kind == WsErrorKind.IO)
    var d = Sys()
    d.faults = Faults(SysCall.POLL, 9, 0, 1)
    assert_true(failure(url(port), ClientConfig(), d^).kind == WsErrorKind.IO)


def test_connect_timeout() raises:
    # A listener with a full queue does not answer the SYN.
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 0, False)
    var held = List[Int]()
    var index = 0
    while index < 4:
        var fd = sys.socket()
        _ = sys.connect(fd, IPv4Address.LOOPBACK, listener.port)
        held.append(fd)
        index += 1
    var c = ClientConfig()
    c.connect_timeout_ms = 100
    var error = failure(url(listener.port), c)
    assert_true(error.kind == WsErrorKind.TIMEOUT, String(error))
    for fd in held:
        sys.close(fd)
    sys.close(listener.fd)


def test_handshake_errors() raises:
    var refused = script_in_child(
        "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
    )
    var error = failure(url(refused.port))
    assert_true(error.kind == WsErrorKind.HANDSHAKE)
    assert_equal(error.status, 404)
    refused.stop()
    var garbage = script_in_child("garbage\r\n\r\n")
    assert_equal(
        failure(url(garbage.port)).message, "invalid handshake response"
    )
    garbage.stop()
    var dropped = script_in_child("")
    assert_equal(failure(url(dropped.port)).message, "Handshake not finished")
    dropped.stop()
    var slow = script_in_child("HTTP/1.1 101 Switching", 2000)
    var c = ClientConfig()
    c.connect_timeout_ms = 100
    assert_true(failure(url(slow.port), c).kind == WsErrorKind.TIMEOUT)
    slow.stop()
    # A long answer head grows the buffer.
    var long = script_in_child(
        "HTTP/1.1 400 Bad\r\nX-Pad: " + String("p") * 6000 + "\r\n\r\n"
    )
    assert_equal(failure(url(long.port)).status, 400)
    long.stop()


def test_reset_without_close() raises:
    var child = script_in_child("", 0, True)
    var client = WsClient.connect(url(child.port))
    var m = Message()
    var error = WsError.of(WsErrorKind(255), "")
    try:
        _ = client.read(m, 2000)
    except e:
        error = e^
    assert_true(error.kind == WsErrorKind.PROTOCOL)
    assert_equal(error.message, "Connection reset without closing handshake")
    child.stop()


def test_bad_frame_from_server() raises:
    # A masked frame from a server fails the connection.
    var frame = raw(OpCode.TEXT, "x".as_bytes(), True, True)
    var child = script_in_child(String(unsafe_from_utf8=frame), 500, True)
    var client = WsClient.connect(url(child.port))
    var m = Message()
    var kind = WsErrorKind(255)
    try:
        _ = client.read(m, 2000)
    except e:
        kind = e.kind
    assert_true(kind == WsErrorKind.PROTOCOL)
    child.stop()


def test_frames_with_the_answer() raises:
    var frame = raw(OpCode.TEXT, "first".as_bytes(), True, False)
    var child = script_in_child(String(unsafe_from_utf8=frame), 500, True)
    var client = WsClient.connect(url(child.port))
    var m = Message()
    assert_true(client.read(m, 0))
    assert_equal(m.text(), "first")
    child.stop()


def test_io_faults() raises:
    var child = serve_in_child(Echo(), config())
    var sys = Sys()
    var client = WsClient.connect(url(child.port), [], ClientConfig(), sys^)
    var m = Message()
    # Interrupted calls go on.
    client.sys.faults = Faults(SysCall.SEND, EINTR, 0, 1)
    client.send_text("a")
    # A read without a timeout waits.
    client.sys.faults = Faults(SysCall.RECV, 11, 0, 1)
    assert_true(client.read(m))
    client.send_text("a")
    client.sys.faults = Faults(SysCall.RECV, EINTR, 0, 1)
    assert_true(client.read(m, 2000))
    client.sys.faults = Faults(SysCall.POLL, EINTR, 0, 1)
    client.send_text("b")
    assert_true(client.read(m, 2000))
    # A send that would block waits; one that never can times out.
    client.sys.faults = Faults(SysCall.SEND, 11, 0, 1)
    client.send_text("c")
    assert_true(client.read(m, 2000))
    client.config.write_timeout_ms = 0
    client.sys.faults = Faults(SysCall.SEND, 11, 0, 1)
    var kinds = List[WsErrorKind]()
    try:
        client.send_text("d")
    except e:
        kinds.append(e.kind)
    client.config.write_timeout_ms = 30000
    client.sys.faults = Faults(SysCall.SEND, 32, 0, 1)
    try:
        client.send_text("e")
    except e:
        kinds.append(e.kind)
    client.sys.faults = Faults(SysCall.POLL, 9, 0, 1)
    try:
        _ = client.read(m, 50)
    except e:
        kinds.append(e.kind)
    client.sys.faults = Faults(SysCall.RECV, 104, 0, 1)
    try:
        _ = client.read(m, 50)
    except e:
        kinds.append(e.kind)
    assert_equal(len(kinds), 4)
    assert_true(kinds[0] == WsErrorKind.TIMEOUT)
    assert_true(kinds[1] == WsErrorKind.IO)
    assert_true(kinds[2] == WsErrorKind.IO)
    assert_true(kinds[3] == WsErrorKind.IO)
    child.stop()


def test_handshake_faults() raises:
    var child = serve_in_child(Echo(), config())
    var a = Sys()
    a.faults = Faults(SysCall.RECV, EINTR, 0, 1)
    var client = WsClient.connect(url(child.port), [], ClientConfig(), a^)
    client.send_text("ok")
    var m = Message()
    assert_true(client.read(m, 2000))
    var b = Sys()
    b.faults = Faults(SysCall.SEND, 11, 0, 1)
    var other = WsClient.connect(url(child.port), [], ClientConfig(), b^)
    other.send_text("ok")
    assert_true(other.read(m, 2000))
    var c = Sys()
    c.faults = Faults(SysCall.SEND, 32, 0, 1)
    assert_true(
        failure(url(child.port), ClientConfig(), c^).kind == WsErrorKind.IO
    )
    var d = ClientConfig()
    d.headers = "Origin: http://example\r\n"
    var third = WsClient.connect(url(child.port, "/"), [], d)
    third.send_text("ok")
    assert_true(third.read(m, 2000))
    child.stop()


def test_default_port() raises:
    # Port 80 has no server here: the URL without a port uses it.
    var error = failure("ws://127.0.0.1/")
    assert_true(error.kind == WsErrorKind.IO)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
