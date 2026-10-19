# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Socket helpers of the gql_http2 suites: a connected loopback pair, and
reads and writes that wait."""

from gql_http.socket import EAGAIN, IPv4Address, POLLIN, Sys


@fieldwise_init
struct Pair(Movable):
    """A listener, and a client end and a server end connected to it."""

    var listener: Int
    var client: Int
    var server: Int

    def close(self, mut sys: Sys):
        """Close the three descriptors."""
        sys.close(self.client)
        sys.close(self.server)
        sys.close(self.listener)


def loopback_pair(mut sys: Sys) raises -> Pair:
    """Connect a non-blocking client to a fresh loopback listener."""
    var listener = sys.socket()
    if sys.bind(listener, IPv4Address.LOOPBACK, 0) < 0:
        raise Error("bind failed")
    _ = sys.listen(listener, 16)
    var client = sys.socket()
    var rc = sys.connect(client, IPv4Address.LOOPBACK, sys.local_port(listener))
    if rc < 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    _ = sys.poll(listener, POLLIN, 2000)
    var server = sys.accept(listener)
    if server < 0:
        raise Error("accept failed: " + String(server))
    _ = sys.poll(client, 4, 2000)
    return Pair(listener, client, server)


def send_all(mut sys: Sys, fd: Int, data: List[UInt8]) raises:
    """Send all of some bytes."""
    var sent = 0
    while sent < len(data):
        var n = sys.send(
            fd, data.unsafe_ptr().unsafe_offset(sent), len(data) - sent
        )
        if n == -EAGAIN:
            _ = sys.poll(fd, 4, 100)
            continue
        if n < 0:
            raise Error("send failed: " + String(n))
        sent += n


def read_all(mut sys: Sys, fd: Int, quiet_ms: Int = 50) -> List[UInt8]:
    """Read until the socket is quiet for a while, or closed."""
    var out = List[UInt8]()
    var buffer = List[UInt8](length=65536, fill=0)
    while True:
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n > 0:
            out.extend(Span(buffer)[:n])
            continue
        if n == 0:
            return out^
        if sys.poll(fd, POLLIN, quiet_ms) <= 0:
            return out^
