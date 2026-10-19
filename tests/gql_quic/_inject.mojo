# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Packets that a test writes frame by frame, protected with the keys of
one end of a `Pair`, as the `Pair` of quinn-proto 0.11.19
quinn-proto/src/tests/util.rs injects raw frames.

`seal_packet` appends one packet of a space to a datagram. `deliver`
gives a datagram to an end. `start_key_update` moves an end to the next
key phase, as a peer that starts a key update (RFC 9001 section 6)."""

from gql_quic.cid import ConnectionId
from gql_quic.connection import DATA, HANDSHAKE, INITIAL, Connection
from gql_quic.crypto import TAG_SIZE
from gql_quic.packet import (
    HeaderMarks,
    LongType,
    QUIC_VERSION_1,
    packet_number_len,
    set_length,
    write_long_header,
    write_short_header,
)


def seal_packet(
    mut sender: Connection,
    space: Int,
    payload: Span[UInt8, _],
    mut out: List[UInt8],
    first_or: UInt8 = 0,
    flip_phase: Bool = False,
    corrupt: Bool = False,
):
    """Append a packet of `space` with a payload of frames, protected as
    `sender` protects its packets.

    `first_or` sets bits of the first byte before the protection, such as
    the reserved bits. `flip_phase` sets the other key phase bit than the
    keys. `corrupt` changes the tag, so the packet does not open."""
    ref sp = sender.spaces[space]
    var pn = sp.next_pn
    sp.next_pn += 1
    var pn_len = packet_number_len(pn, sp.largest_acked)
    var start = len(out)
    var marks: HeaderMarks
    if space == DATA:
        marks = write_short_header(
            out,
            False,
            sender.key_phase != flip_phase,
            sender.remote_cid,
            pn,
            pn_len,
        )
    else:
        var kind = LongType.INITIAL if space == INITIAL else LongType.HANDSHAKE
        marks = write_long_header(
            out,
            kind,
            QUIC_VERSION_1,
            sender.remote_cid,
            sender.local_cid,
            List[UInt8](),
            pn,
            pn_len,
        )
    out.extend(payload)
    var header_end = marks.pn_at + pn_len
    var size = len(out) - header_end
    if size + pn_len < 4:
        out.resize(len(out) + 4 - pn_len - size, 0)
    var payload_end = len(out)
    out.resize(payload_end + TAG_SIZE, 0)
    set_length(out, marks, payload_end + TAG_SIZE)
    out[start] |= first_or
    ref keys = sp.keys[0]
    var p = out.unsafe_ptr()
    keys.local.packet.seal(p, marks.header_start, header_end, payload_end, pn)
    keys.local.header.protect(p, marks.header_start, marks.pn_at, pn_len)
    if corrupt:
        out[len(out) - 1] ^= 1


def packet(
    mut sender: Connection,
    space: Int,
    payload: Span[UInt8, _],
    first_or: UInt8 = 0,
    flip_phase: Bool = False,
    corrupt: Bool = False,
) -> List[UInt8]:
    """Return a datagram of one packet; see `seal_packet`."""
    var out = List[UInt8]()
    seal_packet(sender, space, payload, out, first_or, flip_phase, corrupt)
    return out^


def deliver(mut receiver: Connection, now: Int, datagram: List[UInt8]):
    """Give a copy of a datagram to an end; it opens packets in place."""
    var copy = datagram.copy()
    receiver.handle_datagram(now, copy.unsafe_ptr(), len(copy))


def start_key_update(mut end: Connection):
    """Move an end to the next key phase, as a peer that starts a key
    update: it sends with the next keys, and opens the next phase."""
    ref keys = end.spaces[DATA].keys[0]
    _ = keys.local.update()
    var old = keys.remote.update()
    end.prev_remote.clear()
    end.prev_remote.append(old^)
    end.key_phase = not end.key_phase
