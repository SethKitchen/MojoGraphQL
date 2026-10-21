# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A raw client for the gql_server_ws suite: a socket, and a client
`WebSocket` after the handshake, driven while the server loop runs in this
process. The WebSocket part is that of `tests/gql_ws_execution/_peer.mojo`.
"""

from gql_http.socket import ECONNRESET, IPv4Address, POLLOUT, Sys
from gql_server.plugin import ServerPlugin
from gql_server_ws.server import ApolloWsServer
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.handshake import client_request
from gql_ws.protocol import Message, MessageKind, Role, WebSocket
from gql_ws_execution.executor import Hooks


struct Peer(Movable):
    """A client of a server in this process."""

    var sys: Sys
    var fd: Int
    var ws: WebSocket

    def __init__(out self, port: Int) raises:
        self.sys = Sys()
        self.fd = self.sys.socket()
        _ = self.sys.set_no_delay(self.fd)
        var rc = self.sys.connect(self.fd, IPv4Address.LOOPBACK, port)
        if rc < 0 and rc != -115:
            raise Error("connect failed")
        _ = self.sys.poll(self.fd, POLLOUT, 2000)
        self.ws = WebSocket(Role.CLIENT)

    def send_bytes(mut self, data: Span[UInt8, _]) raises:
        var sent = 0
        while sent < len(data):
            var n = self.sys.send(
                self.fd, data.unsafe_ptr().unsafe_offset(sent), len(data) - sent
            )
            if n < 0:
                raise Error("send failed")
            sent += n

    def flush(mut self) raises:
        """Send the output of the client `WebSocket`, such as the reply to
        a close frame."""
        var count = self.ws.pending()
        var bytes = List[UInt8]()
        var at = self.ws.output()
        var index = 0
        while index < count:
            bytes.append(at[unsafe_offset=index])
            index += 1
        self.ws.advance(count)
        self.send_bytes(bytes)

    def pump[
        P: ServerPlugin, K: Hooks
    ](
        mut self, mut server: ApolloWsServer[P, K], turns: Int = 10
    ) raises -> List[UInt8]:
        """Run the loop and read what comes, until `turns` quiet turns or
        the end of the connection."""
        var out = List[UInt8]()
        var buffer = List[UInt8](length=65536, fill=0)
        var quiet = 0
        while quiet < turns:
            _ = server.poll(2)
            var n = self.sys.recv(self.fd, buffer.unsafe_ptr(), len(buffer))
            if n > 0:
                out.extend(Span(buffer)[:n])
                quiet = 0
            elif n == 0 or n == -ECONNRESET:
                break
            else:
                quiet += 1
        return out^

    def http[
        P: ServerPlugin, K: Hooks
    ](
        mut self, mut server: ApolloWsServer[P, K], request: String
    ) raises -> String:
        """Send an HTTP/1.1 request and return the text of the response."""
        self.send_bytes(request.as_bytes())
        var bytes = self.pump(server)
        return String(unsafe_from_utf8=Span(bytes))

    def open[
        P: ServerPlugin, K: Hooks
    ](mut self, mut server: ApolloWsServer[P, K], path: String = "/") raises:
        """Make the opening handshake of graphql-transport-ws."""
        self.send_bytes(
            client_request(
                "x",
                path,
                "dGhlIHNhbXBsZSBub25jZQ==",
                [GRAPHQL_TRANSPORT_WS_PROTOCOL],
            )
        )
        var head = self.pump(server)
        var text = String(unsafe_from_utf8=Span(head))
        var end = text.find("\r\n\r\n")
        if end < 0:
            raise Error("no handshake: " + text)
        self.ws.receive(Span(head)[end + 4 :])

    def send[
        P: ServerPlugin, K: Hooks
    ](
        mut self, mut server: ApolloWsServer[P, K], text: StringSlice
    ) raises -> List[String]:
        """Send a message and return the messages that come back."""
        self.ws.send_text(text)
        self.flush()
        return self.read(server)

    def read[
        P: ServerPlugin, K: Hooks
    ](mut self, mut server: ApolloWsServer[P, K]) raises -> List[String]:
        """Return the messages that come; a close is `close <code>`."""
        self.ws.receive(self.pump(server))
        var out = List[String]()
        var m = Message()
        while self.ws.read(m):
            if m.kind == MessageKind.CLOSE:
                out.append("close " + String(m.code.value))
            elif m.kind == MessageKind.TEXT:
                out.append(String(m.text()))
        return out^

    def close(mut self):
        self.sys.close(self.fd)
