# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The TLS 1.3 handshake of QUIC (RFC 9001 section 4) through libssl.

OpenSSL 3.5 lets a QUIC stack of its own run the handshake of libssl:
`SSL_set_quic_tls_cbs` replaces the TLS record layer with callbacks. libssl
gives the handshake bytes to send at each encryption level, takes the
bytes that arrived in CRYPTO frames, and yields each traffic secret.

`TlsSession` owns one `SSL` object and a `_Bridge` on the heap, whose
address the callbacks get. The callbacks only queue: the bytes to send at
each level, the secrets, the transport parameters of the peer and the
alert. The connection reads the queues after each `advance`. So the
handshake is sans-I/O, like the rest of `gql_quic`.

- `feed(level, data)` adds CRYPTO bytes that arrived in order.
- `advance()` runs `SSL_do_handshake`, or `SSL_read_ex` after the
  handshake, for messages such as NewSessionTicket.
- `take_send(level)` and `take_secrets()` empty the queues.

The context is an ordinary TLS `SSL_CTX` from `gql_tls.TlsContext`, with
the certificate, the trust store and the ALPN protocols. libssl sets the
oldest version to TLS 1.3 itself.

This module ports the role of quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/crypto.rs `Session` and quinn-proto/src/crypto/rustls.rs
`TlsSession` (MIT OR Apache-2.0, used under MIT): `read_handshake`,
`write_handshake`, the keys of each level and the transport parameters.
The OpenSSL API is Apache-2.0 licensed; no OpenSSL code is copied. The
constants are those of the OpenSSL 3.5 headers `core_dispatch.h` and
`ssl.h`.

