# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP/2 frames (RFC 9113 section 4 and 6): the frame head, the ten frame
types, their flags, `SETTINGS` values, and the writers and readers of each
payload.

A reader checks the rules of the payload alone, such as its length, and
raises an `H2Error` with the code that RFC 9113 gives. The connection
checks the rules of the stream states.

This module ports h2 v0.4.20 `src/frame`: `head.rs`, `data.rs`,
`headers.rs` (the framing part), `settings.rs`, `ping.rs`, `go_away.rs`,
`reset.rs`, `window_update.rs`, `priority.rs`, `stream_id.rs` and
`util.rs`.

Differences from upstream: a frame is not decoded into an owned value. A
`FrameHead` and the offsets of its payload point into the read buffer, so
no byte is copied. The `HEADERS` and `CONTINUATION` writer splits a header
block by the peer's frame size at once.
"""

from gql_http2.error import H2Error, Reason

comptime HEAD_SIZE = 9
"""The size of a frame head."""
comptime PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
"""The client connection preface (RFC 9113 section 3.4)."""
comptime PREFACE_SIZE = 24
"""The size of `PREFACE`."""
comptime MAX_STREAM_ID = 0x7FFFFFFF
"""The largest stream id."""
comptime MAX_WINDOW_SIZE = 0x7FFFFFFF
"""The largest flow-control window (RFC 9113 section 6.9.1)."""
comptime DEFAULT_WINDOW_SIZE = 65535
"""The initial window of a stream and of the connection."""
comptime DEFAULT_MAX_FRAME_SIZE = 16384
"""The initial largest frame payload."""
comptime MAX_MAX_FRAME_SIZE = 16777215
"""The largest value of `SETTINGS_MAX_FRAME_SIZE`."""
comptime DEFAULT_HEADER_TABLE_SIZE = 4096
"""The initial size of the HPACK dynamic table."""

comptime END_STREAM: UInt8 = 0x1
"""The flag of `DATA` and `HEADERS` that ends the stream."""
comptime ACK: UInt8 = 0x1
"""The flag of `SETTINGS` and `PING` that acknowledges."""
comptime END_HEADERS: UInt8 = 0x4
"""The flag of `HEADERS`, `PUSH_PROMISE` and `CONTINUATION` that ends the
header block."""
comptime PADDED: UInt8 = 0x8
"""The flag of `DATA`, `HEADERS` and `PUSH_PROMISE` with padding."""
comptime PRIORITY_FLAG: UInt8 = 0x20
"""The flag of `HEADERS` with a priority."""

comptime SHUTDOWN_PING: UInt64 = 0x0B7BA2F08B9BFE54
"""The payload of the `PING` of a graceful shutdown, big-endian, as h2
sends it."""


@fieldwise_init
struct FrameKind(Equatable, ImplicitlyCopyable, Writable):
    """The type of a frame (RFC 9113 section 6)."""

    var value: UInt8
    """The type byte; an unknown type is allowed on the wire."""

    comptime DATA = FrameKind(0)
    """Content of a stream."""
    comptime HEADERS = FrameKind(1)
    """Opens a stream and carries a header block."""
    comptime PRIORITY = FrameKind(2)
    """The deprecated priority of a stream."""
    comptime RST_STREAM = FrameKind(3)
    """Ends a stream at once."""
    comptime SETTINGS = FrameKind(4)
    """Parameters of the connection."""
    comptime PUSH_PROMISE = FrameKind(5)
    """A stream that a server will push."""
    comptime PING = FrameKind(6)
    """A round trip; the peer answers with an `ACK`."""
    comptime GOAWAY = FrameKind(7)
    """Ends the connection: no new streams."""
    comptime WINDOW_UPDATE = FrameKind(8)
    """Grows a flow-control window."""
    comptime CONTINUATION = FrameKind(9)
    """More of a header block."""

    def is_valid(self) -> Bool:
        """Return True for a type that RFC 9113 defines.

        Returns:
            Whether the type byte is at most 9.
        """
        return self.value <= 9

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the type, such as `HEADERS`.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 10] = [
            "DATA",
            "HEADERS",
            "PRIORITY",
            "RST_STREAM",
            "SETTINGS",
            "PUSH_PROMISE",
            "PING",
            "GOAWAY",
            "WINDOW_UPDATE",
            "CONTINUATION",
        ]
        if self.is_valid():
            writer.write(materialize[names]()[Int(self.value)])
        else:
            writer.write("UNKNOWN(", self.value, ")")


@fieldwise_init
struct FrameHead(ImplicitlyCopyable):
    """The nine bytes before each frame payload."""

    var length: Int
    """The size of the payload."""
    var kind: FrameKind
    """The type."""
    var flags: UInt8
    """The flags."""
    var stream_id: Int
    """The stream; 0 for the connection. The reserved bit is cleared."""

    @staticmethod
    def parse(p: Pointer[UInt8, _]) -> FrameHead:
        """Read a frame head.

        Args:
            p: The first of nine bytes.

        Returns:
            The head.
        """
        var length = (
            (Int(p[unsafe_offset=0]) << 16)
            | (Int(p[unsafe_offset=1]) << 8)
            | Int(p[unsafe_offset=2])
        )
        return FrameHead(
            length,
            FrameKind(p[unsafe_offset=3]),
            p[unsafe_offset=4],
            read_u31(p, 5),
        )

    def has(self, flag: UInt8) -> Bool:
        """Return True when a flag is set.

        Args:
            flag: The flag, such as `END_STREAM`.

        Returns:
            Whether the flag is set.
        """
        return self.flags & flag != 0


def read_u32(p: Pointer[UInt8, _], at: Int) -> Int:
    """Read a big-endian 32-bit integer.

    Args:
        p: The bytes.
        at: The offset of the first byte.

    Returns:
        The value.
    """
    return (
        (Int(p[unsafe_offset=at]) << 24)
        | (Int(p[unsafe_offset=at + 1]) << 16)
        | (Int(p[unsafe_offset=at + 2]) << 8)
        | Int(p[unsafe_offset=at + 3])
    )


def read_u31(p: Pointer[UInt8, _], at: Int) -> Int:
    """Read a big-endian 31-bit integer, and drop the reserved bit.

    Args:
        p: The bytes.
        at: The offset of the first byte.

    Returns:
        The value.
    """
    return read_u32(p, at) & MAX_STREAM_ID


def write_u32(mut out: List[UInt8], value: Int):
    """Append a big-endian 32-bit integer.

    Args:
        out: The destination.
        value: The value; only its low 32 bits are written.
    """
    out.append(UInt8((value >> 24) & 0xFF))
    out.append(UInt8((value >> 16) & 0xFF))
    out.append(UInt8((value >> 8) & 0xFF))
    out.append(UInt8(value & 0xFF))


def write_head(
    mut out: List[UInt8],
    length: Int,
    kind: FrameKind,
    flags: UInt8,
    stream_id: Int,
):
    """Append a frame head.

    Args:
        out: The destination.
        length: The size of the payload, below 2^24.
        kind: The type.
        flags: The flags.
        stream_id: The stream; 0 for the connection.
    """
    out.append(UInt8((length >> 16) & 0xFF))
    out.append(UInt8((length >> 8) & 0xFF))
    out.append(UInt8(length & 0xFF))
    out.append(kind.value)
    out.append(flags)
    write_u32(out, stream_id & MAX_STREAM_ID)


def write_data(
    mut out: List[UInt8], stream_id: Int, data: Span[UInt8, _], end_stream: Bool
):
    """Append one `DATA` frame without padding.

    Args:
        out: The destination.
        stream_id: The stream.
        data: The content; at most the peer's frame size.
        end_stream: Whether the frame ends the stream.
    """
    var flags = END_STREAM if end_stream else UInt8(0)
    write_head(out, len(data), FrameKind.DATA, flags, stream_id)
    out.extend(data)


def write_header_block(
    mut out: List[UInt8],
    stream_id: Int,
    block: Span[UInt8, _],
    end_stream: Bool,
    max_frame_size: Int,
):
    """Append a header block as one `HEADERS` frame and its `CONTINUATION`
    frames.

    Args:
        out: The destination.
        stream_id: The stream.
        block: The HPACK header block.
        end_stream: Whether the `HEADERS` frame ends the stream.
        max_frame_size: The peer's largest frame payload.
    """
    var first = min(len(block), max_frame_size)
    var flags = END_STREAM if end_stream else UInt8(0)
    if first == len(block):
        flags |= END_HEADERS
    write_head(out, first, FrameKind.HEADERS, flags, stream_id)
    out.extend(block[:first])
    var at = first
    while at < len(block):
        var size = min(len(block) - at, max_frame_size)
        var more = END_HEADERS if at + size == len(block) else UInt8(0)
        write_head(out, size, FrameKind.CONTINUATION, more, stream_id)
        out.extend(block[at : at + size])
        at += size


def write_rst_stream(mut out: List[UInt8], stream_id: Int, reason: Reason):
    """Append a `RST_STREAM` frame.

    Args:
        out: The destination.
        stream_id: The stream.
        reason: The error code.
    """
    write_head(out, 4, FrameKind.RST_STREAM, 0, stream_id)
    write_u32(out, Int(reason.code))


def read_u64(p: Pointer[UInt8, _], at: Int) -> UInt64:
    """Read a big-endian 64-bit integer, such as a `PING` payload.

    Args:
        p: The bytes.
        at: The offset of the first byte.

    Returns:
        The value.
    """
    return (UInt64(read_u32(p, at)) << 32) | UInt64(read_u32(p, at + 4))


def write_ping(mut out: List[UInt8], payload: UInt64, ack: Bool):
    """Append a `PING` frame.

    Args:
        out: The destination.
        payload: The eight opaque bytes, big-endian.
        ack: Whether the frame answers a `PING`.
    """
    var flags = ACK if ack else UInt8(0)
    write_head(out, 8, FrameKind.PING, flags, 0)
    write_u32(out, Int(payload >> 32))
    write_u32(out, Int(payload & 0xFFFFFFFF))


def write_goaway(
    mut out: List[UInt8],
    last_stream_id: Int,
    reason: Reason,
    debug: Span[UInt8, _],
):
    """Append a `GOAWAY` frame.

    Args:
        out: The destination.
        last_stream_id: The last stream of the peer that this endpoint
            processed or can process.
        reason: The error code.
        debug: Opaque debug data, such as a message.
    """
    write_head(out, 8 + len(debug), FrameKind.GOAWAY, 0, 0)
    write_u32(out, last_stream_id & MAX_STREAM_ID)
    write_u32(out, Int(reason.code))
    out.extend(debug)


def write_window_update(mut out: List[UInt8], stream_id: Int, increment: Int):
    """Append a `WINDOW_UPDATE` frame.

    Args:
        out: The destination.
        stream_id: The stream; 0 for the connection.
        increment: The increment, from 1 to 2^31 - 1.
    """
    write_head(out, 4, FrameKind.WINDOW_UPDATE, 0, stream_id)
    write_u32(out, increment & MAX_WINDOW_SIZE)


def write_settings_ack(mut out: List[UInt8]):
    """Append a `SETTINGS` frame that acknowledges the peer's settings.

    Args:
        out: The destination.
    """
    write_head(out, 0, FrameKind.SETTINGS, ACK, 0)


@fieldwise_init
struct SettingId(Equatable, ImplicitlyCopyable, Writable):
    """The identifier of a `SETTINGS` parameter (RFC 9113 section 6.5.2)."""

    var value: Int
    """The identifier; an unknown one is ignored on the wire."""

    comptime HEADER_TABLE_SIZE = SettingId(1)
    """The largest HPACK dynamic table of the receiver's decoder."""
    comptime ENABLE_PUSH = SettingId(2)
    """Whether a server can push."""
    comptime MAX_CONCURRENT_STREAMS = SettingId(3)
    """The most streams that the sender lets its peer open."""
    comptime INITIAL_WINDOW_SIZE = SettingId(4)
    """The initial send window of each stream."""
    comptime MAX_FRAME_SIZE = SettingId(5)
    """The largest frame payload that the sender takes."""
    comptime MAX_HEADER_LIST_SIZE = SettingId(6)
    """The largest header list that the sender takes."""
    comptime ENABLE_CONNECT_PROTOCOL = SettingId(8)
    """Whether the extended `CONNECT` of RFC 8441 is allowed."""

    def is_valid(self) -> Bool:
        """Return True for an identifier that the package knows.

        Returns:
            Whether the identifier is 1 to 6, or 8.
        """
        return (self.value >= 1 and self.value <= 6) or self.value == 8

    def write_to(self, mut writer: Some[Writer]):
        """Write the identifier as a number.

        Args:
            writer: The destination.
        """
        writer.write(self.value)


