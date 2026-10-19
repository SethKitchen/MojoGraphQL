# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.server`: the life of the loop, and each system call
or OpenSSL call that can fail, through the fault plans. There is no
upstream suite; the cases follow RFC 9112 section 9.6 and RFC 8446."""

from std.testing import TestSuite, assert_equal, assert_true

from _serve import Echo, Upper, config, dial, open_client, send_text, turns
from _tls import client_context, server_context
from gql_http.socket import Faults, Sys, SysCall
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import SSL_ERROR_WANT_WRITE, TlsCall, TlsFaults
from gql_tls.server import listen_https, listen_tls
from gql_tls.stream import IoWant, TlsStream


def faulty(call: SysCall, skip: Int = 0) -> Sys:
    """System calls whose call of one kind fails once with `EBADF`."""
    var sys = Sys()
    sys.faults = Faults(call, 9, skip, 1)
    return sys^


def listen_error(var sys: Sys) raises -> String:
    """Open a server, and return the text of its error."""
    var context = server_context(["http/1.1"])
    try:
        _ = listen_https(Echo(), context^, config(), sys^)
    except e:
        assert_equal(e.kind, TlsErrorKind.OS)
        return e.message
    return "no error"


def test_listen_faults() raises:
    assert_true(listen_error(faulty(SysCall.SOCKET)).startswith("socket"))
    assert_true(
        listen_error(faulty(SysCall.EPOLL_CREATE)).startswith("epoll_create1")
    )
    assert_true(listen_error(faulty(SysCall.EPOLL_CTL)).startswith("epoll_ctl"))


def test_epoll_wait_faults() raises:
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, 4, 0, 1)
    assert_equal(server.poll(0), 0)
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, 9, 0, 1)
    var kind = TlsErrorKind.USAGE
    try:
        _ = server.poll(0)
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.OS)


def test_close_with_open_connection() raises:
    var sys = Sys()
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    var client = open_client(sys, server)
    assert_equal(server.open_connections, 1)
    server.close()
    assert_equal(server.open_connections, 0)
    # A shutdown after the close has no socket to stop.
    server.begin_shutdown()
    assert_true(server.stopped())
    sys.close(client.fd)


def test_shutdown_idle_and_busy() raises:
    var sys = Sys()
    var c = config()
    c.shutdown_timeout_ms = 0
    var server = listen_tls(
        Echo(), server_context(["upper/1", "http/1.1"]), c, Upper()
    )
    var idle = open_client(sys, server)
    var busy = open_client(sys, server, ["upper/1"])
    turns(server, 2)
    assert_equal(server.open_connections, 2)
    server.begin_shutdown()
    # The idle HTTP/1.1 connection ends at once; the other one is busy.
    assert_equal(server.open_connections, 1)
    server.begin_shutdown()
    send_text(busy, "abc")
    server.run()
    assert_true(server.stopped())
    assert_equal(server.poll(0), 0)
    sys.close(idle.fd)
    sys.close(busy.fd)


def test_idle_sweep() raises:
    var sys = Sys()
    var quick = config()
    quick.idle_timeout_ms = 0
    var server = listen_https(Echo(), server_context(["http/1.1"]), quick)
    var client = open_client(sys, server)
    server._last_sweep = server._now - 5000
    turns(server, 1)
    assert_equal(server.open_connections, 0)
    sys.close(client.fd)
    # A connection before its deadline stays.
    var patient = listen_https(Echo(), server_context(["http/1.1"]), config())
    var other = open_client(sys, patient)
    patient._last_sweep = patient._now - 5000
    turns(patient, 1)
    assert_equal(patient.open_connections, 1)
    sys.close(other.fd)


def test_accept_limits_and_faults() raises:
    var sys = Sys()
    var full = config()
    full.max_connections = 0
    var server = listen_https(Echo(), server_context(["http/1.1"]), full)
    var a = dial(sys, server.port)
    turns(server, 3)
    assert_equal(server.open_connections, 0)
    sys.close(a)
    var second = listen_https(Echo(), server_context(["http/1.1"]), config())
    second.context.openssl.faults = TlsFaults(TlsCall.SSL_NEW, 0, 1)
    var b = dial(sys, second.port)
    turns(second, 3)
    assert_equal(second.open_connections, 0)
    sys.close(b)
    second.context.openssl.faults = TlsFaults()
    second.sys.faults = Faults(SysCall.EPOLL_CTL, 9, 0, 1)
    var d = dial(sys, second.port)
    turns(second, 3)
    assert_equal(second.open_connections, 0)
    sys.close(d)


def test_read_faults() raises:
    var sys = Sys()
    # A read that fails closes the connection.
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    server.context.openssl.faults = TlsFaults(TlsCall.READ, 0, 1)
    var a = open_client(sys, server)
    turns(server, 2)
    assert_equal(server.open_connections, 0)
    sys.close(a.fd)
    # A read that needs a write waits for the socket, then goes on.
    server.context.openssl.faults = TlsFaults(
        TlsCall.READ, 0, 1, SSL_ERROR_WANT_WRITE
    )
    var b = open_client(sys, server)
    turns(server, 2)
    assert_equal(server.open_connections, 1)
    sys.close(b.fd)
    turns(server, 2)
    # The same, when epoll refuses the change.
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 9, 1, 1)
    var d = open_client(sys, server)
    turns(server, 2)
    assert_equal(server.open_connections, 0)
    sys.close(d.fd)


def test_handshake_waits_for_write() raises:
    var sys = Sys()
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    server.context.openssl.faults = TlsFaults(
        TlsCall.HANDSHAKE, 1, 1, SSL_ERROR_WANT_WRITE
    )
    var fd = dial(sys, server.port)
    var context = client_context(["http/1.1"])
    var client = TlsStream.connect(context, fd, "localhost")
    var count = 0
    while client.handshake() != IoWant.NOTHING and count < 2000:
        _ = server.poll(5)
        count += 1
    # The end of the handshake waits for a write, then epoll refuses to
    # watch for reads again.
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 9, 1, 1)
    turns(server, 4)
    assert_equal(server.open_connections, 0)
    sys.close(fd)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