Differences from upstream: quinn's `write_handshake` returns the keys of
the next level when they are ready. Here the secrets come out of
`take_secrets`, and `gql_quic.crypto` derives the keys. 0-RTT is not
offered.
"""

from std.memory import ArcPointer, stack_allocation

from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import CFunction, OpenSsl, X509_V_OK
from gql_quic.crypto import CipherSuite

comptime _CRYPTO_SEND = 2001
comptime _CRYPTO_RECV_RCD = 2002
comptime _CRYPTO_RELEASE_RCD = 2003
comptime _YIELD_SECRET = 2004
comptime _GOT_TRANSPORT_PARAMS = 2005
comptime _ALERT = 2006


@fieldwise_init
struct Level(Equatable, ImplicitlyCopyable, Writable):
    """A TLS encryption level, numbered as in OpenSSL."""

    var value: UInt8
    """The level's index; see `is_valid`."""

    comptime INITIAL = Level(0)
    """No TLS protection: Initial packets."""
    comptime EARLY = Level(1)
    """Early data: 0-RTT packets."""
    comptime HANDSHAKE = Level(2)
    """Handshake packets."""
    comptime APPLICATION = Level(3)
    """1-RTT packets."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the levels.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the level.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 5] = [
            "initial",
            "early",
            "handshake",
            "application",
            "invalid",
        ]
        writer.write(materialize[names]()[Int(min(self.value, 4))])


@fieldwise_init
struct Secret(Copyable, Movable):
    """A traffic secret that libssl yielded."""

    var level: Level
    """The level that it protects."""
    var write: Bool
    """True for the secret of what this end sends."""
    var secret: List[UInt8]
    """The secret."""


struct _Bridge(Movable):
    """The queues between the callbacks and the session, at a fixed
    address on the heap."""

    var send: List[List[UInt8]]
    var write_level: Int
    var recv: List[List[UInt8]]
    var recv_at: List[Int]
    var pending: List[List[UInt8]]
    var read_level: Int
    var lent: Int
    var lent_level: Int
    var secrets: List[Secret]
    var peer_params: List[UInt8]
    var has_peer_params: Bool
    var alert: Int
    var params: List[UInt8]
    var dispatch: List[Int]

    def __init__(out self, var params: List[UInt8]):
        self.send = List[List[UInt8]]()
        self.recv = List[List[UInt8]]()
        self.pending = List[List[UInt8]]()
        self.recv_at = List[Int](length=4, fill=0)
        while len(self.send) < 4:
            self.send.append(List[UInt8]())
            self.recv.append(List[UInt8]())
            self.pending.append(List[UInt8]())
        self.write_level = 0
        self.read_level = 0
        self.lent = -1
        self.lent_level = 0
        self.secrets = List[Secret]()
        self.peer_params = List[UInt8]()
        self.has_peer_params = False
        self.alert = -1
        self.params = params^
        self.dispatch = List[Int](length=14, fill=0)


@always_inline
def _bridge(arg: Int) -> Pointer[_Bridge, MutUntrackedOrigin]:
    """Return the bridge at the address that a callback got."""
    return Pointer[_Bridge, MutUntrackedOrigin](unsafe_from_address=arg)


@always_inline
def _bytes(address: Int, size: Int) -> Span[UInt8, MutUntrackedOrigin]:
    """Return the bytes at an address."""
    return Span(
        unsafe_ptr=Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=address
        ),
        length=size,
    )


def _crypto_send(
    ssl: Int, buf: Int, size: Int, consumed: Int, arg: Int
) abi("C") -> Int32:
    """Queue handshake bytes at the current write level."""
    var b = _bridge(arg)
    b[].send[b[].write_level].extend(_bytes(buf, size))
    Pointer[Int, MutUntrackedOrigin](unsafe_from_address=consumed)[] = size
    return 1


def _crypto_recv_rcd(
    ssl: Int, buf: Int, bytes_read: Int, arg: Int
) abi("C") -> Int32:
    """Lend libssl every byte that waits at the current read level."""
    var b = _bridge(arg)
    var level = b[].read_level
    var at = b[].recv_at[level]
    var size = len(b[].recv[level]) - at
    var out = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=buf)
    var count = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=bytes_read)
    count[] = size
    out[] = Int(b[].recv[level].unsafe_ptr()) + at
    if size > 0:
        b[].lent = size
        b[].lent_level = level
    return 1


def _crypto_release_rcd(ssl: Int, size: Int, arg: Int) abi("C") -> Int32:
    """Drop the bytes that libssl has read, and take the ones that came
    while they were lent."""
    var b = _bridge(arg)
    var level = b[].lent_level
    b[].lent = -1
    b[].recv_at[level] += size
    if b[].recv_at[level] >= len(b[].recv[level]):
        b[].recv[level].clear()
        b[].recv_at[level] = 0
    b[].recv[level].extend(Span(b[].pending[level]))
    b[].pending[level].clear()
    return 1


def _yield_secret(
    ssl: Int, level: UInt32, direction: Int32, secret: Int, size: Int, arg: Int
) abi("C") -> Int32:
    """Queue a secret, and move the read or the write level."""
    var b = _bridge(arg)
    var write = direction == 1
    if write:
        b[].write_level = Int(level)
    else:
        b[].read_level = Int(level)
    b[].secrets.append(
        Secret(Level(UInt8(level)), write, List[UInt8](_bytes(secret, size)))
    )
    return 1


def _got_transport_params(
    ssl: Int, params: Int, size: Int, arg: Int
) abi("C") -> Int32:
    """Keep the transport parameters of the peer."""
    var b = _bridge(arg)
    b[].peer_params = List[UInt8](_bytes(params, size))
    b[].has_peer_params = True
    return 1


def _alert(ssl: Int, code: UInt8, arg: Int) abi("C") -> Int32:
    """Keep the alert that libssl sends; QUIC carries it as an error code."""
    _bridge(arg)[].alert = Int(code)
    return 1


struct QuicTls(Copyable, Movable):
    """The functions of the third-party QUIC API of libssl 3.5."""

    var openssl: OpenSsl
    """The library, shared with `gql_tls`."""
    var _set_cbs: CFunction[Int32]
    var _set_params: CFunction[Int32]
    var _cipher: CFunction[Int]
    var _cipher_id: CFunction[UInt16]
    var _read_ex: CFunction[Int32]

    def __init__(
        out self,
        var openssl: OpenSsl,
        marker: StaticString = "SSL_set_quic_tls_cbs",
    ) raises TlsError:
        """Look up the functions in a loaded OpenSSL.

        Args:
            openssl: The library.
            marker: The function that marks the API; tests name one that is
                missing.

        Raises:
            TlsError: `LIBRARY` when libssl has no third-party QUIC API,
                which came in OpenSSL 3.5.
        """
        if not openssl.has_function(marker):
            raise TlsError(
                TlsErrorKind.LIBRARY,
                "gql_quic needs the QUIC TLS API of OpenSSL 3.5 or newer;"
                " this OpenSSL is version "
                + hex(openssl.version),
                0,
            )
        self._set_cbs = openssl.function[Int32]("SSL_set_quic_tls_cbs")
        self._set_params = openssl.function[Int32](
            "SSL_set_quic_tls_transport_params"
        )
        self._cipher = openssl.function[Int]("SSL_get_current_cipher")
        self._cipher_id = openssl.function[UInt16]("SSL_CIPHER_get_protocol_id")
        self._read_ex = openssl.function[Int32]("SSL_read_ex")
        self.openssl = openssl^


struct TlsSession(Movable):
    """One TLS handshake of a QUIC connection."""

    var tls: QuicTls
    """The functions, and the fault plan of `tls.openssl`."""
    var ssl: Int
    """The `SSL *`."""
    var is_server: Bool
    """Whether this end is the server."""
    var done: Bool
    """Whether the handshake has ended."""
    var _bridge: ArcPointer[_Bridge]

    def __init__(
        out self,
        var tls: QuicTls,
        ctx: Int,
        is_server: Bool,
        var host: String,
        verify: Bool,
        var params: List[UInt8],
    ) raises TlsError:
        """Start a handshake.

        Args:
            tls: The functions.
            ctx: A TLS `SSL_CTX` from `gql_tls.TlsContext`, with the
                certificate or the trust store and the ALPN protocols.
            is_server: True for the server end.
            host: The name of the server, for SNI and verification; a
                server ignores it.
            verify: Whether a client checks the name.
            params: The encoded transport parameters of this end.

        Raises:
            TlsError: `CONFIG` when libssl cannot make the `SSL` object or
                refuses the callbacks.
        """
        self.tls = tls^
        self.is_server = is_server
        self.done = False
        self._bridge = ArcPointer(_Bridge(params^))
        self.ssl = self.tls.openssl.ssl_new(ctx)
        if self.ssl == 0:
            raise TlsError(
                TlsErrorKind.CONFIG, "cannot make a QUIC TLS session", 0
            )
        if is_server:
            self.tls.openssl.set_accept_state(self.ssl)
        else:
            self.tls.openssl.set_connect_state(self.ssl)
            if verify:
                _ = self.tls.openssl.set_host(self.ssl, host^)
        ref d = self._bridge[].dispatch
        var send = _crypto_send
        var recv = _crypto_recv_rcd
        var release = _crypto_release_rcd
        var secret = _yield_secret
        var got = _got_transport_params
        var alert = _alert
        d[0] = _CRYPTO_SEND
        d[1] = Pointer(to=send).unsafe_bitcast[Int]()[]
        d[2] = _CRYPTO_RECV_RCD
        d[3] = Pointer(to=recv).unsafe_bitcast[Int]()[]
        d[4] = _CRYPTO_RELEASE_RCD
        d[5] = Pointer(to=release).unsafe_bitcast[Int]()[]
        d[6] = _YIELD_SECRET
        d[7] = Pointer(to=secret).unsafe_bitcast[Int]()[]
        d[8] = _GOT_TRANSPORT_PARAMS
        d[9] = Pointer(to=got).unsafe_bitcast[Int]()[]
        d[10] = _ALERT
        d[11] = Pointer(to=alert).unsafe_bitcast[Int]()[]
        var arg = Int(Pointer(to=self._bridge[]))
        var ok = self.tls._set_cbs(self.ssl, Int(d.unsafe_ptr()), arg)
        ref p = self._bridge[].params
        ok &= self.tls._set_params(self.ssl, Int(p.unsafe_ptr()), len(p))
        if ok != 1:
            raise TlsError(
                TlsErrorKind.CONFIG,
                "libssl refused the QUIC TLS callbacks: "
                + self.tls.openssl.last_error(),
                0,
            )

    def __deinit__(deinit self):
        """Free the `SSL` object."""
        if self.ssl != 0:
            self.tls.openssl.ssl_free(self.ssl)

    def feed(mut self, level: Level, data: Span[UInt8, _]):
        """Add CRYPTO bytes of a level that arrived in order.

        Args:
            level: The level of the packets that carried them.
            data: The bytes, next after the ones fed before.
        """
        ref b = self._bridge[]
        var index = Int(level.value)
        if b.lent >= 0 and b.lent_level == index:
            b.pending[index].extend(data)
        else:
            b.recv[index].extend(data)

    def advance(mut self) -> Bool:
        """Run the handshake as far as the fed bytes allow.

        After the handshake, read the messages that come later, such as
        NewSessionTicket.

        Returns:
            False when the handshake failed; `alert` then tells why.
        """
        ref openssl = self.tls.openssl
        if not self.done:
            var rc = openssl.handshake(self.ssl)
            if rc == 1:
                self.done = True
                return True
            var code = openssl.get_error(self.ssl, rc)
            openssl.clear_errors()
            return code == 2
        var got = stack_allocation[1, Int]()
        var byte = stack_allocation[1, UInt8]()
        var rc = self.tls._read_ex(self.ssl, Int(byte), 0, Int(got))
        if rc == 1:
            return True
        var code = openssl.get_error(self.ssl, rc)
        openssl.clear_errors()
        return code == 2

    def take_send(mut self, level: Level) -> List[UInt8]:
        """Take the handshake bytes to send at a level.

        Args:
            level: The level.

        Returns:
            The bytes, in order; empty when none wait.
        """
        var out = List[UInt8]()
        swap(out, self._bridge[].send[Int(level.value)])
        return out^

    def has_send(self) -> Bool:
        """Return True when handshake bytes wait at some level.

        Returns:
            Whether `take_send` has bytes for a level.
        """
        ref b = self._bridge[]
        var index = 0
        while index < 4:
            if len(b.send[index]) > 0:
                return True
            index += 1
        return False

    def take_secrets(mut self) -> List[Secret]:
        """Take the secrets that libssl yielded, in order.

        Returns:
            The secrets; empty when none came.
        """
        var out = List[Secret]()
        swap(out, self._bridge[].secrets)
        return out^

    def has_peer_params(self) -> Bool:
        """Return True once the transport parameters of the peer came.

        Returns:
            Whether `peer_params` holds them.
        """
        return self._bridge[].has_peer_params

    def peer_params(self) -> List[UInt8]:
        """Return the encoded transport parameters of the peer.

        Returns:
            The bytes; empty before they came.
        """
        return self._bridge[].peer_params.copy()

    def alert(self) -> Int:
        """Return the TLS alert that this end sent, or -1.

        Returns:
            The alert; QUIC sends it as the error `0x100 + alert`.
        """
        return self._bridge[].alert

    def cipher_suite(mut self) -> CipherSuite:
        """Return the negotiated cipher suite.

        Returns:
            The suite, known once a handshake secret came.
        """
        var cipher = self.tls._cipher(self.ssl)
        return CipherSuite(self.tls._cipher_id(cipher))

    def alpn(mut self) -> String:
        """Return the negotiated ALPN protocol.

        Returns:
            The protocol, such as `h3`; empty without one.
        """
        return self.tls.openssl.alpn_selected(self.ssl)

    def verify_failure(mut self) -> String:
        """Return why the certificate of the peer did not verify.

        Returns:
            The text of the verification result; empty when it verified.
        """
        var verdict = self.tls.openssl.verify_result(self.ssl)
        if verdict == X509_V_OK:
            return String()
        return self.tls.openssl.verify_text(verdict)
