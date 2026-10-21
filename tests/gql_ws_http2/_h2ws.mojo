# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A WebSocket handler, an HTTP handler, and a rig that joins a
`WsH2Session` to a client `Connection` in memory, for the gql_ws_http2
suites."""

from std.memory import unsafe_memcpy

from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import EAGAIN, Sys
from gql_http2.connection import Config, Connection, EventKind, Role
from gql_http2.session import Transport
from gql_http2.hpack import HeaderList
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind, Role as WsRole, WebSocket
from gql_ws.protocol import WsConfig
from gql_ws.server import Sockets, WsHandler
from gql_ws_http2.handshake import client_head
from gql_ws_http2.session import WsH2Session


struct Echo(WsHandler):
    """Echoes each message. `close` closes with 1000 `bye`, `boom` raises,
    `who` answers the protocol and the path, `flood` fills the output."""

    var opened: Int
    var closed: Int
    var code: Int
    var reason: String
    var fail_open: Bool
    var last: Int
    var full: Int
    var tick: String
    """A text that `on_tick` sends once to the last WebSocket."""
    var extra_fd: Int
    """What `fd` returns."""
    var wait: Int
    """What `wait_ms` returns."""

    def __init__(out self):
        self.opened = 0
        self.closed = 0
        self.code = 0
        self.reason = String()
        self.fail_open = False
        self.last = -1
        self.full = 0
        self.tick = String()
        self.extra_fd = -1
        self.wait = -1

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        self.opened += 1
        self.last = id
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
        elif text.startswith('{"type":"connection_init"'):
            _ = sockets.send_text(id, '{"type":"connection_ack"}')
        elif text == "flood":
            var big = String("x") * (1 << 16)
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
        if self.tick.byte_length() > 0 and self.last >= 0:
            _ = sockets.send_text(self.last, self.tick)
            self.tick = String()

    def fd(self) -> Int:
        return self.extra_fd

    def wait_ms(self) -> Int:
        return self.wait


struct Plain(Handler):
    """Answers `http <target>`."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.write_text("http ")
        response.write_text(request.target())


struct Rig(Movable):
    """A server session and a client connection, joined in memory."""

    var session: WsH2Session
    var client: Connection
    var sockets: Sockets
    var echo: Echo
    var plain: Plain

    def __init__(
        out self,
        protocols: List[String] = ["graphql-transport-ws"],
        path: String = "",
        ws: WsConfig = WsConfig(),
        config: Config = Config(),
        client: Config = Config(),
    ) raises:
        self.session = WsH2Session(config, protocols=protocols, path=path)
        self.client = Connection(Role.CLIENT, client)
        self.sockets = Sockets(ws, 1000)
        self.echo = Echo()
        self.plain = Plain()
        self.session.start()
        self.client.start()
        self.pump()

    def to_server(mut self):
        """Give the client's bytes to the server."""
        var data = self.client.out.copy()
        self.client.out.clear()
        self.session.receive(self.plain, self.echo, self.sockets, Span(data))

    def to_client(mut self):
        """Give the server's bytes to the client."""
        var data = self.session.session.conn.out.copy()
        self.session.session.conn.out.clear()
        self.client.receive(Span(data))

    def pump(mut self):
        """Move bytes both ways until neither end sends."""
        var turn = 0
        while turn < 20 and (
            len(self.client.out) > 0 or len(self.session.session.conn.out) > 0
        ):
            self.to_server()
            self.to_client()
            turn += 1

    def open(
        mut self,
        path: StringSlice = "/graphql",
        protocols: List[String] = ["graphql-transport-ws"],
    ) raises -> Int:
        """Send an extended `CONNECT`, and return its stream."""
        var id = self.client.open_stream()
        self.client.send_headers(
            id, client_head("http", "localhost", path, protocols), False
        )
        self.pump()
        return id

    def status(self, id: Int) -> Int:
        """The status of the answer of a stream, or 0."""
        var slot = self.client.find(id)
        if slot < 0:
            return 0
        return self.client.streams[slot].status

    def send(mut self, id: Int, mut ws: WebSocket) raises:
        """Send the output of a client WebSocket on a stream."""
        var data = List[UInt8]()
        data.extend(Span(unsafe_ptr=ws.output(), length=ws.pending()))
        ws.advance(ws.pending())
        self.client.send_data(id, Span(data), False)
        self.pump()

    def take(mut self, id: Int, mut ws: WebSocket):
        """Give the content of a stream to a client WebSocket."""
        var slot = self.client.find(id)
        if slot < 0:
            return
        ws.receive(Span(self.client.streams[slot].body))
        self.client.streams[slot].body.clear()

    def texts(mut self, id: Int, mut ws: WebSocket) raises -> List[String]:
        """The text messages that a stream carries now."""
        self.take(id, ws)
        var out = List[String]()
        var message = Message()
        while ws.read(message):
            if message.kind == MessageKind.TEXT:
                out.append(String(message.text()))
        return out^


