# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of a subgraph subscription over HTTP streaming.

Follows the errors of `subscribe` in Hive Router `1a29df9`
`bin/router/src/executor/executors/http.rs`: a status that is not 2xx, a
content type that does not stream, a bad multipart boundary, and a stream
that breaks. The subgraph is a socket in a child process that writes fixed
bytes, so that each response can be wrong in one way.
"""

from _e2e import Child, wait_for
from gql_http.server import open_listener
from gql_http.socket import EAGAIN, POLLIN, IPv4Address, Sys
from gql_router_stream.subgraph_http import HttpSubscription, StreamError
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _hex(value: Int) -> String:
    var digits = "0123456789abcdef"
    if value == 0:
        return "0"
    var out = String()
    var rest = value
    while rest > 0:
        out = digits[byte = rest % 16 : rest % 16 + 1] + out
        rest //= 16
    return out^


def _chunk(mut out: List[UInt8], data: Span[UInt8, _]):
    out.extend(_hex(len(data)).as_bytes())
    out.extend("\r\n".as_bytes())
    out.extend(data)
    out.extend("\r\n".as_bytes())


def _text_chunk(mut out: List[UInt8], text: StringSlice):
    _chunk(out, text.as_bytes())


comptime EVENT = 'event: next\ndata: {"data":{"a":1}}\n\n'
comptime COMPLETE = "event: complete\n\n"
comptime SSE_HEAD = (
    "HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\n"
    + "transfer-encoding: chunked\r\n\r\n"
)
comptime MP_HEAD = (
    'HTTP/1.1 200 OK\r\ncontent-type: multipart/mixed; boundary="-"\r\n'
    + "transfer-encoding: chunked\r\n\r\n"
)
comptime PART = '\r\n---\r\ncontent-type: application/json\r\n\r\n{"a":1}'


def _response(path: String) -> Tuple[List[UInt8], List[UInt8]]:
    """Return the bytes to send at once, and the bytes to send later."""
    var now = List[UInt8]()
    var later = List[UInt8]()
    if path == "/health":
        now.extend("HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n".as_bytes())
    elif path == "/s500":
        now.extend(
            "HTTP/1.1 500 Internal Server Error\r\ncontent-length: 0\r\n\r\n"
            .as_bytes()
        )
    elif path == "/s099":
        now.extend("HTTP/1.1 099 Low\r\ncontent-length: 0\r\n\r\n".as_bytes())
    elif path == "/plain":
        now.extend(
            "HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\n"
            "content-length: 2\r\n\r\n{}".as_bytes()
        )
    elif path == "/nohead":
        now.extend("HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n".as_bytes())
    elif path == "/boundary":
        now.extend(
            'HTTP/1.1 200 OK\r\ncontent-type: multipart/mixed; boundary="ab\r\n'
            "content-length: 0\r\n\r\n".as_bytes()
        )
    elif path == "/sse":
        now.extend(SSE_HEAD.as_bytes())
        _text_chunk(now, EVENT + COMPLETE)
        now.extend("0\r\n\r\n".as_bytes())
    elif path == "/sse_eof":
        now.extend(SSE_HEAD.as_bytes())
        _text_chunk(now, EVENT)
        now.extend("0\r\n\r\n".as_bytes())
    elif path == "/sse_slow":
        now.extend(SSE_HEAD.as_bytes())
        _text_chunk(later, EVENT)
        _text_chunk(later, COMPLETE)
        later.extend("0\r\n\r\n".as_bytes())
    elif path == "/sse_bad":
        now.extend(SSE_HEAD.as_bytes())
        var bad = List[UInt8]("event: next\ndata: ".as_bytes())
        bad.append(0xFF)
        bad.extend("\n\n".as_bytes())
        _chunk(now, Span(bad))
    elif path == "/mp":
        now.extend(MP_HEAD.as_bytes())
        _text_chunk(now, PART + "\r\n-----\r\n")
        now.extend("0\r\n\r\n".as_bytes())
    elif path == "/mp_bad":
        now.extend(MP_HEAD.as_bytes())
        var bad = List[UInt8](
            "\r\n---\r\ncontent-type: application/json\r\n\r\n".as_bytes()
        )
        bad.append(0xFF)
        bad.extend("\r\n-----\r\n".as_bytes())
        _chunk(now, Span(bad))
    elif path == "/chunk_bad":
        now.extend(SSE_HEAD.as_bytes())
        now.extend("zz\r\n".as_bytes())
    return (now^, later^)


def _send_all(mut sys: Sys, fd: Int, bytes: List[UInt8]):
    var sent = 0
    while sent < len(bytes):
        var n = sys.send(
            fd, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
        )
        if n == -EAGAIN:
            _ = sys.poll(fd, 4, 100)
            continue
        if n < 0:
            return
        sent += n


def _serve_one(mut sys: Sys, fd: Int):
    """Read one request and write the response of its path."""
    var request = List[UInt8]()
    var buffer = List[UInt8](length=4096, fill=0)
    var head_end = -1
    var length = 0
    for _ in range(400):
        if head_end >= 0 and len(request) >= head_end + length:
            break
        if sys.poll(fd, POLLIN, 10) <= 0:
            continue
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n <= 0:
            break
        request.extend(Span(buffer)[:n])
        var text = String(unsafe_from_utf8=Span(request))
        var end = text.find("\r\n\r\n")
        if end >= 0 and head_end < 0:
            head_end = end + 4
            var lower = text[byte=:end].lower()
            var at = lower.find("content-length:")
            if at >= 0:
                var rest = String(lower[byte = at + 15 :])
                var stop = rest.find("\r\n")
                if stop >= 0:
                    var head = String(rest[byte=:stop])
                    rest = head^
                try:
                    length = Int(String(rest.strip()))
                except:
                    length = 0
    var text = String(unsafe_from_utf8=Span(request))
    var first = text.find(" ")
    var second = text.find(" ", first + 1)
    var path = String(text[byte = first + 1 : second])
    if path == "/close":
        sys.close(fd)
        return
    var parts = _response(path)
    _send_all(sys, fd, parts[0])
    if len(parts[1]) > 0:
        _ = sys.poll(-1, 0, 150)
        _send_all(sys, fd, parts[1])
    sys.close(fd)


def _start() raises -> Child:
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        for _ in range(1000):
            if sys.poll(listener.fd, POLLIN, 5) <= 0:
                continue
            var fd = sys.accept(listener.fd)
            if fd >= 0:
                _serve_one(sys, fd)
        sys.exit_now(0)
    sys.close(listener.fd)
    wait_for(listener.port)
    return Child(pid, listener.port)


def _url(server: Child, path: String) -> String:
    return "http://127.0.0.1:" + String(server.port) + path


def _open_error(url: String) -> String:
    try:
        var subscription = HttpSubscription.open(
            url, List[UInt8]("{}".as_bytes()), 2000
        )
        subscription.close()
    except error:
        return error.code + "|" + error.message
    return "opened"


def _poll_error(url: String) -> String:
    var events = List[List[UInt8]]()
    try:
        var subscription = HttpSubscription.open(
            url, List[UInt8]("{}".as_bytes()), 2000
        )
        var sys = Sys()
        for _ in range(100):
            if subscription.poll(events):
                return "done"
            _ = sys.poll(-1, 0, 5)
    except error:
        return error.code + "|" + error.message
    return "pending"


def _events(url: String, mut polls_before: Int) raises -> List[String]:
    var events = List[List[UInt8]]()
    var subscription = HttpSubscription.open(
        url, List[UInt8]("{}".as_bytes()), 2000
    )
    var sys = Sys()
    polls_before = 0
    for _ in range(200):
        var done: Bool
        try:
            done = subscription.poll(events)
        except error:
            raise Error(String(error))
        if done:
            break
        polls_before += 1
        _ = sys.poll(-1, 0, 5)
    var again: Bool
    try:
        again = subscription.poll(events)
    except error:
        raise Error(String(error))
    assert_true(again)
    assert_equal(subscription.fd(), -1)
    var out = List[String]()
    for event in events:
        out.append(String(unsafe_from_utf8=Span(event)))
    return out^


def test_a_status_that_is_not_2xx_fails() raises:
    var server = _start()
    var high = _open_error(_url(server, "/s500"))
    # The client refuses a code below 100.
    var low = _open_error(_url(server, "/s099"))
    server.stop()
    assert_equal(
        high,
        (
            "SUBGRAPH_STREAM_STATUS_CODE_NOT_OK|Subgraph stream responded with"
            " a not-OK status code '500 Internal Server Error'"
        ),
    )
    assert_true(low.startswith("SUBGRAPH_RESPONSE_FAILURE|"), low)


def test_a_content_type_that_does_not_stream_fails() raises:
    var server = _start()
    var plain = _open_error(_url(server, "/plain"))
    var none = _open_error(_url(server, "/nohead"))
    var boundary = _open_error(_url(server, "/boundary"))
    server.stop()
    assert_equal(
        plain,
        (
            "SUBGRAPH_SUBSCRIPTION_UNSUPPORTED_CONTENT_TYPE|Unsupported"
            " content-type 'text/plain': expected 'multipart/mixed' or"
            " 'text/event-stream' for HTTP subscriptions"
        ),
    )
    assert_true("content-type ''" in none)
    assert_true(
        boundary.startswith(
            "SUBGRAPH_SUBSCRIPTION_MULTIPART_BOUNDARY_PARSE_FAILURE|"
        )
    )


def test_a_request_that_fails_is_an_error() raises:
    var server = _start()
    var closed = _open_error(_url(server, "/close"))
    server.stop()
    assert_true(closed.startswith("SUBGRAPH_RESPONSE_FAILURE|"), closed)
    var bad = _open_error("ftp://127.0.0.1/")
    assert_true(bad.startswith("SUBREQUEST_HTTP_ERROR|"), bad)


def test_sse_and_multipart_streams() raises:
    var server = _start()
    var polls = 0
    var sse = _events(_url(server, "/sse"), polls)
    var eof = _events(_url(server, "/sse_eof"), polls)
    var slow = _events(_url(server, "/sse_slow"), polls)
    var slow_polls = polls
    var multipart = _events(_url(server, "/mp"), polls)
    server.stop()
    assert_equal(len(sse), 1)
    assert_equal(sse[0], '{"data":{"a":1}}')
    assert_equal(len(eof), 1)
    assert_equal(len(slow), 1)
    assert_true(slow_polls > 0)
    assert_equal(len(multipart), 1)
    assert_equal(multipart[0], '{"a":1}')


def test_a_stream_that_breaks_is_an_error() raises:
    var server = _start()
    var sse = _poll_error(_url(server, "/sse_bad"))
    var multipart = _poll_error(_url(server, "/mp_bad"))
    var chunk = _poll_error(_url(server, "/chunk_bad"))
    server.stop()
    assert_true(
        sse.startswith(
            "SUBGRAPH_SUBSCRIPTION_SSE_STREAM_ERROR|Error reading SSE"
            " subscription stream: "
        ),
        sse,
    )
    assert_true(
        multipart.startswith("SUBGRAPH_SUBSCRIPTION_MULTIPART_STREAM_ERROR|"),
        multipart,
    )
    assert_true("Stream read error" in chunk, chunk)


def test_stream_error_text() raises:
    assert_equal(String(StreamError("CODE", "message")), "CODE: message")
    assert_false(StreamError("A", "b").code == "B")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
