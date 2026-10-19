# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""QUIC frames (RFC 9000 section 19): the frame types, a decoder that does
not allocate, and the encoders.

`read_frame` reads one frame at a cursor in a packet payload, into a
`Frame`. A `Frame` holds numbers and offsets only: the bytes of a STREAM,
CRYPTO or NEW_TOKEN frame, and the reason of a close frame, stay in the
payload, at `data_start` or `reason_start`. A run of PADDING bytes is one
frame. `ack_ranges` turns the ranges of an ACK frame into a `RangeSet`.

The encoders append one frame, or the header of a frame whose data the
caller appends, to a list. A `*_size` function gives the size of the bytes
that the matching encoder writes.

A frame that does not decode raises `QuicError` with
`FRAME_ENCODING_ERROR`, the frame type, and the reason of upstream:
`unexpected end`, `malformed` or `invalid frame ID`. After an error the
cursor is not defined: the caller must close the connection, as upstream
drops the rest of the payload.

This module ports quinn-proto 0.11.19 (8192ed3) quinn-proto/src/frame.rs
(MIT OR Apache-2.0, used under MIT).

Differences from upstream: upstream decodes into a Rust enum with `Bytes`
fields. Here a `Frame` is one flat struct, and a field means something
only for the types that its docstring names. The DATAGRAM, ACK_FREQUENCY
and IMMEDIATE_ACK extension frames are not ported: their types raise
`invalid frame ID`, as any unknown type does. Upstream reads a PADDING
byte as one frame; here a run is one frame with `padding_len`. These
checks of RFC 9000, which quinn makes in its connection and not in
frame.rs, are made here and raise `malformed`: a STREAM or CRYPTO frame
whose offset plus length is above 2^62 - 1 (sections 19.6 and 19.8), a
MAX_STREAMS or STREAMS_BLOCKED count above 2^60 (sections 19.11 and
19.14), and an empty NEW_TOKEN token (section 19.7). `write_ack` takes the
ECN counts as three integers in place of an `Option<EcnCounts>`.
`write_connection_close` writes frame type 0 for `NO_FRAME`.
"""

from gql_quic.cid import (
    MAX_CID_SIZE,
    RESET_TOKEN_SIZE,
    ConnectionId,
    ResetToken,
)
from gql_quic.error import NO_FRAME, QuicError, TransportErrorCode
from gql_quic.range_set import RangeSet
from gql_quic.shared import Dir, StreamId
from gql_quic.varint import (
    VARINT_MAX,
    read_be,
    read_varint,
    unexpected_end,
    varint_size,
    write_bytes,
    write_u8,
    write_u64,
    write_varint,
)

comptime STREAM_OFF: UInt64 = 0x04
"""The bit of a STREAM type that says an offset is present."""
comptime STREAM_LEN: UInt64 = 0x02
"""The bit of a STREAM type that says a length is present."""
comptime STREAM_FIN: UInt64 = 0x01
"""The bit of a STREAM type that marks the end of the stream."""
comptime MAX_STREAM_COUNT: UInt64 = UInt64(1) << 60
"""The largest count of a MAX_STREAMS or STREAMS_BLOCKED frame."""


@fieldwise_init
struct FrameType(Equatable, ImplicitlyCopyable, Writable):
    """A frame type (RFC 9000 section 12.4), as a type and not a bare
    integer."""

    var value: UInt64
    """The type as it goes on the wire."""

    comptime PADDING = FrameType(0x00)
    """No content; makes a packet larger."""
    comptime PING = FrameType(0x01)
    """No content; asks for an acknowledgment."""
    comptime ACK = FrameType(0x02)
    """Acknowledges packets."""
    comptime ACK_ECN = FrameType(0x03)
    """Acknowledges packets, with ECN counts."""
    comptime RESET_STREAM = FrameType(0x04)
    """Ends the sending part of a stream abruptly."""
    comptime STOP_SENDING = FrameType(0x05)
    """Asks the peer to stop sending on a stream."""
    comptime CRYPTO = FrameType(0x06)
    """Carries handshake data."""
    comptime NEW_TOKEN = FrameType(0x07)
    """Gives the client a token for a later connection."""
    comptime STREAM = FrameType(0x08)
    """Carries stream data; the types 0x08 to 0x0f, with three flag bits."""
    comptime MAX_DATA = FrameType(0x10)
    """The connection flow-control limit."""
    comptime MAX_STREAM_DATA = FrameType(0x11)
    """The flow-control limit of a stream."""
    comptime MAX_STREAMS_BIDI = FrameType(0x12)
    """The limit of bidirectional streams that the peer can open."""
    comptime MAX_STREAMS_UNI = FrameType(0x13)
    """The limit of unidirectional streams that the peer can open."""
    comptime DATA_BLOCKED = FrameType(0x14)
    """The sender has data, but the connection limit blocks it."""
    comptime STREAM_DATA_BLOCKED = FrameType(0x15)
    """The sender has data, but the stream limit blocks it."""
    comptime STREAMS_BLOCKED_BIDI = FrameType(0x16)
    """The sender wants to open a bidirectional stream above the limit."""
    comptime STREAMS_BLOCKED_UNI = FrameType(0x17)
    """The sender wants to open a unidirectional stream above the limit."""
    comptime NEW_CONNECTION_ID = FrameType(0x18)
    """Gives the peer a new connection ID."""
    comptime RETIRE_CONNECTION_ID = FrameType(0x19)
    """Retires a connection ID that the peer gave."""
    comptime PATH_CHALLENGE = FrameType(0x1A)
    """Checks that the peer can be reached on a path."""
    comptime PATH_RESPONSE = FrameType(0x1B)
    """Answers a PATH_CHALLENGE."""
    comptime CONNECTION_CLOSE = FrameType(0x1C)
    """Closes the connection with a transport error code."""
    comptime APPLICATION_CLOSE = FrameType(0x1D)
    """Closes the connection with an application error code."""
    comptime HANDSHAKE_DONE = FrameType(0x1E)
    """The server confirms the handshake."""

    @always_inline
    def is_valid(self) -> Bool:
        """Return True for a type of RFC 9000.

        Returns:
            Whether the value is at most 0x1e.
        """
        return self.value <= 0x1E

    @always_inline
    def is_stream(self) -> Bool:
        """Return True for a STREAM type.

        Returns:
            Whether the value is from 0x08 to 0x0f.
        """
        return self.value >= 0x08 and self.value <= 0x0F

    @always_inline
    def is_ack_eliciting(self) -> Bool:
        """Return True for a type that makes the peer send an ACK.

        Returns:
            Whether the type is not PADDING, ACK, ACK_ECN,
            CONNECTION_CLOSE or APPLICATION_CLOSE.
        """
        var v = self.value
        return not (v <= 0x03 and v != 0x01) and v != 0x1C and v != 0x1D

    def text(self) -> StaticString:
        """Return the name of the type, as upstream's `Display`.

        Returns:
            The name, such as `MAX_DATA` or `STREAM`, or `unknown` for a
            value that `is_valid` refuses.
        """
        comptime names: Array[StaticString, 31] = [
            "PADDING",
            "PING",
            "ACK",
            "ACK_ECN",
            "RESET_STREAM",
            "STOP_SENDING",
            "CRYPTO",
            "NEW_TOKEN",
            "STREAM",
            "STREAM",
            "STREAM",
            "STREAM",
            "STREAM",
            "STREAM",
            "STREAM",
            "STREAM",
            "MAX_DATA",
            "MAX_STREAM_DATA",
            "MAX_STREAMS_BIDI",
            "MAX_STREAMS_UNI",
            "DATA_BLOCKED",
            "STREAM_DATA_BLOCKED",
            "STREAMS_BLOCKED_BIDI",
            "STREAMS_BLOCKED_UNI",
            "NEW_CONNECTION_ID",
            "RETIRE_CONNECTION_ID",
            "PATH_CHALLENGE",
            "PATH_RESPONSE",
            "CONNECTION_CLOSE",
            "APPLICATION_CLOSE",
            "HANDSHAKE_DONE",
        ]
        if not self.is_valid():
            return "unknown"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the type, or `<unknown 0x..>`.

        Args:
            writer: The destination.
        """
        if self.is_valid():
            writer.write(self.text())
        else:
            writer.write("<unknown ", hex(self.value), ">")


