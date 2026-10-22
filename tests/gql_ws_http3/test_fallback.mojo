# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http3.fallback` on loopback: HTTP/3 first, HTTP/2
over TLS when HTTP/3 fails or does not allow the extended `CONNECT`, and
`connect_ws` for `ws://`. There is no upstream suite; the cases follow
tests/gql_ws_http2/test_fallback.mojo and RFC 9220 section 3."""

from std.testing import TestSuite, assert_equal, assert_true

from _certs import test_certs
from _tlsws import start_h2c_ws_server, start_tls_ws_server
from _wsh3 import start_silent_server, start_stub_server, start_ws_server, stop
from gql_ws.client import ClientConfig
from gql_ws.error import WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message
from gql_ws_http3.fallback import (
    WsH3AnyClient,
    connect_any,
    connect_any_transport,
    connect_h2_tls,
)

comptime GTW = "graphql-transport-ws"


def wss(port: Int, path: StaticString = "/ws") -> String:
    return "wss://localhost:" + String(port) + path


def echo(mut client: WsH3AnyClient) raises:
    """Check an echo, then the closing handshake."""
    assert_equal(client.protocol(), GTW)
    client.send_text("hello")
    var message = Message()
    assert_true(client.read(message, 2000))
    assert_equal(String(message.text()), "hello")
    client.close(CloseCode.NORMAL, "bye")
    var closed = False
    var turns = 0
    while turns < 10:
        try:
            _ = client.read(message, 2000)
        except e:
            closed = e.kind == WsErrorKind.CLOSED
            break
        turns += 1
    assert_true(closed)


def any_kind(url: String, ca_file: String) -> WsErrorKind:
    try:
        var client = connect_any(url, [GTW], ClientConfig(), ca_file)
        _ = client.version()
    except e:
        return e.kind
    return WsErrorKind.CLOSED


def tls_kind(url: String, ca_file: String) -> WsErrorKind:
    try:
        var socket = connect_h2_tls(url, [GTW], ClientConfig(), ca_file)
        _ = socket.protocol
    except e:
        return e.kind
    return WsErrorKind.CLOSED


def test_h3() raises:
    var ca = test_certs().cert
    var server = start_ws_server()
    var client = connect_any(wss(server[1]), [GTW], ClientConfig(), ca)
    assert_equal(client.version(), "h3")
    echo(client)
    var transport = connect_any_transport(
        wss(server[1]), "", 2000, ClientConfig(), ca
    )
    assert_equal(transport.socket.version(), "h3")
    transport.close()
    stop(server[0])


def test_h2_over_tls_without_udp() raises:
    """Nothing listens on the UDP port: HTTP/2 over TLS."""
    var ca = test_certs().cert
    var server = start_tls_ws_server()
    var client = connect_any(wss(server[1]), [GTW], ClientConfig(), ca)
    assert_equal(client.version(), "h2")
    echo(client)
    stop(server[0])


def test_h2_over_tls_when_h3_refuses_connect() raises:
    """HTTP/3 answers without SETTINGS_ENABLE_CONNECT_PROTOCOL."""
    var ca = test_certs().cert
    var tls = start_tls_ws_server()
    var h3 = start_stub_server(2, tls[1])
    var client = connect_any(wss(tls[1]), [GTW], ClientConfig(), ca)
    assert_equal(client.version(), "h2")
    echo(client)
    stop(h3[0])
    stop(tls[0])


def test_h2_over_tls_when_h3_is_silent() raises:
    """QUIC answers, but no SETTINGS come within `h3_timeout_ms`."""
    var ca = test_certs().cert
    var tls = start_tls_ws_server()
    var h3 = start_silent_server(tls[1])
    var client = connect_any(
        wss(tls[1], "/ws?a=1"), [GTW], ClientConfig(), ca, True, 300
    )
    assert_equal(client.version(), "h2")
    echo(client)
    stop(h3[0])
    stop(tls[0])


def test_ws_url_http1() raises:
    var server = start_h2c_ws_server(False)
    var url = "ws://127.0.0.1:" + String(server[1]) + "/ws"
    var client = connect_any(url, [GTW])
    assert_equal(client.version(), "http/1.1")
    echo(client)
    stop(server[0])


def test_ws_url() raises:
    var server = start_h2c_ws_server()
    var url = "ws://127.0.0.1:" + String(server[1]) + "/ws"
    var client = connect_any(url, [GTW])
    assert_equal(client.version(), "h2c")
    echo(client)
    stop(server[0])


def test_refusal_does_not_fall_back() raises:
    var ca = test_certs().cert
    var server = start_ws_server("/graphql")
    var raised = False
    try:
        _ = connect_any(wss(server[1]), [GTW], ClientConfig(), ca)
    except e:
        raised = True
        assert_equal(e.kind, WsErrorKind.HANDSHAKE)
        assert_equal(e.status, 404)
    assert_true(raised)
    stop(server[0])


def test_failures() raises:
    var ca = test_certs().cert
    assert_equal(any_kind("nonsense", ca), WsErrorKind.HANDSHAKE)
    assert_equal(any_kind("http://localhost/", ca), WsErrorKind.HANDSHAKE)
    assert_equal(tls_kind("nonsense", ca), WsErrorKind.HANDSHAKE)
    assert_equal(tls_kind("ws://localhost/", ca), WsErrorKind.HANDSHAKE)
    # Nothing listens: neither UDP nor TCP. The default port is 443.
    assert_equal(any_kind("wss://127.0.0.1/", ca), WsErrorKind.IO)
    assert_equal(any_kind("wss://nowhere.invalid/", ca), WsErrorKind.IO)
    # A trust store that does not load.
    assert_equal(any_kind("wss://127.0.0.1:1/", "/no/such.pem"), WsErrorKind.IO)
    # A TLS server that does not choose h2.
    var http1 = start_tls_ws_server(0, "http/1.1")
    assert_equal(tls_kind(wss(http1[1]), ca), WsErrorKind.HANDSHAKE)
    stop(http1[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
