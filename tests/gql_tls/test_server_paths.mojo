# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.server`: `100 Continue`, bad requests, failed
handlers, and responses that the socket cannot take at once. There is no
upstream suite; the cases follow RFC 9110 section 10.1.1 and RFC 9112."""

from std.testing import TestSuite, assert_equal, assert_true

from _serve import (
    BIG,
    Echo,
    config,
    conn_fd,
    open_client,
    read_count,
    read_text,
    send_text,
    turns,
)
from _tls import server_context
from gql_http.socket import Faults, Sys, SysCall
from gql_tls.openssl import TlsCall, TlsFaults
from gql_tls.server import listen_https


def test_continue_fail_and_bad_request() raises:
    var sys = Sys()
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    var client = open_client(sys, server)
    send_text(
        client,
        (
            "POST /a HTTP/1.1\r\nHost: x\r\nExpect: 100-continue\r\n"
            "Content-Length: 2\r\n\r\n"
        ),
    )
    assert_true(
        read_text(server, client, "100 Continue\r\n\r\n").startswith(
            "HTTP/1.1 100 Continue"
        )
    )
    send_text(client, "hi")
    assert_true(read_text(server, client, "/a:hi").find("/a:hi") > 0)
    send_text(client, "GET /fail HTTP/1.1\r\nHost: x\r\n\r\n")
    assert_true(
        read_text(server, client, "\r\n\r\n").startswith("HTTP/1.1 500")
    )
    send_text(client, "BAD\r\n\r\n")
    assert_true(read_text(server, client, "never").find("HTTP/1.1 400") >= 0)
    assert_equal(server.open_connections, 0)
    sys.close(client.fd)


def test_big_response() raises:
    var sys = Sys()
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    var client = open_client(sys, server, small=True)
    send_text(client, "GET /big HTTP/1.1\r\nHost: x\r\n\r\n")
    turns(server, 3)
    var fd = conn_fd(server)
    assert_true(len(server._conns[fd].pending) > 0)
    assert_true(read_count(server, client, BIG + 1) > BIG)
    turns(server, 2)
    assert_equal(len(server._conns[fd].pending), 0)
    # The connection stays open, and closes after a big response that
    # asks for it.
    send_text(client, "GET /a HTTP/1.1\r\nHost: x\r\n\r\n")
    assert_true(read_text(server, client, "/a:").find("/a:") > 0)
    send_text(client, "GET /bigclose HTTP/1.1\r\nHost: x\r\n\r\n")
    assert_true(read_count(server, client, 2 * BIG) > BIG)
    assert_equal(server.open_connections, 0)
    sys.close(client.fd)


def test_write_faults() raises:
    var sys = Sys()
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    # The first write of the response fails.
    server.context.openssl.faults = TlsFaults(TlsCall.WRITE, 0, 1)
    var a = open_client(sys, server)
    send_text(a, "GET /a HTTP/1.1\r\nHost: x\r\n\r\n")
    assert_equal(read_text(server, a, "never"), "")
    assert_equal(server.open_connections, 0)
    sys.close(a.fd)
    server.context.openssl.faults = TlsFaults()
    # A later write of a big response fails.
    var b = open_client(sys, server, small=True)
    send_text(b, "GET /big HTTP/1.1\r\nHost: x\r\n\r\n")
    turns(server, 3)
    var fd = conn_fd(server)
    server._conns[fd].stream.openssl.faults = TlsFaults(TlsCall.WRITE, 0, 1)
    _ = read_count(server, b, BIG + 1)
    assert_equal(server.open_connections, 0)
    sys.close(b.fd)


def test_watch_faults() raises:
    var sys = Sys()
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    # epoll refuses to watch for writes when the response waits.
    var a = open_client(sys, server, small=True)
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 9, 0, 1)
    send_text(a, "GET /big HTTP/1.1\r\nHost: x\r\n\r\n")
    turns(server, 3)
    assert_equal(server.open_connections, 0)
    sys.close(a.fd)
    # epoll refuses to watch for reads after the response went out.
    var b = open_client(sys, server, small=True)
    send_text(b, "GET /big HTTP/1.1\r\nHost: x\r\n\r\n")
    turns(server, 3)
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 9, 0, 1)
    _ = read_count(server, b, BIG + 1)
    turns(server, 2)
    assert_equal(server.open_connections, 0)
    sys.close(b.fd)


def test_request_of_many_records() raises:
    var sys = Sys()
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    var client = open_client(sys, server)
    var body = String("b") * 40000
    send_text(
        client,
        "POST /p HTTP/1.1\r\nHost: x\r\nContent-Length: 40000\r\n\r\n" + body,
    )
    assert_true(read_count(server, client, 40003) >= 40003)
    sys.close(client.fd)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