struct Frame(Copyable, Movable):
    """One decoded frame. It has no heap fields: the bytes of the frame stay
    in the payload, and the offsets here point into it.

    A field means something only for the frame types that its docstring
    names; for the other types it is 0, or empty.
    """

    var type: FrameType
    """The type. For STREAM, the type byte with its flag bits."""
    var fin: Bool
    """STREAM: the frame ends the stream."""
    var stream_id: StreamId
    """STREAM, RESET_STREAM, STOP_SENDING, MAX_STREAM_DATA and
    STREAM_DATA_BLOCKED: the stream."""
    var offset: UInt64
    """STREAM and CRYPTO: the offset of the first byte of the data."""
    var data_start: Int
    """STREAM, CRYPTO and NEW_TOKEN: the offset in the payload of the data,
    or of the token."""
    var data_len: Int
    """STREAM, CRYPTO and NEW_TOKEN: the length of the data, or of the
    token."""
    var reason_start: Int
    """CONNECTION_CLOSE and APPLICATION_CLOSE: the offset of the reason."""
    var reason_len: Int
    """CONNECTION_CLOSE and APPLICATION_CLOSE: the length of the reason."""
    var error_code: UInt64
    """RESET_STREAM, STOP_SENDING, CONNECTION_CLOSE and APPLICATION_CLOSE:
    the error code."""
    var final_size: UInt64
    """RESET_STREAM: the final size of the stream."""
    var value: UInt64
    """The limit of MAX_DATA, MAX_STREAM_DATA and MAX_STREAMS, the limit of
    DATA_BLOCKED, STREAM_DATA_BLOCKED and STREAMS_BLOCKED, and the sequence
    number of RETIRE_CONNECTION_ID."""
    var frame_type: UInt64
    """CONNECTION_CLOSE: the type of the frame that caused the error, or 0
    for none."""
    var sequence: UInt64
    """NEW_CONNECTION_ID and RETIRE_CONNECTION_ID: the sequence number."""
    var retire_prior_to: UInt64
    """NEW_CONNECTION_ID: the peer must retire the IDs below this number."""
    var cid: ConnectionId
    """NEW_CONNECTION_ID: the connection ID."""
    var reset_token: ResetToken
    """NEW_CONNECTION_ID: the stateless reset token."""
    var token: UInt64
    """PATH_CHALLENGE and PATH_RESPONSE: the 8 bytes, big-endian."""
    var ack_largest: UInt64
    """ACK and ACK_ECN: the largest packet number acknowledged."""
    var ack_delay: UInt64
    """ACK and ACK_ECN: the encoded ACK delay."""
    var ack_first_range: UInt64
    """ACK and ACK_ECN: the number of packets below the largest in the first
    range."""
    var ack_range_count: UInt64
    """ACK and ACK_ECN: the number of ranges after the first."""
    var ack_ranges_start: Int
    """ACK and ACK_ECN: the offset of the encoded gap and range pairs."""
    var ack_ranges_end: Int
    """ACK and ACK_ECN: the offset after the gap and range pairs."""
    var ecn: Bool
    """ACK_ECN: the frame has ECN counts."""
    var ect0: UInt64
    """ACK_ECN: the count of ECT(0) packets."""
    var ect1: UInt64
    """ACK_ECN: the count of ECT(1) packets."""
    var ce: UInt64
    """ACK_ECN: the count of ECN-CE packets."""
    var padding_len: Int
    """PADDING: the number of PADDING bytes in the run."""

    def __init__(out self):
        """Make an empty PADDING frame, with every field 0."""
        self.type = FrameType.PADDING
        self.fin = False
        self.stream_id = StreamId(0)
        self.offset = 0
        self.data_start = 0
        self.data_len = 0
        self.reason_start = 0
        self.reason_len = 0
        self.error_code = 0
        self.final_size = 0
        self.value = 0
        self.frame_type = 0
        self.sequence = 0
        self.retire_prior_to = 0
        self.cid = ConnectionId()
        self.reset_token = ResetToken()
        self.token = 0
        self.ack_largest = 0
        self.ack_delay = 0
        self.ack_first_range = 0
        self.ack_range_count = 0
        self.ack_ranges_start = 0
        self.ack_ranges_end = 0
        self.ecn = False
        self.ect0 = 0
        self.ect1 = 0
        self.ce = 0
        self.padding_len = 0

    @always_inline
    def is_ack_eliciting(self) -> Bool:
        """Return True for a frame that makes the peer send an ACK.

        Returns:
            Whether the type is ack-eliciting.
        """
        return self.type.is_ack_eliciting()

    @always_inline
    def dir(self) -> Dir:
        """Return the direction of a MAX_STREAMS or STREAMS_BLOCKED frame.

        Returns:
            `UNI` for the odd types 0x13 and 0x17, else `BI`.
        """
        return Dir(UInt8(self.type.value & 1))


