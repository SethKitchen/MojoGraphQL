# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http3.message`: the frames of a request stream and the
mapping to and from HTTP/1.1. The malformed requests are those of
hyperium/h3 h3-v0.0.8 h3/src/proto/headers.rs (its `Header::request`
tests) and RFC 9114 section 4.1.2 and 4.2."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_http.headers import Headers
from gql_http.parser import Limits
from gql_http.status import Method
from gql_http3.error import H3Error, H3ErrorCode
from gql_http3.frame import FrameType, write_frame_header
from gql_http3.message import (
    MessageReader,
    from_http1_response,
    is_connection_field,
    request_fields,
    to_http1_request,
    to_http1_response,
    write_message,
)
from gql_http3.qpack_decoder import QpackDecoder
from gql_http3.qpack_encoder import QpackEncoder
from gql_http3.qpack_field import FieldList


def block(fields: FieldList) -> List[UInt8]:
    """Encode a field section with the static table only."""
    var encoder = QpackEncoder()
    var out = List[UInt8]()
    var stream = List[UInt8]()
    _ = encoder.encode(0, fields, out, stream)
    return out^


def get_fields() -> FieldList:
    var fields = FieldList()
    fields.add_text(":method", "GET")
    fields.add_text(":scheme", "https")
    fields.add_text(":authority", "example.com")
    fields.add_text(":path", "/a?b=1")
    return fields^


def message(fields: FieldList, body: String) -> List[UInt8]:
    var out = List[UInt8]()
    write_message(block(fields), body.as_bytes(), out)
    return out^


def code_of(data: List[UInt8], max_body: Int = 100) -> UInt64:
    """Feed a stream and its end; return the error code, or 0."""
    var reader = MessageReader(max_body)
    var decoder = QpackDecoder()
    try:
        reader.feed(data, 0, decoder)
        reader.finish()
    except e:
        return e.code.value
    return 0


def test_reader_whole_message_in_pieces() raises:
    var data = message(get_fields(), "hello")
    var reader = MessageReader(100)
    var decoder = QpackDecoder()
    var index = 0
    while index < len(data):
        reader.feed(Span(data)[index : index + 1], 0, decoder)
        index += 1
    reader.finish()
    assert_true(reader.has_headers)
    assert_equal(reader.fields.count(), 4)
    assert_equal(String(unsafe_from_utf8=reader.body), "hello")


def test_reader_trailers_and_reserved_frames() raises:
    var data = message(get_fields(), "x")
    # A reserved frame type is skipped (RFC 9114 section 7.2.8).
    write_frame_header(data, FrameType.grease(1), 2)
    data.append(1)
    data.append(2)
    var trailers = FieldList()
    trailers.add_text("x-trailer", "1")
    var encoded = block(trailers)
    write_frame_header(data, FrameType.HEADERS, len(encoded))
    data.extend(Span(encoded))
    assert_equal(code_of(data), 0)


def test_reader_errors() raises:
    var early = List[UInt8]()
    write_frame_header(early, FrameType.DATA, 1)
    early.append(65)
    assert_equal(code_of(early), H3ErrorCode.H3_FRAME_UNEXPECTED.value)
    var large = message(get_fields(), "too large")
    assert_equal(code_of(large, 3), H3ErrorCode.H3_EXCESSIVE_LOAD.value)
    var settings = message(get_fields(), "")
    write_frame_header(settings, FrameType.SETTINGS, 0)
    assert_equal(code_of(settings), H3ErrorCode.H3_FRAME_UNEXPECTED.value)
    var ping = List[UInt8]()
    write_frame_header(ping, FrameType.H2_PING, 0)
    assert_equal(code_of(ping), H3ErrorCode.H3_FRAME_UNEXPECTED.value)
    var empty = List[UInt8]()
    assert_equal(code_of(empty), H3ErrorCode.H3_REQUEST_INCOMPLETE.value)
    var cut = message(get_fields(), "abc")
    cut.resize(len(cut) - 1, 0)
    assert_equal(code_of(cut), H3ErrorCode.H3_REQUEST_INCOMPLETE.value)
    # A field section that needs the dynamic table cannot be decoded.
    var blocked = List[UInt8]()
    write_frame_header(blocked, FrameType.HEADERS, 3)
    blocked.append(0x02)
    blocked.append(0x00)
    blocked.append(0x80)
    assert_true(code_of(blocked) != 0)


