# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_http3 suites: an `H3Server` in this process, and a
raw QUIC client that writes any bytes on any stream. Both run in one
thread: `pump` turns the server and the client in turn."""

from std.time import perf_counter_ns

from _certs import test_certs
from gql_http.parser import Limits, Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import IPv4Address, Sys
from gql_http.status import Status
from gql_tls.openssl import OpenSsl
from gql_http3.error import H3ErrorCode
from gql_http3.frame import (
    FrameType,
    write_data_frame,
    write_frame_header,
    write_headers_frame,
)
from gql_http3.message import write_message
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_http3.quic import Quic, QuicContext, QuicTransport, ReadState
from gql_http3.server import (
    H3Config,
    H3Server,
    TunnelEvent,
    TunnelEventKind,
    control_preface,
    listen_h3,
)
from gql_http3.varint import encode_varint


struct Echo(Handler):
    """Answer with the path and the content; `/fail` raises."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var path = String(request.path())
        if path == "/fail":
            raise Error("handler failed")
        response.send(
            Status.OK,
            "text/plain",
            path + ":" + String(unsafe_from_utf8=request.body()),
        )


def config() -> H3Config:
    var c = H3Config()
    c.host = IPv4Address.LOOPBACK
    c.port = 0
    return c^


def make_server(
    transport: QuicTransport = QuicTransport.NATIVE,
) raises -> H3Server[Echo]:
    return make_server_with(Quic(OpenSsl(), transport=transport))


def make_server_with(var quic: Quic) raises -> H3Server[Echo]:
    var certs = test_certs()
    return listen_h3(Echo(), certs.cert, certs.key, config(), quic^)


def request_bytes(path: StaticString, body: StaticString = "") -> List[UInt8]:
    var fields = FieldList()
    fields.add_text(":method", "POST")
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", "localhost")
    fields.add_text(":path", path)
    var encoder = QpackEncoder()
    var block = List[UInt8]()
    var stream = List[UInt8]()
    _ = encoder.encode(0, fields, block, stream)
    var out = List[UInt8]()
    write_message(block, body.as_bytes(), out)
    return out^


def control_bytes() -> List[UInt8]:
    var out = List[UInt8]()
    encode_varint(0, out)
    write_frame_header(out, FrameType.SETTINGS, 0)
    return out^


struct RawClient(Movable):
    """A QUIC connection to the server, without HTTP/3 rules."""

    var quic: Quic
    var context: QuicContext
    var sys: Sys
    var fd: Int
    var ssl: Int
    var buffer: List[UInt8]

    def __init__(
        out self,
        mut server: H3Server[Echo],
        transport: QuicTransport = QuicTransport.NATIVE,
        verify: Bool = True,
    ) raises:
        self.quic = Quic(OpenSsl(), transport=transport)
        self.context = QuicContext.client(self.quic.copy(), test_certs().cert)
        self.sys = Sys()
        self.buffer = List[UInt8](length=65536, fill=0)
        self.fd = self.quic.udp_socket()
        _ = self.sys.connect(self.fd, IPv4Address.LOOPBACK, server.port)
        self.ssl = self.quic.client_connection(
            self.context.ctx, self.fd, "localhost", verify
        )
        var turns = 0
        while self.quic.connect(self.ssl) != 1:
            self.pump(server, 1)
            turns += 1
            if turns > 500:
                raise Error("no handshake")
        self.pump(server, 3)

    def __deinit__(deinit self):
        self.quic.free(self.ssl)
        self.sys.close(self.fd)

    def pump(mut self, mut server: H3Server[Echo], turns: Int) raises:
        var index = 0
        while index < turns:
            _ = server.poll(0)
            self.quic.handle_events(self.ssl)
            _ = self.sys.poll(self.fd, 1, 1)
            self.quic.handle_events(self.ssl)
            index += 1

    def open(mut self, unidirectional: Bool) raises -> Int:
        var stream = self.quic.new_stream(self.ssl, unidirectional)
        if stream == 0:
            raise Error("no stream")
        return stream

    def send(mut self, stream: Int, data: List[UInt8], conclude: Bool) raises:
        if self.quic.write(stream, data.unsafe_ptr(), len(data), conclude) < 0:
            raise Error("write failed")
        self.quic.handle_events(self.ssl)

    def receive(
        mut self, mut server: H3Server[Echo], stream: Int
    ) raises -> Tuple[String, ReadState]:
        """Read a stream until it ends, for at most 200 turns."""
        var got = List[UInt8]()
        var turns = 0
        while turns < 200:
            var result = self.quic.read(
                stream, self.buffer.unsafe_ptr(), len(self.buffer)
            )
            if result.state == ReadState.DATA:
                got.extend(Span(self.buffer)[0 : result.count])
                continue
            if result.state != ReadState.WAIT:
                return (String(unsafe_from_utf8=got), result.state)
            self.pump(server, 1)
            turns += 1
        return (String(unsafe_from_utf8=got), ReadState.WAIT)

    def closed(mut self, mut server: H3Server[Echo]) raises -> Bool:
        """Pump until the server closes the connection, at most 200 turns."""
        var turns = 0
        while turns < 200:
            if self.quic.connection_closed(self.ssl):
                return True
            self.pump(server, 1)
            turns += 1
        return False


