# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_https2 suites: a handler, servers in child processes,
a scripted `h2` protocol that misbehaves on one stream, and clients that
trust the test certificate."""

from _certs import test_certs
from _tls import server_context
from gql_http.client import ClientConfig
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig
from gql_http.socket import IPv4Address, Sys
from gql_http.status import Status
from gql_http2.error import Reason
from gql_http2.frame import write_goaway
from gql_tls.openssl import OpenSsl
from gql_tls.server import TlsProtocol, listen_https, listen_tls
from gql_https2.client import Https2Client
from gql_https2.server import H2Protocol, listen_https2


struct Echo(Handler):
    """Answer with the path and the content; `/bye` closes the connection
    and `/fail` raises."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var path = String(request.path())
        if path == "/fail":
            raise Error("handler failed")
        if path == "/bye":
            response.close_connection()
        response.send(
            Status.OK,
            "text/plain",
            path + ":" + String(unsafe_from_utf8=request.body()),
        )


def config() -> ServerConfig:
    """A loopback server on a free port."""
    var c = ServerConfig()
    c.host = IPv4Address.LOOPBACK
    c.port = 0
    c.reuse_port = False
    return c^


def first_headers(data: List[UInt8]) -> Int:
    """Return the stream of the first `HEADERS` frame in some bytes, or -1.
    The bytes start at a frame, or at the client preface."""
    var at = 0
    if len(data) >= 24 and data[0] == 80:
        at = 24
    while at + 9 <= len(data):
        var length = (
            Int(data[at]) << 16 | Int(data[at + 1]) << 8 | Int(data[at + 2])
        )
        if data[at + 3] == 1:
            return (
                Int(data[at + 5] & 0x7F) << 24
                | Int(data[at + 6]) << 16
                | Int(data[at + 7]) << 8
                | Int(data[at + 8])
            )
        at += 9 + length
    return -1


struct Script(TlsProtocol):
    """`h2` that refuses, ignores or closes on one stream of a connection,
    and serves the others with `H2Protocol`."""

    var inner: H2Protocol[Echo]
    var goaway_at: Int
    var silent_at: Int
    var close_at: Int

    def __init__(
        out self, goaway_at: Int = -1, silent_at: Int = -1, close_at: Int = -1
    ):
        self.inner = H2Protocol(Echo())
        self.goaway_at = goaway_at
        self.silent_at = silent_at
        self.close_at = close_at

    def protocol(self) -> String:
        return "h2"

    def open(mut self, conn: Int, mut out: List[UInt8]):
        self.inner.open(conn, out)

    def receive(
        mut self, conn: Int, data: List[UInt8], mut out: List[UInt8]
    ) -> Bool:
        var stream = first_headers(data)
        if stream < 0:
            return self.inner.receive(conn, data, out)
        if stream == self.goaway_at:
            write_goaway(out, 1, Reason.NO_ERROR, List[UInt8]())
            return True
        if stream == self.silent_at:
            return True
        if stream == self.close_at:
            return False
        return self.inner.receive(conn, data, out)

    def close(mut self, conn: Int):
        self.inner.close(conn)


@fieldwise_init
struct Child(Movable):
    """A server in a child process."""

    var pid: Int
    var port: Int

    def stop(self):
        """Kill the child, and wait for it."""
        var sys = Sys()
        _ = sys.kill(self.pid, 9)
        _ = sys.wait(self.pid, True)

    def url(self, path: String, host: String = "localhost") -> String:
        """Return an `https` URL of the server."""
        return "https://" + host + ":" + String(self.port) + path


def start_h2(var protocols: List[String] = ["h2", "http/1.1"]) raises -> Child:
    """Run `listen_https2` with `Echo` in a child process."""
    var server = listen_https2(Echo(), server_context(protocols^), config())
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


def start_http1() raises -> Child:
    """Run an HTTPS/1.1 server that offers only `http/1.1`, in a child."""
    var server = listen_https(Echo(), server_context(["http/1.1"]), config())
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


def start_script(var script: Script) raises -> Child:
    """Run a `TlsServer` with a `Script` protocol in a child process."""
    var server = listen_tls(Echo(), server_context(), config(), script^)
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


def client(
    timeout_ms: Int = 3000, offer_h2: Bool = True
) raises -> Https2Client:
    """A client that trusts the test certificate."""
    var c = ClientConfig()
    c.timeout_ms = timeout_ms
    return Https2Client.create(OpenSsl(), test_certs().cert, True, offer_h2, c)
