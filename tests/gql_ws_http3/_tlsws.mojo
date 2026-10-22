# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Forked servers over TCP for the fallback tests: WebSockets on HTTP/2
over TLS (a `TlsProtocol` of `gql_tls` that runs a `WsH2Session` of
`gql_ws_http2` on each connection), and the h2c server of
`gql_ws_http2`."""

from _certs import test_certs
from _wsh3 import Echo, Plain
from gql_http.server import ServerConfig as HttpConfig
from gql_http.server import open_listener
from gql_http.socket import IPv4Address, Sys
from gql_tls.context import TlsContext
from gql_tls.openssl import OpenSsl
from gql_tls.server import TlsProtocol, listen_tls
from gql_ws.protocol import WsConfig
from gql_ws.server import Server as WsServer
from gql_ws.server import ServerConfig as WsServerConfig
from gql_ws.server import Sockets
from gql_ws_http2.server import Server as H2cServer
from gql_ws_http2.server import ServerConfig as H2cConfig
from gql_ws_http2.session import WsH2Session


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
        var session = WsH2Session(protocols=["graphql-transport-ws"])
        session.start()
        out.extend(Span(session.session.conn.out))
        session.session.conn.out.clear()
        self.conns.append(conn)
        self.sessions.append(session^)

    def receive(
        mut self, conn: Int, data: List[UInt8], mut out: List[UInt8]
    ) raises -> Bool:
        var index = self._index(conn)
        ref session = self.sessions[index]
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


def start_tls_ws_server(
    port: Int = 0, alpn: StaticString = "h2"
) raises -> Tuple[Int, Int]:
    """Fork a TLS server whose ALPN offers `alpn` and `http/1.1`, with
    WebSockets on HTTP/2. It returns the pid and the TCP port."""
    var certs = test_certs()
    var protocols = List[String]()
    protocols.append(String(alpn))
    protocols.append("http/1.1")
    var context = TlsContext.server(
        OpenSsl(), certs.cert, certs.key, protocols^
    )
    var config = HttpConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = port
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
    var bound = server.port
    server.close()
    return (pid, bound)


def start_h2c_ws_server(http2: Bool = True) raises -> Tuple[Int, Int]:
    """Fork the h2c server of `gql_ws_http2`, or the HTTP/1.1 server of
    `gql_ws`; return its pid and port."""
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        if http2:
            try:
                var config = H2cConfig()
                config.protocols = ["graphql-transport-ws"]
                var server = H2cServer(Echo(), Plain(), config, listener, Sys())
                try:
                    while True:
                        _ = server.poll(5)
                except:
                    pass
            except:
                pass
        else:
            try:
                var config = WsServerConfig()
                config.protocols = ["graphql-transport-ws"]
                var server = WsServer(Echo(), Plain(), config, listener, Sys())
                try:
                    while True:
                        _ = server.poll(5)
                except:
                    pass
            except:
                pass
        sys.exit_now(0)
    sys.close(listener.fd)
    return (pid, listener.port)
