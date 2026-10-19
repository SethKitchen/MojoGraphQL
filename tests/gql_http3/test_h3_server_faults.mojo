# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the error paths of `gql_http3.server`: failed system calls
and QUIC calls, a client that closes or resets, and requests that the
stream reader refuses. There is no upstream suite; the cases follow RFC
9114 sections 4.1.2 and 8."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _h3 import (
    Echo,
    RawClient,
    config,
    control_bytes,
    make_server,
    make_server_with,
    request_bytes,
)
from gql_http.socket import Faults, Sys, SysCall
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_http3.frame import FrameType, write_frame_header
from gql_http3.quic import Quic, QuicCall, QuicContext, QuicFaults, ReadState
from gql_http3.server import H3Server


def start_kind(
    call: QuicCall, sys_call: SysCall, cert: String, key: String
) -> TlsErrorKind:
    try:
        var quic = Quic(OpenSsl())
        quic.faults = QuicFaults(call, 0, 1)
        var context = QuicContext.server(quic^, cert, key)
        var sys = Sys()
        sys.faults = Faults(sys_call, 98, 0, 1)
        _ = H3Server(Echo(), context^, config(), sys^)
    except e:
        return e.kind
    return TlsErrorKind.USAGE


def test_start_errors() raises:
    var c = test_certs()
    assert_equal(
        start_kind(QuicCall.SOCKET, SysCall.NONE, c.cert, c.key),
        TlsErrorKind.OS,
    )
    assert_equal(
        start_kind(QuicCall.NONE, SysCall.BIND, c.cert, c.key),
        TlsErrorKind.OS,
    )
    assert_equal(
        start_kind(QuicCall.LISTENER, SysCall.NONE, c.cert, c.key),
        TlsErrorKind.CONFIG,
    )


def test_poll_errors_and_timers() raises:
    var server = make_server()
    server.sys.faults = Faults(SysCall.POLL, 4, 0, 1)
    assert_equal(server.poll(0), 0)
    server.sys.faults = Faults(SysCall.POLL, 9, 0, 1)
    var kind = TlsErrorKind.USAGE
    try:
        _ = server.poll(0)
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.OS)
    var client = RawClient(server)
    # A connection has QUIC timers, shorter than an hour. A datagram waits,
    # so the poll returns at once.
    var stream = client.open(False)
    client.send(stream, request_bytes("/t"), True)
    _ = server.poll(3600000)
    server.close()
    server.run()


def test_client_closes() raises:
    var server = make_server()
    var client = RawClient(server)
    assert_equal(server.connections(), 1)
    client.quic.close_connection(client.ssl, 0x100)
    client.quic.handle_events(client.ssl)
    var turns = 0
    while server.connections() > 0 and turns < 200:
        client.pump(server, 1)
        turns += 1
    assert_equal(server.connections(), 0)


def test_control_stream_fails() raises:
    var quic = Quic(OpenSsl())
    quic.faults = QuicFaults(QuicCall.NEW_STREAM, 0, 1)
    var server = make_server_with(quic^)
    var client = RawClient(server)
    assert_true(client.closed(server))
    var failing = Quic(OpenSsl())
    failing.faults = QuicFaults(QuicCall.WRITE, 0, 1)
    var other = make_server_with(failing^)
    var second = RawClient(other)
    assert_true(second.closed(other))


def test_response_write_fails() raises:
    var server = make_server()
    var client = RawClient(server)
    server.quic.faults = QuicFaults(QuicCall.WRITE, 0, 1)
    var stream = client.open(False)
    client.send(stream, request_bytes("/w"), True)
    client.pump(server, 10)
    assert_equal(server.connections(), 1)


def test_client_resets_request() raises:
    var server = make_server()
    var client = RawClient(server)
    var stream = client.open(False)
    var data = request_bytes("/r")
    data.resize(len(data) - 1, 0)
    client.send(stream, data, False)
    client.pump(server, 3)
    client.quic.reset_stream(stream, 0x10C)
    client.quic.handle_events(client.ssl)
    client.pump(server, 5)
    var next = client.open(False)
    client.send(next, request_bytes("/s"), True)
    assert_equal(client.receive(server, next)[1], ReadState.END)


def test_bad_field_section_resets() raises:
    var server = make_server()
    var client = RawClient(server)
    var stream = client.open(False)
    var frame = List[UInt8]()
    write_frame_header(frame, FrameType.HEADERS, 4)
    frame.append(0x00)
    frame.append(0x00)
    frame.append(0xFF)
    frame.append(0x7F)
    client.send(stream, frame, True)
    assert_equal(client.receive(server, stream)[1], ReadState.RESET)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