def request_text(fields: FieldList, body: String = "") raises H3Error -> String:
    var out = List[UInt8]()
    to_http1_request(fields, body.as_bytes(), out)
    return String(unsafe_from_utf8=out)


def request_code(fields: FieldList, body: String = "") -> UInt64:
    try:
        _ = request_text(fields, body)
    except e:
        return e.code.value
    return 0


def test_to_http1_request() raises:
    var fields = get_fields()
    fields.add_text("accept", "*/*")
    fields.add_text("host", "ignored")
    fields.add_text("te", "trailers")
    fields.add_text("content-length", "2")
    assert_equal(
        request_text(fields, "hi"),
        (
            "GET /a?b=1 HTTP/1.1\r\nHost: example.com\r\naccept: */*\r\n"
            "te: trailers\r\nContent-Length: 2\r\n\r\nhi"
        ),
    )
    var no_authority = FieldList()
    no_authority.add_text(":method", "GET")
    no_authority.add_text(":scheme", "https")
    no_authority.add_text(":path", "/")
    assert_true(request_text(no_authority).find("Host: localhost") > 0)
    no_authority.add_text("host", "h.example")
    assert_true(request_text(no_authority).find("Host: h.example") > 0)


def bad(
    var fields: FieldList, name: StaticString, value: StaticString
) -> FieldList:
    fields.add_text(name, value)
    return fields^


def test_malformed_requests() raises:
    comptime M = H3ErrorCode.H3_MESSAGE_ERROR.value
    var after = get_fields()
    after.add_text("accept", "*/*")
    after.add_text(":method", "GET")
    assert_equal(request_code(after), M)
    assert_equal(request_code(bad(get_fields(), ":status", "200")), M)
    assert_equal(request_code(bad(get_fields(), ":method", "GET")), M)
    assert_equal(request_code(bad(get_fields(), ":path", "/")), M)
    assert_equal(request_code(bad(get_fields(), ":scheme", "http")), M)
    assert_equal(request_code(bad(get_fields(), ":authority", "x")), M)
    assert_equal(request_code(bad(get_fields(), "Accept", "x")), M)
    assert_equal(request_code(bad(get_fields(), "", "x")), M)
    assert_equal(request_code(bad(get_fields(), "connection", "close")), M)
    assert_equal(request_code(bad(get_fields(), "te", "gzip")), M)
    assert_equal(request_code(bad(get_fields(), "content-length", "9")), M)
    assert_equal(
        request_code(bad(get_fields(), "content-length", "10"), "a"), M
    )
    var connect = FieldList()
    connect.add_text(":method", "CONNECT")
    connect.add_text(":scheme", "https")
    connect.add_text(":path", "/")
    assert_equal(request_code(connect), M)
    var no_method = FieldList()
    no_method.add_text(":scheme", "https")
    no_method.add_text(":path", "/")
    assert_equal(request_code(no_method), M)
    var no_scheme = FieldList()
    no_scheme.add_text(":method", "GET")
    no_scheme.add_text(":path", "/")
    assert_equal(request_code(no_scheme), M)
    var no_path = FieldList()
    no_path.add_text(":method", "GET")
    no_path.add_text(":scheme", "https")
    assert_equal(request_code(no_path), M)
    var empty_path = FieldList()
    empty_path.add_text(":method", "GET")
    empty_path.add_text(":scheme", "https")
    empty_path.add_text(":path", "")
    assert_equal(request_code(empty_path), M)


def test_connection_fields() raises:
    assert_true(is_connection_field("connection".as_bytes()))
    assert_true(is_connection_field("keep-alive".as_bytes()))
    assert_true(is_connection_field("proxy-connection".as_bytes()))
    assert_true(is_connection_field("transfer-encoding".as_bytes()))
    assert_true(is_connection_field("upgrade".as_bytes()))
    assert_false(is_connection_field("accept".as_bytes()))


def convert(
    text: String, method: Method = Method.GET
) raises -> Tuple[FieldList, String]:
    var data = List[UInt8](text.as_bytes())
    var fields = FieldList()
    var body = List[UInt8]()
    from_http1_response(data, method, Limits(), fields, body)
    return (fields^, String(unsafe_from_utf8=body))


