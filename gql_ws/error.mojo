# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error of the WebSocket layer, the server and the client.

This module ports `src/error.rs` of tungstenite 0.30.0: the variants of
`Error`, `ProtocolError` and `CapacityError` are kinds and messages here.

Differences from upstream: one `WsError` with a kind, a message, the close
code that the connection sends for the error, and an HTTP status for a
failed handshake. tungstenite nests three enums.
"""


@fieldwise_init
struct WsErrorKind(Equatable, ImplicitlyCopyable, Writable):
    """What went wrong, as a type and not a bare integer."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime PROTOCOL = WsErrorKind(0)
    """The peer broke RFC 6455; the close code is 1002."""
    comptime CAPACITY = WsErrorKind(1)
    """A frame or a message was larger than a limit; the close code is
    1009."""
    comptime UTF8 = WsErrorKind(2)
    """A text message or a close reason was not UTF-8; the close code is
    1007."""
    comptime CLOSED = WsErrorKind(3)
    """The connection closed after the closing handshake."""
    comptime ALREADY_CLOSED = WsErrorKind(4)
    """The caller used a connection that has ended."""
    comptime SEND_AFTER_CLOSING = WsErrorKind(5)
    """The caller sent a message after a close frame."""
    comptime WRITE_BUFFER_FULL = WsErrorKind(6)
    """The output waits for the peer and has no room for the message."""
    comptime HANDSHAKE = WsErrorKind(7)
    """The opening handshake failed; `WsError.status` holds the status."""
    comptime IO = WsErrorKind(8)
    """A socket operation failed, or the peer reset the connection."""
    comptime TIMEOUT = WsErrorKind(9)
    """An operation did not complete before its deadline."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 9

    def text(self) -> StaticString:
        """Return the name of the kind.

        Returns:
            The name, such as `protocol`, or `invalid` for a bad value.
        """
        comptime names: Array[StaticString, 10] = [
            "protocol",
            "capacity",
            "utf8",
            "closed",
            "already closed",
            "send after closing",
            "write buffer full",
            "handshake",
            "io",
            "timeout",
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
struct WsError(Copyable, Movable, Writable):
    """An error of the WebSocket layer."""

    var kind: WsErrorKind
    """What went wrong."""
    var message: String
    """A description for people, as the upstream error text."""
    var close_code: UInt16
    """The close code that the connection sent for the error, or 0."""
    var status: Int
    """The HTTP status of a failed handshake, or 0."""

    @staticmethod
    def protocol(message: String) -> WsError:
        """Make a protocol error, with the close code 1002.

        Args:
            message: The description.

        Returns:
            The error.
        """
        return WsError(WsErrorKind.PROTOCOL, message, 1002, 0)

    @staticmethod
    def of(kind: WsErrorKind, message: String) -> WsError:
        """Make an error without a close code or a status.

        Args:
            kind: The kind.
            message: The description.

        Returns:
            The error.
        """
        return WsError(kind, message, 0, 0)

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind and the message, such as `protocol: ...`.

        Args:
            writer: The destination.
        """
        writer.write(self.kind, ": ", self.message)
