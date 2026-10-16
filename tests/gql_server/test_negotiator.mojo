# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.negotiator` and of the query string reader of
`gql_server.run_http_query`. Every expected value comes from the packages
that Apollo Server 5.5.1 uses, run in Node.js: `negotiator` 1.1.0
`mediaType`, `whatwg-mimetype` 4.0.0 `MIMEType.parse(...).essence`,
`content-type` 2.1.0 `parse(...).parameters`, JavaScript `parseFloat` and
WHATWG `URLSearchParams`.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from gql_server.negotiator import (
    media_type_parameter,
    mime_essence,
    parse_float,
    preferred_media_type,
)
from gql_server.run_http_query import search_params


def _preferred(accept: String) -> String:
    var provided: List[String] = [
        "text/html",
        "application/json; charset=utf-8",
        "text/*",
        "application/xml; q=0.5",
    ]
    return preferred_media_type(accept, provided).or_else("<none>")


def test_media_type() raises:
    assert_equal(_preferred(""), "<none>")
    assert_equal(_preferred("*/*"), "text/*")
    assert_equal(_preferred("text/html;q=0"), "<none>")
    assert_equal(_preferred("TEXT/HTML"), "text/html")
    assert_equal(_preferred("text/*, application/json"), "text/*")
    assert_equal(_preferred("application/json;charset=UTF-8"), "application/json; charset=utf-8")
    assert_equal(_preferred('application/json;charset="utf-8"'), "application/json; charset=utf-8")
    assert_equal(_preferred("application/json;charset=*"), "application/json; charset=utf-8")
    assert_equal(_preferred("application/json;q=abc, text/html;q=0.1"), "text/html")
    assert_equal(_preferred("application/json;q=, text/html;q=0.5"), "application/json; charset=utf-8")
    assert_equal(_preferred("foo, */*;q=0.1"), "text/*")
    assert_equal(_preferred(" text/plain ; q = 0.9 , text/html;level=1"), "<none>")
    assert_equal(
        _preferred("application/json; charset=utf-8; q=0.3, text/html; q=0.3"),
        "application/json; charset=utf-8",
    )
    assert_equal(_preferred("*/json"), "application/json; charset=utf-8")
    assert_equal(_preferred("text/html;q=1e0, application/*;q=1"), "text/html")
    assert_equal(_preferred('application/json; foo="a\\"b"'), "<none>")
    assert_equal(_preferred('application/json; foo="unterminated'), "application/json; charset=utf-8")
    assert_equal(_preferred("application/json; ;; bare; x=1"), "<none>")
    assert_equal(_preferred("text/html;q=.5, application/json;q=0.50"), "text/html")
    assert_equal(_preferred("text/html;q=+1, application/json;q=-1"), "text/html")
    assert_equal(_preferred("text/*;q=Infinity"), "text/*")
    var provided: List[String] = ["text/html"]
    assert_equal(preferred_media_type(None, provided).value(), "text/html")


def test_mime_essence() raises:
    assert_equal(mime_essence(" Text/Plain ; x").value(), "text/plain")
    assert_equal(mime_essence("a/b").value(), "a/b")
    assert_equal(mime_essence("a/b ;").value(), "a/b")
    assert_equal(mime_essence("\ttext/html\r\n").value(), "text/html")
    assert_equal(
        mime_essence("application/x-www-form-urlencoded; charset=utf-8").value(),
        "application/x-www-form-urlencoded",
    )
    assert_equal(mime_essence("A0z!#$%&'*+-.^_`|~/Z9").value(), "a0z!#$%&'*+-.^_`|~/z9")
    for text in ["invalid", "//", "a/", "/b", "a b/c", "a/b c", "x@/y", "é/x", "a:/b", "[/b", "{/b", "", "  "]:
        assert_false(Bool(mime_essence(String(text))), String(text))


def test_media_type_parameter() raises:
    assert_equal(media_type_parameter("application/json; charset=UTF-8", "charset").value(), "UTF-8")
    assert_equal(media_type_parameter('application/json;charset="utf-16"', "charset").value(), "utf-16")
    assert_false(Bool(media_type_parameter("application/json", "charset")))
    assert_equal(
        media_type_parameter("application/json; Charset = latin1 ; charset=x", "charset").value(),
        "latin1",
    )


def test_parse_float() raises:
    assert_equal(parse_float("0.5"), 0.5)
    assert_equal(parse_float(" -1e2x"), -100.0)
    assert_equal(parse_float(".5"), 0.5)
    assert_equal(parse_float("007.25"), 7.25)
    assert_equal(parse_float("1."), 1.0)
    assert_equal(parse_float("+3"), 3.0)
    assert_equal(parse_float("1e"), 1.0)
    assert_equal(parse_float("1e+"), 1.0)
    assert_equal(parse_float("2e-1"), 0.2)
    assert_equal(parse_float("\n4"), 4.0)
    assert_equal(parse_float("0"), 0.0)
    assert_true(parse_float("Infinity") > 1e308)
    assert_true(parse_float("-Infinity") < -1e308)
    for text in ["abc", "", "-", "."]:
        var value = parse_float(String(text))
        assert_true(value != value, String(text))


def _params(search: String) -> String:
    var out = String("")
    for ref param in search_params(search):
        out += "[" + param.name + "=" + param.value + "]"
    return out^


def test_search_params() raises:
    assert_equal(_params(""), "")
    assert_equal(_params("?"), "")
    assert_equal(_params("?a=1&b=2&a=3"), "[a=1][b=2][a=3]")
    assert_equal(_params("a=%41%4&b=%zz&c=%4z"), "[a=A%4][b=%zz][c=%4z]")
    assert_equal(_params("x+y=1+2&&=&k"), "[x y=1 2][=][k=]")
    assert_equal(_params("%C3%A9=%FF"), "[é=\ufffd]")
    assert_equal(_params("?q"), "[q=]")
    assert_equal(_params("%e2%9c%93=%Ab"), "[✓=\ufffd]")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
