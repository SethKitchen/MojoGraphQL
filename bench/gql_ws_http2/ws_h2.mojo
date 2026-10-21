# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the h2c WebSocket server of gql_ws_http2 under the load of
`_h2wsload.mojo`.

    mojo build -I . -o .cache/bin/ws_h2 bench/gql_ws_http2/ws_h2.mojo
    .cache/bin/ws_h2

`ws-h2/echo-roundtrip`: one server process echoes each text message, over
16 h2c connections with one WebSocket stream each (RFC 8441 extended
`CONNECT`); nanoseconds per round trip. The baseline in
`bench/baselines/rust-ws_http2` (h2 0.4.20 and tungstenite 0.30.0) runs
its server with one thread under the same load generator.
"""

from _h2wsload import run_echo
from gql_http.parser import Request
from gql_http.server import Handler, Listener, ResponseWriter, open_listener
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_http.status import Status
from gql_ws.protocol import Message, MessageKind
from gql_ws.server import Sockets, WsHandler
from gql_ws_http2.server import Server, ServerConfig


struct Echo(WsHandler):
    """Echoes each text message."""

    def __init__(out self):
        pass

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        pass

    def on_message(
        mut self, mut sockets: Sockets, id: Int, message: Message
    ) raises:
        if message.kind == MessageKind.TEXT:
            _ = sockets.send_text(id, message.text())

    def on_close(
        mut self, mut sockets: Sockets, id: Int, code: UInt16, reason: String
    ):
        pass

    def on_tick(mut self, mut sockets: Sockets) raises:
        pass

    def fd(self) -> Int:
        return -1

    def wait_ms(self) -> Int:
        return -1


struct NotFound(Handler):
    """Answers each request that is no WebSocket with 404."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.status = Status.NOT_FOUND


def _spin(mut server: Server[Echo, NotFound]):
    """Run a loop until the process is killed."""
    try:
        while True:
            _ = server.poll(-1)
    except:
        pass


def _serve(listener: Listener):
    """Run a server until the process is killed."""
    try:
        var config = ServerConfig()
        config.http.host = IPv4Address.LOOPBACK
        var server = Server(Echo(), NotFound(), config, listener, Sys())
        _spin(server)
    except:
        pass


def main() raises:
    """Run the workload and print its `BENCH` line."""
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 1024, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        _serve(listener)
        sys.exit_now(0)
    sys.close(listener.fd)
    run_echo("ws-h2/echo-roundtrip", listener.port)
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)
