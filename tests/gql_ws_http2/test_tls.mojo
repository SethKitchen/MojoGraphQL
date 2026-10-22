# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `H2WebSocket` over the `TlsTransport` of `gql_https2`: the
extended `CONNECT` of RFC 8441 on HTTP/2 over TLS, after ALPN chose `h2`.
The server is a `TlsProtocol` of `gql_tls` that runs a `WsH2Session` on
each connection. There is no upstream suite; the cases follow
tests/gql_ws_http2/test_client.mojo and RFC 8441 section 4."""

from std.testing import TestSuite, assert_equal, assert_true
from std.time import perf_counter_ns

from _certs import test_certs
from _h2ws import Echo, Plain
from gql_http.server import ServerConfig as HttpConfig
from gql_http.socket import IPv4Address, Sys
from gql_tls.client import HttpsEndpoint, open_tls
from gql_tls.context import TlsContext
from gql_tls.openssl import OpenSsl
from gql_tls.server import TlsProtocol, listen_tls
from gql_https2.transport import TlsTransport
from gql_ws.error import WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, WsConfig
from gql_ws.server import Sockets
from gql_ws_http2.client import H2WebSocket
from gql_ws_http2.session import WsH2Session

comptime GTW = "graphql-transport-ws"


struct WsH2Tls(TlsProtocol):
    """WebSockets on each HTTP/2 connection that ALPN gives."""

    var http: Plain
    var handler: Echo
    var sockets: Sockets
    var conns: List[Int]
    var sessions: List[WsH2Session]

    def __init__(out self):
        self.http = Plain()
        self.handler = Echo()
        self.sockets = Sockets(WsConfig(), 30000)
        self.conns = List[Int]()
        self.sessions = List[WsH2Session]()

    def protocol(self) -> String:
        return "h2"

    def _index(self, conn: Int) -> Int:
        var index = 0
        while index < len(self.conns):
            if self.conns[index] == conn:
                return index
            index += 1
        return -1

    def open(mut self, conn: Int, mut out: List[UInt8]) raises:
        var session = WsH2Session(protocols=[GTW], path="/graphql")
        session.start()
        out.extend(Span(session.session.conn.out))
        session.session.conn.out.clear()
        self.conns.append(conn)
        self.sessions.append(session^)

    def receive(
        mut self, conn: Int, data: List[UInt8], mut out: List[UInt8]
    ) raises -> Bool:
        ref session = self.sessions[self._index(conn)]
        session.receive(self.http, self.handler, self.sockets, Span(data))
        session.flush(self.handler, self.sockets)
        out.extend(Span(session.session.conn.out))
        session.session.conn.out.clear()
        return not session.is_done()

    def close(mut self, conn: Int):
        var index = self._index(conn)
        if index < 0:
            return
        self.sessions[index].close_all(self.handler, self.sockets)
        _ = self.sessions.pop(index)
        _ = self.conns.pop(index)


def start_server() raises -> Tuple[Int, Int]:
    """Fork the TLS server; return its pid and its TCP port."""
    var certs = test_certs()
    var protocols: List[String] = ["h2", "http/1.1"]
    var context = TlsContext.server(
        OpenSsl(), certs.cert, certs.key, protocols^
    )
    var config = HttpConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    var server = listen_tls(Plain(), context^, config, WsH2Tls())
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            server.run()
        except:
            pass
        sys.exit_now(0)
    var port = server.port
    server.close()
    return (pid, port)


def stop(pid: Int):
    var sys = Sys()
    _ = sys.kill(pid, 9)
    _ = sys.wait(pid, True)


def connect(port: Int) raises -> H2WebSocket[TlsTransport]:
    """Open TLS with ALPN `h2`, and wrap the stream."""
    var offered: List[String] = ["h2"]
    var context = TlsContext.client(
        OpenSsl(), offered^, test_certs().cert, True
    )
    var authority = "localhost:" + String(port)
    var endpoint = HttpsEndpoint(
        IPv4Address.LOOPBACK, port, "localhost", authority, "/graphql"
    )
    var sys = Sys()
    var deadline = Int(perf_counter_ns()) + 5_000_000_000
    var stream = open_tls(sys, context, endpoint, deadline, 5000)
    assert_equal(stream.protocol, "h2")
    return H2WebSocket[TlsTransport](TlsTransport(stream^, sys.copy()))


def test_echo_over_tls() raises:
    var server = start_server()
    var socket = connect(server[1])
    var authority = "localhost:" + String(server[1])
    socket.handshake("https", authority, "/graphql", [GTW])
    assert_equal(socket.protocol, GTW)
    socket.send_text("who")
    var message = Message()
    assert_true(socket.read(message, 2000))
    assert_equal(String(message.text()), GTW + " /graphql")
    var big = String("y") * (1 << 18)
    socket.send_text(big)
    assert_true(socket.read(message, 5000))
    assert_equal(String(message.text()).byte_length(), 1 << 18)
    socket.close(CloseCode.NORMAL, "bye")
    var closed = False
    var turns = 0
    while turns < 10:
        try:
            _ = socket.read(message, 2000)
        except e:
            closed = e.kind == WsErrorKind.CLOSED
            break
        turns += 1
    assert_true(closed)
    stop(server[0])


def test_refused_over_tls() raises:
    var server = start_server()
    var socket = connect(server[1])
    var raised = False
    try:
        socket.handshake("https", "localhost", "/other", [GTW])
    except e:
        raised = True
        assert_equal(e.kind, WsErrorKind.HANDSHAKE)
        assert_equal(e.status, 404)
    assert_true(raised)
    stop(server[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
