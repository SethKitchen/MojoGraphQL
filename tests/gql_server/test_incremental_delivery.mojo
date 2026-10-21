# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of incremental delivery over HTTP, ported from Apollo Server 5.5.1
`packages/integration-testsuite/src/httpServerTests.ts`, `describe(
'incremental delivery')`: the `mocked execution` cases and the cases of
`tests that require graphql@17`.

The expected bodies are those of upstream. The deferred entries of the real
executions have the key order of graphql-js 17.0.0-alpha.14,
`{"id":...,"data":...}`; upstream runs graphql-js 17.0.0-alpha.9, which
writes `{"data":...,"id":...}`.

Not ported: the legacy cases that run `legacyExecuteIncrementally` of
`@yaacovcr/transform`, because no executor of the legacy format exists
here. The legacy format still works with the testing option, as the mocked
cases show, and a real execution gets the upstream 406 error.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from gql_http.body import BodyPoll
from gql_server.http_types import HTTPGraphQLResponse
from gql_server.incremental import TestingIncrementalResults
from gql_server.plugin import NoPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_stream.poll import Event
from gql_stream.stream import AnyStream, ListStream
from _helpers import check, error_body, http_request
from _incremental import (
    ALPHA_2_ACCEPT,
    ALPHA_9_ACCEPT,
    INCREMENTAL_SDL,
    NOT_ACCEPTED,
    PART,
    Steps,
    body_of,
    incremental_resolvers,
    read_chunks,
)


def _options() -> ApolloServerOptions:
    var out = ApolloServerOptions()
    out.node_env = String("test")
    return out^


def _server(var options: ApolloServerOptions) raises -> ApolloServer[NoPlugin]:
    var server = ApolloServer.from_type_defs(
        INCREMENTAL_SDL, incremental_resolvers(), options^, NoPlugin()
    )
    server.start()
    return server^


def _post(
    mut server: ApolloServer[NoPlugin], accept: String, query: String
) raises -> HTTPGraphQLResponse:
    var headers: List[String] = ["content-type", "application/json"]
    if accept.byte_length() > 0:
        headers.append("accept")
        headers.append(accept)
    var request = http_request("POST", "", headers, '{"query":"' + query + '"}')
    return server.execute_http_graphql_request(request^)


def _body(*parts: String) -> String:
    """The bytes of `writeMultipartBody` for the JSON of each part."""
    var out = String("\r\n---\r\n")
    var index = 0
    while index < len(parts):
        out += PART + parts[index]
        out += "\r\n-----\r\n" if index == len(parts) - 1 else "\r\n---\r\n"
        index += 1
    return out^


def _legacy_payloads() raises -> AnyStream:
    var texts: List[String] = [
        '{"hasNext":false,"incremental":[{"path":[],"data":{"testString":"it'
        ' works"}}]}'
    ]
    return AnyStream(ListStream.of_json(texts))


def _alpha_9_payloads() raises -> AnyStream:
    var texts: List[String] = [
        '{"hasNext":false,"incremental":[{"id":"0","data":{"testString":"it'
        ' works"}}],"completed":[{"id":"0"}]}'
    ]
    return AnyStream(ListStream.of_json(texts))


def _blocking_payloads() raises -> AnyStream:
    var events = List[Event]()
    events.append(
        Event.parse(
            '{"hasNext":false,"incremental":[{"id":"0","data":'
            '{"barrierString":"we waited"}}],"completed":[{"id":"0"}]}'
        )
    )
    return AnyStream(Steps(events^))


def _failing_payloads() raises -> AnyStream:
    return AnyStream(ListStream(List[Event](), "the generator throws"))


def _unfinished_payloads() raises -> AnyStream:
    var texts: List[String] = ['{"hasNext":true}']
    return AnyStream(ListStream.of_json(texts))


def _mocked(
    initial: String, factory: def() raises thin -> AnyStream
) raises -> ApolloServer[NoPlugin]:
    var options = _options()
    options.testing_incremental_execution_results = TestingIncrementalResults(
        initial, factory
    )
    return _server(options^)


def test_mocked_basic_defer_legacy() raises:
    var initial = String('{"hasNext":true,"data":{"first":"it works"}}')
    var server = _mocked(initial, _legacy_payloads)
    var response = _post(
        server,
        ALPHA_2_ACCEPT + ", application/json",
        "{ first: testString ... @defer { testString } }",
    )
    assert_equal(response.status, 0)
    assert_equal(
        response.headers.get("content-type").value(),
        'multipart/mixed; boundary="-"; deferSpec=20220824',
    )
    assert_equal(
        body_of(server, response),
        _body(
            initial,
            (
                '{"hasNext":false,"incremental":[{"path":[],"data":'
                '{"testString":"it works"}}]}'
            ),
        ),
    )


def test_mocked_basic_defer_alpha_9() raises:
    var initial = String(
        '{"hasNext":true,"pending":[{"id":"0","path":[]}],"data":'
        '{"first":"it works"}}'
    )
    var server = _mocked(initial, _alpha_9_payloads)
    var response = _post(
        server,
        ALPHA_9_ACCEPT + ", application/json",
        "{ first: testString ... @defer { testString } }",
    )
    assert_equal(
        response.headers.get("content-type").value(),
        'multipart/mixed; boundary="-"; incrementalSpec=v0.2',
    )
    assert_equal(
        body_of(server, response),
        _body(
            initial,
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":'
                '{"testString":"it works"}}],"completed":[{"id":"0"}]}'
            ),
        ),
    )


def test_mocked_first_payload_sent_while_deferred_field_is_blocking() raises:
    var initial = String(
        '{"hasNext":true,"pending":[{"id":"0","path":[]}],"data":'
        '{"testString":"it works"}}'
    )
    var server = _mocked(initial, _blocking_payloads)
    var response = _post(
        server,
        ALPHA_9_ACCEPT + ", application/json",
        "{ testString ... @defer { barrierString } }",
    )
    # The first part, with its delimiter, is out before the second exists.
    assert_equal(response.body, "\r\n---\r\n" + PART + initial + "\r\n---\r\n")
    var chunks = response.chunks.value()
    var out = List[UInt8]()
    assert_equal(server.poll_chunk(chunks, out), BodyPoll.PENDING)
    assert_equal(len(out), 0)
    assert_equal(
        body_of(server, response),
        _body(
            initial,
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":'
                '{"barrierString":"we waited"}}],"completed":[{"id":"0"}]}'
            ),
        ),
    )


def test_mocked_payloads_that_fail() raises:
    var server = _mocked(String('{"hasNext":true}'), _failing_payloads)
    var response = _post(server, ALPHA_9_ACCEPT, "{ testString }")
    var parts = List[String]()
    assert_equal(read_chunks(server, response, parts), BodyPoll.ERROR)
    assert_equal(len(parts), 0)
    var out = List[UInt8]()
    assert_equal(server.poll_chunk(response.chunks.value(), out), BodyPoll.DONE)


def test_mocked_payloads_that_end_without_has_next_false() raises:
    var server = _mocked(String('{"hasNext":true}'), _unfinished_payloads)
    var response = _post(server, ALPHA_9_ACCEPT, "{ testString }")
    var parts = List[String]()
    assert_equal(read_chunks(server, response, parts), BodyPoll.DONE)
    # Upstream writes the delimiter from `hasNext`, so no close delimiter.
    assert_equal(len(parts), 1)
    assert_equal(parts[0], PART + '{"hasNext":true}\r\n---\r\n')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