def start_raw_server(
    reply: List[UInt8], transport: QuicTransport = QuicTransport.NATIVE
) raises -> Tuple[Int, Int]:
    """Fork a QUIC server that answers each request stream with `reply`
    and FIN, whatever the request is. It returns the pid and the port."""
    var certs = test_certs()
    var quic = Quic(OpenSsl(), transport=transport)
    var context = QuicContext.server(quic.copy(), certs.cert, certs.key)
    var sys = Sys()
    var fd = quic.udp_socket()
    _ = sys.bind(fd, IPv4Address.LOOPBACK, 0)
    var port = sys.local_port(fd)
    var listener = quic.listener(context.ctx, fd)
    var pid = sys.fork()
    if pid != 0:
        quic.free(listener)
        sys.close(fd)
        return (pid, port)
    _ = sys.die_with_parent()
    var conns = List[Int]()
    var buffer = List[UInt8](length=65536, fill=0)
    # The loop names the context, so it lives: its ALPN list must.
    while context.ctx != 0:
        _ = sys.poll(fd, 1, 5)
        quic.handle_events(listener)
        var conn = quic.accept_connection(listener)
        if conn != 0:
            conns.append(conn)
        var index = 0
        while index < len(conns):
            var stream = quic.accept_stream(conns[index])
            if stream != 0 and quic.stream_id(stream) & 2 == 0:
                var state = ReadState.WAIT
                while state != ReadState.END and state != ReadState.RESET:
                    var result = quic.read(stream, buffer.unsafe_ptr(), 65536)
                    state = result.state
                    if state == ReadState.WAIT:
                        _ = sys.poll(fd, 1, 5)
                        quic.handle_events(listener)
                _ = quic.write(stream, reply.unsafe_ptr(), len(reply), True)
                quic.handle_events(listener)
            index += 1
    return (0, 0)


def start_server(
    max_body: Int = 16 << 20, transport: QuicTransport = QuicTransport.NATIVE
) raises -> Tuple[Int, Int]:
    """Fork an `H3Server` with `Echo`; return the pid and the UDP port."""
    var certs = test_certs()
    var c = config()
    c.limits.max_body_bytes = max_body
    var server = listen_h3(
        Echo(), certs.cert, certs.key, c, Quic(OpenSsl(), transport=transport)
    )
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


def tunnel_head(status: StaticString) -> List[UInt8]:
    var fields = FieldList()
    fields.add_text(":status", status)
    var encoder = QpackEncoder()
    var block = List[UInt8]()
    var inserts = List[UInt8]()
    _ = encoder.encode(0, fields, block, inserts)
    var out = List[UInt8]()
    write_headers_frame(out, Span(block))
    return out^


