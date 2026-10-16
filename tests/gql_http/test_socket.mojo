# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http.socket`: IPv4 addresses, the fault seam, and each
system call on real loopback sockets, pipes, epoll, signals and child
processes. Every descriptor and child that a test opens, it closes or
reaps."""

from gql_http.error import ErrorKind
from gql_http.socket import (
    EAGAIN,
    EBADF,
    EINPROGRESS,
    EPOLLIN,
    EPOLL_CTL_ADD,
    EPOLL_CTL_DEL,
    EPOLL_EVENT_SIZE,
    Faults,
    IPv4Address,
    POLLIN,
    POLLOUT,
    SIGKILL,
    SIGTERM,
    Sys,
    SysCall,
    event_fd,
    event_flags,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_syscall_and_faults() raises:
    assert_true(SysCall.PIPE.is_valid())
    assert_false(SysCall(20).is_valid())
    assert_equal(String(SysCall.BIND), "SysCall(3)")
    var faults = Faults(SysCall.SEND, 32, 1, 2)
    assert_equal(faults.take(SysCall.RECV), 0)
    assert_equal(faults.take(SysCall.SEND), 0)
    assert_equal(faults.take(SysCall.SEND), 32)
    assert_equal(faults.take(SysCall.SEND), 32)
    assert_equal(faults.take(SysCall.SEND), 0)
    var forever = Faults(SysCall.SEND, 11, 0, -1)
    assert_equal(forever.take(SysCall.SEND), 11)
    assert_equal(forever.take(SysCall.SEND), 11)
    assert_equal(forever.count, -1)
    var none = Faults()
    assert_equal(none.take(SysCall.NONE), 0)


def _ip(text: StaticString) -> Int:
    var address = IPv4Address.parse(text)
    if not address:
        return -1
    return Int(address.value().value)


def test_ipv4_address() raises:
    assert_equal(_ip("127.0.0.1"), 0x7F000001)
    assert_equal(_ip("0.0.0.0"), 0)
    assert_equal(_ip("255.255.255.255"), 0xFFFFFFFF)
    assert_equal(_ip("10.20.30.40"), 0x0A141E28)
    assert_equal(_ip(""), -1)
    assert_equal(_ip("256.0.0.1"), -1)
    assert_equal(_ip("1234.1.1.1"), -1)
    assert_equal(_ip("01.2.3.4"), -1)
    assert_equal(_ip("1.2.3"), -1)
    assert_equal(_ip("1.2.3.4.5"), -1)
    assert_equal(_ip("1..2.3"), -1)
    assert_equal(_ip("1.2.3."), -1)
    assert_equal(_ip("1.2.3.4x"), -1)
    assert_equal(_ip("a.b.c.d"), -1)
    assert_equal(String(IPv4Address.LOOPBACK), "127.0.0.1")
    assert_true(IPv4Address.ANY == IPv4Address(0))


@fieldwise_init
struct _Pair(Movable):
    """A listener, and a client and a server end connected over loopback."""

    var listener: Int
    var client: Int
    var server: Int
    var port: Int


def _pair(mut sys: Sys) raises -> _Pair:
    var listener = sys.socket()
    assert_true(listener >= 0)
    assert_equal(sys.set_reuse_address(listener), 0)
    assert_equal(sys.set_reuse_port(listener), 0)
    assert_equal(sys.bind(listener, IPv4Address.LOOPBACK, 0), 0)
    assert_equal(sys.listen(listener, 16), 0)
    var port = sys.local_port(listener)
    assert_true(port > 0)
    assert_equal(sys.accept(listener), -EAGAIN)
    var client = sys.socket()
    var rc = sys.connect(client, IPv4Address.LOOPBACK, port)
    assert_true(rc == 0 or rc == -EINPROGRESS)
    assert_true(sys.poll(client, POLLOUT, 2000) & POLLOUT != 0)
    assert_equal(sys.socket_error(client), 0)
    assert_true(sys.poll(listener, POLLIN, 2000) & POLLIN != 0)
    var server = sys.accept(listener)
    assert_true(server >= 0)
    assert_equal(sys.set_no_delay(server), 0)
    return _Pair(listener, client, server, port)


def _close(mut sys: Sys, pair: _Pair):
    sys.close(pair.client)
    sys.close(pair.server)
    sys.close(pair.listener)


def test_loopback() raises:
    var sys = Sys()
    var pair = _pair(sys)
    var buffer = List[UInt8](length=16, fill=0)
    assert_equal(sys.recv(pair.server, buffer.unsafe_ptr(), 16), -EAGAIN)
    assert_equal(sys.peek(pair.server), -EAGAIN)
    assert_equal(sys.poll(pair.server, POLLIN, 0), 0)
    var text = StaticString("ping").as_bytes()
    assert_equal(sys.send(pair.client, text.unsafe_ptr(), 4), 4)
    assert_true(sys.poll(pair.server, POLLIN, 2000) & POLLIN != 0)
    assert_equal(sys.peek(pair.server), 1)
    assert_equal(sys.recv(pair.server, buffer.unsafe_ptr(), 16), 4)
    assert_equal(String(unsafe_from_utf8=Span(buffer)[:4]), "ping")
    assert_equal(sys.shutdown_write(pair.client), 0)
    assert_true(sys.poll(pair.server, POLLIN, 2000) & POLLIN != 0)
    assert_equal(sys.recv(pair.server, buffer.unsafe_ptr(), 16), 0)
    _close(sys, pair)


def test_bad_descriptors() raises:
    var sys = Sys()
    var byte = List[UInt8](length=1, fill=0)
    assert_equal(sys.local_port(-1), -EBADF)
    assert_equal(sys.socket_error(-1), -EBADF)
    assert_equal(sys.read_signal(-1), -EBADF)
    assert_equal(sys.read(-1, byte.unsafe_ptr(), 1), -EBADF)
    assert_equal(sys.write(-1, byte.unsafe_ptr(), 1), -EBADF)
    assert_equal(sys.recv(-1, byte.unsafe_ptr(), 1), -EBADF)
    assert_equal(sys.send(-1, byte.unsafe_ptr(), 1), -EBADF)
    assert_equal(sys.epoll_ctl(-1, EPOLL_CTL_ADD, 0, EPOLLIN), -EBADF)
    assert_true(sys.poll(-1, POLLIN, 0) <= 0)
    var used = Sys()
    var pair = _pair(used)
    var other = sys.socket()
    assert_true(sys.bind(other, IPv4Address.LOOPBACK, pair.port) < 0)
    sys.close(other)
    _close(used, pair)


def _faulted(call: SysCall) -> Sys:
    var sys = Sys()
    sys.faults = Faults(call, 5, 0, 1)
    return sys^


def test_faults() raises:
    var buffer = List[UInt8](length=4, fill=0)
    var p = buffer.unsafe_ptr()
    var a = _faulted(SysCall.SOCKET)
    assert_equal(a.socket(), -5)
    var b = _faulted(SysCall.SETSOCKOPT)
    assert_equal(b.set_no_delay(0), -5)
    var c = _faulted(SysCall.BIND)
    assert_equal(c.bind(0, IPv4Address.ANY, 0), -5)
    var d = _faulted(SysCall.LISTEN)
    assert_equal(d.listen(0, 1), -5)
    var e = _faulted(SysCall.GETSOCKNAME)
    assert_equal(e.local_port(0), -5)
    var f = _faulted(SysCall.ACCEPT)
    assert_equal(f.accept(0), -5)
    var g = _faulted(SysCall.CONNECT)
    assert_equal(g.connect(0, IPv4Address.LOOPBACK, 1), -5)
    var h = _faulted(SysCall.RECV)
    assert_equal(h.recv(0, p, 4), -5)
    var h2 = _faulted(SysCall.RECV)
    assert_equal(h2.peek(0), -5)
    var i = _faulted(SysCall.SEND)
    assert_equal(i.send(0, p, 4), -5)
    var j = _faulted(SysCall.SHUTDOWN)
    assert_equal(j.shutdown_write(0), -5)
    var k = _faulted(SysCall.EPOLL_CREATE)
    assert_equal(k.epoll_create(), -5)
    var l = _faulted(SysCall.EPOLL_CTL)
    assert_equal(l.epoll_ctl(0, EPOLL_CTL_ADD, 0, EPOLLIN), -5)
    var m = _faulted(SysCall.EPOLL_WAIT)
    assert_equal(m.epoll_wait(0, p, 0, 0), -5)
    var n = _faulted(SysCall.POLL)
    assert_equal(n.poll(0, POLLIN, 0), -5)
    var o = _faulted(SysCall.FORK)
    assert_equal(o.fork(), -5)
    var q = _faulted(SysCall.SIGNALFD)
    assert_equal(q.signal_fd(), -5)
    var r = _faulted(SysCall.GETSOCKOPT)
    assert_equal(r.socket_error(0), -5)
    var s = _faulted(SysCall.PIPE)
    var fds = s.pipe()
    assert_equal(fds[0], -5)
    assert_equal(fds[1], -5)


def test_pipe() raises:
    var sys = Sys()
    var fds = sys.pipe()
    assert_true(fds[0] >= 0 and fds[1] >= 0)
    var text = StaticString("ab").as_bytes()
    assert_equal(sys.write(fds[1], text.unsafe_ptr(), 2), 2)
    var buffer = List[UInt8](length=4, fill=0)
    assert_equal(sys.read(fds[0], buffer.unsafe_ptr(), 4), 2)
    assert_equal(Int(buffer[1]), 98)
    sys.close(fds[0])
    sys.close(fds[1])


def test_epoll() raises:
    var sys = Sys()
    var pair = _pair(sys)
    var epoll = sys.epoll_create()
    assert_true(epoll >= 0)
    assert_equal(sys.epoll_ctl(epoll, EPOLL_CTL_ADD, pair.server, EPOLLIN), 0)
    var events = List[UInt8](length=4 * EPOLL_EVENT_SIZE, fill=0)
    assert_equal(sys.epoll_wait(epoll, events.unsafe_ptr(), 4, 0), 0)
    var text = StaticString("x").as_bytes()
    assert_equal(sys.send(pair.client, text.unsafe_ptr(), 1), 1)
    assert_equal(sys.epoll_wait(epoll, events.unsafe_ptr(), 4, 2000), 1)
    assert_equal(event_fd(events.unsafe_ptr(), 0), pair.server)
    assert_true(event_flags(events.unsafe_ptr(), 0) & EPOLLIN != 0)
    assert_equal(sys.epoll_ctl(epoll, EPOLL_CTL_DEL, pair.server, 0), 0)
    sys.close(epoll)
    _close(sys, pair)


def _signal_child(mut sys: Sys) -> Int:
    """Block the signals, send SIGTERM to this process, and read it back.

    Returns the signal, or 1 to 3 for the step that failed.
    """
    sys.ignore_broken_pipe()
    var fd = sys.signal_fd()
    if fd < 0:
        return 1
    if sys.read_signal(fd) != -EAGAIN:
        return 2
    _ = sys.kill(sys.pid(), SIGTERM)
    if sys.poll(fd, POLLIN, 2000) & POLLIN == 0:
        return 3
    return sys.read_signal(fd)


def test_signals() raises:
    # In a child: the signal mask stays blocked, and the test runner stops
    # a hung suite with SIGTERM.
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        sys.exit_now(_signal_child(sys))
    var result = sys.wait(pid, True)
    assert_equal(result[0], pid)
    assert_equal(result[1], SIGTERM)


def test_processes() raises:
    var sys = Sys()
    assert_true(sys.pid() > 0)
    assert_true(sys.parent_pid() > 0)
    assert_true(sys.wall_seconds() > 1_700_000_000)
    var exits = sys.fork()
    if exits == 0:
        _ = sys.die_with_parent()
        sys.exit_now(3)
    assert_true(exits > 0)
    var exited = sys.wait(exits, True)
    assert_equal(exited[0], exits)
    assert_equal(exited[1], 3)
    var sleeps = sys.fork()
    if sleeps == 0:
        _ = sys.poll(-1, POLLIN, 10000)
        sys.exit_now(0)
    assert_equal(sys.wait(sleeps, False)[0], 0)
    assert_equal(sys.kill(sleeps, SIGKILL), 0)
    var killed = sys.wait(sleeps, True)
    assert_equal(killed[0], sleeps)
    assert_equal(killed[1], 128 + SIGKILL)
    assert_true(sys.kill(sleeps, 0) < 0)


def test_resolve() raises:
    var sys = Sys()
    assert_true(sys.resolve("10.0.0.1") == IPv4Address(0x0A000001))
    assert_true(sys.resolve("localhost") == IPv4Address.LOOPBACK)
    sys.faults = Faults(SysCall.RESOLVE, 2, 0, 1)
    var failed = False
    try:
        _ = sys.resolve("localhost")
    except e:
        failed = e.kind == ErrorKind.RESOLVE and e.errno == 2
        assert_equal(e.message, "cannot resolve localhost: getaddrinfo error 2")
    assert_true(failed)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
