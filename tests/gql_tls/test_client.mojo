# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_tls.client`: requests to an HTTPS server in a child
process, the pool, verification and errors. There is no upstream suite;
the cases follow RFC 9112 and RFC 9110 section 4.3.3."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _tls import client_context, server_context
from gql_http.client import ClientConfig
from gql_http.headers import Headers
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_http.status import Method, Status
from gql_tls.client import HttpsClient
from gql_tls.context import TlsContext
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_tls.server import listen_https


struct Echo(Handler):
    """Answer with the method, the path and the content."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var path = String(request.path())
        if path == "/close":
            response.close_connection()
        response.send(
            Status.OK,
            "text/plain",
            path + ":" + String(unsafe_from_utf8=request.body()),
        )


@fieldwise_init
struct Child(Movable):
    var pid: Int
    var port: Int

    def stop(self):
        var sys = Sys()
        _ = sys.kill(self.pid, SIGKILL)
        _ = sys.wait(self.pid, True)


def start_server() raises -> Child:
    """Run an HTTPS server with the test certificate in a child process."""
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.reuse_port = False
    var server = listen_https(Echo(), server_context(["http/1.1"]), config)
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            server.run()
        except:
            pass
        sys.exit_now(0)
    var port = server.port
    server.close()
    return Child(pid, port)


def client(timeout_ms: Int = 3000) raises -> HttpsClient:
    var config = ClientConfig()
    config.timeout_ms = timeout_ms
    return HttpsClient(client_context(["http/1.1"]), config)


def test_get_post_and_pool() raises:
    var child = start_server()
    var base = "https://localhost:" + String(child.port)
    var c = client()
    var r = c.get(base + "/a")
    assert_equal(Int(r.status.code), 200)
    assert_equal(r.text(), "/a:")
    assert_equal(c.idle_connections(), 1)
    r = c.post(base + "/b", "text/plain", "hi")
    assert_equal(r.text(), "/b:hi")
    assert_equal(c.idle_connections(), 1)
    _ = c.get(base + "/close")
    assert_equal(c.idle_connections(), 0)
    _ = c.get(base + "/c")
    assert_equal(c.idle_connections(), 1)
    c.close_idle()
    assert_equal(c.idle_connections(), 0)
    child.stop()


def test_verify_failure() raises:
    var child = start_server()
    var c = HttpsClient(TlsContext.client(OpenSsl(), ["http/1.1"]))
    var kind = TlsErrorKind.USAGE
    try:
        _ = c.get("https://localhost:" + String(child.port) + "/")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.VERIFY)
    child.stop()


def test_url_errors() raises:
    var c = client()
    var kind = TlsErrorKind.OS
    try:
        _ = c.get("http://localhost/")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.USAGE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