# ===-------------------------------------------------------------------=== #
# Decoding
# ===-------------------------------------------------------------------=== #


@always_inline
def _malformed() -> QuicError:
    """Return the error for a frame with a value that is not permitted."""
    return QuicError(TransportErrorCode.FRAME_ENCODING_ERROR, "malformed")


def check_payload(data: Span[UInt8, _]) raises QuicError:
    """Refuse a packet payload with no frames (RFC 9000 section 12.4).

    Args:
        data: The decrypted payload.

    Raises:
        QuicError: `PROTOCOL_VIOLATION` for an empty payload.
    """
    if len(data) == 0:
        raise QuicError(
            TransportErrorCode.PROTOCOL_VIOLATION, "packet payload is empty"
        )


@always_inline
def _take_len(
    data: Span[UInt8, _], mut pos: Int, mut start: Int, mut length: Int
) raises QuicError:
    """Read a length, and the offset and length of the bytes after it."""
    var n = read_varint(data, pos)
    if n > UInt64(len(data) - pos):
        raise unexpected_end()
    start = pos
    length = Int(n)
    pos += length


@always_inline
def _zero_word(p: Pointer[UInt8, _], at: Int) -> Bool:
    """Return True when the 8 bytes at an offset are 0."""
    return (
        p.unsafe_offset(at).unsafe_bitcast[UInt64]().unsafe_load[alignment=1]()
        == 0
    )


