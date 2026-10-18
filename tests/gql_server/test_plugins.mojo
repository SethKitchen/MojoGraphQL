# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the plugin hooks, ported from Apollo Server 5.5.1
`src/__tests__/runQuery.test.ts` (`request pipeline life-cycle hooks`:
`requestDidStart`, `didResolveSource`, `parsingDidStart`,
`executionDidStart`, `executionDidEnd`, `didEncounterErrors`, `calls hooks
in the expected order`), `src/__tests__/ApolloServer.test.ts` (`ApolloServer
start`) and `packages/integration-testsuite/src/httpServerTests.ts`
(`throwing in didResolveOperation results in error with default HTTP
status code` and `... with specified HTTP status code`, `willSendResponse
can be equivalent to the old formatResponse function`, `calls
serverWillStart before serving a request`).

Upstream cases that are not ported: the `willResolveField` cases, because
`gql_execution` has no field hook; `executionDidEnd is only called once if
it throws`, which tests promise handling; and `addPlugin`, which is not
ported (see `gql_server.server`).
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _helpers import (
    SDL,
    check,
    context,
    error_body,
    failing_context,
    json_post,
    options,
    resolvers,
    root_value,
)
from _plugins import Recorder, joined
from gql_execution.value import Values
from gql_language.ast import Document
from gql_server.plugin import NoPlugin, PluginPair, ServerPlugin
from gql_server.server import ApolloServer, ServerPhase
from gql_server.types import GraphQLRequest, GraphQLRequestContext


def _server(var plugin: Recorder) raises -> ApolloServer[Recorder]:
    var server = ApolloServer[Recorder].from_type_defs(
        SDL, resolvers(), options(), plugin^
    )
    server.start()
    return server^


def test_hooks_in_order() raises:
    var server = _server(Recorder())
    var response = server.execute_operation(
        GraphQLRequest(String("{ testString }"))
    )
    assert_false(response.has_errors)
    assert_equal(
        joined(server.plugin.log),
        (
            "serverWillStart requestDidStart didResolveSource parsingDidStart"
            " parsingDidEnd validationDidStart validationDidEnd(0)"
            " didResolveOperation responseForOperation executionDidStart"
            " executionDidEnd willSendResponse"
        ),
    )
    # The second request finds the document in the store.
    server.plugin.log.clear()
    _ = server.execute_operation(GraphQLRequest(String("{ testString }")))
    assert_equal(
        joined(server.plugin.log),
        (
            "requestDidStart didResolveSource didResolveOperation"
            " responseForOperation executionDidStart executionDidEnd"
            " willSendResponse"
        ),
    )


def test_did_encounter_errors() raises:
    var server = _server(Recorder())
    _ = server.execute_operation(GraphQLRequest(String("{")))
    assert_true(
        "parsingDidEnd(error) didEncounterErrors(1)"
        in joined(server.plugin.log)
    )
    server.plugin.log.clear()
    _ = server.execute_operation(GraphQLRequest(String("{ a b }")))
    assert_true(
        "validationDidEnd(2) didEncounterErrors(2)" in joined(server.plugin.log)
    )
    server.plugin.log.clear()
    _ = server.execute_operation(GraphQLRequest(String("{ testError }")))
    assert_true(
        "didEncounterErrors(1) executionDidEnd willSendResponse"
        in joined(server.plugin.log)
    )
    server.plugin.log.clear()
    _ = server.execute_operation(GraphQLRequest(String("{ testString }")))
    assert_false("didEncounterErrors" in joined(server.plugin.log))


def test_did_resolve_operation_throws() raises:
    var plugin = Recorder(fail_at="didResolveOperation")
    var server = _server(plugin^)
    var response = server.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), context
    )
    check(
        response, 500, "no-store", error_body("denied", "INTERNAL_SERVER_ERROR")
    )
    plugin = Recorder(fail_at="didResolveOperation")
    plugin.status = 403
    server = _server(plugin^)
    response = server.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), context
    )
    check(
        response, 403, "no-store", error_body("denied", "INTERNAL_SERVER_ERROR")
    )


