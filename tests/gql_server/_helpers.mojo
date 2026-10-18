# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_server tests: the schema of the Apollo Server 5.5.1
integration test suite (`packages/integration-testsuite/src/
httpServerTests.ts`) in SDL with Mojo resolvers, and HTTP requests.

The expected responses of the tests come from Apollo Server 5.5.1 itself,
run in Node.js with the same schema, resolvers and requests through
`startStandaloneServer`.
"""

from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import UNDEFINED, ValueKind, Values
from gql_json.parser import parse as parse_json
from gql_language.ast import Document
from gql_server.http_types import HTTPGraphQLRequest, HTTPGraphQLResponse
from gql_server.plugin import NoPlugin, ServerPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from std.testing import assert_equal

comptime SDL = """
type QueryType {
  testString: String
  testPerson: PersonType
  testContext: String
  testRootValue: String
  testArgument(echo: String): String
  testError: String
  testInt(n: Int!): Int
}
type PersonType { firstName: String lastName: String }
type MutationType {
  testMutation(echo: String): String
  testPerson(firstName: String!, lastName: String!): PersonType
  testRootValue: String
}
schema { query: QueryType mutation: MutationType }
"""
"""The schema: the `queryType` and `mutationType` of upstream, and
`testInt` for variable coercion."""


def test_string(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testString`: `it works`."""
    return values.add_string("it works")


def test_person(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`QueryType.testPerson`: Jane Doe."""
    var person = values.add_object()
    values.add_member(person, "firstName", values.add_string("Jane"))
    values.add_member(person, "lastName", values.add_string("Doe"))
    return person


def test_context(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testContext`: `context.testField`, once per context object."""
    if values.get(info.context_value, "otherField") != UNDEFINED:
        return values.add_string("unexpected")
    values.set(info.context_value, "otherField", values.add_bool(True))
    return values.get(info.context_value, "testField")


def test_root_value(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testRootValue`: the root value."""
    return info.root_value


def test_argument(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testArgument`: `hello ${echo}`."""
    var echo = values.get(args, "echo")
    return values.add_string("hello " + String(values.string(echo)))


def test_error(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testError`: throws `Secret error message`."""
    raise Error("Secret error message")


def test_int(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testInt`: its argument."""
    return values.get(args, "n")


def test_mutation(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`testMutation`: not really a mutation."""
    var echo = values.get(args, "echo")
    return values.add_string(
        "not really a mutation, but who cares: " + String(values.string(echo))
    )


def mutation_person(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`MutationType.testPerson`: its arguments."""
    return args


def resolvers() -> Resolvers:
    """The resolvers of the schema."""
    var out = Resolvers()
    out.field("QueryType", "testString", test_string)
    out.field("QueryType", "testPerson", test_person)
    out.field("QueryType", "testContext", test_context)
    out.field("QueryType", "testRootValue", test_root_value)
    out.field("QueryType", "testArgument", test_argument)
    out.field("QueryType", "testError", test_error)
    out.field("QueryType", "testInt", test_int)
    out.field("MutationType", "testMutation", test_mutation)
    out.field("MutationType", "testPerson", mutation_person)
    out.field("MutationType", "testRootValue", test_root_value)
    return out^


def root_value(mut values: Values, document: Document) raises -> Int:
    """The root value of the tests: `it also works`."""
    return values.add_string("it also works")


def context(mut values: Values, request: HTTPGraphQLRequest) raises -> Int:
    """The context of the tests: `{testField: 'context works'}`."""
    var out = values.add_object()
    values.add_member(out, "testField", values.add_string("context works"))
    return out


def failing_context(
    mut values: Values, request: HTTPGraphQLRequest
) raises -> Int:
    """A context function that throws `boom`."""
    raise Error("boom")


def options() -> ApolloServerOptions:
    """The options of the tests: `nodeEnv: 'test'` and the root value."""
    var out = ApolloServerOptions()
    out.node_env = String("test")
    out.root_value = root_value
    return out^


def make_server(var opts: ApolloServerOptions) raises -> ApolloServer[NoPlugin]:
    """A started server with the schema and some options."""
    var server = ApolloServer.from_type_defs(
        SDL, resolvers(), opts^, NoPlugin()
    )
    server.start()
    return server^


def make_server() raises -> ApolloServer[NoPlugin]:
    """A started server with the test options."""
    return make_server(options())


def http_request(
    method: String, search: String, headers: List[String], body: String
) raises -> HTTPGraphQLRequest:
    """Make an HTTP request.

    Args:
        method: The method.
        search: The query string, with its `?`, or empty.
        headers: The names and the values of the fields, in turn.
        body: The JSON content, or empty for none.
    """
    var out = HTTPGraphQLRequest(method)
    out.search = search
    var index = 0
    while index + 1 < len(headers):
        out.headers.set(headers[index], headers[index + 1])
        index += 2
    if body.byte_length() > 0:
        out.body = parse_json(body)
    return out^


def json_post(body: String) raises -> HTTPGraphQLRequest:
    """A `POST` of JSON content with `content-type: application/json`."""
    var headers: List[String] = ["content-type", "application/json"]
    return http_request("POST", "", headers, body)


def preflight_get(search: String) raises -> HTTPGraphQLRequest:
    """A `GET` with `apollo-require-preflight: t`."""
    var headers: List[String] = ["apollo-require-preflight", "t"]
    return http_request("GET", search, headers, "")


def run[
    P: ServerPlugin
](
    mut server: ApolloServer[P], var request: HTTPGraphQLRequest
) raises -> HTTPGraphQLResponse:
    """Answer a request with the context of the tests."""
    return server.execute_http_graphql_request(request^, context)


def check(
    response: HTTPGraphQLResponse,
    status: Int,
    cache_control: String,
    body: String,
    content_type: String = "application/json; charset=utf-8",
    final_newline: Bool = True,
) raises:
    """Check a response as the standalone server of upstream sends it.

    Args:
        response: The response.
        status: The status; 0 stands for 200.
        cache_control: The `cache-control` field, or empty for none.
        body: The content, without the final newline.
        content_type: The `content-type` field.
        final_newline: Whether the content ends with a newline; a batch
            does not.
    """
    assert_equal(response.status, status)
    assert_equal(
        response.headers.get("content-type").or_else("-"), content_type
    )
    assert_equal(
        response.headers.get("cache-control").or_else(""), cache_control
    )
    assert_equal(response.body, body + ("\n" if final_newline else ""))


def error_body(message: String, code: String) -> String:
    """The content of a response with one error without a location."""
    return (
        '{"errors":[{"message":"'
        + message
        + '","extensions":{"code":"'
        + code
        + '"}}]}'
    )
