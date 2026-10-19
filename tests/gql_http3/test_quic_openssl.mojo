# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.quic` on the QUIC stack of OpenSSL, the transport
`QuicTransport.OPENSSL`: requests, partial writes, a reset stream, a
failed verification and the close. The other suites run on the default
stack, `gql_quic`. There is no upstream suite; the cases follow RFC 9000
sections 2 and 4 and RFC 9114 section 4.1."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _h3 import RawClient, make_server, request_bytes, start_server, stop
from gql_http.client import ClientConfig
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_http3.client import H3Client
from gql_http3.quic import (
    Quic,
    QuicContext,
    QuicTransport,
    ReadState,
)

comptime OPENSSL = QuicTransport.OPENSSL


def client() raises -> H3Client:
    var settings = ClientConfig()
    settings.timeout_ms = 20000
    settings.connect_timeout_ms = 20000
    var context = QuicContext.client(
        Quic(OpenSsl(), transport=OPENSSL), test_certs().cert
    )
    return H3Client(context^, settings)


def test_transport_kinds() raises:
    assert_true(QuicTransport.OPENSSL.is_valid())
    assert_false(QuicTransport(2).is_valid())
    assert_equal(String(QuicTransport.NATIVE), "native")
    assert_equal(String(QuicTransport.OPENSSL), "openssl")
    assert_equal(String(QuicTransport(7)), "invalid")
    var quic = Quic(OpenSsl(), transport=OPENSSL)
    assert_equal(quic.transport, OPENSSL)
    quic.free(0)


def test_requests() raises:
    var server = start_server(16 << 20, OPENSSL)
    var c = client()
    var url = "https://localhost:" + String(server[1]) + "/echo"
    var first = c.get(url)
    assert_equal(first.status.code, 200)
    var body = String()
    for _ in range(3000):
        body += "0123456789"
    var second = c.post(url, "text/plain", body)
    assert_equal(second.status.code, 200)
    assert_equal(c.connections(), 1)
    c.close()
    stop(server[0])


def test_partial_write_and_close() raises:
    var server = make_server(OPENSSL)
    var raw = RawClient(server, OPENSSL)
    assert_true(raw.quic.handshake_done(raw.ssl))
    assert_equal(raw.quic.verify_failure(raw.ssl), "")
    assert_true(raw.quic.event_timeout_ms(raw.ssl) >= -1)
    var uni = raw.open(True)
    assert_true(raw.quic.stream_id(uni) & 2 == 2)
    var stream = raw.open(False)
    var big = List[UInt8](length=4 << 20, fill=0)
    assert_equal(raw.quic.write(stream, big.unsafe_ptr(), 0, False), 0)
    var taken = raw.quic.write(stream, big.unsafe_ptr(), len(big), False)
    assert_true(taken >= 0 and taken < len(big))
    raw.quic.reset_stream(stream, 0x10C)
    raw.quic.free(stream)
    # An empty write with FIN ends a stream; the server answers a bad
    # request with a reset.
    var bad = raw.open(False)
    var request = request_bytes("/echo", "x")
    request.resize(3, 0)
    raw.send(bad, request, False)
    assert_equal(raw.quic.write(bad, big.unsafe_ptr(), 0, True), 0)
    var answer = raw.receive(server, bad)
    assert_equal(answer[1], ReadState.RESET)
    raw.quic.free(bad)
    var good = raw.open(False)
    raw.send(good, request_bytes("/echo", "hi"), True)
    var reply = raw.receive(server, good)
    assert_equal(reply[1], ReadState.END)
    raw.quic.free(good)
    raw.quic.close_connection(raw.ssl, 0x100)
    raw.quic.handle_events(raw.ssl)
    assert_true(raw.quic.connection_closed(raw.ssl))
    assert_equal(raw.quic.write(uni, big.unsafe_ptr(), 8, False), -1)
    assert_equal(raw.quic.read(uni, big.unsafe_ptr(), 8).state, ReadState.RESET)
    raw.quic.free(uni)
    assert_equal(raw.quic.failure(raw.ssl).byte_length() >= 0, True)
    _ = server.poll(0)


def test_verify_failure() raises:
    var server = start_server(16 << 20, OPENSSL)
    # The system store does not trust the test certificate.
    var settings = ClientConfig()
    settings.timeout_ms = 20000
    var c = H3Client(
        QuicContext.client(Quic(OpenSsl(), transport=OPENSSL)), settings
    )
    var kind = TlsErrorKind.OS
    try:
        _ = c.get("https://localhost:" + String(server[1]) + "/")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.VERIFY)
    stop(server[0])


def test_client_without_name_check() raises:
    """A client that does not check the name still trusts the CA."""
    var server = make_server(OPENSSL)
    var raw = RawClient(server, OPENSSL, verify=False)
    assert_true(raw.quic.handshake_done(raw.ssl))
    var good = raw.open(False)
    raw.send(good, request_bytes("/echo", "hi"), True)
    var reply = raw.receive(server, good)
    assert_equal(reply[1], ReadState.END)
    raw.quic.free(good)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