def test_hook_raises() raises:
    var server = _server(Recorder(fail_at="didResolveSource"))
    var raised = False
    try:
        _ = server.execute_operation(GraphQLRequest(String("{ testString }")))
    except e:
        raised = True
        assert_equal(String(e), "Internal server error")
    assert_true(raised)
    assert_true(
        joined(server.plugin.log).endswith("unexpectedErrorProcessingRequest")
    )
    var response = server.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), context
    )
    check(
        response,
        500,
        "",
        error_body("Internal server error", "INTERNAL_SERVER_ERROR"),
    )
    # The error of `unexpectedErrorProcessingRequest` replaces it.
    var pair = ApolloServer[PluginPair[Recorder, Recorder]].from_type_defs(
        SDL,
        resolvers(),
        options(),
        PluginPair(
            Recorder(fail_at="didResolveSource"),
            Recorder(fail_at="unexpectedErrorProcessingRequest"),
        ),
    )
    pair.start()
    response = pair.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), context
    )
    check(
        response,
        500,
        "",
        error_body(
            "unexpectedErrorProcessingRequest failed", "INTERNAL_SERVER_ERROR"
        ),
    )
    var failing = _server(Recorder(fail_at="willSendResponse"))
    response = failing.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), context
    )
    check(
        response,
        500,
        "",
        error_body("Internal server error", "INTERNAL_SERVER_ERROR"),
    )


def test_response_for_operation() raises:
    var plugin = Recorder()
    plugin.respond = True
    var server = _server(plugin^)
    var response = server.execute_operation(
        GraphQLRequest(String("{ testString }"))
    )
    assert_equal(response.http.status, 202)
    assert_equal(response.to_json(), '{"data":{}}')
    assert_false("executionDidStart" in joined(server.plugin.log))


def test_will_send_response_formats() raises:
    var server = _server(Recorder("format:"))
    var response = server.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), context
    )
    check(
        response,
        0,
        "no-store",
        '{"data":{"testString":"it works"},"extensions":{"formatted":true}}',
    )
    response = server.execute_http_graphql_request(
        json_post('{"query":"{"}'), context
    )
    assert_true(response.body.endswith(',"extensions":{"formatted":true}}\n'))


def test_plugin_pair_order() raises:
    var server = ApolloServer[PluginPair[Recorder, Recorder]].from_type_defs(
        SDL, resolvers(), options(), PluginPair(Recorder("a:"), Recorder("b:"))
    )
    server.start()
    _ = server.execute_operation(GraphQLRequest(String("{ testString }")))
    server.stop()
    var first = joined(server.plugin.first.log)
    assert_equal(len(server.plugin.first.log), len(server.plugin.second.log))
    assert_true(first.startswith("a:serverWillStart a:requestDidStart"))
    assert_true(first.endswith("a:willSendResponse a:serverWillStop"))


def test_start_fails() raises:
    var server = ApolloServer[Recorder].from_type_defs(
        SDL, resolvers(), options(), Recorder(fail_at="serverWillStart")
    )
    var raised = False
    try:
        server.start()
    except e:
        raised = True
        assert_equal(String(e), "serverWillStart failed")
    assert_true(raised)
    assert_true(server.phase == ServerPhase.FAILED_TO_START)
    check(
        server.execute_http_graphql_request(
            json_post('{"query":"{ testString }"}'), context
        ),
        500,
        "",
        error_body(
            (
                "This data graph is missing a valid configuration. More details"
                " may be available in the server logs."
            ),
            "INTERNAL_SERVER_ERROR",
        ),
    )
    raised = False
    try:
        server.start()
    except e:
        raised = True
        assert_true(String(e).startswith("You should only call 'start()'"))
    assert_true(raised)


def test_execute_operation_starts_the_server() raises:
    var server = ApolloServer[Recorder].from_type_defs(
        SDL, resolvers(), options(), Recorder()
    )
    var response = server.execute_operation(
        GraphQLRequest(String("{ testString }"))
    )
    assert_equal(response.to_json(), '{"data":{"testString":"it works"}}')
    assert_true(server.phase == ServerPhase.STARTED)
    server.stop()
    server.stop()
    assert_equal(joined(server.plugin.log).count("serverWillStop"), 1)
    var raised = False
    try:
        _ = server.execute_operation(GraphQLRequest(String("{ testString }")))
    except:
        raised = True
    assert_true(raised)