struct Settings(Copyable, Movable):
    """The `SETTINGS` parameters of one endpoint.

    A size of -1 means no limit. The initial values are those of RFC 9113.
    """

    var header_table_size: Int
    """`SETTINGS_HEADER_TABLE_SIZE`."""
    var enable_push: Bool
    """`SETTINGS_ENABLE_PUSH`."""
    var max_concurrent_streams: Int
    """`SETTINGS_MAX_CONCURRENT_STREAMS`, or -1."""
    var initial_window_size: Int
    """`SETTINGS_INITIAL_WINDOW_SIZE`."""
    var max_frame_size: Int
    """`SETTINGS_MAX_FRAME_SIZE`."""
    var max_header_list_size: Int
    """`SETTINGS_MAX_HEADER_LIST_SIZE`, or -1."""
    var enable_connect_protocol: Bool
    """`SETTINGS_ENABLE_CONNECT_PROTOCOL`."""

    def __init__(out self):
        """Make the initial settings of RFC 9113."""
        self.header_table_size = DEFAULT_HEADER_TABLE_SIZE
        self.enable_push = True
        self.max_concurrent_streams = -1
        self.initial_window_size = DEFAULT_WINDOW_SIZE
        self.max_frame_size = DEFAULT_MAX_FRAME_SIZE
        self.max_header_list_size = -1
        self.enable_connect_protocol = False

    def set(
        mut self, id: SettingId, value: Int, from_server: Bool
    ) raises H2Error:
        """Set one parameter from the wire, and check its value.

        Args:
            id: The identifier; an unknown one is ignored.
            value: The 32-bit value.
            from_server: Whether a server sent it.

        Raises:
            H2Error: A connection error: `PROTOCOL_ERROR` for an invalid
                `ENABLE_PUSH`, `MAX_FRAME_SIZE` or `ENABLE_CONNECT_PROTOCOL`,
                and `FLOW_CONTROL_ERROR` for a window above 2^31 - 1.
        """
        if id == SettingId.HEADER_TABLE_SIZE:
            self.header_table_size = value
        elif id == SettingId.ENABLE_PUSH:
            if value > 1 or (from_server and value == 1):
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "invalid SETTINGS_ENABLE_PUSH"
                )
            self.enable_push = value == 1
        elif id == SettingId.MAX_CONCURRENT_STREAMS:
            self.max_concurrent_streams = value
        elif id == SettingId.INITIAL_WINDOW_SIZE:
            if value > MAX_WINDOW_SIZE:
                raise H2Error.connection(
                    Reason.FLOW_CONTROL_ERROR,
                    "invalid SETTINGS_INITIAL_WINDOW_SIZE",
                )
            self.initial_window_size = value
        elif id == SettingId.MAX_FRAME_SIZE:
            if value < DEFAULT_MAX_FRAME_SIZE or value > MAX_MAX_FRAME_SIZE:
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR, "invalid SETTINGS_MAX_FRAME_SIZE"
                )
            self.max_frame_size = value
        elif id == SettingId.MAX_HEADER_LIST_SIZE:
            self.max_header_list_size = value
        elif id == SettingId.ENABLE_CONNECT_PROTOCOL:
            if value > 1:
                raise H2Error.connection(
                    Reason.PROTOCOL_ERROR,
                    "invalid SETTINGS_ENABLE_CONNECT_PROTOCOL",
                )
            self.enable_connect_protocol = value == 1

    def apply(
        mut self,
        p: Pointer[UInt8, _],
        start: Int,
        length: Int,
        from_server: Bool,
    ) raises H2Error:
        """Apply the parameters of a `SETTINGS` payload, in order.

        Args:
            p: The bytes.
            start: The offset of the payload.
            length: The size of the payload, a multiple of 6.
            from_server: Whether a server sent it.

        Raises:
            H2Error: A connection error for an invalid value; see `set`.
        """
        var at = start
        while at < start + length:
            var id = (Int(p[unsafe_offset=at]) << 8) | Int(
                p[unsafe_offset=at + 1]
            )
            self.set(SettingId(id), read_u32(p, at + 2), from_server)
            at += 6

    def write(self, mut out: List[UInt8]):
        """Append a `SETTINGS` frame with each value that is not initial.

        Args:
            out: The destination.
        """
        var initial = Settings()
        var body = List[UInt8]()
        if self.header_table_size != initial.header_table_size:
            _setting(body, SettingId.HEADER_TABLE_SIZE, self.header_table_size)
        if self.enable_push != initial.enable_push:
            _setting(body, SettingId.ENABLE_PUSH, Int(self.enable_push))
        if self.max_concurrent_streams >= 0:
            _setting(
                body,
                SettingId.MAX_CONCURRENT_STREAMS,
                self.max_concurrent_streams,
            )
        if self.initial_window_size != initial.initial_window_size:
            _setting(
                body, SettingId.INITIAL_WINDOW_SIZE, self.initial_window_size
            )
        if self.max_frame_size != initial.max_frame_size:
            _setting(body, SettingId.MAX_FRAME_SIZE, self.max_frame_size)
        if self.max_header_list_size >= 0:
            _setting(
                body, SettingId.MAX_HEADER_LIST_SIZE, self.max_header_list_size
            )
        if self.enable_connect_protocol:
            _setting(body, SettingId.ENABLE_CONNECT_PROTOCOL, 1)
        write_head(out, len(body), FrameKind.SETTINGS, 0, 0)
        out.extend(Span(body))


