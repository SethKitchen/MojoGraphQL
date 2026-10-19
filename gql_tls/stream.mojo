# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A TLS connection over a non-blocking socket.

`TlsStream.accept` and `TlsStream.connect` bind an OpenSSL `SSL` object to
a socket. `handshake`, `read` and `write` never block: when the socket is
not ready, they return what the stream waits for, as an `IoWant`, and the
caller polls the socket for it. A `TlsStream` does not own the socket; the
caller closes it after the stream.

`read` returns the count of bytes, 0 at the end of the stream, or a
negative `IoWant` code. A TLS 1.3 read can need a write, and a write can
need a read, so a caller must wait for the event that the code names.

This module ports no code. The behavior follows RFC 8446 through OpenSSL.

Differences from upstream: none; there is no upstream.
"""

from std.memory import ArcPointer
from std.sys._libc_errno import get_errno

from gql_http.socket import POLLIN, POLLOUT, Sys
from gql_tls.context import TlsContext
from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import (
    OpenSsl,
    SSL_ERROR_SYSCALL,
    SSL_ERROR_WANT_READ,
    SSL_ERROR_WANT_WRITE,
    SSL_ERROR_ZERO_RETURN,
    X509_V_OK,
)


@fieldwise_init
struct IoWant(Equatable, ImplicitlyCopyable, Writable):
    """What a TLS operation waits for, as a type and not a bare integer."""

    var value: UInt8
    """The want's index; see `is_valid`."""

    comptime NOTHING = IoWant(0)
    """The operation is done."""
    comptime READ = IoWant(1)
    """The socket must be readable first."""
    comptime WRITE = IoWant(2)
    """The socket must be writable first."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the wants.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def code(self) -> Int:
        """Return the negative code that `read` and `write` return.

        Returns:
            -1 for `READ`, -2 for `WRITE`, 0 for `NOTHING`.
        """
        return -Int(self.value)

    @staticmethod
    def from_code(code: Int) -> IoWant:
        """Read the want of a negative result of `read` or `write`.

        Args:
            code: The result.

        Returns:
            `WRITE` for -2, `READ` for -1, else `NOTHING`.
        """
        if code == -2:
            return IoWant.WRITE
        if code == -1:
            return IoWant.READ
        return IoWant.NOTHING

    def poll_events(self) -> Int:
        """Return the `poll` events to wait for.

        Returns:
            `POLLOUT` for `WRITE`, else `POLLIN`.
        """
        return POLLOUT if self.value == 2 else POLLIN

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the want.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 3] = ["nothing", "read", "write"]
        writer.write(materialize[names]()[Int(min(self.value, 2))])


struct TlsStream(Movable):
    """One TLS connection: an OpenSSL `SSL` object bound to a socket."""

    var openssl: OpenSsl
    """The library, and the fault plan of the calls of this stream."""
    var ssl: Int
    """The `SSL *`."""
    var fd: Int
    """The socket; the stream does not close it."""
    var is_server: Bool
    """Whether this end accepted the connection."""
    var established: Bool
    """Whether the handshake is done."""
    var protocol: String
    """The protocol that ALPN chose, such as `h2`; empty without ALPN."""
    var _verify: Bool
    var _alpn: ArcPointer[List[UInt8]]

    def __init__(
        out self, context: TlsContext, fd: Int, is_server: Bool
    ) raises TlsError:
        """Make the `SSL` object of a connection.

        Use `accept` or `connect` instead.

        Args:
            context: The context.
            fd: The socket.
            is_server: True for the accepting end.

        Raises:
            TlsError: `CONFIG` when OpenSSL cannot make the object.
        """
        self.openssl = context.openssl.copy()
        self.ssl = 0
        self.fd = fd
        self.is_server = is_server
        self.established = False
        self.protocol = String()
        self._verify = context.verify
        self._alpn = context.alpn
        self.ssl = self.openssl.ssl_new(context.ctx)
        if self.ssl == 0:
            raise self._error(TlsErrorKind.CONFIG, "SSL_new failed")
        if not self.openssl.set_fd(self.ssl, fd):
            raise self._error(TlsErrorKind.CONFIG, "SSL_set_fd failed")
        self.openssl.set_read_ahead(self.ssl)

    def __init__(out self, openssl: OpenSsl):
        """Make a stream with no connection, as a placeholder.

        Args:
            openssl: The library.
        """
        self.openssl = openssl.copy()
        self.ssl = 0
        self.fd = -1
        self.is_server = False
        self.established = False
        self.protocol = String()
        self._verify = False
        self._alpn = ArcPointer(List[UInt8]())

    @staticmethod
    def accept(context: TlsContext, fd: Int) raises TlsError -> TlsStream:
        """Start the server end of a connection on an accepted socket.

        Args:
            context: A server context.
            fd: The accepted socket.

        Returns:
            The stream, before its handshake.

        Raises:
            TlsError: `CONFIG` when OpenSSL cannot make the object.
        """
        var stream = TlsStream(context, fd, True)
        stream.openssl.set_accept_state(stream.ssl)
        return stream^

    @staticmethod
    def connect(
        context: TlsContext, fd: Int, host: String
    ) raises TlsError -> TlsStream:
        """Start the client end of a connection on a connected socket.

        Args:
            context: A client context.
            fd: The connected socket.
            host: The name of the server, for SNI and for verification. An
                IP address or an empty name sends no SNI and is not checked
                as a name.

        Returns:
            The stream, before its handshake.

        Raises:
            TlsError: `CONFIG` when OpenSSL cannot make the object or take
                the name.
        """
        var stream = TlsStream(context, fd, False)
        stream.openssl.set_connect_state(stream.ssl)
        if host.byte_length() > 0 and not _is_address(host):
            if not stream.openssl.set_host(stream.ssl, host):
                raise stream._error(
                    TlsErrorKind.CONFIG, "cannot set the server name " + host
                )
        return stream^

    def __deinit__(deinit self):
        """Free the `SSL` object. The socket stays open."""
        if self.ssl != 0:
            self.openssl.ssl_free(self.ssl)

    def _error(mut self, kind: TlsErrorKind, message: String) -> TlsError:
        """Make an error with the text of OpenSSL."""
        var detail = self.openssl.last_error()
        if detail.byte_length() == 0:
            return TlsError(kind, message, 0)
        return TlsError(kind, message + ": " + detail, 0)

    def _failure(mut self, result: Int32) -> Int:
        """Turn a failed call into a want code, or raise its error."""
        var code = self.openssl.get_error(self.ssl, result)
        if code == SSL_ERROR_WANT_READ:
            self.openssl.clear_errors()
            return IoWant.READ.code()
        if code == SSL_ERROR_WANT_WRITE:
            self.openssl.clear_errors()
            return IoWant.WRITE.code()
        return -100 - Int(code)

    def handshake(mut self) raises TlsError -> IoWant:
        """Run the handshake as far as the socket allows.

        Returns:
            `NOTHING` when the handshake is done, else what it waits for.

        Raises:
            TlsError: `VERIFY` when the certificate of the server does not
                verify; `CLOSED` when the peer closed; `HANDSHAKE` for
                another failure.
        """
        if self.established:
            return IoWant.NOTHING
        var result = self.openssl.handshake(self.ssl)
        if result == 1:
            self.established = True
            self.protocol = self.openssl.alpn_selected(self.ssl)
            return IoWant.NOTHING
        var code = self._failure(result)
        if code > -100:
            return IoWant.from_code(code)
        if not self.is_server and self._verify:
            var verdict = self.openssl.verify_result(self.ssl)
            if verdict != X509_V_OK:
                var text = self.openssl.verify_text(verdict)
                self.openssl.clear_errors()
                raise TlsError(
                    TlsErrorKind.VERIFY,
                    "the certificate of the server did not verify: " + text,
                    verdict,
                )
        if code == -100 - Int(SSL_ERROR_SYSCALL):
            var errno = Int(get_errno().value)
            self.openssl.clear_errors()
            raise TlsError(
                TlsErrorKind.CLOSED,
                "the peer closed the connection during the handshake",
                errno,
            )
        raise self._error(TlsErrorKind.HANDSHAKE, "the TLS handshake failed")

    def read(
        mut self, data: Pointer[UInt8, _], size: Int
    ) raises TlsError -> Int:
        """Read decrypted bytes.

        Args:
            data: The buffer.
            size: The size of the buffer; more than 0.

        Returns:
            The count of bytes; 0 at the end of the stream; or the negative
            code of an `IoWant`.

        Raises:
            TlsError: `PROTOCOL` when the peer sent bad TLS data; `OS` when
                the socket failed.
        """
        var result = self.openssl.read(self.ssl, data, size)
        if result > 0:
            return Int(result)
        var code = self._failure(result)
        if code > -100:
            return code
        if code == -100 - Int(SSL_ERROR_ZERO_RETURN):
            self.openssl.clear_errors()
            return 0
        raise self._io_error(code, "the TLS read failed")

    def write(
        mut self, data: Pointer[UInt8, _], size: Int
    ) raises TlsError -> Int:
        """Encrypt and send bytes.

        A partial write is possible: send the rest later.

        Args:
            data: The bytes.
            size: The count of bytes; more than 0.

        Returns:
            The count of bytes taken, or the negative code of an `IoWant`.

        Raises:
            TlsError: `CLOSED` when the peer closed; `PROTOCOL` for a TLS
                failure; `OS` when the socket failed.
        """
        var result = self.openssl.write(self.ssl, data, size)
        if result > 0:
            return Int(result)
        var code = self._failure(result)
        if code > -100:
            return code
        raise self._io_error(code, "the TLS write failed")

    def _io_error(mut self, code: Int, message: String) -> TlsError:
        """Make the error of a failed read or write."""
        if code == -100 - Int(SSL_ERROR_SYSCALL):
            var errno = Int(get_errno().value)
            self.openssl.clear_errors()
            if errno == 0:
                return TlsError(TlsErrorKind.CLOSED, "the peer closed", 0)
            return TlsError.os("send or recv", errno)
        return self._error(TlsErrorKind.PROTOCOL, message)

    def pending(mut self) -> Int:
        """Return the count of decrypted bytes that `read` can take now.

        A caller must read them before it waits for the socket again.

        Returns:
            The count.
        """
        return self.openssl.pending(self.ssl)

    def has_pending(mut self) -> Bool:
        """Return True when OpenSSL holds bytes that the socket no longer
        has, so that `read` can return bytes without a readable socket.

        A caller that waits for the socket must first read until this is
        False.

        Returns:
            Whether OpenSSL holds bytes of the peer.
        """
        return self.openssl.has_pending(self.ssl)

    def shutdown(mut self) -> Bool:
        """Send `close_notify`, once. The stream reads no answer.

        Returns:
            Whether the alert went out.
        """
        var result = self.openssl.shutdown(self.ssl)
        self.openssl.clear_errors()
        return result >= 0


def _is_address(host: String) -> Bool:
    """Return True for an IPv4 or IPv6 literal, which has no SNI."""
    var bytes = host.as_bytes()
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if byte == 58:
            return True
        if byte != 46 and (byte < 48 or byte > 57):
            return False
        index += 1
    return True


def wait_for(
    mut sys: Sys, fd: Int, want: IoWant, timeout_ms: Int
) raises TlsError:
    """Wait until the socket is ready for what a TLS operation wants.

    Args:
        sys: The system calls.
        fd: The socket.
        want: What the operation waits for.
        timeout_ms: The longest wait.

    Raises:
        TlsError: `TIMEOUT` when the time runs out; `OS` when `poll` fails.
    """
    var ready = sys.poll(fd, want.poll_events(), max(timeout_ms, 0))
    if ready < 0:
        raise TlsError.os("poll", -ready)
    if ready == 0:
        raise TlsError(TlsErrorKind.TIMEOUT, "the TLS peer did not answer", 0)
