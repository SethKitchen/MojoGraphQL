# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the subgraph requests and transports, `gql_router.exec_http`.

The cases follow `build_request_body`, `is_valid_graphql_content_type` and
the error kinds of `HTTPSubgraphExecutor` in Hive Router `1a29df9`
`bin/router/src/executor/executors/http.rs`.
"""

from gql_http.error import ErrorKind, HttpError
from gql_json.parser import parse
from gql_router.exec_http import (
    CannedTransport,
    HttpTransport,
    SubgraphFailure,
    build_request_body,
    failure_of,
    is_valid_graphql_content_type,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _text(var bytes: List[UInt8]) -> String:
    return String(unsafe_from_utf8=bytes)


def test_the_body_has_the_variables_it_uses() raises:
    var variables = parse('{"a":1,"b":"x"}')
    var a = variables.find(variables.root, "a")
    var b = variables.find(variables.root, "b")
    var names: List[String] = ["a", "b"]
    var nodes: List[Int] = [a, b]
    var raw_names: List[String] = ["representations"]
    var raw_values = List[List[UInt8]]()
    raw_values.append(List[UInt8]("[{}]".as_bytes()))
    assert_equal(
        _text(
            build_request_body(
                'query { "q" }', names, variables, nodes, raw_names, raw_values
            )
        ),
        '{"query":"query { \\"q\\" }","variables":{"a":1,"b":"x",'
        + '"representations":[{}]}}',
    )
    assert_equal(
        _text(
            build_request_body(
                "{ a }",
                List[String](),
                variables,
                List[Int](),
                raw_names,
                raw_values,
            )
        ),
        '{"query":"{ a }","variables":{"representations":[{}]}}',
    )
    assert_equal(
        _text(
            build_request_body(
                "{ a }",
                List[String](),
                variables,
                List[Int](),
                List[String](),
                List[List[UInt8]](),
            )
        ),
        '{"query":"{ a }"}',
    )


def test_graphql_content_types() raises:
    assert_true(is_valid_graphql_content_type("application/json"))
    assert_true(
        is_valid_graphql_content_type(" Application/JSON ; charset=utf-8")
    )
    assert_true(
        is_valid_graphql_content_type("application/graphql-response+json")
    )
    assert_false(is_valid_graphql_content_type("text/html"))


def test_transport_errors_map_to_failures() raises:
    assert_true(
        failure_of(HttpError(ErrorKind.TIMEOUT, "t", 0))
        == SubgraphFailure.REQUEST_TIMEOUT
    )
    assert_true(
        failure_of(HttpError(ErrorKind.PROTOCOL, "p", 0))
        == SubgraphFailure.RESPONSE_FAILURE
    )
    assert_true(
        failure_of(HttpError(ErrorKind.LIMIT, "l", 0))
        == SubgraphFailure.RESPONSE_FAILURE
    )
    assert_true(
        failure_of(HttpError(ErrorKind.CONNECT, "c", 0))
        == SubgraphFailure.REQUEST_FAILURE
    )
    assert_true(SubgraphFailure.UNKNOWN_SUBGRAPH.is_valid())
    assert_false(SubgraphFailure(5).is_valid())


def test_http_transport_failures() raises:
    var names: List[String] = ["closed"]
    # Port 9 on the loopback interface has no listener.
    var urls: List[String] = ["http://127.0.0.1:9/graphql"]
    var transport = HttpTransport(names, urls)
    var unknown = transport.send("other", "{ a }", List[UInt8]())
    assert_true(unknown.failure == SubgraphFailure.UNKNOWN_SUBGRAPH)
    var refused = transport.send("closed", "{ a }", List[UInt8]())
    assert_true(refused.failure == SubgraphFailure.REQUEST_FAILURE)


def test_a_used_canned_response_is_sent_again() raises:
    var transport = CannedTransport(True)
    transport.add("a", "{ a }", '{"data":{"a":1}}')
    var first = transport.send("a", "{ a }", List[UInt8]("1".as_bytes()))
    var second = transport.send("a", "{ a }", List[UInt8]("2".as_bytes()))
    assert_equal(_text(first^.take_body()), '{"data":{"a":1}}')
    assert_equal(_text(second^.take_body()), '{"data":{"a":1}}')
    assert_equal(len(transport.requests), 2)
    # With two used matches, the first one is sent again.
    transport.add("a", "{ a }", '{"data":{"a":2}}')
    _ = transport.send("a", "{ a }", List[UInt8]())
    var again = transport.send("a", "{ a }", List[UInt8]())
    assert_equal(_text(again^.take_body()), '{"data":{"a":1}}')
    var missing = transport.send("b", "{ b }", List[UInt8]())
    assert_true(missing.failure == SubgraphFailure.REQUEST_FAILURE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
