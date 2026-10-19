# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.stream`: the wants, the server name, and each error
that OpenSSL or the socket can give, through the fault plans. There is no
upstream suite; the cases follow RFC 8446 and RFC 6066 section 3."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _tls import client_context, handshake_both, loopback_pair, server_context
from gql_http.socket import POLLIN, POLLOUT, Faults, Sys, SysCall
from gql_tls.context import TlsContext
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import (
    OpenSsl,
    SSL_ERROR_SYSCALL,
    SSL_ERROR_WANT_WRITE,
    TlsCall,
    TlsFaults,
)
from gql_tls.stream import IoWant, TlsStream, wait_for


def test_wants() raises:
    assert_true(IoWant.WRITE.is_valid())
    assert_false(IoWant(3).is_valid())
    assert_equal(IoWant.READ.code(), -1)
    assert_equal(IoWant.from_code(-2), IoWant.WRITE)
    assert_equal(IoWant.from_code(-1), IoWant.READ)
    assert_equal(IoWant.from_code(7), IoWant.NOTHING)
    assert_equal(IoWant.WRITE.poll_events(), POLLOUT)
    assert_equal(IoWant.READ.poll_events(), POLLIN)
    assert_equal(String(IoWant.NOTHING), "nothing")
    assert_equal(String(IoWant(7)), "write")


def test_object_faults() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var context = server_context()
    context.openssl.faults = TlsFaults(TlsCall.SSL_NEW, 0, 1)
    var message = String()
    try:
        _ = TlsStream.accept(context, pair.server)
    except e:
        assert_equal(e.kind, TlsErrorKind.CONFIG)
        message = e.message
    assert_equal(message, "SSL_new failed")
    context.openssl.faults = TlsFaults(TlsCall.SET_FD, 0, 1)
    try:
        _ = TlsStream.accept(context, pair.server)
    except e:
        message = e.message
    assert_equal(message, "SSL_set_fd failed")
    pair.close(sys)


def test_server_names() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var context = client_context()
    # No name, and a name that is not an address.
    _ = TlsStream.connect(context, pair.client, "")
    _ = TlsStream.connect(context, pair.client, "1-2.example")
    _ = TlsStream.connect(context, pair.client, "::1")
    # A name too long for SNI.
    var kind = TlsErrorKind.OS
    try:
        _ = TlsStream.connect(context, pair.client, String("a") * 300)
    except e:
        kind = e.kind
        assert_true(e.message.startswith("cannot set the server name"))
    assert_equal(kind, TlsErrorKind.CONFIG)
    context.openssl.faults = TlsFaults(TlsCall.SET_HOST, 0, 1)
    kind = TlsErrorKind.OS
    try:
        _ = TlsStream.connect(context, pair.client, "localhost")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CONFIG)
    pair.close(sys)


def handshake_error(
    var client_ctx: TlsContext,
    server_faults: TlsFaults,
    client_faults: TlsFaults,
) raises -> String:
    """Run a handshake with fault plans, and return its error."""
    var sys = Sys()
    var pair = loopback_pair(sys)
    var server_ctx = server_context()
    var server = TlsStream.accept(server_ctx, pair.server)
    var client = TlsStream.connect(client_ctx, pair.client, "localhost")
    server.openssl.faults = server_faults.copy()
    client.openssl.faults = client_faults.copy()
    var text = String("no error")
    try:
        handshake_both(sys, client, server)
    except e:
        text = String(e)
    pair.close(sys)
    return text^


def test_handshake_faults() raises:
    var none = TlsFaults()
    var fail = TlsFaults(TlsCall.HANDSHAKE, 0, 1)
    # The server end; a verifying client; a client that does not verify.
    assert_true(
        handshake_error(client_context(), fail, none).startswith(
            "handshake: the TLS handshake failed"
        )
    )
    assert_true(
        handshake_error(client_context(), none, fail).startswith("handshake:")
    )
    var plain = TlsContext.client(OpenSsl(), verify=False)
    assert_true(handshake_error(plain^, none, fail).startswith("handshake:"))
    var closed = TlsFaults(TlsCall.HANDSHAKE, 0, 1, SSL_ERROR_SYSCALL, 104)
    assert_true(
        handshake_error(client_context(), none, closed).startswith(
            "closed: the peer closed the connection during the handshake"
        )
    )


def test_io_faults() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var server_ctx = server_context()
    var client_ctx = client_context()
    var server = TlsStream.accept(server_ctx, pair.server)
    var client = TlsStream.connect(client_ctx, pair.client, "localhost")
    handshake_both(sys, client, server)
    var buffer = List[UInt8](length=64, fill=0)
    # A TLS failure of a read and of a write.
    client.openssl.faults = TlsFaults(TlsCall.READ, 0, 1)
    var text = String()
    try:
        _ = client.read(buffer.unsafe_ptr(), 64)
    except e:
        text = String(e)
    assert_equal(text, "protocol: the TLS read failed")
    client.openssl.faults = TlsFaults(TlsCall.WRITE, 0, 1)
    try:
        _ = client.write(buffer.unsafe_ptr(), 4)
    except e:
        text = String(e)
    assert_equal(text, "protocol: the TLS write failed")
    # A socket failure, and an end without an error number.
    client.openssl.faults = TlsFaults(
        TlsCall.READ, 0, 1, SSL_ERROR_SYSCALL, 104
    )
    var kind = TlsErrorKind.USAGE
    try:
        _ = client.read(buffer.unsafe_ptr(), 64)
    except e:
        kind = e.kind
        assert_equal(e.errno, 104)
    assert_equal(kind, TlsErrorKind.OS)
    client.openssl.faults = TlsFaults(TlsCall.WRITE, 0, 1, SSL_ERROR_SYSCALL, 0)
    try:
        _ = client.write(buffer.unsafe_ptr(), 4)
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CLOSED)
    # A write that must wait for the socket.
    client.openssl.faults = TlsFaults(TlsCall.WRITE, 0, 1, SSL_ERROR_WANT_WRITE)
    assert_equal(client.write(buffer.unsafe_ptr(), 4), IoWant.WRITE.code())
    assert_equal(client.write(buffer.unsafe_ptr(), 4), 4)
    # A failed close_notify.
    client.openssl.faults = TlsFaults(TlsCall.SHUTDOWN, 0, 1)
    assert_false(client.shutdown())
    pair.close(sys)


def test_wait_for() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var kind = TlsErrorKind.OS
    try:
        wait_for(sys, pair.server, IoWant.READ, 0)
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.TIMEOUT)
    wait_for(sys, pair.client, IoWant.WRITE, 100)
    sys.faults = Faults()
    sys.faults.call = SysCall.POLL
    sys.faults.errno = 4
    sys.faults.count = 1
    kind = TlsErrorKind.TIMEOUT
    try:
        wait_for(sys, pair.client, IoWant.WRITE, 100)
    except e:
        kind = e.kind
        assert_equal(e.errno, 4)
    assert_equal(kind, TlsErrorKind.OS)
    pair.close(sys)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
