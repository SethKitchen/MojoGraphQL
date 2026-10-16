# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the worker processes of `gql_http.server`: `start_workers`,
`run_worker`, `WorkerPool` and `serve`. Every child that a test forks, it
reaps; a worker also ends when its parent ends."""

from _harness import Echo, config, send_text
from gql_http.server import WorkerPool, run_worker, serve, start_workers
from gql_http.socket import (
    Faults,
    IPv4Address,
    POLLIN,
    POLLOUT,
    Sys,
    SysCall,
)
from std.testing import TestSuite, assert_equal, assert_true


def _connect(mut sys: Sys, port: Int) raises -> Int:
    """Connect to a port, and retry while nothing listens on it yet."""
    var tries = 0
    while tries < 300:
        var fd = sys.socket()
        _ = sys.connect(fd, IPv4Address.LOOPBACK, port)
        _ = sys.poll(fd, POLLOUT, 1000)
        if sys.socket_error(fd) == 0:
            return fd
        sys.close(fd)
        _ = sys.poll(-1, 0, 10)
        tries += 1
    raise Error("cannot connect to port " + String(port))


def _ask(mut sys: Sys, port: Int, target: StaticString) raises -> String:
    """Send one request on a new connection and read the response."""
    var fd = _connect(sys, port)
    send_text(sys, fd, String("GET ") + target + " HTTP/1.1\r\nHost: x\r\n\r\n")
    var out = List[UInt8]()
    var buffer = List[UInt8](length=4096, fill=0)
    while not String(unsafe_from_utf8=out).endswith(" "):
        if sys.poll(fd, POLLIN, 2000) <= 0:
            break
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n <= 0:
            break
        out.extend(Span(buffer)[:n])
    sys.close(fd)
    return String(unsafe_from_utf8=out)


def _child(mut sys: Sys, behavior: Int) -> Int:
    """Fork a child: 0 exits 0, 1 exits 1, 2 dies of SIGTERM, 3 blocks
    SIGTERM and sleeps, 4 exits 0 when SIGTERM comes, as a worker does."""
    var pid = sys.fork()
    if pid == 0:
        if behavior == 1:
            sys.exit_now(1)
        if behavior == 4:
            var fd = sys.signal_fd()
            _ = sys.poll(fd, POLLIN, 10000)
            sys.exit_now(0)
        if behavior == 3:
            _ = sys.signal_fd()
        if behavior >= 2:
            _ = sys.poll(-1, 0, 10000)
        sys.exit_now(0)
    return pid


def test_pool() raises:
    var empty = WorkerPool(List[Int](), 0)
    assert_equal(empty.wait(), 0)
    assert_equal(empty.stop(), 0)
    var sys = Sys()
    var pids: List[Int] = [_child(sys, 0), _child(sys, 1)]
    var waited = WorkerPool(pids^, 0)
    assert_equal(waited.wait(), 1)
    assert_equal(len(waited.pids), 0)
    var killed: List[Int] = [_child(sys, 2), _child(sys, 4)]
    var stuck: List[Int] = [_child(sys, 3)]
    # Let the children block SIGTERM before it comes.
    _ = sys.poll(-1, 0, 50)
    var stopped = WorkerPool(killed^, 0)
    assert_equal(stopped.stop(), 1)
    var forced = WorkerPool(stuck^, 0)
    assert_equal(forced.stop(50), 1)
    assert_equal(len(forced.pids), 0)


def test_start_workers() raises:
    var two = config()
    two.workers = 2
    var pool = start_workers(Echo(0), two)
    assert_equal(len(pool.pids), 2)
    assert_true(pool.port > 0)
    var sys = Sys()
    for _ in range(4):
        assert_true(_ask(sys, pool.port, "/w").endswith("GET /w "))
    assert_equal(pool.stop(), 0)


def _start_error(call: SysCall, skip: Int) raises -> String:
    var two = config()
    two.workers = 2
    var sys = Sys()
    sys.faults = Faults(call, 13, skip, 1)
    try:
        var pool = start_workers(Echo(0), two, sys^)
        _ = pool.stop()
    except e:
        return e.message.copy()
    return "no error"


def test_start_errors() raises:
    assert_equal(_start_error(SysCall.BIND, 0), "bind failed: errno 13")
    assert_equal(_start_error(SysCall.BIND, 1), "bind failed: errno 13")
    assert_equal(_start_error(SysCall.FORK, 0), "fork failed: errno 13")
    assert_equal(_start_error(SysCall.FORK, 1), "fork failed: errno 13")


def test_run_worker() raises:
    var sys = Sys()
    var first = sys.socket()
    var second = sys.socket()
    var orphan = sys.fork()
    if orphan == 0:
        var listeners: List[Int] = [first, second]
        run_worker(Echo(0), config(), listeners, 1, 0, -7)
    assert_equal(sys.wait(orphan, True)[1], 1)
    var broken = sys.fork()
    if broken == 0:
        var listeners: List[Int] = [first]
        var faulty = Sys()
        faulty.faults = Faults(SysCall.EPOLL_CREATE, 24, 0, 1)
        run_worker(
            Echo(0), config(), listeners, 0, 0, sys.parent_pid(), faulty^
        )
    assert_equal(sys.wait(broken, True)[1], 1)
    sys.close(first)
    sys.close(second)


def _free_port(mut sys: Sys) raises -> Int:
    var fd = sys.socket()
    _ = sys.bind(fd, IPv4Address.LOOPBACK, 0)
    var port = sys.local_port(fd)
    sys.close(fd)
    return port


def test_serve() raises:
    var sys = Sys()
    var failing = sys.fork()
    if failing == 0:
        var faulty = Sys()
        faulty.faults = Faults(SysCall.EPOLL_CREATE, 24, 0, 1)
        var code = 1
        try:
            serve(Echo(0), config(), faulty^)
        except e:
            code = 0 if e.message == "1 workers failed" else 2
        sys.exit_now(code)
    assert_equal(sys.wait(failing, True)[1], 0)
    var port = _free_port(sys)
    var serving = sys.fork()
    if serving == 0:
        var one = config()
        one.port = port
        var code = 0
        try:
            serve(Echo(0), one)
        except:
            code = 1
        sys.exit_now(code)
    assert_true(_ask(sys, port, "/kill").endswith("GET /kill "))
    assert_equal(sys.wait(serving, True)[1], 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
