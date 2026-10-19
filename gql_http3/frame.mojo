# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""HTTP/3 frames, stream types and settings (RFC 9114 sections 6.2, 7 and
11.2).

A frame is a type and a length, both variable-length integers, then the
payload. `parse_frame_head` reads the two integers at an offset.
`FrameReader` takes the bytes of a stream as they arrive, and hands out
one frame at a time: a whole payload for a control frame, and DATA
payloads in pieces, as upstream's `FrameStream` does. It skips frames of
unknown and reserved types (section 9), and refuses the HTTP/2 frame types
0x2, 0x6, 0x8 and 0x9 with `H3_FRAME_UNEXPECTED` (section 7.2.8).

`Settings` holds the parameters of a SETTINGS frame. Decoding ignores
unknown identifiers, and refuses the HTTP/2 identifiers 0x0 and 0x2 to 0x5
and a repeated identifier with `H3_SETTINGS_ERROR` (section 7.2.4.1).

This module ports `h3/src/proto/frame.rs`, `h3/src/proto/stream.rs` and
`h3/src/frame.rs` of hyperium/h3 h3-v0.0.8 (22c1aa3), MIT.

Differences from upstream: the stream reader is a buffer that the caller
feeds, in place of a poll function over a QUIC stream. It skips an unknown
frame as its bytes arrive, where upstream waits for the whole frame. It
refuses a control frame larger than `max_frame_size` with
`H3_EXCESSIVE_LOAD`; upstream has no limit. A setting value of
ENABLE_CONNECT_PROTOCOL or H3_DATAGRAM other than 0 or 1 is
`H3_SETTINGS_ERROR` (RFC 9220 section 3, RFC 9297 section 2.1.1). The
WebTransport frame and stream types are not ported. A grease value takes
its `N` from the caller in place of a random number.
"""

from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.varint import (
    Progress,
    decode_varint,
    encode_varint,
    varint_size,
)


@always_inline
def _is_reserved(value: UInt64) -> Bool:
    """Return True for a reserved value: `0x1f * N + 0x21`."""
    return value >= 0x21 and (value - 0x21) % 0x1F == 0


@fieldwise_init
struct FrameType(Equatable, ImplicitlyCopyable, Writable):
    """A frame type (RFC 9114 section 7.2), as a type and not a bare integer."""

    var value: UInt64
    """The type as it goes on the wire."""

    comptime DATA = FrameType(0x0)
    """Content of a request or a response."""
    comptime HEADERS = FrameType(0x1)
    """A QPACK field section."""
    comptime H2_PRIORITY = FrameType(0x2)
    """The HTTP/2 PRIORITY type, which HTTP/3 forbids."""
    comptime CANCEL_PUSH = FrameType(0x3)
    """Cancels a server push."""
    comptime SETTINGS = FrameType(0x4)
    """The connection parameters, first on the control stream."""
    comptime PUSH_PROMISE = FrameType(0x5)
    """Announces a server push."""
    comptime H2_PING = FrameType(0x6)
    """The HTTP/2 PING type, which HTTP/3 forbids."""
    comptime GOAWAY = FrameType(0x7)
    """Starts the graceful close of a connection."""
    comptime H2_WINDOW_UPDATE = FrameType(0x8)
    """The HTTP/2 WINDOW_UPDATE type, which HTTP/3 forbids."""
    comptime H2_CONTINUATION = FrameType(0x9)
    """The HTTP/2 CONTINUATION type, which HTTP/3 forbids."""
    comptime MAX_PUSH_ID = FrameType(0xD)
    """The largest push id that the client accepts."""

    @staticmethod
    def grease(n: UInt64) -> FrameType:
        """Return a reserved type, which a peer must ignore.

        Args:
            n: Any number below 0x210842108421083.

        Returns:
            The type `0x1f * n + 0x21`.
        """
        return FrameType(0x1F * n + 0x21)

    def is_valid(self) -> Bool:
        """Return True for a type that RFC 9114 defines for HTTP/3.

        Returns:
            Whether the type is DATA, HEADERS, CANCEL_PUSH, SETTINGS,
            PUSH_PROMISE, GOAWAY or MAX_PUSH_ID.
        """
        var v = self.value
        return v <= 0x7 and not self.is_http2_only() or v == 0xD

    def is_http2_only(self) -> Bool:
        """Return True for an HTTP/2 type that HTTP/3 forbids.

        Returns:
            Whether the type is 0x2, 0x6, 0x8 or 0x9.
        """
        var v = self.value
        return v == 0x2 or v == 0x6 or v == 0x8 or v == 0x9

    def is_reserved(self) -> Bool:
        """Return True for a reserved (grease) type.

        Returns:
            Whether the type is `0x1f * N + 0x21`.
        """
        return _is_reserved(self.value)

    def write_to(self, mut writer: Some[Writer]):
        """Write the type in hexadecimal, such as `0x4`.

        Args:
            writer: The destination.
        """
        writer.write(hex(self.value))


@fieldwise_init
struct StreamType(Equatable, ImplicitlyCopyable, Writable):
    """The type of a unidirectional stream (RFC 9114 section 6.2)."""

    var value: UInt64
    """The type as it goes on the wire."""

    comptime CONTROL = StreamType(0x00)
    """The control stream: SETTINGS first, then control frames."""
    comptime PUSH = StreamType(0x01)
    """A server push stream."""
    comptime QPACK_ENCODER = StreamType(0x02)
    """The QPACK encoder stream (RFC 9204 section 4.2)."""
    comptime QPACK_DECODER = StreamType(0x03)
    """The QPACK decoder stream (RFC 9204 section 4.2)."""

    @staticmethod
    def grease(n: UInt64) -> StreamType:
        """Return a reserved type, which a peer must ignore.

        Args:
            n: Any number below 0x210842108421083.

        Returns:
            The type `0x1f * n + 0x21`.
        """
        return StreamType(0x1F * n + 0x21)

    def is_valid(self) -> Bool:
        """Return True for a type that RFC 9114 or RFC 9204 defines.

        Returns:
            Whether the type is from 0x00 to 0x03.
        """
        return self.value <= 0x03

    def is_reserved(self) -> Bool:
        """Return True for a reserved (grease) type.

        Returns:
            Whether the type is `0x1f * N + 0x21`.
        """
        return _is_reserved(self.value)

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the type, or its value.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 4] = [
            "Control",
            "Push",
            "Encoder",
            "Decoder",
        ]
        if self.is_valid():
            writer.write(materialize[names]()[Int(self.value)])
        else:
            writer.write("StreamType(", self.value, ")")


def write_stream_type(mut out: List[UInt8], stream_type: StreamType):
    """Append the type that starts a unidirectional stream.

    Args:
        out: The destination.
        stream_type: The type.
    """
    encode_varint(stream_type.value, out)


@fieldwise_init
struct SettingId(Equatable, ImplicitlyCopyable, Writable):
    """A setting identifier (RFC 9114 section 7.2.4.1)."""

    var value: UInt64
    """The identifier as it goes on the wire."""

    comptime QPACK_MAX_TABLE_CAPACITY = SettingId(0x1)
    """The largest QPACK dynamic table that the decoder allows."""
    comptime MAX_FIELD_SECTION_SIZE = SettingId(0x6)
    """The largest field section that the endpoint accepts."""
    comptime QPACK_BLOCKED_STREAMS = SettingId(0x7)
    """How many streams can wait for QPACK entries."""
    comptime ENABLE_CONNECT_PROTOCOL = SettingId(0x8)
    """Extended CONNECT (RFC 9220); 0 or 1."""
    comptime H3_DATAGRAM = SettingId(0x33)
    """HTTP datagrams (RFC 9297); 0 or 1."""

    @staticmethod
    def grease(n: UInt64) -> SettingId:
        """Return a reserved identifier, which a peer must ignore.

        Args:
            n: Any number below 0x210842108421083.

        Returns:
            The identifier `0x1f * n + 0x21`.
        """
        return SettingId(0x1F * n + 0x21)

    def is_valid(self) -> Bool:
        """Return True for an identifier that this package supports.

        Returns:
            Whether the identifier is one of the five constants.
        """
        var v = self.value
        return v == 0x1 or v == 0x6 or v == 0x7 or v == 0x8 or v == 0x33

    def is_forbidden(self) -> Bool:
        """Return True for an HTTP/2 identifier that HTTP/3 forbids.

        Returns:
            Whether the identifier is 0x0, or from 0x2 to 0x5.
        """
        return self.value == 0 or (self.value >= 2 and self.value <= 5)

    def is_boolean(self) -> Bool:
        """Return True for an identifier whose value must be 0 or 1.

        Returns:
            Whether it is ENABLE_CONNECT_PROTOCOL or H3_DATAGRAM.
        """
        return self.value == 0x8 or self.value == 0x33

    def write_to(self, mut writer: Some[Writer]):
        """Write the identifier in hexadecimal.

        Args:
            writer: The destination.
        """
        writer.write(hex(self.value))


comptime SETTINGS_LEN = 8
"""The most parameters that a `Settings` holds, as upstream."""


def _settings_error(message: String) -> H3Error:
    """Return an `H3_SETTINGS_ERROR`."""
    return H3Error(H3ErrorCode.H3_SETTINGS_ERROR, message)


def frame_error(message: String) -> H3Error:
    """Return an `H3_FRAME_ERROR`.

    Args:
        message: The description.

    Returns:
        The error.
    """
    return H3Error(H3ErrorCode.H3_FRAME_ERROR, message)


struct Settings(Copyable, Movable, Writable):
    """The parameters of a SETTINGS frame, in order."""

    var ids: List[SettingId]
    """The identifier of each parameter."""
    var values: List[UInt64]
    """The value of each parameter."""

    def __init__(out self):
        """Make an empty set of parameters."""
        self.ids = List[SettingId]()
        self.values = List[UInt64]()

    def count(self) -> Int:
        """Return the number of parameters.

        Returns:
            The count.
        """
        return len(self.ids)

    def insert(mut self, id: SettingId, value: UInt64) raises H3Error:
        """Add a parameter.

        Args:
            id: The identifier.
            value: The value, at most `VARINT_MAX`.

        Raises:
            H3Error: `H3_SETTINGS_ERROR` for a repeated identifier, or more
                than `SETTINGS_LEN` parameters.
        """
        if len(self.ids) >= SETTINGS_LEN:
            raise _settings_error("too many settings")
        if id in self.ids:
            raise _settings_error(String("setting ", id, " repeated"))
        self.ids.append(id)
        self.values.append(value)

    def get(self, id: SettingId) -> Optional[UInt64]:
        """Return the value of a parameter.

        Args:
            id: The identifier.

        Returns:
            The value, or None when the frame did not hold it.
        """
        var index = 0
        while index < len(self.ids):
            if self.ids[index] == id:
                return self.values[index]
            index += 1
        return None

    def get_or(self, id: SettingId, default: UInt64) -> UInt64:
        """Return the value of a parameter, or its default.

        Args:
            id: The identifier.
            default: The value of an absent parameter.

        Returns:
            The value.
        """
        var found = self.get(id)
        if found:
            return found.value()
        return default

    def payload_size(self) -> Int:
        """Return the size of the payload of the frame.

        Returns:
            The bytes of the identifiers and the values.
        """
        var size = 0
        var index = 0
        while index < len(self.ids):
            size += varint_size(self.ids[index].value)
            size += varint_size(self.values[index])
            index += 1
        return size

    def encode(self, mut out: List[UInt8]):
        """Append the SETTINGS frame: its header and its payload.

        Args:
            out: The destination.
        """
        write_frame_header(out, FrameType.SETTINGS, self.payload_size())
        var index = 0
        while index < len(self.ids):
            encode_varint(self.ids[index].value, out)
            encode_varint(self.values[index], out)
            index += 1

    @staticmethod
    def decode(payload: Span[UInt8, _]) raises H3Error -> Settings:
        """Read the payload of a SETTINGS frame.

        Args:
            payload: The payload.

        Returns:
            The supported parameters; the others are ignored.

        Raises:
            H3Error: `H3_FRAME_ERROR` for a truncated parameter;
                `H3_SETTINGS_ERROR` for a forbidden or repeated identifier,
                or a boolean value other than 0 or 1.
        """
        var settings = Settings()
        var at = 0
        while at < len(payload):
            if len(payload) - at < 2:
                raise frame_error("malformed settings frame")
            var id = decode_varint(payload, at)
            if not id.complete():
                raise frame_error("malformed settings frame")
            var value = decode_varint(payload, id.end)
            if not value.complete():
                raise frame_error("malformed settings frame")
            at = value.end
            var setting = SettingId(id.value)
            if setting.is_forbidden():
                raise _settings_error(
                    String("setting id ", setting, " is invalid")
                )
            if setting.is_boolean() and value.value > 1:
                raise _settings_error(
                    String(
                        "setting ", setting, " has invalid value ", value.value
                    )
                )
            if setting.is_valid():
                settings.insert(setting, value.value)
        return settings^

    def write_to(self, mut writer: Some[Writer]):
        """Write each parameter as `id=value`.

        Args:
            writer: The destination.
        """
        writer.write("Settings(")
        var index = 0
        while index < len(self.ids):
            if index > 0:
                writer.write(", ")
            writer.write(self.ids[index], "=", self.values[index])
            index += 1
        writer.write(")")


@fieldwise_init
struct FrameHead(ImplicitlyCopyable, Writable):
    """The result of `parse_frame_head`."""

    var status: Progress
    """`COMPLETE`, or `INCOMPLETE` when the bytes end inside the head."""
    var type: FrameType
    """The frame type."""
    var payload_start: Int
    """The offset of the first byte of the payload."""
    var length: Int
    """The length of the payload."""

    def complete(self) -> Bool:
        """Return True when the head was read.

        Returns:
            Whether the status is `COMPLETE`.
        """
        return self.status == Progress.COMPLETE

    def payload_end(self) -> Int:
        """Return the offset after the payload.

        Returns:
            `payload_start + length`.
        """
        return self.payload_start + self.length

    def write_to(self, mut writer: Some[Writer]):
        """Write the status, the type, the start and the length.

        Args:
            writer: The destination.
        """
        writer.write(
            self.status,
            " type ",
            self.type,
            " at ",
            self.payload_start,
            " length ",
            self.length,
        )


@always_inline
def parse_frame_head(data: Span[UInt8, _], start: Int) -> FrameHead:
    """Read the type and the length of a frame.

    The payload need not be there yet.

    Args:
        data: The bytes.
        start: The offset of the frame.

    Returns:
        The head, or an `INCOMPLETE` result.
    """
    var type = decode_varint(data, start)
    if type.complete():
        var length = decode_varint(data, type.end)
        if length.complete():
            return FrameHead(
                Progress.COMPLETE,
                FrameType(type.value),
                length.end,
                Int(length.value),
            )
    return FrameHead(Progress.INCOMPLETE, FrameType.DATA, start, 0)


def write_frame_header(mut out: List[UInt8], type: FrameType, length: Int):
    """Append the type and the length of a frame.

    Args:
        out: The destination.
        type: The frame type.
        length: The length of the payload that follows.
    """
    encode_varint(type.value, out)
    encode_varint(UInt64(length), out)


def write_data_frame(mut out: List[UInt8], payload: Span[UInt8, _]):
    """Append a DATA frame.

    Args:
        out: The destination.
        payload: The content.
    """
    write_frame_header(out, FrameType.DATA, len(payload))
    out.extend(payload)


def write_headers_frame(mut out: List[UInt8], block: Span[UInt8, _]):
    """Append a HEADERS frame.

    Args:
        out: The destination.
        block: The QPACK field section.
    """
    write_frame_header(out, FrameType.HEADERS, len(block))
    out.extend(block)


def write_push_promise_frame(
    mut out: List[UInt8], push_id: UInt64, block: Span[UInt8, _]
):
    """Append a PUSH_PROMISE frame.

    Args:
        out: The destination.
        push_id: The push id.
        block: The QPACK field section of the promised request.
    """
    write_frame_header(
        out, FrameType.PUSH_PROMISE, varint_size(push_id) + len(block)
    )
    encode_varint(push_id, out)
    out.extend(block)


def write_varint_frame(mut out: List[UInt8], type: FrameType, value: UInt64):
    """Append a frame whose payload is one integer.

    Args:
        out: The destination.
        type: CANCEL_PUSH, GOAWAY or MAX_PUSH_ID.
        value: The push id or the stream id.
    """
    write_frame_header(out, type, varint_size(value))
    encode_varint(value, out)


def write_goaway_frame(mut out: List[UInt8], id: UInt64):
    """Append a GOAWAY frame.

    Args:
        out: The destination.
        id: The first stream id (or push id) that the sender will not
            process.
    """
    write_varint_frame(out, FrameType.GOAWAY, id)


def write_grease_frame(mut out: List[UInt8], n: UInt64):
    """Append a frame of a reserved type with the payload `grease`.

    Args:
        out: The destination.
        n: The `N` of the reserved type.
    """
    write_frame_header(out, FrameType.grease(n), 6)
    out.extend(StaticString("grease").as_bytes())


def decode_varint_payload(payload: Span[UInt8, _]) raises H3Error -> UInt64:
    """Read the payload of CANCEL_PUSH, GOAWAY or MAX_PUSH_ID.

    Args:
        payload: The payload.

    Returns:
        The integer.

    Raises:
        H3Error: `H3_FRAME_ERROR` when the payload is not one integer.
    """
    var value = decode_varint(payload, 0)
    if not value.complete() or value.end != len(payload):
        raise frame_error("frame payload is not one integer")
    return value.value


def parse_push_promise(
    payload: Span[UInt8, _]
) raises H3Error -> Tuple[UInt64, Int]:
    """Read the push id of a PUSH_PROMISE payload.

    Args:
        payload: The payload.

    Returns:
        The push id, and the offset of the field section in the payload.

    Raises:
        H3Error: `H3_FRAME_ERROR` when the push id is cut.
    """
    var value = decode_varint(payload, 0)
    if not value.complete():
        raise frame_error("truncated push promise")
    return (value.value, value.end)


comptime DEFAULT_MAX_FRAME_SIZE = 1 << 20
"""The default limit of a frame that `FrameReader` buffers: 1 MiB."""


struct FrameReader(Movable):
    """Reads the frames of one stream from bytes that arrive in pieces.

    Feed the bytes with `feed`, and the end of the stream with `finish`.
    Then call `next` until it returns False. After each True, `frame_type`
    and `payload` describe a frame. A DATA frame comes in pieces: each
    piece has `frame_type` DATA, and `data_remaining` says how many bytes
    of the frame are still to come. A DATA frame of length 0 comes once,
    with an empty payload. A payload span is valid until the next call of
    `feed` or `next`.
    """

    var max_frame_size: Int
    """The largest payload of a frame other than DATA."""
    var frame_type: FrameType
    """The type of the frame of the last True `next`."""
    var _buffer: List[UInt8]
    var _pos: Int
    var _start: Int
    """The offset of the last payload."""
    var _end: Int
    """The offset after the last payload."""
    var _data: Int
    """The bytes of the current DATA frame still to deliver."""
    var _skip: Int
    """The bytes of an unknown frame still to drop."""
    var _finished: Bool

    def __init__(out self, max_frame_size: Int = DEFAULT_MAX_FRAME_SIZE):
        """Make a reader of an empty stream.

        Args:
            max_frame_size: The largest payload of a frame other than DATA.
        """
        self.max_frame_size = max_frame_size
        self.frame_type = FrameType.DATA
        self._buffer = List[UInt8]()
        self._pos = 0
        self._start = 0
        self._end = 0
        self._data = 0
        self._skip = 0
        self._finished = False

    def feed(mut self, data: Span[UInt8, _]):
        """Add bytes that arrived on the stream.

        Args:
            data: The bytes.
        """
        if self._pos == len(self._buffer):
            self._buffer.clear()
            self._pos = 0
        elif self._pos >= 4096:
            var rest = List[UInt8](capacity=len(self._buffer) - self._pos)
            rest.extend(Span(self._buffer)[self._pos :])
            self._buffer = rest^
            self._pos = 0
        self._buffer.extend(data)

    def finish(mut self):
        """Mark the end of the stream: no more bytes come."""
        self._finished = True

    def buffered(self) -> Int:
        """Return the bytes that are fed and not yet read.

        Returns:
            The count.
        """
        return len(self._buffer) - self._pos

    def data_remaining(self) -> Int:
        """Return the bytes of the current DATA frame still to come.

        Returns:
            The count; 0 after the last piece.
        """
        return self._data

    def is_done(self) -> Bool:
        """Return True when the stream ended at a frame boundary.

        Returns:
            Whether `finish` was called, and every byte was read.
        """
        return self._finished and self.buffered() == 0 and self._data == 0

    def payload(self) -> Span[UInt8, origin_of(self._buffer)]:
        """Return the payload of the frame of the last True `next`.

        Returns:
            The bytes; a piece of the payload for DATA.
        """
        return Span(self._buffer)[self._start : self._end]

    def _wait(self) raises H3Error -> Bool:
        """Return False for more bytes, or raise at an end inside a frame."""
        if self._finished and (
            self.buffered() > 0 or self._data > 0 or self._skip > 0
        ):
            raise frame_error("stream ended inside a frame")
        return False

    def _emit(mut self, type: FrameType, start: Int, end: Int) -> Bool:
        """Describe a frame and consume its bytes."""
        self.frame_type = type
        self._start = start
        self._end = end
        self._pos = end
        return True

    def next(mut self) raises H3Error -> Bool:
        """Read the next frame, or the next piece of a DATA frame.

        Returns:
            True when a frame is ready; False when more bytes are needed,
            or when the stream is done (see `is_done`).

        Raises:
            H3Error: `H3_FRAME_UNEXPECTED` for an HTTP/2 frame type;
                `H3_EXCESSIVE_LOAD` for a frame above `max_frame_size`;
                `H3_FRAME_ERROR` when the stream ends inside a frame.
        """
        while True:
            var available = len(self._buffer) - self._pos
            if self._skip > 0:
                var dropped = min(self._skip, available)
                self._pos += dropped
                self._skip -= dropped
                if self._skip > 0:
                    return self._wait()
                continue
            if self._data > 0:
                var piece = min(self._data, available)
                if piece == 0:
                    return self._wait()
                self._data -= piece
                return self._emit(FrameType.DATA, self._pos, self._pos + piece)
            var head = parse_frame_head(Span(self._buffer), self._pos)
            if not head.complete():
                return self._wait()
            var type = head.type
            if type.is_http2_only():
                raise H3Error(
                    H3ErrorCode.H3_FRAME_UNEXPECTED,
                    String("frame ", type, " is not allowed in HTTP/3"),
                )
            if type == FrameType.DATA:
                self._pos = head.payload_start
                self._data = head.length
                if head.length == 0:
                    return self._emit(type, self._pos, self._pos)
                continue
            if not type.is_valid():
                self._pos = head.payload_start
                self._skip = head.length
                continue
            if head.length > self.max_frame_size:
                raise H3Error(
                    H3ErrorCode.H3_EXCESSIVE_LOAD,
                    String("frame ", type, " is larger than the limit"),
                )
            if head.payload_end() > len(self._buffer):
                return self._wait()
            return self._emit(type, head.payload_start, head.payload_end())
