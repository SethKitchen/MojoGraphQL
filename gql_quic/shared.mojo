# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The side of a connection, the direction of a stream, and the stream ID
(RFC 9000 section 2.1).

The low bit of a stream ID names the side that opened the stream: 0 for
the client and 1 for the server. The next bit names the direction: 0 for a
bidirectional stream and 1 for a unidirectional stream. The other bits are
the index of the stream among the streams of that side and direction.

This module ports quinn-proto 0.11.19 (8192ed3) quinn-proto/src/lib.rs
(MIT OR Apache-2.0, used under MIT): `Side`, `Dir` and `StreamId`.

Differences from upstream: `Side` and `Dir` are structs with `is_valid`,
in place of Rust enums. `Side.opposite` stands for upstream's `!side`.
"""

from std.hash import Hasher


@fieldwise_init
struct Side(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """The side of a connection: the client or the server."""

    var value: UInt8
    """The side's index; see `is_valid`."""

    comptime CLIENT = Side(0)
    """The side that opened the connection."""
    comptime SERVER = Side(1)
    """The side that accepted the connection."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the sides.

        Returns:
            Whether the value is 0 or 1.
        """
        return self.value <= 1

    def is_client(self) -> Bool:
        """Return True for the client.

        Returns:
            Whether the side is `CLIENT`.
        """
        return self.value == 0

    def is_server(self) -> Bool:
        """Return True for the server.

        Returns:
            Whether the side is `SERVER`.
        """
        return self.value == 1

    def opposite(self) -> Side:
        """Return the other side.

        Returns:
            `SERVER` for `CLIENT`, and `CLIENT` for `SERVER`.
        """
        return Side(self.value ^ 1)

    def __hash__[H: Hasher](self, mut hasher: H):
        """Hash the side.

        Parameters:
            H: The hasher type.

        Args:
            hasher: The hasher.
        """
        self.value.__hash__(hasher)

    def write_to(self, mut writer: Some[Writer]):
        """Write `client` or `server`.

        Args:
            writer: The destination.
        """
        if self.value == 0:
            writer.write("client")
        elif self.value == 1:
            writer.write("server")
        else:
            writer.write("invalid")


@fieldwise_init
struct Dir(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """The direction of a stream: bidirectional or unidirectional."""

    var value: UInt8
    """The direction's index; see `is_valid`."""

    comptime BI = Dir(0)
    """Both sides send data."""
    comptime UNI = Dir(1)
    """Only the side that opened the stream sends data."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the directions.

        Returns:
            Whether the value is 0 or 1.
        """
        return self.value <= 1

    def __hash__[H: Hasher](self, mut hasher: H):
        """Hash the direction.

        Parameters:
            H: The hasher type.

        Args:
            hasher: The hasher.
        """
        self.value.__hash__(hasher)

    def write_to(self, mut writer: Some[Writer]):
        """Write `bidirectional` or `unidirectional`, as upstream.

        Args:
            writer: The destination.
        """
        if self.value == 0:
            writer.write("bidirectional")
        elif self.value == 1:
            writer.write("unidirectional")
        else:
            writer.write("invalid")


@fieldwise_init
struct StreamId(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """A stream ID (RFC 9000 section 2.1)."""

    var value: UInt64
    """The ID as it goes on the wire."""

    def __init__(out self, initiator: Side, dir: Dir, index: UInt64):
        """Make the ID of a stream.

        Args:
            initiator: The side that opens the stream.
            dir: The direction of the stream.
            index: The index among the streams of that side and direction.
        """
        self.value = (
            (index << 2) | (UInt64(dir.value) << 1) | UInt64(initiator.value)
        )

    @staticmethod
    def new(initiator: Side, dir: Dir, index: UInt64) -> StreamId:
        """Make the ID of a stream, as upstream's `StreamId::new`.

        Args:
            initiator: The side that opens the stream.
            dir: The direction of the stream.
            index: The index among the streams of that side and direction.

        Returns:
            The ID.
        """
        return StreamId(initiator, dir, index)

    def initiator(self) -> Side:
        """Return the side that opened the stream.

        Returns:
            `CLIENT` or `SERVER`.
        """
        return Side(UInt8(self.value & 1))

    def dir(self) -> Dir:
        """Return the direction of the stream.

        Returns:
            `BI` or `UNI`.
        """
        return Dir(UInt8((self.value >> 1) & 1))

    def index(self) -> UInt64:
        """Return the index among the streams of that side and direction.

        Returns:
            The ID shifted right by 2.
        """
        return self.value >> 2

    def __hash__[H: Hasher](self, mut hasher: H):
        """Hash the ID.

        Parameters:
            H: The hasher type.

        Args:
            hasher: The hasher.
        """
        self.value.__hash__(hasher)

    def write_to(self, mut writer: Some[Writer]):
        """Write the ID as upstream does: `client bidirectional stream 3`.

        Args:
            writer: The destination.
        """
        var dir = "uni" if self.dir() == Dir.UNI else "bi"
        writer.write(self.initiator(), " ", dir, "directional stream ")
        writer.write(self.index())
