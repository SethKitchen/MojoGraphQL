# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.udp` over loopback sockets. The cases port
quinn-udp 0.5.16 quinn-udp/tests/tests.rs: `basic`, `gso` and
`socket_buffers`; ECN, IPv6 and `basic_src_ip` have no case, since the
port has no ECN, no IPv6 and no `IP_PKTINFO`. The GSO fallback cases
make the kernel refuse GSO by honest means: `SO_NO_CHECK` gives EINVAL
and a UDP-Lite socket gives EIO."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _net import (
    IPPROTO_UDPLITE,
    LOOPBACK,
    SOL_SOCKET,
    SO_NO_CHECK,
    SO_SNDBUF,
    bound,
    close_fd,
    closed_port,
    connect_to,
    port_of,
    set_option,
    unix_pair,
    wait_readable,
)
from gql_quic.udp import BATCH, ECONNREFUSED, Peer, UdpIo


def datagrams(sizes: List[Int]) -> List[UInt8]:
    """Datagrams one after another; byte `i` of datagram `n` is `n + i`."""
    var out = List[UInt8]()
    var n = 0
    while n < len(sizes):
        var i = 0
        while i < sizes[n]:
            out.append(UInt8((n + i) & 0xFF))
            i += 1
        n += 1
    return out^


def same(count: Int, size: Int) -> List[Int]:
    """`count` sizes of `size`."""
    return List[Int](length=count, fill=size)


def receive_all(mut io: UdpIo, want: Int) raises -> List[Int]:
    """Receive until `want` datagrams arrived; return their sizes, and
    check the bytes of each one against `datagrams`."""
    var got = List[Int]()
    var turns = 0
    while len(got) < want and turns < 100:
        var count = io.recv()
        if count == 0:
            wait_readable(io.fd, 20)
            turns += 1
            continue
        assert_true(count > 0)
        var index = 0
        while index < count:
            var d = io.datagram(index)
            var n = len(got)
            if len(d) > 0:
                assert_equal(Int(d[0]), n & 0xFF)
                assert_equal(Int(d[len(d) - 1]), (n + len(d) - 1) & 0xFF)
            got.append(len(d))
            index += 1
    return got^


def no_peers() -> List[Peer]:
    return List[Peer]()


def test_peer_write() raises:
    assert_equal(String(Peer(LOOPBACK, 4433)), "127.0.0.1:4433")
    assert_true(Peer(1, 2) == Peer(1, 2))
    assert_false(Peer(1, 2) == Peer(1, 3))


def test_basic() raises:
    """As quinn-udp `basic`: a connected sender and an unconnected receiver,
    then the reverse."""
    var server = bound()
    var client = bound()
    connect_to(client, port_of(server))
    var tx = UdpIo(client, True)
    var rx = UdpIo(server, False)
    assert_equal(rx.recv(), 0)
    var sizes = List[Int]()
    sizes.append(5)
    assert_equal(tx.send(datagrams(sizes), sizes, no_peers()), 1)
    wait_readable(server, 1000)
    assert_equal(rx.recv(), 1)
    assert_equal(len(rx.datagram(0)), 5)
    assert_equal(rx.peers[0], Peer(LOOPBACK, UInt16(port_of(client))))
    # The server answers to the address of the datagram.
    var peers = List[Peer]()
    peers.append(rx.peers[0])
    assert_equal(rx.send(datagrams(sizes), sizes, peers), 1)
    wait_readable(client, 1000)
    assert_equal(tx.recv(), 1)
    assert_equal(len(tx.datagram(0)), 5)
    assert_equal(tx.recv(), 0)
    close_fd(client)
    close_fd(server)


def test_send_nothing() raises:
    var fd = bound()
    var io = UdpIo(fd, True)
    assert_equal(io.send(List[UInt8](), List[Int](), no_peers()), 0)
    close_fd(fd)


def test_gso() raises:
    """As quinn-udp `gso`: equal datagrams leave as one message, and the
    receiver gets each one; a smaller datagram ends a run."""
    var server = bound()
    var client = bound()
    connect_to(client, port_of(server))
    var tx = UdpIo(client, True)
    var rx = UdpIo(server, False)
    var sizes = List[Int]()
    sizes.append(1000)
    sizes.append(1000)
    sizes.append(1000)
    sizes.append(500)
    # A larger datagram after a smaller one starts a new run.
    sizes.append(300)
    sizes.append(900)
    assert_equal(tx.send(datagrams(sizes), sizes, no_peers()), 6)
    assert_true(tx.gso)
    var got = receive_all(rx, 6)
    assert_equal(len(got), 6)
    var index = 0
    while index < 6:
        assert_equal(got[index], sizes[index])
        index += 1
    close_fd(client)
    close_fd(server)


def test_gso_segment_limit() raises:
    """A run holds at most `MAX_SEGMENTS` datagrams."""
    var server = bound()
    var client = bound()
    connect_to(client, port_of(server))
    var tx = UdpIo(client, True)
    var rx = UdpIo(server, False)
    var sizes = same(70, 100)
    assert_equal(tx.send(datagrams(sizes), sizes, no_peers()), 70)
    assert_equal(len(receive_all(rx, 70)), 70)
    close_fd(client)
    close_fd(server)


