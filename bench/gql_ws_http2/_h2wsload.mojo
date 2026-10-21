# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The load generator of the gql_ws_http2 benchmark, in Mojo.

Every server, the Mojo one and the baseline, runs against this program, so
that only the server differs.

`ws-h2/echo-roundtrip`: `CONNECTIONS` h2c connections in one epoll loop,
each with one WebSocket on an extended `CONNECT` stream (RFC 8441). Each
sends a masked text message of 64 bytes in a DATA frame, waits for the
echo, and sends the next at once. The result is nanoseconds per round
trip: the length of a round divided by the echoes of the round.

The workload warms up, then the fastest of `ROUNDS` rounds of at least
`ROUND_NS` is the result. As a program, it starts a server command, reads
`PORT <n>` from the first line of its output, runs the load, and stops
the server's process group:

    h2ws_load <server command>
"""

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
    Sys,
    event_fd,
)
from gql_http2.connection import Connection, Role
from gql_ws.protocol import Message, MessageKind, Role as WsRole, WebSocket
from gql_ws_http2.handshake import client_head

from _spawn import spawn, stop

comptime CONNECTIONS = 16
"""The connections of the workload."""
comptime ECHO_TEXT = (
    '{"type":"next","id":"1","payload":{"data":{"hello":"world"}}}xx'
)
"""The 64 bytes that each echo sends."""
comptime ROUNDS = 5
"""How many rounds are timed."""
comptime ROUND_NS = 1_000_000_000
"""The least length of a round."""
comptime WARMUP_NS = 500_000_000
"""How long the workload warms up."""


struct _Echo(Movable):
    """One connection, with its WebSocket stream."""

    var fd: Int
    var conn: Connection
    var ws: WebSocket
    var stream: Int

    def __init__(out self, fd: Int):
        self.fd = fd
        self.conn = Connection(Role.CLIENT)
        self.conn.start()
        self.ws = WebSocket(WsRole.CLIENT)
        self.stream = 0


def _flush(mut sys: Sys, mut echo: _Echo) raises:
    """Send the output of the connection."""
    var sent = 0
    while sent < len(echo.conn.out):
        var n = sys.send(
            echo.fd,
            echo.conn.out.unsafe_ptr().unsafe_offset(sent),
            len(echo.conn.out) - sent,
        )
        if n == -EAGAIN:
            _ = sys.poll(echo.fd, POLLOUT, 1000)
            continue
        if n < 0:
            raise Error("send failed")
        sent += n
    echo.conn.out.clear()


def _read(mut sys: Sys, mut echo: _Echo, mut buffer: List[UInt8]) -> Bool:
    """Read what arrived into the connection; False when nothing did."""
    var n = sys.recv(echo.fd, buffer.unsafe_ptr(), len(buffer))
    if n <= 0:
        return False
    echo.conn.receive(Span(buffer)[:n])
    echo.conn.events.clear()
    return True


def _connect(mut sys: Sys, port: Int, mut buffer: List[UInt8]) raises -> _Echo:
    """Open one connection, and its WebSocket with the extended CONNECT."""
    var fd = sys.socket()
    _ = sys.set_no_delay(fd)
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc != 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    _ = sys.poll(fd, POLLOUT, 5000)
    var echo = _Echo(fd)
    _flush(sys, echo)
    while not echo.conn.is_extended_connect_protocol_enabled():
        if sys.poll(fd, POLLIN, 5000) <= 0 or not _read(sys, echo, buffer):
            raise Error("the server does not allow the extended CONNECT")
    echo.stream = echo.conn.open_stream()
    var authority = "127.0.0.1:" + String(port)
    echo.conn.send_headers(
        echo.stream, client_head("http", authority, "/graphql", []), False
    )
    _flush(sys, echo)
    while True:
        var index = echo.conn.find(echo.stream)
        if index >= 0 and echo.conn.streams[index].got_head:
            if echo.conn.streams[index].status != 200:
                raise Error("the server refused the WebSocket")
            return echo^
        if sys.poll(fd, POLLIN, 5000) <= 0 or not _read(sys, echo, buffer):
            raise Error("the handshake did not finish")


def _send_text(mut echo: _Echo, text: StringSlice) raises:
    """Send a text message on the stream."""
    echo.ws.send_text(text)
    echo.conn.send_data(
        echo.stream,
        Span(unsafe_ptr=echo.ws.output(), length=echo.ws.pending()),
        False,
    )
    echo.ws.advance(echo.ws.pending())


def run_echo(name: String, port: Int) raises:
    """Run the echo workload and print its `BENCH` line."""
    var sys = Sys()
    var epoll = sys.epoll_create()
    var buffer = List[UInt8](length=65536, fill=0)
    var conns = List[_Echo]()
    var index_of = List[Int](length=65536, fill=-1)
    for _ in range(CONNECTIONS):
        var echo = _connect(sys, port, buffer)
        index_of[echo.fd] = len(conns)
        _ = sys.epoll_ctl(epoll, EPOLL_CTL_ADD, echo.fd, EPOLLIN)
        conns.append(echo^)
    var text = StaticString(ECHO_TEXT)
    for k in range(len(conns)):
        _send_text(conns[k], text)
        _flush(sys, conns[k])
    var events = List[UInt8](length=256 * EPOLL_EVENT_SIZE, fill=0)
    var message = Message()
    var round_start = Int(perf_counter_ns()) + WARMUP_NS
    var round = -1
    var count = 0
    var best = Float64.MAX
    while round < ROUNDS:
        var n = sys.epoll_wait(epoll, events.unsafe_ptr(), 256, 100)
        var index = 0
        while index < n:
            var k = index_of[event_fd(events.unsafe_ptr(), index)]
            index += 1
            ref echo = conns[k]
            if not _read(sys, echo, buffer):
                continue
            var slot = echo.conn.find(echo.stream)
            echo.ws.receive(Span(echo.conn.streams[slot].body))
            echo.conn.streams[slot].body.clear()
            while echo.ws.read(message):
                if message.kind == MessageKind.TEXT:
                    count += 1
                    _send_text(echo, text)
            _flush(sys, echo)
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


def main() raises:
    """Start a server command, load it, and stop it."""
    var args = argv()
    if len(args) < 2:
        raise Error("usage: h2ws_load <server command>")
    var command = String(args[1])
    for k in range(2, len(args)):
        command += " " + String(args[k])
    var server = spawn(command)
    try:
        run_echo("ws-h2/echo-roundtrip", server[1])
    except e:
        stop(server[0])
        raise e^
    stop(server[0])
