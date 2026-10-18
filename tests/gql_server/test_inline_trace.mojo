# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.inline_trace`: federated traces in
`extensions.ftv1`.

Ported from Apollo Server 5.5.1 (MIT)
`packages/server/src/__tests__/plugin/inlineTrace/inlineTracePlugin.test.ts`
and the `Federated tracing` cases of
`packages/integration-testsuite/src/apolloServerTests.ts`. The upstream
resolvers of `books` and `movies` wait 10 and 12 ms; these resolvers do
not wait, so the duration checks compare the times that the trace holds.
The other cases cover the branches of the plugin.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_raises
from std.testing import assert_true
from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE as NO_JSON
from gql_language.error import PathSegment
from gql_schema.build import build_schema
from gql_server.base64 import base64_decode
from gql_server.error_normalize import FormattedError
from gql_server.errors import ServerError, set_extension
from gql_server.http_types import HTTPGraphQLRequest
from gql_server.inline_trace import (
    InlineTraceOptions,
    InlineTracePlugin,
    schema_is_subgraph,
)
from gql_server.plugin import NoPlugin, ServerPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.server import default_context
from gql_server.trace_tree_builder import SendErrorsOptions
from gql_server.types import GraphQLRequest, GraphQLRequestContext
from gql_server.usage_reporting_protobuf import Trace, TraceNode

comptime FEDERATION_V1 = "type _Service { sdl: String }"
"""`federationV1TypeDefs`."""

comptime FEDERATION_V2 = "type _Service { sdl: String! }"
"""`federationV2TypeDefs`."""

comptime BASE = """
type Book { title: String author: String }
type Movie { title: String }
type Query { books: [Book] movies: [Movie] error: String }
"""
"""`baseTypeDefs`."""


