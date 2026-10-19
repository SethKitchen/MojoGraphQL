# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The connections of one UDP socket, without I/O.

`Endpoint` routes each datagram to its connection by the Destination
Connection ID. A server endpoint makes a connection for the first Initial
packet of a client, in a datagram of at least 1200 bytes, and answers a
long header packet of another version with Version Negotiation (RFC 9000
sections 5.2 and 6). Other datagrams that match no connection are dropped.

A connection keeps two routes: its own connection ID, and, on a server,
the Destination Connection ID of the first Initial of the client, which
the client uses until the server answers.

This module ports quinn-proto 0.11.19 (8192ed3) quinn-proto/src/endpoint.rs
(MIT OR Apache-2.0, used under MIT): `handle`, `connect`, the connection
index and the Version Negotiation answer.

Differences from upstream: quinn returns events and `Incoming` values that
the application accepts or refuses. Here a server accepts every valid
Initial, and `accept` gives the new connections in order. No Retry, no
stateless reset and no connection limit.
"""

from std.collections import Dict

from gql_tls.error import TlsError
from gql_quic.cid import ConnectionId
from gql_quic.connection import Connection, MIN_INITIAL_SIZE, TransportConfig
from gql_quic.crypto import Crypto
from gql_quic.packet import (
    LongType,
    PacketHeader,
    QUIC_VERSION_1,
    parse_header,
    write_version_negotiation,
)
from gql_quic.tls import QuicTls
from gql_quic.udp import Peer


struct Endpoint(Movable):
    """The connections of one socket."""

    var is_server: Bool
    """Whether new connections come from Initial packets."""
    var config: TransportConfig
    """The transport settings of new connections."""
    var crypto: Crypto
    """The libcrypto functions."""
    var tls: QuicTls
    """The libssl functions."""
    var ctx: Int
    """The TLS `SSL_CTX` of new connections."""
    var conns: List[Optional[Connection]]
    """The connection slots."""
    var peers: List[Peer]
    """The address of the peer of each slot."""
    var accept_queue: List[Int]
    """The new server connections that wait for `accept`."""
    var replies: List[UInt8]
    """Version Negotiation datagrams to send, one after another."""
    var reply_sizes: List[Int]
    """The size of each datagram of `replies`."""
    var reply_peers: List[Peer]
    """The peer of each datagram of `replies`."""
    var _routes: Dict[ConnectionId, Int]
    var _free: List[Int]

    def __init__(
        out self,
        is_server: Bool,
        var config: TransportConfig,
        crypto: Crypto,
        var tls: QuicTls,
        ctx: Int,
    ):
        """Make an endpoint without connections.

        Args:
            is_server: Whether to accept connections.
            config: The transport settings of the connections.
            crypto: The libcrypto functions.
            tls: The libssl functions.
            ctx: The TLS `SSL_CTX` of the connections.
        """
        self.is_server = is_server
        self.config = config^
        self.crypto = crypto
        self.tls = tls^
        self.ctx = ctx
        self.conns = List[Optional[Connection]]()
        self.peers = List[Peer]()
        self.accept_queue = List[Int]()
        self.replies = List[UInt8]()
        self.reply_sizes = List[Int]()
        self.reply_peers = List[Peer]()
        self._routes = Dict[ConnectionId, Int]()
        self._free = List[Int]()

    def _add(mut self, var conn: Connection, peer: Peer) -> Int:
        """Keep a connection in a slot, with its routes."""
        var cid = conn.local_cid
        var odcid = conn.original_dcid
        var slot = len(self.conns)
        if len(self._free) > 0:
            slot = self._free.pop()
            self.conns[slot] = conn^
            self.peers[slot] = peer
        else:
            self.conns.append(conn^)
            self.peers.append(peer)
        self._routes[cid] = slot
        if self.is_server:
            self._routes[odcid] = slot
        return slot

    def connect(
        mut self, var host: String, verify: Bool, peer: Peer, now: Int
    ) raises TlsError -> Int:
        """Start a client connection.

        Args:
            host: The name of the server, for SNI and verification.
            verify: Whether to check the name.
            peer: The address of the server.
            now: The current time.

        Returns:
            The slot of the connection.

        Raises:
            TlsError: `CONFIG` when libssl cannot make the session.
        """
        var conn = Connection.client(
            self.config.copy(),
            self.crypto,
            self.tls.copy(),
            self.ctx,
            host^,
            verify,
            now,
        )
        return self._add(conn^, peer)

    def handle(
        mut self,
        now: Int,
        data: Pointer[mut=True, UInt8, _],
        size: Int,
        peer: Peer,
    ) -> Int:
        """Give a datagram to its connection, or make one for it.

        Args:
            now: The current time.
            data: The datagram; its bytes change.
            size: Its size.
            peer: Where it came from.

        Returns:
            The slot of the connection that took it, or -1.
        """
        var span = Span(unsafe_ptr=data, length=size)
        var header: PacketHeader
        try:
            header = parse_header(span, 0, self.config.cid_len)
        except:
            return -1
        var route = self._routes.get(header.dcid)
        if route:
            var slot = route.value()
            self.conns[slot].value().handle_datagram(now, data, size)
            return slot
        if not self.is_server or not header.is_long or size < MIN_INITIAL_SIZE:
            return -1
        if not header.is_supported_version():
            if header.version != 0:
                self._negotiate(header.dcid, header.scid, peer)
            return -1
        if header.long_type != LongType.INITIAL:
            return -1
        try:
            var conn = Connection.server(
                self.config.copy(),
                self.crypto,
                self.tls.copy(),
                self.ctx,
                header.dcid,
                header.scid,
                now,
            )
            var slot = self._add(conn^, peer)
            self.accept_queue.append(slot)
            self.conns[slot].value().handle_datagram(now, data, size)
            return slot
        except:
            return -1

    def _negotiate(
        mut self, dcid: ConnectionId, scid: ConnectionId, peer: Peer
    ):
        """Queue a Version Negotiation answer to a long header packet."""
        var start = len(self.replies)
        var versions = List[UInt32]()
        versions.append(QUIC_VERSION_1)
        write_version_negotiation(self.replies, scid, dcid, versions)
        self.reply_sizes.append(len(self.replies) - start)
        self.reply_peers.append(peer)

    def accept(mut self) -> Int:
        """Take the oldest new server connection.

        Returns:
            Its slot, or -1 when none waits.
        """
        if len(self.accept_queue) == 0:
            return -1
        return self.accept_queue.pop(0)

    def remove(mut self, slot: Int):
        """Drop a connection and its routes.

        Args:
            slot: The slot.
        """
        if not self.conns[slot]:
            return
        ref conn = self.conns[slot].value()
        _ = self._routes.pop(conn.local_cid, -1)
        if self.is_server:
            _ = self._routes.pop(conn.original_dcid, -1)
        self.conns[slot] = None
        self._free.append(slot)
        for index in range(len(self.accept_queue)):
            if self.accept_queue[index] == slot:
                _ = self.accept_queue.pop(index)
                break
