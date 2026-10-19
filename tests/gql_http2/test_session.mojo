# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http2.session`: a gql_http handler behind HTTP/2, the h2c
upgrade, `decode_base64url`, and `serve_transport` over a socket.

Ported from h2 v0.4.20 `tests/h2-tests/tests/server.rs` (`serve_request`,
`send_reset_explicitly`, `graceful_shutdown`) for the parts that a handler
sees, and from RFC 7540 section 3.2 for the upgrade.
"""

from _frames import Frame, Peer, kinds, request, response
from gql_http.parser import Limits, Request, RequestReader
from gql_http.server import Handler, ResponseWriter
from _net import loopback_pair, read_all, send_all
from gql_http.socket import (
    EAGAIN,
    ECONNRESET,
    EINTR,
    EPIPE,
    Faults,
    IPv4Address,
    Sys,
    SysCall,
)
from gql_http.status import Status
from gql_http2.connection import Config, Connection, Role
from gql_http2.error import H2ErrorKind, Reason
from gql_http2.frame import END_HEADERS, END_STREAM, FrameKind, PREFACE
from gql_http2.hpack import HeaderList
from gql_http2.session import (
    ServerSession,
    SocketTransport,
    decode_base64url,
    is_h2c_upgrade,
    serve_transport,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime EOS = END_HEADERS | END_STREAM
"""The flags of a whole head that ends its stream."""


@fieldwise_init
struct App(Handler):
    """Answers by path: an echo of the request, a stream, an error."""

    var count: Int

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        self.count += 1
        var path = request.path()
        if path == "/fail":
            raise Error("handler failed")
        if path == "/stream":
            response.add_header("Content-Type", "text/plain")
            response.write_text("a")
            response.begin_chunked()
            response.write_chunk(StaticString("bc").as_bytes())
            response.flush()
            response.write_chunk(StaticString("0123456789abcdefg").as_bytes())
            return
        if path == "/stream-fail":
            response.begin_chunked()
            response.write_chunk(StaticString("x").as_bytes())
            raise Error("broken stream")
        if path == "/big":
            response.write(List[UInt8](length=1 << 23, fill=0x62))
            return
        if path == "/empty":
            response.set_status(Status.NO_CONTENT)
            return
        if path == "/close":
            response.close_connection()
        response.add_header("Content-Type", "text/plain")
        response.add_header("Keep-Alive", "timeout=5")
        response.add_header("X-Upper", "kept")
        response.write_text(request.method_text())
        response.write_text(" ")
        response.write_text(request.target())
        var index = 0
        while index < request.header_count():
            response.write_text("|")
            response.write_text(request.header_name(index))
            response.write_text("=")
            response.write_text(request.header_value(index))
            index += 1
        response.write_text("|")
        response.write(request.body())


struct Run(Movable):
    """A session, its handler and a mock client."""

    var session: ServerSession
    var peer: Peer
    var app: App

    def __init__(out self, limits: Limits = Limits()) raises:
        self.session = ServerSession(Config(), limits)
        self.peer = Peer()
        self.app = App(0)
        self.session.start()
        self.peer.preface()
        self.peer.settings()
        self.peer.settings_ack()
        self.send()
        _ = self.read()

    def send(mut self):
        self.session.receive(self.app, Span(self.peer.out))
        self.peer.out.clear()

    def read(mut self) raises -> List[Frame]:
        return self.peer.read(self.session.conn)

    def get(
        mut self, path: StringSlice, method: StringSlice = "GET"
    ) raises -> List[Frame]:
        """Send one request on a new stream, and return the answer."""
        var id = self.session.conn.last_peer_stream + 2
        if self.session.conn.last_peer_stream == 0:
            id = 1
        self.peer.headers(id, request(method, path), EOS)
        self.send()
        return self.read()


def _body(frames: List[Frame]) -> String:
    var out = String()
    for ref frame in frames:
        if frame.head.kind == FrameKind.DATA:
            out += frame.text()
    return out^


def test_serve_request() raises:
    var run = Run()
    var fields = request("POST", "/graphql?x=1")
    fields.add_text("content-type", "application/json")
    fields.add_text("host", "ignored")
    fields.add_text("cookie", "a=1")
    fields.add_text("cookie", "b=2")
    fields.add_text("content-length", "2")
    run.peer.headers(1, fields, END_HEADERS)
    run.peer.data(1, "{}", END_STREAM)
    run.send()
    var frames = run.read()
    assert_equal(kinds(frames), "HEADERS DATA")
    assert_equal(frames[0].field(":status"), "200")
    assert_equal(frames[0].field("content-type"), "text/plain")
    assert_equal(frames[0].field("x-upper"), "kept")
    assert_equal(frames[0].field("keep-alive"), "<none>")
    assert_true(frames[0].field("date").endswith(" GMT"))
    var body = _body(frames)
    assert_equal(frames[0].field("content-length"), String(body.byte_length()))
    assert_equal(
        body,
        (
            "POST /graphql?x=1|host=example.com|content-type=application/json"
            "|cookie=a=1; b=2|content-length=2|{}"
        ),
    )
    assert_equal(run.app.count, 1)
    assert_equal(run.session.conn.find(1), -1)


def test_request_without_authority() raises:
    var run = Run()
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "http")
    fields.add_text(":path", "/p")
    fields.add_text("host", "h.example")
    run.peer.headers(1, fields, EOS)
    run.send()
    assert_equal(_body(run.read()), "GET /p|host=h.example|")
    # CONNECT: the target is the authority.
    var connect = HeaderList()
    connect.add_text(":method", "CONNECT")
    connect.add_text(":authority", "example.com:443")
    run.peer.headers(3, connect, EOS)
    run.send()
    assert_equal(
        _body(run.read()), "CONNECT example.com:443|host=example.com:443|"
    )


def test_handler_failures() raises:
    var run = Run()
    var frames = run.get("/fail")
    assert_equal(kinds(frames), "HEADERS")
    assert_equal(frames[0].field(":status"), "500")
    assert_true(frames[0].head.has(END_STREAM))
    # A stream that has begun is reset.
    frames = run.get("/stream-fail")
    assert_equal(kinds(frames), "RST_STREAM")
    assert_equal(String(frames[0].reason()), "INTERNAL_ERROR")
    assert_false(run.session.is_done())


def test_streamed_response() raises:
    var run = Run()
    var frames = run.get("/stream")
    assert_equal(kinds(frames), "HEADERS DATA")
    assert_equal(_body(frames), "abc0123456789abcdefg")
    assert_equal(frames[0].field("content-length"), "20")
    # HEAD gets the length and no content.
    frames = run.get("/stream", "HEAD")
    assert_equal(kinds(frames), "HEADERS")
    assert_true(frames[0].head.has(END_STREAM))
    assert_equal(frames[0].field("content-length"), "<none>")
    frames = run.get("/x", "HEAD")
    assert_equal(kinds(frames), "HEADERS")
    assert_equal(frames[0].field("content-length"), "25")


def test_no_content_and_close() raises:
    var run = Run()
    var frames = run.get("/empty")
    assert_equal(kinds(frames), "HEADERS")
    assert_equal(frames[0].field(":status"), "204")
    assert_equal(frames[0].field("content-length"), "<none>")
    # close_connection begins a graceful shutdown.
    frames = run.get("/close")
    assert_equal(kinds(frames), "HEADERS DATA GOAWAY PING")


def test_gql_http_limits() raises:
    # The limits of gql_http apply to the request: 413 for its content.
    var limits = Limits()
    limits.max_body_bytes = 2
    var run = Run(limits)
    run.peer.headers(1, request("POST", "/"), END_HEADERS)
    run.peer.data(1, "abc", END_STREAM)
    run.send()
    var frames = run.read()
    assert_equal(kinds(frames), "HEADERS")
    assert_equal(frames[0].field(":status"), "413")
    assert_equal(run.app.count, 0)


def test_stream_gone_before_answer() raises:
    # A reset after the request, in the same read: nothing to answer.
    var run = Run()
    run.peer.headers(1, request(), EOS)
    run.peer.rst(1, Reason.CANCEL)
    run.send()
    assert_equal(run.app.count, 0)
    assert_equal(len(run.read()), 0)
    # A connection error after the request, in the same read: the
    # handler runs, and its answer has nowhere to go.
    run.peer.headers(3, request(), EOS)
    run.peer.window_update(0, 0)
    run.send()
    assert_equal(run.app.count, 1)
    var frames = run.read()
    assert_equal(kinds(frames), "GOAWAY")
    assert_true(run.session.is_done())


comptime UPGRADE = (
    "GET /up HTTP/1.1\r\nHost: x\r\nConnection: Upgrade, HTTP2-Settings\r\n"
    "Upgrade: h2c\r\nHTTP2-Settings: AAMAAABk\r\n\r\n"
)
"""An h2c upgrade request; its settings allow 100 streams."""


def _parsed(text: StringSlice) raises -> Bool:
    """Whether a request head asks for the h2c upgrade."""
    var reader = RequestReader(Limits())
    reader.append(text.as_bytes())
    _ = reader.next()
    return is_h2c_upgrade(reader.request)


def test_is_h2c_upgrade() raises:
    assert_true(_parsed(UPGRADE))
    assert_true(
        _parsed(
            "GET / HTTP/1.1\r\nHost: x\r\nConnection: keep-alive, ,upgrade ,"
            "\tHTTP2-settings\r\nUpgrade: websocket, H2C\r\n"
            "HTTP2-Settings: \r\n\r\n"
        )
    )
    assert_false(_parsed("GET / HTTP/1.1\r\nHost: x\r\n\r\n"))
    assert_false(
        _parsed(
            "GET / HTTP/1.1\r\nHost: x\r\nUpgrade: h2c\r\n"
            "HTTP2-Settings: AA\r\n\r\n"
        )
    )
    assert_false(
        _parsed(
            "GET / HTTP/1.1\r\nHost: x\r\nConnection: upgrade\r\n"
            "Upgrade: h2c\r\n\r\n"
        )
    )
    assert_false(
        _parsed(
            "GET / HTTP/1.1\r\nHost: x\r\nConnection: upgrade,"
            " http2-settings\r\nUpgrade: h2c\r\nHTTP2-Settings:"
            " AA\r\nHTTP2-Settings: AA\r\n\r\n"
        )
    )
    assert_false(
        _parsed(
            "GET / HTTP/1.1\r\nHost: x\r\nConnection: upgrade,"
            " http2-settings\r\nUpgrade: websocket\r\nHTTP2-Settings:"
            " AA\r\n\r\n"
        )
    )
    assert_false(
        _parsed(
            "GET / HTTP/1.1\r\nHost: x\r\nConnection: upgrade, settings\r\n"
            "Upgrade: h2c\r\nHTTP2-Settings: AA\r\n\r\n"
        )
    )
    assert_false(
        _parsed(
            "GET / HTTP/1.1\r\nHost: x\r\nConnection: http2-settings\r\n"
            "Upgrade: h2c\r\nHTTP2-Settings: AA\r\n\r\n"
        )
    )


def test_decode_base64url() raises:
    var settings = decode_base64url("AAMAAABk").value().copy()
    assert_equal(len(settings), 6)
    assert_equal(Int(settings[1]), 3)
    assert_equal(Int(settings[5]), 100)
    var padded = decode_base64url("AA==").value().copy()
    assert_equal(len(padded), 1)
    var alphabet = decode_base64url("zZ9-_w").value().copy()
    assert_equal(len(alphabet), 4)
    assert_equal(Int(alphabet[0]), 0xCD)
    assert_equal(Int(alphabet[3]), 0xFF)
    assert_equal(len(decode_base64url("").value()), 0)
    assert_false(Bool(decode_base64url("A")))
    assert_false(Bool(decode_base64url("A*")))
    assert_false(Bool(decode_base64url("A+")))


def test_upgrade() raises:
    # RFC 7540 section 3.2: 101, the server's SETTINGS, and the response on
    # stream 1; the bytes after the request are HTTP/2.
    var session = ServerSession()
    var app = App(0)
    var peer = Peer()
    var data = List[UInt8]()
    data.extend(StaticString(UPGRADE).as_bytes())
    var size = len(data)
    peer.preface()
    peer.settings()
    data.extend(Span(peer.out))
    peer.out.clear()
    assert_equal(session.upgrade(app, data), size)
    var expected = StaticString(
        "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\n"
        "Upgrade: h2c\r\n\r\n"
    )
    var head = expected.byte_length()
    var text = String(unsafe_from_utf8=Span(session.conn.out)[:head])
    assert_equal(text, String(expected))
    var rest = List[UInt8]()
    rest.extend(Span(session.conn.out)[head:])
    session.conn.out = rest^
    var frames = peer.read(session.conn)
    assert_equal(kinds(frames), "SETTINGS WINDOW_UPDATE HEADERS DATA SETTINGS")
    assert_equal(frames[2].head.stream_id, 1)
    assert_true(_body(frames).startswith("GET /up|"))
    assert_equal(session.conn.remote.max_concurrent_streams, 100)
    # The next request is HTTP/2.
    peer.headers(3, request("GET", "/after"), EOS)
    session.receive(app, Span(peer.out))
    peer.out.clear()
    assert_equal(app.count, 2)


def _no_upgrade(text: StringSlice) raises:
    var session = ServerSession()
    var app = App(0)
    assert_equal(session.upgrade(app, text.as_bytes()), -1)
    assert_equal(len(session.conn.out), 0)
    assert_equal(app.count, 0)


def test_upgrade_refused() raises:
    _no_upgrade("GET /up HTTP/1.1\r\nHost: x\r\n")
    _no_upgrade("GET /up HTTP/1.1\r\nHost: x\r\n\r\n")
    _no_upgrade("GET /up HTTP/1.1\r\nHost: x\r\nHTTP2-Settings: !!\r\n\r\n")
    _no_upgrade("GET /up HTTP/1.1\r\nHost: x\r\nHTTP2-Settings: AAMA\r\n\r\n")


def _client_bytes() -> List[UInt8]:
    """The preface, the settings and one request, then GOAWAY."""
    var peer = Peer()
    peer.preface()
    peer.settings()
    peer.headers(1, request("GET", "/t"), EOS)
    peer.goaway(0, Reason.NO_ERROR)
    return peer.out.copy()


def _frames_of(data: List[UInt8]) raises -> List[Frame]:
    """Decode the frames that a server sent."""
    var holder = Connection(Role.CLIENT)
    holder.out = data.copy()
    var peer = Peer()
    return peer.read(holder)


def test_serve_transport() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var data = _client_bytes()
    var first = List[UInt8]()
    first.extend(Span(data)[:10])
    var rest = List[UInt8]()
    rest.extend(Span(data)[10:])
    send_all(sys, pair.client, rest)
    var app = App(0)
    var transport = SocketTransport(pair.server)
    transport.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    serve_transport(app, transport, Config(), Limits(), 1000, first)
    assert_equal(transport.fd(), -1)
    transport.close()
    var frames = _frames_of(read_all(sys, pair.client))
    assert_equal(kinds(frames), "SETTINGS WINDOW_UPDATE SETTINGS HEADERS DATA")
    assert_equal(app.count, 1)
    sys.close(pair.client)
    sys.close(pair.listener)


def test_serve_transport_ends() raises:
    var sys = Sys()
    # The client closes its side.
    var pair = loopback_pair(sys)
    var peer = Peer()
    peer.preface()
    peer.settings()
    send_all(sys, pair.client, peer.out)
    _ = sys.shutdown_write(pair.client)
    var app = App(0)
    var transport = SocketTransport(pair.server)
    transport.sys.faults = Faults(SysCall.RECV, EINTR, 0, 1)
    serve_transport(app, transport)
    pair.close(sys)
    # A quiet client, in the middle of a request.
    var quiet = loopback_pair(sys)
    peer.headers(1, request(), END_HEADERS)
    send_all(sys, quiet.client, peer.out)
    var other = SocketTransport(quiet.server)
    serve_transport(app, other, Config(), Limits(), 30)
    var frames = _frames_of(read_all(sys, quiet.client))
    assert_equal(String(frames[len(frames) - 1].head.kind), "GOAWAY")
    quiet.close(sys)


def _fails(fault: Faults, expected: StringSlice) raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    send_all(sys, pair.client, _client_bytes())
    var app = App(0)
    var transport = SocketTransport(pair.server)
    transport.sys.faults = fault.copy()
    var message = String()
    try:
        serve_transport(app, transport)
    except e:
        assert_true(e.kind == H2ErrorKind.IO)
        message = e.message
    assert_true(message.startswith(expected), message)
    assert_equal(transport.fd(), -1)
    sys.close(pair.client)
    sys.close(pair.listener)


def test_serve_transport_failures() raises:
    _fails(Faults(SysCall.RECV, ECONNRESET, 0, 1), "read failed")
    _fails(Faults(SysCall.SEND, EPIPE, 0, 1), "write failed")
    _fails(Faults(SysCall.SEND, EINTR, 0, 1), "")


def test_write_timeout() raises:
    # A client that reads nothing: the response fills the socket.
    var sys = Sys()
    var pair = loopback_pair(sys)
    var peer = Peer()
    peer.preface()
    peer.settings([4], [0x7FFFFFFF])
    peer.window_update(0, 0x7FFFFFFF - 65535)
    peer.headers(1, request("GET", "/big"), EOS)
    var app = App(0)
    var transport = SocketTransport(pair.server)
    var message = String()
    send_all(sys, pair.client, peer.out)
    try:
        serve_transport(app, transport, Config(), Limits(), 50)
    except e:
        message = e.message
    assert_equal(message, "write timed out")
    sys.close(pair.client)
    sys.close(pair.listener)


def test_session_edges() raises:
    # Tokens with a tab before a comma, and one of the same length that
    # is not the one asked for.
    assert_true(
        _parsed(
            "GET / HTTP/1.1\r\nHost: x\r\nConnection: upgrade\t,"
            " http2-settings\r\nUpgrade: h2x, h2c\r\nHTTP2-Settings: AA\r\n\r\n"
        )
    )
    assert_false(Bool(decode_base64url("A~")))
    # A request with content-length 0 and no content.
    var run = Run()
    var fields = request("POST", "/zero")
    fields.add_text("content-length", "0")
    run.peer.headers(1, fields, EOS)
    run.send()
    assert_true(_body(run.read()).endswith("|content-length=0|"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
