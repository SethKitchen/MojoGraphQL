# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""TLS contexts: the certificate, the key, the trust store and ALPN.

A server context has a certificate chain and a private key from PEM files,
and the ALPN protocols that it accepts, in order of preference. A client
context verifies the server against the system CA store, or a PEM file of
CA certificates, and offers its ALPN protocols. Each `TlsStream` of a
client also checks the host name of the server.

The oldest protocol version is TLS 1.2 by default; `TlsVersion.TLS_1_3`
allows only TLS 1.3. OpenSSL negotiates TLS 1.3 when both peers can.

This module ports no code. The behavior follows RFC 8446, RFC 7301 and
RFC 6125 through OpenSSL.

Differences from upstream: none; there is no upstream.
"""

from std.memory import ArcPointer

from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import (
    OpenSsl,
    SSL_CTRL_MODE,
    SSL_CTRL_SET_MIN_PROTO_VERSION,
    SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER,
    SSL_MODE_ENABLE_PARTIAL_WRITE,
    SSL_OP_IGNORE_UNEXPECTED_EOF,
    SSL_OP_NO_RENEGOTIATION,
    SSL_VERIFY_NONE,
    SSL_VERIFY_PEER,
    TLS1_2_VERSION,
    TLS1_3_VERSION,
)


@fieldwise_init
struct TlsVersion(Equatable, ImplicitlyCopyable, Writable):
    """A TLS protocol version, as a type and not a bare integer."""

    var value: UInt8
    """The version's index; see `is_valid`."""

    comptime TLS_1_2 = TlsVersion(0)
    """TLS 1.2 (RFC 5246)."""
    comptime TLS_1_3 = TlsVersion(1)
    """TLS 1.3 (RFC 8446)."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the versions.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1

    def number(self) -> Int:
        """Return the protocol number of the version.

        Returns:
            `0x0303` for TLS 1.2, `0x0304` for TLS 1.3.
        """
        return TLS1_3_VERSION if self.value == 1 else TLS1_2_VERSION

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the version.

        Args:
            writer: The destination.
        """
        writer.write("TLS 1.3" if self.value == 1 else "TLS 1.2")


def alpn_wire(protocols: List[String]) raises TlsError -> List[UInt8]:
    """Encode ALPN protocols: each with a length byte before it.

    Args:
        protocols: The protocols, such as `h2` and `http/1.1`.

    Returns:
        The protocol list of RFC 7301 section 3.1.

    Raises:
        TlsError: `USAGE` for an empty protocol or one over 255 bytes.
    """
    var wire = List[UInt8]()
    var index = 0
    while index < len(protocols):
        var size = protocols[index].byte_length()
        if size == 0 or size > 255:
            raise TlsError(
                TlsErrorKind.USAGE,
                "an ALPN protocol has 1 to 255 bytes",
                0,
            )
        wire.append(UInt8(size))
        wire.extend(protocols[index].as_bytes())
        index += 1
    return wire^


def default_protocols() -> List[String]:
    """Return the ALPN protocols of a server, in order of preference.

    Returns:
        `h2`, then `http/1.1`.
    """
    var protocols = List[String]()
    protocols.append("h2")
    protocols.append("http/1.1")
    return protocols^


