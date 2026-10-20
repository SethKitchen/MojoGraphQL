# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""WebSocket frames (RFC 6455 section 5): opcodes, close codes, the frame
header, and masking.

`parse_header` reads a frame header in place and copies no byte.
`write_header` writes one. `apply_mask` masks or unmasks a payload in
place, 32 bytes at a time.

This module ports tungstenite 0.30.0 `src/protocol/frame/coding.rs`
(`OpCode`, `CloseCode`), `frame.rs` (`FrameHeader::parse`, `format`,
`LengthFormat`) and `mask.rs` (`apply_mask`), with their tests.

Differences from upstream: `OpCode` holds the 4-bit value; a reserved
opcode is a value for which `is_valid` is False, not a variant. The
header parser also refuses a 64-bit length with the most significant bit
set, which RFC 6455 section 5.2 forbids; tungstenite reads it.
"""

from std.memory import bitcast
from std.random import random_ui64


@fieldwise_init
struct OpCode(Equatable, ImplicitlyCopyable, Writable):
    """The opcode of a frame, as a type and not a bare integer."""

    var value: UInt8
    """The 4-bit opcode."""

    comptime CONTINUE = OpCode(0)
    """A continuation frame of a fragmented message."""
    comptime TEXT = OpCode(1)
    """The first frame of a text message."""
    comptime BINARY = OpCode(2)
    """The first frame of a binary message."""
    comptime CLOSE = OpCode(8)
    """A close frame."""
    comptime PING = OpCode(9)
    """A ping frame."""
    comptime PONG = OpCode(10)
    """A pong frame."""

    def is_valid(self) -> Bool:
        """Return True for an opcode that RFC 6455 defines.

        Returns:
            Whether the value is 0, 1, 2, 8, 9 or 10.
        """
        return self.value <= 2 or (self.value >= 8 and self.value <= 10)

    def is_control(self) -> Bool:
        """Return True for a control opcode: close, ping, pong, or a
        reserved control value.

        Returns:
            Whether the high bit of the opcode is set.
        """
        return self.value >= 8

    def text(self) -> String:
        """Return the upstream name of the opcode.

        Returns:
            `CONTINUE`, `TEXT`, `BINARY`, `CLOSE`, `PING`, `PONG`, or
            `RESERVED_DATA_<n>` and `RESERVED_CONTROL_<n>`.
        """
        comptime names: Array[StaticString, 11] = [
            "CONTINUE",
            "TEXT",
            "BINARY",
            "",
            "",
            "",
            "",
            "",
            "CLOSE",
            "PING",
            "PONG",
        ]
        if self.is_valid():
            return String(materialize[names]()[Int(self.value)])
        if self.is_control():
            return "RESERVED_CONTROL_" + String(self.value)
        return "RESERVED_DATA_" + String(self.value)

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the opcode.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct CloseCode(Equatable, ImplicitlyCopyable, Writable):
    """The status code of a close frame (RFC 6455 section 7.4)."""

    var value: UInt16
    """The code."""

    comptime NORMAL = CloseCode(1000)
    """The purpose of the connection is fulfilled."""
    comptime AWAY = CloseCode(1001)
    """The endpoint goes away, such as a server that shuts down."""
    comptime PROTOCOL = CloseCode(1002)
    """A protocol error."""
    comptime UNSUPPORTED = CloseCode(1003)
    """A type of data that the endpoint cannot accept."""
    comptime STATUS = CloseCode(1005)
    """No status code was present; never sent."""
    comptime ABNORMAL = CloseCode(1006)
    """The connection closed without a close frame; never sent."""
    comptime INVALID = CloseCode(1007)
    """Data in a message did not match its type, such as text that is not
    UTF-8."""
    comptime POLICY = CloseCode(1008)
    """A message broke the policy of the endpoint."""
    comptime SIZE = CloseCode(1009)
    """A message was too big."""
    comptime EXTENSION = CloseCode(1010)
    """The server did not negotiate an extension that the client needs."""
    comptime ERROR = CloseCode(1011)
    """The server met an unexpected condition."""
    comptime RESTART = CloseCode(1012)
    """The server restarts."""
    comptime AGAIN = CloseCode(1013)
    """The server is overloaded; try again later."""
    comptime TLS = CloseCode(1015)
    """The TLS handshake failed; never sent."""

    def is_valid(self) -> Bool:
        """Return True for a code that has a meaning in RFC 6455: the
        defined codes 1000 to 1015 and the ranges 1016 to 4999.

        Returns:
            Whether the code is 1000 or more and below 5000.
        """
        return self.value >= 1000 and self.value < 5000

    def is_allowed(self) -> Bool:
        """Return True for a code that a close frame can carry.

        As tungstenite `CloseCode::is_allowed`: 1000 to 1003, 1007 to
        1013, and 3000 to 4999.

        Returns:
            Whether a peer can send the code.
        """
        var v = self.value
        if v >= 3000:
            return v < 5000
        if v >= 1007:
            return v <= 1013
        return v >= 1000 and v <= 1003

    def write_to(self, mut writer: Some[Writer]):
        """Write the code as a number.

        Args:
            writer: The destination.
        """
        writer.write(self.value)


comptime MAX_HEADER_SIZE = 14
"""The longest frame header: 2 bytes, an 8-byte length and a 4-byte mask."""


@fieldwise_init
struct HeaderState(Equatable, ImplicitlyCopyable, Writable):
    """The outcome of `parse_header`."""

    var value: UInt8
    """The outcome's index; see `is_valid`."""

    comptime COMPLETE = HeaderState(0)
    """The header is complete."""
    comptime INCOMPLETE = HeaderState(1)
    """More bytes are needed; nothing was read."""
    comptime INVALID_OPCODE = HeaderState(2)
    """The opcode is reserved."""
    comptime INVALID_LENGTH = HeaderState(3)
    """The 64-bit length has its most significant bit set."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the outcomes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the outcome.

        Args:
            writer: The destination.
        """
        writer.write(self.value)