def _setting(mut body: List[UInt8], id: SettingId, value: Int):
    """Append one parameter of a `SETTINGS` payload."""
    body.append(UInt8((id.value >> 8) & 0xFF))
    body.append(UInt8(id.value & 0xFF))
    write_u32(body, value)


def check_settings(head: FrameHead) raises H2Error:
    """Check the head of a `SETTINGS` frame (RFC 9113 section 6.5).

    Args:
        head: The head.

    Raises:
        H2Error: A connection error: `PROTOCOL_ERROR` for a stream id that
            is not 0, `FRAME_SIZE_ERROR` for an `ACK` with a payload or a
            size that is not a multiple of 6.
    """
    if head.stream_id != 0:
        raise H2Error.connection(Reason.PROTOCOL_ERROR, "SETTINGS on a stream")
    if head.has(ACK) and head.length != 0:
        raise H2Error.connection(
            Reason.FRAME_SIZE_ERROR, "SETTINGS ACK with a payload"
        )
    if head.length % 6 != 0:
        raise H2Error.connection(
            Reason.FRAME_SIZE_ERROR, "SETTINGS size is not a multiple of 6"
        )


def check_ping(head: FrameHead) raises H2Error:
    """Check the head of a `PING` frame (RFC 9113 section 6.7).

    Args:
        head: The head.

    Raises:
        H2Error: A connection error: `PROTOCOL_ERROR` for a stream id that
            is not 0, `FRAME_SIZE_ERROR` for a size that is not 8.
    """
    if head.stream_id != 0:
        raise H2Error.connection(Reason.PROTOCOL_ERROR, "PING on a stream")
    if head.length != 8:
        raise H2Error.connection(Reason.FRAME_SIZE_ERROR, "PING size is not 8")