struct TlsContext(Movable):
    """An OpenSSL `SSL_CTX`: the settings of many TLS connections.

    The context frees the `SSL_CTX` when it ends. A `TlsStream` keeps its
    own reference to OpenSSL, so it can outlive the context.
    """

    var openssl: OpenSsl
    """The library, and the fault plan of the calls of this context."""
    var ctx: Int
    """The `SSL_CTX *`."""
    var is_server: Bool
    """Whether the context accepts connections."""
    var verify: Bool
    """Whether a client verifies the server."""
    var protocols: List[String]
    """The ALPN protocols, in order of preference."""
    var alpn: ArcPointer[List[UInt8]]
    """The ALPN list in wire form. Each stream keeps a reference, because
    the ALPN callback of the `SSL_CTX` reads it after the context ends."""

    def __init__(
        out self,
        var openssl: OpenSsl,
        is_server: Bool,
        min_version: TlsVersion,
    ) raises TlsError:
        """Make a context without a certificate and without ALPN.

        Use `server` or `client` instead; this is their first step.

        Args:
            openssl: The library.
            is_server: True for a server context.
            min_version: The oldest protocol version to accept.

        Raises:
            TlsError: `CONFIG` when OpenSSL refuses a setting.
        """
        self.openssl = openssl^
        self.ctx = 0
        self.is_server = is_server
        self.verify = False
        self.protocols = List[String]()
        self.alpn = ArcPointer(List[UInt8]())
        self.ctx = self.openssl.ctx_new(is_server)
        if self.ctx == 0:
            raise self._error("SSL_CTX_new failed")
        var version = self.openssl.ctx_ctrl(
            self.ctx, SSL_CTRL_SET_MIN_PROTO_VERSION, min_version.number()
        )
        if version != 1:
            raise self._error("cannot set the oldest TLS version")
        self.openssl.set_options(
            self.ctx, SSL_OP_IGNORE_UNEXPECTED_EOF | SSL_OP_NO_RENEGOTIATION
        )
        _ = self.openssl.ctx_ctrl(
            self.ctx,
            SSL_CTRL_MODE,
            SSL_MODE_ENABLE_PARTIAL_WRITE | SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER,
        )

    @staticmethod
    def server(
        var openssl: OpenSsl,
        cert_file: String,
        key_file: String,
        var protocols: List[String] = default_protocols(),
        min_version: TlsVersion = TlsVersion.TLS_1_2,
    ) raises TlsError -> TlsContext:
        """Make a server context with a certificate and a key.

        Args:
            openssl: The library.
            cert_file: A PEM file with the certificate chain, leaf first.
            key_file: A PEM file with the private key.
            protocols: The ALPN protocols that the server accepts, in
                order of preference. Empty turns ALPN off.
            min_version: The oldest protocol version to accept.

        Returns:
            The context.

        Raises:
            TlsError: `CONFIG` when a file does not load, or the key does
                not fit the certificate; `USAGE` for a bad protocol.
        """
        var context = TlsContext(openssl^, True, min_version)
        if not context.openssl.use_certificate_chain(context.ctx, cert_file):
            raise context._error("cannot load the certificate " + cert_file)
        if not context.openssl.use_private_key(context.ctx, key_file):
            raise context._error("cannot load the private key " + key_file)
        if len(protocols) > 0:
            context.alpn = ArcPointer(alpn_wire(protocols))
            context.alpn[].append(0)
            context.openssl.set_alpn_select(context.ctx, context.alpn[])
        context.protocols = protocols^
        return context^

    @staticmethod
    def client(
        var openssl: OpenSsl,
        var protocols: List[String] = default_protocols(),
        ca_file: String = "",
        verify: Bool = True,
        min_version: TlsVersion = TlsVersion.TLS_1_2,
    ) raises TlsError -> TlsContext:
        """Make a client context that verifies servers.

        Args:
            openssl: The library.
            protocols: The ALPN protocols that the client offers, in
                order of preference. Empty turns ALPN off.
            ca_file: A PEM file of trusted CA certificates; empty for the
                system CA store.
            verify: Whether to verify the certificate and the host name of
                the server. Turn it off only for tests.
            min_version: The oldest protocol version to accept.

        Returns:
            The context.

        Raises:
            TlsError: `CONFIG` when the trust store does not load, or
                OpenSSL refuses the protocols; `USAGE` for a bad protocol.
        """
        var context = TlsContext(openssl^, False, min_version)
        context.verify = verify
        if verify:
            if not context.openssl.use_trust(context.ctx, ca_file):
                raise context._error("cannot load the trust store")
            context.openssl.set_verify(context.ctx, SSL_VERIFY_PEER)
        else:
            context.openssl.set_verify(context.ctx, SSL_VERIFY_NONE)
        if len(protocols) > 0:
            context.alpn = ArcPointer(alpn_wire(protocols))
            if not context.openssl.set_alpn_protocols(
                context.ctx, context.alpn[]
            ):
                raise context._error("cannot set the ALPN protocols")
        context.protocols = protocols^
        return context^

    def __deinit__(deinit self):
        """Free the `SSL_CTX`."""
        if self.ctx != 0:
            self.openssl.ctx_free(self.ctx)

    def _error(mut self, message: String) -> TlsError:
        """Make a `CONFIG` error with the text of OpenSSL."""
        var detail = self.openssl.last_error()
        if detail.byte_length() == 0:
            return TlsError(TlsErrorKind.CONFIG, message, 0)
        return TlsError(TlsErrorKind.CONFIG, message + ": " + detail, 0)
