# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_http.client`: end to end against worker processes of
`gql_http.server`, and against a scripted peer that sends exact bytes.
Faults in `Client.sys` reach the error paths."""

from _harness import BIG, Echo, config
from _peer import CLOSE, DEAF, DROP, HANG, KEEP, Peer, Step, start_peer
from gql_http.client import Client, ClientConfig, Endpoint, Response
from gql_http.headers import Headers
from gql_http.server import start_workers
from gql_http.socket import (
    EAGAIN,
    EBADF,
    ECONNRESET,
    EINTR,
    EPIPE,
    Faults,
    IPv4Address,
    Sys,
    SysCall,
)
from gql_http.status import Method
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime OK = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"
"""A keep-alive response with the content `ok`."""


def _url(peer: Peer, path: StaticString = "/") -> String:
    return "http://127.0.0.1:" + String(peer.port) + path


def _peer(var steps: List[Step]) raises -> Peer:
    return start_peer(steps)


def _one(reply: StaticString, action: Int = KEEP) raises -> Peer:
    return _peer([Step(reply, action)])


def _error(mut client: Client, url: String) -> String:
    """Return the error of a GET as `kind: message`, or `no error`."""
    try:
        _ = client.get(url)
    except e:
        return String(e)
    return "no error"


def _text(reply: StaticString, action: Int = KEEP) raises -> String:
    var peer = _one(reply, action)
    var client = Client()
    var text = client.get(_url(peer)).text()
    client.close_idle()
    assert_equal(peer.finish(), 0)
    return text^


def test_echo_server() raises:
    var pool = start_workers(Echo(0), config())
    var client = Client()
    var base = "http://127.0.0.1:" + String(pool.port)
    var response = client.get(base + "/hello?x=1")
    assert_equal(response.status.code, 200)
    assert_equal(response.reason(), "OK")
    assert_equal(response.text(), "GET /hello?x=1 ")
    assert_equal(response.header("content-type").value(), "text/plain")
    assert_false(Bool(response.header("x-missing")))
    assert_equal(response.header_count(), 3)
    assert_equal(response.header_name(0), "Date")
    assert_equal(response.header_value(1), "text/plain")
    assert_equal(client.idle_connections(), 1)
    response = client.post(
        base + "/graphql", "application/json", '{"query":"{a}"}'
    )
    assert_equal(response.text(), 'POST /graphql {"query":"{a}"}')
    assert_equal(client.idle_connections(), 1)
    response = client.get(base + "/stream")
    assert_equal(response.text(), "abcdef")
    response = client.get(base + "/big")
    assert_equal(len(response.body()), BIG)
    assert_equal(client.idle_connections(), 1)
    var endpoint = client.endpoint(
        "http://localhost:" + String(pool.port) + "/a?b"
    )
    assert_equal(
        String(endpoint), "http://localhost:" + String(pool.port) + "/a?b"
    )
    response = client.send(endpoint, Method.PUT, "/p", Headers(), List[UInt8]())
    assert_equal(response.text(), "PUT /p ")
    client.close_idle()
    assert_equal(client.idle_connections(), 0)
    assert_equal(pool.stop(), 0)


def test_interim_and_split() raises:
    assert_equal(_text("HTTP/1.1 100 Continue\r\n\r\n" + OK), "ok")
    assert_equal(
        _text("HTTP/1.1 103 Early Hints\r\nLink: x\r\n\r\n~" + OK), "ok"
    )
    assert_equal(
        _text("HTTP/1.1 200 OK\r\n~Content-Length: 2\r\n\r\n~ok"), "ok"
    )


def test_head_errors() raises:
    var client = Client()
    var a = _one("HTTP/1.1 101 Switching Protocols\r\n\r\n")
    assert_equal(
        _error(client, _url(a)), "protocol: the server switched protocols"
    )
    _ = a.finish()
    var b = _one("HTTP/1.1 2x0 OK\r\n\r\n")
    assert_equal(_error(client, _url(b)), "protocol: invalid response head")
    _ = b.finish()
    var c = _one("", DROP)
    assert_equal(
        _error(client, _url(c)),
        "closed: the connection closed before the response",
    )
    _ = c.finish()


def test_length_body() raises:
    var small = ClientConfig()
    small.limits.max_body_bytes = 4
    var client = Client(small)
    var a = _one("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n0123456789")
    assert_equal(_error(client, _url(a)), "limit: the response is too large")
    _ = a.finish()
    var b = _one("HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nab", CLOSE)
    assert_equal(
        _error(client, _url(b)), "closed: the connection closed in the content"
    )
    _ = b.finish()


comptime CHUNKED = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
"""A chunked response head."""


def test_chunked_body() raises:
    assert_equal(_text(CHUNKED + "3\r\nabc\r\n0\r\n\r\n"), "abc")
    assert_equal(_text(CHUNKED + "3\r\nab~c\r\n2\r\nde\r\n0\r\n~\r\n"), "abcde")
    var small = ClientConfig()
    small.limits.max_body_bytes = 4
    var client = Client(small)
    var a = _one(CHUNKED + "zz\r\n")
    assert_equal(_error(client, _url(a)), "protocol: invalid chunked content")
    _ = a.finish()
    var b = _one(CHUNKED + "a\r\n0123456789\r\n0\r\n\r\n")
    assert_equal(_error(client, _url(b)), "limit: the response is too large")
    _ = b.finish()
    var c = _one(CHUNKED + "3\r\nab", CLOSE)
    assert_equal(
        _error(client, _url(c)), "closed: the connection closed in the content"
    )
    _ = c.finish()


def test_close_delimited() raises:
    var peer = _one("HTTP/1.1 200 OK\r\n\r\nbo~dy", CLOSE)
    var client = Client()
    assert_equal(client.get(_url(peer)).text(), "body")
    assert_equal(client.idle_connections(), 0)
    _ = peer.finish()
    var small = ClientConfig()
    small.limits.max_body_bytes = 4
    var limited = Client(small)
    var big = _one("HTTP/1.1 200 OK\r\n\r\n0123456789", CLOSE)
    assert_equal(_error(limited, _url(big)), "limit: the response is too large")
    _ = big.finish()


def test_no_body() raises:
    var peer = _peer(
        [
            Step("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n", KEEP),
            Step("HTTP/1.1 204 No Content\r\n\r\n", KEEP),
        ]
    )
    var client = Client()
    var endpoint = client.endpoint(_url(peer))
    var head = client.send(endpoint, Method.HEAD, "/", Headers(), List[UInt8]())
    assert_equal(len(head.body()), 0)
    assert_equal(client.idle_connections(), 1)
    var empty = client.get(_url(peer))
    assert_equal(empty.status.code, 204)
    assert_equal(len(empty.body()), 0)
    assert_false(Bool(empty.header("Content-Type")))
    assert_equal(client.idle_connections(), 1)
    client.close_idle()
    assert_equal(peer.finish(), 0)


def test_drop_closes_idle() raises:
    var peer = _one(OK)
    var client = Client()
    _ = client.get(_url(peer))
    assert_equal(client.idle_connections(), 1)
    _ = client^
    # The peer sees the close at once, and ends with status 0.
    assert_equal(peer.finish(), 0)


def _idle_after(reply: StaticString) raises -> Int:
    var peer = _one(reply)
    var client = Client()
    _ = client.get(_url(peer))
    var idle = client.idle_connections()
    client.close_idle()
    _ = peer.finish()
    return idle


def test_keep_alive_rules() raises:
    assert_equal(_idle_after(OK), 1)
    assert_equal(
        _idle_after(
            "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length:"
            " 2\r\n\r\nok"
        ),
        0,
    )
    assert_equal(_idle_after(OK + "EXTRA"), 0)
    assert_equal(
        _idle_after("HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nok"), 0
    )
    var none = ClientConfig()
    none.max_idle_per_host = 0
    var peer = _one(OK)
    var client = Client(none)
    _ = client.get(_url(peer))
    assert_equal(client.idle_connections(), 0)
    _ = peer.finish()


def test_pool_matching() raises:
    var a = _peer([Step(OK, KEEP), Step(OK, KEEP)])
    var b = start_peer([Step(OK, KEEP)], IPv4Address(0x7F000002))
    var c = _one(OK)
    var client = Client()
    _ = client.get(_url(a))
    _ = client.get("http://127.0.0.2:" + String(b.port) + "/")
    _ = client.get(_url(c))
    assert_equal(client.idle_connections(), 3)
    _ = client.get(_url(a))
    assert_equal(client.idle_connections(), 3)
    client.close_idle()
    assert_equal(a.finish(), 0)
    assert_equal(b.finish(), 0)
    assert_equal(c.finish(), 0)


def test_stale_idle_connection() raises:
    var peer = _peer([Step(OK, CLOSE), Step(OK, KEEP)])
    var client = Client()
    assert_equal(client.get(_url(peer)).text(), "ok")
    assert_equal(client.idle_connections(), 1)
    var sys = Sys()
    _ = sys.poll(-1, 0, 50)
    assert_equal(client.get(_url(peer)).text(), "ok")
    client.close_idle()
    assert_equal(peer.finish(), 0)


def test_retry_rule() raises:
    var peer = _peer([Step(OK, KEEP), Step("", DROP), Step(OK, KEEP)])
    var client = Client()
    _ = client.get(_url(peer))
    assert_equal(client.get(_url(peer)).text(), "ok")
    client.close_idle()
    assert_equal(peer.finish(), 0)
    var once = _peer([Step(OK, KEEP), Step("", DROP)])
    var poster = Client()
    _ = poster.get(_url(once))
    var failed = String("no error")
    try:
        _ = poster.post(_url(once), "text/plain", "x")
    except e:
        failed = String(e)
    assert_equal(failed, "closed: the connection closed before the response")
    _ = once.finish()


def test_send_faults() raises:
    var peer = _peer(
        [Step(OK, KEEP), Step(OK, KEEP), Step(OK, KEEP), Step(OK, KEEP)]
    )
    var client = Client()
    client.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    assert_equal(client.get(_url(peer)).text(), "ok")
    client.sys.faults = Faults(SysCall.SEND, EINTR, 0, 1)
    assert_equal(client.get(_url(peer)).text(), "ok")
    client.sys.faults = Faults(SysCall.SEND, EPIPE, 0, 1)
    assert_equal(client.get(_url(peer)).text(), "ok")
    client.close_idle()
    client.sys.faults = Faults(SysCall.SEND, EPIPE, 0, 1)
    assert_equal(_error(client, _url(peer)), "closed: send failed: errno 32")
    assert_equal(client.get(_url(peer)).text(), "ok")
    client.close_idle()
    assert_equal(peer.finish(), 0)


def test_recv_faults() raises:
    var peer = _peer([Step(OK, CLOSE), Step(OK, CLOSE)])
    var client = Client()
    client.sys.faults = Faults(SysCall.RECV, EINTR, 0, 1)
    assert_equal(client.get(_url(peer)).text(), "ok")
    # The pool's peek at the closed idle connection is the first RECV
    # call; the fault hits the recv on the new connection.
    client.sys.faults = Faults(SysCall.RECV, ECONNRESET, 1, 1)
    assert_equal(_error(client, _url(peer)), "closed: recv failed: errno 104")
    _ = peer.finish()


def test_timeouts() raises:
    var quick = ClientConfig()
    quick.timeout_ms = 100
    var client = Client(quick)
    var a = _one("", HANG)
    assert_equal(_error(client, _url(a)), "timeout: the request timed out")
    _ = a.finish()
    var b = _peer([Step(OK, KEEP), Step("", HANG)])
    _ = client.get(_url(b))
    assert_equal(_error(client, _url(b)), "timeout: the request timed out")
    _ = b.finish()
    var c = _peer([Step(OK, KEEP), Step("", DEAF)])
    _ = client.get(_url(c))
    var body = String("x") * (32 * 1024 * 1024)
    var failed = String("no error")
    try:
        _ = client.post(_url(c), "text/plain", body)
    except e:
        failed = String(e)
    assert_equal(failed, "timeout: the request timed out")
    _ = c.finish()


def test_poll_faults() raises:
    # The pause before each reply makes the client wait in poll.
    var peer = _peer([Step("~" + OK, KEEP), Step("~" + OK, KEEP)])
    var client = Client()
    client.sys.faults = Faults(SysCall.POLL, EINTR, 0, 1)
    assert_equal(client.get(_url(peer)).text(), "ok")
    client.sys.faults = Faults(SysCall.POLL, EBADF, 0, -1)
    assert_equal(_error(client, _url(peer)), "os: poll failed: errno 9")
    client.sys.faults = Faults()
    client.close_idle()
    _ = peer.finish()


def test_connect_errors() raises:
    var sys = Sys()
    var fd = sys.socket()
    _ = sys.bind(fd, IPv4Address.LOOPBACK, 0)
    var port = sys.local_port(fd)
    sys.close(fd)
    var url = "http://127.0.0.1:" + String(port) + "/"
    var client = Client()
    assert_equal(
        _error(client, url),
        "connect: cannot connect to " + url + ": errno 111",
    )
    client.sys.faults = Faults(SysCall.SOCKET, 24, 0, 1)
    assert_equal(_error(client, url), "os: socket failed: errno 24")
    client.sys.faults = Faults(SysCall.CONNECT, 101, 0, 1)
    assert_equal(
        _error(client, url), "connect: cannot connect to " + url + ": errno 101"
    )
    var peer = _one(OK)
    var good = _url(peer)
    client.sys.faults = Faults(SysCall.GETSOCKOPT, 5, 0, 1)
    assert_equal(
        _error(client, good), "connect: cannot connect to " + good + ": errno 5"
    )
    client.sys.faults = Faults(SysCall.POLL, EBADF, 0, 1)
    assert_equal(_error(client, good), "os: poll failed: errno 9")
    client.sys.faults = Faults()
    assert_equal(client.get(good).text(), "ok")
    client.close_idle()
    _ = peer.finish()


def test_endpoints() raises:
    var client = Client()
    var failed = String("no error")
    try:
        _ = client.endpoint("https://example.com/")
    except e:
        failed = String(e)
    assert_equal(
        failed, "usage: only http URLs are supported: https://example.com/"
    )
    var first = client.endpoint("http://localhost:1/a?b")
    assert_true(first.address == IPv4Address.LOOPBACK)
    assert_equal(first.target, "/a?b")
    assert_equal(first.authority, "localhost:1")
    client.sys.faults = Faults(SysCall.RESOLVE, 2, 0, 1)
    var cached = client.endpoint("http://localhost:2/")
    assert_equal(cached.port, 2)
    failed = "no error"
    try:
        _ = client.endpoint("http://other.invalid/")
    except e:
        failed = String(e)
    assert_equal(
        failed, "resolve: cannot resolve other.invalid: getaddrinfo error 2"
    )


def _build(
    method: Method, target: StaticString, headers: Headers, body: StaticString
) raises -> String:
    var client = Client()
    var endpoint = Endpoint(IPv4Address.LOOPBACK, 80, "h", "/")
    try:
        client._build(endpoint, method, target, headers, body.as_bytes())
    except e:
        return String(e)
    return String(unsafe_from_utf8=client._out)


def test_build() raises:
    var none = Headers()
    assert_equal(
        _build(Method.GET, "/a", none, ""), "GET /a HTTP/1.1\r\nHost: h\r\n\r\n"
    )
    assert_equal(
        _build(Method.GET, "/a", none, "x"),
        "GET /a HTTP/1.1\r\nHost: h\r\nContent-Length: 1\r\n\r\nx",
    )
    assert_equal(
        _build(Method.PUT, "/", none, ""),
        "PUT / HTTP/1.1\r\nHost: h\r\nContent-Length: 0\r\n\r\n",
    )
    assert_true(
        _build(Method.PATCH, "/", none, "").endswith(
            "Content-Length: 0\r\n\r\n"
        )
    )
    assert_true(
        _build(Method.POST, "/", none, "").endswith("Content-Length: 0\r\n\r\n")
    )
    var host = Headers()
    host.add("Host", "other")
    assert_equal(
        _build(Method.DELETE, "/", host, ""),
        "DELETE / HTTP/1.1\r\nHost: other\r\n\r\n",
    )
    assert_equal(_build(Method.OTHER, "/", none, ""), "usage: invalid method")
    assert_equal(_build(Method(12), "/", none, ""), "usage: invalid method")
    assert_equal(
        _build(Method.GET, "/a b", none, ""), "usage: invalid request target"
    )
    assert_equal(
        _build(Method.GET, "/\x7f", none, ""), "usage: invalid request target"
    )
    assert_equal(
        _build(Method.GET, "/\x01", none, ""), "usage: invalid request target"
    )
    assert_equal(
        _build(Method.GET, "", none, ""), "usage: empty request target"
    )
    var length = Headers()
    length.add("Content-Length", "1")
    assert_equal(
        _build(Method.GET, "/", length, ""),
        "usage: the client writes the framing fields",
    )
    var coding = Headers()
    coding.add("Transfer-Encoding", "chunked")
    assert_equal(
        _build(Method.GET, "/", coding, ""),
        "usage: the client writes the framing fields",
    )


def test_text_not_utf8() raises:
    var response = Response()
    response.data = [255, 254]
    response._body_end = 2
    var failed = String("no error")
    try:
        _ = response.text()
    except e:
        failed = String(e)
    assert_equal(failed, "protocol: the content is not UTF-8")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