def check_goaway(head: FrameHead) raises H2Error:
    """Check the head of a `GOAWAY` frame (RFC 9113 section 6.8).

    Args:
        head: The head.

    Raises:
        H2Error: A connection error: `PROTOCOL_ERROR` for a stream id that
            is not 0, `FRAME_SIZE_ERROR` for a size below 8.
    """
    if head.stream_id != 0:
        raise H2Error.connection(Reason.PROTOCOL_ERROR, "GOAWAY on a stream")
    if head.length < 8:
        raise H2Error.connection(
            Reason.FRAME_SIZE_ERROR, "GOAWAY size is below 8"
        )


def check_rst_stream(head: FrameHead) raises H2Error:
    """Check the head of a `RST_STREAM` frame (RFC 9113 section 6.4).

    Args:
        head: The head.

    Raises:
        H2Error: A connection error: `PROTOCOL_ERROR` on stream 0,
            `FRAME_SIZE_ERROR` for a size that is not 4.
    """
    if head.stream_id == 0:
        raise H2Error.connection(
            Reason.PROTOCOL_ERROR, "RST_STREAM on stream 0"
        )
    if head.length != 4:
        raise H2Error.connection(
            Reason.FRAME_SIZE_ERROR, "RST_STREAM size is not 4"
        )


