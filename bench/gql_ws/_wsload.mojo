# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The WebSocket load generator of the gql_ws benchmarks, in Mojo.

Every server workload, the Mojo one and each baseline, runs against this
program, so that only the server differs.

`ws/echo-roundtrip`: `CONNECTIONS` connections in one epoll loop. Each
sends a masked text message of 64 bytes, waits for the echo, and sends the
next at once. The result is nanoseconds per round trip: the length of a
round divided by the echoes of the round, the inverse of the throughput.

`graphql-ws/subscribe-1000-next`: one connection speaks
`graphql-transport-ws`. Each operation is a `subscribe` to
`subscription { greetings }`; the server publishes 1000 events, and the
client reads the 1000 `next` messages, then sends `complete`. The result
is nanoseconds per `next`.

Each workload warms up, then the fastest of `ROUNDS` rounds of at least
`ROUND_NS` is the result. As a program, it starts a server command, reads
`PORT <n>` from the first line of its output, runs the load, and stops
the server's process group:

    ws_load <workload> <server command>
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
    POLLIN,
    POLLOUT,
    SIGKILL,
    SIGTERM,
    Sys,
    event_fd,
)
from gql_ws.client import WsClient
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.handshake import client_request, generate_key
from gql_ws.protocol import Message, MessageKind, Role, WebSocket

comptime CONNECTIONS = 16
"""The connections of the echo workload."""
comptime ECHO_TEXT = (
    '{"type":"next","id":"1","payload":{"data":{"hello":"world"}}}xx'
)
"""The 64 bytes that each echo sends."""
comptime ROUNDS = 5
"""How many rounds are timed."""
comptime ROUND_NS = 1_000_000_000
"""The least length of a round."""
comptime WARMUP_NS = 500_000_000
"""How long a workload warms up."""
comptime EVENTS = 1000
"""The `next` messages of one subscription."""


def _connect(mut sys: Sys, port: Int) raises -> Int:
    """Open one connection to the loopback port, with its handshake."""
    var fd = sys.socket()
    _ = sys.set_no_delay(fd)
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc != 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    _ = sys.poll(fd, POLLOUT, 5000)
    var request = client_request(
        "127.0.0.1:" + String(port), "/graphql", generate_key(), []
    )
    _ = sys.send(fd, request.unsafe_ptr(), len(request))
    var buffer = List[UInt8](length=4096, fill=0)
    var got = String()
    while not got.endswith("\r\n\r\n"):
        _ = sys.poll(fd, POLLIN, 5000)
        var n = sys.recv(fd, buffer.unsafe_ptr(), 1)
        if n <= 0:
            raise Error("handshake failed")
        got += String(unsafe_from_utf8=Span(buffer)[:1])
    if not got.startswith("HTTP/1.1 101"):
        raise Error("handshake refused: " + got)
    return fd


struct _Echo(Movable):
    """One echo connection."""

    var fd: Int
    var ws: WebSocket

    def __init__(out self, fd: Int):
        self.fd = fd
        self.ws = WebSocket(Role.CLIENT)


def _send(mut sys: Sys, mut conn: _Echo) raises:
    """Send the output of a connection."""
    while conn.ws.pending() > 0:
        var n = sys.send(conn.fd, conn.ws.output(), conn.ws.pending())
        if n == -EAGAIN:
            _ = sys.poll(conn.fd, POLLOUT, 1000)
            continue
        if n < 0:
            raise Error("send failed")
        conn.ws.advance(n)


