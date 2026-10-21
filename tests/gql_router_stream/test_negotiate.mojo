# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the response mode negotiation.

Ports `negotiate_content_types` of Hive Router `1a29df9`
`bin/router/src/pipeline/header.rs`, without the Laboratory cases, and
the `negotiate` and `parse` tests of headers-accept 0.3.0 `src/lib.rs`.
"""

from gql_router_stream.negotiate import (
    MediaRange,
    ResponseMode,
    SingleContentType,
    StreamContentType,
    negotiate,
    negotiate_types,
    parse_accept,
    parse_media_range,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def _mode(accept: String) raises -> String:
    return String(negotiate(accept))


def test_negotiate_content_types() raises:
    var dual_incremental = "Dual(application/json, multipart/mixed)"
    assert_equal(_mode(""), dual_incremental)
    assert_equal(_mode("*/*"), dual_incremental)
    var apollo = (
        'Dual(application/json, multipart/mixed;subscriptionSpec="1.0")'
    )
    assert_equal(
        _mode(
            "application/json, text/event-stream,"
            ' multipart/mixed;subscriptionSpec="1.0"'
        ),
        apollo,
    )
    # Unquoted and quoted boundary parameters.
    assert_equal(
        _mode(
            "multipart/mixed;boundary=graphql;subscriptionSpec=1.0,application/json"
        ),
        apollo,
    )
    assert_equal(
        _mode(
            'multipart/mixed;boundary="graphql";subscriptionSpec=1.0,application/json'
        ),
        apollo,
    )
    assert_equal(
        _mode(
            "application/graphql-response+json, multipart/mixed;q=0.5,"
            " text/event-stream;q=1"
        ),
        "Dual(application/graphql-response+json, text/event-stream)",
    )
    assert_equal(
        _mode("application/json;q=0.5, application/graphql-response+json;q=1"),
        "SingleOnly(application/graphql-response+json)",
    )
    assert_equal(
        _mode(
            "text/event-stream;q=0.5,"
            ' multipart/mixed;q=1;subscriptionSpec="1.0"'
        ),
        'StreamOnly(multipart/mixed;subscriptionSpec="1.0")',
    )
    assert_equal(
        _mode("text/event-stream, application/json"),
        "Dual(application/json, text/event-stream)",
    )
    # A browser, with the Laboratory off.
    assert_equal(
        _mode(
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
        ),
        dual_incremental,
    )
    assert_equal(
        _mode("application/graphql-response+json"),
        "SingleOnly(application/graphql-response+json)",
    )


def test_refusals() raises:
    var failed = False
    try:
        _ = negotiate("text/html")
    except error:
        failed = True
        assert_equal(error.status, 415)
        assert_equal(error.code, "UNSUPPORTED_CONTENT_TYPE")
    assert_true(failed)
    for bad in [
        "application",
        "a/b; q",
        'a/b; c="d',
        "a/b; c=d e",
        "a/b+",
        "a /b",
        "a/b; c d=e",
    ]:
        failed = False
        try:
            _ = negotiate(bad)
        except error:
            failed = True
            assert_equal(error.status, 400)
            assert_equal(error.message, "Header 'accept' has invalid value")
        assert_true(failed, bad)


def test_edges_of_the_parser() raises:
    # A suffix, and parameters, must be the same to match.
    var suffixed = parse_media_range("application/x+json")
    assert_false(suffixed.matches(parse_media_range("application/x")))
    assert_false(
        parse_media_range("a/b;x=1").matches(parse_media_range("a/b;y=1"))
    )
    # Semicolons in quotes do not split; a value that only starts with a
    # quote keeps it.
    var quoted = parse_media_range('a/b; x="1;2"; y=3')
    assert_equal(quoted.values[0], "1;2")
    assert_equal(quoted.values[1], "3")
    with assert_raises():
        _ = parse_media_range('a/b; x="1"2')
    with assert_raises(contains="missing subtype"):
        _ = parse_media_range("")
    with assert_raises(contains="bad type"):
        _ = parse_media_range("a/b@")
    var tokens = parse_media_range("A-1.!/Z_9~")
    assert_equal(tokens.type, "a-1.!")
    assert_equal(tokens.subtype, "z_9~")
    # Bad `q` values count as 1; `0.` is 0.
    assert_equal(parse_media_range("a/b;q=0x5").quality, 1000)
    assert_equal(parse_media_range("a/b;q=0.-").quality, 1000)
    assert_equal(parse_media_range("a/b;q=0.").quality, 0)
    # Empty ranges are skipped.
    assert_equal(len(parse_accept("a/b,,c/d,")), 2)


def test_edges_of_the_negotiation() raises:
    var failed = False
    try:
        _ = negotiate(",")
    except error:
        failed = True
        assert_equal(error.status, 415)
    assert_true(failed)
    assert_equal(
        _mode("application/json, application/graphql-response+json;q=0.5"),
        "SingleOnly(application/json)",
    )
    failed = False
    try:
        _ = negotiate("multipart/form-data")
    except error:
        failed = True
        assert_equal(error.status, 415)
    assert_true(failed)


def test_quality_values() raises:
    # headers-accept `QValue::from_str`: bad values count as 1.
    var ranges = parse_accept(
        "a/a;q=0, a/b;q=1, a/c;q=1.000, a/d;q=0.5, a/e;q=0.05, a/f;q=0.123,"
        " a/g;q=2, a/h;q=0.1234, a/i;q=1.5, a/j;q=0.x, a/k;q=x"
    )
    var by_name = List[Int]()
    for name in "abcdefghijk".as_bytes():
        for ref media in ranges:
            if media.subtype == chr(Int(name)):
                by_name.append(media.quality)
    assert_equal(
        by_name,
        [0, 1000, 1000, 500, 50, 123, 1000, 1000, 1000, 1000, 1000],
    )


def test_headers_accept_negotiate() raises:
    var accept = parse_accept(
        "text/html, application/xhtml+xml, application/xml;q=0.9,"
        " text/*;q=0.7, text/csv;q=0"
    )
    var html = parse_media_range("text/html")
    var json = parse_media_range("application/json")
    var xhtml = parse_media_range("application/xhtml+xml")
    var plain = parse_media_range("text/plain")
    var csv = parse_media_range("text/csv")
    assert_equal(negotiate_types(accept, [html.copy(), json.copy()]), 0)
    assert_equal(negotiate_types(accept, [xhtml.copy(), html.copy()]), 1)
    assert_equal(negotiate_types(accept, [json.copy(), plain.copy()]), 1)
    assert_equal(negotiate_types(accept, [csv.copy(), json.copy()]), -1)
    # A sorted list: specificity first, then quality, stable.
    var sorted = parse_accept("*/*;q=0.1, text/*, text/plain;q=0.2, a/b;c=d")
    assert_equal(sorted[0].subtype, "b")
    assert_equal(sorted[1].subtype, "plain")
    assert_equal(sorted[2].subtype, "*")
    assert_equal(sorted[3].type, "*")
    # Escapes in quotes, and a comma in quotes.
    var quoted = parse_accept('a/b; c="x\\"y,z", d/e')
    assert_equal(len(quoted), 2)
    assert_equal(quoted[0].values[0], 'x"y,z')
    # A different parameter value or count does not match.
    var spec = parse_accept("multipart/mixed;subscriptionSpec=2.0")
    assert_false(spec[0].matches(parse_media_range("multipart/mixed")))
    assert_false(
        spec[0].matches(parse_media_range("multipart/mixed;subscriptionSpec=1"))
    )
    assert_false(spec[0].matches(parse_media_range("multipart/other")))
    assert_false(
        parse_media_range("application/json").matches(
            parse_media_range("application/graphql-response+json")
        )
    )


def test_response_mode() raises:
    var dual = ResponseMode(
        True, SingleContentType.JSON, True, StreamContentType.SSE
    )
    assert_true(dual.can_single())
    assert_true(dual.can_stream())
    assert_false(dual.stream_only())
    assert_true(dual.prefer_status_ok_for_errors())
    var stream = ResponseMode(
        False, SingleContentType.JSON, True, StreamContentType.SSE
    )
    var other = ResponseMode(
        False,
        SingleContentType.GRAPHQL_RESPONSE_JSON,
        True,
        StreamContentType.SSE,
    )
    assert_true(stream == other)
    assert_true(stream.stream_only())
    assert_false(stream.prefer_status_ok_for_errors())
    assert_false(stream == dual)
    var single = ResponseMode(
        True,
        SingleContentType.GRAPHQL_RESPONSE_JSON,
        False,
        StreamContentType.SSE,
    )
    assert_false(single == dual)
    assert_false(
        single
        == ResponseMode(
            True, SingleContentType.JSON, False, StreamContentType.SSE
        )
    )
    assert_false(
        dual
        == ResponseMode(
            True,
            SingleContentType.JSON,
            True,
            StreamContentType.INCREMENTAL_DELIVERY,
        )
    )
    assert_true(SingleContentType.JSON.is_valid())
    assert_false(SingleContentType(2).is_valid())
    assert_true(StreamContentType.SSE.is_valid())
    assert_false(StreamContentType(3).is_valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
