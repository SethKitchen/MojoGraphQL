# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error that the TLS layer, the HTTPS server and the client raise.

`TlsErrorKind` has the kinds of `gql_http.error.ErrorKind`, with the same
meaning, and four more: `LIBRARY`, `CONFIG`, `HANDSHAKE` and `VERIFY`.
`TlsError.from_http` keeps the kind of an `HttpError`.

This module ports no code.

Differences from upstream: none; there is no upstream.
"""

from gql_http.error import HttpError


@fieldwise_init
struct TlsErrorKind(Equatable, ImplicitlyCopyable, Writable):
    """What went wrong, as a type and not a bare integer."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime OS = TlsErrorKind(0)
    """A system call failed; `TlsError.errno` holds its error number."""
    comptime RESOLVE = TlsErrorKind(1)
    """A host name did not resolve to an IPv4 address."""
    comptime CONNECT = TlsErrorKind(2)
    """The connection to the peer failed."""
    comptime TIMEOUT = TlsErrorKind(3)
    """An operation did not complete before its deadline."""
    comptime CLOSED = TlsErrorKind(4)
    """The peer closed the connection before the message was complete."""
    comptime PROTOCOL = TlsErrorKind(5)
    """The peer sent a message that the protocol does not allow."""
    comptime LIMIT = TlsErrorKind(6)
    """A message was larger than a configured limit."""
    comptime USAGE = TlsErrorKind(7)
    """The caller gave a value that the function does not accept."""
    comptime LIBRARY = TlsErrorKind(8)
    """OpenSSL 3 is not installed, or it lacks a function."""
    comptime CONFIG = TlsErrorKind(9)
    """A certificate, a key or a trust store did not load."""
    comptime HANDSHAKE = TlsErrorKind(10)
    """The TLS handshake failed."""
    comptime VERIFY = TlsErrorKind(11)
    """The certificate of the peer did not verify, or its name is wrong."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 11

    def text(self) -> StaticString:
        """Return the name of the kind.

        Returns:
            The name, such as `verify`, or `invalid` for a bad value.
        """
        comptime names: Array[StaticString, 12] = [
            "os",
            "resolve",
            "connect",
            "timeout",
            "closed",
            "protocol",
            "limit",
            "usage",
            "library",
            "config",
            "handshake",
            "verify",
        ]
        if not self.is_valid():
            return "invalid"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the kind.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct TlsError(Copyable, Movable, Writable):
    """An error of the TLS layer: its kind, a message and an error number."""

    var kind: TlsErrorKind
    """What went wrong."""
    var message: String
    """A description for people; OpenSSL errors add the OpenSSL text."""
    var errno: Int
    """The system error number of an `OS` or `CONNECT` error, the X.509
    verification result of a `VERIFY` error, else 0."""

    @staticmethod
    def from_http(error: HttpError) -> TlsError:
        """Keep the kind, the message and the error number of an `HttpError`.

        Args:
            error: The error of the socket layer or the HTTP parser.

        Returns:
            The same error as a `TlsError`.
        """
        return TlsError(
            TlsErrorKind(error.kind.value), error.message, error.errno
        )

    @staticmethod
    def os(call: StaticString, errno: Int) -> TlsError:
        """Make the error of a failed system call.

        Args:
            call: The name of the call, such as `connect`.
            errno: The error number that the call set.

        Returns:
            An `OS` error with the message `<call> failed: errno <n>`.
        """
        return TlsError.from_http(HttpError.os(call, errno))

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind and the message, such as `verify: hostname mismatch`.

        Args:
            writer: The destination.
        """
        writer.write(self.kind, ": ", self.message)
