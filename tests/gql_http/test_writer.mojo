# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the parts of `gql_http.server` that need no event loop: the
`Date` format (RFC 9110 section 5.6.7), `ResponseWriter`, `Router`, and the
error paths of `open_listener` and `listen`."""

from _harness import Echo, config, drain, loopback_pair
from gql_http.error import ErrorKind
from gql_http.parser import Limits, RequestReader
from gql_http.server import (
    MatchKind,
    ResponseWriter,
    Router,
    _WriterState,
    format_http_date,
    listen,
    open_listener,
)
from gql_http.socket import (
    EAGAIN,
    EINTR,
    EPIPE,
    Faults,
    IPv4Address,
    Sys,
    SysCall,
)
from gql_http.status import Method, Status
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime DATE = "Date: Sun, 06 Nov 1994 08:49:37 GMT\r\n"
"""The `Date` field of every response here: the example of RFC 9110."""


def test_http_date() raises:
    assert_equal(format_http_date(784111777), "Sun, 06 Nov 1994 08:49:37 GMT")
    assert_equal(format_http_date(0), "Thu, 01 Jan 1970 00:00:00 GMT")
    assert_equal(format_http_date(951782400), "Tue, 29 Feb 2000 00:00:00 GMT")
    assert_equal(format_http_date(1704067199), "Sun, 31 Dec 2023 23:59:59 GMT")


def _writer(text: StringSlice, keep_alive: Bool = True) -> ResponseWriter:
    """Return a writer begun for the request in `text`, on no socket."""
    var reader = RequestReader(Limits())
    reader.append(text.as_bytes())
    _ = reader.next()
    var writer = ResponseWriter()
    writer.set_date(784111777)
    writer.begin(reader.request, -1, keep_alive)
    return writer^


comptime GET = "GET / HTTP/1.1\r\nHost: x\r\n\r\n"
"""An HTTP/1.1 request."""
comptime OLD = "GET / HTTP/1.0\r\n\r\n"
"""An HTTP/1.0 request."""


def _out(writer: ResponseWriter) -> String:
    return String(unsafe_from_utf8=writer.out)


def test_response() raises:
    var writer = _writer(GET)
    writer.add_header("Content-Type", "text/plain")
    writer.write_text("hi")
    assert_false(writer.committed())
    writer.finish()
    assert_true(writer.committed())
    assert_equal(
        _out(writer),
        "HTTP/1.1 200 OK\r\n"
        + DATE
        + "Content-Type: text/plain\r\nContent-Length: 2\r\n\r\nhi",
    )
    var sent = _writer(GET)
    sent.send(Status.CREATED, "application/json", "{}")
    sent.finish()
    assert_true(_out(sent).startswith("HTTP/1.1 201 Created\r\n"))
    assert_true(_out(sent).endswith("Content-Length: 2\r\n\r\n{}"))


def test_heads() raises:
    var head = _writer("HEAD / HTTP/1.1\r\nHost: x\r\n\r\n")
    head.write_text("abc")
    head.finish()
    assert_equal(
        _out(head), "HTTP/1.1 200 OK\r\n" + DATE + "Content-Length: 3\r\n\r\n"
    )
    var empty = _writer(GET)
    empty.set_status(Status.NO_CONTENT)
    empty.finish()
    assert_equal(_out(empty), "HTTP/1.1 204 No Content\r\n" + DATE + "\r\n")
    var closing = _writer(GET)
    closing.close_connection()
    closing.finish()
    assert_true(
        _out(closing).endswith("Content-Length: 0\r\nConnection: close\r\n\r\n")
    )
    var old = _writer(OLD, True)
    old.finish()
    assert_true(
        _out(old).endswith(
            "Content-Length: 0\r\nConnection: keep-alive\r\n\r\n"
        )
    )
    var old_close = _writer(OLD, False)
    old_close.finish()
    assert_true(_out(old_close).endswith("Connection: close\r\n\r\n"))


def _header_error(name: StaticString) raises -> String:
    var writer = _writer(GET)
    try:
        writer.add_header(name, "1")
    except e:
        assert_true(e.kind == ErrorKind.USAGE)
        return e.message.copy()
    return "no error"


def test_header_rules() raises:
    assert_equal(
        _header_error("content-length"),
        "the server writes the content-length field",
    )
    assert_equal(
        _header_error("Transfer-Encoding"),
        "the server writes the Transfer-Encoding field",
    )
    assert_equal(
        _header_error("CONNECTION"), "the server writes the CONNECTION field"
    )
    assert_equal(_header_error("Date"), "the server writes the Date field")
    assert_equal(_header_error("Bad Name"), "invalid header name: Bad Name")
    assert_equal(_header_error("X-Ok"), "no error")


def test_chunked() raises:
    var writer = _writer(GET)
    writer.write_text("a")
    writer.begin_chunked()
    writer.write_chunk(StaticString("bc").as_bytes())
    writer.write_chunk(StaticString("").as_bytes())
    writer.write_chunk(StaticString("abcdefghijklmnopqrstuvwxyz").as_bytes())
    writer.finish()
    assert_equal(
        _out(writer),
        "HTTP/1.1 200 OK\r\n"
        + DATE
        + "Transfer-Encoding: chunked\r\n\r\n"
        + "1\r\na\r\n2\r\nbc\r\n1a\r\nabcdefghijklmnopqrstuvwxyz\r\n0\r\n\r\n",
    )
    var head = _writer("HEAD / HTTP/1.1\r\nHost: x\r\n\r\n")
    head.begin_chunked()
    head.write_chunk(StaticString("x").as_bytes())
    head.finish()
    assert_equal(
        _out(head),
        "HTTP/1.1 200 OK\r\n" + DATE + "Transfer-Encoding: chunked\r\n\r\n",
    )
    var old = _writer(OLD, True)
    old.write_text("a")
    old.begin_chunked()
    old.write_chunk(StaticString("b").as_bytes())
    old.finish()
    assert_false(old.keep_alive)
    assert_equal(
        _out(old), "HTTP/1.1 200 OK\r\n" + DATE + "Connection: close\r\n\r\nab"
    )


def _usage(mut writer: ResponseWriter, step: Int) raises -> String:
    try:
        if step == 0:
            writer.write_text("x")
        elif step == 1:
            writer.begin_chunked()
        elif step == 2:
            writer.write_chunk(StaticString("x").as_bytes())
        else:
            writer.add_header("X-A", "1")
    except e:
        assert_true(e.kind == ErrorKind.USAGE)
        return e.message.copy()
    return "no error"


def test_stream_errors() raises:
    var open = _writer(GET)
    assert_equal(_usage(open, 2), "call begin_chunked first")
    var streaming = _writer(GET)
    streaming.begin_chunked()
    assert_equal(_usage(streaming, 0), "use write_chunk to stream")
    assert_equal(_usage(streaming, 1), "the stream has begun")
    assert_equal(_usage(streaming, 3), "the response head has gone out")
    var empty = _writer(GET)
    empty.set_status(Status.NOT_MODIFIED)
    assert_equal(_usage(empty, 1), "a 304 Not Modified has no content")


def test_fail_and_error() raises:
    var writer = _writer(GET)
    writer.add_header("X-A", "1")
    writer.write_text("partial")
    writer.fail()
    writer.finish()
    assert_equal(
        _out(writer),
        "HTTP/1.1 500 Internal Server Error\r\n"
        + DATE
        + "Content-Length: 0\r\n\r\n",
    )
    var streaming = _writer(GET)
    streaming.begin_chunked()
    var before = len(streaming.out)
    streaming.fail()
    assert_false(streaming.keep_alive)
    streaming.finish()
    assert_equal(len(streaming.out), before)
    var bad = _writer("HEAD / HTTP/1.0\r\n\r\n")
    bad.write_text("x")
    bad.error(Status.BAD_REQUEST)
    assert_equal(
        _out(bad),
        "HTTP/1.1 400 Bad Request\r\n"
        + DATE
        + "Content-Length: 0\r\nConnection: close\r\n\r\n",
    )
    assert_true(_WriterState.DONE.is_valid())
    assert_false(_WriterState(4).is_valid())


def test_flush() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var reader = RequestReader(Limits())
    reader.append(StaticString(GET).as_bytes())
    _ = reader.next()
    var writer = ResponseWriter()
    writer.begin(reader.request, pair.server, True)
    writer.flush()
    writer.out.extend(StaticString("hello").as_bytes())
    writer.sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    writer.flush()
    assert_equal(len(writer.out), 5)
    writer.sys.faults = Faults(SysCall.SEND, EINTR, 0, 1)
    writer.flush()
    assert_equal(len(writer.out), 5)
    writer.sys.faults = Faults(SysCall.SEND, EPIPE, 0, 1)
    var failed = False
    try:
        writer.flush()
    except e:
        failed = e.kind == ErrorKind.OS and e.errno == EPIPE
    assert_true(failed)
    writer.flush()
    assert_equal(len(writer.out), 0)
    assert_equal(drain(sys, pair.client), 5)
    # More than the socket takes: a partial send keeps the rest, in order.
    var big = 16 * 1024 * 1024
    var data = List[UInt8](capacity=big)
    for index in range(big):
        data.append(UInt8(index % 251))
    writer.out.extend(Span(data))
    writer.flush()
    var rest = len(writer.out)
    assert_true(rest > 0 and rest < big)
    assert_equal(Int(writer.out[0]), (big - rest) % 251)
    # A writer without a connection keeps its output for its owner.
    var unbound = ResponseWriter()
    unbound.out.extend(StaticString("kept").as_bytes())
    unbound.flush()
    assert_equal(len(unbound.out), 4)
    pair.close(sys)


def test_router() raises:
    var router = Router()
    assert_true(router.find(Method.GET, "/").kind == MatchKind.NOT_FOUND)
    router.add(Method.GET, "/graphql", 1)
    router.add(Method.POST, "/graphql", 2)
    router.add(Method.PUT, "/static/*", 3)
    assert_equal(router.find(Method.GET, "/graphql").id, 1)
    assert_equal(router.find(Method.HEAD, "/graphql").id, 1)
    assert_equal(router.find(Method.POST, "/graphql").id, 2)
    assert_equal(router.find(Method.PUT, "/static/a.css").id, 3)
    var wrong = router.find(Method.DELETE, "/graphql")
    assert_true(wrong.kind == MatchKind.METHOD_NOT_ALLOWED)
    assert_equal(wrong.allow, "GET, POST")
    var missing = router.find(Method.GET, "/graphq")
    assert_true(missing.kind == MatchKind.NOT_FOUND)
    assert_equal(missing.id, -1)
    var writer = _writer(GET)
    router.reject(wrong, writer)
    writer.finish()
    assert_true(_out(writer).startswith("HTTP/1.1 405 Method Not Allowed\r\n"))
    assert_true(_out(writer).find("Allow: GET, POST\r\n") > 0)
    var other = _writer(GET)
    router.reject(missing, other)
    other.finish()
    assert_true(_out(other).startswith("HTTP/1.1 404 Not Found\r\n"))
    assert_equal(String(MatchKind.FOUND), "MatchKind(0)")
    assert_true(MatchKind.METHOD_NOT_ALLOWED.is_valid())
    assert_false(MatchKind(3).is_valid())


def _listener_error(
    call: SysCall, skip: Int, reuse_port: Bool = True
) raises -> String:
    var sys = Sys()
    sys.faults = Faults(call, 13, skip, 1)
    try:
        var listener = open_listener(
            sys, IPv4Address.LOOPBACK, 0, 16, reuse_port
        )
        sys.close(listener.fd)
    except e:
        assert_true(e.kind == ErrorKind.OS)
        return e.message.copy()
    return "no error"


def test_open_listener() raises:
    assert_equal(_listener_error(SysCall.SOCKET, 0), "socket failed: errno 13")
    assert_equal(
        _listener_error(SysCall.SETSOCKOPT, 0), "setsockopt failed: errno 13"
    )
    assert_equal(
        _listener_error(SysCall.SETSOCKOPT, 1), "setsockopt failed: errno 13"
    )
    assert_equal(_listener_error(SysCall.SETSOCKOPT, 1, False), "no error")
    assert_equal(_listener_error(SysCall.BIND, 0), "bind failed: errno 13")
    assert_equal(_listener_error(SysCall.LISTEN, 0), "listen failed: errno 13")
    assert_equal(
        _listener_error(SysCall.GETSOCKNAME, 0), "getsockname failed: errno 13"
    )


def _listen_error(call: SysCall) raises -> String:
    var sys = Sys()
    sys.faults = Faults(call, 24, 0, 1)
    try:
        var server = listen(Echo(0), config(), sys^)
        server.close()
    except e:
        return e.message.copy()
    return "no error"


def test_listen_errors() raises:
    assert_equal(
        _listen_error(SysCall.EPOLL_CREATE), "epoll_create1 failed: errno 24"
    )
    assert_equal(_listen_error(SysCall.EPOLL_CTL), "epoll_ctl failed: errno 24")
    var server = listen(Echo(0), config())
    assert_true(server.port > 0)
    server.close()
    server.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
