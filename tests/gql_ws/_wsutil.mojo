# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_ws suites: raw frames, and the output of a
`WebSocket` as bytes and as frames."""

from gql_ws.frame import OpCode, apply_mask, parse_header, write_header
from gql_ws.protocol import Message, WebSocket


def raw(
    opcode: OpCode,
    payload: Span[UInt8, _],
    fin: Bool = True,
    masked: Bool = True,
    rsv: UInt8 = 0,
) -> List[UInt8]:
    """Make one frame as a peer sends it."""
    var out = List[UInt8]()
    var mask: UInt32 = 0x12345678
    write_header(out, fin, opcode, len(payload), masked, mask)
    out[0] = out[0] | rsv
    var start = len(out)
    out.extend(payload)
    if masked:
        apply_mask(out.unsafe_ptr(), start, len(payload), mask)
    return out^


def text_frame(
    text: StringSlice, fin: Bool = True, masked: Bool = True
) -> List[UInt8]:
    """Make a text frame."""
    return raw(OpCode.TEXT, text.as_bytes(), fin, masked)


def close_frame(
    code: Int, reason: StringSlice = "", masked: Bool = True
) -> List[UInt8]:
    """Make a close frame with a code and a reason."""
    var payload = List[UInt8]()
    payload.append(UInt8(code >> 8))
    payload.append(UInt8(code & 0xFF))
    payload.extend(reason.as_bytes())
    return raw(OpCode.CLOSE, payload, True, masked)


def take_output(mut ws: WebSocket) -> List[UInt8]:
    """Take every byte of the output."""
    var out = List[UInt8]()
    var count = ws.pending()
    var at = ws.output()
    var index = 0
    while index < count:
        out.append(at[unsafe_offset=index])
        index += 1
    ws.advance(count)
    return out^


@fieldwise_init
struct Seen(Copyable, Movable):
    """One frame of an output, unmasked."""

    var opcode: OpCode
    var fin: Bool
    var payload: List[UInt8]
    var masked: Bool

    def code(self) -> Int:
        """The code of a close frame, or 0."""
        if len(self.payload) < 2:
            return 0
        return (Int(self.payload[0]) << 8) | Int(self.payload[1])

    def text(self) -> String:
        """The payload as text."""
        return String(unsafe_from_utf8=Span(self.payload))


def frames(data: List[UInt8]) -> List[Seen]:
    """Split bytes into frames, and unmask them."""
    var out = List[Seen]()
    var copy = data.copy()
    var at = 0
    while at < len(copy):
        var header = parse_header(copy.unsafe_ptr(), at, len(copy))
        var start = at + header.size
        var length = Int(header.length)
        if header.masked:
            apply_mask(copy.unsafe_ptr(), start, length, header.mask)
        var payload = List[UInt8](Span(copy)[start : start + length])
        out.append(
            Seen(header.opcode, header.is_final, payload^, header.masked)
        )
        at = start + length
    return out^


def feed(mut ws: WebSocket, data: List[UInt8]):
    """Give bytes to a WebSocket."""
    ws.receive(data)


def next(mut ws: WebSocket, mut message: Message) raises -> Bool:
    """Read a message."""
    return ws.read(message)
