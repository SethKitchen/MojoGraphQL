# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The mock peer of the gql_http2 suites, after h2 v0.4.20
`tests/h2-support` (`frames.rs` and `mock.rs`): it writes frames with its
own HPACK encoder, gives them to a `Connection`, and reads the frames that
the connection sends."""

from gql_http2.connection import Config, Connection, Event, EventKind, Role
from gql_http2.error import Reason
from gql_http2.frame import (
    ACK,
    END_HEADERS,
    END_STREAM,
    FrameHead,
    FrameKind,
    HEAD_SIZE,
    PREFACE,
    headers_payload,
    read_u31,
    read_u32,
    write_head,
    write_u32,
)
from gql_http2.hpack import Decoder, Encoder, HeaderList


struct Frame(Copyable, Movable):
    """One frame that a connection sent, with its block decoded."""

    var head: FrameHead
    var payload: List[UInt8]
    var fields: HeaderList

    def __init__(out self, head: FrameHead, var payload: List[UInt8]):
        self.head = head
        self.payload = payload^
        self.fields = HeaderList()

    def u32(self, at: Int) -> Int:
        """The 32-bit value at an offset of the payload."""
        return read_u32(self.payload.unsafe_ptr(), at)

    def reason(self) -> Reason:
        """The code of a `RST_STREAM` or `GOAWAY` frame."""
        if self.head.kind == FrameKind.GOAWAY:
            return Reason(UInt32(self.u32(4)))
        return Reason(UInt32(self.u32(0)))

    def field(self, name: StringSlice) -> String:
        """The value of a decoded field, or `<none>`."""
        var index = 0
        while index < self.fields.count():
            if StringSlice(unsafe_from_utf8=self.fields.name(index)) == name:
                return String(
                    StringSlice(unsafe_from_utf8=self.fields.value(index))
                )
            index += 1
        return String("<none>")

    def text(self) -> String:
        """The payload as text."""
        return String(unsafe_from_utf8=Span(self.payload))


def request(
    method: StringSlice = "GET",
    path: StringSlice = "/",
    authority: StringSlice = "example.com",
) -> HeaderList:
    """Return the fields of a request head."""
    var fields = HeaderList()
    fields.add_text(":method", method)
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", authority)
    fields.add_text(":path", path)
    return fields^


def response(status: Int = 200) -> HeaderList:
    """Return the fields of a response head."""
    var fields = HeaderList()
    fields.add_text(":status", String(status))
    return fields^


struct Peer(Movable):
    """The other end of a connection under test."""

    var encoder: Encoder
    var decoder: Decoder
    var out: List[UInt8]

    def __init__(out self):
        self.encoder = Encoder()
        self.decoder = Decoder(4096)
        self.out = List[UInt8]()

    def preface(mut self):
        self.out.extend(StaticString(PREFACE).as_bytes())

    def settings(mut self, ids: List[Int] = [], values: List[Int] = []):
        """A `SETTINGS` frame with pairs of ids and values."""
        write_head(self.out, 6 * len(ids), FrameKind.SETTINGS, 0, 0)
        var index = 0
        while index < len(ids):
            self.out.append(UInt8(ids[index] >> 8))
            self.out.append(UInt8(ids[index] & 0xFF))
            write_u32(self.out, values[index])
            index += 1

    def settings_ack(mut self):
        write_head(self.out, 0, FrameKind.SETTINGS, ACK, 0)

    def raw(
        mut self,
        kind: FrameKind,
        flags: UInt8,
        stream_id: Int,
        payload: List[UInt8] = [],
    ):
        """Any frame, as bytes."""
        write_head(self.out, len(payload), kind, flags, stream_id)
        self.out.extend(Span(payload))

    def block(mut self, fields: HeaderList) -> List[UInt8]:
        """Encode a header block with the peer's encoder."""
        var block = List[UInt8]()
        self.encoder.encode(fields, block)
        return block^

    def headers(
        mut self, stream_id: Int, fields: HeaderList, flags: UInt8 = END_HEADERS
    ):
        """A `HEADERS` frame with a whole block."""
        var block = self.block(fields)
        self.raw(FrameKind.HEADERS, flags, stream_id, block)

    def data(mut self, stream_id: Int, text: StringSlice, flags: UInt8 = 0):
        """A `DATA` frame."""
        var payload = List[UInt8]()
        payload.extend(text.as_bytes())
        self.raw(FrameKind.DATA, flags, stream_id, payload)

    def window_update(mut self, stream_id: Int, increment: Int):
        var payload = List[UInt8]()
        write_u32(payload, increment)
        self.raw(FrameKind.WINDOW_UPDATE, 0, stream_id, payload)

    def rst(mut self, stream_id: Int, reason: Reason):
        var payload = List[UInt8]()
        write_u32(payload, Int(reason.code))
        self.raw(FrameKind.RST_STREAM, 0, stream_id, payload)

    def ping(mut self, payload: UInt64, ack: Bool = False):
        var bytes = List[UInt8]()
        write_u32(bytes, Int(payload >> 32))
        write_u32(bytes, Int(payload & 0xFFFFFFFF))
        self.raw(FrameKind.PING, ACK if ack else UInt8(0), 0, bytes)

    def goaway(mut self, last: Int, reason: Reason):
        var payload = List[UInt8]()
        write_u32(payload, last)
        write_u32(payload, Int(reason.code))
        self.raw(FrameKind.GOAWAY, 0, 0, payload)

    def send(mut self, mut conn: Connection):
        """Give the frames written so far to the connection."""
        conn.receive(Span(self.out))
        self.out.clear()

    def read(mut self, mut conn: Connection) raises -> List[Frame]:
        """Take the frames that the connection sent, and decode each whole
        header block."""
        var frames = List[Frame]()
        var at = 0
        var p = conn.out.unsafe_ptr()
        var block = List[UInt8]()
        if len(conn.out) >= 24 and conn.out[0] == 80 and conn.out[1] == 82:
            at = 24  # The client preface.
        while at + HEAD_SIZE <= len(conn.out):
            var head = FrameHead.parse(p.unsafe_offset(at))
            if at + HEAD_SIZE + head.length > len(conn.out):
                raise Error("a partial frame at byte " + String(at))
            var payload = List[UInt8]()
            payload.extend(
                Span(conn.out)[at + HEAD_SIZE : at + HEAD_SIZE + head.length]
            )
            var frame = Frame(head, payload^)
            if (
                head.kind == FrameKind.HEADERS
                or head.kind == FrameKind.CONTINUATION
            ):
                if head.kind == FrameKind.HEADERS:
                    block.clear()
                    var bounds = headers_payload(head, p, at + HEAD_SIZE)
                    block.extend(Span(conn.out)[bounds[0] : bounds[1]])
                else:
                    block.extend(Span(frame.payload))
                if head.flags & END_HEADERS != 0:
                    self.decoder.decode(block, 1 << 20, frame.fields)
            frames.append(frame^)
            at += HEAD_SIZE + head.length
        conn.out.clear()
        return frames^


