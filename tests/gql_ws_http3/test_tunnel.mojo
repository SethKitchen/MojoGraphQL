# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http3.tunnel`: a client and a server `H3Tunnel`
joined in memory, each with its QPACK coder.

There is no upstream suite. The cases follow the session cases of
`tests/gql_ws_http2/test_session.mojo`, on an HTTP/3 request stream as
RFC 9220 tells.
"""

from gql_http3.error import H3ErrorCode
from gql_http3.frame import write_data_frame
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_encoder import QpackEncoder
from gql_ws.error import WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind, Role
from gql_ws_http3.tunnel import H3Tunnel
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime GTW = "graphql-transport-ws"


struct Pair(Movable):
    """A client tunnel and a server tunnel on stream 0."""

    var client: H3Tunnel
    var server: H3Tunnel
    var client_encoder: QpackEncoder
    var client_decoder: QpackDecoder
    var server_encoder: QpackEncoder
    var server_decoder: QpackDecoder

    def __init__(out self):
        self.client = H3Tunnel(Role.CLIENT, 0)
        self.server = H3Tunnel(Role.SERVER, 0)
        self.client_encoder = QpackEncoder()
        self.client_decoder = QpackDecoder()
        self.server_encoder = QpackEncoder()
        self.server_decoder = QpackDecoder()

    def to_server(mut self) raises:
        self.client.flush()
        var data = self.client.out.copy()
        self.client.out.clear()
        self.server.receive(Span(data), self.server_decoder)

    def to_client(mut self) raises:
        self.server.flush()
        var data = self.server.out.copy()
        self.server.out.clear()
        self.client.receive(Span(data), self.client_decoder)

    def request(mut self, path: StringSlice = "/graphql") raises:
        self.client.request(
            self.client_encoder, "https", "localhost", path, [GTW]
        )
        self.to_server()


def _open() raises -> Pair:
    var pair = Pair()
    pair.request()
    assert_true(pair.server.has_head())
    assert_true(pair.server.accept(pair.server_encoder, [GTW], "/graphql"))
    pair.to_client()
    assert_true(pair.client.has_head())
    pair.client.verify([GTW])
    return pair^


def test_echo() raises:
    var pair = _open()
    assert_equal(pair.client.status, 200)
    assert_equal(pair.client.protocol, GTW)
    assert_equal(pair.server.path, "/graphql")
    pair.client.ws.send_text("hello")
    pair.to_server()
    var message = Message()
    assert_true(pair.server.ws.read(message))
    assert_equal(String(message.text()), "hello")
    pair.server.ws.send_text("back")
    pair.to_client()
    assert_true(pair.client.ws.read(message))
    assert_equal(String(message.text()), "back")
    # The closing handshake.
    pair.client.ws.close(CloseCode.NORMAL, "bye")
    pair.to_server()
    assert_true(pair.server.ws.read(message))
    assert_true(message.kind == MessageKind.CLOSE)
    pair.to_client()
    assert_true(pair.client.ws.read(message))
    assert_true(pair.client.ws.should_close())


def test_content_before_open() raises:
    # Content in the same bytes as the answer reaches the WebSocket.
    var pair = Pair()
    pair.request()
    _ = pair.server.accept(pair.server_encoder, [GTW])
    pair.server.ws.send_text("early")
    pair.to_client()
    pair.client.verify([GTW])
    var message = Message()
    assert_true(pair.client.ws.read(message))
    assert_equal(String(message.text()), "early")


def test_refusals() raises:
    var other = Pair()
    other.request("/other")
    assert_false(other.server.accept(other.server_encoder, [GTW], "/graphql"))
    assert_equal(other.server.status, 404)
    other.to_client()
    var raised = False
    try:
        other.client.verify([GTW])
    except e:
        raised = True
        assert_true(e.kind == WsErrorKind.HANDSHAKE)
        assert_equal(e.status, 404)
    assert_true(raised)
    # A subprotocol that the server does not have: no subprotocol.
    var protocol = Pair()
    protocol.request()
    assert_true(protocol.server.accept(protocol.server_encoder, ["other"]))
    assert_equal(protocol.server.protocol, "")
    # Another :protocol is a 400.
    var bread = H3Tunnel(Role.SERVER, 0)
    bread.reader.fields.add_text(":method", "CONNECT")
    bread.reader.fields.add_text(":protocol", "the-bread-protocol")
    bread.reader.fields.add_text(":scheme", "https")
    bread.reader.fields.add_text(":authority", "localhost")
    bread.reader.fields.add_text(":path", "/graphql")
    bread.reader.fields.add_text("sec-websocket-version", "13")
    bread.reader.has_headers = True
    var encoder = QpackEncoder()
    assert_false(bread.accept(encoder, [GTW]))
    assert_equal(bread.status, 400)
    assert_true(len(bread.out) > 0)
    # A server that did not enable the extended CONNECT.
    var disabled = Pair()
    disabled.request()
    var code = 0
    try:
        _ = disabled.server.accept(
            disabled.server_encoder, [GTW], enabled=False
        )
    except e:
        code = Int(e.code.value)
    assert_equal(code, Int(H3ErrorCode.H3_MESSAGE_ERROR.value))


def test_status_of_a_bad_answer() raises:
    # An answer without a valid :status is no 2xx.
    var fields = H3Tunnel(Role.CLIENT, 0)
    fields.reader.fields.add_text(":status", "2x0")
    var raised = False
    try:
        fields.verify()
    except e:
        raised = True
        assert_equal(e.status, 0)
    assert_true(raised)
    var spaced = H3Tunnel(Role.CLIENT, 0)
    spaced.reader.fields.add_text(":status", "2 0")
    raised = False
    try:
        spaced.verify()
    except e:
        raised = True
        assert_equal(e.status, 0)
    assert_true(raised)
    var missing = H3Tunnel(Role.CLIENT, 0)
    raised = False
    try:
        missing.verify()
    except:
        raised = True
    assert_true(raised)


def test_frame_errors() raises:
    # DATA before HEADERS is a frame error of the stream.
    var tunnel = H3Tunnel(Role.SERVER, 0)
    var decoder = QpackDecoder()
    var data = List[UInt8]()
    write_data_frame(data, "x".as_bytes())
    var code = 0
    try:
        tunnel.receive(Span(data), decoder)
    except e:
        code = Int(e.code.value)
    assert_equal(code, Int(H3ErrorCode.H3_FRAME_UNEXPECTED.value))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
