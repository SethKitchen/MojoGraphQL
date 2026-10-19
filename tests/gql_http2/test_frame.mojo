# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http2.frame` and `gql_http2.error`: the frame head, the
writers, `SETTINGS` values, and the error codes.

Ported from h2 v0.4.20 `tests/h2-tests/tests/codec_write.rs`
(`write_continuation_frames`) and the unit tests of `src/frame/head.rs`,
`src/frame/settings.rs` and `src/frame/reason.rs`.
"""

from gql_http2.error import H2Error, H2ErrorKind, Reason
from gql_http2.frame import (
    END_HEADERS,
    END_STREAM,
    FrameHead,
    FrameKind,
    HEAD_SIZE,
    SettingId,
    Settings,
    read_u31,
    read_u64,
    write_data,
    write_goaway,
    write_header_block,
    write_head,
    write_ping,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_reason() raises:
    # reason.rs: names and descriptions of each code.
    assert_equal(String(Reason.NO_ERROR), "NO_ERROR")
    assert_equal(String(Reason.HTTP_1_1_REQUIRED), "HTTP_1_1_REQUIRED")
    assert_equal(String(Reason(77)), "UNKNOWN(77)")
    assert_equal(String(Reason(77).name()), "UNKNOWN")
    assert_equal(
        String(Reason.PROTOCOL_ERROR.description()),
        "unspecific protocol error detected",
    )
    assert_equal(String(Reason(14).description()), "unknown reason")
    assert_true(Reason.CANCEL.is_valid() and not Reason(14).is_valid())


def test_errors() raises:
    assert_equal(String(H2ErrorKind.STREAM), "stream")
    assert_equal(String(H2ErrorKind.TIMEOUT), "timeout")
    assert_equal(String(H2ErrorKind(9)), "invalid")
    assert_false(H2ErrorKind(7).is_valid())
    var stream = H2Error.stream(3, Reason.CANCEL, "gone")
    assert_equal(String(stream), "stream error CANCEL on stream 3: gone")
    var conn = H2Error.connection(Reason.PROTOCOL_ERROR, "bad")
    assert_equal(String(conn), "connection error PROTOCOL_ERROR: bad")
    assert_true(H2Error.usage("u").kind == H2ErrorKind.USAGE)
    assert_true(H2Error.io("i").kind == H2ErrorKind.IO)


def test_frame_head() raises:
    # head.rs: the reserved bit of the stream id is dropped.
    var out = List[UInt8]()
    write_head(out, 0x123456, FrameKind.PING, 0xAB, 0x7FFFFFFF)
    out[5] |= 0x80
    var head = FrameHead.parse(out.unsafe_ptr())
    assert_equal(head.length, 0x123456)
    assert_true(head.kind == FrameKind.PING)
    assert_equal(Int(head.flags), 0xAB)
    assert_equal(head.stream_id, 0x7FFFFFFF)
    assert_equal(read_u31(out.unsafe_ptr(), 5), 0x7FFFFFFF)
    assert_equal(String(FrameKind.WINDOW_UPDATE), "WINDOW_UPDATE")
    assert_equal(String(FrameKind(10)), "UNKNOWN(10)")
    assert_false(FrameKind(10).is_valid())
    var ping = List[UInt8]()
    write_ping(ping, 0x0102030405060708, False)
    assert_equal(read_u64(ping.unsafe_ptr(), HEAD_SIZE), 0x0102030405060708)


def test_write_continuation_frames() raises:
    # codec_write.rs write_continuation_frames
    var block = List[UInt8](length=25, fill=7)
    var out = List[UInt8]()
    write_header_block(out, 1, block, True, 10)
    var first = FrameHead.parse(out.unsafe_ptr())
    assert_true(first.kind == FrameKind.HEADERS)
    assert_equal(first.length, 10)
    assert_true(first.has(END_STREAM) and not first.has(END_HEADERS))
    var second = FrameHead.parse(out.unsafe_ptr().unsafe_offset(19))
    assert_true(second.kind == FrameKind.CONTINUATION)
    assert_false(second.has(END_HEADERS))
    var third = FrameHead.parse(out.unsafe_ptr().unsafe_offset(38))
    assert_equal(third.length, 5)
    assert_true(third.has(END_HEADERS))
    assert_equal(len(out), 3 * HEAD_SIZE + 25)
    # A block that fits is one frame.
    out.clear()
    write_header_block(out, 1, block, False, 100)
    var only = FrameHead.parse(out.unsafe_ptr())
    assert_true(only.has(END_HEADERS) and not only.has(END_STREAM))
    out.clear()
    write_data(out, 3, block, False)
    assert_equal(Int(FrameHead.parse(out.unsafe_ptr()).flags), 0)
    out.clear()
    write_goaway(out, 5, Reason.CANCEL, StaticString("why").as_bytes())
    assert_equal(FrameHead.parse(out.unsafe_ptr()).length, 11)


def test_settings() raises:
    # settings.rs: only the values that are not initial are sent.
    var out = List[UInt8]()
    Settings().write(out)
    assert_equal(len(out), HEAD_SIZE)
    var all = Settings()
    all.header_table_size = 0
    all.enable_push = False
    all.max_concurrent_streams = 10
    all.initial_window_size = 1
    all.max_frame_size = 20000
    all.max_header_list_size = 100
    all.enable_connect_protocol = True
    out.clear()
    all.write(out)
    assert_equal(FrameHead.parse(out.unsafe_ptr()).length, 7 * 6)
    var back = Settings()
    back.apply(out.unsafe_ptr(), HEAD_SIZE, 7 * 6, False)
    assert_equal(back.header_table_size, 0)
    assert_false(back.enable_push)
    assert_equal(back.max_concurrent_streams, 10)
    assert_equal(back.initial_window_size, 1)
    assert_equal(back.max_frame_size, 20000)
    assert_equal(back.max_header_list_size, 100)
    assert_true(back.enable_connect_protocol)
    assert_equal(String(SettingId.MAX_FRAME_SIZE), "5")
    assert_true(SettingId(8).is_valid())
    assert_false(SettingId(7).is_valid() or SettingId(0).is_valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
