# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http.server`: the event loop in this process, with raw
loopback clients, for a bounded number of turns. Faults in `Server.sys`
reach the error paths. The tests that block signals run in a child."""

from _harness import BIG, Echo, config, connect, receive, send_text
from gql_http.server import Handler, Server, listen
from gql_http.socket import (
    EAGAIN,
    EBADF,
    ECONNRESET,
    EINTR,
    EPIPE,
    Faults,
    SIGTERM,
    Sys,
    SysCall,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime REQUEST = "GET / HTTP/1.1\r\nHost: x\r\n\r\n"
"""A request that `Echo` answers with `GET / `."""


def _closed[
    H: Handler
](
    mut server: Server[H], mut sys: Sys, fd: Int, turns: Int = 400
) raises -> Bool:
    """Run the server until the client end sees the connection close."""
    var buffer = List[UInt8](length=65536, fill=0)
    var turn = 0
    while turn < turns:
        _ = server.poll(5)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n == 0 or n == -ECONNRESET:
            return True
        turn += 1
    return False


def _read_until[
    H: Handler
](
    mut server: Server[H],
    mut sys: Sys,
    fd: Int,
    size: Int,
    suffix: StaticString,
) raises -> String:
    """Run the server and read until at least `size` bytes that end with
    `suffix` came, or the connection closed."""
    var out = List[UInt8]()
    var buffer = List[UInt8](length=65536, fill=0)
    var tail = suffix.as_bytes()
    var turn = 0
    while turn < 20000:
        if len(out) >= size and Span(out)[len(out) - len(tail) :] == tail:
            break
        _ = server.poll(1)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n > 0:
            out.extend(Span(buffer)[:n])
        elif n == 0:
            break
        turn += 1
    return String(unsafe_from_utf8=out)


def _client[H: Handler](mut server: Server[H], mut sys: Sys) raises -> Int:
    """Connect a client and run the server until it has accepted it."""
    var before = server.open_connections
    var fd = connect(sys, server.port)
    var turn = 0
    while server.open_connections == before and turn < 400:
        _ = server.poll(5)
        turn += 1
    return fd


def test_get_and_keep_alive() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, "GET /a?b HTTP/1.1\r\nHost: x\r\n\r\n")
    var text = receive(server, sys, fd)
    assert_true(text.startswith("HTTP/1.1 200 OK\r\nDate: "), text)
    assert_true(
        text.endswith(
            "\r\nContent-Type: text/plain\r\nContent-Length: 9\r\n\r\nGET /a?b "
        ),
        text,
    )
    send_text(
        sys,
        fd,
        (
            "POST /p HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n\r\nhiGET /s"
            " HTTP/1.1\r\nHost: x\r\n\r\n"
        ),
    )
    text = receive(server, sys, fd)
    assert_true(text.find("POST /p hi") > 0, text)
    assert_true(text.find("GET /s ") > 0, text)
    assert_equal(server.open_connections, 1)
    sys.close(fd)
    assert_true(_closed(server, sys, fd, 20) or server.open_connections == 0)
    var turn = 0
    while server.open_connections > 0 and turn < 100:
        _ = server.poll(5)
        turn += 1
    assert_equal(server.open_connections, 0)


def test_routes() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, "GET /fail HTTP/1.1\r\nHost: x\r\n\r\n")
    var text = receive(server, sys, fd)
    assert_true(text.startswith("HTTP/1.1 500 Internal Server Error\r\n"), text)
    assert_true(text.endswith("Content-Length: 0\r\n\r\n"), text)
    send_text(sys, fd, "GET /stream HTTP/1.1\r\nHost: x\r\n\r\n")
    text = receive(server, sys, fd)
    assert_true(text.find("Transfer-Encoding: chunked\r\n") > 0, text)
    assert_true(
        text.endswith("\r\n\r\n1\r\na\r\n2\r\nbc\r\n3\r\ndef\r\n0\r\n\r\n"),
        text,
    )
    send_text(sys, fd, "GET /empty HTTP/1.1\r\nHost: x\r\n\r\n")
    text = receive(server, sys, fd)
    assert_true(text.startswith("HTTP/1.1 204 No Content\r\n"), text)
    send_text(sys, fd, "GET /close HTTP/1.1\r\nHost: x\r\n\r\n")
    text = receive(server, sys, fd)
    assert_true(text.find("Connection: close\r\n") > 0, text)
    assert_true(_closed(server, sys, fd))
    assert_equal(server.open_connections, 0)
    sys.close(fd)


def test_bad_request_lingers() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, REQUEST + "GET /a\x01 HTTP/1.1\r\n\r\n")
    var text = receive(server, sys, fd)
    assert_true(text.startswith("HTTP/1.1 200 OK\r\n"), text)
    assert_true(text.find("HTTP/1.1 400 Bad Request\r\n") > 0, text)
    assert_true(text.endswith("Connection: close\r\n\r\n"), text)
    assert_equal(server.open_connections, 1)
    send_text(sys, fd, "more bytes that the server drops")
    _ = receive(server, sys, fd, 5)
    assert_equal(server.open_connections, 1)
    sys.close(fd)
    var turn = 0
    while server.open_connections > 0 and turn < 100:
        _ = server.poll(5)
        turn += 1
    assert_equal(server.open_connections, 0)


def test_expect_continue() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(
        sys,
        fd,
        (
            "POST /e HTTP/1.1\r\nHost: x\r\nExpect:"
            " 100-continue\r\nContent-Length: 2\r\n\r\n"
        ),
    )
    var text = receive(server, sys, fd)
    assert_equal(text, "HTTP/1.1 100 Continue\r\n\r\n")
    send_text(sys, fd, "o")
    assert_equal(receive(server, sys, fd), "")
    send_text(sys, fd, "k")
    text = receive(server, sys, fd)
    assert_true(text.endswith("POST /e ok"), text)
    sys.close(fd)


def test_close_with_pipelined() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, "GET /close HTTP/1.1\r\nHost: x\r\n\r\n" + REQUEST)
    var text = receive(server, sys, fd)
    assert_true(text.endswith("GET /close "), text)
    assert_equal(text.find("GET / "), -1)
    assert_equal(server.open_connections, 1)
    sys.close(fd)
    var turn = 0
    while server.open_connections > 0 and turn < 100:
        _ = server.poll(5)
        turn += 1
    assert_equal(server.open_connections, 0)


def test_big_responses() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, "GET /big HTTP/1.1\r\nHost: x\r\n\r\n" + REQUEST)
    for _ in range(10):
        _ = server.poll(2)
    var text = _read_until(server, sys, fd, BIG, "GET / ")
    assert_true(text.find("Content-Length: " + String(BIG) + "\r\n") > 0)
    assert_true(text.endswith("\r\n\r\nGET / "), String(text.byte_length()))
    send_text(
        sys, fd, "GET /big HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
    )
    for _ in range(10):
        _ = server.poll(2)
    text = _read_until(server, sys, fd, BIG, "x")
    assert_true(text.byte_length() > BIG)
    assert_true(_closed(server, sys, fd))
    sys.close(fd)


def test_poll_faults() raises:
    var server = listen(Echo(0), config())
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, EINTR, 0, 1)
    assert_equal(server.poll(0), 0)
    server.sys.faults = Faults(SysCall.EPOLL_WAIT, EBADF, 0, 1)
    var failed = False
    try:
        _ = server.poll(0)
    except e:
        failed = e.message == "epoll_wait failed: errno 9"
    assert_true(failed)


def test_accept_limits() raises:
    var limited = config()
    limited.max_connections = 1
    var server = listen(Echo(0), limited)
    var sys = Sys()
    var first = _client(server, sys)
    var second = connect(sys, server.port)
    assert_true(_closed(server, sys, second))
    send_text(sys, first, REQUEST)
    assert_true(receive(server, sys, first).endswith("GET / "))
    sys.close(first)
    sys.close(second)
    var other = listen(Echo(0), config())
    other.sys.faults = Faults(SysCall.EPOLL_CTL, 24, 0, 1)
    var refused = connect(sys, other.port)
    assert_true(_closed(other, sys, refused))
    assert_equal(other.open_connections, 0)
    sys.close(refused)


def test_recv_faults() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = _client(server, sys)
    server.sys.faults = Faults(SysCall.RECV, EINTR, 0, 1)
    send_text(sys, fd, REQUEST)
    assert_true(receive(server, sys, fd).endswith("GET / "))
    server.sys.faults = Faults(SysCall.RECV, EAGAIN, 0, 1)
    send_text(sys, fd, REQUEST)
    assert_true(receive(server, sys, fd).endswith("GET / "))
    server.sys.faults = Faults(SysCall.RECV, ECONNRESET, 0, 1)
    send_text(sys, fd, REQUEST)
    assert_true(_closed(server, sys, fd))
    assert_equal(server.open_connections, 0)
    sys.close(fd)


def _deferred_send(errno: Int, then: Int) raises -> Int:
    """Fail the first send with `errno`; then the send on `EPOLLOUT` with
    `then`, or with none for 0. Return the open connections after."""
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = _client(server, sys)
    server.sys.faults = Faults(SysCall.SEND, errno, 0, 1)
    send_text(sys, fd, REQUEST)
    _ = server.poll(50)
    if then != 0:
        server.sys.faults = Faults(SysCall.SEND, then, 0, 1)
        _ = server.poll(50)
    var text = receive(server, sys, fd)
    if server.open_connections > 0:
        assert_true(text.endswith("GET / "), text)
    var open = server.open_connections
    sys.close(fd)
    return open


def test_send_faults() raises:
    assert_equal(_deferred_send(EAGAIN, 0), 1)
    assert_equal(_deferred_send(EINTR, 0), 1)
    assert_equal(_deferred_send(EPIPE, 0), 0)
    assert_equal(_deferred_send(EAGAIN, EAGAIN), 1)
    assert_equal(_deferred_send(EAGAIN, EINTR), 1)
    assert_equal(_deferred_send(EAGAIN, EPIPE), 0)


def test_watch_and_end_faults() raises:
    var sys = Sys()
    # The switch to EPOLLOUT fails: the connection closes.
    var a = listen(Echo(0), config())
    var fa = _client(a, sys)
    a.sys.faults = Faults(SysCall.EPOLL_CTL, EBADF, 0, 1)
    send_text(sys, fa, "GET /big HTTP/1.1\r\nHost: x\r\n\r\n")
    _ = a.poll(50)
    assert_equal(a.open_connections, 0)
    sys.close(fa)
    # The switch back to EPOLLIN fails after the pending bytes went out.
    var b = listen(Echo(0), config())
    var fb = _client(b, sys)
    b.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    send_text(sys, fb, REQUEST)
    _ = b.poll(50)
    b.sys.faults = Faults(SysCall.EPOLL_CTL, EBADF, 0, 1)
    _ = b.poll(50)
    assert_equal(b.open_connections, 0)
    sys.close(fb)
    # shutdown(SHUT_WR) fails at the end of a connection with a 400.
    var c = listen(Echo(0), config())
    var fc = _client(c, sys)
    c.sys.faults = Faults(SysCall.SHUTDOWN, EBADF, 0, 1)
    send_text(sys, fc, "BAD\r\n\r\n")
    _ = c.poll(50)
    assert_equal(c.open_connections, 0)
    sys.close(fc)
    # The end of a closing connection with bytes left, after EPOLLOUT.
    var d = listen(Echo(0), config())
    var fd = _client(d, sys)
    send_text(
        sys,
        fd,
        "GET /big HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n" + REQUEST,
    )
    _ = d.poll(50)
    d.sys.faults = Faults(SysCall.EPOLL_CTL, EBADF, 0, 1)
    var text = _read_until(d, sys, fd, BIG, "x")
    assert_true(text.byte_length() > BIG)
    assert_equal(d.open_connections, 0)
    sys.close(fd)


def test_idle_timeout() raises:
    var quick = config()
    quick.idle_timeout_ms = 10
    var server = listen(Echo(0), quick)
    var sys = Sys()
    var fd = _client(server, sys)
    assert_true(_closed(server, sys, fd, 300))
    assert_equal(server.open_connections, 0)
    sys.close(fd)


def test_shutdown() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var idle = _client(server, sys)
    var busy = _client(server, sys)
    send_text(sys, busy, "GET / HTTP/1.1\r\nHo")
    _ = receive(server, sys, busy, 5)
    server.begin_shutdown()
    server.begin_shutdown()
    assert_true(server.draining)
    assert_equal(server.open_connections, 1)
    assert_false(server.stopped())
    assert_true(_closed(server, sys, idle, 5))
    send_text(sys, busy, "st: x\r\n\r\n")
    var text = receive(server, sys, busy)
    assert_true(text.find("Connection: close\r\n") > 0, text)
    assert_true(server.stopped())
    server.run()
    sys.close(idle)
    sys.close(busy)
    var forced = config()
    forced.shutdown_timeout_ms = 20
    var other = listen(Echo(0), forced)
    var stuck = _client(other, sys)
    send_text(sys, stuck, "GET / HTTP/1.1\r\nHo")
    _ = receive(other, sys, stuck, 5)
    other.begin_shutdown()
    other.run()
    assert_equal(other.open_connections, 0)
    sys.close(stuck)


def test_close_with_connections() raises:
    var server = listen(Echo(0), config())
    var sys = Sys()
    var fd = _client(server, sys)
    server.close()
    assert_equal(server.open_connections, 0)
    # A shutdown after close has no listening socket to stop.
    server.begin_shutdown()
    assert_true(server.stopped())
    var buffer = List[UInt8](length=4, fill=0)
    _ = sys.poll(fd, 1, 1000)
    assert_true(sys.recv(fd, buffer.unsafe_ptr(), 4) <= 0)
    sys.close(fd)


def _signal_child() raises -> Int:
    """In a child: a signal ends the loop, and closes an idle connection
    whose event comes in the same turn. Return 0 when all went right."""
    var server = listen(Echo(0), config())
    server.listen_signals()
    var sys = Sys()
    var fd = _client(server, sys)
    _ = sys.kill(sys.pid(), SIGTERM)
    send_text(sys, fd, REQUEST)
    _ = server.poll(100)
    if not server.draining or server.open_connections != 0:
        return 2
    server.run()
    sys.close(fd)
    return 0


def _signal_fault_child() -> Int:
    """In a child: epoll cannot watch the signalfd."""
    try:
        var server = listen(Echo(0), config())
        server.sys.faults = Faults(SysCall.EPOLL_CTL, EBADF, 0, 1)
        try:
            server.listen_signals()
        except e:
            return 0 if e.message == "epoll_ctl failed: errno 9" else 3
        return 4
    except:
        return 5


def _child_status(which: Int) raises -> Int:
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        var code: Int
        if which == 0:
            try:
                code = _signal_child()
            except:
                code = 1
        else:
            code = _signal_fault_child()
        sys.exit_now(code)
    return sys.wait(pid, True)[1]


def test_signals() raises:
    assert_equal(_child_status(0), 0)
    assert_equal(_child_status(1), 0)
    var server = listen(Echo(0), config())
    server.sys.faults = Faults(SysCall.SIGNALFD, 24, 0, 1)
    var failed = False
    try:
        server.listen_signals()
    except e:
        failed = e.message == "signalfd failed: errno 24"
    assert_true(failed)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
