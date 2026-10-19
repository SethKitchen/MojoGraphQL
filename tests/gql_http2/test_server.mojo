# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http2.server`: the event loop that chooses HTTP/2 or
HTTP/1.1 for each connection, in this process, with raw loopback clients.
Faults in `Server.sys` reach the error paths.

The upstream h2 v0.4.20 has no listener; these follow `src/server.rs`
`handshake` and the gql_http server suite.
"""

from _frames import Frame, Peer, kinds, request
from _net import send_all
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import (
    EAGAIN,
    ECONNRESET,
    EINTR,
    EPIPE,
    Faults,
    IPv4Address,
    POLLOUT,
    Sys,
    SysCall,
)
from gql_http2.connection import Connection, Role
from gql_http2.error import Reason
from gql_http2.frame import END_HEADERS, END_STREAM, PREFACE
from gql_http2.server import Server, ServerConfig, listen
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime EOS = END_HEADERS | END_STREAM
"""The flags of a whole head that ends its stream."""
comptime UPGRADE = (
    "GET /up HTTP/1.1\r\nHost: x\r\nConnection: Upgrade, HTTP2-Settings\r\n"
    "Upgrade: h2c\r\nHTTP2-Settings: AAMAAABk\r\n\r\n"
)
"""An h2c upgrade request."""


@fieldwise_init
struct Echo(Handler):
    """Answers with the method and the target; `/big` is 8 MiB."""

    var count: Int

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        self.count += 1
        if request.path() == "/big":
            response.write(List[UInt8](length=1 << 23, fill=0x62))
            return
        response.write_text(request.method_text())
        response.write_text(" ")
        response.write_text(request.target())


def config() -> ServerConfig:
    var c = ServerConfig()
    c.http.host = IPv4Address.LOOPBACK
    c.http.port = 0
    return c^


def connect(mut sys: Sys, port: Int) raises -> Int:
    var fd = sys.socket()
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc < 0 and rc != -115:
        raise Error("connect failed")
    _ = sys.poll(fd, POLLOUT, 2000)
    return fd


def exchange[
    H: Handler
](
    mut server: Server[H],
    mut sys: Sys,
    fd: Int,
    data: List[UInt8],
    turns: Int = 20,
) raises -> List[UInt8]:
    """Send bytes, run the loop, and read what the client gets until it is
    quiet for some turns, or closed."""
    send_all(sys, fd, data)
    var out = List[UInt8]()
    var buffer = List[UInt8](length=65536, fill=0)
    var quiet = 0
    while quiet < turns:
        _ = server.poll(2)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n > 0:
            out.extend(Span(buffer)[:n])
            quiet = 0
        elif n == 0 or n == -ECONNRESET:
            break
        else:
            quiet += 1
    return out^


def closed[
    H: Handler
](mut server: Server[H], mut sys: Sys, fd: Int) raises -> Bool:
    """Run the loop until the client sees the connection close."""
    var buffer = List[UInt8](length=65536, fill=0)
    var turn = 0
    while turn < 400:
        _ = server.poll(5)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n == 0 or n == -ECONNRESET:
            return True
        turn += 1
    return False


def h2_request(path: StringSlice = "/x") -> List[UInt8]:
    """The preface, the settings and one GET."""
    var peer = Peer()
    peer.preface()
    peer.settings()
    peer.headers(1, request("GET", path), EOS)
    return peer.out.copy()


def frames_of(data: List[UInt8]) raises -> List[Frame]:
    var holder = Connection(Role.CLIENT)
    holder.out = data.copy()
    var peer = Peer()
    return peer.read(holder)


def frames_with(mut reader: Peer, data: List[UInt8]) raises -> List[Frame]:
    """Decode frames with the HPACK state of one connection."""
    var holder = Connection(Role.CLIENT)
    holder.out = data.copy()
    return reader.read(holder)


def body(frames: List[Frame]) -> String:
    var out = String()
    for ref frame in frames:
        if String(frame.head.kind) == "DATA":
            out += frame.text()
    return out^


def text(data: List[UInt8]) -> String:
    return String(unsafe_from_utf8=Span(data))


def test_prior_knowledge() raises:
    var sys = Sys()
    var server = listen(Echo(0), config())
    assert_true(server.port > 0)
    var fd = connect(sys, server.port)
    var frames = frames_of(exchange(server, sys, fd, h2_request("/a?b")))
    assert_equal(kinds(frames), "SETTINGS WINDOW_UPDATE SETTINGS HEADERS DATA")
    assert_equal(body(frames), "GET /a?b")
    assert_equal(server.open_connections, 1)
    assert_equal(server.http1.open_connections, 0)
    sys.close(fd)
    for _ in range(10):
        _ = server.poll(5)
    assert_equal(server.open_connections, 0)


def test_preface_in_pieces() raises:
    var sys = Sys()
    var server = listen(Echo(0), config())
    var fd = connect(sys, server.port)
    var data = h2_request()
    var first = List[UInt8]()
    first.extend(Span(data)[:5])
    var rest = List[UInt8]()
    rest.extend(Span(data)[5:])
    assert_equal(len(exchange(server, sys, fd, first, 5)), 0)
    var frames = frames_of(exchange(server, sys, fd, rest))
    assert_equal(body(frames), "GET /x")
    sys.close(fd)


def test_http1_fallback() raises:
    var sys = Sys()
    var server = listen(Echo(0), config())
    var fd = connect(sys, server.port)
    var request = List[UInt8]()
    request.extend(
        StaticString("PUT /h1 HTTP/1.1\r\nHost: x\r\n\r\n").as_bytes()
    )
    var answer = text(exchange(server, sys, fd, request))
    assert_true(answer.startswith("HTTP/1.1 200 OK\r\n"), answer)
    assert_true(answer.endswith("PUT /h1"), answer)
    assert_equal(server.open_connections, 0)
    assert_equal(server.http1.open_connections, 1)
    sys.close(fd)
    # Without prior knowledge, the preface goes to HTTP/1.1, which refuses
    # it.
    var c = config()
    c.prior_knowledge = False
    var plain = listen(Echo(0), c)
    var other = connect(sys, plain.port)
    answer = text(exchange(plain, sys, other, h2_request()))
    assert_true(answer.startswith("HTTP/1.1 505"), answer)
    sys.close(other)


def test_upgrade() raises:
    var sys = Sys()
    var c = config()
    c.upgrade = True
    var server = listen(Echo(0), c)
    var fd = connect(sys, server.port)
    var head = List[UInt8]()
    head.extend(StaticString(UPGRADE).as_bytes())
    var first = List[UInt8]()
    first.extend(Span(head)[:20])
    var rest = List[UInt8]()
    rest.extend(Span(head)[20:])
    assert_equal(len(exchange(server, sys, fd, first, 5)), 0)
    var answer = exchange(server, sys, fd, rest)
    var expected = StaticString(
        "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\n"
        "Upgrade: h2c\r\n\r\n"
    )
    var size = expected.byte_length()
    assert_equal(String(unsafe_from_utf8=Span(answer)[:size]), String(expected))
    var frames_data = List[UInt8]()
    frames_data.extend(Span(answer)[size:])
    var reader = Peer()
    var frames = frames_with(reader, frames_data)
    assert_equal(body(frames), "GET /up")
    # The client goes on with HTTP/2.
    var peer = Peer()
    peer.preface()
    peer.settings()
    peer.headers(3, request("GET", "/next"), EOS)
    frames = frames_with(reader, exchange(server, sys, fd, peer.out))
    assert_equal(body(frames), "GET /next")
    sys.close(fd)
    # A request that is not an upgrade, and an upgrade with invalid
    # settings, get HTTP/1.1.
    var plain = connect(sys, server.port)
    var get = List[UInt8]()
    get.extend(StaticString("GET /p HTTP/1.1\r\nHost: x\r\n\r\n").as_bytes())
    assert_true(text(exchange(server, sys, plain, get)).endswith("GET /p"))
    sys.close(plain)
    var bad = connect(sys, server.port)
    var invalid = List[UInt8]()
    invalid.extend(
        StaticString(
            "GET /bad HTTP/1.1\r\nHost: x\r\nConnection: Upgrade,"
            " HTTP2-Settings\r\nUpgrade: h2c\r\nHTTP2-Settings: AAMA\r\n\r\n"
        ).as_bytes()
    )
    var reply = text(exchange(server, sys, bad, invalid))
    assert_true(reply.startswith("HTTP/1.1 200"), reply)
    sys.close(bad)


def test_graceful_shutdown() raises:
    var sys = Sys()
    var server = listen(Echo(0), config())
    var h2 = connect(sys, server.port)
    _ = exchange(server, sys, h2, h2_request())
    var h1 = connect(sys, server.port)
    var get = List[UInt8]()
    get.extend(StaticString("GET / HTTP/1.1\r\nHost: x\r\n\r\n").as_bytes())
    _ = exchange(server, sys, h1, get)
    var waiting = connect(sys, server.port)
    var partial = List[UInt8]()
    partial.extend(StaticString("PRI ").as_bytes())
    _ = exchange(server, sys, waiting, partial, 3)
    server.begin_shutdown()
    server.begin_shutdown()
    assert_true(server.draining)
    # The connection that had not chosen closes; HTTP/2 gets GOAWAY and PING.
    assert_true(closed(server, sys, waiting))
    var peer = Peer()
    peer.ping(0x0B7BA2F08B9BFE54, True)
    var frames = frames_of(exchange(server, sys, h2, peer.out))
    assert_equal(kinds(frames), "GOAWAY PING GOAWAY")
    assert_true(closed(server, sys, h2))
    assert_true(closed(server, sys, h1))
    for _ in range(5):
        _ = server.poll(5)
    assert_true(server.stopped())
    server.run()
    sys.close(h2)
    sys.close(h1)
    sys.close(waiting)


def test_idle_sweep() raises:
    var sys = Sys()
    var c = config()
    c.http.idle_timeout_ms = 1
    var server = listen(Echo(0), c)
    var h2 = connect(sys, server.port)
    _ = exchange(server, sys, h2, h2_request(), 2)
    var quiet = connect(sys, server.port)
    var partial = List[UInt8]()
    partial.extend(StaticString("PR").as_bytes())
    _ = exchange(server, sys, quiet, partial, 2)
    var deadline = 0
    while server.open_connections > 0 and deadline < 300:
        _ = server.poll(10)
        deadline += 1
    assert_equal(server.open_connections, 0)
    assert_true(closed(server, sys, h2))
    sys.close(h2)
    sys.close(quiet)


def test_max_connections() raises:
    var sys = Sys()
    var c = config()
    c.http.max_connections = 1
    var server = listen(Echo(0), c)
    var first = connect(sys, server.port)
    _ = exchange(server, sys, first, h2_request(), 2)
    var second = connect(sys, server.port)
    assert_true(closed(server, sys, second))
    sys.close(first)
    sys.close(second)


def big_request() -> List[UInt8]:
    """A request for `/big`, with windows large enough for its answer."""
    var peer = Peer()
    peer.preface()
    peer.settings([4], [0x7FFFFFFF])
    peer.window_update(0, 0x7FFFFFFF - 65535)
    peer.headers(1, request("GET", "/big"), EOS)
    return peer.out.copy()


def test_backpressure() raises:
    # A response larger than the socket waits for EPOLLOUT.
    var sys = Sys()
    var server = listen(Echo(0), config())
    var fd = connect(sys, server.port)
    var data = exchange(server, sys, fd, big_request(), 50)
    assert_true(len(data) > (1 << 23), String(len(data)))
    sys.close(fd)


def test_construction_faults() raises:
    var sys = Sys()
    sys.faults = Faults(SysCall.EPOLL_CREATE, 24, 0, 1)
    var failed = False
    try:
        _ = listen(Echo(0), config(), sys^)
    except e:
        failed = e.message.startswith("epoll_create1")
    assert_true(failed)
    var other = Sys()
    other.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    failed = False
    try:
        _ = listen(Echo(0), config(), other^)
    except e:
        failed = e.message.startswith("epoll_ctl")
    assert_true(failed)
    var third = Sys()
    third.faults = Faults(SysCall.EPOLL_CTL, 24, 1, 1)
    failed = False
    try:
        _ = listen(Echo(0), config(), third^)
    except e:
        failed = e.message.startswith("epoll_ctl")
    assert_true(failed)


def test_loop_faults() raises:
    var sys = Sys()
    var server = listen(Echo(0), config())
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, EINTR, 0, 1)
    assert_equal(server.poll(0), 0)
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, 9, 0, 1)
    var failed = False
    try:
        _ = server.poll(0)
    except e:
        failed = e.message.startswith("epoll_wait")
    assert_true(failed)
    # An accepted connection that epoll cannot watch is closed.
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    var fd = connect(sys, server.port)
    assert_true(closed(server, sys, fd))
    sys.close(fd)
    # recv: EAGAIN and EINTR wait; an error closes.
    var errnos: List[Int] = [EAGAIN, EINTR]
    for errno in errnos:
        var other = connect(sys, server.port)
        _ = exchange(server, sys, other, List[UInt8](), 3)
        server.sys.faults = Faults(SysCall.RECV, errno, 0, 1)
        var frames = frames_of(exchange(server, sys, other, h2_request()))
        assert_equal(body(frames), "GET /x")
        sys.close(other)
    var third = connect(sys, server.port)
    _ = exchange(server, sys, third, List[UInt8](), 3)
    server.sys.faults = Faults(SysCall.RECV, ECONNRESET, 0, 1)
    send_all(sys, third, h2_request())
    assert_true(closed(server, sys, third))
    sys.close(third)


def test_send_faults() raises:
    var sys = Sys()
    var server = listen(Echo(0), config())
    # EAGAIN and EINTR keep the output for EPOLLOUT.
    var fd = connect(sys, server.port)
    _ = exchange(server, sys, fd, List[UInt8](), 3)
    server.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    var frames = frames_of(exchange(server, sys, fd, h2_request()))
    assert_equal(body(frames), "GET /x")
    sys.close(fd)
    var other = connect(sys, server.port)
    _ = exchange(server, sys, other, List[UInt8](), 3)
    server.sys.faults = Faults(SysCall.SEND, EINTR, 0, 1)
    frames = frames_of(exchange(server, sys, other, h2_request()))
    assert_equal(body(frames), "GET /x")
    sys.close(other)
    # An error closes the connection.
    var third = connect(sys, server.port)
    _ = exchange(server, sys, third, List[UInt8](), 3)
    server.sys.faults = Faults(SysCall.SEND, EPIPE, 0, 1)
    send_all(sys, third, h2_request())
    assert_true(closed(server, sys, third))
    sys.close(third)
    # A connection whose epoll interest cannot change is closed.
    var fourth = connect(sys, server.port)
    _ = exchange(server, sys, fourth, List[UInt8](), 3)
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    send_all(sys, fourth, big_request())
    assert_true(closed(server, sys, fourth))
    sys.close(fourth)


def test_shutdown_edges() raises:
    # A drain that times out closes the connections that are left.
    var sys = Sys()
    var c = config()
    c.http.shutdown_timeout_ms = 1
    var server = listen(Echo(0), c)
    var fd = connect(sys, server.port)
    _ = exchange(server, sys, fd, h2_request(), 3)
    server.begin_shutdown()
    assert_true(closed(server, sys, fd))
    assert_equal(server.open_connections, 0)
    sys.close(fd)
    # A shutdown after close does nothing with the listener.
    var other = listen(Echo(0), config())
    other.close()
    other.begin_shutdown()
    assert_true(other.draining)


def test_upgrade_mode_bad_request() raises:
    # An invalid request with the upgrade on goes to HTTP/1.1, which
    # answers 400.
    var sys = Sys()
    var c = config()
    c.upgrade = True
    var server = listen(Echo(0), c)
    var fd = connect(sys, server.port)
    var bad = List[UInt8]()
    bad.extend(StaticString("GET / HTTP/1.1\r\n\r\n").as_bytes())
    var answer = text(exchange(server, sys, fd, bad))
    assert_true(answer.startswith("HTTP/1.1 400"), answer)
    sys.close(fd)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
