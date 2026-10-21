# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of incremental delivery with real executions, ported from Apollo
Server 5.5.1 `packages/integration-testsuite/src/httpServerTests.ts`,
`describe('tests that require graphql@17')`, and the cases of
`formatErrorsInSubsequentResultsAlpha9` in `requestPipeline.ts`.

The deferred entries have the key order of graphql-js 17.0.0-alpha.14,
`{"id":...,"data":...}`. Upstream runs graphql-js 17.0.0-alpha.9, which
writes `{"data":...,"id":...}`. Not ported: the cases of
`legacyExecuteIncrementally` of `@yaacovcr/transform`.
"""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from gql_execution.execute import Resolvers
from gql_execution.value import Values
from gql_language.ast import Document
from gql_server.http_types import HTTPGraphQLResponse
from gql_server.inline_trace import InlineTraceOptions
from gql_server.plugin import NoPlugin, PluginPair, ServerPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.types import GraphQLRequest
from gql_stream.waker import Waker
from _helpers import check, error_body, http_request
from _incremental import (
    ALPHA_2_ACCEPT,
    ALPHA_9_ACCEPT,
    INCREMENTAL_SDL,
    NOT_ACCEPTED,
    PART,
    body_of,
    incremental_resolvers,
)
from _plugins import Recorder, joined

comptime LEGACY = (
    "Apollo Server received an operation that uses incremental delivery"
    " (@defer or @stream) with the legacy incremental format, but the server"
    " does not support the legacy incremental delivery format. Add the HTTP"
    " header: 'Accept: multipart/mixed; incrementalSpec=v0.2' to use the"
    " current incremental delivery format"
)
"""The 406 error of `executeIncrementally` for the legacy format."""

comptime NOT_JSON = (
    "An 'accept' header was provided for this request which does not accept"
    " application/json; charset=utf-8 or application/graphql-response+json;"
    " charset=utf-8"
)
"""The 406 error of `runHttpQuery` for a single result."""


def _options() -> ApolloServerOptions:
    var out = ApolloServerOptions()
    out.node_env = String("test")
    return out^


def _server[
    P: ServerPlugin
](var options: ApolloServerOptions, var plugin: P) raises -> ApolloServer[P]:
    var server = ApolloServer.from_type_defs(
        INCREMENTAL_SDL, incremental_resolvers(), options^, plugin^
    )
    server.start()
    return server^


def _server() raises -> ApolloServer[NoPlugin]:
    return _server(_options(), NoPlugin())


def _post[
    P: ServerPlugin
](
    mut server: ApolloServer[P],
    accept: String,
    body: String,
    extra: String = "",
) raises -> HTTPGraphQLResponse:
    var headers: List[String] = ["content-type", "application/json"]
    if accept.byte_length() > 0:
        headers.append("accept")
        headers.append(accept)
    if extra.byte_length() > 0:
        headers.append(extra)
        headers.append("ftv1")
    return server.execute_http_graphql_request(
        http_request("POST", "", headers, body)
    )


def _query(query: String) -> String:
    return '{"query":"' + query + '"}'


def _body(*parts: String) -> String:
    var out = String("\r\n---\r\n")
    var index = 0
    while index < len(parts):
        out += PART + parts[index]
        out += "\r\n-----\r\n" if index == len(parts) - 1 else "\r\n---\r\n"
        index += 1
    return out^


def test_errors_when_defer_is_used_without_multipart() raises:
    var accepts: List[String] = [
        "",
        "application/json",
        "multipart/mixed",
        "multipart/mixed; deferSpec=12345",
    ]
    for ref accept in accepts:
        var server = _server()
        var response = _post(
            server, accept, _query("{ ... @defer { testString } }")
        )
        assert_equal(response.status, 406)
        assert_equal(
            response.body, error_body(NOT_ACCEPTED, "BAD_REQUEST") + "\n"
        )
        assert_false(response.is_chunked())


def test_legacy_format_is_not_supported() raises:
    var query = _query("{ first: testString ... @defer { testString } }")
    var accepts: List[String] = [
        ALPHA_2_ACCEPT + ", application/json",
        "application/json, " + ALPHA_2_ACCEPT,
    ]
    for ref accept in accepts:
        var server = _server()
        var response = _post(server, accept, query)
        check(response, 406, "no-store", error_body(LEGACY, "BAD_REQUEST"))
    # Without `application/json`, the single result of the legacy error
    # has no content type: `runHttpQuery` gives its own 406 error.
    var server = _server()
    var response = _post(server, ALPHA_2_ACCEPT, query)
    check(response, 406, "", error_body(NOT_JSON, "BAD_REQUEST"))


def test_basic_defer_working() raises:
    var accepts: List[String] = [
        ALPHA_9_ACCEPT,
        ALPHA_9_ACCEPT + ", application/json",
        "application/json, " + ALPHA_9_ACCEPT,
    ]
    for ref accept in accepts:
        var server = _server()
        var response = _post(
            server,
            accept,
            _query("{ first: testString ... @defer { testString } }"),
        )
        assert_equal(response.status, 0)
        assert_equal(
            response.headers.get("content-type").value(),
            'multipart/mixed; boundary="-"; incrementalSpec=v0.2',
        )
        assert_equal(
            body_of(server, response),
            _body(
                (
                    '{"data":{"first":"it'
                    ' works"},"pending":[{"id":"0","path":[]}],"hasNext":true}'
                ),
                (
                    '{"hasNext":false,"incremental":[{"id":"0","data":'
                    '{"testString":"it works"}}],"completed":[{"id":"0"}]}'
                ),
            ),
        )


def test_basic_stream_working() raises:
    var server = _server()
    var response = _post(
        server, ALPHA_9_ACCEPT, _query("{ testStrings @stream }")
    )
    assert_equal(
        body_of(server, response),
        _body(
            (
                '{"data":{"testStrings":[]},"pending":[{"id":"0","path":'
                '["testStrings"]}],"hasNext":true}'
            ),
            '{"hasNext":true,"incremental":[{"id":"0","items":["it works"]}]}',
            (
                '{"hasNext":true,"incremental":[{"id":"0","items":["it works'
                ' again"]}]}'
            ),
            (
                '{"hasNext":true,"incremental":[{"id":"0","items":["it works'
                ' again again"]}]}'
            ),
            '{"hasNext":false,"completed":[{"id":"0"}]}',
        ),
    )


def test_first_payload_sent_while_deferred_field_is_blocking() raises:
    var server = _server()
    var response = _post(
        server,
        ALPHA_9_ACCEPT + ", application/json",
        _query("{ testString ... @defer { barrierString } }"),
    )
    var initial = String(
        '{"data":{"testString":"it works"},"pending":[{"id":"0","path":[]}],'
        '"hasNext":true}'
    )
    # The deferred field runs on the first poll of the later parts.
    assert_equal(response.body, "\r\n---\r\n" + PART + initial + "\r\n---\r\n")
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


def test_subsequent_errors_are_formatted() raises:
    var plugin = PluginPair(Recorder("a:"), Recorder("b:"))
    var server = _server(_options(), plugin^)
    var response = _post(
        server,
        ALPHA_9_ACCEPT,
        _query("{ testString ... @defer { failing } ... @defer { nonNull } }"),
    )
    var text = body_of(server, response)
    assert_true(
        '"incremental":[{"id":"0","data":{"failing":null},"errors":[{"message":'
        '"boom","locations":[{"line":1,"column":27}],"path":["failing"],'
        '"extensions":{"code":"INTERNAL_SERVER_ERROR"}}]}]'
        in text,
        text,
    )
    assert_true(
        '{"id":"1","errors":[{"message":"boom","locations":[{"line":1,'
        '"column":50}],"path":["nonNull"],"extensions":{"code":'
        '"INTERNAL_SERVER_ERROR"}}]}'
        in text,
        text,
    )
    var log = joined(server.plugin.first.log)
    assert_true("a:didEncounterSubsequentErrors(1)" in log, log)
    assert_true("a:willSendSubsequentPayload" in log, log)
    assert_true(
        "b:willSendSubsequentPayload" in joined(server.plugin.second.log)
    )


def test_will_send_subsequent_payload_can_change_it() raises:
    var server = _server(_options(), Recorder("rewrite:"))
    var response = _post(
        server,
        ALPHA_9_ACCEPT,
        _query("{ testString ... @defer { barrierString } }"),
    )
    var text = body_of(server, response)
    assert_true(
        text.endswith(PART + '{"hasNext":false,"rewritten":true}\r\n-----\r\n'),
        text,
    )


def test_hook_that_raises_ends_the_body() raises:
    var server = _server(_options(), Recorder("", "willSendSubsequentPayload"))
    var response = _post(
        server,
        ALPHA_9_ACCEPT,
        _query("{ testString ... @defer { barrierString } }"),
    )
    assert_equal(body_of(server, response), response.body)


def test_no_inline_trace_and_no_cache_header_for_incremental() raises:
    var options = _options()
    options.inline_trace = InlineTraceOptions()
    var server = _server(options^, NoPlugin())
    var response = _post(
        server,
        ALPHA_9_ACCEPT,
        _query("{ testString ... @defer { barrierString } }"),
        "apollo-federation-include-trace",
    )
    assert_false("extensions" in response.body, response.body)
    assert_equal(response.headers.get("cache-control").or_else(""), "no-store")


def test_batch_with_incremental_delivery() raises:
    var options = _options()
    options.allow_batched_http_requests = True
    var server = _server(options^, NoPlugin())
    var response = _post(
        server,
        ALPHA_9_ACCEPT,
        "[" + _query("{ testString ... @defer { barrierString } }") + "]",
    )
    # Upstream throws a plain `Error`.
    check(
        response,
        500,
        "",
        error_body(
            "Incremental delivery is not implemented for batch requests",
            "INTERNAL_SERVER_ERROR",
        ),
    )
    # A deferred fragment that is not delivered gives a single result,
    # which needs `application/json`.
    var batch = (
        "["
        + _query("{ testString ... @defer(if: false) { barrierString } }")
        + ","
        + _query("{ testString }")
        + "]"
    )
    response = _post(server, ALPHA_9_ACCEPT, batch)
    check(response, 406, "", error_body(NOT_JSON, "BAD_REQUEST"))
    response = _post(server, ALPHA_9_ACCEPT + ", application/json", batch)
    check(
        response,
        0,
        "no-store",
        (
            '[{"data":{"testString":"it works","barrierString":"we waited"}}\n,'
            '{"data":{"testString":"it works"}}\n]'
        ),
        final_newline=False,
    )


def test_execute_operation_with_defer() raises:
    var server = _server()
    var response = server.execute_operation(
        GraphQLRequest(String("{ testString ... @defer { barrierString } }"))
    )
    assert_true(response.is_incremental())
    assert_equal(
        response.to_json(),
        (
            '{"data":{"testString":"it'
            ' works"},"pending":[{"id":"0","path":[]}],"hasNext":true}'
        ),
    )
    var waker = Waker.noop()
    var payload = server.next_subsequent_payload(response, waker)
    assert_equal(
        payload.value().json,
        (
            '{"hasNext":false,"incremental":[{"id":"0","data":'
            '{"barrierString":"we waited"}}],"completed":[{"id":"0"}]}'
        ),
    )
    assert_false(payload.value().has_next)
    assert_false(server.next_subsequent_payload(response, waker))
    var single = server.execute_operation(
        GraphQLRequest(String("{ testString }"))
    )
    assert_false(single.is_incremental())
    with assert_raises(contains="not incremental"):
        _ = server.next_subsequent_payload(single, waker)


def _failing_root(mut values: Values, document: Document) raises -> Int:
    raise Error("no root")


def test_root_value_that_raises() raises:
    # The same error response, with or without incremental delivery.
    var options = _options()
    options.root_value = _failing_root
    var server = _server(options^, NoPlugin())
    var queries: List[String] = [
        "{ testString ... @defer { barrierString } }",
        "{ testString }",
    ]
    for ref query in queries:
        var response = server.execute_operation(GraphQLRequest(query))
        assert_equal(response.http.status, 500)
        assert_equal(response.errors[0].message, "no root")


def test_unknown_operation_with_defer() raises:
    var server = _server()
    var request = GraphQLRequest(
        String("query A { ... @defer { testString } }")
    )
    request.operation_name = String("B")
    var response = server.execute_operation(request^)
    assert_equal(response.http.status, 400)
    assert_equal(response.errors[0].message, 'Unknown operation named "B".')


comptime HERO_SDL = """
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT
type Query {
  hero: Hero
}
type Hero {
  id: ID
  name: String
}
"""
"""A schema with a nested object, for the `subPath` of an entry."""


def _hero_root(mut values: Values, document: Document) raises -> Int:
    var hero = values.add_object()
    var id = values.add_string("1")
    values.add_member(hero, "id", id)
    var name = values.add_string("Luke")
    values.add_member(hero, "name", name)
    var root = values.add_object()
    values.add_member(root, "hero", hero)
    return root


def test_entry_with_sub_path_labels_and_variables() raises:
    # graphql-js `Separately emits defer fragments with varying subfields of
    # same priorities but different level of defers`, through the server.
    var options = _options()
    options.root_value = _hero_root
    var server = ApolloServer.from_type_defs(
        HERO_SDL, Resolvers(), options^, NoPlugin()
    )
    server.start()
    var response = _post(
        server,
        ALPHA_9_ACCEPT,
        (
            '{"query":"query Q($w: Boolean!) { hero { ... @defer(label:'
            ' \\"DeferID\\") { id } } ... @defer(label: \\"DeferName\\") {'
            ' hero { name @include(if: $w) } } }","variables":{"w":true}}'
        ),
    )
    assert_equal(
        body_of(server, response),
        _body(
            (
                '{"data":{"hero":{}},"pending":[{"id":"0","path":["hero"],'
                '"label":"DeferID"},{"id":"1","path":[],"label":"DeferName"}],'
                '"hasNext":true}'
            ),
            (
                '{"hasNext":false,"incremental":[{"id":"0","data":{"id":"1"}},'
                '{"id":"1","data":{"name":"Luke"},"subPath":["hero"]}],'
                '"completed":[{"id":"0"},{"id":"1"}]}'
            ),
        ),
    )


def test_other_directive_before_defer() raises:
    # A directive that is not `@defer` or `@stream` does not end the search.
    var server = _server()
    var response = server.execute_operation(
        GraphQLRequest(
            String("{ testString @include(if: true) ... @defer { failing } }")
        )
    )
    assert_true(response.is_incremental())


def test_nested_defers_and_errors_without_hooks() raises:
    # Two pending entries in a later payload, and two errors in one entry,
    # with a plugin that keeps the default hooks.
    var server = _server()
    var response = _post(
        server,
        ALPHA_9_ACCEPT,
        _query(
            "{ testString ... @defer { barrierString ... @defer(label:"
            ' \\"a\\") { failing again: failing } ... @defer(label: \\"b\\")'
            " { nonNull } } }"
        ),
    )
    comptime BOOM = '{"message":"boom","locations":[{"line":1,"column":'
    comptime CODE = '"extensions":{"code":"INTERNAL_SERVER_ERROR"}}'
    assert_equal(
        body_of(server, response),
        _body(
            (
                '{"data":{"testString":"it works"},"pending":[{"id":"0",'
                '"path":[]}],"hasNext":true}'
            ),
            '{"hasNext":false,"pending":[{"id":"1","path":[],"label":"a"},'
            + '{"id":"2","path":[],"label":"b"}],"incremental":[{"id":"0",'
            + '"data":{"barrierString":"we waited"}},{"id":"1","data":'
            + '{"failing":null,"again":null},"errors":['
            + BOOM
            + '66}],"path":["failing"],'
            + CODE
            + ","
            + BOOM
            + '74}],"path":["again"],'
            + CODE
            + ']}],"completed":[{"id":"0"},{"id":"1"},{"id":"2","errors":['
            + BOOM
            + '116}],"path":["nonNull"],'
            + CODE
            + "]}]}",
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
