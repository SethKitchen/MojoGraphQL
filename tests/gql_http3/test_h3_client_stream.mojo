# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the streams of `gql_http3.client` that stay open: the tunnel
of an extended `CONNECT` (RFC 9220 section 3), over real QUIC on loopback.
hyperium/h3 h3-v0.0.8 has no client test of the extended `CONNECT`; the
cases follow RFC 9220 sections 3 and 4 (SETTINGS_ENABLE_CONNECT_PROTOCOL,
a tunnel that ends with FIN or a reset)."""

from std.testing import TestSuite, assert_equal, assert_true

from _certs import test_certs
from _h3 import (
    start_control_server,
    start_raw_server,
    start_tunnel_server,
    stop,
    tunnel_head,
)
from gql_http.client import ClientConfig
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_tls.client import HttpsEndpoint
from gql_http3.client import H3Client, H3Stream
from gql_http3.error import H3ErrorCode
from gql_http3.frame import write_data_frame, write_headers_frame
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_http3.quic import Quic, QuicCall, QuicContext, QuicFaults, ReadState


def client(timeout_ms: Int = 20000) raises -> H3Client:
    var settings = ClientConfig()
    settings.timeout_ms = timeout_ms
    var context = QuicContext.client(Quic(OpenSsl()), test_certs().cert)
    return H3Client(context^, settings)


def connect_head() -> List[UInt8]:
    var fields = FieldList()
    fields.add_text(":method", "CONNECT")
    fields.add_text(":protocol", "websocket")
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", "localhost")
    fields.add_text(":path", "/ws")
    var encoder = QpackEncoder()
    var block = List[UInt8]()
    var inserts = List[UInt8]()
    _ = encoder.encode(0, fields, block, inserts)
    var out = List[UInt8]()
    write_headers_frame(out, Span(block))
    return out^


def data(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    write_data_frame(out, text.as_bytes())
    return out^


def read_until(
    mut c: H3Client, stream: H3Stream, mut got: List[UInt8], want: Int
) raises -> ReadState:
    """Read until `want` bytes, the end, or a reset."""
    var turns = 0
    while len(got) < want and turns < 400:
        var state = c.read_stream(stream, got, 20)
        if state == ReadState.END or state == ReadState.RESET:
            return state
        turns += 1
    return ReadState.DATA if len(got) >= want else ReadState.WAIT


def open_kind(mut c: H3Client, endpoint: HttpsEndpoint) -> TlsErrorKind:
    try:
        var stream = c.open_stream(endpoint)
        c.close_stream(stream)
    except e:
        return e.kind
    return TlsErrorKind.USAGE


def test_echo_and_end() raises:
    """A tunnel echoes DATA; the FIN of the client ends it on both sides."""
    var server = start_tunnel_server()
    var c = client()
    var endpoint = c.endpoint("https://localhost:" + String(server[1]) + "/")
    var stream = c.open_stream(endpoint)
    assert_equal(stream.id & 3, 0)
    c.write_stream(stream, Span(connect_head()), False)
    c.write_stream(stream, Span(data("hello")), False)
    var expect = tunnel_head("200")
    expect.extend(Span(data("hello")))
    var got = List[UInt8]()
    assert_equal(read_until(c, stream, got, len(expect)), ReadState.DATA)
    assert_true(got == expect)
    # Nothing more arrives: no wait gives WAIT.
    assert_equal(c.read_stream(stream, got, 0), ReadState.WAIT)
    c.write_stream(stream, List[UInt8](), True)
    assert_equal(read_until(c, stream, got, len(expect) + 1), ReadState.END)
    c.close_stream(stream)
    # The connection stays; a second tunnel opens on it.
    var again = c.open_stream(endpoint)
    assert_equal(c.connections(), 1)
    c.reset_stream(again, H3ErrorCode.H3_REQUEST_CANCELLED.value)
    c.close_stream(again)
    c.close()
    stop(server[0])


def test_server_reset() raises:
    var server = start_tunnel_server()
    var c = client()
    var endpoint = c.endpoint("https://localhost:" + String(server[1]) + "/")
    var stream = c.open_stream(endpoint)
    c.write_stream(stream, Span(connect_head()), False)
    c.write_stream(stream, Span(data("reset")), False)
    var got = List[UInt8]()
    assert_equal(read_until(c, stream, got, 1 << 20), ReadState.RESET)
    c.close_stream(stream)
    c.close()
    stop(server[0])


def test_larger_than_the_stream_window() raises:
    """2 MB passes the 1.25 MB window of a stream: the client writes it in
    parts as the server gives credit, and reads the whole echo."""
    var server = start_tunnel_server()
    var c = client()
    var endpoint = c.endpoint("https://localhost:" + String(server[1]) + "/")
    var stream = c.open_stream(endpoint)
    c.write_stream(stream, Span(connect_head()), False)
    var big = data(String("x") * (2 << 20))
    c.write_stream(stream, Span(big), True)
    var got = List[UInt8]()
    var state = read_until(c, stream, got, 1 << 30)
    assert_equal(state, ReadState.END)
    assert_true(len(got) > 2 << 20)
    c.close_stream(stream)
    c.close()
    stop(server[0])


def test_not_enabled() raises:
    """A server without SETTINGS_ENABLE_CONNECT_PROTOCOL refuses."""
    var server = start_tunnel_server(False)
    var c = client()
    var endpoint = c.endpoint("https://localhost:" + String(server[1]) + "/")
    assert_equal(open_kind(c, endpoint), TlsErrorKind.PROTOCOL)
    c.close()
    stop(server[0])


def test_no_settings() raises:
    """A server that never opens its control stream times out."""
    var server = start_raw_server(List[UInt8]())
    var c = client(300)
    var endpoint = c.endpoint("https://localhost:" + String(server[1]) + "/")
    assert_equal(open_kind(c, endpoint), TlsErrorKind.TIMEOUT)
    c.close()
    stop(server[0])


def test_failures() raises:
    var server = start_tunnel_server()
    var c = client()
    var endpoint = c.endpoint("https://localhost:" + String(server[1]) + "/")
    var stream = c.open_stream(endpoint)
    # A reused connection that gives no stream.
    c.quic.faults = QuicFaults(QuicCall.NEW_STREAM, 0, 1)
    assert_equal(open_kind(c, endpoint), TlsErrorKind.PROTOCOL)
    c.quic.faults = QuicFaults(QuicCall.WRITE, 0, 1)
    var kind = TlsErrorKind.USAGE
    try:
        c.write_stream(stream, Span(connect_head()), False)
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CLOSED)
    c.quic.faults = QuicFaults()
    c.close_stream(stream)
    # A stream of a connection that has closed.
    c.close()
    var gone = H3Stream(stream.conn, 0, 0)
    kind = TlsErrorKind.USAGE
    try:
        var got = List[UInt8]()
        _ = c.read_stream(gone, got, 0)
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CLOSED)
    stop(server[0])


def test_server_streams() raises:
    """The SETTINGS come 200 ms after the type of the control stream, and
    a stream of an unknown type ends at once; two servers give two
    connections."""
    var first = start_control_server(False)
    var second = start_control_server(False)
    var c = client()
    var a = c.open_stream(
        c.endpoint("https://localhost:" + String(first[1]) + "/")
    )
    var b = c.open_stream(
        c.endpoint("https://localhost:" + String(second[1]) + "/")
    )
    assert_equal(c.connections(), 2)
    var got = List[UInt8]()
    assert_equal(c.read_stream(b, got, 0), ReadState.WAIT)
    c.close_stream(a)
    c.close_stream(b)
    c.close()
    stop(first[0])
    stop(second[0])


def test_control_stream_fails() raises:
    var server = start_control_server(True)
    var c = client()
    var endpoint = c.endpoint("https://localhost:" + String(server[1]) + "/")
    assert_equal(open_kind(c, endpoint), TlsErrorKind.PROTOCOL)
    c.close()
    stop(server[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
