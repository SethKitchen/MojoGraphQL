# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers for the tests of `gql_ws_http3` over real QUIC on loopback: the
handlers, a `Rig` that runs a `Server` and a raw QUIC client in one
thread, and forked servers for the client."""

from _certs import test_certs
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import IPv4Address, Sys
from gql_tls.openssl import OpenSsl
from gql_http3.client import H3Client
from gql_http3.error import H3ErrorCode
from gql_http3.frame import write_data_frame, write_headers_frame
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_http3.quic import Quic, QuicContext, ReadState
from gql_http3.server import (
    H3Config,
    TunnelEvent,
    TunnelEventKind,
    listen_h3,
)
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind
from gql_ws.server import Sockets, WsHandler
from gql_ws_http3.server import Server, ServerConfig, listen_ws_h3
from gql_ws_http3.tunnel import H3Tunnel


struct Echo(WsHandler):
    """Echoes each message. `close` closes with 1000 `bye`, `boom` raises,
    `who` answers the protocol and the path, `flood` fills the output,
    `stop` ends the loop of a forked server."""

    var opened: Int
    var closed: Int
    var code: Int
    var reason: String
    var fail_open: Bool
    var last: Int
    var full: Int
    var stop: Bool
    var tick: String
    """A text that `on_tick` sends once to the last WebSocket."""
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
        self.stop = False
        self.tick = String()
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
        elif text == "stop":
            self.stop = True
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
        return -1

    def wait_ms(self) -> Int:
        return self.wait


struct Plain(Handler):
    """Answers `http <target>`."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.write_text("http ")
        response.write_text(request.target())


def ws_config(path: String = "") -> ServerConfig:
    var c = ServerConfig()
    c.h3.host = IPv4Address.LOOPBACK
    c.h3.port = 0
    c.path = path
    c.protocols = ["graphql-transport-ws"]
    return c^


def make_server(path: String = "") raises -> Server[Echo, Plain]:
    var certs = test_certs()
    return listen_ws_h3(
        Echo(), Plain(), certs.cert, certs.key, ws_config(path), Quic(OpenSsl())
    )


def raw_head(
    method: StaticString,
    protocol: StaticString,
    path: StaticString,
    version: StaticString = "13",
) -> List[UInt8]:
    """A HEADERS frame; an empty value leaves its field out."""
    var fields = FieldList()
    fields.add_text(":method", method)
    if protocol.byte_length() > 0:
        fields.add_text(":protocol", protocol)
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", "localhost")
    if path.byte_length() > 0:
        fields.add_text(":path", path)
    fields.add_text("sec-websocket-version", version)
    var encoder = QpackEncoder()
    var block = List[UInt8]()
    var inserts = List[UInt8]()
    _ = encoder.encode(0, fields, block, inserts)
    var out = List[UInt8]()
    write_headers_frame(out, Span(block))
    return out^


struct Rig(Movable):
    """A `Server` and a raw QUIC client to it, in one thread."""

    var server: Server[Echo, Plain]
    var quic: Quic
    var context: QuicContext
    var sys: Sys
    var fd: Int
    var ssl: Int
    var buffer: List[UInt8]
    var encoder: QpackEncoder
    var decoder: QpackDecoder

    def __init__(out self, path: String = "") raises:
        self.server = make_server(path)
        self.quic = Quic(OpenSsl())
        self.context = QuicContext.client(self.quic.copy(), test_certs().cert)
        self.sys = Sys()
        self.buffer = List[UInt8](length=65536, fill=0)
        self.encoder = QpackEncoder()
        self.decoder = QpackDecoder()
        self.fd = self.quic.udp_socket()
        _ = self.sys.connect(self.fd, IPv4Address.LOOPBACK, self.server.port)
        self.ssl = self.quic.client_connection(
            self.context.ctx, self.fd, "localhost", True
        )
        var turns = 0
        while self.quic.connect(self.ssl) != 1:
            self.pump(1)
            turns += 1
            if turns > 500:
                raise Error("no handshake")
        self.pump(3)

    def __deinit__(deinit self):
        self.quic.free(self.ssl)
        self.sys.close(self.fd)
        self.server.close()

    def pump(mut self, turns: Int) raises:
        var index = 0
        while index < turns:
            _ = self.server.poll(0)
            self.quic.handle_events(self.ssl)
            _ = self.sys.poll(self.fd, 1, 1)
            self.quic.handle_events(self.ssl)
            index += 1

    def open(mut self) raises -> Int:
        var stream = self.quic.new_stream(self.ssl, False)
        if stream == 0:
            raise Error("no stream")
        return stream

    def write(mut self, stream: Int, data: List[UInt8], fin: Bool) raises:
        if self.quic.write(stream, data.unsafe_ptr(), len(data), fin) < 0:
            raise Error("write failed")
        self.quic.handle_events(self.ssl)

    def head(
        mut self,
        stream: Int,
        mut tunnel: H3Tunnel,
        path: StaticString = "/ws",
        protocols: List[String] = ["graphql-transport-ws"],
    ) raises:
        """Send the extended `CONNECT` of a tunnel."""
        tunnel.request(self.encoder, "https", "localhost", path, protocols)
        self.write(stream, tunnel.out, False)
        tunnel.out.clear()

    def flush(
        mut self, stream: Int, mut tunnel: H3Tunnel, fin: Bool = False
    ) raises:
        tunnel.flush()
        self.write(stream, tunnel.out, fin)
        tunnel.out.clear()

    def take(mut self, stream: Int, mut tunnel: H3Tunnel) raises -> ReadState:
        """Give what arrived to the tunnel; return the last state."""
        while True:
            var result = self.quic.read(
                stream, self.buffer.unsafe_ptr(), len(self.buffer)
            )
            if result.state != ReadState.DATA:
                return result.state
            tunnel.receive(Span(self.buffer)[0 : result.count], self.decoder)

    def wait_head(
        mut self, stream: Int, mut tunnel: H3Tunnel
    ) raises -> ReadState:
        """Pump until the head of the server, the end, or 200 turns."""
        var turns = 0
        while turns < 200:
            var state = self.take(stream, tunnel)
            if tunnel.has_head() or state != ReadState.WAIT:
                return state
            self.pump(1)
            turns += 1
        return ReadState.WAIT

    def next(
        mut self, stream: Int, mut tunnel: H3Tunnel, mut message: Message
    ) raises -> Bool:
        """Pump until a message, for at most 200 turns."""
        var turns = 0
        while turns < 200:
            if tunnel.ws.read(message):
                return True
            _ = self.take(stream, tunnel)
            self.pump(1)
            turns += 1
        return False

    def until_end(
        mut self, stream: Int, mut tunnel: H3Tunnel
    ) raises -> ReadState:
        """Pump until the stream ends or resets, for at most 200 turns."""
        var turns = 0
        while turns < 200:
            var state = self.take(stream, tunnel)
            if state != ReadState.WAIT:
                return state
            self.pump(1)
            turns += 1
        return ReadState.WAIT


