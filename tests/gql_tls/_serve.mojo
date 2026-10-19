# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_tls server suites: test handlers, a test protocol,
and clients that drive an in-process `TlsServer` turn by turn."""

from std.ffi import external_call
from std.memory import stack_allocation

from _tls import client_context, server_context
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig
from gql_http.socket import IPv4Address, Sys
from gql_http.status import Status
from gql_tls.server import TlsProtocol, TlsServer, listen_https
from gql_tls.stream import IoWant, TlsStream

comptime BIG = 8 * 1024 * 1024
"""The size of a response that a socket cannot take at once."""


struct Echo(Handler):
    """Answer with the path and the content.

    `/fail` raises, `/close` closes the connection, `/big` sends `BIG`
    bytes, and `/bigclose` sends `BIG` bytes and closes.
    """

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var path = String(request.path())
        if path == "/fail":
            raise Error("handler failed")
        if path == "/close" or path == "/bigclose":
            response.close_connection()
        if path.startswith("/big"):
            response.send(Status.OK, "text/plain", String("x") * BIG)
            return
        response.send(
            Status.OK,
            "text/plain",
            path + ":" + String(unsafe_from_utf8=request.body()),
        )


struct Upper(TlsProtocol):
    """A test protocol `upper/1`: answer each read in upper case.

    `!` raises, `q` first ends the connection, and `*` first answers `BIG`
    bytes. `fail_open` makes `open` raise; `preface` is the size of the
    greeting.
    """

    var opened: Int
    var fail_open: Bool
    var preface: Int

    def __init__(out self, fail_open: Bool = False, preface: Int = 0):
        self.opened = 0
        self.fail_open = fail_open
        self.preface = preface

    def protocol(self) -> String:
        return "upper/1"

    def open(mut self, conn: Int, mut out: List[UInt8]) raises:
        if self.fail_open:
            raise Error("no open")
        self.opened += 1
        if self.preface > 0:
            out.resize(self.preface, 72)
            return
        out.extend("HELLO\n".as_bytes())

    def receive(
        mut self, conn: Int, data: List[UInt8], mut out: List[UInt8]
    ) raises -> Bool:
        if data[0] == 42:
            out.resize(len(out) + BIG, 42)
            return True
        var index = 0
        while index < len(data):
            var byte = data[index]
            if byte == 33:
                raise Error("bang")
            if byte >= 97 and byte <= 122:
                byte -= 32
            out.append(byte)
            index += 1
        return data[0] != 113

    def close(mut self, conn: Int):
        self.opened -= 1


def config() -> ServerConfig:
    """A loopback configuration on a free port."""
    var c = ServerConfig()
    c.host = IPv4Address.LOOPBACK
    c.port = 0
    c.reuse_port = False
    return c^


def dial(mut sys: Sys, port: Int, small: Bool = False) raises -> Int:
    """Start a connection; `small` gives it a small receive buffer, so that
    a large answer fills the socket of the server."""
    var fd = sys.socket()
    if small:
        var value = stack_allocation[1, Int32]()
        value[unsafe_offset=0] = 8192
        # SOL_SOCKET, SO_RCVBUF
        _ = external_call["setsockopt", Int32](
            Int32(fd), Int32(1), Int32(8), value.unsafe_bitcast[NoneType](), 4
        )
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc < 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    return fd


def open_client[
    H: Handler, P: TlsProtocol
](
    mut sys: Sys,
    mut server: TlsServer[H, P],
    var protocols: List[String] = ["http/1.1"],
    small: Bool = False,
) raises -> TlsStream:
    """Connect to the server, and drive both ends to the end of the
    handshake."""
    var fd = dial(sys, server.port, small)
    var context = client_context(protocols^)
    var stream = TlsStream.connect(context, fd, "localhost")
    var turns = 0
    while stream.handshake() != IoWant.NOTHING:
        _ = server.poll(5)
        turns += 1
        if turns > 2000:
            raise Error("no handshake")
    return stream^


def send_text(mut stream: TlsStream, text: String) raises:
    """Write all of a text."""
    var data = List[UInt8](text.as_bytes())
    var sent = 0
    while sent < len(data):
        var n = stream.write(
            data.unsafe_ptr().unsafe_offset(sent), len(data) - sent
        )
        if n > 0:
            sent += n


def read_text[
    H: Handler, P: TlsProtocol
](
    mut server: TlsServer[H, P], mut stream: TlsStream, until: String
) raises -> String:
    """Drive the server and read the client until `until` arrives or the
    stream ends."""
    var got = String()
    var buffer = List[UInt8](length=65536, fill=0)
    var turns = 0
    while got.find(until) < 0 and turns < 4000:
        _ = server.poll(1)
        var n = stream.read(buffer.unsafe_ptr(), len(buffer))
        if n == 0:
            return got^
        if n > 0:
            got += String(unsafe_from_utf8=Span(buffer)[0:n])
        turns += 1
    return got^


def read_count[
    H: Handler, P: TlsProtocol
](mut server: TlsServer[H, P], mut stream: TlsStream, count: Int) raises -> Int:
    """Drive the server and read until `count` bytes or the end arrive.

    Returns:
        The count of bytes read.
    """
    var got = 0
    var buffer = List[UInt8](length=262144, fill=0)
    var turns = 0
    while got < count and turns < 20000:
        _ = server.poll(0)
        var n = stream.read(buffer.unsafe_ptr(), len(buffer))
        if n == 0:
            return got
        if n > 0:
            got += n
        turns += 1
    return got


def turns[
    H: Handler, P: TlsProtocol
](mut server: TlsServer[H, P], count: Int) raises:
    """Run some turns of the server loop."""
    var index = 0
    while index < count:
        _ = server.poll(2)
        index += 1


def conn_fd[H: Handler, P: TlsProtocol](server: TlsServer[H, P]) -> Int:
    """Return the socket of the first open connection, or -1."""
    var fd = 0
    while fd < len(server._conns):
        if server._conns[fd].fd >= 0:
            return fd
        fd += 1
    return -1


@fieldwise_init
struct Child(Movable):
    """An HTTPS server in a child process."""

    var pid: Int
    var port: Int

    def stop(self):
        """Kill the child, and wait for it."""
        var sys = Sys()
        _ = sys.kill(self.pid, 9)
        _ = sys.wait(self.pid, True)


def start_server() raises -> Child:
    """Run an HTTPS server that answers with `Echo`, in a child process."""
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