def client_ws() -> WebSocket:
    """A client WebSocket, for a stream."""
    return WebSocket(WsRole.CLIENT)


struct Loop(Transport):
    """A transport whose far end is a `WsH2Session` in memory. Each write
    goes to the server at once, and its answer waits for a read.

    `reads` and `writes` are results to return first, such as `-EINTR`;
    `silent` drops the writes, as a server that never answers; `hang_up`
    ends the stream once the answers are read; `read_chunk` limits each
    read. With `ready`, `fd` is a descriptor that `poll` finds ready at
    once: the write end of a pipe without a reader."""

    var session: WsH2Session
    var sockets: Sockets
    var echo: Echo
    var plain: Plain
    var inbox: List[UInt8]
    var reads: List[Int]
    var writes: List[Int]
    var silent: Bool
    var hang_up: Bool
    var read_chunk: Int
    var ready_fd: Int
    var sys: Sys

    def __init__(
        out self,
        protocols: List[String] = ["graphql-transport-ws"],
        path: String = "",
        config: Config = Config(),
        connect_protocol: Bool = True,
        ready: Bool = False,
    ):
        self.session = WsH2Session(config, protocols=protocols, path=path)
        self.session.session.conn.local.enable_connect_protocol = (
            connect_protocol
        )
        self.sockets = Sockets(WsConfig(), 1000)
        self.echo = Echo()
        self.plain = Plain()
        self.inbox = List[UInt8]()
        self.reads = List[Int]()
        self.writes = List[Int]()
        self.silent = False
        self.hang_up = False
        self.read_chunk = 0
        self.sys = Sys()
        self.ready_fd = -1
        if ready:
            var ends = self.sys.pipe()
            self.sys.close(ends[0])
            self.ready_fd = ends[1]
        self.session.start()
        self._move()

    def _move(mut self):
        """Move the output of the server to the inbox."""
        self.inbox.extend(Span(self.session.session.conn.out))
        self.session.session.conn.out.clear()

    def read(
        mut self, data: Pointer[UInt8, MutUntrackedOrigin], size: Int
    ) -> Int:
        if len(self.reads) > 0:
            return self.reads.pop(0)
        if len(self.inbox) == 0:
            return 0 if self.hang_up else -EAGAIN
        var n = min(size, len(self.inbox))
        if self.read_chunk > 0:
            n = min(n, self.read_chunk)
        unsafe_memcpy(dest=data, src=self.inbox.unsafe_ptr(), count=n)
        var rest = List[UInt8]()
        rest.extend(Span(self.inbox)[n:])
        self.inbox = rest^
        return n

    def write(
        mut self, data: Pointer[UInt8, ImmUntrackedOrigin], size: Int
    ) -> Int:
        if len(self.writes) > 0:
            return self.writes.pop(0)
        if self.silent:
            return size
        self.session.receive(
            self.plain,
            self.echo,
            self.sockets,
            Span[UInt8, ImmUntrackedOrigin](unsafe_ptr=data, length=size),
        )
        self._move()
        return size

    def push(mut self):
        """Move what the server sent outside a read, after a handler sent
        on `sockets`."""
        self.session.flush(self.echo, self.sockets)
        self._move()

    def close(mut self):
        if self.ready_fd >= 0:
            self.sys.close(self.ready_fd)
            self.ready_fd = -1

    def fd(self) -> Int:
        return self.ready_fd