def test_context_and_invalid_request_hooks() raises:
    var server = _server(Recorder(fail_at="contextCreationDidFail"))
    var response = server.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), failing_context
    )
    assert_equal(response.status, 500)
    assert_true("contextCreationDidFail" in joined(server.plugin.log))
    server = _server(Recorder(fail_at="invalidRequestWasReceived"))
    response = server.execute_http_graphql_request(json_post("{}"), context)
    assert_equal(response.status, 400)
    assert_true("invalidRequestWasReceived" in joined(server.plugin.log))


def test_validation_end_hook_can_change_errors() raises:
    var plugin = Recorder()
    plugin.clear_validation = True
    var server = _server(plugin^)
    var response = server.execute_operation(GraphQLRequest(String("{ nope }")))
    assert_equal(response.http.status, 500)
    assert_equal(response.to_json(), '{"errors":[]}')


def failing_root(mut values: Values, document: Document) raises -> Int:
    raise Error("no root")


def test_execution_raises() raises:
    var opts = options()
    opts.root_value = failing_root
    var server = ApolloServer[Recorder].from_type_defs(
        SDL, resolvers(), opts^, Recorder()
    )
    var response = server.execute_operation(
        GraphQLRequest(String("{ testString }"))
    )
    assert_equal(response.http.status, 500)
    assert_equal(
        response.to_json(),
        (
            '{"errors":[{"message":"no'
            ' root","extensions":{"code":"INTERNAL_SERVER_ERROR"}}]}'
        ),
    )
    assert_true("executionDidEnd(error)" in joined(server.plugin.log))
    var request = GraphQLRequest(String("{ testString }"))
    request.set_variables("5")
    var plain = ApolloServer[NoPlugin].from_type_defs(
        SDL, resolvers(), options(), NoPlugin()
    )
    response = plain.execute_operation(request^)
    assert_equal(response.http.status, 500)
    assert_true(
        response.errors[0].message.startswith(
            "Variables must be provided as an Object"
        )
    )


def test_operation_resolution_hook() raises:
    var server = _server(Recorder())
    var request = GraphQLRequest(String("query a { testString }"))
    request.operation_name = String("b")
    var response = server.execute_operation(request^)
    assert_equal(response.http.status, 400)
    assert_true("executionDidEnd(error)" in joined(server.plugin.log))


def _pair(
    var first: Recorder,
) raises -> ApolloServer[PluginPair[Recorder, Recorder]]:
    var server = ApolloServer[PluginPair[Recorder, Recorder]].from_type_defs(
        SDL, resolvers(), options(), PluginPair(first^, Recorder("b:"))
    )
    server.start()
    return server^


def test_plugin_pair_error_hooks() raises:
    var first = Recorder("a:")
    first.respond = True
    var server = _pair(first^)
    var response = server.execute_operation(
        GraphQLRequest(String("{ testString }"))
    )
    assert_equal(response.http.status, 202)
    assert_false("responseForOperation" in joined(server.plugin.second.log))
    server = _pair(Recorder("a:"))
    _ = server.execute_operation(GraphQLRequest(String("{ testError }")))
    assert_true("b:didEncounterErrors" in joined(server.plugin.second.log))
    _ = server.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), failing_context
    )
    assert_true("b:contextCreationDidFail" in joined(server.plugin.second.log))
    _ = server.execute_http_graphql_request(json_post("{}"), context)
    assert_true(
        "b:invalidRequestWasReceived" in joined(server.plugin.second.log)
    )


struct Raiser(ServerPlugin):
    """A plugin with one hook, which raises; the others are the defaults."""

    def __init__(out self):
        pass

    def request_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        raise Error("no")


def test_default_unexpected_error_hook() raises:
    var server = ApolloServer[Raiser].from_type_defs(
        SDL, resolvers(), options(), Raiser()
    )
    server.start()
    var response = server.execute_http_graphql_request(
        json_post('{"query":"{ testString }"}'), context
    )
    check(
        response,
        500,
        "",
        error_body("Internal server error", "INTERNAL_SERVER_ERROR"),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