def books(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`[{ title: 'H', author: 'J' }]`."""
    var json = parse_json('[{"title":"H","author":"J"}]')
    return values.add_json(json, json.root)


def movies(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`[{ title: 'H' }]`."""
    var json = parse_json('[{"title":"H"}]')
    return values.add_json(json, json.root)


def broken(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`throw new GraphQLError('It broke')`."""
    raise Error("It broke")


def base_resolvers() -> Resolvers:
    """The resolvers of `baseTypeDefs`."""
    var out = Resolvers()
    out.field("Query", "books", books)
    out.field("Query", "movies", movies)
    out.field("Query", "error", broken)
    return out^


def quiet_options() -> ApolloServerOptions:
    """The options of the tests."""
    var options = ApolloServerOptions()
    options.node_env = String("test")
    return options^


def make_server(
    type_defs: String, var options: ApolloServerOptions
) raises -> ApolloServer[NoPlugin]:
    """A started server of `baseTypeDefs` resolvers."""
    var server = ApolloServer.from_type_defs(
        type_defs, base_resolvers(), options^, NoPlugin()
    )
    server.start()
    return server^


def make_server(type_defs: String) raises -> ApolloServer[NoPlugin]:
    """A started server with the options of the tests. A default argument
    of a struct type does not keep the fields that `quiet_options` sets."""
    return make_server(type_defs, quiet_options())


def gateway_post(
    query: String, trace: Bool = True
) raises -> HTTPGraphQLRequest:
    """A JSON `POST`, with the header of a gateway when `trace` is set:
    `createApolloFetchAsIfFromGateway`."""
    var request = HTTPGraphQLRequest("POST")
    request.headers.set("content-type", "application/json")
    if trace:
        request.headers.set("apollo-federation-include-trace", "ftv1")
    var body = String('{"query":"') + query + '"}'
    request.body = parse_json(body)
    return request^


def send[
    P: ServerPlugin
](
    mut server: ApolloServer[P], query: String, trace: Bool = True
) raises -> String:
    """Send a request and return the content of the response."""
    var response = server.execute_http_graphql_request(
        gateway_post(query, trace), default_context
    )
    return response.body.copy()


def ftv1(body: String) raises -> Trace:
    """Decode `extensions.ftv1` of a response."""
    var json = parse_json(body)
    var extensions = json.find(json.root, "extensions")
    assert_true(extensions != NO_JSON)
    var encoded = json.find(extensions, "ftv1")
    assert_true(encoded != NO_JSON)
    var bytes = base64_decode(json.string_value(encoded))
    return Trace.decode(bytes)


def child(trace: Trace, node: Int, index: Int) -> Int:
    """The index in `trace.nodes` of a child of a node."""
    return trace.nodes[node].child[index]


# inlineTracePlugin.test.ts


def list_object(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`a: () => ({})`."""
    return values.add_object()


def broken_list(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`['hello world!', null]`."""
    var list = values.add_list()
    values.append(list, values.add_string("hello world!"))
    values.append(list, values.add_null())
    return list


def test_adds_errors_within_lists_to_the_correct_path() raises:
    var resolvers = Resolvers()
    resolvers.field("Query", "a", list_object)
    resolvers.field("A", "brokenList", broken_list)
    var options = quiet_options()
    options.inline_trace = InlineTraceOptions()
    var server = ApolloServer.from_type_defs(
        "type Query { a: A! } type A { brokenList: [String!]! }",
        resolvers^,
        options^,
        NoPlugin(),
    )
    server.start()
    var trace = ftv1(send(server, "{a{brokenList}}"))
    assert_equal(len(trace.nodes[0].error), 0)
    var a = child(trace, 0, 0)
    var list = child(trace, a, 0)
    var item = child(trace, list, 0)
    ref errors = trace.nodes[item].error
    assert_equal(len(errors), 1)
    assert_equal(
        errors[0].json,
        (
            '{"message":"<masked>","locations":[{"line":1,"column":4}],'
            '"path":["a","brokenList",1],'
            '"extensions":{"maskedBy":"ApolloServerPluginInlineTrace"}}'
        ),
    )
    assert_equal(len(errors[0].location), 1)
    assert_equal(errors[0].location[0].column, 4)
    assert_equal(errors[0].location[0].line, 1)
    assert_equal(errors[0].message, "<masked>")
    assert_equal(trace.nodes[item].index.value(), 1)
    assert_equal(trace.nodes[list].type, "[String!]!")
    assert_equal(trace.nodes[list].parent_type, "A")
    server.stop()


# apolloServerTests.ts: Federated tracing


def test_no_trace_without_the_special_header() raises:
    var server = make_server(FEDERATION_V2 + BASE)
    var body = send(server, "{ books { title author } }", trace=False)
    assert_false("extensions" in body)


def test_no_trace_without_service_in_the_schema() raises:
    var server = make_server(BASE)
    var body = send(server, "{ books { title author } }")
    assert_false("extensions" in body)


def _check_durations(type_defs: String) raises:
    var server = make_server(type_defs + BASE)
    var trace = ftv1(send(server, "{ books { title author } }"))
    var earliest = Int.MAX
    var latest = -1
    for ref node in trace.nodes:
        if node.start_time != 0 and node.end_time != 0:
            earliest = min(earliest, node.start_time)
            latest = max(latest, node.end_time)
    assert_true(earliest < Int.MAX)
    assert_true(latest > -1)
    var resolver_duration = latest - earliest
    assert_true(resolver_duration > 0)
    assert_true(trace.duration_ns >= resolver_duration)
    assert_true(trace.start_time.seconds <= trace.end_time.seconds)
    if trace.start_time.seconds == trace.end_time.seconds:
        assert_true(trace.start_time.nanos <= trace.end_time.nanos)
    assert_equal(trace.field_execution_weight, 1.0)
    var books = child(trace, 0, 0)
    assert_equal(trace.nodes[books].response_name.value(), "books")
    assert_equal(trace.nodes[books].type, "[Book]")
    assert_equal(trace.nodes[books].parent_type, "Query")
    var first = child(trace, books, 0)
    assert_equal(trace.nodes[first].index.value(), 0)
    assert_equal(len(trace.nodes[first].child), 2)
    var author = child(trace, first, 1)
    assert_equal(trace.nodes[author].response_name.value(), "author")
    assert_equal(trace.nodes[author].type, "String")
    assert_equal(trace.nodes[author].parent_type, "Book")


def test_total_duration_with_nullable_service_sdl() raises:
    _check_durations(FEDERATION_V1)


def test_total_duration_with_non_nullable_service_sdl() raises:
    _check_durations(FEDERATION_V2)


def format_error(
    formatted: FormattedError, error: ServerError
) raises -> FormattedError:
    """`formatError`: `Formatted: <message>`."""
    var out = formatted.copy()
    out.message = "Formatted: " + formatted.message
    return out^


def rewrite(var error: ServerError) raises -> Optional[ServerError]:
    """`transform`: `Rewritten for Usage Reporting: <message>`."""
    error.message = "Rewritten for Usage Reporting: " + error.message
    return error^


def _check_errors(type_defs: String) raises:
    var options = quiet_options()
    options.format_error = format_error
    var trace_options = InlineTraceOptions()
    trace_options.include_errors = SendErrorsOptions.with_transform(rewrite)
    options.inline_trace = trace_options^
    var server = make_server(type_defs + BASE, options^)
    var body = send(server, "{ error }")
    assert_true(
        body.startswith(
            '{"errors":[{"message":"Formatted: It broke","locations":'
            '[{"line":1,"column":3}],"path":["error"]'
        )
    )
    assert_true('"data":{"error":null}' in body)
    var trace = ftv1(body)
    var error = child(trace, 0, 0)
    assert_equal(
        trace.nodes[error].error[0].message,
        "Rewritten for Usage Reporting: It broke",
    )


def test_includes_errors_with_nullable_service_sdl() raises:
    _check_errors(FEDERATION_V1)


def test_includes_errors_with_non_nullable_service_sdl() raises:
    _check_errors(FEDERATION_V2)


# The other branches of the plugin.


def test_schema_is_subgraph() raises:
    var query = String(" type Query { a: String } type B { b: String }")
    assert_true(schema_is_subgraph(build_schema(FEDERATION_V1 + query)))
    assert_true(schema_is_subgraph(build_schema(FEDERATION_V2 + query)))
    var others: List[String] = [
        "",
        "scalar _Service",
        "interface _Service { sdl: String }",
        "type _Service { other: String }",
        "type _Service { sdl: [String] }",
        "type _Service { sdl: Int! }",
        "type _Service { sdl: B }",
    ]
    for ref other in others:
        assert_false(schema_is_subgraph(build_schema(other + query)))


def test_disabled_plugin_does_not_trace() raises:
    var options = quiet_options()
    options.inline_trace = None
    var server = make_server(FEDERATION_V2 + BASE, options^)
    assert_false("extensions" in send(server, "{ books { title } }"))
    var plugin = InlineTracePlugin.disabled()
    plugin.server_will_start(build_schema(FEDERATION_V2 + BASE))
    assert_false(plugin.enabled)


def test_in_process_operation_has_no_http_header() raises:
    var server = make_server(FEDERATION_V2 + BASE)
    var response = server.execute_operation(
        GraphQLRequest("{ books { title } }")
    )
    assert_false(Bool(response.extensions))


@fieldwise_init
struct TraceSwitch(ServerPlugin):
    """Sets `captureTraces`, the extensions of the response, or fails with
    a `serviceName` error."""

    var capture: Optional[Bool]
    var extensions: Optional[String]
    var service_error: Bool

    def request_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        if self.capture:
            ctx.metrics.capture_traces = self.capture

    def did_resolve_operation(
        mut self, mut ctx: GraphQLRequestContext
    ) raises ServerError:
        if self.service_error:
            var error = ServerError("from a subgraph")
            set_extension(error.extensions, "serviceName", '"books"')
            raise error^

    def will_send_response(mut self, mut ctx: GraphQLRequestContext) raises:
        if self.extensions:
            ctx.response.extensions = self.extensions


def switch_server(var plugin: TraceSwitch) raises -> ApolloServer[TraceSwitch]:
    """A started subgraph server with a `TraceSwitch`."""
    var server = ApolloServer.from_type_defs(
        FEDERATION_V2 + BASE, base_resolvers(), quiet_options(), plugin^
    )
    server.start()
    return server^


def test_capture_traces_false_turns_tracing_off() raises:
    var server = switch_server(TraceSwitch(False, None, False))
    assert_false("extensions" in send(server, "{ books { title } }"))
    var on = switch_server(TraceSwitch(True, None, False))
    assert_true('"extensions":{"ftv1":"' in send(on, "{ books { title } }"))


def test_ftv1_joins_the_extensions_of_other_plugins() raises:
    var server = switch_server(TraceSwitch(None, String(' {"a":1} '), False))
    assert_true(
        '"extensions":{"a":1,"ftv1":"' in send(server, "{ movies { title } }")
    )
    var empty = switch_server(TraceSwitch(None, String("{}"), False))
    assert_true('"extensions":{"ftv1":"' in send(empty, "{ movies { title } }"))


def test_ftv1_already_present() raises:
    var server = switch_server(TraceSwitch(None, String('{"ftv1":"x"}'), False))
    var body = send(server, "{ movies { title } }")
    assert_true("Internal server error" in body)
    assert_false('"ftv1":"x"' in body)


def test_errors_from_a_subgraph_are_skipped() raises:
    var server = switch_server(TraceSwitch(None, None, True))
    var body = send(server, "{ movies { title } }")
    assert_true("from a subgraph" in body)
    var trace = ftv1(body)
    assert_equal(len(trace.nodes), 1)
    assert_equal(len(trace.nodes[0].error), 0)


def test_errors_without_a_path_go_on_the_root() raises:
    var server = make_server(FEDERATION_V2 + BASE)
    var trace = ftv1(send(server, "{ books {"))
    assert_equal(len(trace.nodes), 1)
    assert_equal(len(trace.nodes[0].error), 1)
    assert_equal(trace.nodes[0].error[0].message, "<masked>")
    assert_equal(trace.nodes[0].error[0].location[0].column, 10)


def _server_with(
    var include_errors: SendErrorsOptions,
) raises -> ApolloServer[NoPlugin]:
    var options = quiet_options()
    var trace_options = InlineTraceOptions()
    trace_options.include_errors = include_errors^
    options.inline_trace = trace_options^
    return make_server(BASE, options^)


def test_unmodified_errors() raises:
    var server = _server_with(SendErrorsOptions.unmodified())
    var trace = ftv1(send(server, "{ error }"))
    ref error = trace.nodes[child(trace, 0, 0)].error[0]
    assert_equal(error.message, "It broke")
    assert_equal(
        error.json,
        (
            '{"message":"It broke","locations":[{"line":1,"column":3}],'
            '"path":["error"]}'
        ),
    )


def drop(var error: ServerError) raises -> Optional[ServerError]:
    """A `transform` that leaves every error out."""
    return None


def fail(var error: ServerError) raises -> Optional[ServerError]:
    """A `transform` that raises."""
    raise Error("transform failed")


def test_transform_can_leave_an_error_out() raises:
    var server = _server_with(SendErrorsOptions.with_transform(drop))
    var trace = ftv1(send(server, "{ error }"))
    assert_equal(len(trace.nodes[child(trace, 0, 0)].error), 0)


def test_transform_that_raises_fails_the_request() raises:
    var server = _server_with(SendErrorsOptions.with_transform(fail))
    var body = send(server, "{ error }")
    assert_true("Internal server error" in body)


def test_aliases_send_the_original_field_name() raises:
    var server = make_server(FEDERATION_V2 + BASE)
    var trace = ftv1(send(server, "{ b: books { title } movies { t: title } }"))
    var b = child(trace, 0, 0)
    assert_equal(trace.nodes[b].response_name.value(), "b")
    assert_equal(trace.nodes[b].original_field_name, "books")
    var movies = child(trace, 0, 1)
    assert_equal(trace.nodes[movies].original_field_name, "")
    var t = child(trace, child(trace, movies, 0), 0)
    assert_equal(trace.nodes[t].original_field_name, "title")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
