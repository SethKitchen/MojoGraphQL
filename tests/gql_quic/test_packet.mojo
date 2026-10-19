# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.packet`.

Upstream: quinn-proto 0.11.19 (8192ed3) quinn-proto/src/packet.rs, the
`tests` module: `roundtrip_packet_numbers`, `pn_encode`,
`pn_expand_roundtrip`, and the unprotected part of `header_encoding`
(the protected bytes need `crypto`). The other tests cover each header
form and each error of `ProtectedHeader::decode`, and the example of RFC
9000 appendix A.3.
"""

from gql_quic.cid import ConnectionId
from gql_quic.packet import (
    QUIC_VERSION_1,
    HeaderMarks,
    LongType,
    PacketHeader,
    SpaceId,
    decode_packet_number,
    first_byte_mask,
    key_phase,
    packet_number_len,
    parse_header,
    parse_version_negotiation,
    pn_len_from_first,
    reserved_bits_valid,
    set_length,
    write_long_header,
    write_packet_number,
    write_short_header,
    write_version_negotiation,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(UInt8(v))
    return out^


def _parse_error(
    data: List[UInt8], local_cid_len: Int = 0, grease: Bool = False
) -> String:
    try:
        _ = parse_header(Span(data), 0, local_cid_len, grease)
    except e:
        return String(e)
    return "no error"


def _check_pn(full: UInt64, length: Int, wire: List[UInt8]) raises:
    var out = List[UInt8]()
    write_packet_number(out, full, length)
    assert_true(out == wire, String(full))


def test_roundtrip_packet_numbers() raises:
    _check_pn(0x7F, 1, _bytes(0x7F))
    _check_pn(0x80, 2, _bytes(0x00, 0x80))
    _check_pn(0x3FFF, 2, _bytes(0x3F, 0xFF))
    _check_pn(0x4000, 4, _bytes(0, 0, 0x40, 0))
    _check_pn(0xFFFFFFFF, 4, _bytes(0xFF, 0xFF, 0xFF, 0xFF))
    _check_pn(0x123456, 3, _bytes(0x12, 0x34, 0x56))


def test_pn_encode() raises:
    assert_equal(packet_number_len(0x10, 0), 1)
    _check_pn(0x10, 1, _bytes(0x10))
    assert_equal(packet_number_len(0x100, 0), 2)
    _check_pn(0x100, 2, _bytes(0x01, 0x00))
    assert_equal(packet_number_len(0x10000, 0), 3)
    _check_pn(0x10000, 3, _bytes(0x01, 0x00, 0x00))
    assert_equal(packet_number_len(0x1000000, 0), 4)
    # No packet acknowledged yet.
    assert_equal(packet_number_len(0, -1), 1)
    assert_equal(packet_number_len(127, -1), 2)
    assert_equal(packet_number_len(126, -1), 1)


def test_pn_expand_roundtrip() raises:
    var bad = 0
    for expected in range(1024):
        for actual in range(expected, 1024):
            var full = UInt64(actual)
            var length = packet_number_len(full, Int64(expected))
            var mask = (UInt64(1) << UInt64(8 * length)) - 1
            var got = decode_packet_number(
                UInt64(expected), full & mask, length
            )
            if got != full:
                bad += 1
    assert_equal(bad, 0)


def test_rfc9000_a3_example() raises:
    assert_equal(decode_packet_number(0xA82F30EB, 0x9B32, 2), 0xA82F9B32)
    # The candidate is a window too high.
    assert_equal(decode_packet_number(300, 0xF0, 1), 240)
    # High, but not above the window.
    assert_equal(decode_packet_number(0, 200, 1), 200)
    # A window too low.
    assert_equal(decode_packet_number(250, 2, 1), 258)


def test_header_encoding() raises:
    var dcid = ConnectionId(
        Span(_bytes(0x06, 0xB8, 0x58, 0xEC, 0x6F, 0x80, 0x45, 0x2B))
    )
    var out = List[UInt8]()
    var marks = write_long_header(
        out,
        LongType.INITIAL,
        QUIC_VERSION_1,
        dcid,
        ConnectionId(),
        Span(List[UInt8]()),
        0,
        1,
    )
    # 16 bytes of payload and a 16-byte AEAD tag.
    set_length(out, marks, len(out) + 16 + 16)
    var want = _bytes(0xC0, 0, 0, 0, 1, 8, 0x06, 0xB8, 0x58, 0xEC, 0x6F)
    want.extend(Span(_bytes(0x80, 0x45, 0x2B, 0, 0, 0x40, 0x21, 0)))
    assert_true(out == want)
    assert_equal(marks.header_start, 0)
    assert_equal(marks.length_at, 16)
    assert_equal(marks.pn_at, 18)
    assert_equal(marks.header_len(), 19)
    out.resize(len(out) + 32, 0)
    var h = parse_header(Span(out), 0, 8)
    assert_true(h.is_long)
    assert_true(h.long_type == LongType.INITIAL)
    assert_true(h.space() == SpaceId.INITIAL)
    assert_equal(h.version, QUIC_VERSION_1)
    assert_true(h.dcid == dcid)
    assert_equal(h.scid.len(), 0)
    assert_equal(h.token_len, 0)
    assert_equal(h.pn_offset, 18)
    assert_equal(h.end, len(out))
    assert_true(h.fixed_bit)
    assert_true(h.is_supported_version())
    assert_equal(pn_len_from_first(h.first), 1)


def test_initial_token_and_coalesced() raises:
    var dcid = ConnectionId(Span(_bytes(1, 2, 3, 4)))
    var scid = ConnectionId(Span(_bytes(5, 6)))
    var out = List[UInt8]()
    var token = _bytes(0xAA, 0xBB, 0xCC)
    var m1 = write_long_header(
        out, LongType.INITIAL, QUIC_VERSION_1, dcid, scid, Span(token), 7, 2
    )
    out.resize(len(out) + 20, 0)
    set_length(out, m1, len(out))
    var second = len(out)
    var m2 = write_long_header(
        out, LongType.HANDSHAKE, QUIC_VERSION_1, dcid, scid, Span(token), 9, 4
    )
    out.resize(len(out) + 20, 0)
    set_length(out, m2, len(out))
    var third = len(out)
    var m3 = write_long_header(
        out, LongType.ZERO_RTT, QUIC_VERSION_1, dcid, scid, Span(token), 1, 1
    )
    out.resize(len(out) + 20, 0)
    set_length(out, m3, len(out))
    var h = parse_header(Span(out), 0, 4)
    assert_equal(
        String(Span(out)[h.token_start : h.token_start + h.token_len]),
        String(Span(token)),
    )
    assert_equal(h.end, second)
    assert_true(h.scid == scid)
    h = parse_header(Span(out), h.end, 4)
    assert_true(h.long_type == LongType.HANDSHAKE)
    assert_true(h.space() == SpaceId.HANDSHAKE)
    assert_equal(h.start, second)
    assert_equal(h.token_len, 0)
    assert_equal(h.end, third)
    assert_equal(pn_len_from_first(out[second]), 4)
    h = parse_header(Span(out), h.end, 4)
    assert_true(h.long_type == LongType.ZERO_RTT)
    assert_true(h.space() == SpaceId.DATA)
    assert_equal(h.end, len(out))


def test_short_header() raises:
    var dcid = ConnectionId(Span(_bytes(1, 2, 3, 4, 5, 6, 7, 8)))
    var out = List[UInt8]()
    var marks = write_short_header(out, True, True, dcid, 0x1234, 2)
    assert_equal(out[0], 0x65)
    assert_equal(marks.length_at, -1)
    assert_equal(marks.pn_at, 9)
    set_length(out, marks, 100)
    assert_equal(out[9], 0x12)
    assert_equal(out[10], 0x34)
    out.resize(40, 0)
    var h = parse_header(Span(out), 0, 8)
    assert_false(h.is_long)
    assert_true(h.spin)
    assert_true(h.dcid == dcid)
    assert_equal(h.pn_offset, 9)
    assert_equal(h.end, 40)
    assert_true(h.space() == SpaceId.DATA)
    assert_true(h.is_supported_version())
    out.clear()
    _ = write_short_header(out, False, False, dcid, 1, 1)
    assert_equal(out[0], 0x40)
    out.resize(30, 0)
    assert_false(parse_header(Span(out), 0, 8).spin)


def test_first_byte_helpers() raises:
    assert_equal(first_byte_mask(True), 0x0F)
    assert_equal(first_byte_mask(False), 0x1F)
    assert_equal(pn_len_from_first(0x43), 4)
    assert_true(key_phase(0x44))
    assert_false(key_phase(0x40))
    assert_true(reserved_bits_valid(0xC3, True))
    assert_false(reserved_bits_valid(0xC4, True))
    assert_true(reserved_bits_valid(0x47, False))
    assert_false(reserved_bits_valid(0x48, False))


def test_retry() raises:
    var dcid = ConnectionId(Span(_bytes(1, 2)))
    var scid = ConnectionId(Span(_bytes(3, 4, 5)))
    var out = List[UInt8]()
    var token = _bytes(9, 9, 9, 9, 9)
    var marks = write_long_header(
        out, LongType.RETRY, QUIC_VERSION_1, dcid, scid, Span(token), 0, 1
    )
    assert_equal(marks.pn_at, -1)
    assert_equal(marks.header_len(), 0)
    assert_equal(out[0], 0xF0)
    set_length(out, marks, 50)
    out.resize(len(out) + 16, 0xEE)
    var h = parse_header(Span(out), 0, 0)
    assert_true(h.long_type == LongType.RETRY)
    assert_equal(h.token_start, 12)
    assert_equal(h.token_len, 5)
    assert_equal(h.pn_offset, -1)
    assert_equal(h.end, len(out))
    assert_true(h.space() == SpaceId.DATA)
    out.resize(len(out) - 6, 0)
    assert_equal(
        _parse_error(out), "PROTOCOL_VIOLATION: invalid header: retry too short"
    )


def test_version_negotiation() raises:
    var dcid = ConnectionId(Span(_bytes(1, 2, 3)))
    var scid = ConnectionId(Span(_bytes(4)))
    var out = List[UInt8]()
    var versions: List[UInt32] = [1, 0x6B3343CF]
    write_version_negotiation(out, dcid, scid, Span(versions))
    assert_equal(out[0], 0xC0)
    out.append(0xFF)
    out.append(0xFF)
    var h = parse_header(Span(out), 0, 0)
    assert_true(h.is_version_negotiation)
    assert_equal(h.version, 0)
    assert_equal(h.pn_offset, -1)
    assert_false(h.is_supported_version())
    assert_true(parse_version_negotiation(Span(out), h) == versions)
    out.clear()
    write_version_negotiation(out, dcid, scid, Span(List[UInt32]()))
    h = parse_header(Span(out), 0, 0)
    assert_equal(len(parse_version_negotiation(Span(out), h)), 0)


def test_unsupported_version() raises:
    var out = List[UInt8]()
    _ = write_long_header(
        out,
        LongType.INITIAL,
        0xFF00001D,
        ConnectionId(Span(_bytes(1))),
        ConnectionId(),
        Span(List[UInt8]()),
        0,
        1,
    )
    var h = parse_header(Span(out), 0, 0)
    assert_true(h.is_long)
    assert_false(h.is_version_negotiation)
    assert_false(h.is_supported_version())
    assert_equal(h.pn_offset, -1)
    assert_equal(h.end, len(out))


def test_header_errors() raises:
    var end = "PROTOCOL_VIOLATION: invalid header: unexpected end of packet"
    var cid = "PROTOCOL_VIOLATION: invalid header: malformed cid"
    assert_equal(_parse_error(List[UInt8]()), end)
    assert_equal(
        _parse_error(_bytes(0x00, 1, 2)),
        "PROTOCOL_VIOLATION: invalid header: fixed bit unset",
    )
    assert_equal(_parse_error(_bytes(0x00, 1, 2), 2, True), "no error")
    assert_equal(
        _parse_error(_bytes(0x40, 1, 2), 4),
        "PROTOCOL_VIOLATION: invalid header: packet too small",
    )
    assert_equal(_parse_error(_bytes(0xC0, 0, 0)), end)
    assert_equal(_parse_error(_bytes(0xC0, 0, 0, 0, 1)), cid)
    assert_equal(_parse_error(_bytes(0xC0, 0, 0, 0, 1, 21)), cid)
    assert_equal(_parse_error(_bytes(0xC0, 0, 0, 0, 1, 4, 1, 2)), cid)
    assert_equal(_parse_error(_bytes(0xC0, 0, 0, 0, 1, 0, 0)), end)
    assert_equal(
        _parse_error(_bytes(0xC0, 0, 0, 0, 1, 0, 0, 5, 1)),
        "PROTOCOL_VIOLATION: invalid header: token out of bounds",
    )
    assert_equal(
        _parse_error(_bytes(0xC0, 0, 0, 0, 1, 0, 0, 0, 9, 1)),
        (
            "PROTOCOL_VIOLATION: invalid header: packet too short to contain"
            " payload length"
        ),
    )
    assert_equal(_parse_error(_bytes(0xE0, 0, 0, 0, 1, 0, 0, 0x40)), end)


def test_kinds() raises:
    assert_true(SpaceId.DATA.is_valid())
    assert_false(SpaceId(3).is_valid())
    assert_equal(String(SpaceId.INITIAL), "Initial")
    assert_equal(String(SpaceId.HANDSHAKE), "Handshake")
    assert_equal(String(SpaceId(3)), "invalid")
    assert_true(LongType.RETRY.is_valid())
    assert_false(LongType(4).is_valid())
    assert_equal(String(LongType.ZERO_RTT), "0-RTT")
    assert_equal(String(LongType(4)), "invalid")
    var m = HeaderMarks(0, 16, 18, 1)
    assert_equal(
        String(m), "HeaderMarks(start=0, length_at=16, pn_at=18, pn_len=1)"
    )
    assert_true(m == HeaderMarks(0, 16, 18, 1))
    var h = PacketHeader(5)
    assert_equal(h.start, 5)
    assert_equal(h.pn_offset, -1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
