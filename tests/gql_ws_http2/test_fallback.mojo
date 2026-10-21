# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http2.fallback`: `connect_ws` against an h2c server
with the extended `CONNECT`, and against an HTTP/1.1 WebSocket server of
`gql_ws`, each in a child process.

There is no upstream suite. The cases follow RFC 8441 section 3.
"""

from _h2ws import Echo, Plain
from gql_http.server import open_listener
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_ws.client import ClientConfig
from gql_ws.error import WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message
from gql_ws.server import Server as WsServer
from gql_ws.server import ServerConfig as WsServerConfig
from gql_ws_http2.fallback import WsAnyClient, connect_transport, connect_ws
from gql_ws_http2.server import Server, ServerConfig
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime GTW = "graphql-transport-ws"


def _spin_h2(mut server: Server[Echo, Plain]):
    try:
        var turn = 0
        while turn < 5000:
            _ = server.poll(1)
            turn += 1
    except:
        pass


def _spin_h1(mut server: WsServer[Echo, Plain]):
    try:
        var turn = 0
        while turn < 5000:
            _ = server.poll(1)
            turn += 1
    except:
        pass


def _child(http2: Bool, path: String = "") raises -> Tuple[Int, Int]:
    """Run a server in a child process for at most five seconds; return
    its pid and its port."""
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            if http2:
                var config = ServerConfig()
                config.protocols = [GTW]
                config.path = path
                var server = Server(Echo(), Plain(), config, listener, Sys())
                _spin_h2(server)
            else:
                var config = WsServerConfig()
                config.protocols = [GTW]
                var server = WsServer(Echo(), Plain(), config, listener, Sys())
                _spin_h1(server)
        except:
            pass
        sys.exit_now(0)
    sys.close(listener.fd)
    return (pid, listener.port)


def _stop(pid: Int):
    var sys = Sys()
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)


def _url(port: Int, path: StringSlice = "/graphql") -> String:
    return "ws://127.0.0.1:" + String(port) + path


def _exchange(mut client: WsAnyClient) raises:
    """Echo a message, then close."""
    assert_equal(client.protocol(), GTW)
    client.send_text("hello")
    var message = Message()
    assert_true(client.read(message, 2000))
    assert_equal(String(message.text()), "hello")
    client.close(CloseCode.NORMAL, "bye")
    var closed = False
    var turns = 0
    while turns < 10:
        try:
            _ = client.read(message, 2000)
        except e:
            closed = e.kind == WsErrorKind.CLOSED
            break
        turns += 1
    assert_true(closed)


def test_http2() raises:
    var child = _child(True)
    var client = connect_ws(_url(child[1]), [GTW])
    assert_true(client.uses_http2())
    _exchange(client)
    _stop(child[0])


def test_http1() raises:
    var child = _child(False)
    var client = connect_ws(_url(child[1]), [GTW])
    assert_false(client.uses_http2())
    _exchange(client)
    _stop(child[0])


def test_refusal_does_not_fall_back() raises:
    var child = _child(True, "/graphql")
    var status = 0
    try:
        _ = connect_ws(_url(child[1], "/other"), [GTW])
    except e:
        status = e.status
    assert_equal(status, 404)
    _stop(child[0])


def test_connection_errors() raises:
    # No server: the error of the connection, without a second try.
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    var port = listener.port
    sys.close(listener.fd)
    var kind = WsErrorKind.CLOSED
    try:
        _ = connect_ws(_url(port), [GTW])
    except e:
        kind = e.kind
    assert_true(kind == WsErrorKind.IO)
    # A server that never answers: both tries time out.
    var silent = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    var config = ClientConfig()
    config.connect_timeout_ms = 100
    try:
        _ = connect_ws(_url(silent.port), [GTW], config)
    except e:
        kind = e.kind
    assert_true(kind == WsErrorKind.TIMEOUT)
    sys.close(silent.fd)


def test_transport() raises:
    var child = _child(True)
    var client = connect_transport(_url(child[1]), "", 2000)
    assert_true(client.socket.uses_http2())
    client.close()
    _stop(child[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
