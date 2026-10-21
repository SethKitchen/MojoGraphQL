# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_sse_execution`: graphql-sse on gql_execution, end to end
over a `gql_http` server. The cases follow graphql-sse 2.6.3
`tests/handler.test.ts` (distinct connections and validation) and add
`@defer` over SSE and over `multipart/mixed`."""

from _harness import (
    ROOT,
    SDL,
    TestRoot,
    encode,
    exchange,
    execution,
    request,
    sse_server,
)
from _harness import config
from gql_execution.value import UNDEFINED, Values
from gql_http.client import Client, Endpoint, ResponseStream
from gql_http.headers import Headers
from gql_http.multipart import (
    INCREMENTAL_ACCEPT,
    INCREMENTAL_CONTENT_TYPE,
    JSON_PART_TYPE,
    MultipartDecoder,
    boundary_of,
)
from gql_http.server import start_workers
from gql_http.status import Method, Status
from gql_sse.incremental_http import IncrementalHandler
from gql_language.parser import parse
from gql_execution.execute import ExecutionArgs
from gql_execution.incremental import experimental_execute_incrementally
from gql_schema.build import build_schema
from gql_sse_execution.executor import IncrementalStream, JsonRoot, NoRoot
from gql_stream.waker import Waker
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime DEFER = "{ hero { id ... @defer { name } } }"
comptime INITIAL = (
    '{"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],'
    '"hasNext":true}'
)
comptime SUBSEQUENT = (
    '{"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],'
    '"completed":[{"id":"0"}]}'
)


def _status(text: String) -> String:
    return String(text[byte=9:12])


def _body(text: String) -> String:
    var at = text.find("\r\n\r\n")
    return String(text[byte = at + 4 :])


def _stream(query: StringSlice, incremental: Bool = True) raises -> String:
    var server = sse_server(incremental)
    return exchange(
        server, request("GET", "/?query=" + encode(query), "text/event-stream")
    )


def test_defer_over_sse() raises:
    var text = _stream(DEFER)
    assert_equal(_status(text), "200")
    var first = text.find("event: next\ndata: " + INITIAL + "\n\n")
    var second = text.find("event: next\ndata: " + SUBSEQUENT + "\n\n")
    var end = text.find("event: complete\ndata:\n\n")
    assert_true(first > 0 and second > first and end > second, text)


def test_results() raises:
    # Without `@defer` the incremental executor gives one result.
    var text = _stream("{ a }")
    assert_true(
        text.find('event: next\ndata: {"data":{"a":"A"}}\n\n') > 0, text
    )
    text = _stream("{ a }", False)
    assert_true(
        text.find('event: next\ndata: {"data":{"a":"A"}}\n\n') > 0, text
    )
    # Variables reach the execution.
    var server = sse_server()
    text = exchange(
        server,
        request(
            "POST",
            "/",
            "text/event-stream",
            body=(
                '{"query":"query Q($b: Boolean!) { a @skip(if: $b) }",'
                '"variables":{"b":false}}'
            ),
        ),
    )
    assert_true(text.find('data: {"data":{"a":"A"}}') > 0, text)


def test_subscription() raises:
    var text = _stream("subscription { greetings }")
    var hi = text.find('event: next\ndata: {"data":{"greetings":"hi"}}')
    var hey = text.find('event: next\ndata: {"data":{"greetings":"hey"}}')
    assert_true(hi > 0 and hey > hi, text)
    assert_true(text.find("event: complete") > hey, text)
    # A subscription field without a stream raises, as `perform` throws.
    var server = sse_server(True, False)
    text = exchange(
        server,
        request(
            "GET",
            "/?query=" + encode("subscription { greetings }"),
            "text/event-stream",
        ),
    )
    assert_equal(_status(text), "500")


def test_refusals() raises:
    var server = sse_server()
    var text = exchange(
        server, request("GET", "/?query=" + encode("{"), "text/event-stream")
    )
    assert_equal(_status(text), "400")
    assert_true(
        _body(text).startswith('{"errors":[{"message":"Syntax Error'), text
    )
    text = exchange(
        server,
        request(
            "GET",
            "/?operationName=B&query=" + encode("query A { a }"),
            "text/event-stream",
        ),
    )
    assert_equal(_status(text), "400")
    assert_equal(
        _body(text), '{"errors":[{"message":"Unable to detect operation AST"}]}'
    )
    text = exchange(
        server,
        request(
            "GET", "/?query=" + encode("mutation { m }"), "text/event-stream"
        ),
    )
    assert_equal(_status(text), "405")
    assert_true(text.find("allow: POST") > 0, text)
    text = exchange(
        server,
        request(
            "POST", "/", "text/event-stream", body='{"query":"mutation { m }"}'
        ),
    )
    assert_true(text.find('data: {"data":{"m":"M"}}') > 0, text)


def test_validation() raises:
    # An event stream reports validation errors as a result.
    var text = _stream("{ nope }")
    assert_equal(_status(text), "200")
    assert_true(
        text.find('event: next\ndata: {"errors":[{"message":') > 0, text
    )
    # An operation request of the single connection mode gets a 400.
    var server = sse_server()
    _ = exchange(server, request("PUT", "/", token="t"))
    text = exchange(
        server,
        request(
            "POST",
            "/",
            token="t",
            body='{"query":"{ nope }","extensions":{"operationId":"1"}}',
        ),
    )
    assert_equal(_status(text), "400")
    assert_true(_body(text).startswith('{"errors":[{"message":'), text)
    # Without `incremental`, `@defer` does not defer.
    text = _stream(DEFER, False)
    assert_true(
        text.find('data: {"data":{"hero":{"id":"1","name":"Luke"}}}') > 0, text
    )


def _post(
    mut client: Client,
    endpoint: Endpoint,
    query: StringSlice,
    accept: StringSlice,
) raises -> ResponseStream:
    var headers = Headers()
    headers.add("content-type", "application/json")
    if accept.byte_length() > 0:
        headers.add("accept", accept)
    var body = String('{"query":"') + String(query) + '"}'
    return client.stream(
        client.start(endpoint, Method.POST, "/", headers, body.as_bytes())
    )


def _content(mut client: Client, mut stream: ResponseStream) raises -> String:
    var all = List[UInt8]()
    var out = List[UInt8]()
    while client.read_body(stream, out):
        all.extend(Span(out))
        out.clear()
    return String(unsafe_from_utf8=all)


def test_defer_over_multipart() raises:
    var pool = start_workers(IncrementalHandler(execution()), config())
    var client = Client()
    var endpoint = client.endpoint(
        "http://127.0.0.1:" + String(pool.port) + "/"
    )
    var stream = _post(client, endpoint, DEFER, INCREMENTAL_ACCEPT)
    assert_equal(stream.response.status, Status.OK)
    var content_type = String(stream.response.header("content-type").value())
    assert_equal(content_type, INCREMENTAL_CONTENT_TYPE)
    var decoder = MultipartDecoder(boundary_of(content_type))
    var out = List[UInt8]()
    while client.read_body(stream, out):
        _ = decoder.feed(out)
        out.clear()
    decoder.finish()
    var parts = decoder.take()
    assert_equal(len(parts), 2)
    assert_equal(parts[0].content_type, JSON_PART_TYPE)
    assert_equal(parts[0].text(), INITIAL)
    assert_equal(parts[1].text(), SUBSEQUENT)
    # One result is plain JSON.
    var plain = _post(client, endpoint, "{ a }", INCREMENTAL_ACCEPT)
    assert_equal(
        String(plain.response.header("content-type").value()),
        "application/json; charset=utf-8",
    )
    assert_equal(_content(client, plain), '{"data":{"a":"A"}}')
    # A stream needs an accept of multipart/mixed.
    var refused = _post(client, endpoint, DEFER, "application/json")
    assert_equal(refused.response.status, Status.NOT_ACCEPTABLE)
    _ = _content(client, refused)
    var bad = _post(client, endpoint, "{", "")
    assert_equal(bad.response.status, Status.BAD_REQUEST)
    _ = _content(client, bad)
    var get = client.stream(
        client.start(
            endpoint,
            Method.GET,
            "/?query=" + encode("mutation { m }"),
            Headers(),
            List[UInt8](),
        )
    )
    assert_equal(get.response.status, Status.METHOD_NOT_ALLOWED)
    assert_equal(String(get.response.header("allow").value()), "POST")
    _ = _content(client, get)
    var form = client.stream(
        client.start(endpoint, Method.PUT, "/", Headers(), List[UInt8]())
    )
    assert_equal(form.response.status, Status.UNSUPPORTED_MEDIA_TYPE)
    _ = _content(client, form)
    _ = pool.stop()


def test_subscription_errors() raises:
    # A variable that is missing gives one result with errors. The
    # variable is in `@defer`, because validation reads `@include` and
    # `@skip` of a subscription with no variable values, and raises.
    var server = sse_server(False)
    var text = exchange(
        server,
        request(
            "POST",
            "/",
            "text/event-stream",
            body=(
                '{"query":"subscription S($x: Boolean!) { ... @defer(if:'
                ' $x) { greetings } }","variables":{}}'
            ),
        ),
    )
    assert_true(text.find('event: next\ndata: {"errors":[') > 0, text)
    assert_true(text.find("event: complete") > 0, text)


def test_incremental_stream_close() raises:
    var document = parse(DEFER)
    var args = ExecutionArgs()
    var root = JsonRoot(ROOT)
    args.root_value = root.root(args.values, document, 0)
    var results = experimental_execute_incrementally(
        build_schema(SDL), document, args^
    )
    var stream = IncrementalStream(
        results.to_json(), results.take_subsequent_results()
    )
    stream.close()
    var waker = Waker.noop()
    assert_false(stream.poll_next(waker).is_ready())


def test_roots() raises:
    var values = Values()
    var document = parse("{ a }")
    var none = NoRoot()
    assert_equal(none.root(values, document, 0), UNDEFINED)
    var json = JsonRoot(ROOT)
    assert_true(json.root(values, document, 0) != UNDEFINED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
