# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the subgraph stream parsers and of the client stream framing.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/executor/executors/sse.rs` and
`executor/executors/multipart_subscribe.rs`. The `custom_scalar_paths`
cases are not ported, because this port has no custom scalar paths.
"""

from gql_router_stream.encode import (
    APOLLO_MULTIPART_HTTP_CONTENT_TYPE,
    INCREMENTAL_DELIVERY_CONTENT_TYPE,
    SSE_CONTENT_TYPE,
    StreamFormat,
)
from gql_router_stream.negotiate import StreamContentType
from gql_router_stream.subgraph_parse import (
    MAX_BUFFER_SIZE,
    MultipartParser,
    SseEvent,
    SseParser,
    extract_body_after_headers,
    extract_payload,
    find_sse_event_boundary,
    parse_boundary_from_header,
    parse_sse_event,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _event(text: String) raises -> SseEvent:
    var event = SseEvent()
    assert_true(parse_sse_event(List[UInt8](text.as_bytes()), event))
    return event^


def _texts(events: List[List[UInt8]]) -> List[String]:
    var out = List[String]()
    for event in events:
        out.append(String(unsafe_from_utf8=Span(event)))
    return out^


def test_parse_sse_events() raises:
    var single = _event("event: next\ndata: some data\n")
    assert_equal(single.event, "next")
    assert_equal(single.data, "some data")
    var untyped = _event("data: some data\n\n")
    assert_false(untyped.has_event)
    assert_equal(untyped.data, "some data")
    var complete = _event("event: complete\n\n")
    assert_equal(complete.event, "complete")
    assert_equal(complete.data, "")
    var multiple = _event(
        "event: next\ndata: value 1\n\nevent: next\ndata: value 2\n\n"
        "event: complete\n"
    )
    assert_equal(multiple.event, "next")
    assert_equal(multiple.data, "value 1")
    assert_equal(
        _event("event: next\ndata: line1\ndata: line2\n\n").data,
        "line1\nline2",
    )
    assert_equal(_event("event: next\ndata: line0").data, "line0")
    var heartbeat = _event(":\n\nevent: next\ndata: payload\n\n:\n\n")
    assert_equal(heartbeat.data, "payload")
    var empty = SseEvent()
    assert_false(parse_sse_event(List[UInt8](), empty))
    assert_equal(
        _event("event: next\r\ndata: some data\r\n\r\n").data, "some data"
    )
    assert_equal(_event("event: complete\r\n\r\n").event, "complete")
    # A line without a colon and an unknown field are ignored.
    var ignored = _event("retry\nid: 1\nevent: next\n")
    assert_equal(ignored.event, "next")
    var invalid = SseEvent()
    var failed = False
    try:
        _ = parse_sse_event([UInt8(0xFF), 10, 10], invalid)
    except error:
        failed = True
        assert_equal(String(error), "Invalid UTF-8 sequence")
    assert_true(failed)


def test_find_sse_event_boundary() raises:
    var crlf = List[UInt8]("event: next\r\ndata: hello\r\n\r\n".as_bytes())
    assert_equal(find_sse_event_boundary(crlf), len(crlf))
    var lf = List[UInt8]("event: next\ndata: hello\n\n".as_bytes())
    assert_equal(find_sse_event_boundary(lf), len(lf))
    assert_equal(find_sse_event_boundary(List[UInt8]()), -1)
    assert_equal(find_sse_event_boundary(List[UInt8]("a\r\n\r".as_bytes())), -1)
    # A carriage return that does not start `\r\n\r\n`.
    assert_equal(
        find_sse_event_boundary(List[UInt8]("a\rxyz\r\n\rq\n\n".as_bytes())),
        11,
    )


def _sse(chunks: List[String], mut events: List[List[UInt8]]) raises -> Bool:
    var parser = SseParser()
    var ended = False
    for chunk in chunks:
        parser.feed(chunk.as_bytes())
        ended = parser.take(events)
    return ended


def test_sse_parse_to_stream() raises:
    for crlf in [False, True]:
        var nl = "\r\n" if crlf else "\n"
        var events = List[List[UInt8]]()
        var ended = _sse(
            [
                "event: next" + nl + 'data: {"data":{"hello":"wor',
                'ld"}}' + nl + nl + "eve",
                "nt: complete" + nl + nl,
            ],
            events,
        )
        assert_true(ended)
        assert_equal(_texts(events), ['{"data":{"hello":"world"}}'])
    # Heartbeats, events without data and unknown events are skipped.
    var events = List[List[UInt8]]()
    assert_false(
        _sse(
            [":\n\nevent: next\n\ndata: x\n\nevent: ping\ndata: y\n\n"], events
        )
    )
    assert_equal(len(events), 0)


def test_sse_buffer_limit() raises:
    assert_equal(SseParser().limit, MAX_BUFFER_SIZE)
    var parser = SseParser(16)
    var big = List[UInt8](length=17, fill=65)
    var failed = False
    try:
        parser.feed(Span(big))
    except error:
        failed = True
        assert_true(String(error).startswith("Buffer size limit exceeded"))
    assert_true(failed)


def test_parse_boundary_from_header() raises:
    assert_equal(
        parse_boundary_from_header("multipart/mixed; boundary=graphql"),
        "graphql",
    )
    # A control byte below tab does not end an unquoted boundary.
    assert_equal(
        parse_boundary_from_header("multipart/mixed; boundary=a\x01b"),
        "a\x01b",
    )
    assert_equal(
        parse_boundary_from_header('multipart/mixed; boundary="my-boundary"'),
        "my-boundary",
    )
    assert_equal(
        parse_boundary_from_header("multipart/mixed;   boundary=graphql"),
        "graphql",
    )
    assert_equal(
        parse_boundary_from_header(
            "multipart/mixed; boundary=graphql; charset=utf-8"
        ),
        "graphql",
    )
    assert_equal(
        parse_boundary_from_header(
            'multipart/mixed; boundary="my-boundary"; charset=utf-8'
        ),
        "my-boundary",
    )
    assert_equal(
        parse_boundary_from_header(
            "multipart/mixed; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW"
        ),
        "----WebKitFormBoundary7MA4YWxkTrZu0gW",
    )
    assert_equal(
        parse_boundary_from_header(
            'multipart/mixed; boundary=graphql; subscriptionSpec="1.0"'
        ),
        "graphql",
    )
    assert_equal(
        parse_boundary_from_header(
            "multipart/mixed;"
            ' boundary="boundary-with-dashes_and_underscores.123"'
        ),
        "boundary-with-dashes_and_underscores.123",
    )
    for header in [
        "multipart/mixed; Boundary=graphql",
        "multipart/mixed; BOUNDARY=graphql",
        "multipart/mixed; bOuNdArY=graphql",
    ]:
        assert_equal(parse_boundary_from_header(header), "graphql")
    assert_equal(
        parse_boundary_from_header("multipart/mixed; boundary=my boundary"),
        "my",
    )
    assert_equal(
        parse_boundary_from_header('multipart/mixed; boundary="my boundary"'),
        "my boundary",
    )
    assert_equal(parse_boundary_from_header("multipart/mixed; boundary=-"), "-")
    assert_equal(
        parse_boundary_from_header("multipart/mixed; boundary=graphql   "),
        "graphql",
    )
    assert_equal(
        parse_boundary_from_header("multipart/mixed; boundary=a\tb"), "a"
    )
    for pair in [
        (
            "multipart/mixed",
            "Missing boundary parameter in Content-Type header",
        ),
        ("", "Missing boundary parameter in Content-Type header"),
        (
            "multipart/mixed; boundary=",
            "Invalid boundary parameter: Empty boundary value",
        ),
        (
            'multipart/mixed; boundary=""',
            "Invalid boundary parameter: Empty boundary value",
        ),
        (
            'multipart/mixed; boundary="graphql',
            "Invalid boundary parameter: Unclosed quoted boundary",
        ),
    ]:
        var failed = False
        try:
            _ = parse_boundary_from_header(pair[0])
        except error:
            failed = True
            assert_equal(String(error), pair[1])
        assert_true(failed)


def _payload(body: String) -> String:
    var out = List[UInt8]()
    if not extract_payload(body, out):
        return "None"
    return String(unsafe_from_utf8=Span(out))


def test_parts_and_payloads() raises:
    assert_equal(
        extract_body_after_headers(
            "Content-Type:"
            ' application/json\r\n\r\n{"payload":{"data":{"reviewAdded":{"id":"1"}}}}'
        ),
        '{"payload":{"data":{"reviewAdded":{"id":"1"}}}}',
    )
    assert_equal(
        extract_body_after_headers('\r\n{"payload":{"data":{"value":1}}}'),
        '{"payload":{"data":{"value":1}}}',
    )
    assert_equal(extract_body_after_headers("A: b\n\n {} "), "{}")
    assert_equal(
        _payload('{"payload":{"data":{"reviewAdded":{"id":"1"}}}}'),
        '{"data":{"reviewAdded":{"id":"1"}}}',
    )
    assert_equal(
        _payload('{"data":{"user":{"name":"Alice"}}}'),
        '{"data":{"user":{"name":"Alice"}}}',
    )
    assert_equal(_payload("{}"), "None")
    assert_equal(
        _payload('{"payload":null,"errors":[{"message":"Connection lost"}]}'),
        '{"errors":[{"message":"Connection lost"}]}',
    )
    assert_equal(_payload('{"payload":null}'), "None")
    assert_equal(_payload("[1]"), "[1]")
    assert_equal(_payload("not json"), "not json")


def _multipart(
    boundary: String, chunks: List[String], mut events: List[List[UInt8]]
) raises -> Bool:
    var parser = MultipartParser(boundary)
    var ended = False
    for chunk in chunks:
        parser.feed(chunk.as_bytes())
        ended = parser.take(events)
    return ended


def test_multipart_waits_for_the_line_after_the_first_delimiter() raises:
    var events = List[List[UInt8]]()
    assert_false(
        _multipart(
            "graphql",
            [
                "--gra",
                "phql",
                "\r\nContent-Type: application/json\r\n\r\n{}",
            ],
            events,
        )
    )
    assert_equal(len(events), 0)


def test_multipart_parse_to_stream() raises:
    var head = "Content-Type: application/json\r\n\r\n"
    var events = List[List[UInt8]]()
    assert_true(
        _multipart(
            "graphql",
            [
                "--graphql\r\n"
                + head
                + '{"payload":{"data":{"test":1}}}\r\n--graphql--\r\n'
            ],
            events,
        )
    )
    assert_equal(_texts(events), ['{"data":{"test":1}}'])
    events.clear()
    assert_true(
        _multipart(
            "graphql",
            [
                "--graphql\r\n" + head + '{"pay',
                'load":{"data":{"value":1}}}\r\n--graphql\r\n',
                head + '{"payload":{"data":{"value":2}}}\r\n--graphql--\r\n',
            ],
            events,
        )
    )
    assert_equal(
        _texts(events), ['{"data":{"value":1}}', '{"data":{"value":2}}']
    )
    events.clear()
    assert_true(
        _multipart(
            "graphql",
            [
                "--graphql\r\n"
                + head
                + "{}\r\n--graphql\r\n"
                + head
                + '{"payload":{"data":{"test":1}}}\r\n--graphql--\r\n'
            ],
            events,
        )
    )
    assert_equal(_texts(events), ['{"data":{"test":1}}'])
    events.clear()
    assert_true(
        _multipart(
            "graphql",
            [
                "--graphql\r\n"
                + head
                + '{"payload":null,"errors":[{"message":"Connection'
                ' lost"}]}\r\n--graphql--\r\n'
            ],
            events,
        )
    )
    assert_equal(_texts(events), ['{"errors":[{"message":"Connection lost"}]}'])
    events.clear()
    assert_true(
        _multipart(
            "myboundary",
            [
                "--myboundary\r\n"
                + head
                + '{"data":{"test":1}}\r\n--myboundary--\r\n'
            ],
            events,
        )
    )
    assert_equal(_texts(events), ['{"data":{"test":1}}'])
    events.clear()
    # The end without a line break, an empty part, a part of headers only,
    # and content that waits for the line after the first delimiter.
    assert_false(_multipart("-", ["preamble ---"], events))
    assert_true(
        _multipart("-", ["---\r\n---\r\nA: b\r\n\r\n---\r\n-----"], events)
    )
    assert_equal(len(events), 0)
    assert_false(_multipart("-", ["---\r\n{}"], events))
    assert_true(_multipart("-", ["---\r\n{}\r\n--", "---"], events))
    var invalid = MultipartParser("-")
    invalid.feed("---\r\n".as_bytes())
    invalid.feed([UInt8(0xFF)])
    invalid.feed("\r\n-----".as_bytes())
    var failed = False
    try:
        _ = invalid.take(events)
    except:
        failed = True
    assert_true(failed)
    var big = MultipartParser("-", 16)
    failed = False
    try:
        big.feed(Span(List[UInt8](length=17, fill=65)))
    except error:
        failed = True
        assert_true(String(error).endswith("without a part boundary"))
    assert_true(failed)


def _framed(type: StreamContentType) -> String:
    var format = StreamFormat(type)
    var out = List[UInt8]()
    format.result(out, '{"data":1}'.as_bytes())
    format.heartbeat(out)
    format.end(out)
    return String(unsafe_from_utf8=Span(out))


def test_stream_formats() raises:
    assert_equal(
        _framed(StreamContentType.SSE),
        'event: next\ndata: {"data":1}\n\n:\n\nevent: complete\n\n',
    )
    assert_equal(
        _framed(StreamContentType.INCREMENTAL_DELIVERY),
        '---\r\nContent-Type: application/json\r\n\r\n{"data":1}\r\n-----',
    )
    assert_equal(
        _framed(StreamContentType.APOLLO_MULTIPART_HTTP),
        "--graphql\r\nContent-Type:"
        ' application/json\r\n\r\n{"payload":{"data":1}}\r\n'
        + "--graphql\r\nContent-Type:"
        " application/json\r\n\r\n{}\r\n--graphql--",
    )
    assert_equal(
        StreamFormat(StreamContentType.SSE).content_type(), SSE_CONTENT_TYPE
    )
    assert_equal(
        StreamFormat(StreamContentType.INCREMENTAL_DELIVERY).content_type(),
        INCREMENTAL_DELIVERY_CONTENT_TYPE,
    )
    assert_equal(
        StreamFormat(StreamContentType.APOLLO_MULTIPART_HTTP).content_type(),
        APOLLO_MULTIPART_HTTP_CONTENT_TYPE,
    )
    assert_true(StreamFormat(StreamContentType.SSE).has_heartbeat())
    assert_false(
        StreamFormat(StreamContentType.INCREMENTAL_DELIVERY).has_heartbeat()
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
