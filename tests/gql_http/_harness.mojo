# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_http suites: handlers, raw loopback clients, and a
server that runs in the same process for a bounded number of turns."""

from gql_http.error import HttpError
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, Server, ServerConfig
from gql_http.socket import EAGAIN, IPv4Address, POLLIN, SIGTERM, Sys
from gql_http.status import Status

comptime BIG = 8 * 1024 * 1024
"""The size of the content of `/big`: more than a socket buffer takes."""


@fieldwise_init
struct Echo(Handler):
    """Answers with the method, the target and the content."""

    var count: Int

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        self.count += 1
        if request.path() == "/fail":
            raise Error("handler failed")
        if request.path() == "/stream":
            response.add_header("Content-Type", "text/plain")
            response.write_text("a")
            response.begin_chunked()
            response.write_chunk(StaticString("bc").as_bytes())
            response.flush()
            response.write_chunk(StaticString("def").as_bytes())
            return
        if request.path() == "/big":
            response.write(List[UInt8](length=BIG, fill=120))
            return
        if request.path() == "/kill":
            var sys = Sys()
            _ = sys.kill(sys.pid(), SIGTERM)
        if request.path() == "/close":
            response.close_connection()
        if request.path() == "/empty":
            response.set_status(Status.NO_CONTENT)
            return
        response.add_header("Content-Type", "text/plain")
        response.write_text(request.method_text())
        response.write_text(" ")
        response.write_text(request.target())
        response.write_text(" ")
        response.write(request.body())


def config() -> ServerConfig:
    """Return a configuration on a free loopback port."""
    var c = ServerConfig()
    c.host = IPv4Address.LOOPBACK
    c.port = 0
    return c^


def connect(mut sys: Sys, port: Int) raises -> Int:
    """Connect a non-blocking socket to the loopback port."""
    var fd = sys.socket()
    if fd < 0:
        raise Error("socket failed")
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc < 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    return fd


def send_text(mut sys: Sys, fd: Int, text: StringSlice) raises:
    """Send all of a text."""
    var bytes = text.as_bytes()
    var sent = 0
    while sent < len(bytes):
        var n = sys.send(
            fd, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
        )
        if n == -EAGAIN:
            _ = sys.poll(fd, 4, 100)
            continue
        if n < 0:
            raise Error("send failed: " + String(n))
        sent += n


def drive[H: Handler](mut server: Server[H], turns: Int) raises:
    """Run a number of turns of the loop, each with a short wait."""
    for _ in range(turns):
        _ = server.poll(5)


def receive[
    H: Handler
](
    mut server: Server[H], mut sys: Sys, fd: Int, turns: Int = 20
) raises -> String:
    """Run the server and read what the client socket gets until it is
    quiet, or closed."""
    var out = List[UInt8]()
    var buffer = List[UInt8](length=65536, fill=0)
    var quiet = 0
    while quiet < turns:
        _ = server.poll(2)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n > 0:
            out.extend(Span(buffer)[:n])
            quiet = 0
        elif n == 0:
            break
        else:
            quiet += 1
    return String(unsafe_from_utf8=out)


@fieldwise_init
struct Pair(Movable):
    """A listener, and a client end and a server end connected to it."""

    var listener: Int
    var client: Int
    var server: Int

    def close(self, mut sys: Sys):
        """Close all three descriptors."""
        sys.close(self.client)
        sys.close(self.server)
        sys.close(self.listener)


def loopback_pair(mut sys: Sys) raises -> Pair:
    """Connect a non-blocking client to a fresh loopback listener."""
    var listener = sys.socket()
    if sys.bind(listener, IPv4Address.LOOPBACK, 0) < 0:
        raise Error("bind failed")
    _ = sys.listen(listener, 16)
    var client = connect(sys, sys.local_port(listener))
    _ = sys.poll(listener, POLLIN, 2000)
    var server = sys.accept(listener)
    if server < 0:
        raise Error("accept failed: " + String(server))
    _ = sys.poll(client, 4, 2000)
    return Pair(listener, client, server)


def drain(mut sys: Sys, fd: Int) -> Int:
    """Read and drop what a socket holds now; return the count."""
    var buffer = List[UInt8](length=65536, fill=0)
    var total = 0
    while True:
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n <= 0:
            return total
        total += n
