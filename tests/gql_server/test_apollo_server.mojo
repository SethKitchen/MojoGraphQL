# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `ApolloServer` and `execute_operation`, ported from Apollo
Server 5.5.1 `src/__tests__/ApolloServer.test.ts` (`ApolloServer
construction`, `ApolloServer executeOperation`),
`src/__tests__/runQuery.test.ts` (the results of operations, `parsing and
validation cache`, `validationMaxErrors option`) and
`src/__tests__/documentStore.test.ts`.

Upstream cases that are not ported:
- `stringifyResult`, the Apollo key and graph variant cases, `TypeScript
  enforces ...`, the context typing cases and `TypedQueryDocumentNode`:
  they test options and TypeScript types that the port does not have.
- `works with AST`: a request holds query text; print a document with
  `gql_language.printer` first.
- The `someField` extension of the `error` resolver: a Mojo resolver
  cannot give extensions.
- `supports yielding resolver functions`: there are no async resolvers.
- `documentStore - custom` and `the documentStore calculates the
  DocumentNode's length by its JSON.stringify'd representation`: the
  document store is not an option.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _plugins import Recorder, joined
from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_schema.build import build_schema
from gql_server.plugin import NoPlugin
from gql_server.server import (
    ApolloServer,
    ApolloServerOptions,
    ExecuteOperationOptions,
)
from gql_server.types import GraphQLRequest

comptime TYPE_DEFS = """
type Query {
  hello: String
  error: Boolean
  contextFoo: String
  needsStringArg(aString: String): String
  needsCompoundArg(aCompound: CompoundInput): String
}
input CompoundInput { compound: NestedInput! }
input NestedInput { nested1: String! nested2: String! }
"""
"""The schema of upstream `ApolloServer.test.ts`."""