@always_inline
def _skip_padding(data: Span[UInt8, _], mut pos: Int) -> Int:
    """Move past the zero bytes at the cursor; return how many there were."""
    var n = len(data)
    var p = data.unsafe_ptr()
    var run = pos
    while run + 8 <= n and _zero_word(p, run):
        run += 8
    while run < n and p[unsafe_offset=run] == 0:
        run += 1
    var count = run - pos
    pos = run
    return count


@always_inline
def _read_ack(
    data: Span[UInt8, _], mut pos: Int, mut f: Frame
) raises QuicError:
    """Read the body of an ACK or ACK_ECN frame, and check its ranges."""
    f.ack_largest = read_varint(data, pos)
    f.ack_delay = read_varint(data, pos)
    f.ack_range_count = read_varint(data, pos)
    f.ack_first_range = read_varint(data, pos)
    if f.ack_first_range > f.ack_largest:
        raise _malformed()
    var smallest = f.ack_largest - f.ack_first_range
    f.ack_ranges_start = pos
    var left = f.ack_range_count
    while left > 0:
        var gap = read_varint(data, pos) + 2
        if gap > smallest:
            raise _malformed()
        smallest -= gap
        var block = read_varint(data, pos)
        if block > smallest:
            raise _malformed()
        smallest -= block
        left -= 1
    f.ack_ranges_end = pos
    if f.type == FrameType.ACK_ECN:
        f.ecn = True
        f.ect0 = read_varint(data, pos)
        f.ect1 = read_varint(data, pos)
        f.ce = read_varint(data, pos)


@always_inline
def _read_stream(
    data: Span[UInt8, _], mut pos: Int, mut f: Frame
) raises QuicError:
    """Read the body of a STREAM frame."""
    var bits = f.type.value
    f.stream_id = StreamId(read_varint(data, pos))
    if bits & STREAM_OFF != 0:
        f.offset = read_varint(data, pos)
    if bits & STREAM_LEN != 0:
        _take_len(data, pos, f.data_start, f.data_len)
    else:
        f.data_start = pos
        f.data_len = len(data) - pos
        pos = len(data)
    f.fin = bits & STREAM_FIN != 0
    if f.offset + UInt64(f.data_len) > VARINT_MAX:
        raise _malformed()


@always_inline
def _read_new_connection_id(
    data: Span[UInt8, _], mut pos: Int, mut f: Frame
) raises QuicError:
    """Read the body of a NEW_CONNECTION_ID frame."""
    f.sequence = read_varint(data, pos)
    f.retire_prior_to = read_varint(data, pos)
    if f.retire_prior_to > f.sequence:
        raise _malformed()
    var length = Int(read_be(data, pos, 1))
    if length == 0 or length > MAX_CID_SIZE:
        raise _malformed()
    if pos + length + RESET_TOKEN_SIZE > len(data):
        raise unexpected_end()
    f.cid = ConnectionId(data[pos : pos + length])
    pos += length
    f.reset_token = ResetToken(data[pos : pos + RESET_TOKEN_SIZE])
    pos += RESET_TOKEN_SIZE