def start_tunnel_server(
    enable: Bool = True, max_body: Int = 16 << 20
) raises -> Tuple[Int, Int]:
    """Fork an `H3Server` that echoes each tunnel of an extended `CONNECT`.
    It answers the head with `:status 200`, echoes each DATA payload in a
    DATA frame, ends its side at the end of the peer, and resets the tunnel
    on the payload `reset`. It returns the pid and the UDP port."""
    var certs = test_certs()
    var c = config()
    c.enable_connect = enable
    c.limits.max_body_bytes = max_body
    var server = listen_h3(Echo(), certs.cert, certs.key, c, Quic(OpenSsl()))
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        var head = tunnel_head("200")
        try:
            while True:
                _ = server.poll(5)
                var events = List[TunnelEvent]()
                swap(events, server.events)
                var index = 0
                while index < len(events):
                    ref event = events[index]
                    if event.kind == TunnelEventKind.HEAD:
                        _ = server.send(event.stream, Span(head), False)
                    elif event.kind == TunnelEventKind.DATA:
                        if String(unsafe_from_utf8=event.data) == "reset":
                            _ = server.reset(
                                event.stream,
                                H3ErrorCode.H3_REQUEST_CANCELLED.value,
                            )
                        else:
                            var out = List[UInt8]()
                            write_data_frame(out, Span(event.data))
                            _ = server.send(event.stream, Span(out), False)
                    elif event.kind == TunnelEventKind.END:
                        _ = server.send(event.stream, List[UInt8](), True)
                    index += 1
        except:
            pass
        sys.exit_now(0)
    var port = server.port
    server.close()
    return (pid, port)


def _pump_for(mut quic: Quic, mut sys: Sys, fd: Int, listener: Int, ms: Int):
    var end = Int(perf_counter_ns()) + ms * 1_000_000
    while Int(perf_counter_ns()) < end:
        _ = sys.poll(fd, 1, 5)
        quic.handle_events(listener)


def start_control_server(bad: Bool) raises -> Tuple[Int, Int]:
    """Fork a QUIC server that opens streams to each client, and reads
    nothing. It opens a stream of an unknown type that ends at once, and a
    control stream. Its type comes first, and its SETTINGS (with
    `SETTINGS_ENABLE_CONNECT_PROTOCOL`) 200 ms later; `bad` sends a DATA
    frame instead, which fails the control stream. It returns the pid and
    the port."""
    var certs = test_certs()
    var quic = Quic(OpenSsl())
    var context = QuicContext.server(quic.copy(), certs.cert, certs.key)
    var sys = Sys()
    var fd = quic.udp_socket()
    _ = sys.bind(fd, IPv4Address.LOOPBACK, 0)
    var port = sys.local_port(fd)
    var listener = quic.listener(context.ctx, fd)
    var pid = sys.fork()
    if pid != 0:
        quic.free(listener)
        sys.close(fd)
        return (pid, port)
    _ = sys.die_with_parent()
    var grease: List[UInt8] = [0x21, 0x78]
    var kind: List[UInt8] = [0x00]
    var settings = List[UInt8](Span(control_preface(Limits(), True))[1:])
    var frame: List[UInt8] = [0x00, 0x00]
    # The loop names the context, so it lives: its ALPN list must.
    while context.ctx != 0:
        _ = sys.poll(fd, 1, 5)
        quic.handle_events(listener)
        var conn = quic.accept_connection(listener)
        if conn == 0:
            continue
        # Streams open once the handshake has ended.
        while not quic.handshake_done(conn):
            _ = sys.poll(fd, 1, 5)
            quic.handle_events(listener)
        var other = quic.new_stream(conn, True)
        _ = quic.write(other, grease.unsafe_ptr(), len(grease), True)
        var control = quic.new_stream(conn, True)
        _ = quic.write(control, kind.unsafe_ptr(), len(kind), False)
        quic.handle_events(listener)
        _pump_for(quic, sys, fd, listener, 200)
        if bad:
            _ = quic.write(control, frame.unsafe_ptr(), len(frame), False)
        else:
            _ = quic.write(control, settings.unsafe_ptr(), len(settings), False)
        quic.handle_events(listener)
    return (0, 0)


def stop(pid: Int):
    var sys = Sys()
    _ = sys.kill(pid, 9)
    _ = sys.wait(pid, True)
