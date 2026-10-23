# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the HTTP/2 steps of `gql_http3.fallback`: the order
h3, h2 over TLS, HTTPS/1.1, h2c and HTTP/1.1. There is no upstream suite;
the cases follow RFC 7838, RFC 9113 section 3 and RFC 7301."""

from std.testing import TestSuite, assert_equal, assert_true

from _certs import test_certs
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, listen
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_http.status import Status
from gql_http2.server import ServerConfig as H2ServerConfig
from gql_http2.server import listen as listen_h2c
from gql_tls.context import TlsContext
from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_https2.server import listen_https2
from gql_http3.alt_svc import AltSvc
from gql_http3.fallback import FallbackClient, FallbackConfig, Protocol
from gql_http3.quic import Quic
from gql_http3.server import H3Config, listen_h3


struct Echo(Handler):
    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.send(Status.OK, "text/plain", String(request.path()))


def tcp_config() -> ServerConfig:
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.reuse_port = False
    return config^


def kill(pid: Int):
    var sys = Sys()
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)


def start_h3() raises -> Tuple[Int, Int]:
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
    return (pid, port)


def start_https2(h3_port: Int) raises -> Tuple[Int, Int]:
    """An h2 and HTTPS/1.1 server; it announces HTTP/3 when `h3_port` > 0."""
    var certs = test_certs()
    var context = TlsContext.server(OpenSsl(), certs.cert, certs.key)
    var sys = Sys()
    var port: Int
    var pid: Int
    if h3_port > 0:
        var server = listen_https2(
            AltSvc(Echo(), h3_port), context^, tcp_config()
        )
        pid = sys.fork()
        if pid == 0:
            _ = sys.die_with_parent()
            try:
                server.run()
            except:
                pass
            sys.exit_now(0)
        port = server.port
        server.close()
    else:
        var server = listen_https2(Echo(), context^, tcp_config())
        pid = sys.fork()
        if pid == 0:
            _ = sys.die_with_parent()
            try:
                server.run()
            except:
                pass
            sys.exit_now(0)
        port = server.port
        server.close()
    return (pid, port)


def start_h2c() raises -> Tuple[Int, Int]:
    var config = H2ServerConfig()
    config.http = tcp_config()
    var server = listen_h2c(Echo(), config)
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
    return (pid, port)


def start_http1() raises -> Tuple[Int, Int]:
    var server = listen(Echo(), tcp_config())
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
    return (pid, port)


def fallback_config() raises -> FallbackConfig:
    var config = FallbackConfig()
    config.ca_file = test_certs().cert
    config.client.timeout_ms = 20000
    return config^


def test_protocol_names() raises:
    assert_true(Protocol.H2C.is_valid())
    assert_equal(String(Protocol.HTTPS2), "h2")
    assert_equal(String(Protocol.H2C), "h2c")
    assert_equal(String(Protocol(9)), "h2c")


def test_h2_over_tls_then_h3() raises:
    # The first request has no Alt-Svc yet: h2 over TLS. Then HTTP/3.
    var h3 = start_h3()
    var https = start_https2(h3[1])
    var url = "https://localhost:" + String(https[1]) + "/a"
    var client = FallbackClient(fallback_config())
    var first = client.get(url)
    assert_equal(client.protocol, Protocol.HTTPS2)
    assert_equal(first.text(), "/a")
    assert_true(String(first.header("alt-svc").value()).startswith('h3=":'))
    _ = client.get(url)
    assert_equal(client.protocol, Protocol.HTTP3)
    kill(https[0])
    kill(h3[0])


def test_h3_fails_then_h2_then_https1() raises:
    # No UDP listener: HTTP/3 times out, and h2 over TLS answers.
    var https = start_https2(0)
    var config = fallback_config()
    config.enable_h3 = True
    config.h3_timeout_ms = 200
    var client = FallbackClient(config)
    var url = "https://localhost:" + String(https[1]) + "/b"
    assert_equal(client.get(url).text(), "/b")
    assert_equal(client.protocol, Protocol.HTTPS2)
    # Without h2 in the handshake, the same server speaks HTTPS/1.1.
    var old = fallback_config()
    old.enable_h2 = False
    var plain = FallbackClient(old)
    assert_equal(plain.get(url).text(), "/b")
    assert_equal(plain.protocol, Protocol.HTTPS1)
    kill(https[0])


def test_h2c_then_http1() raises:
    var h2c = start_h2c()
    var http1 = start_http1()
    var config = fallback_config()
    config.enable_h2c = True
    var client = FallbackClient(config)
    var response = client.post(
        "http://127.0.0.1:" + String(h2c[1]) + "/c", "text/plain", "x"
    )
    assert_equal(client.protocol, Protocol.H2C)
    assert_equal(response.text(), "/c")
    # A server without HTTP/2 does not answer the preface: HTTP/1.1.
    var old = client.get("http://127.0.0.1:" + String(http1[1]) + "/d")
    assert_equal(client.protocol, Protocol.HTTP1)
    assert_equal(old.text(), "/d")
    var kind = TlsErrorKind.OS
    try:
        _ = client.get("http://127.0.0.1:1/")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.CONNECT)
    kill(http1[0])
    kill(h2c[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
