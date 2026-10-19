# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""QUIC (RFC 9000) through the QUIC API of the system OpenSSL 3.5.

`Quic` is the table of the QUIC functions of OpenSSL: listeners,
connections and streams. It shares the library of a `gql_tls.OpenSsl`,
so a program that does not use HTTP/3 never needs OpenSSL. An OpenSSL
older than 3.5 has no server API, and `Quic` raises a `LIBRARY` error.

Every object is non-blocking. A listener owns one UDP socket. One call of
`handle_events` on the listener runs the timers and the network I/O of
every connection that it accepted. The caller waits on the socket with
`poll`, at most until `event_timeout_ms`.

`QuicContext` is an `SSL_CTX` for QUIC: a server context has a
certificate, a key and the ALPN protocol `h3`; a client context verifies
the server and offers `h3`.

`Quic.faults` can make one kind of call fail, so that tests reach the
error paths.

This module ports no code. It calls the public API of OpenSSL 3.5, which
is Apache-2.0 licensed; no OpenSSL code is copied. The constants are those
of the OpenSSL 3.5 header `ssl.h`.

Differences from upstream: none; there is no upstream.
"""

from std.ffi import external_call
from std.memory import ArcPointer, stack_allocation

from gql_tls.context import alpn_wire
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import (
    CFunction,
    OpenSsl,
    SSL_VERIFY_NONE,
    SSL_VERIFY_PEER,
)

comptime SSL_ACCEPT_CONNECTION_NO_BLOCK: UInt64 = 1
"""`SSL_accept_connection`: do not wait for a connection."""
comptime SSL_ACCEPT_STREAM_NO_BLOCK: UInt64 = 1
"""`SSL_accept_stream`: do not wait for a stream."""
comptime SSL_STREAM_FLAG_UNI: UInt64 = 1
"""`SSL_new_stream`: a unidirectional stream."""
comptime SSL_STREAM_FLAG_NO_BLOCK: UInt64 = 2
"""`SSL_new_stream`: fail instead of waiting for stream credit."""
comptime SSL_WRITE_FLAG_CONCLUDE: UInt64 = 1
"""`SSL_write_ex2`: end the stream after the bytes."""
comptime SSL_DEFAULT_STREAM_MODE_NONE: UInt32 = 0
"""A connection has no default stream; every stream is accepted."""
comptime SSL_SHUTDOWN_FLAG_RAPID: UInt64 = 1
"""`SSL_shutdown_ex`: close at once, without waiting for the peer."""
comptime SSL_SHUTDOWN_FLAG_NO_BLOCK: UInt64 = 4
"""`SSL_shutdown_ex`: do not wait."""
comptime _SSL_VALUE_CLASS_GENERIC: UInt32 = 0
comptime _SSL_VALUE_EVENT_HANDLING_MODE: UInt32 = 6
comptime _AF_INET: Int32 = 2
comptime _SOCK_DGRAM: Int32 = 2
comptime _SOCK_NONBLOCK: Int32 = 0o4000
comptime _SOCK_CLOEXEC: Int32 = 0o2000000


@fieldwise_init
struct QuicCall(Equatable, ImplicitlyCopyable, Writable):
    """A kind of QUIC call that `QuicFaults` can make fail."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NONE = QuicCall(0)
    """No call: faults are off."""
    comptime SOCKET = QuicCall(1)
    """`socket` of a UDP socket."""
    comptime CTX_NEW = QuicCall(2)
    """`SSL_CTX_new` with a QUIC method."""
    comptime LISTENER = QuicCall(3)
    """`SSL_new_listener` and `SSL_listen`."""
    comptime CONNECTION = QuicCall(4)
    """`SSL_new` and the setup of a client connection."""
    comptime NEW_STREAM = QuicCall(5)
    """`SSL_new_stream`."""
    comptime WRITE = QuicCall(6)
    """`SSL_write_ex2`."""
    comptime READ = QuicCall(7)
    """`SSL_read_ex`."""
    comptime HANDSHAKE = QuicCall(8)
    """`SSL_connect`; a fault is a failure that `SSL_get_error` names."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 8

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write("QuicCall(", self.value, ")")


@fieldwise_init
struct QuicFaults(Copyable, Movable):
    """A plan that makes one kind of QUIC call fail, for tests.

    The first `skip` matching calls run. The next `count` matching calls
    fail. A `count` of -1 fails every later call.
    """

    var call: QuicCall
    """The kind of call to fail, or `QuicCall.NONE`."""
    var skip: Int
    """How many matching calls run before the first failure."""
    var count: Int
    """How many matching calls fail; -1 for no limit."""

    def __init__(out self):
        """Make a plan that fails nothing."""
        self.call = QuicCall.NONE
        self.skip = 0
        self.count = 0

    def take(mut self, call: QuicCall) -> Bool:
        """Decide whether this call fails.

        Args:
            call: The kind of the call that is about to run.

        Returns:
            True when the call must fail.
        """
        if self.call != call or self.count == 0:
            return False
        if self.skip > 0:
            self.skip -= 1
            return False
        if self.count > 0:
            self.count -= 1
        return True


@fieldwise_init
struct ReadResult(ImplicitlyCopyable, Writable):
    """The result of a stream read: a count and a state."""

    var count: Int
    """The count of bytes read."""
    var state: ReadState
    """What the stream does next."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the count and the state.

        Args:
            writer: The destination.
        """
        writer.write(self.count, " ", self.state)


@fieldwise_init
struct ReadState(Equatable, ImplicitlyCopyable, Writable):
    """The state of a stream after a read, as a type."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime DATA = ReadState(0)
    """Bytes arrived; more can follow."""
    comptime WAIT = ReadState(1)
    """No bytes now; more can follow."""
    comptime END = ReadState(2)
    """The peer ended the stream (FIN)."""
    comptime RESET = ReadState(3)
    """The peer reset the stream, or the connection failed."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the states.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the state.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 4] = [
            "data",
            "wait",
            "end",
            "reset",
        ]
        writer.write(materialize[names]()[Int(min(self.value, 3))])


struct Quic(Copyable, Movable):
    """The QUIC functions of OpenSSL 3.5, and a fault plan."""

    var openssl: OpenSsl
    """The library, shared with `gql_tls`."""
    var faults: QuicFaults
    """The plan of calls that fail; empty by default."""
    var _server_method: CFunction[Int]
    var _client_method: CFunction[Int]
    var _ctx_new: CFunction[Int]
    var _new_listener: CFunction[Int]
    var _listen: CFunction[Int32]
    var _accept_connection: CFunction[Int]
    var _accept_stream: CFunction[Int]
    var _new_stream: CFunction[Int]
    var _blocking: CFunction[Int32]
    var _handle_events: CFunction[Int32]
    var _event_timeout: CFunction[Int32]
    var _stream_mode: CFunction[Int32]
    var _read_ex: CFunction[Int32]
    var _write_ex2: CFunction[Int32]
    var _stream_id: CFunction[UInt64]
    var _conclude: CFunction[Int32]
    var _connect: CFunction[Int32]
    var _set_alpn: CFunction[Int32]
    var _shutdown_ex: CFunction[Int32]
    var _close_info: CFunction[Int32]
    var _stream_reset: CFunction[Int32]
    var _init_finished: CFunction[Int32]
    var _set_value: CFunction[Int32]

    def __init__(
        out self,
        var openssl: OpenSsl,
        marker: StaticString = "SSL_new_listener",
    ) raises TlsError:
        """Look up the QUIC functions of a loaded OpenSSL.

        Args:
            openssl: The library.
            marker: The function that marks the QUIC server API; tests
                name one that is missing.

        Raises:
            TlsError: `LIBRARY` when OpenSSL has no QUIC server API, which
                came in OpenSSL 3.5.
        """
        if not openssl.has_function(marker):
            raise TlsError(
                TlsErrorKind.LIBRARY,
                "HTTP/3 needs the QUIC server API of OpenSSL 3.5 or newer;"
                " this OpenSSL is version "
                + hex(openssl.version),
                0,
            )
        self._server_method = openssl.function[Int]("OSSL_QUIC_server_method")
        self._client_method = openssl.function[Int]("OSSL_QUIC_client_method")
        self._ctx_new = openssl.function[Int]("SSL_CTX_new")
        self._new_listener = openssl.function[Int]("SSL_new_listener")
        self._listen = openssl.function[Int32]("SSL_listen")
        self._accept_connection = openssl.function[Int]("SSL_accept_connection")
        self._accept_stream = openssl.function[Int]("SSL_accept_stream")
        self._new_stream = openssl.function[Int]("SSL_new_stream")
        self._blocking = openssl.function[Int32]("SSL_set_blocking_mode")
        self._handle_events = openssl.function[Int32]("SSL_handle_events")
        self._event_timeout = openssl.function[Int32]("SSL_get_event_timeout")
        self._stream_mode = openssl.function[Int32](
            "SSL_set_default_stream_mode"
        )
        self._read_ex = openssl.function[Int32]("SSL_read_ex")
        self._write_ex2 = openssl.function[Int32]("SSL_write_ex2")
        self._stream_id = openssl.function[UInt64]("SSL_get_stream_id")
        self._conclude = openssl.function[Int32]("SSL_stream_conclude")
        self._connect = openssl.function[Int32]("SSL_connect")
        self._set_alpn = openssl.function[Int32]("SSL_set_alpn_protos")
        self._shutdown_ex = openssl.function[Int32]("SSL_shutdown_ex")
        self._close_info = openssl.function[Int32]("SSL_get_conn_close_info")
        self._stream_reset = openssl.function[Int32]("SSL_stream_reset")
        self._init_finished = openssl.function[Int32]("SSL_is_init_finished")
        self._set_value = openssl.function[Int32]("SSL_set_value_uint")
        self.openssl = openssl^
        self.faults = QuicFaults()

    @always_inline
    def _fail(mut self, call: QuicCall) -> Bool:
        """Return True when the fault plan fails this call."""
        if self.faults.call.value == 0:
            return False
        return self.faults.take(call)

    def _explicit(mut self, ssl: Int):
        """Make network I/O happen only in `handle_events`.

        A read or a write then never takes datagrams from the socket, so a
        loop that runs `handle_events`, serves, and sleeps on the socket
        cannot miss a datagram that a read took.
        """
        _ = self._set_value(
            ssl, _SSL_VALUE_CLASS_GENERIC, _SSL_VALUE_EVENT_HANDLING_MODE, 2
        )

    def udp_socket(mut self) -> Int:
        """Open a non-blocking IPv4 UDP socket, closed on exec.

        Returns:
            The descriptor, or -1.
        """
        if self._fail(QuicCall.SOCKET):
            return -1
        return Int(
            external_call["socket", Int32](
                _AF_INET, _SOCK_DGRAM | _SOCK_NONBLOCK | _SOCK_CLOEXEC, 0
            )
        )

    def ctx_new(mut self, server: Bool) -> Int:
        """Make an `SSL_CTX` for QUIC servers or QUIC clients.

        Args:
            server: True for a server context.

        Returns:
            The context, or 0.
        """
        if self._fail(QuicCall.CTX_NEW):
            return 0
        var method = self._server_method() if server else self._client_method()
        return self._ctx_new(method)

    def listener(mut self, ctx: Int, fd: Int) -> Int:
        """Make a non-blocking listener on a bound UDP socket, and start it.

        Args:
            ctx: A server context.
            fd: The socket; the listener does not close it.

        Returns:
            The listener, or 0.
        """
        if self._fail(QuicCall.LISTENER):
            return 0
        var listener = self._new_listener(ctx, UInt64(0))
        _ = self.openssl.set_fd(listener, fd)
        _ = self._blocking(listener, 0)
        self._explicit(listener)
        _ = self._listen(listener)
        return listener

    def accept_connection(mut self, listener: Int) -> Int:
        """Take a new connection of a listener, without waiting.

        Every stream of the connection must then be accepted.

        Args:
            listener: The listener.

        Returns:
            The connection, or 0 when none waits.
        """
        var conn = self._accept_connection(
            listener, SSL_ACCEPT_CONNECTION_NO_BLOCK
        )
        if conn != 0:
            _ = self._stream_mode(conn, SSL_DEFAULT_STREAM_MODE_NONE)
            _ = self._blocking(conn, 0)
            self._explicit(conn)
        return conn

    def accept_stream(mut self, conn: Int) -> Int:
        """Take a stream that the peer opened, without waiting.

        Args:
            conn: The connection.

        Returns:
            The stream, or 0 when none waits.
        """
        return self._accept_stream(conn, SSL_ACCEPT_STREAM_NO_BLOCK)

    def new_stream(mut self, conn: Int, unidirectional: Bool) -> Int:
        """Open a stream, without waiting for stream credit.

        Args:
            conn: The connection.
            unidirectional: True for a stream that only this end writes.

        Returns:
            The stream, or 0 when the peer allows no more streams now.
        """
        if self._fail(QuicCall.NEW_STREAM):
            return 0
        var flags = SSL_STREAM_FLAG_NO_BLOCK
        if unidirectional:
            flags |= SSL_STREAM_FLAG_UNI
        return self._new_stream(conn, flags)

    def client_connection(
        mut self, ctx: Int, fd: Int, var host: String, verify: Bool
    ) -> Int:
        """Make a non-blocking client connection on a connected UDP socket.

        Args:
            ctx: A client context.
            fd: The socket, connected to the server.
            host: The name of the server, for SNI and verification.
            verify: Whether to check the name.

        Returns:
            The connection, or 0.
        """
        if self._fail(QuicCall.CONNECTION):
            return 0
        var conn = self.openssl.ssl_new(ctx)
        _ = self.openssl.set_fd(conn, fd)
        _ = self._blocking(conn, 0)
        # Without a default stream, OpenSSL queues the streams of the
        # server for `accept_stream`, such as its control stream.
        _ = self._stream_mode(conn, SSL_DEFAULT_STREAM_MODE_NONE)
        self._explicit(conn)
        var wire = List[UInt8]()
        wire.append(2)
        wire.append(104)
        wire.append(51)
        _ = self._set_alpn(conn, wire.unsafe_ptr(), UInt32(len(wire)))
        if verify:
            _ = self.openssl.set_host(conn, host^)
        return conn

    def connect(mut self, conn: Int) -> Int32:
        """Go on with the handshake of a client connection.

        Args:
            conn: The connection.

        Returns:
            1 when done, else a value for `OpenSsl.get_error`.
        """
        if self._fail(QuicCall.HANDSHAKE):
            return 0
        return self._connect(conn)

    @staticmethod
    def wants_io(code: Int32) -> Bool:
        """Return True when an `SSL_get_error` code asks to wait for I/O.

        Args:
            code: The code.

        Returns:
            Whether it is `SSL_ERROR_WANT_READ` or `SSL_ERROR_WANT_WRITE`.
        """
        return code == 2 or code == 3

    def handle_events(mut self, ssl: Int):
        """Run the timers and the network I/O of a listener or connection.

        Args:
            ssl: The listener or the client connection.
        """
        _ = self._handle_events(ssl)

    def event_timeout_ms(mut self, ssl: Int) -> Int:
        """Return how soon `handle_events` must run again.

        Args:
            ssl: The listener or the client connection.

        Returns:
            Milliseconds, rounded up; -1 when no timer runs.
        """
        var tv = stack_allocation[2, Int]()
        var infinite = stack_allocation[1, Int32]()
        tv[unsafe_offset=0] = 0
        tv[unsafe_offset=1] = 0
        infinite[unsafe_offset=0] = 1
        _ = self._event_timeout(ssl, tv, infinite)
        if infinite[unsafe_offset=0] != 0:
            return -1
        return tv[unsafe_offset=0] * 1000 + (tv[unsafe_offset=1] + 999) // 1000

    def read(
        mut self, stream: Int, data: Pointer[UInt8, _], size: Int
    ) -> ReadResult:
        """Read bytes of a stream, without waiting.

        Args:
            stream: The stream.
            data: The buffer.
            size: The size of the buffer.

        Returns:
            The count of bytes and the state of the stream.
        """
        if self._fail(QuicCall.READ):
            return ReadResult(0, ReadState.RESET)
        var got = stack_allocation[1, Int]()
        got[unsafe_offset=0] = 0
        var rc = self._read_ex(stream, data, size, got)
        if rc == 1:
            return ReadResult(got[unsafe_offset=0], ReadState.DATA)
        var code = self.openssl.get_error(stream, rc)
        self.openssl.clear_errors()
        if code == 2:
            return ReadResult(0, ReadState.WAIT)
        if code == 6:
            return ReadResult(0, ReadState.END)
        return ReadResult(0, ReadState.RESET)

    def write(
        mut self,
        stream: Int,
        data: Pointer[UInt8, _],
        size: Int,
        conclude: Bool,
    ) -> Int:
        """Write bytes to a stream, and end it after them when asked.

        Args:
            stream: The stream.
            data: The bytes.
            size: The count of bytes.
            conclude: Whether to send FIN after the bytes.

        Returns:
            The count of bytes taken; 0 when the stream has no credit now;
            -1 when the stream failed.
        """
        if self._fail(QuicCall.WRITE):
            return -1
        if size == 0:
            # SSL_write_ex2 sends no FIN without bytes.
            if conclude:
                _ = self._conclude(stream, UInt64(0))
            return 0
        var written = stack_allocation[1, Int]()
        written[unsafe_offset=0] = 0
        var flags = SSL_WRITE_FLAG_CONCLUDE if conclude else UInt64(0)
        var rc = self._write_ex2(stream, data, size, flags, written)
        if rc == 1:
            return written[unsafe_offset=0]
        var code = self.openssl.get_error(stream, rc)
        self.openssl.clear_errors()
        if code == 3:
            return written[unsafe_offset=0]
        return -1

    def stream_id(mut self, stream: Int) -> UInt64:
        """Return the QUIC id of a stream.

        Args:
            stream: The stream.

        Returns:
            The id; bit 0 is the initiator and bit 1 the direction.
        """
        return self._stream_id(stream)

    def close_connection(mut self, conn: Int, code: UInt64):
        """Close a connection at once, without waiting for the peer.

        Args:
            conn: The connection.
            code: The application error code, such as `H3_NO_ERROR`.
        """
        var args = stack_allocation[2, UInt64]()
        args[unsafe_offset=0] = code
        args[unsafe_offset=1] = 0
        _ = self._shutdown_ex(
            conn, SSL_SHUTDOWN_FLAG_RAPID | SSL_SHUTDOWN_FLAG_NO_BLOCK, args, 16
        )
        self.openssl.clear_errors()

    def handshake_done(mut self, conn: Int) -> Bool:
        """Return True when the handshake of a connection has ended.

        Args:
            conn: The connection.

        Returns:
            Whether streams can be opened.
        """
        return self._init_finished(conn) == 1

    def connection_closed(mut self, conn: Int) -> Bool:
        """Return True when a connection has closed, by either end.

        Args:
            conn: The connection.

        Returns:
            Whether it is closed.
        """
        var info = stack_allocation[8, UInt64]()
        return self._close_info(conn, info, 40) == 1

    def reset_stream(mut self, stream: Int, code: UInt64):
        """Abort the sending part of a stream with an error code.

        Args:
            stream: The stream.
            code: The application error code, such as `H3_MESSAGE_ERROR`.
        """
        var args = stack_allocation[1, UInt64]()
        args[unsafe_offset=0] = code
        _ = self._stream_reset(stream, args, 8)
        self.openssl.clear_errors()

    def free(mut self, ssl: Int):
        """Free a listener, a connection or a stream.

        Args:
            ssl: The object; 0 does nothing.
        """
        if ssl != 0:
            self.openssl.ssl_free(ssl)


struct QuicContext(Movable):
    """An OpenSSL `SSL_CTX` for QUIC, with the ALPN protocol `h3`.

    The context frees the `SSL_CTX` when it ends. OpenSSL keeps a context
    alive while a connection uses it.
    """

    var quic: Quic
    """The QUIC functions."""
    var ctx: Int
    """The `SSL_CTX *`."""
    var is_server: Bool
    """Whether the context accepts connections."""
    var verify: Bool
    """Whether a client verifies the server."""
    var alpn: ArcPointer[List[UInt8]]
    """The ALPN list of the server callback, shared with the server, so it
    outlives the context."""

    def __init__(out self, var quic: Quic, is_server: Bool) raises TlsError:
        """Make a context without a certificate.

        Use `server` or `client` instead; this is their first step.

        Args:
            quic: The QUIC functions.
            is_server: True for a server context.

        Raises:
            TlsError: `CONFIG` when OpenSSL cannot make the context.
        """
        self.quic = quic^
        self.is_server = is_server
        self.verify = False
        self.alpn = ArcPointer(List[UInt8]())
        self.ctx = self.quic.ctx_new(is_server)
        if self.ctx == 0:
            raise self._error("SSL_CTX_new failed for QUIC")

    @staticmethod
    def server(
        var quic: Quic, cert_file: String, key_file: String
    ) raises TlsError -> QuicContext:
        """Make a server context with a certificate and a key.

        Args:
            quic: The QUIC functions.
            cert_file: A PEM file with the certificate chain, leaf first.
            key_file: A PEM file with the private key.

        Returns:
            The context; its ALPN protocol is `h3`.

        Raises:
            TlsError: `CONFIG` when a file does not load, or the key does
                not fit the certificate.
        """
        var context = QuicContext(quic^, True)
        ref openssl = context.quic.openssl
        if not openssl.use_certificate_chain(context.ctx, cert_file):
            raise context._error("cannot load the certificate " + cert_file)
        if not openssl.use_private_key(context.ctx, key_file):
            raise context._error("cannot load the private key " + key_file)
        var protocols = List[String]()
        protocols.append("h3")
        context.alpn = ArcPointer(alpn_wire(protocols))
        context.alpn[].append(0)
        openssl.set_alpn_select(context.ctx, context.alpn[])
        return context^

    @staticmethod
    def client(
        var quic: Quic, ca_file: String = "", verify: Bool = True
    ) raises TlsError -> QuicContext:
        """Make a client context that verifies servers.

        Args:
            quic: The QUIC functions.
            ca_file: A PEM file of trusted CA certificates; empty for the
                system CA store.
            verify: Whether to verify the certificate and the host name of
                the server. Turn it off only for tests.

        Returns:
            The context.

        Raises:
            TlsError: `CONFIG` when the trust store does not load.
        """
        var context = QuicContext(quic^, False)
        context.verify = verify
        ref openssl = context.quic.openssl
        if verify:
            if not openssl.use_trust(context.ctx, ca_file):
                raise context._error("cannot load the trust store")
            openssl.set_verify(context.ctx, SSL_VERIFY_PEER)
        else:
            openssl.set_verify(context.ctx, SSL_VERIFY_NONE)
        return context^

    def __deinit__(deinit self):
        """Free the `SSL_CTX`."""
        if self.ctx != 0:
            self.quic.openssl.ctx_free(self.ctx)

    def _error(mut self, message: String) -> TlsError:
        """Make a `CONFIG` error with the text of OpenSSL."""
        var detail = self.quic.openssl.last_error()
        if detail.byte_length() == 0:
            return TlsError(TlsErrorKind.CONFIG, message, 0)
        return TlsError(TlsErrorKind.CONFIG, message + ": " + detail, 0)
