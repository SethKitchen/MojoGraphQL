# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""QUIC packet headers and packet numbers (RFC 9000 section 17 and
appendix A).

`parse_header` reads the header of one packet in a datagram, before the
header protection is removed: the form, the version, the connection IDs,
the token, the offset of the protected packet number, and the end of the
packet. A datagram can hold more than one long-header packet, so the
caller calls it again at `end`. `write_long_header` and
`write_short_header` append a header with a placeholder for the Length,
and `set_length` patches it when the payload is written.

The packet number functions of appendix A choose the length of a
truncated packet number, write it, and expand a truncated number back.
Header protection and the AEAD are in `crypto`, which uses `pn_offset`
and the helpers `first_byte_mask` and `pn_len_from_first`.

This module ports quinn-proto 0.11.19 (8192ed3) quinn-proto/src/packet.rs
(MIT OR Apache-2.0, used under MIT).

Differences from upstream: upstream returns a `PacketDecodeError`, which
makes the endpoint drop the datagram. Here `parse_header` raises
`QuicError` with `PROTOCOL_VIOLATION` and upstream's reason, such as
`invalid header: malformed cid`, and the caller must drop the datagram in
the same way. Upstream checks the version against a list; here a long
header of a version other than 0 and `QUIC_VERSION_1` stops after the
connection IDs, with `end` at the end of the datagram and `pn_offset` -1,
and the caller answers with Version Negotiation. A Retry packet keeps its
16-byte integrity tag out of the token, and one shorter than the tag
raises `invalid header: retry too short`; upstream checks the tag in the
connection. `packet_number_len` gives 4 for a range that upstream panics
on. The header is a flat `PacketHeader` with offsets into the datagram, in
place of the `ProtectedHeader` enum.
"""

from gql_quic.cid import MAX_CID_SIZE, ConnectionId
from gql_quic.error import QuicError, TransportErrorCode
from gql_quic.varint import (
    patch_varint_2,
    read_be,
    read_varint,
    reserve_tail,
    write_bytes,
    write_u8,
    write_u32,
    write_varint,
    write_varint_2,
)

comptime QUIC_VERSION_1: UInt32 = 1
"""The version of RFC 9000."""
comptime LONG_HEADER_FORM: UInt8 = 0x80
"""The bit of the first byte that marks a long header."""
comptime FIXED_BIT: UInt8 = 0x40
"""The bit of the first byte that is 1 in QUIC version 1."""
comptime SPIN_BIT: UInt8 = 0x20
"""The latency spin bit of a short header."""
comptime KEY_PHASE_BIT: UInt8 = 0x04
"""The key phase bit of a short header, under header protection."""
comptime RETRY_TAG_SIZE = 16
"""The size of the Retry integrity tag (RFC 9001 section 5.8)."""


@fieldwise_init
struct SpaceId(Equatable, ImplicitlyCopyable, Writable):
    """A packet number space (RFC 9000 section 12.3)."""

    var value: UInt8
    """The space's index; see `is_valid`."""

    comptime INITIAL = SpaceId(0)
    """The space of Initial packets."""
    comptime HANDSHAKE = SpaceId(1)
    """The space of Handshake packets."""
    comptime DATA = SpaceId(2)
    """The space of 0-RTT and 1-RTT packets."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the spaces.

        Returns:
            Whether the value is at most 2.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the space.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 3] = [
            "Initial",
            "Handshake",
            "Data",
        ]
        if self.is_valid():
            writer.write(materialize[names]()[Int(self.value)])
        else:
            writer.write("invalid")


@fieldwise_init
struct LongType(Equatable, ImplicitlyCopyable, Writable):
    """The type of a long-header packet (RFC 9000 section 17.2)."""

    var value: UInt8
    """The type as the bits 0x30 of the first byte hold it."""

    comptime INITIAL = LongType(0)
    """An Initial packet."""
    comptime ZERO_RTT = LongType(1)
    """A 0-RTT packet."""
    comptime HANDSHAKE = LongType(2)
    """A Handshake packet."""
    comptime RETRY = LongType(3)
    """A Retry packet."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the types.

        Returns:
            Whether the value is at most 3.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the type.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 4] = [
            "Initial",
            "0-RTT",
            "Handshake",
            "Retry",
        ]
        if self.is_valid():
            writer.write(materialize[names]()[Int(self.value)])
        else:
            writer.write("invalid")


