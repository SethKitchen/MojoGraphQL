# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the error paths of `gql_http3.client`: URLs, failed calls, a
handshake that times out or does not verify, a reset stream and bad
responses. The cases follow hyperium/h3 h3-v0.0.8 h3/src/tests/request.rs
(responses without `:status`, streams that end early) and RFC 9114
section 4.1."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _h3 import start_raw_server, start_server, stop
from gql_http.client import ClientConfig
from gql_http.headers import Headers
from gql_http.socket import Faults, IPv4Address, Sys, SysCall
from gql_http.status import Method
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_http3.client import H3Client, h3_error
from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.frame import FrameType, write_frame_header
from gql_http3.message import write_message
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList
from gql_http3.quic import Quic, QuicCall, QuicContext, QuicFaults


def client(timeout_ms: Int = 20000, connect_ms: Int = 20000) raises -> H3Client:
    var settings = ClientConfig()
    settings.timeout_ms = timeout_ms
    settings.connect_timeout_ms = connect_ms
    var context = QuicContext.client(Quic(OpenSsl()), test_certs().cert)
    return H3Client(context^, settings)


def kind_of(mut c: H3Client, url: String) -> TlsErrorKind:
    try:
        _ = c.get(url)
    except e:
        return e.kind
    return TlsErrorKind.USAGE


def test_h3_error() raises:
    var e = h3_error(H3Error(H3ErrorCode.H3_MESSAGE_ERROR, "bad"))
    assert_equal(e.kind, TlsErrorKind.PROTOCOL)
    assert_equal(e.errno, 0x10E)


def test_urls_and_usage() raises:
    var c = client()
    assert_equal(kind_of(c, "http://localhost/"), TlsErrorKind.USAGE)
    assert_equal(kind_of(c, "nonsense"), TlsErrorKind.PROTOCOL)
    var raised = False
    try:
        _ = c.post("https://127.0.0.1:1/", "bad\ntype", "x")
    except e:
        raised = e.kind == TlsErrorKind.USAGE
    assert_true(raised)
    var endpoint = c.endpoint("https://127.0.0.1:1/")
    raised = False
    try:
        _ = c.send(endpoint, Method.OTHER, "/", Headers(), List[UInt8]())
    except e:
        raised = e.kind == TlsErrorKind.USAGE
    assert_true(raised)


def test_system_client() raises:
    var c = H3Client.system()
    assert_equal(c.connections(), 0)


def test_handshake_times_out() raises:
    # A bound UDP socket that never answers drops the QUIC packets.
    var sys = Sys()
    var quic = Quic(OpenSsl())
    var silent = quic.udp_socket()
    _ = sys.bind(silent, IPv4Address.LOOPBACK, 0)
    var port = sys.local_port(silent)
    var c = client(20000, 100)
    assert_equal(
        kind_of(c, "https://127.0.0.1:" + String(port) + "/"),
        TlsErrorKind.TIMEOUT,
    )
    assert_equal(c.connections(), 0)
    sys.close(silent)


def test_failed_calls() raises:
    var server = start_server()
    var url = "https://localhost:" + String(server[1]) + "/"
    var c = client()
    c.quic.faults = QuicFaults(QuicCall.SOCKET, 0, 1)
    assert_equal(kind_of(c, url), TlsErrorKind.OS)
    c.sys.faults = Faults(SysCall.CONNECT, 111, 0, 1)
    assert_equal(kind_of(c, url), TlsErrorKind.CONNECT)
    c.quic.faults = QuicFaults(QuicCall.CONNECTION, 0, 1)
    assert_equal(kind_of(c, url), TlsErrorKind.CONFIG)
    c.quic.faults = QuicFaults(QuicCall.NEW_STREAM, 0, 1)
    assert_equal(kind_of(c, url), TlsErrorKind.PROTOCOL)
    c.quic.faults = QuicFaults(QuicCall.NEW_STREAM, 1, 1)
    assert_equal(kind_of(c, url), TlsErrorKind.PROTOCOL)
    c.quic.faults = QuicFaults(QuicCall.WRITE, 1, 1)
    assert_equal(kind_of(c, url), TlsErrorKind.CLOSED)
    c.quic.faults = QuicFaults()
    var r = c.get(url)
    assert_equal(Int(r.status.code), 200)
    # A reused connection that gives no stream: a new connection sends it.
    c.quic.faults = QuicFaults(QuicCall.NEW_STREAM, 0, 1)
    assert_equal(Int(c.get(url).status.code), 200)
    # A reused connection that fails after the stream opened is not retried.
    c.quic.faults = QuicFaults(QuicCall.WRITE, 0, 1)
    assert_equal(kind_of(c, url), TlsErrorKind.CLOSED)
    c.close()
    stop(server[0])


