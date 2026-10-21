# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A WebSocket handler, an HTTP handler and a scripted client for the
server suites."""

from _net import connect, drain, send_all
from gql_http.body import BodyPoll
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import IPv4Address, Sys
from gql_ws.frame import CloseCode
from gql_ws.handshake import client_request
from gql_ws.protocol import Message, MessageKind, Role, WebSocket
from gql_ws.server import Server, ServerConfig, Sockets, WsHandler

comptime KEY = "dGhlIHNhbXBsZSBub25jZQ=="


struct Echo(WsHandler):
    """Echoes each message. `close` closes with 1000 `bye`, `boom` raises,
    `who` answers the protocol and the path, `flood` sends 64 MiB."""

    var opened: Int
    var closed: Int
    var code: Int
    var reason: String
    var ticks: Int
    var fail_open: Bool
    var extra_fd: Int
    var wait: Int
    var last: Int
    var full: Int
    var ids: List[Int]

    def __init__(out self):
        self.ids = List[Int]()
        self.opened = 0
        self.closed = 0
        self.code = 0
        self.reason = String()
        self.ticks = 0
        self.fail_open = False
        self.extra_fd = -1
        self.wait = -1
        self.last = -1
        self.full = 0

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        self.opened += 1
        self.last = id
        self.ids.append(id)
        if self.fail_open:
            raise Error("no")

    def on_message(
        mut self, mut sockets: Sockets, id: Int, message: Message
    ) raises:
        if message.kind == MessageKind.BINARY:
            _ = sockets.send_binary(id, message.data)
            return
        var text = message.text()
        if text == "close":
            _ = sockets.close(id, CloseCode.NORMAL, "bye")
        elif text == "boom":
            raise Error("boom")
        elif text == "who":
            _ = sockets.send_text(
                id, sockets.protocol(id) + " " + sockets.path(id)
            )
        elif text == "all":
            for other in self.ids:
                if other != id:
                    _ = sockets.send_text(other, "all")
        elif text == "ping":
            _ = sockets.ping(id, "p".as_bytes())
        elif text == "flood":
            var big = String("x") * (1 << 20)
            var index = 0
            while index < 64:
                try:
                    _ = sockets.send_text(id, big)
                except:
                    self.full += 1
                index += 1
        else:
            _ = sockets.send_text(id, text)

    def on_close(
        mut self, mut sockets: Sockets, id: Int, code: UInt16, reason: String
    ):
        self.closed += 1
        self.code = Int(code)
        self.reason = reason

    def on_tick(mut self, mut sockets: Sockets) raises:
        self.ticks += 1

    def fd(self) -> Int:
        return self.extra_fd

    def wait_ms(self) -> Int:
        return self.wait


@fieldwise_init
struct Plain(Handler):
    """Answers `http <target>`."""

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.write_text("http ")
        response.write_text(request.target())


struct Held(Handler):
    """Holds each response, and sends `a`, nothing for two polls, and `b`."""

    var turn: Int

    def __init__(out self):
        self.turn = 0

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.begin_chunked()
        response.hold()

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        self.turn += 1
        if self.turn == 1:
            out.extend("a".as_bytes())
            return BodyPoll.READY
        if self.turn <= 3:
            return BodyPoll.PENDING
        out.extend("b".as_bytes())
        return BodyPoll.DONE


def config() -> ServerConfig:
    var c = ServerConfig()
    c.http.host = IPv4Address.LOOPBACK
    c.http.port = 0
    return c^


struct Peer(Movable):
    """A client socket, and a client WebSocket for the frames."""

    var sys: Sys
    var fd: Int
    var data: List[UInt8]
    var closed: Bool
    var ws: WebSocket

    def __init__(out self, port: Int) raises:
        self.sys = Sys()
        self.fd = connect(self.sys, port)
        self.data = List[UInt8]()
        self.closed = False
        self.ws = WebSocket(Role.CLIENT)

    def send(mut self, data: Span[UInt8, _]) raises:
        send_all(self.sys, self.fd, data)

    def pump[
        W: WsHandler, H: Handler
    ](mut self, mut server: Server[W, H], turns: Int = 10) raises:
        """Run the loop and read until quiet for some turns, or closed."""
        var quiet = 0
        while quiet < turns and not self.closed:
            _ = server.poll(2)
            var before = len(self.data)
            self.closed = not drain(self.sys, self.fd, self.data)
            if len(self.data) == before:
                quiet += 1
            else:
                quiet = 0

    def text(self) -> String:
        return String(unsafe_from_utf8=Span(self.data))

    def upgrade[
        W: WsHandler, H: Handler
    ](
        mut self,
        mut server: Server[W, H],
        path: StringSlice = "/graphql",
        protocols: List[String] = [],
    ) raises:
        """Send the handshake and take the 101 answer."""
        self.send(client_request("x", path, KEY, protocols))
        self.pump(server)
        var text = self.text()
        var end = text.find("\r\n\r\n")
        if not text.startswith("HTTP/1.1 101") or end < 0:
            raise Error("no upgrade: " + text)
        var rest = List[UInt8](Span(self.data)[end + 4 :])
        self.data = rest^

    def send_ws_text(mut self, text: StringSlice) raises:
        self.ws.send_text(text)
        self.flush_ws()

    def flush_ws(mut self) raises:
        var count = self.ws.pending()
        var bytes = List[UInt8]()
        var at = self.ws.output()
        var index = 0
        while index < count:
            bytes.append(at[unsafe_offset=index])
            index += 1
        self.ws.advance(count)
        self.send(bytes)

    def messages(mut self) raises -> List[Message]:
        """Read the frames that came, as messages."""
        self.ws.receive(self.data)
        self.data.clear()
        var out = List[Message]()
        var m = Message()
        while self.ws.read(m):
            out.append(m.copy())
        return out^

    def close(mut self):
        self.sys.close(self.fd)