# ===-------------------------------------------------------------------=== #
# Packet numbers
# ===-------------------------------------------------------------------=== #


def packet_number_len(full: UInt64, largest_acked: Int64) -> Int:
    """Return the length of the truncated packet number to send
    (RFC 9000 appendix A.2).

    Args:
        full: The full packet number.
        largest_acked: The largest packet number that the peer
            acknowledged in this space, or -1 for none.

    Returns:
        1, 2, 3 or 4.
    """
    var unacked = full + 1
    if largest_acked >= 0:
        unacked = full - UInt64(largest_acked)
    var range = unacked * 2
    if range < 1 << 8:
        return 1
    if range < 1 << 16:
        return 2
    if range < 1 << 24:
        return 3
    return 4


def write_packet_number(mut out: List[UInt8], full: UInt64, length: Int):
    """Append the low `length` bytes of a packet number, big-endian.

    Args:
        out: The destination.
        full: The full packet number.
        length: 1, 2, 3 or 4.
    """
    var at = reserve_tail(out, length)
    var p = out.unsafe_ptr().unsafe_offset(at)
    var i = 0
    while i < length:
        p[unsafe_offset=i] = UInt8(
            (full >> UInt64(8 * (length - 1 - i))) & 0xFF
        )
        i += 1


def decode_packet_number(
    expected_next: UInt64, truncated: UInt64, length: Int
) -> UInt64:
    """Expand a truncated packet number (RFC 9000 appendix A.3), as
    upstream's `PacketNumber::expand`.

    Args:
        expected_next: The largest packet number received in the space,
            plus 1.
        truncated: The truncated packet number.
        length: Its length in bytes: 1, 2, 3 or 4.

    Returns:
        The full packet number nearest to `expected_next`.
    """
    var win = UInt64(1) << UInt64(length * 8)
    var hwin = win // 2
    var mask = win - 1
    var candidate = (expected_next & ~mask) | truncated
    if expected_next >= hwin and candidate <= expected_next - hwin:
        return candidate + win
    if candidate > expected_next + hwin and candidate > win:
        return candidate - win
    return candidate


@always_inline
def first_byte_mask(is_long: Bool) -> UInt8:
    """Return the bits of the first byte that header protection covers.

    Args:
        is_long: True for a long header.

    Returns:
        0x0f for a long header, 0x1f for a short header.
    """
    return UInt8(0x0F) if is_long else UInt8(0x1F)


@always_inline
def pn_len_from_first(first: UInt8) -> Int:
    """Return the packet number length from an unprotected first byte.

    Args:
        first: The first byte, after header protection is removed.

    Returns:
        1, 2, 3 or 4.
    """
    return 1 + Int(first & 0x03)


@always_inline
def reserved_bits_valid(first: UInt8, is_long: Bool) -> Bool:
    """Return True when the reserved bits of an unprotected first byte are
    0, as upstream's `Packet::reserved_bits_valid`.

    Args:
        first: The first byte, after header protection is removed.
        is_long: True for a long header.

    Returns:
        Whether the bits 0x0c (long) or 0x18 (short) are 0.
    """
    var mask = UInt8(0x0C) if is_long else UInt8(0x18)
    return first & mask == 0


@always_inline
def key_phase(first: UInt8) -> Bool:
    """Return the key phase bit of an unprotected short-header first byte.

    Args:
        first: The first byte, after header protection is removed.

    Returns:
        Whether the bit 0x04 is set.
    """
    return first & KEY_PHASE_BIT != 0


# ===-------------------------------------------------------------------=== #
# Header parsing
# ===-------------------------------------------------------------------=== #


@always_inline
def _invalid(reason: StaticString) -> QuicError:
    """Return the error for a header that does not decode."""
    return QuicError(
        TransportErrorCode.PROTOCOL_VIOLATION,
        String("invalid header: ", reason),
    )


