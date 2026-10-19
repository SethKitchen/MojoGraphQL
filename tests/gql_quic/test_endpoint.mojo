# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.endpoint`: a server endpoint and client endpoints
joined in memory. The cases port quinn-proto 0.11.19
quinn-proto/src/endpoint.rs (`handle`, `connect`, the connection index)
and quinn-proto/src/tests/mod.rs: `version_negotiate_server`,
`silently_drop_rejected_initials` and `multiple_conns_with_zero_length_cids`
in spirit (each client has its own route)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _pair import h3
from gql_tls.context import TlsContext, TlsVersion
from gql_tls.openssl import OpenSsl, TlsCall, TlsFaults
from gql_quic.cid import ConnectionId
from gql_quic.connection import TransportConfig
from gql_quic.crypto import Crypto
from gql_quic.endpoint import Endpoint
from gql_quic.packet import parse_header
from gql_quic.tls import QuicTls
from gql_quic.udp import Peer

comptime MS = 1_000_000
comptime BASE_PORT = 5000


struct Net(Movable):
    """A server endpoint and client endpoints, with a virtual clock."""

    var crypto: Crypto
    var sctx: TlsContext
    var cctx: TlsContext
    var server: Endpoint
    var clients: List[Endpoint]
    var now: Int
    var buf: List[UInt8]

    def __init__(out self) raises:
        var certs = test_certs()
        self.crypto = Crypto(OpenSsl())
        self.sctx = TlsContext.server(
            OpenSsl(), certs.cert, certs.key, h3(), TlsVersion.TLS_1_3
        )
        self.cctx = TlsContext.client(
            OpenSsl(), h3(), certs.cert, True, TlsVersion.TLS_1_3
        )
        self.server = Endpoint(
            True,
            TransportConfig(),
            self.crypto,
            QuicTls(OpenSsl()),
            self.sctx.ctx,
        )
        self.clients = List[Endpoint]()
        self.now = 1000 * MS
        self.buf = List[UInt8]()

    def client_endpoint(mut self) raises -> Endpoint:
        return Endpoint(
            False,
            TransportConfig(),
            self.crypto,
            QuicTls(OpenSsl()),
            self.cctx.ctx,
        )

    def add_client(mut self) raises -> Int:
        """Start a client; return its index, which names its port."""
        var ep = self.client_endpoint()
        var slot = ep.connect(
            "localhost", True, Peer(0x7F000001, 443), self.now
        )
        assert_equal(slot, 0)
        self.clients.append(ep^)
        return len(self.clients) - 1

    def step(mut self) -> Int:
        """Move every waiting datagram once each way; return the count."""
        var moved = 0
        var index = 0
        while index < len(self.clients):
            if (
                len(self.clients[index].conns) > 0
                and self.clients[index].conns[0]
            ):
                while True:
                    self.buf.clear()
                    var n = (
                        self.clients[index]
                        .conns[0]
                        .value()
                        .poll_transmit(self.now, self.buf)
                    )
                    if n == 0:
                        break
                    moved += 1
                    _ = self.server.handle(
                        self.now,
                        self.buf.unsafe_ptr(),
                        n,
                        Peer(0x7F000001, UInt16(BASE_PORT + index)),
                    )
            index += 1
        var slot = 0
        while slot < len(self.server.conns):
            if self.server.conns[slot]:
                var to = Int(self.server.peers[slot].port) - BASE_PORT
                while True:
                    self.buf.clear()
                    var n = (
                        self.server.conns[slot]
                        .value()
                        .poll_transmit(self.now, self.buf)
                    )
                    if n == 0:
                        break
                    moved += 1
                    _ = self.clients[to].handle(
                        self.now, self.buf.unsafe_ptr(), n, Peer(0, 0)
                    )
            slot += 1
        return moved

    def run(mut self):
        """Move datagrams until neither side sends."""
        var turns = 0
        while turns < 200 and self.step() > 0:
            turns += 1


def long_header(
    first: UInt8, version: UInt32, size: Int, length_field: Bool
) -> List[UInt8]:
    """A long header packet with cids 8 x 0xD1 and 8 x 0x5C, padded."""
    var out = List[UInt8]()
    out.append(first)
    out.append(UInt8(version >> 24))
    out.append(UInt8((version >> 16) & 0xFF))
    out.append(UInt8((version >> 8) & 0xFF))
    out.append(UInt8(version & 0xFF))
    out.append(8)
    for _ in range(8):
        out.append(0xD1)
    out.append(8)
    for _ in range(8):
        out.append(0x5C)
    if first == 0xC0 and version == 1:
        out.append(0)  # No token.
    if length_field:
        out.append(0x10)
    out.resize(size, 0)
    return out^


