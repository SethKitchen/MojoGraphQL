# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A client and a server `Connection` joined in memory, with a virtual
clock, as `Pair` of quinn-proto 0.11.19 quinn-proto/src/tests/util.rs.

`drive` moves datagrams both ways until neither end has one, then runs
the earliest timer, until both ends are quiet. `drop_client` and
`drop_server` drop the next datagrams of one end, to test loss."""

from _certs import test_certs
from gql_tls.context import TlsContext, TlsVersion
from gql_tls.openssl import OpenSsl
from gql_quic.connection import Connection, TransportConfig
from gql_quic.crypto import Crypto
from gql_quic.packet import parse_header
from gql_quic.shared import Dir
from gql_quic.tls import QuicTls

comptime MS = 1_000_000
"""Nanoseconds in a millisecond."""


def h3() -> List[String]:
    """The ALPN list of the tests."""
    var out = List[String]()
    out.append("h3")
    return out^


struct Pair(Movable):
    """A client and a server in memory."""

    var crypto: Crypto
    var sctx: TlsContext
    var cctx: TlsContext
    var client: Connection
    var server: List[Connection]
    var now: Int
    var drop_client: Int
    var drop_server: Int
    var client_datagrams: Int
    var server_datagrams: Int
    var server_config: TransportConfig
    var _buf: List[UInt8]

    def __init__(
        out self,
        var client_config: TransportConfig = TransportConfig(),
        var server_config: TransportConfig = TransportConfig(),
        verify: Bool = True,
        host: String = "localhost",
    ) raises:
        var certs = test_certs()
        self.crypto = Crypto(OpenSsl())
        self.sctx = TlsContext.server(
            OpenSsl(), certs.cert, certs.key, h3(), TlsVersion.TLS_1_3
        )
        self.cctx = TlsContext.client(
            OpenSsl(), h3(), certs.cert, verify, TlsVersion.TLS_1_3
        )
        self.now = 1000 * MS
        self.client = Connection.client(
            client_config^,
            self.crypto,
            QuicTls(OpenSsl()),
            self.cctx.ctx,
            host,
            verify,
            self.now,
        )
        self.server = List[Connection]()
        self.drop_client = 0
        self.drop_server = 0
        self.client_datagrams = 0
        self.server_datagrams = 0
        self.server_config = server_config^
        self._buf = List[UInt8]()

    def _to_server(mut self) raises:
        """Deliver the datagram in the buffer to the server."""
        if len(self.server) == 0:
            var header = parse_header(self._buf, 0, 8)
            self.server.append(
                Connection.server(
                    self.server_config.copy(),
                    self.crypto,
                    QuicTls(OpenSsl()),
                    self.sctx.ctx,
                    header.dcid,
                    header.scid,
                    self.now,
                )
            )
        self.server[0].handle_datagram(
            self.now, self._buf.unsafe_ptr(), len(self._buf)
        )

    def step(mut self) raises -> Int:
        """Move every waiting datagram once each way; return the count."""
        var moved = 0
        while True:
            self._buf.clear()
            var n = self.client.poll_transmit(self.now, self._buf)
            if n == 0:
                break
            moved += 1
            self.client_datagrams += 1
            if self.drop_client > 0:
                self.drop_client -= 1
                continue
            self._to_server()
        if len(self.server) > 0:
            while True:
                self._buf.clear()
                var n = self.server[0].poll_transmit(self.now, self._buf)
                if n == 0:
                    break
                moved += 1
                self.server_datagrams += 1
                if self.drop_server > 0:
                    self.drop_server -= 1
                    continue
                self.client.handle_datagram(
                    self.now, self._buf.unsafe_ptr(), len(self._buf)
                )
        return moved

    def next_timeout(self) -> Int:
        """Return the earliest timer of both ends, or -1."""
        var t = self.client.poll_timeout()
        if len(self.server) > 0:
            var s = self.server[0].poll_timeout()
            if s >= 0 and (t < 0 or s < t):
                t = s
        return t

    def drive(mut self, horizon_ms: Int = 60_000) raises:
        """Run both ends until they are quiet, or past a horizon."""
        var limit = self.now + horizon_ms * MS
        for _ in range(10000):
            if self.step() > 0:
                continue
            var t = self.next_timeout()
            if t < 0 or t > limit:
                return
            self.now = max(self.now, t)
            self.client.handle_timeout(self.now)
            if len(self.server) > 0:
                self.server[0].handle_timeout(self.now)

    def drive_until_quiet(mut self) raises:
        """Move datagrams until neither end sends, without timers."""
        for _ in range(1000):
            if self.step() == 0:
                return

    def connect(mut self) raises:
        """Run the handshake to the end."""
        for _ in range(100):
            _ = self.step()
            if (
                self.client.is_established()
                and len(self.server) > 0
                and self.server[0].handshake_confirmed
                and self.client.handshake_confirmed
            ):
                self.drive_until_quiet()
                return
            if self.step() == 0:
                var t = self.next_timeout()
                if t < 0:
                    return
                self.now = max(self.now, t)
                self.client.handle_timeout(self.now)
                if len(self.server) > 0:
                    self.server[0].handle_timeout(self.now)