struct PacketHeader(Copyable, Movable):
    """The header of one packet, before header protection is removed.

    The offsets are absolute offsets in the datagram.
    """

    var start: Int
    """The offset of the first byte of the packet."""
    var first: UInt8
    """The first byte, still under header protection."""
    var is_long: Bool
    """True for a long header."""
    var long_type: LongType
    """The type of a long header; `INITIAL` for a short header."""
    var version: UInt32
    """The version of a long header; 0 for Version Negotiation and for a
    short header."""
    var dcid: ConnectionId
    """The destination connection ID."""
    var scid: ConnectionId
    """The source connection ID of a long header."""
    var token_start: Int
    """Initial and Retry: the offset of the token."""
    var token_len: Int
    """Initial and Retry: the length of the token; for Retry, without the
    integrity tag."""
    var versions_start: Int
    """Version Negotiation: the offset of the list of versions."""
    var pn_offset: Int
    """The offset of the protected packet number, or -1 for Retry,
    Version Negotiation and an unsupported version."""
    var end: Int
    """The offset after the packet: from the Length of a long header, or
    the end of the datagram."""
    var fixed_bit: Bool
    """Whether the fixed bit 0x40 is set."""
    var spin: Bool
    """The spin bit of a short header."""
    var is_version_negotiation: Bool
    """True for a Version Negotiation packet (version 0)."""

    def __init__(out self, start: Int):
        """Make an empty header at an offset.

        Args:
            start: The offset of the first byte of the packet.
        """
        self.start = start
        self.first = 0
        self.is_long = False
        self.long_type = LongType.INITIAL
        self.version = 0
        self.dcid = ConnectionId()
        self.scid = ConnectionId()
        self.token_start = start
        self.token_len = 0
        self.versions_start = start
        self.pn_offset = -1
        self.end = start
        self.fixed_bit = False
        self.spin = False
        self.is_version_negotiation = False

    def space(self) -> SpaceId:
        """Return the packet number space of the packet.

        Returns:
            `INITIAL` for Initial, `HANDSHAKE` for Handshake, and `DATA`
            for 0-RTT and short headers.
        """
        if not self.is_long:
            return SpaceId.DATA
        if self.long_type == LongType.INITIAL:
            return SpaceId.INITIAL
        if self.long_type == LongType.HANDSHAKE:
            return SpaceId.HANDSHAKE
        return SpaceId.DATA

    def is_supported_version(self) -> Bool:
        """Return True for a long header of QUIC version 1, or a short
        header.

        Returns:
            Whether the rest of the packet can be read.
        """
        return not self.is_long or self.version == QUIC_VERSION_1


@always_inline
def _read_long_cid(
    data: Span[UInt8, _], mut pos: Int
) raises QuicError -> ConnectionId:
    """Read a length byte and a connection ID, as upstream's `decode_long`."""
    if pos >= len(data):
        raise _invalid("malformed cid")
    var length = Int(data[pos])
    pos += 1
    if length > MAX_CID_SIZE or pos + length > len(data):
        raise _invalid("malformed cid")
    var cid = ConnectionId(data[pos : pos + length])
    pos += length
    return cid


@always_inline
def _read_length(
    data: Span[UInt8, _], mut pos: Int, mut h: PacketHeader
) raises QuicError:
    """Read the Length of a long header, and set `pn_offset` and `end`."""
    var length = read_varint(data, pos)
    if length > UInt64(len(data) - pos):
        raise _invalid("packet too short to contain payload length")
    h.pn_offset = pos
    h.end = pos + Int(length)


def _parse_long(
    data: Span[UInt8, _], mut pos: Int, mut h: PacketHeader
) raises QuicError:
    """Read the rest of a long header, after its first byte."""
    h.is_long = True
    h.version = UInt32(read_be(data, pos, 4))
    h.dcid = _read_long_cid(data, pos)
    h.scid = _read_long_cid(data, pos)
    h.end = len(data)
    if h.version == 0:
        h.is_version_negotiation = True
        h.versions_start = pos
        return
    if h.version != QUIC_VERSION_1:
        return
    h.long_type = LongType((h.first >> 4) & 0x03)
    if h.long_type == LongType.INITIAL:
        var token_len = read_varint(data, pos)
        if token_len > UInt64(len(data) - pos):
            raise _invalid("token out of bounds")
        h.token_start = pos
        h.token_len = Int(token_len)
        pos += h.token_len
        _read_length(data, pos, h)
    elif h.long_type == LongType.RETRY:
        if len(data) - pos < RETRY_TAG_SIZE:
            raise _invalid("retry too short")
        h.token_start = pos
        h.token_len = len(data) - pos - RETRY_TAG_SIZE
    else:
        _read_length(data, pos, h)


