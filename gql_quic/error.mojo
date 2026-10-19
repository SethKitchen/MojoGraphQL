# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The transport error codes of QUIC, and the error that this package
raises.

`TransportErrorCode` holds the codes of RFC 9000 section 20.1. A
CONNECTION_CLOSE frame sends one of them to the peer. The codes from 0x100
to 0x1ff carry a TLS alert (RFC 9001 section 4.8). `QuicError` is the error
that the wire layers raise: a code, the type of the frame that caused it,
and a reason.

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/transport_error.rs (MIT OR Apache-2.0, used under MIT).

Differences from upstream: upstream holds the frame type as an
`Option<FrameType>`. Here `frame_type` is a bare `UInt64`, because this
module comes before `frame`, and `NO_FRAME` (`UInt64.MAX`, which is not a
variable-length integer) means that no frame caused the error. A code
writes its name, such as `PROTOCOL_VIOLATION`, in place of the long
description of upstream's `Display`.
"""

comptime NO_FRAME: UInt64 = UInt64.MAX
"""The `frame_type` of an error that no frame caused."""


@fieldwise_init
struct TransportErrorCode(Equatable, ImplicitlyCopyable, Writable):
    """A QUIC transport error code (RFC 9000 section 20.1)."""

    var value: UInt64
    """The code as it goes on the wire."""

    comptime NO_ERROR = TransportErrorCode(0x0)
    """The connection closes without an error."""
    comptime INTERNAL_ERROR = TransportErrorCode(0x1)
    """The endpoint has an internal error and cannot continue."""
    comptime CONNECTION_REFUSED = TransportErrorCode(0x2)
    """The server refuses a new connection."""
    comptime FLOW_CONTROL_ERROR = TransportErrorCode(0x3)
    """The peer sent more data than the advertised limits permit."""
    comptime STREAM_LIMIT_ERROR = TransportErrorCode(0x4)
    """A frame names a stream above the advertised stream limit."""
    comptime STREAM_STATE_ERROR = TransportErrorCode(0x5)
    """A frame came for a stream in a state that does not permit it."""
    comptime FINAL_SIZE_ERROR = TransportErrorCode(0x6)
    """A frame changes the final size of a stream."""
    comptime FRAME_ENCODING_ERROR = TransportErrorCode(0x7)
    """A frame is badly formatted."""
    comptime TRANSPORT_PARAMETER_ERROR = TransportErrorCode(0x8)
    """The transport parameters are badly formatted or not permitted."""
    comptime CONNECTION_ID_LIMIT_ERROR = TransportErrorCode(0x9)
    """The peer gave more connection IDs than the advertised limit."""
    comptime PROTOCOL_VIOLATION = TransportErrorCode(0xA)
    """The peer broke the protocol in a way no other code covers."""
    comptime INVALID_TOKEN = TransportErrorCode(0xB)
    """A client Initial has an invalid Retry token."""
    comptime APPLICATION_ERROR = TransportErrorCode(0xC)
    """The application closes the connection during the handshake."""
    comptime CRYPTO_BUFFER_EXCEEDED = TransportErrorCode(0xD)
    """The peer sent more CRYPTO data than the endpoint can buffer."""
    comptime KEY_UPDATE_ERROR = TransportErrorCode(0xE)
    """A key update is not correct."""
    comptime AEAD_LIMIT_REACHED = TransportErrorCode(0xF)
    """The AEAD confidentiality or integrity limit is reached."""
    comptime NO_VIABLE_PATH = TransportErrorCode(0x10)
    """No network path can carry the connection."""

    @staticmethod
    def crypto(alert: UInt8) -> TransportErrorCode:
        """Return the code that carries a TLS alert.

        Args:
            alert: The TLS alert.

        Returns:
            The code `0x100 + alert`.
        """
        return TransportErrorCode(0x100 | UInt64(alert))

    def is_crypto(self) -> Bool:
        """Return True for a code that carries a TLS alert.

        Returns:
            Whether the code is from 0x100 to 0x1ff.
        """
        return self.value >= 0x100 and self.value < 0x200

    def is_valid(self) -> Bool:
        """Return True if the value names one of the codes.

        Returns:
            Whether the code is at most 0x10, or from 0x100 to 0x1ff.
        """
        return self.value <= 0x10 or self.is_crypto()

    def text(self) -> StaticString:
        """Return the name of a code of RFC 9000 section 20.1.

        Returns:
            The name, such as `PROTOCOL_VIOLATION`, or `invalid` for a
            value above 0x10.
        """
        comptime names: Array[StaticString, 17] = [
            "NO_ERROR",
            "INTERNAL_ERROR",
            "CONNECTION_REFUSED",
            "FLOW_CONTROL_ERROR",
            "STREAM_LIMIT_ERROR",
            "STREAM_STATE_ERROR",
            "FINAL_SIZE_ERROR",
            "FRAME_ENCODING_ERROR",
            "TRANSPORT_PARAMETER_ERROR",
            "CONNECTION_ID_LIMIT_ERROR",
            "PROTOCOL_VIOLATION",
            "INVALID_TOKEN",
            "APPLICATION_ERROR",
            "CRYPTO_BUFFER_EXCEEDED",
            "KEY_UPDATE_ERROR",
            "AEAD_LIMIT_REACHED",
            "NO_VIABLE_PATH",
        ]
        if self.value > 0x10:
            return "invalid"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the code.

        A code with a TLS alert writes `crypto(0x2a)`, and an unknown code
        writes `unknown(0x...)`.

        Args:
            writer: The destination.
        """
        if self.value <= 0x10:
            writer.write(self.text())
        elif self.is_crypto():
            writer.write("crypto(", hex(self.value & 0xFF), ")")
        else:
            writer.write("unknown(", hex(self.value), ")")


struct QuicError(Copyable, Movable, Writable):
    """The error that the QUIC wire layers raise."""

    var code: TransportErrorCode
    """The transport error code to send to the peer."""
    var frame_type: UInt64
    """The type of the frame that caused the error, or `NO_FRAME`."""
    var reason: String
    """A short text for the peer and for the log."""

    def __init__(out self, code: TransportErrorCode, var reason: String):
        """Make an error that no frame caused.

        Args:
            code: The transport error code.
            reason: A short text.
        """
        self.code = code
        self.frame_type = NO_FRAME
        self.reason = reason^

    def __init__(
        out self,
        code: TransportErrorCode,
        frame_type: UInt64,
        var reason: String,
    ):
        """Make an error that a frame caused.

        Args:
            code: The transport error code.
            frame_type: The type of the frame, or `NO_FRAME`.
            reason: A short text.
        """
        self.code = code
        self.frame_type = frame_type
        self.reason = reason^

    def has_frame(self) -> Bool:
        """Return True when a frame caused the error.

        Returns:
            Whether `frame_type` is not `NO_FRAME`.
        """
        return self.frame_type != NO_FRAME

    def write_to(self, mut writer: Some[Writer]):
        """Write the code, the frame type and the reason.

        The form is `FRAME_ENCODING_ERROR in 0x8: bad offset`, as upstream.
        The frame part is absent when no frame caused the error, and the
        reason part is absent when the reason is empty.

        Args:
            writer: The destination.
        """
        writer.write(self.code)
        if self.has_frame():
            writer.write(" in ", hex(self.frame_type))
        if self.reason.byte_length() > 0:
            writer.write(": ", self.reason)
