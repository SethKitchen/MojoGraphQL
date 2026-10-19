# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An interop check of the gql_http2 server against curl and its nghttp2
HTTP/2 stack: h2c with prior knowledge, the h2c upgrade, and HTTP/1.1 on
the same port.

The check runs only when `curl --version` lists `HTTP2`. Without such a
curl, each test passes at once: the suite never installs anything and
never uses the network beyond the loopback address.
"""

from std.subprocess import run

from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import IPv4Address
from gql_http2.server import ServerConfig, start_workers
from std.testing import TestSuite, assert_true


@fieldwise_init
struct Echo(Handler):
    """Answers with the method, the target and the content."""

    var count: Int

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.add_header("Content-Type", "text/plain")
        response.write_text(request.method_text())
        response.write_text(" ")
        response.write_text(request.target())
        response.write_text(" ")
        response.write(request.body())


def _has_curl() -> Bool:
    try:
        return "HTTP2" in run("curl --version 2>/dev/null")
    except:
        return False


def _curl(flags: StringSlice) raises -> String:
    var config = ServerConfig()
    config.http.host = IPv4Address.LOOPBACK
    config.http.port = 0
    config.upgrade = True
    var pool = start_workers(Echo(0), config)
    var url = "http://127.0.0.1:" + String(pool.port) + "/graphql?x=1"
    var out = run(
        "curl -s -i --max-time 5 " + String(flags) + " " + url + " 2>&1"
    )
    _ = pool.stop(2000)
    return out


def test_prior_knowledge() raises:
    if not _has_curl():
        return
    var out = _curl("--http2-prior-knowledge -d hello")
    assert_true(out.startswith("HTTP/2 200"), out)
    assert_true(out.endswith("POST /graphql?x=1 hello"), out)


def test_upgrade() raises:
    if not _has_curl():
        return
    var out = _curl("--http2 -d up")
    assert_true(out.startswith("HTTP/1.1 101 Switching Protocols"), out)
    assert_true("HTTP/2 200" in out, out)
    assert_true(out.endswith("POST /graphql?x=1 up"), out)


def test_http1_on_the_same_port() raises:
    if not _has_curl():
        return
    var out = _curl("--http1.1")
    assert_true(out.startswith("HTTP/1.1 200 OK"), out)
    # run() drops the trailing space of the output.
    assert_true(out.endswith("GET /graphql?x=1"), out)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
