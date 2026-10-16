# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http.url`: percent-decoding (RFC 3986 section 2.1),
query strings (WHATWG `application/x-www-form-urlencoded`) and absolute
URLs (RFC 3986 section 3)."""

from gql_http.error import ErrorKind
from gql_http.url import (
    QueryParam,
    Url,
    parse_query,
    percent_decode,
    query_value,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _decode_error(text: StaticString) raises -> String:
    try:
        _ = percent_decode(text)
    except e:
        assert_true(e.kind == ErrorKind.PROTOCOL)
        return e.message.copy()
    return "no error"


def test_percent_decode() raises:
    assert_equal(percent_decode(""), "")
    assert_equal(percent_decode("a%20b%2fc%2Fd"), "a b/c/d")
    assert_equal(percent_decode("%41%7a%7A%09"), "Azz\t")
    assert_equal(percent_decode("%C3%A9"), "é")
    assert_equal(percent_decode("a+b"), "a+b")
    assert_equal(percent_decode("a+b", True), "a b")
    assert_equal(_decode_error("%"), "truncated percent escape")
    assert_equal(_decode_error("ab%4"), "truncated percent escape")
    assert_equal(_decode_error("%G1"), "invalid percent escape")
    assert_equal(_decode_error("%1g"), "invalid percent escape")
    assert_equal(_decode_error("%@1"), "invalid percent escape")
    assert_equal(_decode_error("%1/"), "invalid percent escape")
    assert_equal(_decode_error("%1:"), "invalid percent escape")
    assert_equal(
        _decode_error("%FF"), "percent escapes decode to invalid UTF-8"
    )


def test_parse_query() raises:
    var params = parse_query("a=1&&b=%20x+y&flag&=v&a=2=3")
    assert_equal(len(params), 5)
    assert_equal(params[0].name, "a")
    assert_equal(params[0].value, "1")
    assert_equal(params[1].name, "b")
    assert_equal(params[1].value, " x y")
    assert_equal(params[2].name, "flag")
    assert_equal(params[2].value, "")
    assert_equal(params[3].name, "")
    assert_equal(params[3].value, "v")
    assert_equal(params[4].value, "2=3")
    assert_equal(len(parse_query("")), 0)
    assert_equal(query_value(params, "a").value(), "1")
    assert_false(Bool(query_value(params, "A")))
    assert_false(Bool(query_value(List[QueryParam](), "a")))
    var failed = False
    try:
        _ = parse_query("a=%zz")
    except e:
        failed = e.kind == ErrorKind.PROTOCOL
    assert_true(failed)


def test_url_parts() raises:
    var url = Url.parse("HTTP://user:pw@LocalHost:4000/graphql?x=1&y#frag")
    assert_equal(url.scheme, "http")
    assert_equal(url.userinfo, "user:pw")
    assert_equal(url.host, "localhost")
    assert_equal(url.port, 4000)
    assert_equal(url.path, "/graphql")
    assert_equal(url.query, "x=1&y")
    assert_equal(url.fragment, "frag")
    assert_equal(url.target(), "/graphql?x=1&y")
    assert_equal(url.authority(), "localhost:4000")
    assert_equal(String(url), "http://localhost:4000/graphql?x=1&y#frag")


def test_url_defaults() raises:
    var http = Url.parse("http://example.com")
    assert_equal(http.port, 80)
    assert_equal(http.path, "/")
    assert_equal(http.userinfo, "")
    assert_equal(http.target(), "/")
    assert_equal(http.authority(), "example.com")
    assert_equal(String(http), "http://example.com/")
    var https = Url.parse("https://example.com?q")
    assert_equal(https.port, 443)
    assert_equal(https.path, "/")
    assert_equal(https.query, "q")
    assert_equal(https.authority(), "example.com")
    var https80 = Url.parse("https://example.com:80/")
    assert_equal(https80.authority(), "example.com:80")
    var http443 = Url.parse("http://example.com:443/")
    assert_equal(http443.authority(), "example.com:443")
    var ws = Url.parse("ws+a-b.c://h#x")
    assert_equal(ws.port, -1)
    assert_equal(ws.path, "/")
    assert_equal(ws.fragment, "x")
    assert_equal(ws.authority(), "h")
    assert_equal(Url.parse("ws://h:9").authority(), "h:9")
    assert_equal(Url.parse("http://h:/p").port, 80)
    var v6 = Url.parse("http://[::1]:8080/p")
    assert_equal(v6.host, "[::1]")
    assert_equal(v6.port, 8080)
    assert_equal(Url.parse("http://[::1]").port, 80)
    assert_equal(Url.parse("http://h:65535").port, 65535)
    assert_equal(Url.parse("s3://h").scheme, "s3")


def _url_error(text: StaticString) raises -> String:
    try:
        _ = Url.parse(text)
    except e:
        assert_true(e.kind == ErrorKind.PROTOCOL)
        return e.message.copy()
    return "no error"


def test_url_errors() raises:
    comptime SPACE = "a URL cannot hold white space or controls"
    assert_equal(_url_error("http://a b"), SPACE)
    assert_equal(_url_error("http://a\x7f"), SPACE)
    assert_equal(_url_error("http://a\x01"), SPACE)
    assert_equal(_url_error("://h"), "expected scheme://")
    assert_equal(_url_error("h"), "expected scheme://")
    assert_equal(_url_error(""), "expected scheme://")
    assert_equal(_url_error("http://"), "a URL needs a host")
    assert_equal(_url_error("h_p://h"), "invalid scheme")
    assert_equal(_url_error("a/b://h"), "invalid scheme")
    assert_equal(_url_error("a:b://h"), "invalid scheme")
    assert_equal(_url_error("a{b://h"), "invalid scheme")
    assert_equal(_url_error("http://[::1"), "unterminated IPv6 literal")
    assert_equal(_url_error("http:///p"), "a URL needs a host")
    assert_equal(_url_error("http://u@:80"), "a URL needs a host")
    assert_equal(_url_error("http://[::1]x"), "invalid text after the host")
    assert_equal(_url_error("http://h:123456"), "invalid port")
    assert_equal(_url_error("http://h:8!"), "invalid port")
    assert_equal(_url_error("http://h:8a"), "invalid port")
    assert_equal(_url_error("http://h:65536"), "invalid port")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
