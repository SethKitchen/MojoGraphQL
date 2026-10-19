# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The h2c load generator of the gql_http2 benchmarks, in Mojo.

The Mojo server and the Rust baseline both run against this program, so
that only the server differs. It opens one h2c connection with prior
knowledge, and sends a small GraphQL `POST` on a new stream as soon as the
last response is whole: one request in flight, on one connection that
stays open.

It warms up for `WARMUP_NS`, then counts the round trips of each of
`ROUNDS` rounds of `ROUND_NS`. The result is the best round: nanoseconds
per round trip.

As a program, it starts a server command, reads `PORT <n>` from the first
line of its output, runs the load, and stops the server's process group:

    h2load <workload> <server command>

It prints `BENCH <workload> <ns per round trip>`.
"""

from std.ffi import external_call
from std.sys import argv
from std.time import perf_counter_ns

from gql_http.error import HttpError
from gql_http.headers import Headers
from gql_http.socket import (
    EINPROGRESS,
    IPv4Address,
    POLLOUT,
    SIGKILL,
    SIGTERM,
    Sys,
)
from gql_http2.client import ClientConnection
from gql_http2.session import SocketTransport

comptime WARMUP_NS = 500_000_000
"""How long the load runs before the first round."""
comptime ROUND_NS = 1_000_000_000
"""The length of a round."""
comptime ROUNDS = 5
"""How many rounds the load runs."""
comptime REQUEST_BODY = '{"query":"{hello}"}'
"""The content of each request."""
comptime RESPONSE_BODY = '{"data":{"hello":"world"}}'
"""The content that every server answers with."""


def _connect(port: Int) raises -> ClientConnection[SocketTransport]:
    """Open an h2c connection to a loopback port."""
    var sys = Sys()
    var fd = sys.socket()
    _ = sys.set_no_delay(fd)
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc == -EINPROGRESS:
        _ = sys.poll(fd, POLLOUT, 5000)
        rc = -abs(sys.socket_error(fd))
    if rc != 0:
        raise Error("connect failed: errno " + String(-rc))
    return ClientConnection[SocketTransport](SocketTransport(fd, sys^))


def run_load(name: String, port: Int) raises:
    """Run the load against a server on a loopback port, and print the
    result line.

    Args:
        name: The workload id.
        port: The port.

    Raises:
        Error: When a response is not the expected one.
    """
    var connection = _connect(port)
    var headers = Headers()
    headers.add("user-agent", "mojo-h2load")
    headers.add("accept", "application/graphql-response+json, application/json")
    headers.add("content-type", "application/json")
    var body = StaticString(REQUEST_BODY).as_bytes()
    var start = Int(perf_counter_ns())
    var round_end = start + WARMUP_NS
    var round = -1
    var count = 0
    var best = Float64(1e18)
    while round < ROUNDS:
        var response = connection.send(
            "POST", "http", "localhost", "/graphql", headers, body, 5000
        )
        if response.status.code != 200 or len(response.data) != 26:
            raise Error("unexpected response: " + String(response.status.code))
        count += 1
        var now = Int(perf_counter_ns())
        if now >= round_end:
            if round >= 0:
                var ns = Float64(now - (round_end - ROUND_NS)) / Float64(count)
                best = min(best, ns)
            round += 1
            count = 0
            round_end = now + ROUND_NS
    connection.close()
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def _spawn(command: String) raises -> Tuple[Int, Int]:
    """Start `/bin/sh -c command` in its own process group, and return its
    process id and the port from its first output line."""
    var sys = Sys()
    var fds = sys.pipe()
    var shell = String("/bin/sh")
    var flag = String("-c")
    var cmd = command.copy()
    var pid = sys.fork()
    if pid == 0:
        _ = external_call["setpgid", Int32](Int32(0), Int32(0))
        _ = external_call["dup2", Int32](Int32(fds[1]), Int32(1))
        var args = List[Int]()
        args.append(Int(shell.as_c_string_span().ptr()))
        args.append(Int(flag.as_c_string_span().ptr()))
        args.append(Int(cmd.as_c_string_span().ptr()))
        args.append(0)
        _ = external_call["execv", Int32](
            shell.as_c_string_span().ptr(), args.unsafe_ptr()
        )
        sys.exit_now(127)
    _ = shell
    _ = flag
    _ = cmd
    sys.close(fds[1])
    var line = List[UInt8]()
    var byte = List[UInt8](length=1, fill=0)
    while True:
        var n = sys.read(fds[0], byte.unsafe_ptr(), 1)
        if n <= 0:
            raise Error("the server ended before it printed PORT <n>")
        if byte[0] == 10:
            var text = String(unsafe_from_utf8=line)
            if text.startswith("PORT "):
                break
            line.clear()
            continue
        line.append(byte[0])
    var text = String(unsafe_from_utf8=line)
    sys.close(fds[0])
    return (pid, Int(String(text[byte=5:])))


def _stop(pid: Int):
    """Stop a server process group: SIGTERM, then SIGKILL after 3 s."""
    var sys = Sys()
    _ = sys.kill(-pid, SIGTERM)
    var deadline = Int(perf_counter_ns()) + 3_000_000_000
    while Int(perf_counter_ns()) < deadline:
        var result = sys.wait(pid, False)
        if result[0] != 0:
            _ = sys.kill(-pid, SIGKILL)
            return
        _ = sys.poll(-1, 0, 10)
    _ = sys.kill(-pid, SIGKILL)
    _ = sys.wait(pid, True)


def main() raises:
    """Start a server command, load it, and stop it."""
    var args = argv()
    if len(args) < 3:
        raise Error("usage: h2load <workload> <server command>")
    var name = String(args[1])
    var command = String(args[2])
    for k in range(3, len(args)):
        command += " " + String(args[k])
    var server = _spawn(command)
    try:
        run_load(name, server[1])
    except e:
        _stop(server[0])
        raise e^
    _stop(server[0])
