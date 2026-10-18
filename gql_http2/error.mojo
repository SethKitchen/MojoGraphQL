# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error codes of HTTP/2 (RFC 9113 section 7) and the error that the
package raises.

This module ports h2 v0.4.20 `src/frame/reason.rs` and the error kinds of
`src/proto/error.rs` and `src/error.rs`.

Differences from upstream: `H2Error` is one struct with a kind, a reason, a
stream id and a message. h2 has an enum of a library error, a GOAWAY, a
reset and an I/O error.
"""


@fieldwise_init
struct Reason(Equatable, ImplicitlyCopyable, Writable):
    """An HTTP/2 error code, as in `RST_STREAM` and `GOAWAY` frames."""

    var code: UInt32
    """The error code; an unknown code is allowed on the wire."""

    comptime NO_ERROR = Reason(0)
    """The condition is not a result of an error."""
    comptime PROTOCOL_ERROR = Reason(1)
    """The endpoint detected an unspecific protocol error."""
    comptime INTERNAL_ERROR = Reason(2)
    """The endpoint encountered an unexpected internal error."""
    comptime FLOW_CONTROL_ERROR = Reason(3)
    """The endpoint detected that its peer violated flow control."""
    comptime SETTINGS_TIMEOUT = Reason(4)
    """A `SETTINGS` frame was not acknowledged in time."""
    comptime STREAM_CLOSED = Reason(5)
    """A frame came after a stream was half-closed."""
    comptime FRAME_SIZE_ERROR = Reason(6)
    """A frame had an invalid size."""
    comptime REFUSED_STREAM = Reason(7)
    """The stream was refused before any application processing."""
    comptime CANCEL = Reason(8)
    """The stream is no longer needed."""
    comptime COMPRESSION_ERROR = Reason(9)
    """The header compression context cannot be maintained."""
    comptime CONNECT_ERROR = Reason(10)
    """The connection of a `CONNECT` request was reset or closed."""
    comptime ENHANCE_YOUR_CALM = Reason(11)
    """The peer generates excessive load."""
    comptime INADEQUATE_SECURITY = Reason(12)
    """The transport does not meet the minimum security requirements."""
    comptime HTTP_1_1_REQUIRED = Reason(13)
    """The endpoint requires HTTP/1.1."""

    def is_valid(self) -> Bool:
        """Return True if the code is one that RFC 9113 defines.

        Returns:
            Whether the code is at most 13.
        """
        return self.code <= 13

    def description(self) -> StaticString:
        """Return the description of the code, as h2 gives it.

        Returns:
            The description, or `unknown reason` for an unknown code.
        """
        comptime texts: Array[StaticString, 14] = [
            "not a result of an error",
            "unspecific protocol error detected",
            "unexpected internal error encountered",
            "flow-control protocol violated",
            "settings ACK not received in timely manner",
            "received frame when stream half-closed",
            "frame with invalid size",
            "refused stream before processing any application logic",
            "stream no longer needed",
            "unable to maintain the header compression context",
            (
                "connection established in response to a CONNECT request"
                " was reset or abnormally closed"
            ),
            "detected excessive load generating behavior",
            "security properties do not meet minimum requirements",
            "endpoint requires HTTP/1.1",
        ]
        if not self.is_valid():
            return "unknown reason"
        return materialize[texts]()[Int(self.code)]

    def name(self) -> StaticString:
        """Return the name of the code, such as `PROTOCOL_ERROR`.

        Returns:
            The name, or `UNKNOWN` for an unknown code.
        """
        comptime names: Array[StaticString, 14] = [
            "NO_ERROR",
            "PROTOCOL_ERROR",
            "INTERNAL_ERROR",
            "FLOW_CONTROL_ERROR",
            "SETTINGS_TIMEOUT",
            "STREAM_CLOSED",
            "FRAME_SIZE_ERROR",
            "REFUSED_STREAM",
            "CANCEL",
            "COMPRESSION_ERROR",
            "CONNECT_ERROR",
            "ENHANCE_YOUR_CALM",
            "INADEQUATE_SECURITY",
            "HTTP_1_1_REQUIRED",
        ]
        if not self.is_valid():
            return "UNKNOWN"
        return materialize[names]()[Int(self.code)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the code, or the number of an unknown code.

        Args:
            writer: The destination.
        """
        if self.is_valid():
            writer.write(self.name())
        else:
            writer.write("UNKNOWN(", self.code, ")")


@fieldwise_init
struct H2ErrorKind(Equatable, ImplicitlyCopyable, Writable):
    """Where an HTTP/2 error comes from, and what it ends."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime CONNECTION = H2ErrorKind(0)
    """This endpoint found a connection error; it sends `GOAWAY`."""
    comptime STREAM = H2ErrorKind(1)
    """This endpoint found a stream error; it sends `RST_STREAM`."""
    comptime REMOTE_RESET = H2ErrorKind(2)
    """The peer reset the stream with `RST_STREAM`."""
    comptime REMOTE_GOAWAY = H2ErrorKind(3)
    """The peer ended the connection with `GOAWAY`."""
    comptime IO = H2ErrorKind(4)
    """The transport failed or closed."""
    comptime USAGE = H2ErrorKind(5)
    """The caller gave a value that the function does not accept."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 5

    def text(self) -> StaticString:
        """Return the name of the kind.

        Returns:
            The name, such as `stream`, or `invalid` for a bad value.
        """
        comptime names: Array[StaticString, 6] = [
            "connection",
            "stream",
            "remote reset",
            "remote goaway",
            "io",
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
struct H2Error(Copyable, Movable, Writable):
    """An HTTP/2 error: its kind, its code, its stream and a message."""

    var kind: H2ErrorKind
    """Where the error comes from."""
    var reason: Reason
    """The error code."""
    var stream_id: Int
    """The stream of a stream error or a reset; 0 for the connection."""
    var message: String
    """A description for people."""

    @staticmethod
    def connection(reason: Reason, message: String) -> H2Error:
        """Make a connection error of this endpoint.

        Args:
            reason: The code for the `GOAWAY` frame.
            message: A description for people.

        Returns:
            A `CONNECTION` error.
        """
        return H2Error(H2ErrorKind.CONNECTION, reason, 0, message)

    @staticmethod
    def stream(stream_id: Int, reason: Reason, message: String) -> H2Error:
        """Make a stream error of this endpoint.

        Args:
            stream_id: The stream.
            reason: The code for the `RST_STREAM` frame.
            message: A description for people.

        Returns:
            A `STREAM` error.
        """
        return H2Error(H2ErrorKind.STREAM, reason, stream_id, message)

    @staticmethod
    def usage(message: String) -> H2Error:
        """Make the error of a value that a function does not accept.

        Args:
            message: A description for people.

        Returns:
            A `USAGE` error with the code `INTERNAL_ERROR`.
        """
        return H2Error(H2ErrorKind.USAGE, Reason.INTERNAL_ERROR, 0, message)

    @staticmethod
    def io(message: String) -> H2Error:
        """Make the error of a transport that failed or closed.

        Args:
            message: A description for people.

        Returns:
            An `IO` error with the code `INTERNAL_ERROR`.
        """
        return H2Error(H2ErrorKind.IO, Reason.INTERNAL_ERROR, 0, message)

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind, the code, the stream and the message.

        Args:
            writer: The destination.
        """
        writer.write(self.kind, " error ", self.reason)
        if self.stream_id != 0:
            writer.write(" on stream ", self.stream_id)
        writer.write(": ", self.message)
