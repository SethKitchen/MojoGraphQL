# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time a QUIC stream echo round trip over localhost UDP.

    mojo build -I . -o .cache/bin/quic_echo bench/gql_quic/echo.mojo
    .cache/bin/quic_echo

`quic/echo-roundtrip-32b`: a `QuicDriver` server in a child process echoes
each bidirectional stream. One client opens the streams one after another
on one connection, after the handshake. On each stream it writes 32 bytes
and FIN, and reads the echo to the end. The number is nanoseconds per
stream. The baseline `bench/baselines/rust-quic/src/bin/echo.rs` runs
quinn and tokio the same way, with the server on another thread.
"""

from std.ffi import external_call
from std.time import perf_counter_ns

from _certs import test_certs
from gql_http.socket import IPv4Address, POLLIN, SIGKILL, Sys
from gql_tls.context import TlsContext, TlsVersion
from gql_tls.openssl import OpenSsl
from gql_quic.connection import TransportConfig
from gql_quic.crypto import Crypto
from gql_quic.driver import QuicDriver
from gql_quic.streams import ReadStatus
from gql_quic.tls import QuicTls

comptime PAYLOAD = 32
"""The bytes of each stream."""
comptime WARMUP = 200
"""The streams before the timing."""
comptime ROUNDS = 5000
"""The timed streams."""
comptime TIMEOUT_MS = 5000
"""The longest wait for one echo."""


def alpn() -> List[String]:
    """Return the ALPN list of the baseline."""
    var out = List[String]()
    out.append("bench")
    return out^


def udp_socket() -> Int:
    """Open a non-blocking IPv4 datagram socket; -1 on failure."""
    # AF_INET, SOCK_DGRAM | SOCK_NONBLOCK | SOCK_CLOEXEC.
    return Int(
        external_call["socket", Int32](
            Int32(2), Int32(2 | 0x800 | 0x80000), Int32(0)
        )
    )


def driver() raises -> QuicDriver:
    """Make a driver on the system OpenSSL."""
    return QuicDriver(Crypto(OpenSsl()), QuicTls(OpenSsl()), TransportConfig())


def wait(mut sys: Sys, mut quic: QuicDriver, handle: Int, fd: Int):
    """Wait for a datagram or a timer of a handle, then run it."""
    var timer = quic.event_timeout_ms(handle)
    var limit = TIMEOUT_MS if timer < 0 else min(timer, TIMEOUT_MS)
    _ = sys.poll(fd, POLLIN, limit)
    quic.handle_events(handle)


struct Echo(Copyable, Movable):
    """A server stream and the bytes that it read."""

    var stream: Int
    """The stream handle."""
    var data: List[UInt8]
    """The bytes that came in."""

    def __init__(out self, stream: Int):
        """Start the echo of a stream."""
        self.stream = stream
        self.data = List[UInt8]()


struct EchoServer(Movable):
    """A listener that echoes every stream of every connection.

    The struct holds the TLS context, so that it outlives every `SSL` that
    the listener makes from it.
    """

    var ctx: TlsContext
    """The server TLS context."""
    var quic: QuicDriver
    """The driver."""
    var listener: Int
    """The listener handle."""
    var fd: Int
    """The UDP socket."""

    def __init__(out self, var ctx: TlsContext, fd: Int) raises:
        """Serve a bound UDP socket."""
        self.ctx = ctx^
        self.quic = driver()
        self.listener = self.quic.listener(self.ctx.ctx, fd)
        self.fd = fd

    def run(mut self):
        """Echo the streams, until the parent kills the process."""
        var sys = Sys()
        var conns = List[Int]()
        var echoes = List[Echo]()
        var buf = List[UInt8](length=65536, fill=0)
        while self.ctx.ctx != 0:
            wait(sys, self.quic, self.listener, self.fd)
            while True:
                var conn = self.quic.accept_connection(self.listener)
                if conn == 0:
                    break
                conns.append(conn)
            for conn in conns:
                while True:
                    var stream = self.quic.accept_stream(conn)
                    if stream == 0:
                        break
                    echoes.append(Echo(stream))
            var index = 0
            var wrote = False
            while index < len(echoes):
                ref echo = echoes[index]
                var status = ReadStatus.DATA
                while status == ReadStatus.DATA:
                    var r = self.quic.read(
                        echo.stream, buf.unsafe_ptr(), len(buf)
                    )
                    status = r.status
                    if status == ReadStatus.DATA:
                        echo.data.extend(Span(buf)[0 : r.count])
                if status == ReadStatus.END:
                    _ = self.quic.write(echo.stream, Span(echo.data), True)
                    self.quic.free(echo.stream)
                    wrote = True
                    _ = echoes.pop(index)
                elif status == ReadStatus.RESET:
                    self.quic.free(echo.stream)
                    _ = echoes.pop(index)
                else:
                    index += 1
            if wrote:
                self.quic.handle_events(self.listener)


def main() raises:
    """Start the server in a child, time the echoes, and stop it."""
    var certs = test_certs()
    var sys = Sys()
    var sctx = TlsContext.server(
        OpenSsl(), certs.cert, certs.key, alpn(), TlsVersion.TLS_1_3
    )
    var sfd = udp_socket()
    _ = sys.bind(sfd, IPv4Address.LOOPBACK, 0)
    var port = sys.local_port(sfd)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            var server = EchoServer(sctx^, sfd)
            server.run()
        except:
            pass
        sys.exit_now(0)
    sys.close(sfd)
    var cctx = TlsContext.client(
        OpenSsl(), alpn(), certs.cert, True, TlsVersion.TLS_1_3
    )
    var client = driver()
    var cfd = udp_socket()
    _ = sys.connect(cfd, IPv4Address.LOOPBACK, port)
    var conn = client.client_connection(cctx.ctx, cfd, "localhost", True)
    var deadline = perf_counter_ns() + TIMEOUT_MS * 1_000_000
    while client.connect(conn) != 1:
        if client.connect(conn) < 0 or perf_counter_ns() > deadline:
            raise Error("the handshake failed: " + client.failure(conn))
        wait(sys, client, conn, cfd)
    var payload = List[UInt8](length=PAYLOAD, fill=UInt8(ord("x")))
    var buf = List[UInt8](length=65536, fill=0)
    var index = 0
    var start = perf_counter_ns()
    while index < WARMUP + ROUNDS:
        if index == WARMUP:
            start = perf_counter_ns()
        var stream = client.new_stream(conn, False)
        while stream == 0:
            wait(sys, client, conn, cfd)
            stream = client.new_stream(conn, False)
        if client.write(stream, Span(payload), True) != PAYLOAD:
            raise Error("the write failed")
        client.handle_events(conn)
        var got = 0
        deadline = perf_counter_ns() + TIMEOUT_MS * 1_000_000
        while True:
            var r = client.read(stream, buf.unsafe_ptr(), len(buf))
            if r.status == ReadStatus.DATA:
                got += r.count
                continue
            if r.status == ReadStatus.END:
                break
            if r.status == ReadStatus.RESET or perf_counter_ns() > deadline:
                raise Error("the echo failed")
            wait(sys, client, conn, cfd)
        if got != PAYLOAD:
            raise Error("the echo is short")
        client.free(stream)
        index += 1
    var elapsed = Int(perf_counter_ns() - start)
    print("BENCH quic/echo-roundtrip-32b", elapsed // ROUNDS)
    client.close_connection(conn, 0)
    client.handle_events(conn)
    client.free(conn)
    sys.close(cfd)
    # The client context must outlive the connection.
    _ = cctx.ctx
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)
