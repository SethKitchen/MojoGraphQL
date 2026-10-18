# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error codes of HTTP/3 and QPACK, and the error that this package
raises.

`H3ErrorCode` holds the codes of RFC 9114 section 8.1 and of RFC 9204
section 6. A connection error or a stream error sends one of them to the
peer. `H3Error` is the error that the framing, the QPACK coder and the
connection raise: a code and a message.

This module ports `h3/src/error/codes.rs` of hyperium/h3 h3-v0.0.8
(22c1aa3), MIT. The names and the values are the names and the values of
upstream.

Differences from upstream: upstream wraps the code in a large error type
with a kind, a reason and a source. Here an error is the code and a message
only.
"""


@fieldwise_init
struct H3ErrorCode(Equatable, ImplicitlyCopyable, Writable):
    """An HTTP/3 or QPACK error code, as a type and not a bare integer."""

    var value: UInt64
    """The code as it goes on the wire; see `is_valid`."""

    comptime H3_NO_ERROR = H3ErrorCode(0x100)
    """No error: a graceful close."""
    comptime H3_GENERAL_PROTOCOL_ERROR = H3ErrorCode(0x101)
    """A protocol error that no more specific code covers."""
    comptime H3_INTERNAL_ERROR = H3ErrorCode(0x102)
    """An internal error of the endpoint."""
    comptime H3_STREAM_CREATION_ERROR = H3ErrorCode(0x103)
    """The peer opened a stream that is not allowed."""
    comptime H3_CLOSED_CRITICAL_STREAM = H3ErrorCode(0x104)
    """A stream that the connection needs was closed or reset."""
    comptime H3_FRAME_UNEXPECTED = H3ErrorCode(0x105)
    """A frame came on a stream or at a time where it is not allowed."""
    comptime H3_FRAME_ERROR = H3ErrorCode(0x106)
    """A frame does not satisfy its layout, or its size is wrong."""
    comptime H3_EXCESSIVE_LOAD = H3ErrorCode(0x107)
    """The peer causes too much load."""
    comptime H3_ID_ERROR = H3ErrorCode(0x108)
    """A stream id or a push id was used wrongly."""
    comptime H3_SETTINGS_ERROR = H3ErrorCode(0x109)
    """A SETTINGS frame has an error."""
    comptime H3_MISSING_SETTINGS = H3ErrorCode(0x10A)
    """The control stream did not start with a SETTINGS frame."""
    comptime H3_REQUEST_REJECTED = H3ErrorCode(0x10B)
    """The server rejected a request before it processed it."""
    comptime H3_REQUEST_CANCELLED = H3ErrorCode(0x10C)
    """The request or its response was cancelled."""
    comptime H3_REQUEST_INCOMPLETE = H3ErrorCode(0x10D)
    """The client stream ended before the request was complete."""
    comptime H3_MESSAGE_ERROR = H3ErrorCode(0x10E)
    """An HTTP message is malformed."""
    comptime H3_CONNECT_ERROR = H3ErrorCode(0x10F)
    """The connection of a CONNECT request was reset or closed."""
    comptime H3_VERSION_FALLBACK = H3ErrorCode(0x110)
    """The request must be sent again over HTTP/1.1."""
    comptime QPACK_DECOMPRESSION_FAILED = H3ErrorCode(0x200)
    """A field section could not be decoded."""
    comptime QPACK_ENCODER_STREAM_ERROR = H3ErrorCode(0x201)
    """An instruction on the encoder stream could not be read or applied."""
    comptime QPACK_DECODER_STREAM_ERROR = H3ErrorCode(0x202)
    """An instruction on the decoder stream could not be read or applied."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the codes.

        Returns:
            Whether the value is from 0x100 to 0x110, or from 0x200 to
            0x202.
        """
        return (self.value >= 0x100 and self.value <= 0x110) or (
            self.value >= 0x200 and self.value <= 0x202
        )

    def text(self) -> StaticString:
        """Return the name of the code.

        Returns:
            The name, such as `H3_FRAME_ERROR`, or `invalid` for a value
            that `is_valid` refuses.
        """
        comptime h3: Array[StaticString, 17] = [
            "H3_NO_ERROR",
            "H3_GENERAL_PROTOCOL_ERROR",
            "H3_INTERNAL_ERROR",
            "H3_STREAM_CREATION_ERROR",
            "H3_CLOSED_CRITICAL_STREAM",
            "H3_FRAME_UNEXPECTED",
            "H3_FRAME_ERROR",
            "H3_EXCESSIVE_LOAD",
            "H3_ID_ERROR",
            "H3_SETTINGS_ERROR",
            "H3_MISSING_SETTINGS",
            "H3_REQUEST_REJECTED",
            "H3_REQUEST_CANCELLED",
            "H3_REQUEST_INCOMPLETE",
            "H3_MESSAGE_ERROR",
            "H3_CONNECT_ERROR",
            "H3_VERSION_FALLBACK",
        ]
        comptime qpack: Array[StaticString, 3] = [
            "QPACK_DECOMPRESSION_FAILED",
            "QPACK_ENCODER_STREAM_ERROR",
            "QPACK_DECODER_STREAM_ERROR",
        ]
        if not self.is_valid():
            return "invalid"
        if self.value >= 0x200:
            return materialize[qpack]()[Int(self.value - 0x200)]
        return materialize[h3]()[Int(self.value - 0x100)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the code.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct H3Error(Copyable, Movable, Writable):
    """An error of HTTP/3 or QPACK: the code to send, and a message."""

    var code: H3ErrorCode
    """The code that the connection sends to the peer."""
    var message: String
    """A description for people."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the code and the message, such as `H3_FRAME_ERROR: short`.

        Args:
            writer: The destination.
        """
        writer.write(self.code, ": ", self.message)
