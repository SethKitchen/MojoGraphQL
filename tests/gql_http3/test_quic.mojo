# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.quic`: the kinds, the fault plan, the contexts and
the stream reads and writes of the OpenSSL QUIC API. There is no upstream
suite; the cases follow RFC 9000 sections 2 and 4."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _h3 import RawClient, make_server
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_http3.quic import (
    Quic,
    QuicCall,
    QuicContext,
    QuicFaults,
    ReadResult,
    ReadState,
)


def test_kinds() raises:
    assert_true(QuicCall.READ.is_valid())
    assert_false(QuicCall(9).is_valid())
    assert_equal(String(QuicCall.WRITE), "QuicCall(6)")
    assert_true(ReadState.RESET.is_valid())
    assert_false(ReadState(4).is_valid())
    assert_equal(String(ReadResult(3, ReadState.END)), "3 end")


def test_wants_io() raises:
    assert_true(Quic.wants_io(2))
    assert_true(Quic.wants_io(3))
    assert_false(Quic.wants_io(1))


def test_fault_plan() raises:
    var plan = QuicFaults(QuicCall.READ, 1, 1)
    assert_false(plan.take(QuicCall.WRITE))
    assert_false(plan.take(QuicCall.READ))
    assert_true(plan.take(QuicCall.READ))
    assert_false(plan.take(QuicCall.READ))
    var forever = QuicFaults(QuicCall.READ, 0, -1)
    assert_true(forever.take(QuicCall.READ))
    assert_true(forever.take(QuicCall.READ))


def test_missing_api() raises:
    var kind = TlsErrorKind.OS
    try:
        _ = Quic(OpenSsl(), "SSL_no_such_function")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.LIBRARY)


def config_kind(which: Int, cert: String) -> TlsErrorKind:
    try:
        var quic = Quic(OpenSsl())
        if which == 0:
            quic.faults = QuicFaults(QuicCall.CTX_NEW, 0, 1)
            _ = QuicContext.client(quic^)
        elif which == 1:
            _ = QuicContext.server(quic^, "/no/cert.pem", "/no/key.pem")
        elif which == 2:
            _ = QuicContext.server(quic^, cert, "/no/key.pem")
        else:
            _ = QuicContext.client(quic^, "/no/ca.pem")
    except e:
        return e.kind
    return TlsErrorKind.OS


def test_context_errors() raises:
    var cert = test_certs().cert
    var which = 0
    while which < 4:
        assert_equal(config_kind(which, cert), TlsErrorKind.CONFIG)
        which += 1
    var open = QuicContext.client(Quic(OpenSsl()), verify=False)
    assert_false(open.verify)


def test_calls_that_fail() raises:
    var quic = Quic(OpenSsl())
    quic.faults = QuicFaults(QuicCall.SOCKET, 0, 1)
    assert_equal(quic.udp_socket(), -1)
    quic.faults = QuicFaults(QuicCall.LISTENER, 0, 1)
    assert_equal(quic.listener(0, -1), 0)
    quic.faults = QuicFaults(QuicCall.CONNECTION, 0, 1)
    assert_equal(quic.client_connection(0, -1, "x", True), 0)
    quic.faults = QuicFaults(QuicCall.NEW_STREAM, 0, 1)
    assert_equal(quic.new_stream(0, True), 0)
    var buffer = List[UInt8](length=8, fill=0)
    quic.faults = QuicFaults(QuicCall.READ, 0, 1)
    assert_equal(quic.read(0, buffer.unsafe_ptr(), 8).state, ReadState.RESET)
    quic.faults = QuicFaults(QuicCall.WRITE, 0, 1)
    assert_equal(quic.write(0, buffer.unsafe_ptr(), 8, False), -1)


def test_write_without_credit_and_after_close() raises:
    var server = make_server()
    var client = RawClient(server)
    var stream = client.open(False)
    var big = List[UInt8](length=4 << 20, fill=0)
    assert_equal(client.quic.write(stream, big.unsafe_ptr(), 0, False), 0)
    # Without the server reading the stream, the flow control window fills.
    var taken = client.quic.write(stream, big.unsafe_ptr(), len(big), False)
    assert_true(taken >= 0 and taken < len(big))
    client.quic.close_connection(client.ssl, 0x100)
    client.quic.handle_events(client.ssl)
    assert_equal(client.quic.write(stream, big.unsafe_ptr(), 8, False), -1)
    assert_equal(
        client.quic.read(stream, big.unsafe_ptr(), 8).state, ReadState.RESET
    )
    client.quic.free(stream)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