def parse_header(
    data: Span[UInt8, _],
    start: Int,
    local_cid_len: Int,
    grease_quic_bit: Bool = False,
) raises QuicError -> PacketHeader:
    """Read the header of the packet at an offset of a datagram.

    Args:
        data: The datagram.
        start: The offset of the packet; below `len(data)`.
        local_cid_len: The length of the connection IDs that this endpoint
            issues, which a short header does not state.
        grease_quic_bit: True when the peer may clear the fixed bit
            (RFC 9287); else a clear fixed bit is an error, as upstream.

    Returns:
        The header. The next packet of the datagram, if any, starts at
        `end`.

    Raises:
        QuicError: `PROTOCOL_VIOLATION` with the reason of upstream when
            the header is malformed or truncated. The caller drops the
            datagram.
    """
    var h = PacketHeader(start)
    var pos = start
    try:
        h.first = UInt8(read_be(data, pos, 1))
        h.fixed_bit = h.first & FIXED_BIT != 0
        if not grease_quic_bit and not h.fixed_bit:
            raise _invalid("fixed bit unset")
        if h.first & LONG_HEADER_FORM != 0:
            _parse_long(data, pos, h)
            return h^
    except e:
        if e.code == TransportErrorCode.FRAME_ENCODING_ERROR:
            raise _invalid("unexpected end of packet")
        raise e^
    h.spin = h.first & SPIN_BIT != 0
    if len(data) - pos < local_cid_len:
        raise _invalid("packet too small")
    h.dcid = ConnectionId(data[pos : pos + local_cid_len])
    h.pn_offset = pos + local_cid_len
    h.end = len(data)
    return h^


def parse_version_negotiation(
    data: Span[UInt8, _], header: PacketHeader
) -> List[UInt32]:
    """Return the versions of a Version Negotiation packet.

    Args:
        data: The datagram.
        header: A header with `is_version_negotiation` set.

    Returns:
        The versions, in order. A trailing part of fewer than 4 bytes is
        ignored.
    """
    var out = List[UInt32]()
    var pos = header.versions_start
    while pos + 4 <= header.end:
        var b = data[pos : pos + 4]
        out.append(
            (UInt32(b[0]) << 24)
            | (UInt32(b[1]) << 16)
            | (UInt32(b[2]) << 8)
            | UInt32(b[3])
        )
        pos += 4
    return out^


# ===-------------------------------------------------------------------=== #
# Header building
# ===-------------------------------------------------------------------=== #


@fieldwise_init
struct HeaderMarks(Equatable, ImplicitlyCopyable, Writable):
    """Where a written header put its parts, as upstream's
    `PartialEncode`."""

    var header_start: Int
    """The offset of the first byte."""
    var length_at: Int
    """The offset of the 2-byte Length placeholder, or -1 for a short
    header and for Retry."""
    var pn_at: Int
    """The offset of the packet number, or -1 for Retry."""
    var pn_len: Int
    """The length of the packet number, or 0 for Retry."""

    def header_len(self) -> Int:
        """Return the length of the header, packet number included.

        Returns:
            `pn_at + pn_len - header_start`, or 0 for Retry.
        """
        if self.pn_at < 0:
            return 0
        return self.pn_at + self.pn_len - self.header_start

    def write_to(self, mut writer: Some[Writer]):
        """Write the offsets.

        Args:
            writer: The destination.
        """
        writer.write(
            "HeaderMarks(start=",
            self.header_start,
            ", length_at=",
            self.length_at,
            ", pn_at=",
            self.pn_at,
            ", pn_len=",
            self.pn_len,
            ")",
        )


