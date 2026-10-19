# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.tls`: a client and a server session run the TLS 1.3
handshake of RFC 9001 section 4 in memory, level by level. The cases follow
the handshake tests of quinn-proto 0.11.19 quinn-proto/src/tests/mod.rs
(`version_negotiate_client` aside): a full handshake, ALPN, the transport
parameters, the secrets of each level, and a failed verification."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from gql_tls.context import TlsContext, TlsVersion
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl, TlsCall, TlsFaults
from gql_quic.crypto import CipherSuite
from gql_quic.tls import Level, QuicTls, Secret, TlsSession


def h3() -> List[String]:
    var out = List[String]()
    out.append("h3")
    return out^


def server_context() raises -> TlsContext:
    var certs = test_certs()
    return TlsContext.server(
        OpenSsl(), certs.cert, certs.key, h3(), TlsVersion.TLS_1_3
    )


def client_context(verify: Bool) raises -> TlsContext:
    var certs = test_certs()
    return TlsContext.client(
        OpenSsl(), h3(), certs.cert, verify, TlsVersion.TLS_1_3
    )


def params(tag: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    out.append(tag)
    out.append(0)
    return out^


def pump(mut a: TlsSession, mut b: TlsSession) -> Int:
    """Move the bytes that `a` sends to `b`; return how many moved."""
    var moved = 0
    for index in range(4):
        var level = Level(UInt8(index))
        var data = a.take_send(level)
        moved += len(data)
        if len(data) > 0:
            b.feed(level, data)
    return moved


def run(mut client: TlsSession, mut server: TlsSession) -> Bool:
    """Run both ends until neither sends; return False on a failure."""
    for _ in range(10):
        if not client.advance():
            return False
        var moved = pump(client, server)
        if not server.advance():
            return False
        moved += pump(server, client)
        if moved == 0 and client.done and server.done:
            return True
    return client.done and server.done


def test_levels() raises:
    assert_true(Level.APPLICATION.is_valid())
    assert_false(Level(4).is_valid())
    assert_equal(String(Level.HANDSHAKE), "handshake")
    assert_equal(String(Level(9)), "invalid")


def test_missing_api() raises:
    var kind = TlsErrorKind.OS
    try:
        _ = QuicTls(OpenSsl(), "SSL_no_such_function")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.LIBRARY)


def test_handshake() raises:
    var sctx = server_context()
    var cctx = client_context(True)
    var client = TlsSession(
        QuicTls(OpenSsl()), cctx.ctx, False, "localhost", True, params(1)
    )
    var server = TlsSession(
        QuicTls(OpenSsl()), sctx.ctx, True, "", False, params(2)
    )
    assert_false(client.has_send())
    assert_true(client.advance())
    assert_true(client.has_send())
    assert_true(run(client, server))
    assert_true(client.done and server.done)
    assert_equal(client.alpn(), "h3")
    assert_equal(server.alpn(), "h3")
    assert_true(client.has_peer_params())
    assert_true(server.has_peer_params())
    assert_equal(client.peer_params()[0], 2)
    assert_equal(server.peer_params()[0], 1)
    assert_equal(client.alert(), -1)
    assert_equal(client.verify_failure(), "")
    var suite = client.cipher_suite()
    assert_true(suite.is_valid())
    assert_equal(server.cipher_suite(), suite)
    # Each end yields a read and a write secret for the handshake and the
    # application levels; they match across the ends.
    var cs = client.take_secrets()
    var ss = server.take_secrets()
    assert_equal(len(cs), 4)
    assert_equal(len(ss), 4)
    for index in range(4):
        var found = False
        for other in range(4):
            if (
                cs[index].level == ss[other].level
                and cs[index].write != ss[other].write
            ):
                assert_equal(len(cs[index].secret), suite.hash_size())
                assert_true(cs[index].secret == ss[other].secret)
                found = True
        assert_true(found)
    assert_equal(len(client.take_secrets()), 0)
    # After the handshake, reads give the NewSessionTicket to libssl.
    assert_true(client.advance())
    assert_true(client.advance())
    _ = sctx.ctx
    _ = cctx.ctx


def test_ticket_while_lent() raises:
    """Bytes that arrive while libssl holds a record wait, then follow."""
    var sctx = server_context()
    var cctx = client_context(False)
    var client = TlsSession(
        QuicTls(OpenSsl()), cctx.ctx, False, "localhost", False, params(1)
    )
    var server = TlsSession(
        QuicTls(OpenSsl()), sctx.ctx, True, "", False, params(2)
    )
    assert_true(client.advance())
    _ = pump(client, server)
    assert_true(server.advance())
    # Give the client the server flight one byte short at the handshake
    # level, so libssl keeps a record and waits.
    var initial = server.take_send(Level.INITIAL)
    var handshake = server.take_send(Level.HANDSHAKE)
    client.feed(Level.INITIAL, initial)
    var last = handshake[len(handshake) - 1]
    handshake.resize(len(handshake) - 1, 0)
    client.feed(Level.HANDSHAKE, handshake)
    assert_true(client.advance())
    assert_false(client.done)
    var rest = List[UInt8]()
    rest.append(last)
    client.feed(Level.HANDSHAKE, rest)
    assert_true(client.advance())
    assert_true(client.done)
    _ = sctx.ctx
    _ = cctx.ctx


def test_verify_failure() raises:
    var sctx = server_context()
    # The system store does not trust the test certificate.
    var cctx = TlsContext.client(OpenSsl(), h3(), "", True, TlsVersion.TLS_1_3)
    var client = TlsSession(
        QuicTls(OpenSsl()), cctx.ctx, False, "localhost", True, params(1)
    )
    var server = TlsSession(
        QuicTls(OpenSsl()), sctx.ctx, True, "", False, params(2)
    )
    assert_false(run(client, server))
    assert_true(client.alert() > 0)
    assert_true(client.verify_failure().byte_length() > 0)
    _ = sctx.ctx
    _ = cctx.ctx


def test_failures() raises:
    var cctx = client_context(False)
    var openssl = OpenSsl()
    openssl.faults = TlsFaults(TlsCall.SSL_NEW, 0, 1)
    var tls = QuicTls(openssl^)
    var kind = TlsErrorKind.OS
    try:
        _ = TlsSession(tls^, cctx.ctx, False, "x", False, params(1))
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CONFIG)
    # An SSL_CTX of the QUIC stack of OpenSSL refuses the callbacks.
    var library = OpenSsl()
    var method = library.function[Int]("OSSL_QUIC_client_method")()
    var quic_ctx = library.function[Int]("SSL_CTX_new")(method)
    var refused = TlsErrorKind.OS
    try:
        _ = TlsSession(
            QuicTls(OpenSsl()), quic_ctx, False, "x", False, params(1)
        )
    except e:
        refused = e.kind
    assert_equal(refused, TlsErrorKind.CONFIG)
    library.ctx_free(quic_ctx)
    var faulty = OpenSsl()
    faulty.faults = TlsFaults(TlsCall.HANDSHAKE, 0, -1)
    var session = TlsSession(
        QuicTls(faulty^), cctx.ctx, False, "x", False, params(1)
    )
    assert_false(session.advance())
    _ = cctx.ctx


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
