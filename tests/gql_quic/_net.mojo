# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Sockets of the gql_quic suites: loopback UDP sockets, a closed port,
UDP-Lite and Unix datagram pairs, and raw sends, through libc."""

from std.ffi import external_call

from gql_http.socket import IPv4Address, Sys

comptime AF_INET: Int32 = 2
comptime AF_UNIX: Int32 = 1
comptime SOCK_DGRAM: Int32 = 2
comptime SOCK_FLAGS: Int32 = 0x800 | 0x80000
comptime IPPROTO_UDPLITE: Int32 = 136
comptime SOL_SOCKET: Int32 = 1
comptime SO_SNDBUF: Int32 = 7
comptime SO_NO_CHECK: Int32 = 11
comptime LOOPBACK: UInt32 = 0x7F000001


def udp_socket(proto: Int32 = 0) -> Int:
    """Open a non-blocking IPv4 datagram socket; -1 on failure."""
    return Int(
        external_call["socket", Int32](AF_INET, SOCK_DGRAM | SOCK_FLAGS, proto)
    )


def bound(proto: Int32 = 0) -> Int:
    """Open a datagram socket bound to a free loopback port."""
    var fd = udp_socket(proto)
    if fd < 0:
        return fd
    var sys = Sys()
    _ = sys.bind(fd, IPv4Address.LOOPBACK, 0)
    return fd


def port_of(fd: Int) -> Int:
    """Return the local port of a socket."""
    var sys = Sys()
    return sys.local_port(fd)


def connect_to(fd: Int, port: Int):
    """Connect a datagram socket to a loopback port."""
    var sys = Sys()
    _ = sys.connect(fd, IPv4Address.LOOPBACK, port)


def close_fd(fd: Int):
    """Close a descriptor."""
    var sys = Sys()
    sys.close(fd)


def closed_port() -> Int:
    """Return a loopback port that no socket has."""
    var fd = bound()
    var port = port_of(fd)
    close_fd(fd)
    return port


def set_option(fd: Int, level: Int32, name: Int32, value: Int32) -> Int:
    """Set an integer socket option; return the result of `setsockopt`."""
    var v = value
    return Int(
        external_call["setsockopt", Int32](
            Int32(fd), level, name, Int(Pointer(to=v)), Int32(4)
        )
    )


def unix_pair() -> Tuple[Int, Int]:
    """Open a pair of connected non-blocking Unix datagram sockets."""
    var fds = List[Int32](length=2, fill=-1)
    _ = external_call["socketpair", Int32](
        AF_UNIX, SOCK_DGRAM | SOCK_FLAGS, Int32(0), Int(fds.unsafe_ptr())
    )
    return (Int(fds[0]), Int(fds[1]))


def send_raw(fd: Int, data: List[UInt8]) -> Int:
    """Send one datagram on a connected socket; return the result."""
    return Int(
        external_call["send", Int](
            Int32(fd), Int(data.unsafe_ptr()), len(data), Int32(0x40)
        )
    )


def wait_readable(fd: Int, timeout_ms: Int):
    """Wait until a socket has a datagram, or a timeout."""
    var sys = Sys()
    _ = sys.poll(fd, 1, timeout_ms)