@fieldwise_init
struct FrameHeader(ImplicitlyCopyable, Movable):
    """A frame header: the flags, the opcode, the mask and the payload
    length, and the size of the header itself."""

    var state: HeaderState
    """Whether the header is complete or invalid."""
    var is_final: Bool
    """The FIN bit: the last frame of a message."""
    var rsv: UInt8
    """The three reserved bits, in the place they have in the first byte."""
    var opcode: OpCode
    """The opcode."""
    var masked: Bool
    """Whether the payload is masked."""
    var mask: UInt32
    """The masking key, its first byte in the low bits; 0 when unmasked."""
    var length: UInt64
    """The payload length."""
    var size: Int
    """The size of the header in bytes."""

    def __init__(out self):
        """Make an incomplete header."""
        self.state = HeaderState.INCOMPLETE
        self.is_final = True
        self.rsv = 0
        self.opcode = OpCode.CLOSE
        self.masked = False
        self.mask = 0
        self.length = 0
        self.size = 0


def header_size(length: Int, masked: Bool) -> Int:
    """Return the size of a header for a payload length.

    Args:
        length: The payload length.
        masked: Whether the header holds a mask.

    Returns:
        2, 4 or 10 bytes, and 4 more with a mask.
    """
    var size = 2
    if length >= 65536:
        size = 10
    elif length >= 126:
        size = 4
    return size + 4 if masked else size


