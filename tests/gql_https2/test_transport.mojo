# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_https2.transport`: reads and writes that wait, fail and
end, and the close. There is no upstream suite; the cases follow the
`Transport` contract of `gql_http2.session` and RFC 8446."""

from std.testing import TestSuite, assert_equal, assert_true

from _tls import client_context, handshake_both, loopback_pair, server_context
from gql_http.socket import EAGAIN, ECONNRESET, POLLIN, Sys
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import (
    SSL_ERROR_SYSCALL,
    SSL_ERROR_WANT_WRITE,
    TlsCall,
    TlsFaults,
)
from gql_tls.stream import TlsStream
from gql_https2.transport import TlsTransport, transport_errno


def ptr(mut data: List[UInt8]) -> Pointer[UInt8, MutUntrackedOrigin]:
    return Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=Int(data.unsafe_ptr())
    )


def cptr(data: List[UInt8]) -> Pointer[UInt8, ImmUntrackedOrigin]:
    return Pointer[UInt8, ImmUntrackedOrigin](
        unsafe_from_address=Int(data.unsafe_ptr())
    )


def test_read_write_close() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var a = TlsStream.connect(client_context(), pair.client, "localhost")
    var b = TlsStream.accept(server_context(), pair.server)
    handshake_both(sys, a, b)
    assert_equal(a.protocol, "h2")
    var client = TlsTransport(a^)
    var server = TlsTransport(b^)
    assert_equal(client.fd(), pair.client)
    var buffer = List[UInt8](length=64, fill=0)
    # Nothing has arrived: the read waits.
    assert_equal(server.read(ptr(buffer), 64), -EAGAIN)
    var hello = List[UInt8](StaticString("hello").as_bytes())
    assert_equal(client.write(cptr(hello), 5), 5)
    _ = sys.poll(pair.server, POLLIN, 2000)
    assert_equal(server.read(ptr(buffer), 64), 5)
    assert_equal(buffer[0], 104)
    # A write that must wait.
    client.stream.openssl.faults = TlsFaults(
        TlsCall.WRITE, 0, 1, SSL_ERROR_WANT_WRITE
    )
    assert_equal(client.write(cptr(hello), 5), -EAGAIN)
    # Failed calls give their error number, or ECONNRESET.
    client.stream.openssl.faults = TlsFaults(TlsCall.WRITE, 0, 1)
    assert_equal(client.write(cptr(hello), 5), -ECONNRESET)
    server.stream.openssl.faults = TlsFaults(
        TlsCall.READ, 0, 1, SSL_ERROR_SYSCALL, 104
    )
    assert_equal(server.read(ptr(buffer), 64), -104)
    # close_notify ends the stream of the peer.
    client.close()
    assert_equal(client.fd(), -1)
    client.close()
    _ = sys.poll(pair.server, POLLIN, 2000)
    assert_equal(server.read(ptr(buffer), 64), 0)
    # The transport closes its socket when it goes.
    _ = server^
    sys.close(pair.listener)


def test_transport_errno() raises:
    assert_equal(transport_errno(TlsError.os("recv", 32)), -32)
    var none = TlsError(TlsErrorKind.PROTOCOL, "bad record", 0)
    assert_equal(transport_errno(none), -ECONNRESET)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
