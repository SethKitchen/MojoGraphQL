# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http.status` and `gql_http.error`: status codes and their
reason phrases (RFC 9110 section 15), methods (section 9), versions, and
the kinds of transport errors."""

from gql_http.error import ErrorKind, HttpError
from gql_http.status import Method, Status, Version
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _reason(code: Int, phrase: StaticString) raises:
    assert_equal(String(Status(code).reason()), String(phrase), String(code))


def test_reason_phrases() raises:
    _reason(100, "Continue")
    _reason(101, "Switching Protocols")
    _reason(200, "OK")
    _reason(201, "Created")
    _reason(202, "Accepted")
    _reason(204, "No Content")
    _reason(203, "")
    _reason(301, "Moved Permanently")
    _reason(302, "Found")
    _reason(303, "See Other")
    _reason(304, "Not Modified")
    _reason(307, "Temporary Redirect")
    _reason(308, "Permanent Redirect")
    _reason(305, "")
    _reason(400, "Bad Request")
    _reason(401, "Unauthorized")
    _reason(403, "Forbidden")
    _reason(404, "Not Found")
    _reason(405, "Method Not Allowed")
    _reason(406, "Not Acceptable")
    _reason(408, "Request Timeout")
    _reason(409, "Conflict")
    _reason(411, "Length Required")
    _reason(413, "Content Too Large")
    _reason(414, "URI Too Long")
    _reason(415, "Unsupported Media Type")
    _reason(417, "Expectation Failed")
    _reason(422, "Unprocessable Content")
    _reason(429, "Too Many Requests")
    _reason(431, "Request Header Fields Too Large")
    _reason(402, "")
    _reason(500, "Internal Server Error")
    _reason(501, "Not Implemented")
    _reason(502, "Bad Gateway")
    _reason(503, "Service Unavailable")
    _reason(504, "Gateway Timeout")
    _reason(505, "HTTP Version Not Supported")
    _reason(506, "")


def test_status_classes() raises:
    assert_false(Status(99).is_valid())
    assert_true(Status(100).is_valid())
    assert_true(Status(599).is_valid())
    assert_false(Status(600).is_valid())
    assert_false(Status(99).is_informational())
    assert_true(Status(100).is_informational())
    assert_true(Status(199).is_informational())
    assert_false(Status(200).is_informational())
    assert_true(Status.OK.has_body())
    assert_false(Status.CONTINUE.has_body())
    assert_false(Status.NO_CONTENT.has_body())
    assert_false(Status.NOT_MODIFIED.has_body())
    assert_equal(String(Status.NOT_FOUND), "404 Not Found")
    assert_true(Status.OK == Status(200))
    assert_true(Status.OK != Status.CREATED)


def test_method_text() raises:
    var names: List[String] = [
        "GET",
        "HEAD",
        "POST",
        "PUT",
        "DELETE",
        "CONNECT",
        "OPTIONS",
        "TRACE",
        "PATCH",
        "",
    ]
    for index in range(len(names)):
        var method = Method(UInt8(index))
        assert_true(method.is_valid())
        assert_equal(String(method.text()), names[index])
        assert_equal(String(method), names[index])
    assert_false(Method(10).is_valid())
    assert_equal(String(Method(10).text()), "")


def test_method_idempotent() raises:
    assert_true(Method.GET.is_idempotent())
    assert_true(Method.HEAD.is_idempotent())
    assert_false(Method.POST.is_idempotent())
    assert_true(Method.PUT.is_idempotent())
    assert_true(Method.DELETE.is_idempotent())
    assert_false(Method.CONNECT.is_idempotent())
    assert_true(Method.OPTIONS.is_idempotent())
    assert_true(Method.TRACE.is_idempotent())
    assert_false(Method.PATCH.is_idempotent())
    assert_false(Method.OTHER.is_idempotent())


def _parse(token: StaticString) -> Method:
    return Method.from_bytes(token.as_bytes())


def test_method_from_bytes() raises:
    assert_true(_parse("GET") == Method.GET)
    assert_true(_parse("PUT") == Method.PUT)
    assert_true(_parse("PUX") == Method.OTHER)
    assert_true(_parse("get") == Method.OTHER)
    assert_true(_parse("POST") == Method.POST)
    assert_true(_parse("HEAD") == Method.HEAD)
    assert_true(_parse("HEAX") == Method.OTHER)
    assert_true(_parse("PATCH") == Method.PATCH)
    assert_true(_parse("TRACE") == Method.TRACE)
    assert_true(_parse("TRACX") == Method.OTHER)
    assert_true(_parse("DELETE") == Method.DELETE)
    assert_true(_parse("DELETX") == Method.OTHER)
    assert_true(_parse("OPTIONS") == Method.OPTIONS)
    assert_true(_parse("CONNECT") == Method.CONNECT)
    assert_true(_parse("CONNECX") == Method.OTHER)
    assert_true(_parse("GE") == Method.OTHER)
    assert_true(_parse("PROPFIND") == Method.OTHER)


def test_version() raises:
    assert_true(Version.HTTP_1_0.is_valid())
    assert_true(Version.HTTP_1_1.is_valid())
    assert_false(Version(2).is_valid())
    assert_equal(String(Version.HTTP_1_0), "HTTP/1.0")
    assert_equal(String(Version.HTTP_1_1), "HTTP/1.1")
    assert_equal(String(Version(2).text()), "HTTP/1.1")
    assert_true(Version.HTTP_1_0 != Version.HTTP_1_1)


def test_error_kinds() raises:
    var names: List[String] = [
        "os",
        "resolve",
        "connect",
        "timeout",
        "closed",
        "protocol",
        "limit",
        "usage",
    ]
    for index in range(len(names)):
        var kind = ErrorKind(UInt8(index))
        assert_true(kind.is_valid())
        assert_equal(String(kind), names[index])
    assert_false(ErrorKind(8).is_valid())
    assert_equal(String(ErrorKind(8).text()), "invalid")
    assert_true(ErrorKind.OS == ErrorKind(0))


def test_http_error() raises:
    var error = HttpError.os("bind", 98)
    assert_true(error.kind == ErrorKind.OS)
    assert_equal(error.errno, 98)
    assert_equal(String(error), "os: bind failed: errno 98")
    var timeout = HttpError(ErrorKind.TIMEOUT, "read timed out", 0)
    assert_equal(String(timeout), "timeout: read timed out")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