def h3_client() raises -> H3Client:
    var context = QuicContext.client(Quic(OpenSsl()), test_certs().cert)
    return H3Client(context^)


def start_ws_server(path: String = "") raises -> Tuple[Int, Int]:
    """Fork a `Server` with `Echo`; `stop` closes it. It returns the pid
    and the UDP port."""
    var server = make_server(path)
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            while not server.handler.stop:
                _ = server.poll(5)
        except:
            pass
        server.close()
        sys.exit_now(0)
    var port = server.port
    server.close()
    return (pid, port)


def start_stub_server(mode: Int, port: Int = 0) raises -> Tuple[Int, Int]:
    """Fork an `H3Server` with `Plain`. Mode 0 never answers a tunnel; 1
    resets each tunnel at its head; 2 does not enable the extended
    `CONNECT`; 3 answers a head with a DATA frame; 4 answers 200, then a
    masked frame. It returns the pid and
    the UDP port."""
    var certs = test_certs()
    var c = H3Config()
    c.host = IPv4Address.LOOPBACK
    c.port = port
    c.enable_connect = mode != 2
    var server = listen_h3(Plain(), certs.cert, certs.key, c, Quic(OpenSsl()))
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        var data: List[UInt8] = [0x00, 0x01, 0x41]
        # A 200 answer, then a masked frame: a server must not mask.
        var status = FieldList()
        status.add_text(":status", "200")
        var encoder = QpackEncoder()
        var block = List[UInt8]()
        var inserts = List[UInt8]()
        _ = encoder.encode(0, status, block, inserts)
        var masked = List[UInt8]()
        write_headers_frame(masked, Span(block))
        var frame: List[UInt8] = [0x81, 0x80, 0, 0, 0, 0]
        write_data_frame(masked, Span(frame))
        try:
            while True:
                _ = server.poll(5)
                var events = List[TunnelEvent]()
                swap(events, server.events)
                var index = 0
                while index < len(events):
                    if events[index].kind == TunnelEventKind.HEAD:
                        if mode == 1:
                            _ = server.reset(
                                events[index].stream,
                                H3ErrorCode.H3_REQUEST_CANCELLED.value,
                            )
                        elif mode == 3:
                            _ = server.send(
                                events[index].stream, Span(data), False
                            )
                        elif mode == 4:
                            _ = server.send(
                                events[index].stream, Span(masked), False
                            )
                    index += 1
        except:
            pass
        sys.exit_now(0)
    var bound = server.port
    server.close()
    return (pid, bound)


def start_silent_server(port: Int = 0) raises -> Tuple[Int, Int]:
    """Fork a QUIC server that accepts connections and sends nothing: no
    SETTINGS. It returns the pid and the UDP port."""
    var certs = test_certs()
    var quic = Quic(OpenSsl())
    var context = QuicContext.server(quic.copy(), certs.cert, certs.key)
    var sys = Sys()
    var fd = quic.udp_socket()
    _ = sys.bind(fd, IPv4Address.LOOPBACK, port)
    var bound = sys.local_port(fd)
    var listener = quic.listener(context.ctx, fd)
    var pid = sys.fork()
    if pid != 0:
        quic.free(listener)
        sys.close(fd)
        return (pid, bound)
    _ = sys.die_with_parent()
    # The loop names the context, so it lives: its ALPN list must.
    while context.ctx != 0:
        _ = sys.poll(fd, 1, 5)
        quic.handle_events(listener)
        _ = quic.accept_connection(listener)
    return (0, 0)


def stop(pid: Int):
    var sys = Sys()
    _ = sys.kill(pid, 9)
    _ = sys.wait(pid, True)
