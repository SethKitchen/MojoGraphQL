# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the answer to one HTTP request of a router that streams.

Follows `handle_pipeline_error` and the request tests of Hive Router
`1a29df9` `bin/router/src/pipeline/mod.rs` and `pipeline/header.rs`: an
`Accept` that the router cannot serve is 415, a stream-only client gets
its errors in the stream format, and a query that the client wants only as
a stream is 415. The subgraphs answer in the same process.
"""

from std.memory import ArcPointer

from _supergraph import sdl
from gql_http.status import Method
from gql_router.exec_http import CannedTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router_stream.config import SubscriptionsConfig
from gql_router_stream.http import StreamAnswer, answer_request
from gql_router_stream.subscription import StreamHub
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _hub() raises -> ArcPointer[StreamHub[CannedTransport]]:
    var transport = CannedTransport()
    transport.add(
        "products", "{topProducts{upc}}", '{"data":{"topProducts":[]}}'
    )
    return ArcPointer(
        StreamHub(
            Router(RouterSchema(sdl("http://x")), transport^),
            SubscriptionsConfig(),
        )
    )


def _answer(
    method: Method, accept: String, body: String, query_string: String = ""
) raises -> StreamAnswer[CannedTransport]:
    return answer_request(
        _hub(),
        method,
        query_string,
        String("application/json"),
        accept,
        List[UInt8](body.as_bytes()),
    )


def _body(answer: StreamAnswer[CannedTransport]) -> String:
    return String(unsafe_from_utf8=Span(answer.body))


def test_an_accept_that_the_router_cannot_serve_is_415() raises:
    var answer = _answer(Method.POST, "text/html", '{"query":"{ a }"}')
    assert_equal(answer.status, 415)
    assert_false(answer.is_stream)
    assert_true("application/json" in answer.content_type)


def test_a_method_that_is_not_get_or_post_is_405() raises:
    var answer = _answer(Method.PUT, "application/json", "")
    assert_equal(answer.status, 405)
    assert_true("METHOD_NOT_ALLOWED" in _body(answer))


def test_a_request_without_a_query_is_an_error() raises:
    var answer = _answer(Method.POST, "application/json", "{}")
    assert_true("MISSING_QUERY_PARAM" in _body(answer))
    var get = _answer(
        Method.GET, "application/json", "", "query=%7BtopProducts%7Bupc%7D%7D"
    )
    assert_equal(get.status, 200)
    assert_equal(_body(get), '{"data":{"topProducts":[]}}')


def test_a_query_for_a_stream_only_client_is_415_in_the_stream() raises:
    var answer = _answer(
        Method.POST, "text/event-stream", '{"query":"{ topProducts { upc } }"}'
    )
    assert_false(answer.is_stream)
    assert_equal(answer.status, 200)
    assert_equal(answer.content_type, "text/event-stream")
    var body = _body(answer)
    assert_true(body.startswith("event: next\ndata: "))
    assert_true("UNSUPPORTED_CONTENT_TYPE" in body)
    assert_true(body.endswith("event: complete\n\n"))


def test_defer_to_an_apollo_multipart_client_is_incremental() raises:
    var answer = _answer(
        Method.POST,
        'multipart/mixed;subscriptionSpec="1.0"',
        '{"query":"{ topProducts { upc ... @defer { name } } }"}',
    )
    assert_true(answer.is_stream)
    assert_true(Bool(answer.deferred))
    assert_equal(answer.content_type, 'multipart/mixed;boundary="-"')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
