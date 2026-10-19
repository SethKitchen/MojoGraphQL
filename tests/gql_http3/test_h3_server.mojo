# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the stream rules of `gql_http3.server`, with a raw QUIC
client in this process. The cases follow hyperium/h3 h3-v0.0.8
h3/src/tests/connection.rs (control stream first frame, duplicate control
streams, push streams from a client, unknown stream types) and RFC 9114
sections 6.2, 7.2 and 8."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _h3 import RawClient, control_bytes, make_server, request_bytes
from gql_http3.error import H3ErrorCode
from gql_http3.frame import FrameType, StreamType, write_frame_header
from gql_http3.quic import ReadState
from gql_http3.server import ControlReader, StreamRole
from gql_http3.varint import encode_varint


def test_request_and_control() raises:
    var server = make_server()
    var client = RawClient(server)
    var control = client.open(True)
    client.send(control, control_bytes(), False)
    var stream = client.open(False)
    client.send(stream, request_bytes("/a", "hi"), True)
    var answer = client.receive(server, stream)
    assert_equal(answer[1], ReadState.END)
    assert_true(answer[0].find("/a:hi") > 0)
    assert_equal(server.connections(), 1)
    var failing = client.open(False)
    client.send(failing, request_bytes("/fail"), True)
    assert_equal(client.receive(server, failing)[1], ReadState.END)
    client.quic.free(stream)
    client.quic.free(failing)
    client.quic.free(control)
    server.close()
    assert_equal(server.connections(), 0)


def uni(mut client: RawClient, type: UInt64, var tail: List[UInt8]) raises:
    var stream = client.open(True)
    var data = List[UInt8]()
    encode_varint(type, data)
    data.extend(Span(tail))
    client.send(stream, data, False)


def expect_close(type: UInt64, var tail: List[UInt8]) raises:
    var server = make_server()
    var client = RawClient(server)
    uni(client, type, tail^)
    assert_true(client.closed(server))
    client.pump(server, 3)
    assert_equal(server.connections(), 0)


def test_push_stream_from_client() raises:
    expect_close(StreamType.PUSH.value, List[UInt8]())


def test_missing_settings() raises:
    var tail = List[UInt8]()
    write_frame_header(tail, FrameType.GOAWAY, 1)
    tail.append(0)
    expect_close(StreamType.CONTROL.value, tail^)


def test_second_control_stream() raises:
    var server = make_server()
    var client = RawClient(server)
    var first = client.open(True)
    client.send(first, control_bytes(), False)
    client.pump(server, 3)
    var second = client.open(True)
    client.send(second, control_bytes(), False)
    assert_true(client.closed(server))


def test_control_frames() raises:
    var reader = ControlReader()
    var data = List[UInt8]()
    write_frame_header(data, FrameType.SETTINGS, 0)
    write_frame_header(data, FrameType.grease(2), 0)
    write_frame_header(data, FrameType.GOAWAY, 1)
    data.append(0)
    reader.feed(Span(data)[0:3])
    reader.feed(Span(data)[3:])
    assert_true(reader.has_settings)
    assert_true(reader.goaway)
    var codes = List[UInt64]()
    var types: List[FrameType] = [
        FrameType.SETTINGS,
        FrameType.DATA,
        FrameType.HEADERS,
        FrameType.PUSH_PROMISE,
        FrameType.H2_PING,
    ]
    var index = 0
    while index < len(types):
        var fresh = ControlReader()
        var frame = List[UInt8]()
        write_frame_header(frame, FrameType.SETTINGS, 0)
        write_frame_header(frame, types[index], 0)
        try:
            fresh.feed(frame)
        except e:
            codes.append(e.code.value)
        index += 1
    assert_equal(len(codes), 5)
    var at = 0
    while at < 5:
        assert_equal(codes[at], H3ErrorCode.H3_FRAME_UNEXPECTED.value)
        at += 1
    # A frame whose payload has not arrived waits.
    var partial = ControlReader()
    var head = List[UInt8]()
    write_frame_header(head, FrameType.SETTINGS, 2)
    partial.feed(head)
    assert_false(partial.has_settings)


def test_control_stream_end() raises:
    var server = make_server()
    var client = RawClient(server)
    var control = client.open(True)
    client.send(control, control_bytes(), True)
    assert_true(client.closed(server))


def test_qpack_and_unknown_streams() raises:
    var server = make_server()
    var client = RawClient(server)
    uni(client, StreamType.QPACK_ENCODER.value, List[UInt8]())
    uni(client, StreamType.QPACK_DECODER.value, List[UInt8]())
    var tail = List[UInt8]()
    tail.append(1)
    tail.append(2)
    uni(client, 0x21, tail^)
    # A type split over two writes.
    var split = client.open(True)
    var first = List[UInt8]()
    first.append(0x40)
    client.send(split, first, False)
    client.pump(server, 3)
    var rest = List[UInt8]()
    rest.append(0x21)
    client.send(split, rest, True)
    client.pump(server, 5)
    var stream = client.open(False)
    client.send(stream, request_bytes("/b"), True)
    assert_equal(client.receive(server, stream)[1], ReadState.END)


def second_stream(type: UInt64) raises:
    var server = make_server()
    var client = RawClient(server)
    uni(client, type, List[UInt8]())
    client.pump(server, 3)
    uni(client, type, List[UInt8]())
    assert_true(client.closed(server))


def test_second_qpack_streams() raises:
    second_stream(StreamType.QPACK_ENCODER.value)
    second_stream(StreamType.QPACK_DECODER.value)


def test_bad_decoder_instruction() raises:
    var server = make_server()
    var client = RawClient(server)
    var bad = List[UInt8]()
    bad.append(0x3F)
    bad.append(0xE1)
    bad.append(0xFF)
    bad.append(0xFF)
    bad.append(0xFF)
    bad.append(0x0F)
    uni(client, StreamType.QPACK_DECODER.value, bad^)
    assert_true(client.closed(server))


def test_malformed_request_resets_stream() raises:
    var server = make_server()
    var client = RawClient(server)
    var stream = client.open(False)
    var data = request_bytes("")
    client.send(stream, data, True)
    assert_equal(client.receive(server, stream)[1], ReadState.RESET)
    # The connection lives on.
    var next = client.open(False)
    client.send(next, request_bytes("/n"), True)
    assert_equal(client.receive(server, next)[1], ReadState.END)


def test_data_before_headers_closes() raises:
    var server = make_server()
    var client = RawClient(server)
    var early = client.open(False)
    var frame = List[UInt8]()
    write_frame_header(frame, FrameType.DATA, 1)
    frame.append(65)
    client.send(early, frame, True)
    assert_true(client.closed(server))


def test_settings_on_request_stream_closes() raises:
    var server = make_server()
    var client = RawClient(server)
    var unexpected = client.open(False)
    var settings = List[UInt8]()
    write_frame_header(settings, FrameType.SETTINGS, 0)
    client.send(unexpected, settings, False)
    assert_true(client.closed(server))


def test_rejected_request() raises:
    var server = make_server()
    var client = RawClient(server)
    var stream = client.open(False)
    client.send(stream, request_bytes("/bad target"), True)
    var answer = client.receive(server, stream)
    assert_equal(answer[1], ReadState.END)


def test_kinds() raises:
    assert_true(StreamRole.IGNORED.is_valid())
    assert_false(StreamRole(6).is_valid())
    assert_equal(String(StreamRole.CONTROL), "control")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
