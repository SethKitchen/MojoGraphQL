# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_sse.bridge` and `gql_sse.incremental_http`, with an executor
of synthetic payloads. No upstream suite."""

from _harness import Fake, Forever, connect, exchange, receive, send_text
from gql_http.body import BodyPoll
from gql_http.server import ServerConfig, listen
from gql_http.socket import IPv4Address, Sys
from gql_sse.bridge import HeldBodies, MultipartBody, SseBody
from gql_sse.incremental_http import IncrementalHandler
from gql_stream.stream import AnyStream, ListStream
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_bodies() raises:
    # A held body that the client leaves goes; a missing one is DONE.
    var bodies = HeldBodies[SseBody]()
    bodies.add(3, SseBody(AnyStream(ListStream.of_json(['{"a":1}']))))
    assert_equal(bodies.count(), 1)
    var out = List[UInt8]()
    assert_equal(bodies.poll(3, out), BodyPoll.READY)
    assert_equal(bodies.poll(3, out), BodyPoll.DONE)
    assert_equal(
        String(unsafe_from_utf8=out),
        'event: next\ndata: {"a":1}\n\nevent: complete\ndata:\n\n',
    )
    assert_equal(bodies.count(), 0)
    assert_equal(bodies.poll(3, out), BodyPoll.DONE)
    assert_equal(bodies.poll(99, out), BodyPoll.DONE)
    bodies.add(1, SseBody(AnyStream(ListStream.of_json([], "failed"))))
    assert_equal(bodies.poll(1, out), BodyPoll.ERROR)
    bodies.add(1, SseBody(AnyStream(ListStream.of_json([]))))
    bodies.drop(1)
    bodies.drop(50)
    assert_equal(bodies.count(), 0)
    var multi = MultipartBody(AnyStream(ListStream.of_json([], "failed")))
    assert_equal(multi.poll_body(out), BodyPoll.ERROR)
    var done = MultipartBody(AnyStream(ListStream.of_json([])))
    assert_equal(done.poll_body(out), BodyPoll.DONE)
    assert_equal(done.poll_body(out), BodyPoll.DONE)
    var quiet = SseBody(AnyStream(Forever()))
    assert_equal(quiet.poll_body(out), BodyPoll.PENDING)
    var sse = SseBody(AnyStream(ListStream.of_json([])))
    assert_equal(sse.poll_body(out), BodyPoll.DONE)
    assert_equal(sse.poll_body(out), BodyPoll.DONE)


def _request(
    method: StringSlice,
    target: StringSlice,
    body: StringSlice = "",
    accept: StringSlice = "multipart/mixed;deferSpec=20220824",
) -> String:
    var text = (
        String(method) + " " + String(target) + " HTTP/1.1\r\nHost: x\r\n"
    )
    if accept.byte_length() > 0:
        text += "Accept: " + String(accept) + "\r\n"
    if body.byte_length() > 0:
        text += "Content-Type: application/json\r\n"
    text += "Content-Length: " + String(body.byte_length()) + "\r\n\r\n"
    return text + String(body)


def test_incremental_http() raises:
    var c = ServerConfig()
    c.host = IPv4Address.LOOPBACK
    c.port = 0
    c.stream_poll_ms = 1
    var server = listen(IncrementalHandler(Fake()), c)
    var text = exchange(server, _request("POST", "/", '{"query":"count:2"}'))
    assert_true(
        text.find(
            'content-type: multipart/mixed; boundary="-"; deferSpec=20220824'
        )
        > 0,
        text,
    )
    assert_true(
        text.find(
            "\r\n---\r\ncontent-type: application/json;"
            ' charset=utf-8\r\n\r\n{"data":{"n":1}}'
        )
        > 0,
        text,
    )
    assert_true(text.find("\r\n-----\r\n") > 0, text)
    assert_true(text.endswith("0\r\n\r\n"), text)
    text = exchange(server, _request("POST", "/", '{"query":"{ a }"}'))
    assert_true(text.endswith('\r\n\r\n{"data":{"q":"{ a }"}}'), text)
    text = exchange(server, _request("POST", "/", '{"query":"count:1"}', ""))
    assert_true(text.startswith("HTTP/1.1 406"), text)
    text = exchange(
        server,
        _request("POST", "/", '{"query":"count:1"}', "application/json"),
    )
    assert_true(text.startswith("HTTP/1.1 406"), text)
    text = exchange(server, _request("GET", "/?query=mutation"))
    assert_true(text.startswith("HTTP/1.1 405"), text)
    assert_true(text.find("allow: POST") > 0, text)
    text = exchange(server, _request("POST", "/", '{"query":"syntax"}'))
    assert_true(text.startswith("HTTP/1.1 400"), text)
    text = exchange(server, _request("PUT", "/"))
    assert_true(text.startswith("HTTP/1.1 415"), text)
    assert_equal(server.handler.bodies.count(), 0)
    # A client that goes away drops its body.
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, _request("POST", "/", '{"query":"forever"}'))
    _ = receive(server, sys, fd, 5)
    assert_equal(server.handler.bodies.count(), 1)
    sys.close(fd)
    _ = receive(server, sys, fd, 5)
    assert_equal(server.handler.bodies.count(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
