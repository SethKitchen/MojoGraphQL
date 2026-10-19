# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.client`: request checks, connection failures, the
pool, and when a failed request goes again on a new connection. There is
no upstream suite; the cases follow RFC 9112 and RFC 9110 section 9.2.2."""

from std.testing import TestSuite, assert_equal, assert_true

from _serve import BIG, start_server
from _tls import client_context
from gql_http.client import ClientConfig
from gql_http.headers import Headers
from gql_http.socket import Faults, SysCall
from gql_http.status import Method
from gql_tls.client import HttpsClient
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import (
    SSL_ERROR_SYSCALL,
    SSL_ERROR_WANT_WRITE,
    TlsCall,
    TlsFaults,
)


def client(timeout_ms: Int = 3000, idle: Int = 8) raises -> HttpsClient:
    var config = ClientConfig()
    config.timeout_ms = timeout_ms
    config.max_idle_per_host = idle
    return HttpsClient(client_context(["http/1.1"]), config)


def send_kind(
    mut c: HttpsClient,
    method: Method,
    target: String,
    headers: Headers = Headers(),
) raises -> TlsErrorKind:
    """Send a request to a port without a server; return the error kind."""
    var endpoint = c.endpoint("https://localhost:1/")
    try:
        _ = c.send(endpoint, method, target, headers, List[UInt8]())
    except e:
        return e.kind
    return TlsErrorKind.OS


def get_kind(mut c: HttpsClient, url: String) raises -> TlsErrorKind:
    """Send a `GET`; return the kind of its error."""
    try:
        _ = c.get(url)
    except e:
        return e.kind
    return TlsErrorKind.OS


def test_request_checks() raises:
    var c = client()
    assert_equal(send_kind(c, Method.OTHER, "/"), TlsErrorKind.USAGE)
    assert_equal(send_kind(c, Method(10), "/"), TlsErrorKind.USAGE)
    assert_equal(send_kind(c, Method.GET, ""), TlsErrorKind.USAGE)
    assert_equal(send_kind(c, Method.GET, "/a b"), TlsErrorKind.USAGE)
    assert_equal(send_kind(c, Method.GET, "/" + chr(127)), TlsErrorKind.USAGE)
    var length = Headers()
    length.add("Content-Length", "0")
    assert_equal(send_kind(c, Method.GET, "/", length), TlsErrorKind.USAGE)
    var chunked = Headers()
    chunked.add("Transfer-Encoding", "chunked")
    assert_equal(send_kind(c, Method.GET, "/", chunked), TlsErrorKind.USAGE)
    var kind = TlsErrorKind.OS
    try:
        _ = c.post("https://localhost:1/", "text/plain\r\nX: y", "")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.USAGE)
    _ = HttpsClient.system()


def test_connect_errors() raises:
    var c = client()
    c.sys.faults = Faults(SysCall.SOCKET, 24, 0, 1)
    assert_equal(get_kind(c, "https://localhost:1/"), TlsErrorKind.OS)
    c.sys.faults = Faults(SysCall.CONNECT, 111, 0, 1)
    assert_equal(get_kind(c, "https://localhost:1/"), TlsErrorKind.CONNECT)
    var text = String()
    try:
        _ = c.get("https://localhost:1/")
    except e:
        text = e.message
    assert_equal(text, "cannot connect to https://localhost:1: errno 111")
    var child = start_server()
    var base = "https://localhost:" + String(child.port)
    var late = client(timeout_ms=-1)
    assert_equal(get_kind(late, base + "/"), TlsErrorKind.TIMEOUT)
    c.context.openssl.faults = TlsFaults(TlsCall.SSL_NEW, 0, 1)
    assert_equal(get_kind(c, base + "/"), TlsErrorKind.CONFIG)
    # A write that must wait, on a new connection.
    c.context.openssl.faults = TlsFaults(
        TlsCall.WRITE, 0, 1, SSL_ERROR_WANT_WRITE
    )
    assert_equal(c.get(base + "/w").text(), "/w:")
    # A read that fails on a new connection is not sent again.
    c.close_idle()
    c.context.openssl.faults = TlsFaults(TlsCall.READ, 0, 1, SSL_ERROR_SYSCALL)
    assert_equal(get_kind(c, base + "/"), TlsErrorKind.CLOSED)
    child.stop()


def test_pool() raises:
    var child = start_server()
    var base = "https://localhost:" + String(child.port)
    var c = client()
    assert_equal(c.get(base + "/a").text(), "/a:")
    # Another address and another port do not take the pooled connection.
    var other = "https://127.0.0.2:" + String(child.port) + "/"
    assert_equal(get_kind(c, other), TlsErrorKind.CONNECT)
    assert_equal(get_kind(c, "https://localhost:1/"), TlsErrorKind.CONNECT)
    assert_equal(c.idle_connections(), 1)
    assert_equal(c.post(base + "/e", "text/plain", "").text(), "/e:")
    var headers = Headers()
    headers.add("Host", "localhost")
    var endpoint = c.endpoint(base + "/h")
    var r = c.send(endpoint, Method.GET, "/h", headers, List[UInt8]())
    assert_equal(r.text(), "/h:")
    # A big response grows the buffer.
    assert_equal(c.get(base + "/big").text().byte_length(), BIG)
    # A pooled connection whose check fails is closed.
    c.sys.faults = Faults(SysCall.RECV, 104, 0, 1)
    c._idle[0].stream.openssl.faults = TlsFaults(TlsCall.READ, 0, 1)
    assert_equal(c.get(base + "/b").text(), "/b:")
    assert_equal(c.idle_connections(), 1)
    # Without a pool, nothing stays.
    var single = client(idle=0)
    _ = single.get(base + "/a")
    assert_equal(single.idle_connections(), 0)
    # A server that has gone leaves a stale connection.
    child.stop()
    assert_equal(get_kind(c, base + "/"), TlsErrorKind.CONNECT)
    assert_equal(c.idle_connections(), 0)


def test_retries() raises:
    var child = start_server()
    var base = "https://localhost:" + String(child.port)
    var c = client()
    _ = c.get(base + "/a")
    # A send that fails on a pooled connection goes again on a new one.
    c._idle[0].stream.openssl.faults = TlsFaults(TlsCall.WRITE, 0, 1)
    assert_equal(c.get(base + "/b").text(), "/b:")
    # A read that fails with a TLS error does not.
    c._idle[0].stream.openssl.faults = TlsFaults(TlsCall.READ, 0, 1)
    assert_equal(get_kind(c, base + "/c"), TlsErrorKind.PROTOCOL)
    _ = c.get(base + "/a")
    # A closed connection: an idempotent request goes again.
    c._idle[0].stream.openssl.faults = TlsFaults(
        TlsCall.READ, 0, 1, SSL_ERROR_SYSCALL
    )
    assert_equal(c.get(base + "/d").text(), "/d:")
    # A POST does not.
    c._idle[0].stream.openssl.faults = TlsFaults(
        TlsCall.READ, 0, 1, SSL_ERROR_SYSCALL
    )
    var kind = TlsErrorKind.OS
    try:
        _ = c.post(base + "/e", "text/plain", "x")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CLOSED)
    _ = c.get(base + "/a")
    # Nor a request whose response had begun.
    c._idle[0].stream.openssl.faults = TlsFaults(
        TlsCall.READ, 2, 1, SSL_ERROR_SYSCALL
    )
    assert_equal(get_kind(c, base + "/big"), TlsErrorKind.CLOSED)
    child.stop()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