def write_long_header(
    mut out: List[UInt8],
    long_type: LongType,
    version: UInt32,
    dcid: ConnectionId,
    scid: ConnectionId,
    token: Span[UInt8, _],
    pn: UInt64,
    pn_len: Int,
) -> HeaderMarks:
    """Append a long header, as upstream's `Header::encode`.

    The first byte is `0xc0 | type << 4 | (pn_len - 1)`. An Initial header
    writes the token. Each type but Retry then writes a 2-byte Length
    placeholder for `set_length` and the truncated packet number. A Retry
    header writes the Retry token after the connection IDs, and nothing
    else; the caller appends the integrity tag.

    Args:
        out: The destination.
        long_type: The packet type.
        version: The version.
        dcid: The destination connection ID.
        scid: The source connection ID.
        token: The token of an Initial or Retry packet; ignored for the
            other types.
        pn: The full packet number.
        pn_len: The length of the truncated packet number: 1 to 4.

    Returns:
        The offsets of the Length and the packet number.
    """
    var start = len(out)
    if long_type == LongType.RETRY:
        write_u8(out, 0xF0)
    else:
        write_u8(out, 0xC0 | (long_type.value << 4) | UInt8(pn_len - 1))
    write_u32(out, version)
    dcid.encode_long(out)
    scid.encode_long(out)
    if long_type == LongType.RETRY:
        write_bytes(out, token)
        return HeaderMarks(start, -1, -1, 0)
    if long_type == LongType.INITIAL:
        write_varint(out, UInt64(len(token)))
        write_bytes(out, token)
    var length_at = len(out)
    write_varint_2(out, 0)
    var pn_at = len(out)
    write_packet_number(out, pn, pn_len)
    return HeaderMarks(start, length_at, pn_at, pn_len)


def write_short_header(
    mut out: List[UInt8],
    spin: Bool,
    key_phase: Bool,
    dcid: ConnectionId,
    pn: UInt64,
    pn_len: Int,
) -> HeaderMarks:
    """Append a short (1-RTT) header.

    The first byte is `0x40 | spin << 5 | key_phase << 2 | (pn_len - 1)`.

    Args:
        out: The destination.
        spin: The latency spin bit.
        key_phase: The key phase bit.
        dcid: The destination connection ID.
        pn: The full packet number.
        pn_len: The length of the truncated packet number: 1 to 4.

    Returns:
        The offset of the packet number; `length_at` is -1.
    """
    var start = len(out)
    var first = FIXED_BIT | UInt8(pn_len - 1)
    if spin:
        first |= SPIN_BIT
    if key_phase:
        first |= KEY_PHASE_BIT
    write_u8(out, first)
    write_bytes(out, dcid.bytes())
    var pn_at = len(out)
    write_packet_number(out, pn, pn_len)
    return HeaderMarks(start, -1, pn_at, pn_len)


def set_length(mut out: List[UInt8], marks: HeaderMarks, end: Int):
    """Patch the Length of a long header.

    The Length counts the packet number, the payload and the AEAD tag. The
    tag is added by the encryption, after this call, so the caller must
    pass `end` = the offset after the payload + the tag size. A short
    header has no Length, and the call does nothing.

    Args:
        out: The list that holds the header.
        marks: The marks that `write_long_header` returned.
        end: The offset after the packet, AEAD tag included; the Length
            must be below 16384.
    """
    if marks.length_at < 0:
        return
    patch_varint_2(out, marks.length_at, UInt64(end - (marks.length_at + 2)))


def write_version_negotiation(
    mut out: List[UInt8],
    dcid: ConnectionId,
    scid: ConnectionId,
    versions: Span[UInt32, _],
):
    """Append a Version Negotiation packet (RFC 9000 section 17.2.1).

    The first byte is 0xc0: the long form, and the fixed bit that a server
    should set. The connection IDs are the ones the reply carries: the
    client's source ID as `dcid`, and its destination ID as `scid`.

    Args:
        out: The destination.
        dcid: The destination connection ID.
        scid: The source connection ID.
        versions: The versions that this endpoint supports.
    """
    write_u8(out, LONG_HEADER_FORM | FIXED_BIT)
    write_u32(out, 0)
    dcid.encode_long(out)
    scid.encode_long(out)
    for v in versions:
        write_u32(out, v)
