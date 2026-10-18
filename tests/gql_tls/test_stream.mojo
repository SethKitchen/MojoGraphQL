# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.stream`: the handshake, ALPN, a round trip, the end
of a stream and verification failures. There is no upstream suite; the
cases follow RFC 8446, RFC 7301 and RFC 6125."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _tls import (
    client_context,
    handshake_both,
    loopback_pair,
    server_context,
)
from gql_http.socket import POLLIN, Sys
from gql_tls.context import TlsContext
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_tls.stream import IoWant, TlsStream


def test_handshake_and_alpn_h2() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var server_ctx = server_context()
    var client_ctx = client_context()
    var server = TlsStream.accept(server_ctx, pair.server)
    var client = TlsStream.connect(client_ctx, pair.client, "localhost")
    handshake_both(sys, client, server)
    assert_true(client.established)
    assert_equal(client.protocol, "h2")
    assert_equal(server.protocol, "h2")
    assert_equal(client.handshake(), IoWant.NOTHING)
    pair.close(sys)


def test_alpn_http11_and_none() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var server_ctx = server_context()
    var client_ctx = client_context(["http/1.1"])
    var server = TlsStream.accept(server_ctx, pair.server)
    var client = TlsStream.connect(client_ctx, pair.client, "localhost")
    handshake_both(sys, client, server)
    assert_equal(server.protocol, "http/1.1")
    pair.close(sys)
    # No protocol in common: the handshake goes on without ALPN.
    pair = loopback_pair(sys)
    var other = client_context(["spdy/3"])
    server = TlsStream.accept(server_ctx, pair.server)
    client = TlsStream.connect(other, pair.client, "127.0.0.1")
    handshake_both(sys, client, server)
    assert_equal(server.protocol, "")
    assert_equal(client.protocol, "")
    pair.close(sys)


def test_round_trip_and_end() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var server_ctx = server_context()
    var client_ctx = client_context()
    var server = TlsStream.accept(server_ctx, pair.server)
    var client = TlsStream.connect(client_ctx, pair.client, "localhost")
    handshake_both(sys, client, server)
    var message = List[UInt8]("ping".as_bytes())
    assert_equal(client.write(message.unsafe_ptr(), len(message)), 4)
    var buffer = List[UInt8](length=64, fill=0)
    var n = server.read(buffer.unsafe_ptr(), 64)
    while n < 0:
        _ = sys.poll(pair.server, POLLIN, 100)
        n = server.read(buffer.unsafe_ptr(), 64)
    assert_equal(n, 4)
    assert_equal(String(unsafe_from_utf8=Span(buffer)[0:4]), "ping")
    assert_equal(server.pending(), 0)
    # Nothing more: the read waits.
    assert_equal(server.read(buffer.unsafe_ptr(), 64), IoWant.READ.code())
    assert_true(client.shutdown())
    n = server.read(buffer.unsafe_ptr(), 64)
    while n < 0:
        _ = sys.poll(pair.server, POLLIN, 100)
        n = server.read(buffer.unsafe_ptr(), 64)
    assert_equal(n, 0)
    pair.close(sys)


def test_verify_failure_system_store() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var server_ctx = server_context()
    # The system store does not trust a self-signed certificate.
    var client_ctx = TlsContext.client(OpenSsl())
    var server = TlsStream.accept(server_ctx, pair.server)
    var client = TlsStream.connect(client_ctx, pair.client, "localhost")
    try:
        handshake_both(sys, client, server)
        raise Error("expected a verification error")
    except e:
        assert_true(String(e).startswith("verify: "))
    pair.close(sys)


def test_verify_failure_wrong_host() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var server_ctx = server_context()
    var client_ctx = client_context()
    var server = TlsStream.accept(server_ctx, pair.server)
    var client = TlsStream.connect(client_ctx, pair.client, "example.com")
    try:
        handshake_both(sys, client, server)
        raise Error("expected a verification error")
    except e:
        assert_true(String(e).find("mismatch") >= 0)
    pair.close(sys)


def test_no_verify() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var server_ctx = server_context()
    var client_ctx = TlsContext.client(OpenSsl(), verify=False)
    var server = TlsStream.accept(server_ctx, pair.server)
    var client = TlsStream.connect(client_ctx, pair.client, "example.com")
    handshake_both(sys, client, server)
    assert_true(client.established)
    pair.close(sys)


def test_missing_library() raises:
    var raised = False
    try:
        _ = OpenSsl("libssl-missing.so.3")
    except e:
        raised = True
        assert_equal(e.kind, TlsErrorKind.LIBRARY)
        assert_true(e.message.find("libssl-missing.so.3") >= 0)
        assert_true(e.message.find("Install") >= 0)
    assert_true(raised)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