@always_inline
def _read_count(data: Span[UInt8, _], mut pos: Int) raises QuicError -> UInt64:
    """Read the stream count of MAX_STREAMS or STREAMS_BLOCKED."""
    var count = read_varint(data, pos)
    if count > MAX_STREAM_COUNT:
        raise _malformed()
    return count


def _read_body(
    data: Span[UInt8, _], mut pos: Int, mut f: Frame
) raises QuicError:
    """Read the body of a frame whose type `f.type` is read."""
    var v = f.type.value
    if v >= 0x08 and v <= 0x0F:
        _read_stream(data, pos, f)
    elif v == 0x02 or v == 0x03:
        _read_ack(data, pos, f)
    elif v == 0x00:
        f.padding_len = 1 + _skip_padding(data, pos)
    elif v == 0x06:
        f.offset = read_varint(data, pos)
        _take_len(data, pos, f.data_start, f.data_len)
        if f.offset + UInt64(f.data_len) > VARINT_MAX:
            raise _malformed()
    elif v == 0x01 or v == 0x1E:
        pass
    elif v == 0x04:
        f.stream_id = StreamId(read_varint(data, pos))
        f.error_code = read_varint(data, pos)
        f.final_size = read_varint(data, pos)
    elif v == 0x05:
        f.stream_id = StreamId(read_varint(data, pos))
        f.error_code = read_varint(data, pos)
    elif v == 0x07:
        _take_len(data, pos, f.data_start, f.data_len)
        if f.data_len == 0:
            raise _malformed()
    elif v == 0x10 or v == 0x14:
        f.value = read_varint(data, pos)
    elif v == 0x11 or v == 0x15:
        f.stream_id = StreamId(read_varint(data, pos))
        f.value = read_varint(data, pos)
    elif v <= 0x17:
        # 0x12, 0x13, 0x16 and 0x17: the lower types are handled above.
        f.value = _read_count(data, pos)
    elif v == 0x18:
        _read_new_connection_id(data, pos, f)
    elif v == 0x19:
        f.sequence = read_varint(data, pos)
        f.value = f.sequence
    elif v == 0x1A or v == 0x1B:
        f.token = read_be(data, pos, 8)
    elif v == 0x1C:
        f.error_code = read_varint(data, pos)
        f.frame_type = read_varint(data, pos)
        _take_len(data, pos, f.reason_start, f.reason_len)
    elif v == 0x1D:
        f.error_code = read_varint(data, pos)
        _take_len(data, pos, f.reason_start, f.reason_len)
    else:
        raise QuicError(
            TransportErrorCode.FRAME_ENCODING_ERROR, "invalid frame ID"
        )


def read_frame(data: Span[UInt8, _], mut pos: Int) raises QuicError -> Frame:
    """Read one frame at the cursor. A run of PADDING bytes is one frame.

    Args:
        data: The decrypted packet payload.
        pos: The cursor, below `len(data)`. It moves past the frame.

    Returns:
        The frame. Its offsets point into `data`.

    Raises:
        QuicError: `FRAME_ENCODING_ERROR`, with the frame type when it was
            read, for a truncated frame, a frame with a value that is not
            permitted, or an unknown frame type.
    """
    var f = Frame()
    var ty = read_varint(data, pos)
    f.type = FrameType(ty)
    try:
        _read_body(data, pos, f)
    except e:
        raise QuicError(e.code, ty, String(e.reason))
    return f^


def ack_ranges(
    data: Span[UInt8, _], frame: Frame, mut out: RangeSet
) raises QuicError:
    """Add the packet numbers that an ACK frame acknowledges to a set.

    Args:
        data: The payload that `read_frame` read the frame from.
        frame: An ACK or ACK_ECN frame.
        out: The set; each acknowledged range `[start, end)` is inserted.

    Raises:
        QuicError: `FRAME_ENCODING_ERROR` when the ranges do not decode;
            this cannot happen for a frame that `read_frame` returned.
    """
    var largest = frame.ack_largest
    var smallest = largest - frame.ack_first_range
    _ = out.insert(smallest, largest + 1)
    var pos = frame.ack_ranges_start
    while pos < frame.ack_ranges_end:
        var gap = read_varint(data, pos)
        var block = read_varint(data, pos)
        largest = smallest - gap - 2
        smallest = largest - block
        _ = out.insert(smallest, largest + 1)


