# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.frame`.

Upstream: `h3/src/proto/frame.rs` (`unknown_frame_type`,
`len_unexpected_end`, `type_unexpected_end`, `buffer_too_short`,
`settings_frame`, `settings_frame_emtpy`, `data_frame`, `simple_frames`,
`headers_frames`, `reserved_frame`) and `h3/src/frame.rs` (`one_frame`,
`incomplete_frame`, `header_spread_multiple_buf`,
`varint_spread_multiple_buf`, `two_frames_then_incomplete`,
`poll_full_request`, `poll_next_incomplete_frame`, `poll_data_split`,
`poll_data_unexpected_end`, `poll_data_ignores_unknown_frames`,
`poll_data_eos_but_buffered_data`) of hyperium/h3 h3-v0.0.8. The
`should_panic` test `poll_next_reamining_data` has no counterpart: the
reader hands out the rest of a DATA frame first.
"""

from gql_http3.error import H3ErrorCode
from gql_http3.frame import (
    FrameHead,
    FrameReader,
    FrameType,
    SettingId,
    Settings,
    StreamType,
    decode_varint_payload,
    parse_frame_head,
    parse_push_promise,
    write_data_frame,
    write_frame_header,
    write_goaway_frame,
    write_grease_frame,
    write_headers_frame,
    write_push_promise_frame,
    write_stream_type,
    write_varint_frame,
)
from gql_http3.varint import Progress, encode_varint
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime _ = String().as_bytes()


def _b(text: StaticString) -> Span[UInt8, ImmStaticOrigin]:
    return text.as_bytes()


def _text(data: Span[UInt8, _]) -> String:
    return String(StringSlice(unsafe_from_utf8=data))


def test_frame_types() raises:
    for v in [0x0, 0x1, 0x3, 0x4, 0x5, 0x7, 0xD]:
        assert_true(FrameType(UInt64(v)).is_valid(), String(v))
        assert_false(FrameType(UInt64(v)).is_http2_only())
    for v in [0x2, 0x6, 0x8, 0x9]:
        assert_false(FrameType(UInt64(v)).is_valid(), String(v))
        assert_true(FrameType(UInt64(v)).is_http2_only())
    for v in [0xA, 0xE, 0x21, 0x40]:
        assert_false(FrameType(UInt64(v)).is_valid(), String(v))
    assert_true(FrameType.grease(1337).is_reserved())
    assert_equal(FrameType.grease(0).value, 0x21)
    assert_false(FrameType(0x20).is_reserved())
    assert_false(FrameType(0x22).is_reserved())
    assert_equal(String(FrameType.SETTINGS), "0x4")


def test_stream_types() raises:
    assert_true(StreamType.QPACK_DECODER.is_valid())
    assert_false(StreamType(4).is_valid())
    assert_true(StreamType.grease(2).is_reserved())
    assert_false(StreamType.CONTROL.is_reserved())
    assert_equal(String(StreamType.CONTROL), "Control")
    assert_equal(String(StreamType.PUSH), "Push")
    assert_equal(String(StreamType.QPACK_ENCODER), "Encoder")
    assert_equal(String(StreamType(0x54)), "StreamType(84)")
    var out = List[UInt8]()
    write_stream_type(out, StreamType.QPACK_DECODER)
    write_stream_type(out, StreamType.grease(0))
    var expected: List[UInt8] = [3, 0x21]
    assert_true(out == expected)


def test_setting_ids() raises:
    for v in [0x1, 0x6, 0x7, 0x8, 0x33]:
        assert_true(SettingId(UInt64(v)).is_valid(), String(v))
    for v in [0x0, 0x2, 0x5, 0x9, 0x21]:
        assert_false(SettingId(UInt64(v)).is_valid(), String(v))
    for v in [0x0, 0x2, 0x3, 0x4, 0x5]:
        assert_true(SettingId(UInt64(v)).is_forbidden(), String(v))
    for v in [0x1, 0x6, 0x33]:
        assert_false(SettingId(UInt64(v)).is_forbidden(), String(v))
    assert_true(SettingId.H3_DATAGRAM.is_boolean())
    assert_true(SettingId.ENABLE_CONNECT_PROTOCOL.is_boolean())
    assert_false(SettingId.QPACK_BLOCKED_STREAMS.is_boolean())
    assert_equal(SettingId.grease(2).value, 0x21 + 2 * 0x1F)
    assert_equal(String(SettingId.H3_DATAGRAM), "0x33")


def _head(data: List[UInt8]) -> FrameHead:
    return parse_frame_head(Span(data), 0)


def test_unexpected_end() raises:
    # type_unexpected_end, len_unexpected_end and buffer_too_short.
    assert_false(_head([255]).complete())
    assert_false(_head([0, 255]).complete())
    var head = _head([4, 4, 0, 255, 128])
    assert_true(head.complete())
    assert_equal(head.length, 4)
    assert_equal(head.payload_end(), 6)
    assert_equal(String(head), "complete type 0x4 at 2 length 4")
    assert_true(_head([]).status == Progress.INCOMPLETE)


def _settings_wire() -> List[UInt8]:
    return [
        4,
        18,
        6,
        128,
        0,
        250,
        209,
        1,
        128,
        0,
        250,
        210,
        7,
        128,
        0,
        250,
        211,
        64,
        95,
        0,
    ]


def test_settings_frame() raises:
    var settings = Settings()
    settings.insert(SettingId.MAX_FIELD_SECTION_SIZE, 0xFAD1)
    settings.insert(SettingId.QPACK_MAX_TABLE_CAPACITY, 0xFAD2)
    settings.insert(SettingId.QPACK_BLOCKED_STREAMS, 0xFAD3)
    settings.insert(SettingId(95), 0)
    var out = List[UInt8]()
    settings.encode(out)
    assert_true(out == _settings_wire())
    var head = parse_frame_head(Span(out), 0)
    var decoded = Settings.decode(Span(out)[head.payload_start :])
    assert_equal(decoded.count(), 3)
    assert_equal(decoded.get(SettingId.QPACK_BLOCKED_STREAMS).value(), 0xFAD3)
    assert_false(decoded.get(SettingId(95)))
    assert_equal(decoded.get_or(SettingId.H3_DATAGRAM, 7), 7)
    assert_equal(decoded.get_or(SettingId.QPACK_MAX_TABLE_CAPACITY, 7), 0xFAD2)
    assert_equal(String(decoded), "Settings(0x6=64209, 0x1=64210, 0x7=64211)")


def test_settings_frame_empty() raises:
    var out = List[UInt8]()
    Settings().encode(out)
    var expected: List[UInt8] = [4, 0]
    assert_true(out == expected)
    assert_equal(Settings.decode(Span(out)[2:]).count(), 0)


def _settings_error(payload: List[UInt8]) raises -> String:
    try:
        _ = Settings.decode(Span(payload))
    except e:
        return String(e)
    return "no error"


def test_settings_errors() raises:
    var malformed = "H3_FRAME_ERROR: malformed settings frame"
    assert_equal(_settings_error([1]), malformed)
    assert_equal(_settings_error([0x80, 1]), malformed)
    assert_equal(_settings_error([1, 0x40]), malformed)
    assert_equal(
        _settings_error([2, 0]), "H3_SETTINGS_ERROR: setting id 0x2 is invalid"
    )
    assert_equal(
        _settings_error([0x33, 2]),
        "H3_SETTINGS_ERROR: setting 0x33 has invalid value 2",
    )
    assert_equal(
        _settings_error([1, 0, 1, 1]), "H3_SETTINGS_ERROR: setting 0x1 repeated"
    )
    var ok: List[UInt8] = [8, 1, 0x33, 0, 0x21, 9]
    var settings = Settings.decode(Span(ok))
    assert_equal(settings.count(), 2)
    var full = Settings()
    for i in range(8):
        full.insert(SettingId(UInt64(0x40 + i)), 0)
    var failed = False
    try:
        full.insert(SettingId(0x60), 0)
    except e:
        failed = True
        assert_equal(e.message, "too many settings")
    assert_true(failed)


def test_simple_frames() raises:
    var out = List[UInt8]()
    write_varint_frame(out, FrameType.CANCEL_PUSH, 2)
    write_goaway_frame(out, 2)
    write_varint_frame(out, FrameType.MAX_PUSH_ID, 2)
    var expected: List[UInt8] = [3, 1, 2, 7, 1, 2, 13, 1, 2]
    assert_true(out == expected)
    assert_equal(decode_varint_payload(Span(out)[2:3]), 2)
    for bad in [0, 2]:
        var failed = False
        try:
            _ = decode_varint_payload(Span(out)[2 : 2 + bad])
        except e:
            failed = True
            assert_true(e.code == H3ErrorCode.H3_FRAME_ERROR)
        assert_true(failed)


def test_data_and_headers_frames() raises:
    var out = List[UInt8]()
    write_data_frame(out, _b("1234567"))
    var expected: List[UInt8] = [0, 7, 49, 50, 51, 52, 53, 54, 55]
    assert_true(out == expected)
    out.clear()
    write_headers_frame(out, _b("TODO QPACK"))
    expected = [1, 10, 84, 79, 68, 79, 32, 81, 80, 65, 67, 75]
    assert_true(out == expected)
    out.clear()
    write_push_promise_frame(out, 134, _b("TODO QPACK"))
    expected = [5, 12, 64, 134, 84, 79, 68, 79, 32, 81, 80, 65, 67, 75]
    assert_true(out == expected)
    var promise = parse_push_promise(Span(out)[2:])
    assert_equal(promise[0], 134)
    assert_equal(_text(Span(out)[2 + promise[1] :]), "TODO QPACK")
    var failed = False
    try:
        _ = parse_push_promise(Span(out)[2:3])
    except e:
        failed = True
        assert_equal(e.message, "truncated push promise")
    assert_true(failed)


def _next(mut reader: FrameReader) raises -> String:
    """Return `<type>:<payload>` of the next frame, or `wait`."""
    if not reader.next():
        return "wait"
    return String(reader.frame_type, ":", _text(reader.payload()))


def _reader_error(mut reader: FrameReader) raises -> String:
    try:
        while reader.next():
            pass
    except e:
        return String(e)
    return "no error"


def test_unknown_frame_type() raises:
    var reader = FrameReader()
    var data: List[UInt8] = [22, 4, 0, 255, 128, 0, 3, 1, 2]
    reader.feed(Span(data))
    assert_equal(_next(reader), "0x3:\x02")
    assert_equal(_next(reader), "wait")


def test_reserved_frame() raises:
    var raw = List[UInt8]()
    encode_varint(0x21 + 2 * 0x1F, raw)
    raw.extend(Span([UInt8(6), 0, 255, 128, 0, 250, 218]))
    var reader = FrameReader()
    reader.feed(Span(raw))
    assert_equal(_next(reader), "wait")
    assert_equal(reader.buffered(), 0)


def test_one_frame_and_incomplete() raises:
    var buf = List[UInt8]()
    write_headers_frame(buf, _b("salut"))
    var reader = FrameReader()
    reader.feed(Span(buf)[: len(buf) - 1])
    assert_equal(_next(reader), "wait")
    reader.feed(Span(buf)[len(buf) - 1 :])
    assert_equal(_next(reader), "0x1:salut")


def test_spread_multiple_buf() raises:
    # header_spread_multiple_buf and varint_spread_multiple_buf.
    var buf = List[UInt8]()
    write_headers_frame(buf, _b("salut"))
    var big = String()
    for _ in range(1024):
        big += "salut"
    write_headers_frame(buf, big.as_bytes())
    var reader = FrameReader()
    reader.feed(Span(buf)[:1])
    assert_equal(_next(reader), "wait")
    reader.feed(Span(buf)[1:9])
    assert_equal(_next(reader), "0x1:salut")
    assert_equal(_next(reader), "wait")
    reader.feed(Span(buf)[9:])
    assert_true(reader.next())
    assert_equal(len(reader.payload()), 5120)


def test_two_frames_then_incomplete() raises:
    # Also poll_full_request: headers, a DATA frame, trailers.
    var buf = List[UInt8]()
    write_headers_frame(buf, _b("header"))
    write_data_frame(buf, _b("body"))
    write_headers_frame(buf, _b("trailer"))
    var reader = FrameReader()
    reader.feed(Span(buf)[: len(buf) - 1])
    assert_equal(_next(reader), "0x1:header")
    assert_equal(_next(reader), "0x0:body")
    assert_equal(reader.data_remaining(), 0)
    assert_equal(_next(reader), "wait")
    reader.feed(Span(buf)[len(buf) - 1 :])
    assert_equal(_next(reader), "0x1:trailer")
    reader.finish()
    assert_equal(_next(reader), "wait")
    assert_true(reader.is_done())


def test_poll_next_incomplete_frame() raises:
    var buf = List[UInt8]()
    write_headers_frame(buf, _b("header"))
    var reader = FrameReader()
    reader.feed(Span(buf)[: len(buf) - 1])
    reader.finish()
    assert_equal(
        _reader_error(reader), "H3_FRAME_ERROR: stream ended inside a frame"
    )
    assert_false(reader.is_done())


def test_poll_data_split() raises:
    var buf = List[UInt8]()
    write_data_frame(buf, _b("body"))
    var reader = FrameReader()
    reader.feed(Span(buf)[: len(buf) - 2])
    assert_equal(_next(reader), "0x0:bo")
    assert_equal(reader.data_remaining(), 2)
    assert_equal(_next(reader), "wait")
    reader.feed(Span(buf)[len(buf) - 2 :])
    assert_equal(_next(reader), "0x0:dy")
    assert_equal(reader.data_remaining(), 0)


def test_poll_data_unexpected_end() raises:
    var buf: List[UInt8] = [0, 4, 98]
    var reader = FrameReader()
    reader.feed(Span(buf))
    assert_equal(_next(reader), "0x0:b")
    reader.finish()
    assert_equal(
        _reader_error(reader), "H3_FRAME_ERROR: stream ended inside a frame"
    )


def test_poll_data_ignores_unknown_frames() raises:
    var buf = List[UInt8]()
    write_frame_header(buf, FrameType.grease(7), 0)
    write_grease_frame(buf, 9)
    write_data_frame(buf, _b("body"))
    var reader = FrameReader()
    reader.feed(Span(buf))
    assert_equal(_next(reader), "0x0:body")


def test_unknown_frame_split() raises:
    # An unknown frame is dropped as its bytes arrive.
    var buf = List[UInt8]()
    write_grease_frame(buf, 3)
    var reader = FrameReader()
    reader.feed(Span(buf)[:4])
    assert_equal(_next(reader), "wait")
    reader.finish()
    assert_equal(
        _reader_error(reader), "H3_FRAME_ERROR: stream ended inside a frame"
    )


def test_poll_data_eos_but_buffered_data() raises:
    var buf: List[UInt8] = [0, 4, 98, 111]
    var reader = FrameReader()
    reader.feed(Span(buf))
    assert_equal(_next(reader), "0x0:bo")
    reader.feed(Span(buf)[2:4])
    reader.finish()
    assert_equal(_next(reader), "0x0:bo")
    assert_equal(_next(reader), "wait")
    assert_true(reader.is_done())


def test_empty_data_frame() raises:
    var buf = List[UInt8]()
    write_data_frame(buf, _b(""))
    var reader = FrameReader()
    reader.feed(Span(buf))
    assert_equal(_next(reader), "0x0:")
    assert_equal(_next(reader), "wait")


def test_forbidden_and_large_frames() raises:
    for t in [0x2, 0x6, 0x8, 0x9]:
        var buf = List[UInt8]()
        write_frame_header(buf, FrameType(UInt64(t)), 0)
        var reader = FrameReader()
        reader.feed(Span(buf))
        assert_equal(
            _reader_error(reader),
            String(
                "H3_FRAME_UNEXPECTED: frame ",
                hex(t),
                " is not allowed in HTTP/3",
            ),
        )
    var buf = List[UInt8]()
    write_frame_header(buf, FrameType.HEADERS, 11)
    var reader = FrameReader(10)
    reader.feed(Span(buf))
    assert_equal(
        _reader_error(reader),
        "H3_EXCESSIVE_LOAD: frame 0x1 is larger than the limit",
    )


def test_buffer_compaction() raises:
    # A long stream of small frames keeps the buffer short.
    var reader = FrameReader()
    var frame = List[UInt8]()
    write_headers_frame(frame, _b("0123456789"))
    var count = 0
    for _ in range(1000):
        reader.feed(Span(frame)[:5])
        reader.feed(Span(frame)[5:])
        while reader.next():
            count += 1
    assert_equal(count, 1000)
    assert_equal(reader.buffered(), 0)
    # Bytes left over across a compaction stay in order.
    var many = List[UInt8]()
    for _ in range(400):
        many.extend(Span(frame))
    reader.feed(Span(many))
    reader.feed(Span(frame)[:3])
    count = 0
    while reader.next():
        count += 1
    reader.feed(Span(frame)[3:])
    assert_equal(_next(reader), "0x1:0123456789")
    assert_equal(count, 400)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
