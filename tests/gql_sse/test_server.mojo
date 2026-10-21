# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_sse.server` and `gql_sse.handler` on a `gql_http` server.
Ported from graphql-sse 2.6.3 `tests/handler.test.ts`; an executor of
synthetic payloads stands for graphql-js."""

from _harness import Fake, connect, exchange, receive, send_text, sse_server
from gql_http.body import BodyPoll
from gql_http.socket import Sys
from gql_sse.handler import PreparedKind, error_json
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _request(
    method: StringSlice,
    target: StringSlice,
    accept: StringSlice = "",
    token: StringSlice = "",
    body: StringSlice = "",
    content_type: StringSlice = "application/json",
) -> String:
    var text = (
        String(method) + " " + String(target) + " HTTP/1.1\r\nHost: x\r\n"
    )
    if accept.byte_length() > 0:
        text += "Accept: " + String(accept) + "\r\n"
    if token.byte_length() > 0:
        text += "x-graphql-event-stream-token: " + String(token) + "\r\n"
    if body.byte_length() > 0:
        text += "Content-Type: " + String(content_type) + "\r\n"
    text += "Content-Length: " + String(body.byte_length()) + "\r\n\r\n"
    return text + String(body)


def _status(text: String) -> String:
    return String(text[byte=9:12])


def _body(text: String) -> String:
    var at = text.find("\r\n\r\n")
    return String(text[byte = at + 4 :])


def test_valid_accept_headers() raises:
    var server = sse_server()
    var token = _body(exchange(server, _request("PUT", "/")))
    var text = exchange(server, _request("GET", "/", "gibberish", token))
    assert_equal(_status(text), "406")
    text = exchange(server, _request("GET", "/", "application/json", token))
    assert_equal(_status(text), "400")
    assert_true(
        text.find("content-type: application/json; charset=utf-8") > 0, text
    )
    assert_equal(_body(text), '{"errors":[{"message":"Missing query"}]}')
    text = exchange(server, _request("PUT", "/", "application/json"))
    assert_equal(_status(text), "406")
    text = exchange(server, _request("PUT", "/", "text/plain"))
    assert_equal(_status(text), "201")


def test_unregistered_token() raises:
    var server = sse_server()
    var text = exchange(server, _request("POST", "/", token="0"))
    assert_equal(_status(text), "404")
    assert_equal(_body(text), '{"errors":[{"message":"Stream not found"}]}')
    text = exchange(server, _request("GET", "/?token=0"))
    assert_equal(_status(text), "404")
    text = exchange(server, _request("DELETE", "/?token=0"))
    assert_equal(_status(text), "404")
    assert_equal(_body(text), '{"errors":[{"message":"Stream not found"}]}')


def test_put_token() raises:
    var server = sse_server()
    var text = exchange(server, _request("PUT", "/", token="token"))
    assert_equal(_status(text), "201")
    assert_true(text.find("content-type: text/plain; charset=utf-8") > 0, text)
    assert_equal(_body(text), "token")
    text = exchange(server, _request("PUT", "/?token=token"))
    assert_equal(_status(text), "409")
    assert_equal(
        _body(text), '{"errors":[{"message":"Stream already registered"}]}'
    )
    # A generated token is a version 4 UUID.
    var made = _body(exchange(server, _request("PUT", "/")))
    assert_equal(made.byte_length(), 36)
    assert_equal(String(made[byte=14:15]), "4")
    assert_equal(server.handler.streams(), 2)


def test_event_stream_without_reservation() raises:
    var server = sse_server()
    var text = exchange(server, _request("GET", "/", "text/event-stream", "0"))
    assert_equal(_status(text), "400")
    assert_equal(_body(text), '{"errors":[{"message":"Missing query"}]}')


def test_event_stream_on_reservation() raises:
    var server = sse_server()
    _ = exchange(server, _request("PUT", "/", token="t"))
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, _request("GET", "/", "text/event-stream", "t"))
    var text = receive(server, sys, fd)
    assert_equal(_status(text), "200")
    assert_true(
        text.find("content-type: text/event-stream; charset=utf-8") > 0, text
    )
    assert_true(text.find("cache-control: no-cache") > 0, text)
    assert_true(text.find("content-encoding: none") > 0, text)
    assert_true(text.endswith("\r\n\r\n3\r\n:\n\n\r\n"), text)
    # One open stream for each token.
    var again = exchange(server, _request("GET", "/", "text/event-stream", "t"))
    assert_equal(_status(again), "409")
    assert_equal(_body(again), '{"errors":[{"message":"Stream already open"}]}')
    sys.close(fd)
    _ = receive(server, sys, fd, 5)
    # The stream goes when its client goes, as upstream `dispose`.
    assert_equal(server.handler.streams(), 0)


def test_operation_id() raises:
    var server = sse_server()
    _ = exchange(server, _request("PUT", "/", token="t"))
    var text = exchange(
        server, _request("POST", "/", token="t", body='{"query":"{ a }"}')
    )
    assert_equal(_status(text), "400")
    assert_equal(
        _body(text), '{"errors":[{"message":"Operation ID is missing"}]}'
    )
    text = exchange(
        server,
        _request(
            "POST",
            "/",
            token="t",
            body='{"query":"{ a }","extensions":{"operationId":true}}',
        ),
    )
    assert_equal(_status(text), "400")
    text = exchange(server, _request("DELETE", "/?token=t"))
    assert_equal(_status(text), "400")
    assert_equal(
        _body(text), '{"errors":[{"message":"Operation ID is missing"}]}'
    )
    text = exchange(server, _request("DELETE", "/?token=t&operationId=none"))
    assert_equal(_status(text), "200")


def _op(id: StringSlice, query: StringSlice) -> String:
    return (
        '{"query":"'
        + String(query)
        + '","extensions":{"operationId":"'
        + String(id)
        + '"}}'
    )


def test_single_connection_operations() raises:
    var server = sse_server()
    _ = exchange(server, _request("PUT", "/", token="t"))
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, _request("GET", "/", "text/event-stream", "t"))
    _ = receive(server, sys, fd, 5)
    var text = exchange(
        server, _request("POST", "/", token="t", body=_op("1", "{ a }"))
    )
    assert_equal(_status(text), "202")
    text = receive(server, sys, fd)
    assert_true(
        text.find(
            'event: next\ndata: {"id":"1","payload":{"data":{"q":"{ a }"}}}\n\n'
        )
        > 0,
        text,
    )
    assert_true(text.find('event: complete\ndata: {"id":"1"}\n\n') > 0, text)
    # A subscription streams each result; the stream stays open.
    _ = exchange(
        server, _request("POST", "/", token="t", body=_op("2", "count:2"))
    )
    text = receive(server, sys, fd)
    assert_true(
        text.find('data: {"id":"2","payload":{"data":{"n":1}}}') > 0, text
    )
    assert_true(text.find('data: {"id":"2"}') > 0, text)
    assert_equal(server.handler.operations("t"), 0)
    # An operation id can be used once at a time, and DELETE stops it.
    _ = exchange(
        server, _request("POST", "/", token="t", body=_op("3", "forever"))
    )
    text = exchange(
        server, _request("POST", "/", token="t", body=_op("3", "forever"))
    )
    assert_equal(_status(text), "409")
    assert_equal(
        _body(text),
        '{"errors":[{"message":"Operation with ID already exists"}]}',
    )
    assert_equal(server.handler.operations("t"), 1)
    text = exchange(server, _request("DELETE", "/?token=t&operationId=3"))
    assert_equal(_status(text), "200")
    assert_equal(server.handler.operations("t"), 0)
    # Operations wait for the stream when it is not open.
    sys.close(fd)
    _ = receive(server, sys, fd, 5)
    assert_equal(server.handler.operations("t"), -1)


def test_reserved_stream_queues() raises:
    var server = sse_server()
    _ = exchange(server, _request("PUT", "/", token="q"))
    _ = exchange(
        server, _request("POST", "/", token="q", body=_op("a", "{ x }"))
    )
    # Two operations: a stream and a result that is not a stream.
    _ = exchange(
        server, _request("POST", "/", token="q", body=_op("b", "forever"))
    )
    assert_equal(server.handler.operations("q"), 2)
    var text = exchange(
        server, _request("POST", "/", token="q", body=_op("c", "syntax"))
    )
    assert_equal(_status(text), "400")
    assert_equal(_body(text), error_json("Syntax Error"))
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, _request("GET", "/?token=q", "text/event-stream"))
    text = receive(server, sys, fd)
    assert_true(text.find('"id":"a","payload"') > 0, text)
    sys.close(fd)
    _ = receive(server, sys, fd, 5)


def test_distinct_connections() raises:
    var server = sse_server()
    var text = exchange(
        server, _request("GET", "/?query=%7B%20a%20%7D", "text/event-stream")
    )
    assert_equal(_status(text), "200")
    assert_true(
        text.find('event: next\ndata: {"data":{"q":"{ a }"}}\n\n') > 0, text
    )
    assert_true(text.find("event: complete\ndata:\n\n") > 0, text)
    assert_true(text.endswith("0\r\n\r\n"), text)
    text = exchange(
        server,
        _request("POST", "/", "text/event-stream", body='{"query":"count:3"}'),
    )
    assert_true(text.find('data: {"data":{"n":2}}') > 0, text)
    assert_true(text.endswith("event: complete\ndata:\n\n\r\n0\r\n\r\n"), text)
    # Validation issues stream as a result.
    text = exchange(
        server,
        _request("POST", "/", "text/event-stream", body='{"query":"invalid"}'),
    )
    assert_true(text.find('data: {"errors":[{"message":"invalid"}]}') > 0, text)
    text = exchange(
        server, _request("GET", "/?query=mutation", "text/event-stream")
    )
    assert_equal(_status(text), "405")
    assert_true(text.find("allow: POST") > 0, text)
    assert_equal(server.handler.streams(), 0)


def test_distinct_client_goes_away() raises:
    var server = sse_server()
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, _request("GET", "/?query=forever", "text/event-stream"))
    _ = receive(server, sys, fd, 5)
    assert_equal(server.handler.streams(), 1)
    sys.close(fd)
    _ = receive(server, sys, fd, 5)
    assert_equal(server.handler.streams(), 0)


def test_failures() raises:
    var server = sse_server()
    # A stream that fails ends the connection without `complete`.
    var text = exchange(
        server, _request("GET", "/?query=fail", "text/event-stream")
    )
    assert_true(text.find('data: {"data":{}}') > 0, text)
    assert_false(text.find("complete") > 0, text)
    assert_equal(server.handler.streams(), 0)
    text = exchange(
        server, _request("GET", "/?query=raise", "text/event-stream")
    )
    assert_equal(_status(text), "500")
    text = exchange(server, _request("PATCH", "/", token="x"))
    assert_equal(_status(text), "405")
    assert_true(text.find("allow: GET, POST, PUT, DELETE") > 0, text)
    _ = exchange(server, _request("PUT", "/", token="p"))
    text = exchange(server, _request("POST", "/", "text/html", "p"))
    assert_equal(_status(text), "406")


def test_pings() raises:
    var server = sse_server()
    server.handler.ping_ms = 0
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, _request("GET", "/?query=forever", "text/event-stream"))
    # Pings come on every turn, so the client is never quiet: read a few.
    var buffer = List[UInt8](length=4096, fill=0)
    var turn = 0
    while turn < 10:
        _ = server.poll(2)
        turn += 1
    var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
    var text = String(unsafe_from_utf8=Span(buffer)[: max(n, 0)])
    assert_true(text.find("\r\n3\r\n:\n\n\r\n3\r\n:\n\n\r\n") > 0, text)
    sys.close(fd)
    server.handler.ping_ms = 12000
    _ = receive(server, sys, fd, 5)
    assert_equal(server.handler.streams(), 0)


def _params(request: String) raises -> String:
    var server = sse_server()
    _ = exchange(server, _request("PUT", "/", token="p"))
    var text = exchange(server, request)
    return _status(text) + " " + _body(text)


def test_parse_request() raises:
    assert_equal(
        _params(
            _request(
                "POST", "/", token="p", body="x", content_type="text/plain"
            )
        ),
        "415 ",
    )
    assert_equal(
        _params(_request("POST", "/", token="p")),
        "415 ",
    )
    assert_equal(
        _params(_request("POST", "/", token="p", body="[1]")),
        '400 {"errors":[{"message":"JSON body must be an object"}]}',
    )
    assert_equal(
        _params(_request("POST", "/", token="p", body='{"query":1}')),
        '400 {"errors":[{"message":"Invalid query"}]}',
    )
    assert_equal(
        _params(_request("POST", "/", token="p", body='{"query":null}')),
        '400 {"errors":[{"message":"Missing query"}]}',
    )
    assert_equal(
        _params(
            _request(
                "POST", "/", token="p", body='{"query":"a","variables":[]}'
            )
        ),
        '400 {"errors":[{"message":"Invalid variables"}]}',
    )
    assert_equal(
        _params(
            _request(
                "POST", "/", token="p", body='{"query":"a","extensions":1}'
            )
        ),
        '400 {"errors":[{"message":"Invalid extensions"}]}',
    )
    assert_true(
        _params(_request("POST", "/", token="p", body="{")).startswith("400 ")
    )
    assert_equal(
        _params(_request("GET", "/?token=p&query=a&variables=%7B")),
        '400 {"errors":[{"message":"Unparsable URL"}]}',
    )
    assert_equal(
        _params(_request("GET", "/?query=a&variables=%ZZ", token="p")),
        '400 {"errors":[{"message":"Unparsable URL"}]}',
    )
    # Numbers are operation ids too; null parameters count as none.
    assert_equal(
        _params(
            _request(
                "GET",
                "/?token=p&query=a&operationName=A&variables=%7B%7D&extensions=%7B%22operationId%22%3A7%7D",
            )
        ),
        "202 ",
    )
    assert_equal(
        _params(
            _request(
                "POST",
                "/",
                token="p",
                body=(
                    '{"query":"a","operationName":null,"variables":null,'
                    '"extensions":{"operationId":"x"}}'
                ),
            )
        ),
        "202 ",
    )


def test_edges() raises:
    var server = sse_server()
    _ = exchange(server, _request("PUT", "/", token="e"))
    # Extensions without an operation id; a JSON POST without a body.
    var text = exchange(
        server,
        _request("POST", "/", token="e", body='{"query":"a","extensions":{}}'),
    )
    assert_equal(
        _body(text), '{"errors":[{"message":"Operation ID is missing"}]}'
    )
    text = exchange(
        server,
        (
            "POST / HTTP/1.1\r\nHost: x\r\nx-graphql-event-stream-token:"
            " e\r\nContent-Type: application/json\r\nContent-Length: 0\r\n\r\n"
        ),
    )
    assert_equal(_body(text), '{"errors":[{"message":"Missing body"}]}')
    # An empty JSON parameter counts as none; `application/*` is accepted.
    text = exchange(
        server,
        _request(
            "GET",
            "/?token=e&query=a&variables=&extensions=%7B%22operationId%22%3A1%7D",
            "application/*",
        ),
    )
    assert_equal(_status(text), "202")
    # Empty tokens and a query string that does not decode give a new
    # token, which has no stream.
    text = exchange(
        server,
        (
            "POST /?token= HTTP/1.1\r\nHost: x\r\nx-graphql-event-stream-token:"
            " \r\nContent-Length: 0\r\n\r\n"
        ),
    )
    assert_equal(_status(text), "404")
    text = exchange(server, _request("POST", "/?%ZZ"))
    assert_equal(_status(text), "404")
    text = exchange(server, _request("DELETE", "/?operationId=%ZZ", token="e"))
    assert_equal(_status(text), "400")
    # DELETE of a result that waits for the stream.
    _ = exchange(
        server, _request("POST", "/", token="e", body=_op("r", "{ a }"))
    )
    assert_equal(server.handler.operations("e"), 2)
    text = exchange(server, _request("DELETE", "/?operationId=r", token="e"))
    assert_equal(_status(text), "200")
    assert_equal(server.handler.operations("e"), 1)
    # A stream that fails before any result ends the connection.
    text = exchange(
        server, _request("GET", "/?query=fail0", "text/event-stream")
    )
    assert_false(text.find("event:") > 0, text)
    # Calls for connections without a stream.
    var out = List[UInt8]()
    assert_equal(server.handler.poll_body(9999, out), BodyPoll.DONE)
    assert_equal(server.handler.poll_body(0, out), BodyPoll.DONE)
    server.handler.body_closed(9999)
    server.handler.body_closed(0)


def test_budget() raises:
    # More than one turn of messages: the rest waits for the next poll,
    # and a client that leaves drops what is not sent.
    var server = sse_server()
    _ = exchange(server, _request("PUT", "/", token="b"))
    _ = exchange(
        server, _request("POST", "/", token="b", body=_op("1", "count:40000"))
    )
    _ = exchange(
        server, _request("POST", "/", token="b", body=_op("2", "{ a }"))
    )
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, _request("GET", "/", "text/event-stream", "b"))
    var turn = 0
    while turn < 20:
        _ = server.poll(2)
        turn += 1
    assert_equal(server.handler.operations("b"), 2)
    sys.close(fd)
    turn = 0
    while server.handler.streams() > 0 and turn < 200:
        _ = server.poll(2)
        turn += 1
    assert_equal(server.handler.streams(), 0)


def test_prepared_kind() raises:
    assert_true(PreparedKind.STREAM.is_valid())
    assert_false(PreparedKind(3).is_valid())
    assert_equal(String(PreparedKind.RESULT), "PreparedKind(1)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