def test_gso_size_limit() raises:
    """A run holds at most 65000 bytes."""
    var server = bound()
    var client = bound()
    connect_to(client, port_of(server))
    var tx = UdpIo(client, True)
    var rx = UdpIo(server, False)
    var sizes = same(60, 1200)
    assert_equal(tx.send(datagrams(sizes), sizes, no_peers()), 60)
    var got = receive_all(rx, 60)
    assert_equal(len(got), 60)
    assert_equal(got[59], 1200)
    close_fd(client)
    close_fd(server)


def test_unconnected_peers() raises:
    """A run holds the datagrams of one peer only."""
    var a = bound()
    var b = bound()
    var sender = bound()
    var tx = UdpIo(sender, False)
    var sizes = same(3, 100)
    var peers = List[Peer]()
    peers.append(Peer(LOOPBACK, UInt16(port_of(a))))
    peers.append(Peer(LOOPBACK, UInt16(port_of(a))))
    peers.append(Peer(LOOPBACK, UInt16(port_of(b))))
    assert_equal(tx.send(datagrams(sizes), sizes, peers), 3)
    var ra = UdpIo(a, False)
    var rb = UdpIo(b, False)
    assert_equal(len(receive_all(ra, 2)), 2)
    wait_readable(b, 1000)
    assert_equal(rb.recv(), 1)
    assert_equal(rb.peers[0].port, UInt16(port_of(sender)))
    close_fd(a)
    close_fd(b)
    close_fd(sender)


def test_batch_limit() raises:
    """Without GSO, one `sendmmsg` takes `BATCH` messages; the rest go
    in the next call."""
    var server = bound()
    var client = bound()
    connect_to(client, port_of(server))
    var tx = UdpIo(client, True, False)
    var rx = UdpIo(server, False)
    var sizes = same(BATCH + 1, 200)
    assert_equal(tx.send(datagrams(sizes), sizes, no_peers()), BATCH + 1)
    assert_equal(len(receive_all(rx, BATCH + 1)), BATCH + 1)
    close_fd(client)
    close_fd(server)


def test_gso_einval_fallback() raises:
    """A socket without UDP checksums refuses GSO with EINVAL; the batch
    goes again, one datagram per message."""
    var server = bound()
    var client = bound()
    assert_equal(set_option(client, SOL_SOCKET, SO_NO_CHECK, 1), 0)
    connect_to(client, port_of(server))
    var tx = UdpIo(client, True)
    var rx = UdpIo(server, False)
    var sizes = same(2, 1000)
    assert_equal(tx.send(datagrams(sizes), sizes, no_peers()), 2)
    assert_false(tx.gso)
    assert_equal(len(receive_all(rx, 2)), 2)
    close_fd(client)
    close_fd(server)


def test_gso_eio_fallback() raises:
    """A UDP-Lite socket refuses GSO with EIO."""
    var server = bound(IPPROTO_UDPLITE)
    if server < 0:
        return  # The kernel has no UDP-Lite.
    var client = bound(IPPROTO_UDPLITE)
    connect_to(client, port_of(server))
    var tx = UdpIo(client, True)
    var rx = UdpIo(server, False)
    var sizes = same(2, 1000)
    assert_equal(tx.send(datagrams(sizes), sizes, no_peers()), 2)
    assert_false(tx.gso)
    assert_equal(len(receive_all(rx, 2)), 2)
    close_fd(client)
    close_fd(server)


def test_refused() raises:
    """An ICMP port unreachable fails the next call of a connected socket
    with ECONNREFUSED, whether it sends or receives."""
    var client = bound()
    connect_to(client, closed_port())
    var io = UdpIo(client, True)
    var sizes = List[Int]()
    sizes.append(10)
    var data = datagrams(sizes)
    assert_equal(io.send(data, sizes, no_peers()), 1)
    assert_equal(io.send(data, sizes, no_peers()), -ECONNREFUSED)
    assert_true(io.gso)
    assert_equal(io.send(data, sizes, no_peers()), 1)
    assert_equal(io.recv(), -ECONNREFUSED)
    close_fd(client)


def test_socket_buffers() raises:
    """As quinn-udp `socket_buffers`: a full send buffer takes part of a
    batch, then nothing; a datagram that does not fit is dropped."""
    var pair = unix_pair()
    _ = set_option(pair[0], SOL_SOCKET, SO_SNDBUF, 4096)
    var io = UdpIo(pair[0], True, False)
    var sizes = same(BATCH, 1000)
    var data = datagrams(sizes)
    var first = io.send(data, sizes, no_peers())
    assert_true(first > 0)
    assert_true(first < BATCH)
    assert_equal(io.send(data, sizes, no_peers()), 0)
    # The other end reads what was sent, with no addresses.
    var rx = UdpIo(pair[1], True)
    assert_equal(rx.recv(), first)
    assert_equal(len(rx.datagram(0)), 1000)
    close_fd(pair[0])
    close_fd(pair[1])


def test_closed_socket() raises:
    """A closed descriptor fails both ways with EBADF."""
    var fd = bound()
    close_fd(fd)
    var io = UdpIo(fd, False)
    assert_equal(io.recv(), -9)
    var sizes = List[Int]()
    sizes.append(10)
    var peers = List[Peer]()
    peers.append(Peer(LOOPBACK, 9))
    assert_equal(io.send(datagrams(sizes), sizes, peers), -9)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