def parse_header(data: Pointer[UInt8, _], start: Int, end: Int) -> FrameHeader:
    """Read a frame header in place.

    As tungstenite `FrameHeader::parse`: an incomplete header reads
    nothing, and a reserved opcode is an error.

    Args:
        data: The buffer.
        start: The offset of the header.
        end: The offset after the last byte in the buffer.

    Returns:
        The header. Its `state` is `INCOMPLETE` when more bytes are needed.
    """
    var header = FrameHeader()
    var available = end - start
    if available < 2:
        return header
    var first = data[unsafe_offset=start]
    var second = data[unsafe_offset=start + 1]
    header.is_final = first & 0x80 != 0
    header.rsv = first & 0x70
    header.opcode = OpCode(first & 0x0F)
    header.masked = second & 0x80 != 0
    var length_byte = second & 0x7F
    var size = 2
    var length = UInt64(length_byte)
    if length_byte == 126:
        size = 4
        if available < 4:
            return header
        length = (UInt64(data[unsafe_offset=start + 2]) << 8) | UInt64(
            data[unsafe_offset=start + 3]
        )
    elif length_byte == 127:
        size = 10
        if available < 10:
            return header
        length = 0
        var index = 2
        while index < 10:
            length = (length << 8) | UInt64(data[unsafe_offset=start + index])
            index += 1
    if header.masked:
        if available < size + 4:
            return header
        header.mask = (
            UInt32(data[unsafe_offset=start + size])
            | (UInt32(data[unsafe_offset=start + size + 1]) << 8)
            | (UInt32(data[unsafe_offset=start + size + 2]) << 16)
            | (UInt32(data[unsafe_offset=start + size + 3]) << 24)
        )
        size += 4
    header.length = length
    header.size = size
    if not header.opcode.is_valid():
        header.state = HeaderState.INVALID_OPCODE
    elif length >> 63 != 0:
        header.state = HeaderState.INVALID_LENGTH
    else:
        header.state = HeaderState.COMPLETE
    return header


def write_header(
    mut out: List[UInt8],
    is_final: Bool,
    opcode: OpCode,
    length: Int,
    masked: Bool,
    mask: UInt32,
):
    """Append a frame header, as tungstenite `FrameHeader::format`.

    Args:
        out: The output.
        is_final: The FIN bit.
        opcode: The opcode.
        length: The payload length.
        masked: Whether to write a mask.
        mask: The masking key, its first byte in the low bits.
    """
    var first = opcode.value | (UInt8(0x80) if is_final else UInt8(0))
    var mask_bit: UInt8 = 0x80 if masked else 0
    out.append(first)
    if length < 126:
        out.append(UInt8(length) | mask_bit)
    elif length < 65536:
        out.append(126 | mask_bit)
        out.append(UInt8(length >> 8))
        out.append(UInt8(length & 0xFF))
    else:
        out.append(127 | mask_bit)
        var shift = 56
        while shift >= 0:
            out.append(UInt8((length >> shift) & 0xFF))
            shift -= 8
    if masked:
        out.append(UInt8(mask & 0xFF))
        out.append(UInt8((mask >> 8) & 0xFF))
        out.append(UInt8((mask >> 16) & 0xFF))
        out.append(UInt8(mask >> 24))


def random_mask() -> UInt32:
    """Return a new masking key (RFC 6455 section 5.3).

    Returns:
        32 random bits.
    """
    return UInt32(random_ui64(0, 0xFFFFFFFF))


comptime _WIDTH = 32
"""The bytes that `apply_mask` masks in one step."""


def apply_mask(
    data: Pointer[mut=True, UInt8, _], start: Int, count: Int, mask: UInt32
):
    """Mask or unmask bytes in place: byte `i` is XORed with byte `i % 4`
    of the key.

    Args:
        data: The buffer.
        start: The offset of the first payload byte.
        count: The count of bytes.
        mask: The masking key, its first byte in the low bits.
    """
    # The key, repeated: little-endian lanes put its first byte first.
    var bytes = bitcast[DType.uint8, _WIDTH](
        SIMD[DType.uint32, _WIDTH // 4](mask)
    )
    var index = 0
    var at = data.unsafe_offset(start)
    while index + _WIDTH <= count:
        var chunk = at.unsafe_offset(index).unsafe_load[width=_WIDTH]()
        at.unsafe_offset(index).unsafe_store(chunk ^ bytes)
        index += _WIDTH
    while index < count:
        var shift = UInt32((index & 3) * 8)
        var byte = UInt8((mask >> shift) & 0xFF)
        at[unsafe_offset=index] = at[unsafe_offset=index] ^ byte
        index += 1
