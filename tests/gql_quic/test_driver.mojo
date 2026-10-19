# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.driver`: a client and a server `QuicDriver` over
loopback UDP in one process, turned in one loop. The cases port the quinn
crate 0.11.12 quinn/src/tests.rs: `echo_v4` and `stress_both_windows`
(`run_echo` with small windows), `handshake_timeout`, `read_after_close`,
`close_endpoint` and `stream_id_flow_control`; the driver roles of
quinn/src/endpoint.rs (`accept`, `connect`, the socket loop) give the
cases of handles, refused ports, closed sockets and batches."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _certs import test_certs
from _net import (
    LOOPBACK,
    bound,
    close_fd,
    closed_port,
    connect_to,
    port_of,
    send_raw,
    wait_readable,
)
from _pair import h3
from gql_tls.context import TlsContext, TlsVersion
from gql_tls.openssl import OpenSsl, TlsCall, TlsFaults
from gql_quic.connection import TransportConfig
from gql_quic.crypto import Crypto
from gql_quic.driver import QuicDriver, now_ns
from gql_quic.streams import ReadStatus
from gql_quic.tls import QuicTls
from gql_quic.udp import BATCH, ECONNREFUSED, Peer, UdpIo

comptime MS = 1_000_000
comptime LIMIT = 4000 * MS
"""The longest that a loop of a test turns."""
comptime CONN = 2 << 56
comptime STREAM = 3 << 56
comptime LISTENER = 1 << 56


def make_driver(var config: TransportConfig) raises -> QuicDriver:
    return QuicDriver(Crypto(OpenSsl()), QuicTls(OpenSsl()), config^)


struct Loop(Movable):
    """A server driver with a listener, and a client driver."""

    var sctx: TlsContext
    var cctx: TlsContext
    var server: QuicDriver
    var client: QuicDriver
    var sfd: Int
    var cfd: Int
    var listener: Int
    var conn: Int
    var sconn: Int

    def __init__(
        out self,
        var config: TransportConfig = TransportConfig(),
        host: String = "localhost",
        pin_listener: Bool = False,
    ) raises:
        var certs = test_certs()
        self.sctx = TlsContext.server(
            OpenSsl(), certs.cert, certs.key, h3(), TlsVersion.TLS_1_3
        )
        self.cctx = TlsContext.client(
            OpenSsl(), h3(), certs.cert, True, TlsVersion.TLS_1_3
        )
        self.server = make_driver(config.copy())
        self.client = make_driver(config^)
        self.sfd = bound()
        self.listener = self.server.listener(self.sctx.ctx, self.sfd)
        self.cfd = bound()
        connect_to(self.cfd, port_of(self.sfd))
        if pin_listener:
            # The listener socket takes datagrams of this client only, and
            # gets the ICMP errors of its sends.
            connect_to(self.sfd, port_of(self.cfd))
        self.conn = self.client.client_connection(
            self.cctx.ctx, self.cfd, host, True
        )
        self.sconn = 0

    def close(mut self):
        """Free the handles and close the sockets."""
        self.client.free(self.conn)
        self.server.free(self.listener)
        if self.cfd >= 0:
            close_fd(self.cfd)
        close_fd(self.sfd)

    def pump(mut self):
        """Turn the server, then the client."""
        self.server.handle_events(self.listener)
        if self.sconn == 0:
            self.sconn = self.server.accept_connection(self.listener)
        self.client.handle_events(self.conn)

    def pump_wait(mut self, wait_ms: Int):
        """Turn both, then wait for a datagram of the client or a timer."""
        self.pump()
        wait_readable(self.cfd, wait_ms)

    def handshake(mut self) raises:
        """Turn both until the handshake ends on both."""
        var start = now_ns()
        while self.client.connect(self.conn) != 1 or self.sconn == 0:
            assert_true(self.client.connect(self.conn) >= 0)
            assert_true(now_ns() - start < LIMIT)
            self.pump_wait(1)
        # Let the HANDSHAKE_DONE and its ACK cross.
        for _ in range(5):
            self.pump_wait(1)