def test_from_http1_response() raises:
    var plain = convert(
        "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n"
        "Content-Length: 2\r\n\r\nhi"
    )
    assert_equal(plain[0].count(), 3)
    assert_equal(String(plain[0].value_text(0)), "200")
    assert_equal(String(plain[0].name_text(1)), "content-type")
    assert_equal(plain[1], "hi")
    var chunked = convert(
        "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n"
        "Content-Length: 9\r\n\r\n1\r\na\r\n1\r\nb\r\n0\r\n\r\n"
    )
    assert_equal(chunked[0].count(), 1)
    assert_equal(chunked[1], "ab")
    var until_close = convert("HTTP/1.1 200 OK\r\n\r\nrest")
    assert_equal(until_close[1], "rest")
    var head = convert(
        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n", Method.HEAD
    )
    assert_equal(head[1], "")
    var raised = 0
    try:
        _ = convert("HTTP/1.1 200")
    except e:
        raised += 1
    try:
        _ = convert(
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n"
        )
    except e:
        raised += 1
    assert_equal(raised, 2)


def test_request_fields() raises:
    var headers = Headers()
    headers.add("Content-Type", "application/json")
    headers.add("Host", "dropped")
    headers.add("Connection", "keep-alive")
    headers.add("Content-Length", "99")
    var fields = FieldList()
    request_fields(Method.POST, "a.example", "/graphql", headers, 2, fields)
    assert_equal(fields.count(), 6)
    assert_equal(String(fields.name_text(4)), "content-type")
    assert_equal(String(fields.value_text(5)), "2")
    request_fields(Method.GET, "a.example", "/", Headers(), 0, fields)
    assert_equal(fields.count(), 4)
    request_fields(Method.PUT, "a", "/", Headers(), 0, fields)
    assert_equal(fields.count(), 5)
    request_fields(Method.PATCH, "a", "/", Headers(), 0, fields)
    assert_equal(fields.count(), 5)
    request_fields(Method.GET, "a", "/", Headers(), 3, fields)
    assert_equal(fields.count(), 5)


def response_code(fields: FieldList) -> Int:
    var out = List[UInt8]()
    try:
        to_http1_response(fields, "".as_bytes(), out)
    except e:
        return Int(e.code.value)
    return 0


def test_to_http1_response() raises:
    var fields = FieldList()
    fields.add_text(":status", "204")
    fields.add_text("x-a", "1")
    fields.add_text("content-length", "7")
    var out = List[UInt8]()
    to_http1_response(fields, "ok".as_bytes(), out)
    assert_equal(
        String(unsafe_from_utf8=out),
        "HTTP/1.1 204 \r\nx-a: 1\r\nContent-Length: 2\r\n\r\nok",
    )
    comptime M = Int(H3ErrorCode.H3_MESSAGE_ERROR.value)
    assert_equal(response_code(FieldList()), M)
    var other = FieldList()
    other.add_text("x", "1")
    assert_equal(response_code(other), M)
    var statuses: List[StaticString] = ["20", "2x0", "099", "600", "abc"]
    var index = 0
    while index < len(statuses):
        var wrong = FieldList()
        wrong.add_text(":status", statuses[index])
        assert_equal(response_code(wrong), M)
        index += 1
    var names: List[StaticString] = [":path", "X", "", "upgrade"]
    index = 0
    while index < len(names):
        var field = FieldList()
        field.add_text(":status", "200")
        field.add_text(names[index], "v")
        assert_equal(response_code(field), M)
        index += 1


def test_reader_blocked_section() raises:
    var blocked = List[UInt8]()
    write_frame_header(blocked, FrameType.HEADERS, 3)
    blocked.append(0x02)
    blocked.append(0x00)
    blocked.append(0x80)
    var reader = MessageReader(100)
    var decoder = QpackDecoder(4096, 10)
    var code: UInt64 = 0
    try:
        reader.feed(blocked, 0, decoder)
    except e:
        code = e.code.value
    assert_equal(code, H3ErrorCode.QPACK_DECOMPRESSION_FAILED.value)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
