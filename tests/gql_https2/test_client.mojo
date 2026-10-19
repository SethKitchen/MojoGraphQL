# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_https2.client`: the fall back to HTTPS/1.1, the retry on
a reused HTTP/2 connection, the errors, and `http1_response`. There is no
upstream suite; the cases follow RFC 9113 section 3.2, RFC 7301 and
RFC 9110 section 9.2.2."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _h2tls import Script, client, start_h2, start_http1, start_script
from gql_http.headers import Headers
from gql_http.socket import Faults, SysCall
from gql_http.status import Method, Status
from gql_http2.client import Protocol, Response
from gql_http2.error import H2Error, H2ErrorKind, Reason
from gql_tls.error import TlsErrorKind
from gql_https2.client import Https2Client, http1_response, tls_error


def get_kind(mut c: Https2Client, url: String) -> TlsErrorKind:
    try:
        _ = c.get(url)
    except e:
        return e.kind
    return TlsErrorKind.OS


def send_kind(
    mut c: Https2Client, url: String, method: Method
) raises -> TlsErrorKind:
    var endpoint = c.endpoint(url)
    try:
        _ = c.send(endpoint, method, "/", Headers(), List[UInt8]())
    except e:
        return e.kind
    return TlsErrorKind.OS


def test_fall_back_to_https1() raises:
    var child = start_http1()
    var c = client()
    var first = c.post(child.url("/a"), "text/plain", "x")
    assert_equal(first.protocol, Protocol.HTTP_1_1)
    assert_equal(first.text(), "/a:x")
    # The handshake connection went to the HTTPS/1.1 pool, and stays.
    assert_equal(c.http1.idle_connections(), 1)
    assert_equal(c.connections(), 0)
    var endpoint = c.endpoint(child.url("/"))
    assert_true(c.speaks_http1(endpoint))
    # Another port and another address are not known.
    var other = endpoint.copy()
    other.port = 1
    assert_false(c.speaks_http1(other))
    var far = c.endpoint("https://127.0.0.2:" + String(child.port) + "/")
    assert_false(c.speaks_http1(far))
    assert_equal(c.get(child.url("/b")).text(), "/b:")
    assert_equal(c.http1.idle_connections(), 1)
    c.close()
    assert_equal(c.http1.idle_connections(), 0)
    child.stop()


def test_peers_by_address_and_port() raises:
    var child = start_h2()
    var second = start_h2()
    var c = client()
    assert_equal(c.get(child.url("/a")).protocol, Protocol.HTTP_2)
    # The same port on another address is another peer.
    var other = "https://127.0.0.2:" + String(child.port) + "/b"
    assert_equal(get_kind(c, other), TlsErrorKind.CONNECT)
    # Another port on the same address is another peer.
    assert_equal(c.get(second.url("/c", "127.0.0.1")).text(), "/c:")
    assert_equal(c.connections(), 2)
    # A connection that the server ends is not used again.
    assert_equal(c.get(child.url("/bye")).text(), "/bye:")
    assert_equal(c.get(child.url("/d")).text(), "/d:")
    assert_equal(c.connections(), 2)
    c.close()
    assert_equal(c.connections(), 0)
    second.stop()
    child.stop()


def test_retry_after_goaway() raises:
    # The GOAWAY refuses stream 3: the request goes on a new connection.
    var child = start_script(Script(goaway_at=3))
    var c = client()
    assert_equal(c.post(child.url("/a"), "text/plain", "1").text(), "/a:1")
    assert_equal(c.post(child.url("/b"), "text/plain", "2").text(), "/b:2")
    assert_equal(c.connections(), 1)
    child.stop()


def test_retry_after_close() raises:
    var child = start_script(Script(close_at=3))
    var c = client()
    _ = c.get(child.url("/a"))
    # The connection closes under stream 3: GET goes again.
    assert_equal(c.get(child.url("/b")).text(), "/b:")
    _ = c.get(child.url("/c"))
    # POST does not.
    var kind = TlsErrorKind.OS
    try:
        _ = c.post(child.url("/d"), "text/plain", "x")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CLOSED)
    assert_equal(c.connections(), 0)
    child.stop()


def test_timeout_is_not_retried() raises:
    var child = start_script(Script(silent_at=3))
    var c = client(timeout_ms=300)
    _ = c.get(child.url("/a"))
    assert_equal(get_kind(c, child.url("/b")), TlsErrorKind.TIMEOUT)
    # A new connection has no stream 3 yet.
    assert_equal(c.get(child.url("/c")).text(), "/c:")
    # A new connection that fails raises at once. The script drops the
    # preface with stream 1, so the server ends the connection.
    var silent = start_script(Script(silent_at=1))
    assert_equal(get_kind(c, silent.url("/d")), TlsErrorKind.PROTOCOL)
    assert_equal(c.connections(), 1)
    silent.stop()
    child.stop()


def test_errors() raises:
    var c = client()
    assert_equal(
        send_kind(c, "https://localhost:1/", Method.OTHER), TlsErrorKind.USAGE
    )
    assert_equal(
        send_kind(c, "https://localhost:1/", Method(10)), TlsErrorKind.USAGE
    )
    assert_equal(get_kind(c, "https://localhost:1/"), TlsErrorKind.CONNECT)
    assert_equal(get_kind(c, "http://localhost:1/"), TlsErrorKind.USAGE)
    var kind = TlsErrorKind.OS
    try:
        _ = c.post("https://localhost:1/", "text/plain\r\nX: y", "")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.USAGE)
    c.sys.faults = Faults(SysCall.SOCKET, 24, 0, 1)
    assert_equal(get_kind(c, "https://localhost:1/"), TlsErrorKind.OS)
    _ = Https2Client.create(c.context.openssl)
    var error = H2Error(H2ErrorKind.TIMEOUT, Reason.CANCEL, 1, "late")
    assert_equal(tls_error(error).kind, TlsErrorKind.TIMEOUT)


def test_http1_response() raises:
    var response = Response()
    response.status = Status.OK
    response.headers.add_text("content-type", "text/plain")
    response.data.extend(StaticString("hello").as_bytes())
    var copy = http1_response(response, Method.GET)
    assert_equal(copy.status, Status.OK)
    assert_equal(copy.text(), "hello")
    assert_equal(String(copy.header("content-length").value()), "5")
    # A content-length of the response stays: HEAD has no content.
    var head = Response()
    head.headers.add_text("content-length", "7")
    var empty = http1_response(head, Method.HEAD)
    assert_equal(String(empty.header("content-length").value()), "7")
    assert_equal(len(empty.body()), 0)
    # An HTTP/1.1 response: names in any case, and decoded chunks.
    var old = Response()
    old.headers.add_text("Content-Lengtx", "x")
    old.headers.add_text("Content-Length", "2")
    old.headers.add_text("Transfer-Encoding", "chunked")
    old.data.extend(StaticString("ok").as_bytes())
    var plain = http1_response(old, Method.GET)
    assert_equal(plain.text(), "ok")
    assert_false(Bool(plain.header("transfer-encoding")))
    # A field that HTTP/1.1 cannot carry.
    var bad = Response()
    bad.headers.add_text("bad name", "x")
    var kind = TlsErrorKind.OS
    try:
        _ = http1_response(bad, Method.GET)
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.PROTOCOL)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
