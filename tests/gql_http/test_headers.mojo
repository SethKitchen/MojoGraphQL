# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http.headers`: fields to send, media types (RFC 9110
section 8.3.1) and `Accept` lists (RFC 9110 section 12.5.1)."""

from gql_http.error import ErrorKind
from gql_http.headers import (
    Headers,
    MediaRange,
    accept_quality,
    is_field_value,
    is_token,
    parse_accept,
    parse_media_type,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_tokens_and_values() raises:
    assert_false(is_token(""))
    assert_true(is_token("Content-Type"))
    assert_true(is_token("!#$%&'*+-.^_`|~09az"))
    assert_false(is_token("a b"))
    assert_false(is_token("a:b"))
    assert_true(is_field_value(""))
    assert_true(is_field_value("a\tb c"))
    assert_false(is_field_value("a\rb"))
    assert_false(is_field_value("a\nb"))


def _add_error(name: StaticString, value: StaticString) raises -> String:
    var headers = Headers()
    try:
        headers.add(name, value)
    except e:
        assert_true(e.kind == ErrorKind.USAGE)
        return e.message.copy()
    return "no error"


def test_headers_add_and_get() raises:
    var headers = Headers()
    assert_equal(len(headers), 0)
    headers.add("Content-Type", " text/plain \t")
    headers.add("Set-Cookie", "a=1")
    headers.add("set-cookie", "b=2")
    assert_equal(len(headers), 3)
    assert_equal(String(headers.name(0)), "Content-Type")
    assert_equal(String(headers.value(0)), "text/plain")
    assert_equal(
        String(unsafe_from_utf8=headers.data),
        "Content-Type: text/plain\r\nSet-Cookie: a=1\r\nset-cookie: b=2\r\n",
    )
    assert_equal(headers.find("SET-COOKIE"), 1)
    assert_equal(headers.find("Accept"), -1)
    assert_equal(String(headers.get("content-type").value()), "text/plain")
    assert_false(Bool(headers.get("Accept")))
    assert_equal(_add_error("Bad Name", "x"), "invalid header name: Bad Name")
    assert_equal(_add_error("", "x"), "invalid header name: ")
    assert_equal(
        _add_error("X-A", "a\r\nX-B: b"), "invalid value for header X-A"
    )


def test_headers_set_remove_clear() raises:
    var headers = Headers()
    headers.add("A", "1")
    headers.add("B", "2")
    headers.add("a", "3")
    headers.set("A", "4")
    assert_equal(len(headers), 2)
    assert_equal(String(headers.name(0)), "B")
    assert_equal(String(headers.get("a").value()), "4")
    headers.remove("missing")
    assert_equal(len(headers), 2)
    headers.remove("b")
    assert_equal(len(headers), 1)
    assert_equal(String(unsafe_from_utf8=headers.data), "A: 4\r\n")
    headers.clear()
    assert_equal(len(headers), 0)
    assert_equal(len(headers.data), 0)


def test_media_type() raises:
    var media = parse_media_type('Application/JSON ; Charset=UTF-8;\tq="a\\"b"')
    assert_equal(media.type, "application")
    assert_equal(media.subtype, "json")
    assert_equal(media.essence(), "application/json")
    assert_equal(len(media.parameters), 2)
    assert_equal(media.parameter("CHARSET").value(), "UTF-8")
    assert_equal(media.parameter("q").value(), 'a"b')
    assert_false(Bool(media.parameter("boundary")))
    assert_equal(String(media), 'application/json;charset=UTF-8;q=a"b')
    var bare = parse_media_type("text/plain;")
    assert_equal(len(bare.parameters), 0)
    assert_equal(String(bare), "text/plain")
    assert_false(Bool(bare.parameter("charset")))


def _media_error(text: StaticString) raises -> String:
    try:
        _ = parse_media_type(text)
    except e:
        assert_true(e.kind == ErrorKind.USAGE)
        return e.message.copy()
    return "no error"


def test_media_type_errors() raises:
    assert_equal(_media_error(""), "expected type/subtype")
    assert_equal(_media_error("/json"), "expected type/subtype")
    assert_equal(_media_error("text"), "expected type/subtype")
    assert_equal(_media_error("text;x"), "expected type/subtype")
    assert_equal(_media_error("text/"), "expected type/subtype")
    assert_equal(_media_error("text/plain x"), "expected ; before a parameter")
    assert_equal(_media_error("text/plain; =x"), "expected name=value")
    assert_equal(_media_error("text/plain; a"), "expected name=value")
    assert_equal(_media_error("text/plain; a;b"), "expected name=value")
    assert_equal(_media_error("text/plain; a="), "expected a parameter value")
    assert_equal(_media_error("text/plain; a=;"), "expected a parameter value")
    assert_equal(_media_error('text/plain; a="x'), "unterminated quoted string")
    assert_equal(
        _media_error('text/plain; a="x\\'), "unterminated quoted string"
    )
    assert_equal(
        _media_error('text/plain; a="x\ry"'), "invalid byte in a quoted string"
    )
    assert_equal(
        _media_error("text/plain, text/html"),
        "unexpected text after the media type",
    )
    assert_equal(
        _media_error("text/plain;, text/html"),
        "unexpected text after the media type",
    )


def _q(text: StaticString) -> Int:
    """Return the weight of one range, or -1 when it is dropped."""
    var ranges = parse_accept(String("a/b;q=") + text)
    if len(ranges) == 0:
        return -1
    return ranges[0].quality


def test_quality_values() raises:
    assert_equal(_q("0"), 0)
    assert_equal(_q("1"), 1000)
    assert_equal(_q("2"), -1)
    assert_equal(_q('""'), -1)
    assert_equal(_q("0.12345"), -1)
    assert_equal(_q("0x"), -1)
    assert_equal(_q("1."), 1000)
    assert_equal(_q("1.000"), 1000)
    assert_equal(_q("1.5"), -1)
    assert_equal(_q("0.5"), 500)
    assert_equal(_q("0.123"), 123)
    assert_equal(_q("0./"), -1)
    assert_equal(_q("0.!"), -1)
    assert_equal(_q("0.a"), -1)


def test_parse_accept() raises:
    var ranges = parse_accept(
        "junk, text/html;level=1;q=0.5;ext=1 ,*/*;q=2, application/*"
    )
    assert_equal(len(ranges), 2)
    assert_equal(ranges[0].media.essence(), "text/html")
    assert_equal(ranges[0].quality, 500)
    assert_equal(len(ranges[0].media.parameters), 1)
    assert_equal(ranges[0].media.parameters[0].name, "level")
    assert_equal(ranges[1].media.essence(), "application/*")
    assert_equal(ranges[1].quality, 1000)
    assert_equal(len(parse_accept("")), 0)
    assert_equal(len(parse_accept("a/b, junk")), 1)
    assert_equal(len(parse_accept("a/b;, c/d")), 2)


def _range(text: StaticString) raises -> MediaRange:
    var ranges = parse_accept(text)
    assert_equal(len(ranges), 1)
    return ranges[0].copy()


def test_media_range() raises:
    var any = _range("*/*")
    assert_true(any.matches("text", "html"))
    assert_equal(any.specificity(), 0)
    var text = _range("text/*")
    assert_true(text.matches("TEXT", "html"))
    assert_false(text.matches("image", "png"))
    assert_equal(text.specificity(), 1)
    var html = _range("text/html;level=1")
    assert_true(html.matches("text", "HTML"))
    assert_false(html.matches("text", "plain"))
    assert_equal(html.specificity(), 3)


def test_accept_quality() raises:
    assert_equal(accept_quality("", "a", "b"), 1000)
    assert_equal(accept_quality(" \t", "a", "b"), 1000)
    assert_equal(accept_quality("junk", "a", "b"), 0)
    assert_equal(accept_quality("application/json", "text", "plain"), 0)
    var accept = "*/*;q=0.1, application/*;q=0.5, application/json;q=0.9"
    assert_equal(accept_quality(accept, "application", "json"), 900)
    assert_equal(accept_quality(accept, "application", "xml"), 500)
    assert_equal(accept_quality(accept, "text", "plain"), 100)
    assert_equal(accept_quality("a/b;q=0.2, a/b;q=0.3", "a", "b"), 200)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
