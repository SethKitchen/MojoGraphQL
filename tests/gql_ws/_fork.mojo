# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Child processes for the client suites: a gql_ws server, and a scripted
peer that answers the handshake with exact bytes."""

from _server_util import Echo, Plain
from gql_http.server import Listener, open_listener
from gql_http.socket import IPv4Address, POLLIN, SIGKILL, Sys
from gql_http.parser import Limits, RequestReader
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.handshake import server_response
from gql_ws.server import Server, ServerConfig, WsHandler


@fieldwise_init
struct Child(Movable):
    """A running child process and its port."""

    var pid: Int
    var port: Int

    def stop(self):
        """Kill the child and wait for it."""
        var sys = Sys()
        _ = sys.kill(self.pid, SIGKILL)
        _ = sys.wait(self.pid, True)


def _spin[W: WsHandler](mut server: Server[W, Plain]):
    """Run a loop for at most five seconds."""
    try:
        var turn = 0
        while turn < 5000:
            _ = server.poll(1)
            turn += 1
    except:
        pass


def serve_in_child[
    W: WsHandler
](var handler: W, config: ServerConfig) raises -> Child:
    """Run a server in a child process for at most five seconds."""
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            var server = Server(handler^, Plain(), config, listener, Sys())
            _spin(server)
        except:
            pass
        sys.exit_now(0)
    sys.close(listener.fd)
    return Child(pid, listener.port)


def script_in_child(
    reply: String, hold_ms: Int = 2000, upgrade: Bool = False
) raises -> Child:
    """Accept one connection, read the request head, send `reply`, and
    keep the connection for `hold_ms`. An empty reply closes at once.
    With `upgrade`, a valid 101 answer goes before the reply."""
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        _ = sys.poll(listener.fd, POLLIN, 3000)
        var fd = sys.accept(listener.fd)
        var buffer = List[UInt8](length=4096, fill=0)
        var got = String()
        var turn = 0
        while turn < 300 and not got.endswith("\r\n\r\n"):
            _ = sys.poll(fd, POLLIN, 10)
            var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
            if n > 0:
                got += String(unsafe_from_utf8=Span(buffer)[:n])
            turn += 1
        var out = List[UInt8]()
        if upgrade:
            var reader = RequestReader(Limits())
            reader.append(got.as_bytes())
            _ = reader.next()
            try:
                out.extend(
                    Span(
                        server_response(
                            reader.request, [GRAPHQL_TRANSPORT_WS_PROTOCOL]
                        ).response
                    )
                )
            except:
                pass
        out.extend(reply.as_bytes())
        if len(out) > 0:
            _ = sys.send(fd, out.unsafe_ptr(), len(out))
            # Read and drop what the client sends, until it closes.
            var waited = 0
            while waited < hold_ms:
                _ = sys.poll(fd, POLLIN, 10)
                if sys.recv(fd, buffer.unsafe_ptr(), len(buffer)) == 0:
                    break
                waited += 10
        sys.close(fd)
        sys.exit_now(0)
    sys.close(listener.fd)
    return Child(pid, listener.port)