# ===-------------------------------------------------------------------=== #
# Encoding
# ===-------------------------------------------------------------------=== #


def write_ack(
    mut out: List[UInt8],
    ranges: RangeSet,
    delay: UInt64,
    ecn: Bool = False,
    ect0: UInt64 = 0,
    ect1: UInt64 = 0,
    ce: UInt64 = 0,
):
    """Append an ACK or ACK_ECN frame, largest range first, as
    upstream's `Ack::encode`.

    Args:
        out: The destination.
        ranges: The packet numbers to acknowledge; at least one range.
        delay: The encoded ACK delay.
        ecn: True to write ACK_ECN with the three counts.
        ect0: The count of ECT(0) packets.
        ect1: The count of ECT(1) packets.
        ce: The count of ECN-CE packets.
    """
    var last = ranges.len() - 1
    var first = ranges.get(last)
    write_u8(out, UInt8(0x03) if ecn else UInt8(0x02))
    write_varint(out, first.end - 1)
    write_varint(out, delay)
    write_varint(out, UInt64(last))
    write_varint(out, first.len() - 1)
    var prev = first.start
    var i = last - 1
    while i >= 0:
        var block = ranges.get(i)
        write_varint(out, prev - block.end - 1)
        write_varint(out, block.len() - 1)
        prev = block.start
        i -= 1
    if ecn:
        write_varint(out, ect0)
        write_varint(out, ect1)
        write_varint(out, ce)


def ack_size(
    ranges: RangeSet,
    delay: UInt64,
    ecn: Bool = False,
    ect0: UInt64 = 0,
    ect1: UInt64 = 0,
    ce: UInt64 = 0,
) -> Int:
    """Return the size of the frame that `write_ack` writes.

    Args:
        ranges: The packet numbers to acknowledge; at least one range.
        delay: The encoded ACK delay.
        ecn: True for ACK_ECN.
        ect0: The count of ECT(0) packets.
        ect1: The count of ECT(1) packets.
        ce: The count of ECN-CE packets.

    Returns:
        The size in bytes.
    """
    var last = ranges.len() - 1
    var first = ranges.get(last)
    var size = 1 + varint_size(first.end - 1) + varint_size(delay)
    size += varint_size(UInt64(last)) + varint_size(first.len() - 1)
    var prev = first.start
    var i = last - 1
    while i >= 0:
        var block = ranges.get(i)
        size += varint_size(prev - block.end - 1) + varint_size(block.len() - 1)
        prev = block.start
        i -= 1
    if ecn:
        size += varint_size(ect0) + varint_size(ect1) + varint_size(ce)
    return size


@always_inline
def _stream_type(offset: UInt64, fin: Bool, with_length: Bool) -> UInt64:
    """Return the STREAM type byte with its flag bits."""
    var ty = FrameType.STREAM.value
    if offset != 0:
        ty |= STREAM_OFF
    if with_length:
        ty |= STREAM_LEN
    if fin:
        ty |= STREAM_FIN
    return ty


def write_stream_header(
    mut out: List[UInt8],
    id: StreamId,
    offset: UInt64,
    length: UInt64,
    fin: Bool,
    with_length: Bool,
):
    """Append the header of a STREAM frame, as upstream's
    `StreamMeta::encode`. The caller appends the data.

    The offset is written only when it is not 0, and the length only when
    `with_length` is True. A frame without a length runs to the end of the
    packet.

    Args:
        out: The destination.
        id: The stream.
        offset: The offset of the first byte of the data.
        length: The number of bytes of data.
        fin: True when the data ends the stream.
        with_length: True to write the length.
    """
    write_u8(out, UInt8(_stream_type(offset, fin, with_length)))
    write_varint(out, id.value)
    if offset != 0:
        write_varint(out, offset)
    if with_length:
        write_varint(out, length)


def stream_header_size(
    id: StreamId, offset: UInt64, length: UInt64, with_length: Bool
) -> Int:
    """Return the size of the header that `write_stream_header` writes.

    Args:
        id: The stream.
        offset: The offset of the first byte of the data.
        length: The number of bytes of data.
        with_length: True when the length is written.

    Returns:
        The size in bytes.
    """
    var size = 1 + varint_size(id.value)
    if offset != 0:
        size += varint_size(offset)
    if with_length:
        size += varint_size(length)
    return size


