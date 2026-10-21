# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_sse.event`. Ported from graphql-sse 2.6.3
`tests/parser.test.ts`; the snapshots are written out as strings."""

from gql_sse.event import (
    EventParser,
    StreamEvent,
    StreamMessage,
    parse_stream_data,
    print_message,
    print_ping,
    validate_stream_event,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _parse(mut parser: EventParser, text: StringSlice) raises -> String:
    """Feed a text; describe the messages as `event=data;`."""
    var out = List[StreamMessage]()
    parser.feed(text.as_bytes(), out)
    var described = String()
    var i = 0
    while i < len(out):
        described += String(out[i].event) + "=" + out[i].data + ";"
        i += 1
    return described


def _one(text: StringSlice) raises -> String:
    var parser = EventParser()
    return _parse(parser, text)


def _error(text: StringSlice) -> String:
    try:
        _ = _one(text)
    except e:
        return String(e)
    return "no error"


def test_whole_message() raises:
    assert_equal(
        _one('event: next\ndata: { "iAm": "data" }\n\n'),
        'next={ "iAm": "data" };',
    )
    assert_equal(
        _one('event:next\ndata:{ "iAm": "data" }\n\n'),
        'next={ "iAm": "data" };',
    )
    assert_equal(_one("event: complete\n\n"), "complete=;")


def test_prepended_ping() raises:
    assert_equal(
        _one(':\n\nevent:next\ndata:{ "iAm": "data" }\n\n'),
        'next={ "iAm": "data" };',
    )


def test_chunked_message() raises:
    var parser = EventParser()
    assert_equal(_parse(parser, "even"), "")
    assert_equal(_parse(parser, ""), "")
    assert_equal(_parse(parser, "t: ne"), "")
    assert_equal(_parse(parser, "xt\nda"), "")
    assert_equal(_parse(parser, "ta:{"), "")
    assert_equal(_parse(parser, ""), "")
    assert_equal(_parse(parser, ' "iAm'), "")
    assert_equal(_parse(parser, '": "data" }\n\n'), 'next={ "iAm": "data" };')


def test_crlf_lines() raises:
    assert_equal(
        _one('event: next\r\ndata: { "iAm": "data" }\r\n\r\n'),
        'next={ "iAm": "data" };',
    )
    # A CR alone ends a line; a CRLF split over two chunks is one end.
    var parser = EventParser()
    assert_equal(_parse(parser, "event: complete\r"), "")
    assert_equal(_parse(parser, "\n\r"), "complete=;")
    # A CR after a CR is a blank line.
    assert_equal(_one("event: complete\r\r"), "complete=;")


def test_comments() raises:
    assert_equal(
        _one(': I am comment\nevent: next\ndata: { "iAm": "data" }\n\n'),
        'next={ "iAm": "data" };',
    )


def test_valid_events_only() raises:
    assert_equal(
        _error("event: done\ndata: {}\n\n"), 'Invalid stream event "done"'
    )
    assert_equal(
        _error("event: value\ndata: {}\n\n"), 'Invalid stream event "value"'
    )
    assert_equal(_error("event: next\ndata: {}\n\n"), "no error")
    assert_equal(_error("event: complete\ndata: {}\n\n"), "no error")
    assert_equal(_error("data: {}\n\n"), "Missing message event")
    assert_equal(_error("event: next\ndata: {\n\n"), "Invalid stream data")
    assert_equal(
        _error("event: next\n\n"),
        'Stream data must be an object for "next" events',
    )
    assert_equal(
        _error("event: next\ndata: null\n\n"),
        'Stream data must be an object for "next" events',
    )


def test_server_pings() raises:
    assert_equal(_one(":\n\n"), "")


def test_multiple_messages() raises:
    assert_equal(
        _one(
            'event: next\ndata: {}\n\nevent: next\ndata: { "no": "data" }\n\n'
        ),
        'next={};next={ "no": "data" };',
    )
    assert_equal(
        _one(
            'event: next\ndata: { "almost": "done" }\n\nevent:'
            " complete\ndata: {}\n\n"
        ),
        'next={ "almost": "done" };complete={};',
    )


def test_chunk_ends_mid_line() raises:
    var parser = EventParser()
    assert_equal(
        _parse(
            parser,
            (
                'event: next\ndata: { "iAm": "data" }\n\nevent: next\ndata: {'
                ' "iAm": "more" }\n\nevent: ne'
            ),
        ),
        'next={ "iAm": "data" };next={ "iAm": "more" };',
    )
    assert_equal(
        _parse(parser, 'xt\ndata: { "iAm": "last" }\n\n'),
        'next={ "iAm": "last" };',
    )


def test_fields() raises:
    # Lines of `data` join with LF; other fields and colonless lines count
    # for nothing; a field with no value is empty.
    assert_equal(
        _one("id: 1\nevent: next\ndata: [1,\nignored\ndata: 2]\n\n"),
        "next=[1,\n2];",
    )
    assert_equal(_one("event: complete\ndata:\n\n"), "complete=;")
    assert_equal(_one("event: complete\ndata: null\n\n"), "complete=;")


def test_print() raises:
    var out = List[UInt8]()
    print_message(out, StreamEvent.NEXT, '{"data":{}}')
    print_message(out, StreamEvent.COMPLETE, "")
    print_message(out, StreamEvent.COMPLETE, "null")
    print_ping(out)
    assert_equal(
        String(unsafe_from_utf8=out),
        (
            'event: next\ndata: {"data":{}}\n\nevent: complete\ndata:\n\nevent:'
            " complete\ndata:\n\n:\n\n"
        ),
    )
    assert_true(StreamEvent.COMPLETE.is_valid())
    assert_false(StreamEvent(2).is_valid())
    assert_equal(validate_stream_event("next"), StreamEvent.NEXT)
    assert_equal(parse_stream_data(StreamEvent.COMPLETE, "{}"), "{}")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
