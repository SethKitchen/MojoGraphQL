# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The HTTP load generator of the gql_http benchmarks, in Mojo.

Every server workload, the Mojo one and each baseline, runs against this
program, so that only the server differs. It forks `PROCESSES` client
processes. Each holds `CONNECTIONS / PROCESSES` keep-alive connections in
an epoll loop. Each connection sends a request, waits for the whole
response, and sends the next one at once: one request in flight per
connection, no pipelining.

The clock is shared: all processes warm up until one time, then count the
responses that complete in each of `ROUNDS` rounds of `ROUND_NS`. The
result of a round is its length divided by the responses of all processes
in it: nanoseconds per request, the inverse of the throughput. The best
round is the result. Each response also records its latency.

As a program, it starts a server command, reads `PORT <n>` from the first
line of its output, runs the load, and stops the server's process group:

    http_loadgen <workload> <server command>

It prints `BENCH <workload> <ns per request>` and a `LATENCY` line.
"""

from std.ffi import external_call
from std.sys import argv
from std.time import perf_counter_ns

from gql_http.socket import (
    EAGAIN,
    EPOLL_CTL_ADD,
    EPOLL_EVENT_SIZE,
    EPOLLIN,
    IPv4Address,
    POLLOUT,
    SIGKILL,
    SIGTERM,
    Sys,
    event_fd,
)

comptime CONNECTIONS = 64
"""The keep-alive connections of all client processes."""
comptime PROCESSES = 4
"""The client processes."""
comptime WARMUP_NS = 500_000_000
"""How long the load runs before the first round."""
comptime ROUND_NS = 1_000_000_000
"""The length of a round."""
comptime ROUNDS = 5
"""How many rounds the load runs."""
comptime BUCKET_NS = 1000
"""The width of a latency bucket."""
comptime BUCKETS = 20000
"""The latency buckets; the last one holds every slower response."""
comptime REQUEST = (
    "POST /graphql HTTP/1.1\r\nHost: localhost\r\nUser-Agent: mojo-loadgen\r\n"
    "Accept: application/graphql-response+json, application/json\r\n"
    "Content-Type: application/json\r\nContent-Length: 19\r\n\r\n"
    '{"query":"{hello}"}'
)
"""The request: a small GraphQL POST."""
comptime RESPONSE_BODY = '{"data":{"hello":"world"}}'
"""The content that every server answers with."""


struct _Conn(Copyable):
    """The state of one client connection."""

    var fd: Int
    var buffer: List[UInt8]
    var end: Int
    var started: Int

    def __init__(out self, fd: Int):
        self.fd = fd
        self.buffer = List[UInt8](length=8192, fill=0)
        self.end = 0
        self.started = 0


def _lower(byte: UInt8) -> UInt8:
    """ASCII lowercase."""
    return byte | 32 if byte >= 65 and byte <= 90 else byte


def _complete(p: Pointer[UInt8, _], end: Int) -> Int:
    """Return the size of the response at `p` when it is whole, else -1.

    The servers answer with `Content-Length`, so that is all it reads.
    """
    var head_end = -1
    var index = 3
    while index < end:
        if p[unsafe_offset=index] == 10 and p[unsafe_offset=index - 1] == 13:
            if (
                p[unsafe_offset=index - 2] == 10
                and p[unsafe_offset=index - 3] == 13
            ):
                head_end = index + 1
                break
        index += 1
    if head_end < 0:
        return -1
    var name = StaticString("\ncontent-length:")
    var w = name.unsafe_ptr()
    var n = name.byte_length()
    var length = -1
    index = 0
    while index + n < head_end:
        var same = True
        for k in range(n):
            if _lower(p[unsafe_offset=index + k]) != w[unsafe_offset=k]:
                same = False
                break
        if same:
            var at = index + n
            while p[unsafe_offset=at] == 32:
                at += 1
            length = 0
            while p[unsafe_offset=at] >= 48 and p[unsafe_offset=at] <= 57:
                length = length * 10 + Int(p[unsafe_offset=at]) - 48
                at += 1
            break
        index += 1
    if length < 0:
        return -1
    if end - head_end < length:
        return -1
    return head_end + length


def _connect(mut sys: Sys, port: Int) raises -> Int:
    """Open one connection to the loopback port."""
    var fd = sys.socket()
    if fd < 0:
        raise Error("socket failed")
    _ = sys.set_no_delay(fd)
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc != 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    _ = sys.poll(fd, POLLOUT, 5000)
    if sys.socket_error(fd) != 0:
        raise Error("connect failed")
    return fd


def _client(port: Int, count: Int, start: Int, out_fd: Int) raises:
    """Run one client process: drive `count` connections, then write the
    counts per round and the latency buckets to `out_fd`."""
    var sys = Sys()
    var request = StaticString(REQUEST)
    var epoll = sys.epoll_create()
    var conns = List[_Conn]()
    var index_of = List[Int](length=65536, fill=-1)
    for _ in range(count):
        var fd = _connect(sys, port)
        index_of[fd] = len(conns)
        conns.append(_Conn(fd))
        _ = sys.epoll_ctl(epoll, EPOLL_CTL_ADD, fd, EPOLLIN)
    var rounds = List[Int](length=ROUNDS, fill=0)
    var buckets = List[Int](length=BUCKETS, fill=0)
    var finish = start + WARMUP_NS + ROUNDS * ROUND_NS
    var events = List[UInt8](length=256 * EPOLL_EVENT_SIZE, fill=0)
    var now = Int(perf_counter_ns())
    for k in range(len(conns)):
        conns[k].started = now
        _ = sys.send(conns[k].fd, request.unsafe_ptr(), request.byte_length())
    while now < finish:
        var n = sys.epoll_wait(epoll, events.unsafe_ptr(), 256, 100)
        now = Int(perf_counter_ns())
        for e in range(n):
            var fd = event_fd(events.unsafe_ptr(), e)
            ref conn = conns[index_of[fd]]
            var got = sys.recv(
                fd,
                conn.buffer.unsafe_ptr().unsafe_offset(conn.end),
                len(conn.buffer) - conn.end,
            )
            if got == -EAGAIN:
                continue
            if got <= 0:
                raise Error("the server closed a connection")
            conn.end += got
            var size = _complete(conn.buffer.unsafe_ptr(), conn.end)
            if size < 0:
                continue
            conn.end = 0
            var since = now - start - WARMUP_NS
            if since >= 0 and since < ROUNDS * ROUND_NS:
                rounds[since // ROUND_NS] += 1
                var latency = (now - conn.started) // BUCKET_NS
                buckets[min(latency, BUCKETS - 1)] += 1
            conn.started = now
            _ = sys.send(fd, request.unsafe_ptr(), request.byte_length())
    var text = String()
    for k in range(ROUNDS):
        text += String(rounds[k]) + " "
    text += "\n"
    for k in range(BUCKETS):
        if buckets[k] > 0:
            text += String(k) + ":" + String(buckets[k]) + " "
    text += "\n"
    var bytes = text.as_bytes()
    var sent = 0
    while sent < len(bytes):
        var w = sys.write(
            out_fd, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
        )
        if w <= 0:
            break
        sent += w


def _read_all(mut sys: Sys, fd: Int) -> String:
    """Read a descriptor to its end."""
    var out = List[UInt8]()
    var buffer = List[UInt8](length=65536, fill=0)
    while True:
        var n = sys.read(fd, buffer.unsafe_ptr(), len(buffer))
        if n <= 0:
            break
        out.extend(Span(buffer)[:n])
    return String(unsafe_from_utf8=out)


def run_load(name: StringSlice, port: Int) raises:
    """Run the load against a server on a loopback port and print the
    `BENCH` and `LATENCY` lines.

    Args:
        name: The workload name.
        port: The port.

    Raises:
        Error: When a client process fails.
    """
    var sys = Sys()
    var start = Int(perf_counter_ns()) + 300_000_000
    var pipes = List[Int]()
    var pids = List[Int]()
    for _ in range(PROCESSES):
        var fds = sys.pipe()
        var pid = sys.fork()
        if pid == 0:
            sys.close(fds[0])
            var share = CONNECTIONS // PROCESSES
            var code = 0
            try:
                _client(port, share, start, fds[1])
            except e:
                print("client failed:", e)
                code = 1
            sys.exit_now(code)
        sys.close(fds[1])
        pipes.append(fds[0])
        pids.append(pid)
    var rounds = List[Int](length=ROUNDS, fill=0)
    var buckets = List[Int](length=BUCKETS, fill=0)
    for k in range(PROCESSES):
        var text = _read_all(sys, pipes[k])
        sys.close(pipes[k])
        var result = sys.wait(pids[k], True)
        if result[1] != 0:
            raise Error("a client process failed")
        var lines = text.splitlines()
        var counts = lines[0].split(" ")
        for r in range(ROUNDS):
            rounds[r] += Int(String(counts[r]))
        for item in lines[1].split(" "):
            if item.byte_length() == 0:
                continue
            var parts = item.split(":")
            buckets[Int(String(parts[0]))] += Int(String(parts[1]))
    var best = Float64.MAX
    for r in range(ROUNDS):
        if rounds[r] > 0:
            best = min(best, Float64(ROUND_NS) / Float64(rounds[r]))
    var total = 0
    var sum = 0
    for k in range(BUCKETS):
        total += buckets[k]
        sum += buckets[k] * k
    var p50 = 0
    var p99 = 0
    var seen = 0
    for k in range(BUCKETS):
        seen += buckets[k]
        if p50 == 0 and seen * 2 >= total:
            p50 = k + 1
        if p99 == 0 and seen * 100 >= total * 99:
            p99 = k + 1
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)
    print(
        "LATENCY",
        name,
        "mean_us=" + String(Float64(sum) / Float64(max(total, 1)) + 0.5),
        "p50_us<=" + String(p50),
        "p99_us<=" + String(p99),
        "requests=" + String(total),
        "connections=" + String(CONNECTIONS),
    )


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
        raise Error("usage: http_loadgen <workload> <server command>")
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