def check_window_update(head: FrameHead) raises H2Error:
    """Check the head of a `WINDOW_UPDATE` frame (RFC 9113 section 6.9).

    Args:
        head: The head.

    Raises:
        H2Error: A connection error `FRAME_SIZE_ERROR` for a size that is
            not 4.
    """
    if head.length != 4:
        raise H2Error.connection(
            Reason.FRAME_SIZE_ERROR, "WINDOW_UPDATE size is not 4"
        )


def check_priority(
    head: FrameHead, p: Pointer[UInt8, _], at: Int
) raises H2Error:
    """Check a `PRIORITY` frame (RFC 9113 section 6.3).

    Args:
        head: The head.
        p: The bytes.
        at: The offset of the payload.

    Raises:
        H2Error: A connection error `PROTOCOL_ERROR` on stream 0; a stream
            error `FRAME_SIZE_ERROR` for a size that is not 5, and
            `PROTOCOL_ERROR` for a stream that depends on itself.
    """
    if head.stream_id == 0:
        raise H2Error.connection(Reason.PROTOCOL_ERROR, "PRIORITY on stream 0")
    if head.length != 5:
        raise H2Error.stream(
            head.stream_id, Reason.FRAME_SIZE_ERROR, "PRIORITY size is not 5"
        )
    if read_u31(p, at) == head.stream_id:
        raise H2Error.stream(
            head.stream_id, Reason.PROTOCOL_ERROR, "stream depends on itself"
        )