def write_crypto_header(mut out: List[UInt8], offset: UInt64, length: UInt64):
    """Append the header of a CRYPTO frame. The caller appends the data.

    Args:
        out: The destination.
        offset: The offset of the first byte of the data.
        length: The number of bytes of data.
    """
    write_u8(out, UInt8(FrameType.CRYPTO.value))
    write_varint(out, offset)
    write_varint(out, length)


def crypto_header_size(offset: UInt64, length: UInt64) -> Int:
    """Return the size of the header that `write_crypto_header` writes.

    Args:
        offset: The offset of the first byte of the data.
        length: The number of bytes of data.

    Returns:
        The size in bytes.
    """
    return 1 + varint_size(offset) + varint_size(length)


def write_reset_stream(
    mut out: List[UInt8], id: StreamId, error_code: UInt64, final_size: UInt64
):
    """Append a RESET_STREAM frame.

    Args:
        out: The destination.
        id: The stream.
        error_code: The application error code.
        final_size: The final size of the stream.
    """
    write_u8(out, UInt8(FrameType.RESET_STREAM.value))
    write_varint(out, id.value)
    write_varint(out, error_code)
    write_varint(out, final_size)


def write_stop_sending(mut out: List[UInt8], id: StreamId, error_code: UInt64):
    """Append a STOP_SENDING frame.

    Args:
        out: The destination.
        id: The stream.
        error_code: The application error code.
    """
    write_u8(out, UInt8(FrameType.STOP_SENDING.value))
    write_varint(out, id.value)
    write_varint(out, error_code)


def write_max_data(mut out: List[UInt8], value: UInt64):
    """Append a MAX_DATA frame.

    Args:
        out: The destination.
        value: The connection flow-control limit.
    """
    write_u8(out, UInt8(FrameType.MAX_DATA.value))
    write_varint(out, value)


def write_max_stream_data(mut out: List[UInt8], id: StreamId, value: UInt64):
    """Append a MAX_STREAM_DATA frame.

    Args:
        out: The destination.
        id: The stream.
        value: The flow-control limit of the stream.
    """
    write_u8(out, UInt8(FrameType.MAX_STREAM_DATA.value))
    write_varint(out, id.value)
    write_varint(out, value)


def write_max_streams(mut out: List[UInt8], dir: Dir, count: UInt64):
    """Append a MAX_STREAMS frame.

    Args:
        out: The destination.
        dir: The direction of the streams.
        count: The limit of streams that the peer can open.
    """
    write_u8(out, UInt8(FrameType.MAX_STREAMS_BIDI.value) | dir.value)
    write_varint(out, count)


def write_data_blocked(mut out: List[UInt8], value: UInt64):
    """Append a DATA_BLOCKED frame.

    Args:
        out: The destination.
        value: The connection limit that blocks the sender.
    """
    write_u8(out, UInt8(FrameType.DATA_BLOCKED.value))
    write_varint(out, value)


def write_stream_data_blocked(
    mut out: List[UInt8], id: StreamId, value: UInt64
):
    """Append a STREAM_DATA_BLOCKED frame.

    Args:
        out: The destination.
        id: The stream.
        value: The stream limit that blocks the sender.
    """
    write_u8(out, UInt8(FrameType.STREAM_DATA_BLOCKED.value))
    write_varint(out, id.value)
    write_varint(out, value)


def write_streams_blocked(mut out: List[UInt8], dir: Dir, count: UInt64):
    """Append a STREAMS_BLOCKED frame.

    Args:
        out: The destination.
        dir: The direction of the streams.
        count: The stream limit that blocks the sender.
    """
    write_u8(out, UInt8(FrameType.STREAMS_BLOCKED_BIDI.value) | dir.value)
    write_varint(out, count)


def write_new_connection_id(
    mut out: List[UInt8],
    sequence: UInt64,
    retire_prior_to: UInt64,
    cid: ConnectionId,
    token: ResetToken,
):
    """Append a NEW_CONNECTION_ID frame.

    Args:
        out: The destination.
        sequence: The sequence number of the connection ID.
        retire_prior_to: The peer must retire the IDs below this number.
        cid: The connection ID, of 1 to 20 bytes.
        token: The stateless reset token of the connection ID.
    """
    write_u8(out, UInt8(FrameType.NEW_CONNECTION_ID.value))
    write_varint(out, sequence)
    write_varint(out, retire_prior_to)
    cid.encode_long(out)
    write_bytes(out, token.bytes())