def hello(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("world")


def error(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    raise Error("A test error")


def context_foo(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.get(info.context_value, "foo")


def _resolvers() -> Resolvers:
    var out = Resolvers()
    out.field("Query", "hello", hello)
    out.field("Query", "error", error)
    out.field("Query", "contextFoo", context_foo)
    return out^


def _server(
    var options: ApolloServerOptions = ApolloServerOptions(),
) raises -> ApolloServer[NoPlugin]:
    if not options.node_env:
        options.node_env = String("test")
    var server = ApolloServer.from_type_defs(
        TYPE_DEFS, _resolvers(), options^, NoPlugin()
    )
    server.start()
    return server^


def _run(mut server: ApolloServer[NoPlugin], query: String) raises -> String:
    return server.execute_operation(GraphQLRequest(query)).to_json()


def test_construction() raises:
    _ = ApolloServer(
        build_schema(TYPE_DEFS), _resolvers(), ApolloServerOptions(), NoPlugin()
    )
    var raised = False
    try:
        _ = ApolloServer(
            build_schema("type Query { a: String } union U"),
            Resolvers(),
            ApolloServerOptions(),
            NoPlugin(),
        )
    except e:
        raised = True
        assert_equal(
            String(e), "Union type U must define one or more member types."
        )
    assert_true(raised)


def test_error_without_details_by_default() raises:
    var server = _server()
    assert_equal(
        _run(server, "query { error }"),
        '{"errors":[{"message":"A test'
        ' error","locations":[{"line":1,"column":9}],'
        + '"path":["error"],"extensions":{"code":"INTERNAL_SERVER_ERROR"}}],'
        + '"data":{"error":null}}',
    )


def test_error_with_details_in_debug() raises:
    var options = ApolloServerOptions()
    options.include_stacktrace_in_error_responses = True
    var server = _server(options^)
    var response = server.execute_operation(
        GraphQLRequest(String("query { error }"))
    )
    assert_equal(
        response.errors[0].extension("code").value(), '"INTERNAL_SERVER_ERROR"'
    )
    assert_equal(
        response.errors[0].extension("stacktrace").value(),
        '["Error: A test error"]',
    )


def test_works_with_string() raises:
    var server = _server()
    assert_equal(_run(server, "{ hello }"), '{"data":{"hello":"world"}}')


def test_parse_and_validation_errors() raises:
    var server = _server()
    assert_equal(
        _run(server, "{"),
        '{"errors":[{"message":"Syntax Error: Expected Name, found <EOF>.",'
        + '"locations":[{"line":1,"column":2}],"extensions":{"code":'
        + '"GRAPHQL_PARSE_FAILED"}}]}',
    )
    assert_equal(
        _run(server, "{ unknown }"),
        '{"errors":[{"message":"Cannot query field \\"unknown\\" on type'
        + ' \\"Query\\".","locations":[{"line":1,"column":3}],"extensions":'
        + '{"code":"GRAPHQL_VALIDATION_FAILED"}}]}',
    )


def _coerce(
    mut server: ApolloServer[NoPlugin], query: String, variables: String
) raises -> Tuple[Int, String]:
    var request = GraphQLRequest(query)
    if variables.byte_length() > 0:
        request.set_variables(variables)
    var response = server.execute_operation(request^)
    return (response.http.status, response.errors[0].extension("code").value())


def test_variable_coercion_errors() raises:
    var server = _server()
    var result = _coerce(
        server,
        "query NeedsArg($arg: String) { needsStringArg(aString: $arg) }",
        '{"arg":1}',
    )
    assert_equal(result[0], 400)
    assert_equal(result[1], '"BAD_USER_INPUT"')
    var options = ApolloServerOptions()
    options.status400_for_variable_coercion_errors = False
    var lenient = _server(options^)
    result = _coerce(
        lenient,
        "query NeedsArg($arg: String) { needsStringArg(aString: $arg) }",
        '{"arg":1}',
    )
    assert_equal(result[0], 0)


def test_variable_coercion_additional_examples() raises:
    var server = _server()
    var query = (
        "query NeedsArg($arg: CompoundInput!) { needsCompoundArg(aCompound:"
        " $arg) }"
    )
    for variables in [
        '{"arg":{"compound":{"nested1":"abc"}}}',
        '{"arg":{"compound":{"nested1":"abc","nested2":null}}}',
        '{"arg":{"compound":{"nested1":"abc","nested2":123}}}',
        "{}",
        "null",
        "",
    ]:
        var result = _coerce(server, query, String(variables))
        assert_equal(result[0], 400)
        assert_equal(result[1], '"BAD_USER_INPUT"')


def test_max_coercion_errors() raises:
    var options = ApolloServerOptions()
    options.max_coercion_errors = 1
    var server = _server(options^)
    var request = GraphQLRequest(
        String(
            "query NeedsArg($arg: CompoundInput!) { needsCompoundArg(aCompound:"
            " $arg) }"
        )
    )
    request.set_variables(
        '{"arg":{"compound":{"error1":"1","error2":"2","error3":"3"}}}'
    )
    var response = server.execute_operation(request^)
    assert_equal(len(response.errors), 2)
    assert_equal(
        response.errors[0].extension("code").value(), '"BAD_USER_INPUT"'
    )
    assert_equal(
        response.errors[1].extension("code").value(), '"INTERNAL_SERVER_ERROR"'
    )
    assert_true(
        response.errors[1].message.startswith(
            "Too many errors processing variables"
        )
    )
    assert_equal(response.http.status, 400)


def test_context_object() raises:
    var server = _server()
    var options = ExecuteOperationOptions()
    var foo = options.values.add_string("bla")
    options.values.add_member(options.context_value, "foo", foo)
    var response = server.execute_operation(
        GraphQLRequest(String("{ contextFoo }")), options
    )
    assert_equal(response.to_json(), '{"data":{"contextFoo":"bla"}}')


def test_document_store() raises:
    var server = ApolloServer[Recorder].from_type_defs(
        TYPE_DEFS, _resolvers(), ApolloServerOptions(), Recorder()
    )
    _ = server.execute_operation(GraphQLRequest(String("{ hello }")))
    _ = server.execute_operation(GraphQLRequest(String("{ hello }")))
    assert_equal(joined(server.plugin.log).count("validationDidStart"), 1)
    var options = ApolloServerOptions()
    options.document_store = False
    var uncached = ApolloServer[Recorder].from_type_defs(
        TYPE_DEFS, _resolvers(), options^, Recorder()
    )
    _ = uncached.execute_operation(GraphQLRequest(String("{ hello }")))
    _ = uncached.execute_operation(GraphQLRequest(String("{ hello }")))
    assert_equal(joined(uncached.plugin.log).count("validationDidStart"), 2)


def test_disable_validation() raises:
    var options = ApolloServerOptions()
    options.dangerously_disable_validation = True
    var server = _server(options^)
    assert_equal(
        _run(server, "{ unknown hello }"), '{"data":{"hello":"world"}}'
    )


def _many_variables() -> String:
    var vars = String("")
    for index in range(1000):
        vars += ("," if index > 0 else "") + "$a:a"
    return "query aaa (" + vars + ") { a }"


def test_validation_max_errors() raises:
    var server = _server()
    var response = server.execute_operation(GraphQLRequest(_many_variables()))
    assert_equal(response.http.status, 400)
    assert_equal(len(response.errors), 101)
    var options = ApolloServerOptions()
    options.validation_options.max_errors = 1
    var strict = _server(options^)
    response = strict.execute_operation(GraphQLRequest(_many_variables()))
    assert_equal(len(response.errors), 2)
    assert_equal(
        response.errors[0].message, 'There can be only one variable named "$a".'
    )
    assert_equal(
        response.errors[1].message,
        "Too many validation errors, error limit reached. Validation aborted.",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