def run_echo(name: String, port: Int) raises:
    """Run the echo workload and print its `BENCH` line."""
    var sys = Sys()
    var epoll = sys.epoll_create()
    var conns = List[_Echo]()
    var index_of = List[Int](length=65536, fill=-1)
    for _ in range(CONNECTIONS):
        var fd = _connect(sys, port)
        index_of[fd] = len(conns)
        conns.append(_Echo(fd))
        _ = sys.epoll_ctl(epoll, EPOLL_CTL_ADD, fd, EPOLLIN)
    var text = StaticString(ECHO_TEXT)
    for k in range(len(conns)):
        conns[k].ws.send_text(text)
        _send(sys, conns[k])
    var events = List[UInt8](length=256 * EPOLL_EVENT_SIZE, fill=0)
    var message = Message()
    var start = Int(perf_counter_ns())
    var round_start = start + WARMUP_NS
    var round = -1
    var count = 0
    var best = Float64.MAX
    while round < ROUNDS:
        var n = sys.epoll_wait(epoll, events.unsafe_ptr(), 256, 100)
        var index = 0
        while index < n:
            var k = index_of[event_fd(events.unsafe_ptr(), index)]
            index += 1
            ref conn = conns[k]
            conn.ws.reserve(16384)
            var got = sys.recv(
                conn.fd, conn.ws.write_pointer(), conn.ws.space()
            )
            if got <= 0:
                continue
            conn.ws.commit(got)
            while conn.ws.read(message):
                if message.kind == MessageKind.TEXT:
                    count += 1
                    conn.ws.send_text(text)
            _send(sys, conn)
        var now = Int(perf_counter_ns())
        if now >= round_start + ROUND_NS or (round < 0 and now >= round_start):
            if round >= 0:
                best = min(
                    best, Float64(now - round_start) / Float64(max(count, 1))
                )
            round += 1
            round_start = now
            count = 0
    for k in range(len(conns)):
        sys.close(conns[k].fd)
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def _subscription(mut client: WsClient, mut message: Message, id: Int) raises:
    """Run one subscription: subscribe, read the `next` messages of the
    events, and complete."""
    var key = String(id)
    client.send_text(
        '{"id":"'
        + key
        + '","type":"subscribe","payload":{"query":"subscription {'
        ' greetings }"}}'
    )
    var prefix = '{"id":"' + key + '","type":"next"'
    var seen = 0
    while seen < EVENTS:
        if not client.read(message, 5000):
            raise Error("the server sent " + String(seen) + " events")
        if message.kind == MessageKind.TEXT and message.text().startswith(
            prefix
        ):
            seen += 1
    client.send_text('{"id":"' + key + '","type":"complete"}')


def run_subscribe(name: String, port: Int) raises:
    """Run the graphql-ws workload and print its `BENCH` line."""
    var client = WsClient.connect(
        "ws://127.0.0.1:" + String(port) + "/graphql",
        [GRAPHQL_TRANSPORT_WS_PROTOCOL],
    )
    var message = Message()
    client.send_text('{"type":"connection_init"}')
    if not client.read(message, 5000) or not message.text().startswith(
        '{"type":"connection_ack"'
    ):
        raise Error("no connection_ack")
    var id = 0
    var start = Int(perf_counter_ns())
    while Int(perf_counter_ns()) - start < WARMUP_NS:
        id += 1
        _subscription(client, message, id)
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var round_start = Int(perf_counter_ns())
        var count = 0
        while Int(perf_counter_ns()) - round_start < ROUND_NS:
            id += 1
            _subscription(client, message, id)
            count += EVENTS
        var elapsed = Int(perf_counter_ns()) - round_start
        best = min(best, Float64(elapsed) / Float64(count))
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def run_load(name: String, port: Int) raises:
    """Run a workload by its name against a server on a port.

    Args:
        name: `ws/echo-roundtrip` or `graphql-ws/subscribe-1000-next`.
        port: The loopback port of the server.

    Raises:
        Error: For an unknown workload, or when the server fails.
    """
    if name == "ws/echo-roundtrip":
        run_echo(name, port)
    elif name == "graphql-ws/subscribe-1000-next":
        run_subscribe(name, port)
    else:
        raise Error("unknown workload: " + name)


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


def stop(pid: Int):
    """Stop a server process group: SIGTERM, then SIGKILL after 3 s.

    Args:
        pid: The process id, which is also the group id.
    """
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
        raise Error("usage: ws_load <workload> <server command>")
    var name = String(args[1])
    var command = String(args[2])
    for k in range(3, len(args)):
        command += " " + String(args[k])
    var server = _spawn(command)
    try:
        run_load(name, server[1])
    except e:
        stop(server[0])
        raise e^
    stop(server[0])
