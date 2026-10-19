# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP/3 round trips over localhost UDP: `H3Server` in a child process,
`H3Client` in the test. The cases follow RFC 9114 section 4; the request
shapes are those of hyperium/h3 h3-v0.0.8 h3/src/tests/request.rs."""

from std.subprocess import run
from std.testing import TestSuite, assert_equal, assert_true

from _certs import test_certs
from gql_http.client import ClientConfig
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_http.status import Status
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_http3.client import H3Client
from gql_http3.quic import Quic, QuicContext
from gql_http3.server import H3Config, H3Server, listen_h3


struct Echo(Handler):
    """Answer with the method, the path and the content."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var path = String(request.path())
        if path == "/fail":
            raise Error("handler failed")
        if path == "/stream":
            response.set_status(Status.OK)
            response.begin_chunked()
            response.write_chunk("a".as_bytes())
            response.write_chunk("b".as_bytes())
            return
        response.add_header("X-Method", request.method.text())
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
    """Run an HTTP/3 server with the test certificate in a child process."""
    var certs = test_certs()
    var config = H3Config()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    var server = listen_h3(
        Echo(), certs.cert, certs.key, config, Quic(OpenSsl())
    )
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


def client() raises -> H3Client:
    var certs = test_certs()
    var config = ClientConfig()
    config.timeout_ms = 20000
    var context = QuicContext.client(Quic(OpenSsl()), certs.cert)
    return H3Client(context^, config)


def test_round_trip() raises:
    var child = start_server()
    var base = "https://localhost:" + String(child.port)
    var c = client()
    var r = c.get(base + "/a")
    assert_equal(Int(r.status.code), 200)
    assert_equal(r.text(), "/a:")
    assert_equal(String(r.header("x-method").value()), "GET")
    r = c.post(base + "/b", "application/json", '{"query":"{a}"}')
    assert_equal(r.text(), '/b:{"query":"{a}"}')
    assert_equal(c.connections(), 1)
    r = c.get(base + "/stream")
    assert_equal(r.text(), "ab")
    r = c.get(base + "/fail")
    assert_equal(Int(r.status.code), 500)
    c.close()
    child.stop()


def test_curl_interop() raises:
    """Run curl over HTTP/3 when it has HTTP/3 support; skip otherwise."""
    var features = run("curl --version 2> /dev/null || true")
    if features.find("HTTP3") < 0:
        print("skip: curl has no HTTP/3 support")
        return
    var child = start_server()
    var out = run(
        "curl --http3-only -sk --max-time 5 https://localhost:"
        + String(child.port)
        + "/curl 2>&1 || true"
    )
    child.stop()
    assert_equal(out, "/curl:")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
