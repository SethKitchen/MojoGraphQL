# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.server`: HTTPS/1.1 round trips, keep-alive, ALPN
dispatch to another protocol, and shutdown. There is no upstream suite;
the cases follow RFC 9112 and RFC 7301."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _serve import Echo, Upper, config, open_client, read_text, send_text
from _tls import server_context
from gql_http.socket import Sys
from gql_tls.server import ConnectionMode, NoProtocol, listen_https, listen_tls


def test_no_protocol_and_modes() raises:
    var p = NoProtocol()
    assert_equal(p.protocol(), "")
    var out = List[UInt8]()
    p.open(3, out)
    assert_false(p.receive(3, List[UInt8](), out))
    p.close(3)
    assert_equal(len(out), 0)
    assert_true(ConnectionMode.OTHER.is_valid())
    assert_false(ConnectionMode(3).is_valid())
    assert_equal(String(ConnectionMode.HANDSHAKE), "handshake")
    assert_equal(String(ConnectionMode.HTTP1), "http1")
    assert_equal(String(ConnectionMode(9)), "other")


def test_https_round_trip_keep_alive() raises:
    var sys = Sys()
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
    var client = open_client(sys, server)
    assert_equal(client.protocol, "http/1.1")
    send_text(
        client, "POST /a HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n\r\nhi"
    )
    var first = read_text(server, client, "/a:hi")
    assert_true(first.startswith("HTTP/1.1 200 OK\r\n"))
    send_text(client, "GET /b HTTP/1.1\r\nHost: x\r\n\r\n")
    var second = read_text(server, client, "/b:")
    assert_true(second.find("Content-Length: 3") >= 0)
    assert_equal(server.open_connections, 1)
    send_text(client, "GET /close HTTP/1.1\r\nHost: x\r\n\r\n")
    var third = read_text(server, client, "never")
    assert_true(third.find("Connection: close") >= 0)
    assert_equal(server.open_connections, 0)
    sys.close(client.fd)


def test_alpn_dispatch_other_protocol() raises:
    var sys = Sys()
    var server = listen_tls(
        Echo(), server_context(["upper/1", "http/1.1"]), config(), Upper()
    )
    var client = open_client(sys, server, ["upper/1"])
    assert_equal(client.protocol, "upper/1")
    assert_true(read_text(server, client, "HELLO").find("HELLO") >= 0)
    send_text(client, "abc")
    assert_true(read_text(server, client, "ABC").find("ABC") >= 0)
    assert_equal(server.other.opened, 1)
    send_text(client, "quit")
    _ = read_text(server, client, "never")
    assert_equal(server.open_connections, 0)
    assert_equal(server.other.opened, 0)
    sys.close(client.fd)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