def _strip_padding(
    head: FrameHead, p: Pointer[UInt8, _], at: Int
) raises H2Error -> Tuple[Int, Int]:
    """Return the payload of a frame without its padding."""
    if not head.has(PADDED):
        return (at, at + head.length)
    if head.length == 0:
        raise H2Error.connection(
            Reason.FRAME_SIZE_ERROR, "padded frame without a pad length"
        )
    var pad = Int(p[unsafe_offset=at])
    if pad >= head.length:
        raise H2Error.connection(
            Reason.PROTOCOL_ERROR, "padding is longer than the payload"
        )
    return (at + 1, at + head.length - pad)


def data_payload(
    head: FrameHead, p: Pointer[UInt8, _], at: Int
) raises H2Error -> Tuple[Int, Int]:
    """Return the content of a `DATA` frame (RFC 9113 section 6.1).

    Args:
        head: The head.
        p: The bytes.
        at: The offset of the payload.

    Returns:
        The start and end offsets of the content, without padding.

    Raises:
        H2Error: A connection error: `PROTOCOL_ERROR` for padding that
            fills the payload, `FRAME_SIZE_ERROR` for a padded frame without
            a pad length.
    """
    return _strip_padding(head, p, at)


def headers_payload(
    head: FrameHead, p: Pointer[UInt8, _], at: Int
) raises H2Error -> Tuple[Int, Int, Int]:
    """Return the header block fragment of a `HEADERS` frame (RFC 9113
    section 6.2), without padding and priority, and its dependency.

    A stream that depends on itself is a stream error `PROTOCOL_ERROR`.
    The caller raises it after it decodes the block, so that the HPACK state
    stays in step.

    Args:
        head: The head.
        p: The bytes.
        at: The offset of the payload.

    Returns:
        The start and end offsets of the fragment, and the stream that the
        stream depends on, or -1 without a priority.

    Raises:
        H2Error: A connection error for bad padding, or `FRAME_SIZE_ERROR`
            for a priority that does not fit.
    """
    var bounds = _strip_padding(head, p, at)
    if not head.has(PRIORITY_FLAG):
        return (bounds[0], bounds[1], -1)
    if bounds[1] - bounds[0] < 5:
        raise H2Error.connection(
            Reason.FRAME_SIZE_ERROR, "HEADERS priority does not fit"
        )
    return (bounds[0] + 5, bounds[1], read_u31(p, bounds[0]))