def kinds(frames: List[Frame]) -> String:
    """The kinds of frames, such as `SETTINGS WINDOW_UPDATE`."""
    var out = String()
    var index = 0
    while index < len(frames):
        if index > 0:
            out += " "
        out += String(frames[index].head.kind)
        index += 1
    return out^


def server(config: Config = Config()) raises -> Pair:
    """A started server connection after the preface and the settings
    exchange, with its output read."""
    var conn = Connection(Role.SERVER, config)
    conn.start()
    var peer = Peer()
    peer.preface()
    peer.settings()
    peer.settings_ack()
    peer.send(conn)
    _ = peer.read(conn)
    return Pair(conn^, peer^)


def client(config: Config = Config()) raises -> Pair:
    """A started client connection after the settings exchange."""
    var conn = Connection(Role.CLIENT, config)
    conn.start()
    var peer = Peer()
    peer.settings()
    peer.settings_ack()
    peer.send(conn)
    _ = peer.read(conn)
    return Pair(conn^, peer^)


def bytes(text: StringSlice) -> List[UInt8]:
    """The bytes of a text, as a list."""
    var out = List[UInt8]()
    out.extend(text.as_bytes())
    return out^


struct Pair(Movable):
    """A connection under test and its mock peer."""

    var conn: Connection
    var peer: Peer

    def __init__(out self, var conn: Connection, var peer: Peer):
        self.conn = conn^
        self.peer = peer^

    def send(mut self):
        """Give the peer's frames to the connection."""
        self.peer.send(self.conn)

    def read(mut self) raises -> List[Frame]:
        """Take the frames that the connection sent."""
        return self.peer.read(self.conn)


def part(data: List[UInt8], start: Int, end: Int = -1) -> List[UInt8]:
    """A copy of bytes `start` to `end` of a list; -1 for the end."""
    var stop = len(data) if end < 0 else end
    var out = List[UInt8]()
    out.extend(Span(data)[start:stop])
    return out^


def repeat(text: StringSlice, count: Int) -> String:
    """A text repeated."""
    var out = String()
    for _ in range(count):
        out += text
    return out^
