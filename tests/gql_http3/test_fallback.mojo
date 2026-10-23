# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.alt_svc` and `gql_http3.fallback`: an HTTPS server
that announces HTTP/3, the upgrade, and the fall back to TCP when UDP gets
no answer. There is no upstream suite; the cases follow RFC 7838."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, listen
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_http.headers import Headers
from gql_http.status import Method, Status
from gql_tls.error import TlsErrorKind
from gql_tls.context import TlsContext
from gql_tls.openssl import OpenSsl
from gql_tls.server import listen_https
from gql_http3.alt_svc import AltSvc, AltSvcCache, parse_alt_svc
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


def start_plain_https() raises -> Tuple[Int, Int]:
    var certs = test_certs()
    var protocols = List[String]()
    protocols.append("http/1.1")
    var context = TlsContext.server(
        OpenSsl(), certs.cert, certs.key, protocols^
    )
    var server = listen_https(Echo(), context^, tcp_config())
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


def start_https(h3_port: Int) raises -> Tuple[Int, Int]:
    var certs = test_certs()
    var protocols = List[String]()
    protocols.append("http/1.1")
    var context = TlsContext.server(
        OpenSsl(), certs.cert, certs.key, protocols^
    )
    var server = listen_https(AltSvc(Echo(), h3_port), context^, tcp_config())
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


def test_parse_alt_svc() raises:
    var found = parse_alt_svc('h2=":443", h3=":4433"; ma=60; persist=1')
    assert_true(Bool(found))
    assert_equal(found.value().port, 4433)
    assert_equal(found.value().max_age, 60)
    assert_equal(found.value().host, "")
    var other = parse_alt_svc('h3="example.com:8443"')
    assert_equal(other.value().host, "example.com")
    assert_equal(other.value().max_age, 86400)
    assert_false(Bool(parse_alt_svc('h2=":443"')))
    assert_false(Bool(parse_alt_svc('h3=":0"')))
    assert_false(Bool(parse_alt_svc('h3="nocolon"')))
    assert_equal(parse_alt_svc(" clear ").value().port, 0)


def test_cache() raises:
    var cache = AltSvcCache()
    cache.remember("a:1", 'h3=":5"; ma=10', 100)
    assert_equal(len(cache), 1)
    assert_equal(cache.lookup("a:1", 105).value().port, 5)
    assert_false(Bool(cache.lookup("b:1", 105)))
    assert_false(Bool(cache.lookup("a:1", 111)))
    assert_equal(len(cache), 0)
    cache.remember("a:1", 'h3=":5"', 100)
    cache.remember("a:1", "clear", 101)
    assert_equal(len(cache), 0)
    cache.remember("a:1", "garbage", 101)
    assert_equal(len(cache), 0)


def test_upgrade_with_alt_svc() raises:
    var h3 = start_h3()
    var https = start_https(h3[1])
    var url = "https://localhost:" + String(https[1]) + "/x"
    var client = FallbackClient(fallback_config())
    var first = client.get(url)
    assert_equal(client.protocol, Protocol.HTTPS1)
    assert_equal(first.text(), "/x")
    assert_true(String(first.header("alt-svc").value()).startswith('h3=":'))
    var second = client.get(url)
    assert_equal(client.protocol, Protocol.HTTP3)
    assert_equal(second.text(), "/x")
    kill(https[0])
    kill(h3[0])


def test_fall_back_when_udp_is_silent() raises:
    # The TCP port has no UDP listener: the QUIC handshake gets no answer.
    var https = start_https(1)
    var config = fallback_config()
    config.enable_h3 = True
    config.h3_timeout_ms = 200
    var client = FallbackClient(config)
    var url = "https://localhost:" + String(https[1]) + "/y"
    var response = client.get(url)
    assert_equal(client.protocol, Protocol.HTTPS1)
    assert_equal(response.text(), "/y")
    # HTTP/3 rests for this origin now: no second wait.
    _ = client.get(url)
    assert_equal(client.protocol, Protocol.HTTPS1)
    kill(https[0])


def test_plain_http() raises:
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
    var client = FallbackClient(fallback_config())
    var response = client.post(
        "http://127.0.0.1:" + String(port) + "/p", "text/plain", "x"
    )
    assert_equal(client.protocol, Protocol.HTTP1)
    assert_equal(response.text(), "/p")
    kill(pid)


def kind(
    mut client: FallbackClient, url: String, method: Method = Method.GET
) -> TlsErrorKind:
    try:
        _ = client.send(method, url, Headers(), List[UInt8]())
    except e:
        return e.kind
    return TlsErrorKind.OS


def test_errors_and_kinds() raises:
    assert_true(Protocol.HTTP3.is_valid())
    assert_false(Protocol(6).is_valid())
    assert_equal(String(Protocol.HTTPS1), "https/1.1")
    var client = FallbackClient(fallback_config())
    assert_equal(kind(client, "nonsense"), TlsErrorKind.PROTOCOL)
    assert_equal(kind(client, "ftp://x/"), TlsErrorKind.USAGE)
    assert_equal(kind(client, "http://127.0.0.1:1/"), TlsErrorKind.CONNECT)
    var raised = False
    try:
        _ = client.post("http://127.0.0.1:1/", "bad\ntype", "x")
    except e:
        raised = e.kind == TlsErrorKind.USAGE
    assert_true(raised)


def test_retry_after_rest() raises:
    var https = start_https(1)
    var config = fallback_config()
    config.enable_h3 = True
    config.h3_retry_after_s = 0
    var client = FallbackClient(config)
    var url = "https://localhost:" + String(https[1]) + "/z"
    var other = "https://127.0.0.1:" + String(https[1]) + "/z"
    _ = client.get(other)
    _ = client.get(url)
    _ = client.get(url)
    assert_equal(client.protocol, Protocol.HTTPS1)
    assert_equal(kind(client, url, Method.OTHER), TlsErrorKind.USAGE)
    kill(https[0])


def test_https_without_alt_svc() raises:
    var https = start_plain_https()
    var client = FallbackClient(fallback_config())
    var response = client.get("https://localhost:" + String(https[1]) + "/q")
    assert_equal(response.text(), "/q")
    assert_equal(len(client.alt_svc), 0)
    kill(https[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