def write_retire_connection_id(mut out: List[UInt8], sequence: UInt64):
    """Append a RETIRE_CONNECTION_ID frame.

    Args:
        out: The destination.
        sequence: The sequence number of the connection ID to retire.
    """
    write_u8(out, UInt8(FrameType.RETIRE_CONNECTION_ID.value))
    write_varint(out, sequence)


def write_path_challenge(mut out: List[UInt8], token: UInt64):
    """Append a PATH_CHALLENGE frame.

    Args:
        out: The destination.
        token: The 8 bytes of data, big-endian.
    """
    write_u8(out, UInt8(FrameType.PATH_CHALLENGE.value))
    write_u64(out, token)


def write_path_response(mut out: List[UInt8], token: UInt64):
    """Append a PATH_RESPONSE frame.

    Args:
        out: The destination.
        token: The 8 bytes of the PATH_CHALLENGE, big-endian.
    """
    write_u8(out, UInt8(FrameType.PATH_RESPONSE.value))
    write_u64(out, token)


@always_inline
def _reason_len(reason_len: Int, fixed: Int, max_len: Int) -> Int:
    """Return how many bytes of a reason fit, as upstream computes it."""
    var budget = max_len - 3 - fixed - varint_size(UInt64(reason_len))
    return max(min(reason_len, budget), 0)


def write_connection_close(
    mut out: List[UInt8],
    code: TransportErrorCode,
    frame_type: UInt64,
    reason: StringSlice,
    max_len: Int = Int.MAX,
):
    """Append a CONNECTION_CLOSE frame, as upstream's
    `ConnectionClose::encode`.

    Args:
        out: The destination.
        code: The transport error code.
        frame_type: The type of the frame that caused the error; 0 or
            `NO_FRAME` for none.
        reason: A short text. Its end is cut so that the frame fits in
            `max_len`, as upstream does.
        max_len: The space left in the packet.
    """
    var ty = UInt64(0) if frame_type == NO_FRAME else frame_type
    var n = _reason_len(reason.byte_length(), varint_size(ty), max_len)
    write_u8(out, UInt8(FrameType.CONNECTION_CLOSE.value))
    write_varint(out, code.value)
    write_varint(out, ty)
    write_varint(out, UInt64(n))
    write_bytes(out, reason.as_bytes()[:n])


def write_application_close(
    mut out: List[UInt8],
    code: UInt64,
    reason: StringSlice,
    max_len: Int = Int.MAX,
):
    """Append an APPLICATION_CLOSE frame, as upstream's
    `ApplicationClose::encode`.

    Args:
        out: The destination.
        code: The application error code.
        reason: A short text. Its end is cut so that the frame fits in
            `max_len`, as upstream does.
        max_len: The space left in the packet.
    """
    var n = _reason_len(reason.byte_length(), 0, max_len)
    write_u8(out, UInt8(FrameType.APPLICATION_CLOSE.value))
    write_varint(out, code)
    write_varint(out, UInt64(n))
    write_bytes(out, reason.as_bytes()[:n])


def write_new_token(mut out: List[UInt8], token: Span[UInt8, _]):
    """Append a NEW_TOKEN frame.

    Args:
        out: The destination.
        token: The token; not empty.
    """
    write_u8(out, UInt8(FrameType.NEW_TOKEN.value))
    write_varint(out, UInt64(len(token)))
    write_bytes(out, token)


def new_token_size(token_len: Int) -> Int:
    """Return the size of the frame that `write_new_token` writes.

    Args:
        token_len: The length of the token.

    Returns:
        The size in bytes.
    """
    return 1 + varint_size(UInt64(token_len)) + token_len


def write_handshake_done(mut out: List[UInt8]):
    """Append a HANDSHAKE_DONE frame.

    Args:
        out: The destination.
    """
    write_u8(out, UInt8(FrameType.HANDSHAKE_DONE.value))


def write_ping(mut out: List[UInt8]):
    """Append a PING frame.

    Args:
        out: The destination.
    """
    write_u8(out, UInt8(FrameType.PING.value))


def write_padding(mut out: List[UInt8], count: Int):
    """Append PADDING bytes.

    Args:
        out: The destination.
        count: The number of bytes.
    """
    out.resize(len(out) + count, 0)
