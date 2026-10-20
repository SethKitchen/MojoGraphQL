# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the error paths of `gql_ws.server`: faults in `Server.sys`,
limits, the shutdown deadline, and the descriptor of the handler.

The upstream tungstenite 0.30.0 has no event loop; these follow the fault
tests of the gql_http2 server suite.
"""

from _net import connect, drain, send_text
from _server_util import KEY, Echo, Peer, Plain, config
from _wsutil import close_frame, raw, text_frame
from gql_http.error import HttpError
from gql_http.socket import (
    EAGAIN,
    ECONNRESET,
    EINTR,
    EPIPE,
    Faults,
    Sys,
    SysCall,
)
from gql_ws.frame import CloseCode, OpCode
from gql_ws.handshake import client_request
from gql_ws.protocol import MessageKind
from gql_ws.server import Server, listen
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def construction_fails(var sys: Sys, extra: Int = -1) -> Bool:
    var handler = Echo()
    handler.extra_fd = extra
    try:
        var server = listen(handler^, Plain(), config(), sys^)
        _ = server^
        return False
    except:
        return True


def test_construction_faults() raises:
    var a = Sys()
    a.faults = Faults(SysCall.EPOLL_CREATE, 24, 0, 1)
    assert_true(construction_fails(a^))
    var b = Sys()
    b.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    assert_true(construction_fails(b^))
    var c = Sys()
    c.faults = Faults(SysCall.EPOLL_CTL, 24, 1, 1)
    assert_true(construction_fails(c^))
    var s = Sys()
    var pipe = s.pipe()
    var d = Sys()
    d.faults = Faults(SysCall.EPOLL_CTL, 24, 2, 1)
    assert_true(construction_fails(d^, pipe[0]))
    var e = Sys()
    assert_false(construction_fails(e^, pipe[0]))
    s.close(pipe[0])
    s.close(pipe[1])


def test_handler_fd_and_wait() raises:
    # The descriptor of the handler wakes the loop for `on_tick`.
    var sys = Sys()
    var pipe = sys.pipe()
    var handler = Echo()
    handler.extra_fd = pipe[0]
    handler.wait = 5
    var server = listen(handler^, Plain(), config())
    var byte = List[UInt8](length=1, fill=1)
    _ = sys.write(pipe[1], byte.unsafe_ptr(), 1)
    var before = server.handler.ticks
    assert_equal(server.poll(-1), 1)
    assert_equal(server.handler.ticks, before + 1)
    # `wait_ms` bounds the wait.
    var buffer = List[UInt8](length=8, fill=0)
    _ = sys.read(pipe[0], buffer.unsafe_ptr(), 8)
    assert_equal(server.poll(-1), 0)
    assert_equal(server.poll(1000), 0)
    sys.close(pipe[0])
    sys.close(pipe[1])


def test_loop_faults() raises:
    var server = listen(Echo(), Plain(), config())
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, EINTR, 0, 1)
    assert_equal(server.poll(0), 0)
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, 9, 0, 1)
    var failed = False
    try:
        _ = server.poll(0)
    except:
        failed = True
    assert_true(failed)


def test_accept_faults() raises:
    var c = config()
    c.http.max_connections = 1
    var server = listen(Echo(), Plain(), c)
    var first = Peer(server.port)
    first.pump(server, 2)
    var second = Peer(server.port)
    second.pump(server, 5)
    assert_true(second.closed)
    assert_equal(server.open_connections, 1)
    first.close()
    second.close()
    var other = listen(Echo(), Plain(), config())
    other.sys.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    var third = Peer(other.port)
    third.pump(other, 5)
    assert_true(third.closed)
    assert_equal(other.open_connections, 0)
    third.close()


def test_recv_faults() raises:
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    # A handshake read that would block, then an interrupted one.
    server.sys.faults = Faults(SysCall.RECV, EAGAIN, 0, 1)
    peer.send(Span(client_request("x", "/", KEY, []))[:5])
    peer.pump(server, 3)
    server.sys.faults = Faults(SysCall.RECV, EINTR, 0, 1)
    peer.send(Span(client_request("x", "/", KEY, []))[5:])
    peer.pump(server, 3)
    peer.pump(server, 3)
    assert_equal(server.handler.opened, 1)
    var data = peer.text()
    var end = data.find("\r\n\r\n")
    peer.data = List[UInt8](Span(peer.data)[end + 4 :])
    # A frame read that would block, then a reset.
    server.sys.faults = Faults(SysCall.RECV, EAGAIN, 0, 1)
    peer.send_ws_text("a")
    peer.pump(server, 3)
    server.sys.faults = Faults(SysCall.RECV, EINTR, 0, 1)
    peer.send_ws_text("b")
    peer.pump(server, 3)
    var got = peer.messages()
    assert_equal(len(got), 2)
    server.sys.faults = Faults(SysCall.RECV, ECONNRESET, 0, 1)
    peer.send_ws_text("c")
    peer.pump(server, 3)
    assert_true(peer.closed)
    assert_equal(server.handler.code, 1006)
    peer.close()


def test_send_faults() raises:
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    # A send that would block waits for EPOLLOUT; an interrupted one too.
    server.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    peer.send_ws_text("one")
    peer.pump(server)
    server.sys.faults = Faults(SysCall.SEND, EINTR, 0, 1)
    peer.send_ws_text("two")
    peer.pump(server)
    var got = peer.messages()
    assert_equal(len(got), 2)
    assert_equal(got[1].text(), "two")
    # A failed watch closes the connection.
    server.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    peer.send_ws_text("three")
    peer.pump(server)
    server.sys.faults = Faults(SysCall.SEND, EPIPE, 0, 1)
    peer.send_ws_text("four")
    peer.pump(server)
    assert_true(peer.closed)
    assert_equal(server.open_connections, 0)
    peer.close()


def test_watch_fault() raises:
    var c = config()
    c.ws.max_write_buffer_size = 16 << 20
    var server = listen(Echo(), Plain(), c)
    var peer = Peer(server.port)
    peer.upgrade(server)
    # The output fills the socket, the connection waits for EPOLLOUT,
    # and going back to EPOLLIN fails.
    server.sys.faults = Faults(SysCall.EPOLL_CTL, 24, 1, 1)
    peer.send_ws_text("flood")
    var turn = 0
    while turn < 400 and not peer.closed:
        _ = server.poll(1)
        peer.closed = not drain(peer.sys, peer.fd, peer.data)
        peer.data.clear()
        turn += 1
    assert_true(peer.closed)
    assert_equal(server.open_connections, 0)
    peer.close()


def test_closed_in_the_same_turn() raises:
    # The output for B fails while A is read, and B has an event in the
    # same turn.
    var server = listen(Echo(), Plain(), config())
    var a = Peer(server.port)
    a.upgrade(server)
    var b = Peer(server.port)
    b.upgrade(server)
    a.send_ws_text("all")
    b.send_ws_text("x")
    server.sys.faults = Faults(SysCall.SEND, EPIPE, 0, 1)
    _ = server.poll(100)
    var turn = 0
    while turn < 20:
        _ = server.poll(2)
        turn += 1
    assert_equal(server.open_connections, 1)
    a.close()
    b.close()


def test_message_then_close() raises:
    # An echo and a close in one packet: the output of the echo goes out
    # with the close, and the connection ends.
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    peer.ws.send_text("last")
    peer.ws.ping("p".as_bytes())
    peer.ws.close()
    peer.flush_ws()
    peer.pump(server)
    assert_true(peer.closed)
    var got = peer.messages()
    assert_equal(got[0].text(), "last")
    assert_true(got[1].kind == MessageKind.PONG)
    peer.close()


def test_forced_shutdown() raises:
    # A WebSocket that does not answer the close ends at the deadline, and
    # `run` returns.
    var c = config()
    c.http.shutdown_timeout_ms = 10
    var server = listen(Echo(), Plain(), c)
    var peer = Peer(server.port)
    peer.upgrade(server)
    server.begin_shutdown()
    server.run()
    assert_true(server.stopped())
    peer.close()
    # A shutdown with nothing open, then after close.
    var empty = listen(Echo(), Plain(), config())
    empty.begin_shutdown()
    assert_equal(empty.poll(0), 0)
    var closed = listen(Echo(), Plain(), config())
    closed.close()
    closed.begin_shutdown()
    assert_true(closed.draining)


def test_signals() raises:
    var server = listen(Echo(), Plain(), config())
    server.sys.faults = Faults(SysCall.SIGNALFD, 24, 0, 1)
    server.http1.sys.faults = Faults(SysCall.SIGNALFD, 24, 0, 1)
    var failed = False
    try:
        server.listen_signals()
    except:
        failed = True
    assert_true(failed)


def test_close_reason_limits() raises:
    var server = listen(Echo(), Plain(), config())
    var peer = Peer(server.port)
    peer.upgrade(server)
    var id = server.handler.last
    # A reason over 123 bytes is not sent.
    assert_true(server.sockets.close(id, CloseCode.NORMAL, String("r") * 124))
    peer.pump(server)
    var got = peer.messages()
    assert_equal(Int(got[0].code.value), 1000)
    assert_equal(got[0].text(), "")
    assert_false(server.sockets.close(id, CloseCode.NORMAL))
    assert_false(server.sockets.is_open((1 << 40) | 0xFFFF0))
    peer.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
