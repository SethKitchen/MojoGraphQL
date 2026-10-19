# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A poll loop over `Endpoint` and `UdpIo`, with integer handles.

`QuicDriver` gives the same shape of API as the QUIC objects of OpenSSL:
a listener, connections and streams are non-zero `Int` handles, and
network I/O happens only in `handle_events`. Thus `gql_http3` runs over
either stack with one loop.

- `listener(ctx, fd)` serves a bound UDP socket; `accept_connection`
  gives its new connections.
- `client_connection(ctx, fd, host, verify)` starts a client on a
  connected UDP socket; `connect` tells when its handshake ends.
- `new_stream`, `accept_stream`, `read`, `write`, `reset_stream`,
  `stream_id` and `free` act on streams.
- `handle_events(handle)` reads every datagram that waits, runs the
  timers, and sends what the connections of the socket have to send.
  `event_timeout_ms` tells how soon it must run again.

Writes only queue bytes, so a response and its ACK leave in one
datagram when `handle_events` runs.

This module ports the role of the quinn crate 0.11.12 (8192ed3)
quinn/src/endpoint.rs and quinn/src/connection.rs, the drivers that join
quinn-proto to sockets (MIT OR Apache-2.0, used under MIT).

Differences from upstream: quinn is async on tokio; this driver is a poll
loop without threads, and its handles follow the OpenSSL QUIC API.
"""

from std.time import perf_counter_ns

from gql_quic.connection import Connection, TransportConfig
from gql_quic.crypto import Crypto
from gql_quic.endpoint import Endpoint
from gql_quic.shared import Dir
from gql_quic.streams import ReadStatus, StreamRead
from gql_quic.tls import QuicTls
from gql_quic.udp import BATCH, ECONNREFUSED, Peer, SLOT, UdpIo

comptime _KIND_SHIFT = 56
comptime _ENDPOINT = 1
comptime _CONNECTION = 2
comptime _STREAM = 3
comptime _MASK = (1 << 24) - 1


def now_ns() -> Int:
    """Return a monotonic time in nanoseconds.

    Returns:
        The time.
    """
    return Int(perf_counter_ns())


struct _Socket(Movable):
    """A socket, its batched I/O and its endpoint."""

    var io: UdpIo
    var endpoint: Endpoint
    var error: Int

    def __init__(out self, var io: UdpIo, var endpoint: Endpoint):
        self.io = io^
        self.endpoint = endpoint^
        self.error = 0


@fieldwise_init
struct _StreamRef(ImplicitlyCopyable, Movable):
    """Where a stream handle points: a socket, a slot and a stream id."""

    var socket: Int
    var slot: Int
    var id: UInt64


struct QuicDriver(Movable):
    """The sockets, connections and streams of a program, as handles."""

    var crypto: Crypto
    """The libcrypto functions."""
    var tls: QuicTls
    """The libssl functions."""
    var config: TransportConfig
    """The transport settings of new connections."""
    var gso: Bool
    """Whether new sockets try GSO."""
    var _sockets: List[Optional[_Socket]]
    var _streams: List[Optional[_StreamRef]]
    var _free_streams: List[Int]
    var _out: List[UInt8]
    var _sizes: List[Int]
    var _peers: List[Peer]

    def __init__(
        out self,
        crypto: Crypto,
        var tls: QuicTls,
        var config: TransportConfig = TransportConfig(),
    ):
        """Make a driver without sockets.

        Args:
            crypto: The libcrypto functions.
            tls: The libssl functions.
            config: The transport settings of every connection.
        """
        self.crypto = crypto
        self.tls = tls^
        self.config = config^
        self.gso = True
        self._sockets = List[Optional[_Socket]]()
        self._streams = List[Optional[_StreamRef]]()
        self._free_streams = List[Int]()
        self._out = List[UInt8](capacity=BATCH * 1500)
        self._sizes = List[Int]()
        self._peers = List[Peer]()

    # ---- handles ----

    @staticmethod
    def _kind(handle: Int) -> Int:
        """Return the kind of a handle."""
        return handle >> _KIND_SHIFT

    @staticmethod
    def _socket_of(handle: Int) -> Int:
        """Return the socket index of a socket or connection handle."""
        if (handle >> _KIND_SHIFT) == _ENDPOINT:
            return (handle & _MASK) - 1
        return (handle >> 24) & _MASK

    def _add_socket(mut self, var socket: _Socket) -> Int:
        """Keep a socket; return its index."""
        for index in range(len(self._sockets)):
            if not self._sockets[index]:
                self._sockets[index] = socket^
                return index
        self._sockets.append(socket^)
        return len(self._sockets) - 1

    def _has_conn(self, handle: Int) -> Bool:
        """Return True when a connection handle points at a connection."""
        if (handle >> _KIND_SHIFT) != _CONNECTION:
            return False
        var socket = (handle >> 24) & _MASK
        var slot = (handle & _MASK) - 1
        if socket >= len(self._sockets) or not self._sockets[socket]:
            return False
        ref conns = self._sockets[socket].value().endpoint.conns
        return slot >= 0 and slot < len(conns) and Bool(conns[slot])

    def _conn(mut self, handle: Int) -> ref[self] Connection:
        """Return the connection of a valid connection handle."""
        var socket = (handle >> 24) & _MASK
        var slot = (handle & _MASK) - 1
        return Pointer(
            to=self._sockets[socket].value().endpoint.conns[slot].value()
        ).unsafe_origin_cast[origin_of(self)]()[]

    @staticmethod
    def _conn_handle(socket: Int, slot: Int) -> Int:
        """Make the handle of a connection."""
        return (_CONNECTION << _KIND_SHIFT) | (socket << 24) | (slot + 1)

    def _stream(self, handle: Int) -> Optional[_StreamRef]:
        """Return where a stream handle points, if it is valid."""
        var index = (handle & _MASK) - 1
        if (
            (handle >> _KIND_SHIFT) != _STREAM
            or index < 0
            or index >= len(self._streams)
        ):
            return None
        var ref_ = self._streams[index]
        if not ref_:
            return None
        var r = ref_.value()
        var conn = QuicDriver._conn_handle(r.socket, r.slot)
        if not self._has_conn(conn):
            return None
        return r

    def _stream_handle(mut self, socket: Int, slot: Int, id: UInt64) -> Int:
        """Make the handle of a stream."""
        var r = _StreamRef(socket, slot, id)
        var index = len(self._streams)
        if len(self._free_streams) > 0:
            index = self._free_streams.pop()
            self._streams[index] = r^
        else:
            self._streams.append(r^)
        return (_STREAM << _KIND_SHIFT) | (index + 1)

    # ---- sockets and connections ----

    def listener(mut self, ctx: Int, fd: Int) -> Int:
        """Serve a bound UDP socket.

        Args:
            ctx: A server `SSL_CTX` with the certificate and ALPN.
            fd: The socket, non-blocking; the driver does not close it.

        Returns:
            The handle of the listener.
        """
        var endpoint = Endpoint(
            True, self.config.copy(), self.crypto, self.tls.copy(), ctx
        )
        var index = self._add_socket(
            _Socket(UdpIo(fd, False, self.gso), endpoint^)
        )
        return (_ENDPOINT << _KIND_SHIFT) | (index + 1)

    def client_connection(
        mut self, ctx: Int, fd: Int, var host: String, verify: Bool
    ) -> Int:
        """Start a client connection on a connected UDP socket.

        Args:
            ctx: A client `SSL_CTX` with the trust store and ALPN.
            fd: The socket, non-blocking and connected to the server.
            host: The name of the server, for SNI and verification.
            verify: Whether to check the name.

        Returns:
            The handle of the connection, or 0 when libssl failed.
        """
        var endpoint = Endpoint(
            False, self.config.copy(), self.crypto, self.tls.copy(), ctx
        )
        var slot: Int
        try:
            slot = endpoint.connect(host^, verify, Peer(0, 0), now_ns())
        except:
            return 0
        var index = self._add_socket(
            _Socket(UdpIo(fd, True, self.gso), endpoint^)
        )
        return QuicDriver._conn_handle(index, slot)

    def accept_connection(mut self, listener: Int) -> Int:
        """Take a new connection of a listener.

        Args:
            listener: The listener.

        Returns:
            The connection, or 0 when none waits.
        """
        var socket = QuicDriver._socket_of(listener)
        var slot = self._sockets[socket].value().endpoint.accept()
        if slot < 0:
            return 0
        return QuicDriver._conn_handle(socket, slot)

    def connect(mut self, conn: Int) -> Int32:
        """Tell how the handshake of a client connection goes.

        Args:
            conn: The connection.

        Returns:
            1 when it is complete, 0 while it runs, -1 when it failed.
        """
        if not self._has_conn(conn):
            return -1
        ref c = self._conn(conn)
        if c.is_closed():
            return -1
        return 1 if c.handshake_done else 0

    def failure(mut self, conn: Int) -> String:
        """Return why a connection closed or failed.

        Args:
            conn: The connection.

        Returns:
            The reason, such as a failed verification; empty for none.
        """
        if not self._has_conn(conn):
            return String("the connection is gone")
        return self._conn(conn).close_reason.copy()

    def verify_failure(mut self, conn: Int) -> String:
        """Return why the certificate of the server did not verify.

        Args:
            conn: The connection.

        Returns:
            The text of the verification result; empty when it verified.
        """
        if not self._has_conn(conn):
            return String()
        return self._conn(conn).tls.verify_failure()

    def handshake_done(mut self, conn: Int) -> Bool:
        """Return True when the handshake of a connection is complete.

        Args:
            conn: The connection.

        Returns:
            Whether streams can be opened.
        """
        return self._has_conn(conn) and self._conn(conn).handshake_done

    def connection_closed(mut self, conn: Int) -> Bool:
        """Return True when a connection has closed, by either end.

        Args:
            conn: The connection.

        Returns:
            Whether it is closed.
        """
        return not self._has_conn(conn) or self._conn(conn).is_closed()

    def close_connection(mut self, conn: Int, code: UInt64):
        """Close a connection with an application error code.

        The CONNECTION_CLOSE goes out in the next `handle_events`.

        Args:
            conn: The connection.
            code: The code, such as `H3_NO_ERROR`.
        """
        if self._has_conn(conn):
            self._conn(conn).close(now_ns(), code, "")

    # ---- streams ----

    def new_stream(mut self, conn: Int, unidirectional: Bool) -> Int:
        """Open a stream.

        Args:
            conn: The connection.
            unidirectional: True for a stream that only this end writes.

        Returns:
            The stream, or 0 when the peer allows no more streams now.
        """
        if not self._has_conn(conn):
            return 0
        var dir = Dir.UNI if unidirectional else Dir.BI
        var id = self._conn(conn).open(dir)
        if id < 0:
            return 0
        return self._stream_handle(
            (conn >> 24) & _MASK, (conn & _MASK) - 1, UInt64(id)
        )

    def accept_stream(mut self, conn: Int) -> Int:
        """Take a stream that the peer opened.

        Args:
            conn: The connection.

        Returns:
            The stream, or 0 when none waits.
        """
        if not self._has_conn(conn):
            return 0
        var id = self._conn(conn).accept()
        if id < 0:
            return 0
        return self._stream_handle(
            (conn >> 24) & _MASK, (conn & _MASK) - 1, UInt64(id)
        )

    def stream_id(self, stream: Int) -> UInt64:
        """Return the QUIC id of a stream.

        Args:
            stream: The stream.

        Returns:
            The id; bit 0 is the initiator and bit 1 the direction.
        """
        var r = self._stream(stream)
        return r.value().id if r else 0

    def read(
        mut self, stream: Int, data: Pointer[mut=True, UInt8, _], size: Int
    ) -> StreamRead:
        """Read bytes of a stream, without waiting.

        Args:
            stream: The stream.
            data: The buffer.
            size: Its size.

        Returns:
            The count and the state of the stream.
        """
        var r = self._stream(stream)
        if not r:
            return StreamRead(0, ReadStatus.RESET)
        var s = r.value()
        return self._conn(QuicDriver._conn_handle(s.socket, s.slot)).read(
            s.id, data, size
        )

    def write(
        mut self, stream: Int, data: Span[UInt8, _], conclude: Bool
    ) -> Int:
        """Queue bytes of a stream, and end it after them when asked.

        Args:
            stream: The stream.
            data: The bytes.
            conclude: Whether to send FIN after the bytes.

        Returns:
            The count of bytes taken; 0 when the stream has no credit now;
            -1 when the stream or the connection failed.
        """
        var r = self._stream(stream)
        if not r:
            return -1
        var s = r.value()
        return self._conn(QuicDriver._conn_handle(s.socket, s.slot)).write(
            s.id, data, conclude
        )

    def reset_stream(mut self, stream: Int, code: UInt64):
        """Abort the sending part of a stream.

        Args:
            stream: The stream.
            code: The application error code.
        """
        var r = self._stream(stream)
        if r:
            var s = r.value()
            self._conn(QuicDriver._conn_handle(s.socket, s.slot)).reset(
                s.id, code
            )

    def free(mut self, handle: Int):
        """Free a listener, a connection or a stream.

        A freed stream finishes what it sends. A freed client connection
        frees its socket state too.

        Args:
            handle: The handle; 0 does nothing.
        """
        var kind = QuicDriver._kind(handle)
        if kind == _STREAM:
            var r = self._stream(handle)
            if r:
                var s = r.value()
                self._conn(QuicDriver._conn_handle(s.socket, s.slot)).release(
                    s.id
                )
            var index = (handle & _MASK) - 1
            if (
                index >= 0
                and index < len(self._streams)
                and self._streams[index]
            ):
                self._streams[index] = None
                self._free_streams.append(index)
            return
        if kind == _ENDPOINT:
            self._sockets[QuicDriver._socket_of(handle)] = None
            return
        if kind == _CONNECTION and self._has_conn(handle):
            var socket = QuicDriver._socket_of(handle)
            if self._sockets[socket].value().endpoint.is_server:
                self._sockets[socket].value().endpoint.remove(
                    (handle & _MASK) - 1
                )
            else:
                self._sockets[socket] = None

    # ---- events ----

    def handle_events(mut self, handle: Int):
        """Read the datagrams of the socket of a handle, run its timers,
        and send what its connections have to send.

        Args:
            handle: A listener, or a connection.
        """
        var socket = QuicDriver._socket_of(handle)
        if socket >= len(self._sockets) or not self._sockets[socket]:
            return
        var now = now_ns()
        ref s = self._sockets[socket].value()
        while True:
            var count = s.io.recv()
            if count < 0:
                s.error = -count
                if -count == ECONNREFUSED:
                    for slot in range(len(s.endpoint.conns)):
                        if s.endpoint.conns[slot]:
                            ref c = s.endpoint.conns[slot].value()
                            c.state = c.state.DRAINED
                            c.close_reason = String(
                                "the server refused the connection"
                            )
                break
            var base = s.io.data.unsafe_ptr()
            for index in range(count):
                var peer = s.io.peers[index]
                _ = s.endpoint.handle(
                    now,
                    base.unsafe_offset(index * SLOT),
                    s.io.sizes[index],
                    peer,
                )
            if count < BATCH:
                break
        self._out.clear()
        self._sizes.clear()
        self._peers.clear()
        if len(s.endpoint.reply_sizes) > 0:
            self._out.extend(Span(s.endpoint.replies))
            self._sizes.extend(Span(s.endpoint.reply_sizes))
            self._peers.extend(Span(s.endpoint.reply_peers))
            s.endpoint.replies.clear()
            s.endpoint.reply_sizes.clear()
            s.endpoint.reply_peers.clear()
        for slot in range(len(s.endpoint.conns)):
            if not s.endpoint.conns[slot]:
                continue
            ref c = s.endpoint.conns[slot].value()
            c.handle_timeout(now)
            while True:
                if len(self._sizes) >= BATCH:
                    _ = s.io.send(self._out, self._sizes, self._peers)
                    self._out.clear()
                    self._sizes.clear()
                    self._peers.clear()
                var size = c.poll_transmit(now, self._out)
                if size == 0:
                    break
                self._sizes.append(size)
                self._peers.append(s.endpoint.peers[slot])
        if len(self._sizes) > 0:
            _ = s.io.send(self._out, self._sizes, self._peers)

    def event_timeout_ms(mut self, handle: Int) -> Int:
        """Return how soon `handle_events` must run again.

        Args:
            handle: A listener, or a connection.

        Returns:
            Milliseconds, rounded up; -1 when no timer runs.
        """
        var socket = QuicDriver._socket_of(handle)
        if socket >= len(self._sockets) or not self._sockets[socket]:
            return -1
        ref s = self._sockets[socket].value()
        var earliest = -1
        for slot in range(len(s.endpoint.conns)):
            if not s.endpoint.conns[slot]:
                continue
            var t = s.endpoint.conns[slot].value().poll_timeout()
            if t >= 0 and (earliest < 0 or t < earliest):
                earliest = t
        if earliest < 0:
            return -1
        return max(earliest - now_ns() + 999_999, 0) // 1_000_000
