# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Socket helpers of the gql_ws suites: connect, send, and read while a
server loop runs in this process."""

from gql_http.socket import ECONNRESET, IPv4Address, POLLOUT, Sys


def connect(mut sys: Sys, port: Int) raises -> Int:
    """Connect a non-blocking socket to a loopback port."""
    var fd = sys.socket()
    _ = sys.set_no_delay(fd)
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc < 0 and rc != -115:
        raise Error("connect failed")
    _ = sys.poll(fd, POLLOUT, 2000)
    return fd


def send_all(mut sys: Sys, fd: Int, data: Span[UInt8, _]) raises:
    """Send all of some bytes."""
    var sent = 0
    while sent < len(data):
        var n = sys.send(
            fd, data.unsafe_ptr().unsafe_offset(sent), len(data) - sent
        )
        if n == -11:
            _ = sys.poll(fd, 4, 100)
            continue
        if n < 0:
            raise Error("send failed: " + String(n))
        sent += n


def send_text(mut sys: Sys, fd: Int, text: StringSlice) raises:
    """Send the bytes of a text."""
    send_all(sys, fd, text.as_bytes())


def drain(mut sys: Sys, fd: Int, mut out: List[UInt8]) -> Bool:
    """Read what the socket holds now; False when the peer closed it."""
    var buffer = List[UInt8](length=65536, fill=0)
    while True:
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n > 0:
            out.extend(Span(buffer)[:n])
            continue
        return not (n == 0 or n == -ECONNRESET)


def text_of(data: List[UInt8]) -> String:
    """The bytes as text, for messages of a test."""
    return String(unsafe_from_utf8=Span(data))
