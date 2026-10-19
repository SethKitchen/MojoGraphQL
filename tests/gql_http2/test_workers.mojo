# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the worker processes of `gql_http2.server`: `start_workers`,
`run_worker` and `serve`, and a graceful shutdown on `SIGTERM`.

These follow the gql_http worker suite; h2 v0.4.20 has no workers.
"""

from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import Faults, IPv4Address, SIGTERM, Sys, SysCall
from gql_http2.client import Client, Protocol
from gql_http2.server import ServerConfig, run_worker, serve, start_workers
from std.testing import TestSuite, assert_equal, assert_true


@fieldwise_init
struct Echo(Handler):
    """Answers with the target; `/kill` sends `SIGTERM` to its worker."""

    var count: Int

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        if request.path() == "/kill":
            var sys = Sys()
            _ = sys.kill(sys.pid(), SIGTERM)
        response.write_text(request.target())


def config() -> ServerConfig:
    var c = ServerConfig()
    c.http.host = IPv4Address.LOOPBACK
    c.http.port = 0
    return c^


def _url(port: Int, path: StringSlice) -> String:
    return "http://127.0.0.1:" + String(port) + String(path)


def test_start_workers() raises:
    var two = config()
    two.http.workers = 2
    var pool = start_workers(Echo(0), two)
    assert_equal(len(pool.pids), 2)
    for _ in range(4):
        var client = Client()
        var response = client.get(_url(pool.port, "/w"))
        assert_true(response.protocol == Protocol.HTTP_2)
        assert_equal(response.text(), "/w")
    assert_equal(pool.stop(), 0)


def _start_error(call: SysCall, skip: Int) raises -> String:
    var two = config()
    two.http.workers = 2
    var sys = Sys()
    sys.faults = Faults(call, 13, skip, 1)
    try:
        var pool = start_workers(Echo(0), two, sys^)
        _ = pool.stop()
    except e:
        return e.message.copy()
    return "no error"


def test_start_errors() raises:
    assert_equal(_start_error(SysCall.BIND, 1), "bind failed: errno 13")
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
        one.http.port = port
        var code = 0
        try:
            serve(Echo(0), one)
        except:
            code = 1
        sys.exit_now(code)
    # A request that makes its worker shut down gracefully: the response
    # still arrives, and the worker ends with 0.
    var client = Client()
    var answer = String()
    var tries = 0
    while tries < 100 and answer == "":
        try:
            answer = client.get(_url(port, "/kill")).text()
        except:
            _ = sys.poll(-1, 0, 20)
        tries += 1
    assert_equal(answer, "/kill")
    client.close()
    assert_equal(sys.wait(serving, True)[1], 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
