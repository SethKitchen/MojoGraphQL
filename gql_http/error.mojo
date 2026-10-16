# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error that the socket layer, the server and the client raise.

This module ports no code.

Differences from upstream: none; there is no upstream.
"""


@fieldwise_init
struct ErrorKind(Equatable, ImplicitlyCopyable, Writable):
    """What went wrong, as a type and not a bare integer."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime OS = ErrorKind(0)
    """A system call failed; `HttpError.errno` holds its error number."""
    comptime RESOLVE = ErrorKind(1)
    """A host name did not resolve to an IPv4 address."""
    comptime CONNECT = ErrorKind(2)
    """The connection to the peer failed."""
    comptime TIMEOUT = ErrorKind(3)
    """An operation did not complete before its deadline."""
    comptime CLOSED = ErrorKind(4)
    """The peer closed the connection before the message was complete."""
    comptime PROTOCOL = ErrorKind(5)
    """The peer sent a message that RFC 9112 does not allow."""
    comptime LIMIT = ErrorKind(6)
    """A message was larger than a configured limit."""
    comptime USAGE = ErrorKind(7)
    """The caller gave a value that the function does not accept."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 7

    def text(self) -> StaticString:
        """Return the name of the kind.

        Returns:
            The name, such as `timeout`, or `invalid` for a bad value.
        """
        comptime names: Array[StaticString, 8] = [
            "os",
            "resolve",
            "connect",
            "timeout",
            "closed",
            "protocol",
            "limit",
            "usage",
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
struct HttpError(Copyable, Movable, Writable):
    """An error of the transport: its kind, a message and an error number."""

    var kind: ErrorKind
    """What went wrong."""
    var message: String
    """A description for people."""
    var errno: Int
    """The system error number of an `OS` or `CONNECT` error, else 0."""

    @staticmethod
    def os(call: StaticString, errno: Int) -> HttpError:
        """Make the error of a failed system call.

        Args:
            call: The name of the call, such as `bind`.
            errno: The error number that the call set.

        Returns:
            An `OS` error with the message `<call> failed: errno <n>`.
        """
        return HttpError(
            ErrorKind.OS,
            String(call) + " failed: errno " + String(errno),
            errno,
        )

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind and the message, such as `timeout: read timed out`.

        Args:
            writer: The destination.
        """
        writer.write(self.kind, ": ", self.message)
