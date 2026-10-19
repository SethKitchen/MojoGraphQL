# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.frame`.

Upstream: quinn-proto 0.11.19 (8192ed3) quinn-proto/src/frame.rs, the
`test` module: `ack_coding`. The tests `ack_frequency_coding` and
`immediate_ack_coding` are for extension frames that are not ported. The
other tests encode and decode each frame type, and check the errors of
`Iter::try_next`.
"""

from gql_quic.cid import ConnectionId, ResetToken
from gql_quic.error import NO_FRAME, TransportErrorCode
from gql_quic.frame import (
    MAX_STREAM_COUNT,
    Frame,
    FrameType,
    ack_ranges,
    ack_size,
    check_payload,
    crypto_header_size,
    new_token_size,
    read_frame,
    stream_header_size,
    write_ack,
    write_application_close,
    write_connection_close,
    write_crypto_header,
    write_data_blocked,
    write_handshake_done,
    write_max_data,
    write_max_stream_data,
    write_max_streams,
    write_new_connection_id,
    write_new_token,
    write_padding,
    write_path_challenge,
    write_path_response,
    write_ping,
    write_reset_stream,
    write_retire_connection_id,
    write_stop_sending,
    write_stream_data_blocked,
    write_stream_header,
    write_streams_blocked,
)
from gql_quic.range_set import RangeSet
from gql_quic.shared import Dir, Side, StreamId
from gql_quic.varint import VARINT_MAX, write_varint
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _bytes(*values: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(UInt8(v))
    return out^


def _one(buf: List[UInt8]) raises -> Frame:
    """Read the only frame of a payload."""
    var pos = 0
    var f = read_frame(Span(buf), pos)
    assert_equal(pos, len(buf))
    return f^


def _error(buf: List[UInt8]) -> String:
    """Read frames until the end; return the error, or `no error`."""
    var pos = 0
    try:
        while pos < len(buf):
            _ = read_frame(Span(buf), pos)
    except e:
        return String(e)
    return "no error"


def _ack_error(buf: List[UInt8], f: Frame) -> String:
    var set = RangeSet()
    try:
        ack_ranges(Span(buf), f, set)
    except e:
        return String(e)
    return "no error"


def test_ack_coding() raises:
    var packets: List[UInt64] = [1, 2, 3, 5, 10, 11, 14]
    var ranges = RangeSet()
    for p in packets:
        _ = ranges.insert_one(p)
    var buf = List[UInt8]()
    write_ack(buf, ranges, 42, True, 42, 24, 12)
    assert_equal(ack_size(ranges, 42, True, 42, 24, 12), len(buf))
    var f = _one(buf)
    assert_true(f.type == FrameType.ACK_ECN)
    assert_false(f.is_ack_eliciting())
    assert_equal(f.ack_largest, 14)
    assert_equal(f.ack_delay, 42)
    assert_equal(f.ack_range_count, 3)
    assert_true(f.ecn)
    assert_equal(f.ect0, 42)
    assert_equal(f.ect1, 24)
    assert_equal(f.ce, 12)
    var got = RangeSet()
    ack_ranges(Span(buf), f, got)
    var elts = List[UInt64]()
    for i in range(got.len()):
        for v in range(got.start(i), got.end(i)):
            elts.append(v)
    assert_true(elts == packets)


def test_ack_single_range() raises:
    var ranges = RangeSet()
    _ = ranges.insert(100, 200)
    var buf = List[UInt8]()
    write_ack(buf, ranges, 7)
    assert_equal(ack_size(ranges, 7), len(buf))
    var f = _one(buf)
    assert_true(f.type == FrameType.ACK)
    assert_false(f.ecn)
    assert_equal(f.ack_first_range, 99)
    assert_equal(f.ack_ranges_start, f.ack_ranges_end)
    var got = RangeSet()
    ack_ranges(Span(buf), f, got)
    assert_equal(String(got), "[100..200]")


def test_ack_malformed() raises:
    var malformed = "FRAME_ENCODING_ERROR in 0x2: malformed"
    # First range larger than the largest packet number.
    assert_equal(_error(_bytes(0x02, 5, 0, 0, 6)), malformed)
    # A gap below packet number 0.
    assert_equal(_error(_bytes(0x02, 5, 0, 1, 2, 2, 0)), malformed)
    # A range below packet number 0.
    assert_equal(_error(_bytes(0x02, 9, 0, 1, 2, 2, 5)), malformed)
    # The exact fit is accepted: 9 to 7, a gap to 3, then 3 to 0.
    assert_equal(_error(_bytes(0x02, 9, 0, 1, 2, 2, 3)), "no error")
    assert_equal(
        _error(_bytes(0x02, 9, 0, 1)),
        "FRAME_ENCODING_ERROR in 0x2: unexpected end",
    )
    assert_equal(
        _error(_bytes(0x03, 9, 0, 0, 0, 1, 2)),
        "FRAME_ENCODING_ERROR in 0x3: unexpected end",
    )
    # ack_ranges reports truncated pairs, for a frame not from read_frame.
    var f = Frame()
    f.ack_largest = 10
    f.ack_ranges_start = 0
    f.ack_ranges_end = 2
    assert_equal(
        _ack_error(_bytes(0x40), f), "FRAME_ENCODING_ERROR: unexpected end"
    )


def test_stream() raises:
    var id = StreamId(Side.CLIENT, Dir.BI, 3)
    var data = _bytes(1, 2, 3, 4, 5)
    for flags in range(8):
        var offset = UInt64(1000) if flags & 1 != 0 else UInt64(0)
        var fin = flags & 2 != 0
        var with_length = flags & 4 != 0
        var buf = List[UInt8]()
        write_stream_header(buf, id, offset, 5, fin, with_length)
        assert_equal(len(buf), stream_header_size(id, offset, 5, with_length))
        var header = len(buf)
        buf.extend(Span(data))
        var f = _one(buf)
        assert_true(f.type.is_stream())
        assert_true(f.is_ack_eliciting())
        assert_true(f.stream_id == id)
        assert_equal(f.offset, offset)
        assert_equal(f.fin, fin)
        assert_equal(f.data_start, header)
        assert_equal(f.data_len, 5)


def test_stream_errors() raises:
    # A length past the end of the payload.
    assert_equal(
        _error(_bytes(0x0A, 0, 9, 1)),
        "FRAME_ENCODING_ERROR in 0xa: unexpected end",
    )
    # Offset plus length above 2^62 - 1.
    var buf = List[UInt8]()
    write_stream_header(buf, StreamId(0), VARINT_MAX, 1, False, True)
    buf.append(7)
    assert_equal(_error(buf), "FRAME_ENCODING_ERROR in 0xe: malformed")
    # The largest offset with no data is accepted.
    buf.clear()
    write_stream_header(buf, StreamId(0), VARINT_MAX, 0, False, True)
    assert_equal(_error(buf), "no error")


def test_crypto() raises:
    var buf = List[UInt8]()
    write_crypto_header(buf, 300, 3)
    assert_equal(len(buf), crypto_header_size(300, 3))
    buf.extend(Span(_bytes(7, 8, 9)))
    var f = _one(buf)
    assert_true(f.type == FrameType.CRYPTO)
    assert_equal(f.offset, 300)
    assert_equal(f.data_start, 4)
    assert_equal(f.data_len, 3)
    buf.clear()
    write_crypto_header(buf, VARINT_MAX, 1)
    buf.append(0)
    assert_equal(_error(buf), "FRAME_ENCODING_ERROR in 0x6: malformed")


def test_stream_control_frames() raises:
    var id = StreamId(Side.SERVER, Dir.UNI, 2)
    var buf = List[UInt8]()
    write_reset_stream(buf, id, 9, 1234)
    var f = _one(buf)
    assert_true(f.type == FrameType.RESET_STREAM)
    assert_true(f.stream_id == id)
    assert_equal(f.error_code, 9)
    assert_equal(f.final_size, 1234)
    buf.clear()
    write_stop_sending(buf, id, 77)
    f = _one(buf)
    assert_true(f.type == FrameType.STOP_SENDING)
    assert_true(f.stream_id == id)
    assert_equal(f.error_code, 77)
    buf.clear()
    write_max_stream_data(buf, id, 5000)
    f = _one(buf)
    assert_true(f.type == FrameType.MAX_STREAM_DATA)
    assert_true(f.stream_id == id)
    assert_equal(f.value, 5000)
    buf.clear()
    write_stream_data_blocked(buf, id, 6000)
    f = _one(buf)
    assert_true(f.type == FrameType.STREAM_DATA_BLOCKED)
    assert_equal(f.value, 6000)


def test_limit_frames() raises:
    var buf = List[UInt8]()
    write_max_data(buf, 1 << 20)
    var f = _one(buf)
    assert_true(f.type == FrameType.MAX_DATA)
    assert_equal(f.value, 1 << 20)
    buf.clear()
    write_data_blocked(buf, 99)
    f = _one(buf)
    assert_true(f.type == FrameType.DATA_BLOCKED)
    assert_equal(f.value, 99)
    for d in [Dir.BI, Dir.UNI]:
        buf.clear()
        write_max_streams(buf, d, 100)
        f = _one(buf)
        assert_equal(f.type.value, 0x12 + UInt64(d.value))
        assert_true(f.dir() == d)
        assert_equal(f.value, 100)
        buf.clear()
        write_streams_blocked(buf, d, MAX_STREAM_COUNT)
        f = _one(buf)
        assert_equal(f.type.value, 0x16 + UInt64(d.value))
        assert_true(f.dir() == d)
        assert_equal(f.value, MAX_STREAM_COUNT)
    buf.clear()
    write_max_streams(buf, Dir.UNI, MAX_STREAM_COUNT + 1)
    assert_equal(_error(buf), "FRAME_ENCODING_ERROR in 0x13: malformed")


def test_connection_ids() raises:
    var cid = ConnectionId(Span(_bytes(1, 2, 3, 4, 5, 6, 7, 8)))
    var token = ResetToken.random()
    var buf = List[UInt8]()
    write_new_connection_id(buf, 5, 3, cid, token)
    var f = _one(buf)
    assert_true(f.type == FrameType.NEW_CONNECTION_ID)
    assert_equal(f.sequence, 5)
    assert_equal(f.retire_prior_to, 3)
    assert_true(f.cid == cid)
    assert_true(f.reset_token == token)
    buf.clear()
    write_retire_connection_id(buf, 4)
    f = _one(buf)
    assert_true(f.type == FrameType.RETIRE_CONNECTION_ID)
    assert_equal(f.sequence, 4)
    assert_equal(f.value, 4)


def test_new_connection_id_errors() raises:
    var malformed = "FRAME_ENCODING_ERROR in 0x18: malformed"
    var end = "FRAME_ENCODING_ERROR in 0x18: unexpected end"
    # retire_prior_to above the sequence number.
    assert_equal(_error(_bytes(0x18, 1, 2, 1, 9)), malformed)
    # A connection ID of 0 and of 21 bytes.
    assert_equal(_error(_bytes(0x18, 1, 0, 0)), malformed)
    assert_equal(_error(_bytes(0x18, 1, 0, 21)), malformed)
    # The bytes end in the connection ID, and in the reset token.
    assert_equal(_error(_bytes(0x18, 1, 0, 4, 1, 2)), end)
    var buf = _bytes(0x18, 1, 0, 1, 7)
    buf.extend(Span(List[UInt8](length=15, fill=0)))
    assert_equal(_error(buf), end)
    # The length byte is missing.
    assert_equal(_error(_bytes(0x18, 1, 0)), end)


def test_path_frames() raises:
    var buf = List[UInt8]()
    write_path_challenge(buf, 0x0102030405060708)
    var f = _one(buf)
    assert_true(f.type == FrameType.PATH_CHALLENGE)
    assert_equal(f.token, 0x0102030405060708)
    buf.clear()
    write_path_response(buf, 0xFFEEDDCCBBAA9988)
    f = _one(buf)
    assert_true(f.type == FrameType.PATH_RESPONSE)
    assert_equal(f.token, 0xFFEEDDCCBBAA9988)
    assert_equal(
        _error(_bytes(0x1A, 1, 2, 3)),
        "FRAME_ENCODING_ERROR in 0x1a: unexpected end",
    )


def test_close_frames() raises:
    var buf = List[UInt8]()
    write_connection_close(
        buf, TransportErrorCode.PROTOCOL_VIOLATION, 0x08, "bad stream"
    )
    var f = _one(buf)
    assert_true(f.type == FrameType.CONNECTION_CLOSE)
    assert_false(f.is_ack_eliciting())
    assert_equal(f.error_code, 0xA)
    assert_equal(f.frame_type, 0x08)
    assert_equal(f.reason_len, 10)
    assert_equal(
        String(
            StringSlice(
                unsafe_from_utf8=Span(buf)[
                    f.reason_start : f.reason_start + f.reason_len
                ]
            )
        ),
        "bad stream",
    )
    buf.clear()
    write_connection_close(buf, TransportErrorCode.NO_ERROR, NO_FRAME, "")
    f = _one(buf)
    assert_equal(f.frame_type, 0)
    assert_equal(f.reason_len, 0)
    # The reason is cut to fit, as upstream: 12 - 3 - 1 - 1 = 7 bytes.
    buf.clear()
    write_connection_close(
        buf, TransportErrorCode.INTERNAL_ERROR, 0, "abcdefghij", 12
    )
    f = _one(buf)
    assert_equal(f.reason_len, 7)
    buf.clear()
    write_connection_close(buf, TransportErrorCode.INTERNAL_ERROR, 0, "ab", 2)
    assert_equal(_one(buf).reason_len, 0)
    buf.clear()
    write_application_close(buf, 0x100, "bye")
    f = _one(buf)
    assert_true(f.type == FrameType.APPLICATION_CLOSE)
    assert_equal(f.error_code, 0x100)
    assert_equal(f.reason_len, 3)
    buf.clear()
    write_application_close(buf, 1, "abcdefghij", 8)
    assert_equal(_one(buf).reason_len, 4)
    assert_equal(
        _error(_bytes(0x1C, 0, 0, 5, 1)),
        "FRAME_ENCODING_ERROR in 0x1c: unexpected end",
    )


def test_new_token() raises:
    var buf = List[UInt8]()
    var token = _bytes(9, 8, 7, 6)
    write_new_token(buf, Span(token))
    assert_equal(len(buf), new_token_size(4))
    var f = _one(buf)
    assert_true(f.type == FrameType.NEW_TOKEN)
    assert_equal(f.data_start, 2)
    assert_equal(f.data_len, 4)
    assert_equal(
        _error(_bytes(0x07, 0)), "FRAME_ENCODING_ERROR in 0x7: malformed"
    )


def test_ping_and_handshake_done() raises:
    var buf = List[UInt8]()
    write_ping(buf)
    write_handshake_done(buf)
    var pos = 0
    var f = read_frame(Span(buf), pos)
    assert_true(f.type == FrameType.PING)
    assert_true(f.is_ack_eliciting())
    f = read_frame(Span(buf), pos)
    assert_true(f.type == FrameType.HANDSHAKE_DONE)
    assert_equal(pos, 2)


def test_padding() raises:
    # One byte, then PING.
    var buf = _bytes(0, 1)
    var pos = 0
    var f = read_frame(Span(buf), pos)
    assert_true(f.type == FrameType.PADDING)
    assert_equal(f.padding_len, 1)
    assert_equal(pos, 1)
    # 20 bytes, then PING: two words and four bytes.
    buf.clear()
    write_padding(buf, 20)
    write_ping(buf)
    pos = 0
    f = read_frame(Span(buf), pos)
    assert_equal(f.padding_len, 20)
    assert_equal(pos, 20)
    # 17 bytes to the end of the payload.
    buf.clear()
    write_padding(buf, 17)
    f = _one(buf)
    assert_equal(f.padding_len, 17)
    write_padding(buf, 0)
    assert_equal(len(buf), 17)
    # 3 bytes, then a PING inside the next 8 bytes.
    buf = _bytes(0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1)
    pos = 0
    f = read_frame(Span(buf), pos)
    assert_equal(f.padding_len, 3)
    assert_equal(pos, 3)


def test_unknown_types() raises:
    assert_equal(
        _error(_bytes(0x1F)), "FRAME_ENCODING_ERROR in 0x1f: invalid frame ID"
    )
    assert_equal(
        _error(_bytes(0x30)), "FRAME_ENCODING_ERROR in 0x30: invalid frame ID"
    )
    var buf = List[UInt8]()
    write_varint(buf, 0xAF)
    assert_equal(_error(buf), "FRAME_ENCODING_ERROR in 0xaf: invalid frame ID")
    # A type that is cut off has no frame type in the error.
    assert_equal(_error(_bytes(0x40)), "FRAME_ENCODING_ERROR: unexpected end")


def test_frame_type() raises:
    for v in range(0x1F):
        assert_true(FrameType(UInt64(v)).is_valid())
    assert_false(FrameType(0x1F).is_valid())
    assert_true(FrameType(0x08).is_stream())
    assert_true(FrameType(0x0F).is_stream())
    assert_false(FrameType(0x07).is_stream())
    assert_false(FrameType(0x10).is_stream())
    var eliciting = 0
    for v in range(0x1F):
        if FrameType(UInt64(v)).is_ack_eliciting():
            eliciting += 1
    assert_equal(eliciting, 31 - 5)
    assert_equal(String(FrameType.MAX_DATA), "MAX_DATA")
    assert_equal(String(FrameType(0x0B)), "STREAM")
    assert_equal(String(FrameType.HANDSHAKE_DONE), "HANDSHAKE_DONE")
    assert_equal(String(FrameType(0x30)), "<unknown 0x30>")
    assert_equal(FrameType(0x30).text(), "unknown")


def test_check_payload() raises:
    var empty = List[UInt8]()
    var failed = False
    try:
        check_payload(Span(empty))
    except e:
        failed = True
        assert_equal(String(e), "PROTOCOL_VIOLATION: packet payload is empty")
    assert_true(failed)
    check_payload(Span(_bytes(1)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
