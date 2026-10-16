# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A scripted HTTP peer for the client suite: a child process that reads
each request and answers with exact bytes, so a test can send what a real
server would not: interim responses, bad heads, early closes, stalls."""

from gql_http.socket import IPv4Address, POLLIN, SIGKILL, Sys

comptime KEEP = 0
"""Send the reply and keep the connection."""
comptime CLOSE = 1
"""Send the reply, then close the connection."""
comptime DROP = 2
"""Read the request, then close the connection without a reply."""
comptime HANG = 3
"""Read the request, then send nothing until the client closes."""
comptime DEAF = 4
"""Read nothing, and send nothing, for half a second."""


@fieldwise_init
struct Step(Copyable, Movable):
    """One request of the script: what the peer does with it."""

    var reply: String
    """The bytes to send; a `~` is a 30 ms pause, and is not sent."""
    var action: Int
    """`KEEP`, `CLOSE`, `DROP`, `HANG` or `DEAF`."""


@fieldwise_init
struct Peer(Movable):
    """A running peer process and its port."""

    var pid: Int
    var port: Int

    def finish(self) -> Int:
        """Wait at most three seconds for the peer to end; return its
        status, or -1 when it had to be killed."""
        var sys = Sys()
        var turn = 0
        while turn < 300:
            var result = sys.wait(self.pid, False)
            if result[0] == self.pid:
                return result[1]
            _ = sys.poll(-1, 0, 10)
            turn += 1
        _ = sys.kill(self.pid, SIGKILL)
        _ = sys.wait(self.pid, True)
        return -1


def _read_request(mut sys: Sys, fd: Int, mut pending: String) -> Int:
    """Read until a whole request head is in `pending`, and drop it.

    Returns 0 for a request, 1 when the client closed, 2 on a timeout.
    """
    var buffer = List[UInt8](length=65536, fill=0)
    while pending.find("\r\n\r\n") < 0:
        if sys.poll(fd, POLLIN, 3000) <= 0:
            return 2
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n <= 0:
            return 1
        pending += String(unsafe_from_utf8=Span(buffer)[:n])
    var end = pending.find("\r\n\r\n") + 4
    var rest = String(pending[byte=end:])
    pending = rest^
    return 0


def _send(mut sys: Sys, fd: Int, reply: String):
    """Send a reply, with a pause at each `~`."""
    var parts = reply.split("~")
    for index in range(len(parts)):
        if index > 0:
            _ = sys.poll(-1, 0, 30)
        var bytes = parts[index].as_bytes()
        var sent = 0
        while sent < len(bytes):
            var n = sys.send(
                fd, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
            )
            if n <= 0:
                _ = sys.poll(fd, 4, 100)
                continue
            sent += n


def _run(mut sys: Sys, listener: Int, steps: List[Step]) -> Int:
    """Serve the script; return the exit status of the peer."""
    var conn = -1
    var pending = String()
    for ref step in steps:
        var read = 1
        while read == 1:
            if conn < 0:
                if sys.poll(listener, POLLIN, 3000) <= 0:
                    return 2
                conn = sys.accept(listener)
                pending = String()
            if step.action == DEAF:
                break
            read = _read_request(sys, conn, pending)
            if read == 1:
                # The client gave up this connection; it comes back on a
                # new one for the same step.
                sys.close(conn)
                conn = -1
        if read == 2:
            return 3
        if step.action == DEAF:
            # Wait until the request begins, then read none of it.
            _ = sys.poll(conn, POLLIN, 3000)
            _ = sys.poll(-1, 0, 500)
            sys.close(conn)
            conn = -1
            continue
        if step.action == DROP:
            sys.close(conn)
            conn = -1
            continue
        if step.action == HANG:
            _ = sys.poll(conn, POLLIN, 2000)
            sys.close(conn)
            conn = -1
            continue
        _send(sys, conn, step.reply)
        if step.action == CLOSE:
            sys.close(conn)
            conn = -1
    if conn >= 0:
        _ = sys.poll(conn, POLLIN, 2000)
        sys.close(conn)
    return 0


def start_peer(
    steps: List[Step], address: IPv4Address = IPv4Address.LOOPBACK
) raises -> Peer:
    """Fork a peer that listens on a free port of `address`."""
    var sys = Sys()
    var listener = sys.socket()
    if sys.bind(listener, address, 0) < 0:
        raise Error("bind failed")
    _ = sys.listen(listener, 16)
    var port = sys.local_port(listener)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        sys.exit_now(_run(sys, listener, steps))
    sys.close(listener)
    return Peer(pid, port)