def test_verify_failure() raises:
    var server = start_server()
    var c = H3Client(QuicContext.client(Quic(OpenSsl())))
    assert_equal(
        kind_of(c, "https://localhost:" + String(server[1]) + "/"),
        TlsErrorKind.VERIFY,
    )
    stop(server[0])


def test_reset_and_large_body() raises:
    var server = start_server(10)
    var url = "https://localhost:" + String(server[1]) + "/"
    var c = client()
    var kind = TlsErrorKind.USAGE
    try:
        _ = c.post(url, "text/plain", "far more than ten bytes")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CLOSED)
    # The connection is gone; the next request opens another.
    var big = String("x") * (300 * 1024)
    var answer = c.post(url, "text/plain", "short")
    assert_equal(answer.text(), "/:short")
    stop(server[0])
    _ = big^


def raw_kind(var reply: List[UInt8]) raises -> TlsErrorKind:
    var server = start_raw_server(reply)
    var c = client()
    var kind = kind_of(c, "https://localhost:" + String(server[1]) + "/")
    stop(server[0])
    return kind


def encoded(fields: FieldList, body: StaticString = "") -> List[UInt8]:
    var encoder = QpackEncoder()
    var block = List[UInt8]()
    var stream = List[UInt8]()
    _ = encoder.encode(0, fields, block, stream)
    var out = List[UInt8]()
    write_message(block, body.as_bytes(), out)
    return out^


def test_bad_responses() raises:
    # The stream ends before HEADERS; a reserved frame is skipped.
    var reserved = List[UInt8]()
    write_frame_header(reserved, FrameType.grease(1), 0)
    assert_equal(raw_kind(reserved^), TlsErrorKind.PROTOCOL)
    # DATA before HEADERS.
    var early = List[UInt8]()
    write_frame_header(early, FrameType.DATA, 1)
    early.append(65)
    assert_equal(raw_kind(early^), TlsErrorKind.PROTOCOL)
    # No :status.
    var fields = FieldList()
    fields.add_text("x-a", "1")
    assert_equal(raw_kind(encoded(fields)), TlsErrorKind.PROTOCOL)
    # A head larger than the limits of the client.
    var large = FieldList()
    large.add_text(":status", "200")
    large.add_text("x-big", String("v") * 20000)
    assert_equal(raw_kind(encoded(large)), TlsErrorKind.PROTOCOL)
    # An empty stream.
    assert_equal(raw_kind(List[UInt8]()), TlsErrorKind.PROTOCOL)


def test_handshake_fault() raises:
    var server = start_server()
    var url = "https://localhost:" + String(server[1]) + "/"
    var c = client()
    c.quic.faults = QuicFaults(QuicCall.HANDSHAKE, 0, 1)
    assert_equal(kind_of(c, url), TlsErrorKind.HANDSHAKE)
    var settings = ClientConfig()
    var open = H3Client(QuicContext.client(Quic(OpenSsl()), verify=False))
    open.quic.faults = QuicFaults(QuicCall.HANDSHAKE, 0, 1)
    assert_equal(kind_of(open, url), TlsErrorKind.HANDSHAKE)
    _ = settings^
    stop(server[0])


def test_invalid_method() raises:
    var c = client()
    var endpoint = c.endpoint("https://127.0.0.1:1/")
    var raised = False
    try:
        _ = c.send(endpoint, Method(200), "/", Headers(), List[UInt8]())
    except e:
        raised = e.kind == TlsErrorKind.USAGE
    assert_true(raised)


def test_two_servers_and_a_closed_connection() raises:
    var first = start_server()
    var second = start_server()
    var c = client()
    var a = "https://localhost:" + String(first[1]) + "/a"
    var b = "https://localhost:" + String(second[1]) + "/b"
    assert_equal(c.get(a).text(), "/a:")
    assert_equal(c.get(b).text(), "/b:")
    assert_equal(c.get(a).text(), "/a:")
    assert_equal(c.connections(), 2)
    # Close one connection under the client: it opens another.
    c.quic.close_connection(c._conns[0].ssl, 0x100)
    c.quic.handle_events(c._conns[0].ssl)
    assert_equal(c.get(a).text(), "/a:")
    # A body larger than the flow control window of a stream.
    var big = String("y") * (600 << 10)
    assert_equal(
        c.post(b, "text/plain", big).text().byte_length(), (600 << 10) + 3
    )
    stop(first[0])
    stop(second[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