def short_header() -> List[UInt8]:
    var out = List[UInt8]()
    out.append(0x40)
    out.resize(40, 0x77)
    return out^


def test_connect_and_accept() raises:
    var net = Net()
    _ = net.add_client()
    net.run()
    assert_equal(net.server.accept(), 0)
    assert_equal(net.server.accept(), -1)
    assert_true(net.server.conns[0].value().handshake_done)
    assert_true(net.clients[0].conns[0].value().handshake_done)
    assert_equal(net.server.peers[0], Peer(0x7F000001, BASE_PORT))


def test_drop_unknown() raises:
    var net = Net()
    var peer = Peer(0x7F000001, 9000)
    # No fixed bit: the header does not parse.
    var junk = List[UInt8](length=10, fill=0)
    assert_equal(net.server.handle(net.now, junk.unsafe_ptr(), 10, peer), -1)
    # A client makes no connection for a datagram.
    var client = net.client_endpoint()
    var short = short_header()
    assert_equal(
        client.handle(net.now, short.unsafe_ptr(), len(short), peer), -1
    )
    # A short header of no connection.
    assert_equal(
        net.server.handle(net.now, short.unsafe_ptr(), len(short), peer), -1
    )
    # An Initial in a datagram below 1200 bytes.
    var small = long_header(0xC0, 1, 1000, True)
    assert_equal(net.server.handle(net.now, small.unsafe_ptr(), 1000, peer), -1)
    # A Handshake packet of no connection.
    var hs = long_header(0xE0, 1, 1200, True)
    assert_equal(net.server.handle(net.now, hs.unsafe_ptr(), 1200, peer), -1)
    # A Version Negotiation packet gets no answer.
    var vn = long_header(0xC0, 0, 1200, False)
    assert_equal(net.server.handle(net.now, vn.unsafe_ptr(), 1200, peer), -1)
    assert_equal(len(net.server.reply_sizes), 0)
    assert_equal(len(net.server.conns), 0)


def test_version_negotiation() raises:
    """As quinn-proto `version_negotiate_server`."""
    var net = Net()
    var peer = Peer(0x7F000001, 9001)
    var packet = long_header(0xC0, 0x0A1A2A3A, 1200, False)
    assert_equal(
        net.server.handle(net.now, packet.unsafe_ptr(), 1200, peer), -1
    )
    assert_equal(len(net.server.reply_sizes), 1)
    assert_equal(net.server.reply_peers[0], peer)
    assert_equal(net.server.reply_sizes[0], len(net.server.replies))
    var header = parse_header(net.server.replies, 0, 8)
    assert_equal(header.version, 0)
    assert_true(header.dcid == ConnectionId(Span(packet)[15:23]))
    assert_true(header.scid == ConnectionId(Span(packet)[6:14]))
    assert_equal(len(net.server.conns), 0)


def test_session_failure() raises:
    """As quinn-proto `silently_drop_rejected_initials`: an Initial whose
    TLS session libssl cannot make is dropped."""
    var net = Net()
    net.server.tls.openssl.faults = TlsFaults(TlsCall.SSL_NEW, 0, -1)
    _ = net.add_client()
    assert_true(net.step() > 0)
    assert_equal(net.server.accept(), -1)
    assert_equal(len(net.server.conns), 0)
    # A client endpoint reports the same failure.
    var client = net.client_endpoint()
    client.tls.openssl.faults = TlsFaults(TlsCall.SSL_NEW, 0, -1)
    var raised = False
    try:
        _ = client.connect("localhost", True, Peer(0, 0), net.now)
    except:
        raised = True
    assert_true(raised)


def test_remove_and_reuse() raises:
    var net = Net()
    _ = net.add_client()
    _ = net.add_client()
    net.run()
    assert_equal(len(net.server.accept_queue), 2)
    # A removed connection leaves the accept queue and its routes.
    net.server.remove(1)
    assert_false(Bool(net.server.conns[1]))
    net.server.remove(1)
    assert_equal(net.server.accept(), 0)
    assert_equal(net.server.accept(), -1)
    # A new connection takes the free slot.
    _ = net.add_client()
    net.run()
    assert_equal(net.server.peers[1], Peer(0x7F000001, BASE_PORT + 2))
    assert_equal(net.server.accept(), 1)
    assert_true(net.server.conns[1].value().handshake_done)
    net.server.remove(0)
    assert_false(Bool(net.server.conns[0]))
    # A client endpoint drops its connection too.
    net.clients[0].remove(0)
    assert_false(Bool(net.clients[0].conns[0]))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
