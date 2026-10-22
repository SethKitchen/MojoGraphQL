# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http2.server`: the h2c event loop, with a client
`Connection` on a loopback socket in this process, and `connect_h2c`
against a server in a child process.

There is no upstream suite. The cases follow `tests/gql_http2/test_server.mojo`
and the server cases of `tests/gql_ws/test_server.mojo`.
"""

from _h2ws import Echo, Plain
from gql_http.socket import (
    EAGAIN,
    ECONNRESET,
    EINTR,
    POLLIN,
    POLLOUT,
    Faults,
    IPv4Address,
    SIGKILL,
    Sys,
    SysCall,
)
from gql_http.server import open_listener
from gql_http2.connection import Connection, Role
from gql_http2.hpack import HeaderList
from gql_ws.client import ClientConfig
from gql_ws.error import WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.protocol import Message, MessageKind, Role as WsRole, WebSocket
from gql_ws_http2.client import connect_h2c, connect_transport_h2c
from gql_ws_http2.handshake import client_head
from gql_ws_http2.server import Server, ServerConfig, listen
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from std.time import perf_counter_ns

comptime GTW = "graphql-transport-ws"


def _config() -> ServerConfig:
    """A loopback server on a free port, with `graphql-transport-ws`."""
    var config = ServerConfig()
    config.http.host = IPv4Address.LOOPBACK
    config.http.port = 0
    config.protocols = [GTW]
    return config^


def _server(
    config: ServerConfig = _config(), var sys: Sys = Sys()
) raises -> Server[Echo, Plain]:
    return listen(Echo(), Plain(), config, sys^)


struct Peer(Movable):
    """A client `Connection` on a loopback socket."""

    var sys: Sys
    var fd: Int
    var conn: Connection
    var ws: WebSocket
    var open: Bool

    def __init__(out self, port: Int) raises:
        self.sys = Sys()
        self.fd = self.sys.socket()
        _ = self.sys.connect(self.fd, IPv4Address.LOOPBACK, port)
        _ = self.sys.poll(self.fd, POLLOUT, 2000)
        self.conn = Connection(Role.CLIENT)
        self.conn.start()
        self.ws = WebSocket(WsRole.CLIENT)
        self.open = True

    def __deinit__(deinit self):
        if self.fd >= 0:
            self.sys.close(self.fd)

    def push(mut self):
        """Send the output of the connection, without a turn."""
        var sent = 0
        var tries = 0
        while sent < len(self.conn.out) and tries < 1000:
            var n = self.sys.send(
                self.fd,
                self.conn.out.unsafe_ptr().unsafe_offset(sent),
                len(self.conn.out) - sent,
            )
            if n > 0:
                sent += n
            elif n != -EAGAIN:
                break
            tries += 1
        self.conn.out.clear()

    def turn(mut self, mut server: Server[Echo, Plain]) raises:
        """Send the output, run the server, and read its answer."""
        self.push()
        var round = 0
        while round < 4:
            _ = server.poll(5)
            round += 1
        var buffer = List[UInt8](length=65536, fill=0)
        while True:
            _ = self.sys.poll(self.fd, POLLIN, 5)
            var n = self.sys.recv(self.fd, buffer.unsafe_ptr(), len(buffer))
            if n > 0:
                self.conn.receive(Span(buffer)[:n])
                continue
            if n == 0 or n == -ECONNRESET:
                self.open = False
            return

    def tunnel(mut self, mut server: Server[Echo, Plain]) raises -> Int:
        """Open a WebSocket on a new stream."""
        var id = self.conn.open_stream()
        self.conn.send_headers(
            id, client_head("http", "localhost", "/graphql", [GTW]), False
        )
        self.turn(server)
        return id

    def send(mut self, mut server: Server[Echo, Plain], id: Int) raises:
        """Send the output of the WebSocket on a stream."""
        var data = List[UInt8]()
        data.extend(Span(unsafe_ptr=self.ws.output(), length=self.ws.pending()))
        self.ws.advance(self.ws.pending())
        self.conn.send_data(id, Span(data), False)
        self.turn(server)

    def text(mut self, id: Int) raises -> String:
        """The next text message of a stream, or empty."""
        var slot = self.conn.find(id)
        if slot >= 0:
            self.ws.receive(Span(self.conn.streams[slot].body))
            self.conn.streams[slot].body.clear()
        var message = Message()
        if self.ws.read(message):
            return String(message.text())
        return String()


def test_echo() raises:
    var server = _server()
    var peer = Peer(server.port)
    peer.turn(server)
    assert_true(peer.conn.is_extended_connect_protocol_enabled())
    var id = peer.tunnel(server)
    assert_equal(peer.conn.streams[peer.conn.find(id)].status, 200)
    assert_equal(server.handler.opened, 1)
    peer.ws.send_text("hello")
    peer.send(server, id)
    assert_equal(peer.text(id), "hello")
    # A request on the same connection.
    var get = peer.conn.open_stream()
    var fields = HeaderList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "http")
    fields.add_text(":authority", "localhost")
    fields.add_text(":path", "/x")
    peer.conn.send_headers(get, fields, True)
    peer.turn(server)
    var slot = peer.conn.find(get)
    assert_equal(
        String(unsafe_from_utf8=Span(peer.conn.streams[slot].body)), "http /x"
    )
    assert_equal(server.open_connections, 1)


def test_idle_connections() raises:
    """A connection without a WebSocket that sends nothing closes after
    `idle_timeout_ms`; a connection with a WebSocket stays."""
    var config = _config()
    config.http.idle_timeout_ms = 50
    var server = _server(config)
    var busy = Peer(server.port)
    busy.turn(server)
    var id = busy.tunnel(server)
    var quiet = Peer(server.port)
    quiet.turn(server)
    assert_equal(server.open_connections, 2)
    var start = Int(perf_counter_ns() // 1_000_000)
    while Int(perf_counter_ns() // 1_000_000) - start < 200:
        # The wait of -1 is at most 50 ms while connections are open.
        _ = server.poll(-1)
    assert_equal(server.open_connections, 1)
    busy.ws.send_text("still here")
    busy.send(server, id)
    assert_equal(busy.text(id), "still here")
    _ = quiet.open


def test_tick() raises:
    # What the handler sends in `on_tick` goes out in the same turn.
    var server = _server()
    var unused = Peer(server.port)
    unused.turn(server)
    var peer = Peer(server.port)
    peer.turn(server)
    var id = peer.tunnel(server)
    server.handler.tick = "tick"
    peer.turn(server)
    assert_equal(peer.text(id), "tick")


def test_peer_closes() raises:
    var server = _server()
    var peer = Peer(server.port)
    peer.turn(server)
    _ = peer.tunnel(server)
    peer.sys.close(peer.fd)
    peer.fd = -1
    var round = 0
    while round < 4:
        _ = server.poll(5)
        round += 1
    assert_equal(server.handler.closed, 1)
    assert_equal(server.handler.code, 1006)
    assert_equal(server.open_connections, 0)
    # The slot of the session serves the next connection.
    var next = Peer(server.port)
    next.turn(server)
    _ = next.tunnel(server)
    assert_equal(server.handler.opened, 2)


def test_not_http2() raises:
    # A client that does not send the preface gets GOAWAY and the end.
    var server = _server()
    var peer = Peer(server.port)
    var request = "GET / HTTP/1.1\r\nHost: a\r\n\r\n"
    _ = peer.sys.send(peer.fd, request.unsafe_ptr(), request.byte_length())
    peer.conn.out.clear()
    peer.turn(server)
    assert_false(peer.open)
    assert_equal(server.open_connections, 0)


def test_max_connections() raises:
    var config = _config()
    config.http.max_connections = 0
    var server = _server(config)
    var peer = Peer(server.port)
    peer.turn(server)
    assert_false(peer.open)


def test_handler_source_and_wait() raises:
    var sys = Sys()
    var ends = sys.pipe()
    var echo = Echo()
    echo.extra_fd = ends[0]
    echo.wait = 5
    var server = listen(echo^, Plain(), _config())
    var byte: List[UInt8] = [1]
    _ = sys.write(ends[1], byte.unsafe_ptr(), 1)
    assert_equal(server.poll(-1), 1)
    assert_equal(server.poll(10), 1)
    server.handler.wait = 50
    assert_equal(server.poll(0), 1)
    sys.close(ends[1])
    server.close()
    sys.close(ends[0])


def test_setup_faults() raises:
    var a = Sys()
    a.faults = Faults(SysCall.EPOLL_CREATE, 24, 0, 1)
    var failed = 0
    try:
        _ = _server(_config(), a^)
    except:
        failed += 1
    var b = Sys()
    b.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    try:
        _ = _server(_config(), b^)
    except:
        failed += 1
    var sys = Sys()
    var ends = sys.pipe()
    var echo = Echo()
    echo.extra_fd = ends[0]
    var c = Sys()
    c.faults = Faults(SysCall.EPOLL_CTL, 24, 1, 1)
    try:
        _ = listen(echo^, Plain(), _config(), c^)
    except:
        failed += 1
    sys.close(ends[0])
    sys.close(ends[1])
    assert_equal(failed, 3)


def test_wait_faults() raises:
    var server = _server()
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, EINTR, 0, 1)
    assert_equal(server.poll(0), 0)
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, 9, 0, 1)
    var raised = False
    try:
        _ = server.poll(0)
    except:
        raised = True
    assert_true(raised)


def test_accept_fault() raises:
    # A connection that epoll cannot watch closes.
    var server = _server()
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    var peer = Peer(server.port)
    peer.turn(server)
    assert_false(peer.open)
    assert_equal(server.open_connections, 0)


def test_read_faults() raises:
    var server = _server()
    var peer = Peer(server.port)
    peer.turn(server)
    # EAGAIN and EINTR leave the bytes for the next turn.
    server.sys.faults = Faults(SysCall.RECV, EAGAIN, 0, 1)
    var id = peer.tunnel(server)
    assert_equal(server.handler.opened, 1)
    server.sys.faults = Faults(SysCall.RECV, EINTR, 0, 1)
    peer.ws.send_text("y")
    peer.send(server, id)
    assert_equal(peer.text(id), "y")
    server.sys.faults = Faults(SysCall.RECV, ECONNRESET, 0, 1)
    peer.ws.send_text("x")
    peer.send(server, id)
    assert_false(peer.open)
    assert_equal(server.open_connections, 0)


def test_send_faults() raises:
    # A send that the socket refuses waits for EPOLLOUT; a failed send
    # closes the connection.
    var server = _server()
    server.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    var peer = Peer(server.port)
    peer.turn(server)
    assert_true(peer.conn.got_settings())
    server.sys.faults = Faults(SysCall.SEND, EINTR, 0, 1)
    var id = peer.tunnel(server)
    assert_equal(peer.conn.streams[peer.conn.find(id)].status, 200)
    server.sys.faults = Faults(SysCall.SEND, ECONNRESET, 0, 1)
    peer.ws.send_text("x")
    peer.send(server, id)
    assert_false(peer.open)
    assert_equal(server.open_connections, 0)


def test_watch_fault() raises:
    # A connection whose events epoll cannot change closes.
    var server = _server()
    var peer = Peer(server.port)
    peer.turn(server)
    server.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    var id = peer.conn.open_stream()
    peer.conn.send_headers(
        id, client_head("http", "localhost", "/graphql", [GTW]), False
    )
    peer.push()
    # The answer waits for EPOLLOUT.
    _ = server.poll(100)
    assert_equal(server.open_connections, 1)
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    _ = server.poll(100)
    assert_equal(server.open_connections, 0)


def _spin(mut server: Server[Echo, Plain]):
    """Run a loop for at most five seconds."""
    try:
        var turn = 0
        while turn < 5000:
            _ = server.poll(1)
            turn += 1
    except:
        pass


def _serve_in_child() raises -> Tuple[Int, Int]:
    """Run a server in a child process for at most five seconds; return
    its pid and its port."""
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            var server = Server(Echo(), Plain(), _config(), listener, Sys())
            _spin(server)
        except:
            pass
        sys.exit_now(0)
    sys.close(listener.fd)
    return (pid, listener.port)


def _stop(pid: Int):
    var sys = Sys()
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)


def test_connect_h2c() raises:
    var child = _serve_in_child()
    var url = "ws://127.0.0.1:" + String(child[1]) + "/graphql"
    var socket = connect_h2c(url + "?a=1", [GTW])
    assert_equal(socket.protocol, GTW)
    socket.send_text("who")
    var message = Message()
    assert_true(socket.read(message, 2000))
    assert_equal(String(message.text()), GTW + " /graphql?a=1")
    socket.close(CloseCode.NORMAL, "bye")
    var closed = False
    var turns = 0
    while turns < 10:
        try:
            _ = socket.read(message, 2000)
        except e:
            closed = e.kind == WsErrorKind.CLOSED
            break
        turns += 1
    assert_true(closed)
    # graphql-transport-ws: the Echo handler acks `connection_init`.
    var client = connect_transport_h2c(url, "", 2000)
    assert_equal(client.socket.protocol, GTW)
    client.close()
    _stop(child[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