def read_some(
    mut driver: QuicDriver, stream: Int, mut out: List[UInt8]
) -> ReadStatus:
    """Read what waits on a stream; return the last status."""
    var buf = List[UInt8](length=16384, fill=0)
    while True:
        var r = driver.read(stream, buf.unsafe_ptr(), len(buf))
        if r.status != ReadStatus.DATA:
            return r.status
        out.extend(Span(buf)[0 : r.count])


def payload(size: Int) -> List[UInt8]:
    """Bytes that differ from one offset to the next."""
    var out = List[UInt8](capacity=size)
    var index = 0
    while index < size:
        out.append(UInt8((index * 7 + index // 251) & 0xFF))
        index += 1
    return out^


struct EchoResult(Movable):
    var data: List[UInt8]
    var partial_writes: Int
    var ns: Int

    def __init__(out self, var data: List[UInt8], partial_writes: Int, ns: Int):
        self.data = data^
        self.partial_writes = partial_writes
        self.ns = ns


def echo(mut loop: Loop, data: List[UInt8]) raises -> EchoResult:
    """As quinn `run_echo`: the client sends `data` with FIN on a new
    bidirectional stream, the server writes back what it reads, and the
    client reads to the end."""
    var start = now_ns()
    var stream = loop.client.new_stream(loop.conn, False)
    assert_true(stream != 0)
    var sent = 0
    var fin = False
    var sstream = 0
    var pending = List[UInt8]()
    var pending_at = 0
    var server_end = False
    var back_fin = False
    var got = List[UInt8]()
    var partial = 0
    while True:
        assert_true(now_ns() - start < LIMIT)
        if not fin:
            var n = loop.client.write(stream, Span(data)[sent:], True)
            assert_true(n >= 0)
            if n < len(data) - sent:
                partial += 1
            sent += n
            fin = sent == len(data)
        loop.client.handle_events(loop.conn)
        loop.server.handle_events(loop.listener)
        if sstream == 0:
            sstream = loop.server.accept_stream(loop.sconn)
        if sstream != 0 and not back_fin:
            if not server_end:
                var status = read_some(loop.server, sstream, pending)
                assert_true(status != ReadStatus.RESET)
                server_end = status == ReadStatus.END
            var left = len(pending) - pending_at
            var n = loop.server.write(
                sstream, Span(pending)[pending_at:], server_end
            )
            assert_true(n >= 0)
            if n < left:
                partial += 1
            pending_at += n
            back_fin = server_end and pending_at == len(pending)
            loop.server.handle_events(loop.listener)
        loop.client.handle_events(loop.conn)
        var status = read_some(loop.client, stream, got)
        assert_true(status != ReadStatus.RESET)
        if status == ReadStatus.END:
            break
    var ns = now_ns() - start
    loop.client.free(stream)
    loop.server.free(sstream)
    return EchoResult(got^, partial, ns)


def quiet(mut loop: Loop, ms: Int):
    """Turn both for a while, so the delayed ACKs go out."""
    var start = now_ns()
    while now_ns() - start < ms * MS:
        loop.pump_wait(1)


def test_echo() raises:
    """As quinn `echo_v4`."""
    var loop = Loop()
    loop.handshake()
    var data = List[UInt8]("hello, quic".as_bytes())
    var first = echo(loop, data)
    assert_equal(String(unsafe_from_utf8=first.data), "hello, quic")
    var best = first.ns
    for _ in range(20):
        var again = echo(loop, data)
        assert_equal(len(again.data), len(data))
        best = min(best, again.ns)
    print("echo round trip:", best // 1000, "us (best of 20)")
    loop.close()


def test_echo_large() raises:
    """As quinn `stress_both_windows`: 200 KB through small windows, so
    writes are partial and flow control turns."""
    var config = TransportConfig()
    config.stream_receive_window = 16384
    config.receive_window = 32768
    var loop = Loop(config^)
    loop.handshake()
    var data = payload(200_000)
    var result = echo(loop, data)
    assert_equal(len(result.data), len(data))
    assert_true(result.data == data)
    assert_true(result.partial_writes > 0)
    print("200 KB echo:", result.ns // 1000, "us")
    loop.close()


def test_invalid_handles() raises:
    var driver = make_driver(TransportConfig())
    var buf = List[UInt8](length=16, fill=0)
    assert_equal(driver.connect(0), -1)
    assert_equal(driver.failure(0), "the connection is gone")
    assert_equal(driver.verify_failure(0), "")
    assert_false(driver.handshake_done(0))
    assert_true(driver.connection_closed(0))
    driver.close_connection(0, 0)
    assert_equal(driver.new_stream(0, False), 0)
    assert_equal(driver.accept_stream(0), 0)
    assert_equal(driver.stream_id(0), 0)
    assert_equal(driver.read(0, buf.unsafe_ptr(), 16).status, ReadStatus.RESET)
    assert_equal(driver.write(0, Span(buf), False), -1)
    driver.reset_stream(0, 0)
    driver.free(0)
    driver.handle_events(LISTENER | 99)
    assert_equal(driver.event_timeout_ms(LISTENER | 99), -1)
    # A connection handle past the sockets.
    assert_true(driver.connection_closed(CONN | (5 << 24) | 1))
    var loop = Loop()
    loop.handshake()
    # Slots below and past the connections of a socket.
    assert_true(loop.client.connection_closed(CONN))
    assert_true(loop.client.connection_closed(CONN | 99))
    # A stream handle of the wrong kind, index 0, and past the streams.
    assert_equal(loop.client.stream_id(loop.conn), 0)
    assert_equal(loop.client.stream_id(STREAM), 0)
    assert_equal(loop.client.stream_id(STREAM | 999), 0)
    loop.client.free(STREAM)
    loop.client.free(STREAM | 999)
    loop.close()


def test_streams() raises:
    """As quinn `read_after_close` and `stream_id_flow_control`, in the
    handle API."""
    var loop = Loop()
    # No stream before the handshake.
    assert_equal(loop.client.new_stream(loop.conn, False), 0)
    loop.handshake()
    assert_equal(loop.server.accept_stream(loop.sconn), 0)
    var uni = loop.client.new_stream(loop.conn, True)
    assert_equal(loop.client.stream_id(uni) & 3, 2)
    var bi = loop.client.new_stream(loop.conn, False)
    assert_equal(loop.client.stream_id(bi) & 3, 0)
    var data = List[UInt8]("partial".as_bytes())
    assert_equal(loop.client.write(bi, Span(data), False), len(data))
    loop.client.reset_stream(bi, 7)
    var sstream = 0
    var start = now_ns()
    var status = ReadStatus.WAIT
    var got = List[UInt8]()
    while status != ReadStatus.RESET:
        assert_true(now_ns() - start < LIMIT)
        loop.pump_wait(1)
        if sstream == 0:
            var s = loop.server.accept_stream(loop.sconn)
            if s != 0 and loop.server.stream_id(s) & 2 == 0:
                sstream = s
            continue
        status = read_some(loop.server, sstream, got)
    # A freed handle is invalid, and its index serves the next stream.
    loop.client.free(bi)
    assert_equal(loop.client.stream_id(bi), 0)
    loop.client.free(bi)
    loop.client.reset_stream(bi, 7)
    var next = loop.client.new_stream(loop.conn, False)
    assert_equal(next, bi)
    # A stream of a freed connection is invalid.
    loop.server.free(loop.sconn)
    assert_equal(loop.server.stream_id(sstream), 0)
    loop.server.free(sstream)
    assert_true(loop.server.connection_closed(loop.sconn))
    loop.server.free(loop.sconn)
    loop.close()


def test_close() raises:
    """As quinn `close_endpoint`: a close reaches the peer."""
    var loop = Loop()
    loop.handshake()
    assert_true(loop.client.handshake_done(loop.conn))
    assert_false(loop.client.connection_closed(loop.conn))
    assert_equal(loop.client.verify_failure(loop.conn), "")
    loop.client.close_connection(loop.conn, 0x100)
    assert_equal(loop.client.connect(loop.conn), -1)
    var start = now_ns()
    while not loop.server.connection_closed(loop.sconn):
        assert_true(now_ns() - start < LIMIT)
        loop.pump_wait(1)
    _ = loop.server.failure(loop.sconn)
    loop.close()


def test_verify_failure() raises:
    """As quinn-proto `reject_self_signed_server_cert`: a name that the
    certificate does not have fails the handshake."""
    var loop = Loop(host="wrong.example")
    var start = now_ns()
    while loop.client.connect(loop.conn) != -1:
        assert_true(now_ns() - start < LIMIT)
        loop.pump_wait(1)
    assert_true(loop.client.verify_failure(loop.conn).byte_length() > 0)
    assert_true(loop.client.failure(loop.conn).byte_length() > 0)
    loop.close()


def test_libssl_failure() raises:
    var certs = test_certs()
    var cctx = TlsContext.client(
        OpenSsl(), h3(), certs.cert, True, TlsVersion.TLS_1_3
    )
    var driver = make_driver(TransportConfig())
    driver.tls.openssl.faults = TlsFaults(TlsCall.SSL_NEW, 0, -1)
    var fd = bound()
    assert_equal(driver.client_connection(cctx.ctx, fd, "localhost", True), 0)
    close_fd(fd)
    _ = cctx.ctx  # The context outlives the driver.


def test_refused() raises:
    """A closed port answers with ICMP: the connection fails at once."""
    var certs = test_certs()
    var cctx = TlsContext.client(
        OpenSsl(), h3(), certs.cert, True, TlsVersion.TLS_1_3
    )
    var driver = make_driver(TransportConfig())
    var fd = bound()
    connect_to(fd, closed_port())
    var conn = driver.client_connection(cctx.ctx, fd, "localhost", True)
    assert_true(conn != 0)
    assert_equal(driver.connect(conn), 0)
    var start = now_ns()
    while driver.connect(conn) != -1:
        assert_true(now_ns() - start < LIMIT)
        driver.handle_events(conn)
        wait_readable(fd, 5)
    assert_equal(driver.failure(conn), "the server refused the connection")
    assert_equal(driver.event_timeout_ms(conn), -1)
    driver.free(conn)
    _ = cctx.ctx  # The context outlives the session.
    close_fd(fd)


def test_handshake_timeout() raises:
    """As quinn `handshake_timeout`: a peer that never answers."""
    var certs = test_certs()
    var cctx = TlsContext.client(
        OpenSsl(), h3(), certs.cert, True, TlsVersion.TLS_1_3
    )
    var config = TransportConfig()
    config.max_idle_timeout_ms = 200
    var driver = make_driver(config^)
    var silent = bound()
    var fd = bound()
    connect_to(fd, port_of(silent))
    var start = now_ns()
    var conn = driver.client_connection(cctx.ctx, fd, "localhost", True)
    while not driver.connection_closed(conn):
        assert_true(now_ns() - start < LIMIT)
        driver.handle_events(conn)
        var wait = driver.event_timeout_ms(conn)
        # -1 once the connection has timed out.
        wait_readable(fd, max(min(wait, 50), 0))
    assert_true(now_ns() - start >= 200 * MS)
    assert_equal(driver.failure(conn), "the connection timed out")
    driver.free(conn)
    _ = cctx.ctx  # The context outlives the session.
    close_fd(fd)
    close_fd(silent)


def test_closed_socket() raises:
    """A closed socket fails each read and send; the driver keeps the
    error and goes on."""
    var loop = Loop()
    close_fd(loop.cfd)
    loop.client.handle_events(loop.conn)
    loop.cfd = -1
    assert_equal(loop.client._sockets[0].value().error, 9)
    assert_equal(loop.client.connect(loop.conn), 0)
    loop.close()


def test_listener_refused() raises:
    """A listener socket that gets an ICMP error keeps its connections;
    only a client fails."""
    var certs = test_certs()
    var sctx = TlsContext.server(
        OpenSsl(), certs.cert, certs.key, h3(), TlsVersion.TLS_1_3
    )
    var driver = make_driver(TransportConfig())
    var fd = bound()
    connect_to(fd, closed_port())
    var listener = driver.listener(sctx.ctx, fd)
    var byte = List[UInt8](length=1, fill=1)
    assert_equal(send_raw(fd, byte), 1)
    driver.handle_events(listener)
    assert_equal(driver._sockets[0].value().error, ECONNREFUSED)
    assert_equal(driver.event_timeout_ms(listener), -1)
    driver.free(listener)
    _ = sctx.ctx  # The context outlives the driver.
    close_fd(fd)
    # A listener with a freed connection.
    var loop = Loop(pin_listener=True)
    loop.handshake()
    loop.server.free(loop.sconn)
    loop.client.free(loop.conn)
    close_fd(loop.cfd)
    loop.cfd = -1
    assert_equal(send_raw(loop.sfd, byte), 1)
    loop.server.handle_events(loop.listener)
    assert_equal(loop.server._sockets[0].value().error, ECONNREFUSED)
    loop.close()


def test_free_and_reuse() raises:
    var loop = Loop()
    loop.handshake()
    # A second listener takes a new socket; a freed one leaves a hole
    # that the next socket fills.
    var fd = bound()
    var second = loop.server.listener(loop.sctx.ctx, fd)
    assert_true(second != loop.listener)
    loop.server.free(second)
    loop.server.handle_events(second)
    assert_equal(loop.server.event_timeout_ms(second), -1)
    var third = loop.server.listener(loop.sctx.ctx, fd)
    assert_equal(third, second)
    loop.server.free(third)
    close_fd(fd)
    # A freed client connection frees its socket.
    loop.client.free(loop.conn)
    loop.client.handle_events(loop.conn)
    assert_true(loop.client.connection_closed(loop.conn))
    loop.close()


def test_batches() raises:
    """33 datagrams of an unknown version: the listener reads them in two
    batches, and its 33 answers leave in two sends."""
    var loop = Loop()
    loop.handshake()
    quiet(loop, 30)
    var raw = bound()
    connect_to(raw, port_of(loop.sfd))
    var packet = List[UInt8](length=1200, fill=0)
    packet[0] = 0xC0
    packet[1] = 0x0A
    packet[2] = 0x1A
    packet[3] = 0x2A
    packet[4] = 0x3A
    packet[5] = 8
    packet[14] = 8
    for _ in range(BATCH + 1):
        assert_equal(send_raw(raw, packet), 1200)
    loop.server.handle_events(loop.listener)
    var io = UdpIo(raw, True)
    var got = 0
    var turns = 0
    while got < BATCH + 1 and turns < 50:
        var n = io.recv()
        if n == 0:
            wait_readable(raw, 20)
            turns += 1
        got += n
    assert_equal(got, BATCH + 1)
    close_fd(raw)
    loop.close()


def test_event_timeout() raises:
    """The timer of a listener is the earliest of its connections."""
    var loop = Loop()
    assert_equal(loop.server.event_timeout_ms(loop.listener), -1)
    loop.handshake()
    var extra = List[Int]()
    var fds = List[Int]()
    var sconns = List[Int]()
    for _ in range(3):
        var fd = bound()
        connect_to(fd, port_of(loop.sfd))
        var conn = loop.client.client_connection(
            loop.cctx.ctx, fd, "localhost", True
        )
        var start = now_ns()
        var sconn = 0
        while loop.client.connect(conn) != 1 or sconn == 0:
            assert_true(now_ns() - start < LIMIT)
            loop.server.handle_events(loop.listener)
            if sconn == 0:
                sconn = loop.server.accept_connection(loop.listener)
            loop.client.handle_events(conn)
            wait_readable(fd, 1)
        extra.append(conn)
        fds.append(fd)
        sconns.append(sconn)
    # Slots: 0 the first connection, 1 to 3 the others; 3 is freed.
    loop.server.free(sconns[2])
    # Turn until slots 0 and 2 wait only for their idle timeouts of 30 s:
    # no ACK is delayed and no packet is in flight.
    var start = now_ns()
    while (
        loop.server._conn(loop.sconn).poll_timeout() - now_ns() < 5000 * MS
        or loop.server._conn(sconns[1]).poll_timeout() - now_ns() < 5000 * MS
    ):
        assert_true(now_ns() - start < LIMIT)
        loop.pump_wait(1)
        for index in range(len(extra)):
            loop.client.handle_events(extra[index])
    # Slot 1 closes: its deadline is a few probe timeouts away, before
    # the idle timeouts of slots 0 and 2.
    loop.server.close_connection(sconns[0], 0)
    var ms = loop.server.event_timeout_ms(loop.listener)
    assert_true(ms >= 0)
    assert_true(ms < 5000)
    for index in range(len(extra)):
        loop.client.free(extra[index])
        close_fd(fds[index])
    loop.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
