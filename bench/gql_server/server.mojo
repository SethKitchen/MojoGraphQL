# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time `ApolloServer.execute_operation` against Apollo Server 5.5.1.

    mojo build -I . -o .cache/bin/server bench/gql_server/server.mojo
    .cache/bin/server

- `server/execute-operation-small`: `execute_operation` of `{ hello }`,
  with the request pipeline, the document store and the cache control
  header, as upstream `server.executeOperation({query})`.
- `server/apq-hit`: the same operation sent as an automatic persisted
  query with only its SHA-256 hash, after the query is registered.
- `server/execute-ftv1`: `execute_operation` of `{ books { title author
  } }`, with 10 books, the HTTP header `apollo-federation-include-trace:
  ftv1` and the inline trace plugin, as upstream
  `ApolloServerPluginInlineTrace()`. The response has `extensions.ftv1`,
  the base64 of a trace of 21 fields.

The baseline is `bench/baselines/js-server/bench.mjs`. Both servers use
`node_env` `production`.
"""

from _harness import Workload, measure
from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_server.http_types import HTTPGraphQLRequest
from gql_server.inline_trace import InlineTraceOptions
from gql_server.plugin import NoPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.sha256 import sha256_hex
from gql_server.types import GraphQLRequest

comptime QUERY = "{ hello }"
"""The operation."""


def hello(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Resolve `Query.hello`."""
    return values.add_string("world")


def make_server() raises -> ApolloServer[NoPlugin]:
    """The server of the benchmark: `type Query { hello: String }`."""
    var resolvers = Resolvers()
    resolvers.field("Query", "hello", hello)
    var options = ApolloServerOptions()
    options.node_env = String("production")
    var server = ApolloServer.from_type_defs(
        "type Query { hello: String }", resolvers^, options^, NoPlugin()
    )
    server.start()
    return server^


struct ExecuteOperation(Workload):
    """`server/execute-operation-small`."""

    var server: ApolloServer[NoPlugin]

    def __init__(out self) raises:
        self.server = make_server()

    def run(mut self) raises -> Int:
        var response = self.server.execute_operation(GraphQLRequest(QUERY))
        return response.data.length(response.data.root)


struct ApqHit(Workload):
    """`server/apq-hit`."""

    var server: ApolloServer[NoPlugin]
    var extensions: String

    def __init__(out self) raises:
        self.server = make_server()
        self.extensions = (
            '{"persistedQuery":{"version":1,"sha256Hash":"'
            + sha256_hex(QUERY)
            + '"}}'
        )
        var register = GraphQLRequest(QUERY)
        register.set_extensions(self.extensions)
        _ = self.server.execute_operation(register^)

    def run(mut self) raises -> Int:
        var request = GraphQLRequest()
        request.set_extensions(self.extensions)
        var response = self.server.execute_operation(request^)
        if response.has_errors:
            raise Error("the persisted query was not found")
        return response.data.length(response.data.root)


comptime BOOKS_QUERY = "{ books { title author } }"
"""The operation of `server/execute-ftv1`."""


def books(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Resolve `Query.books`: 10 books."""
    var list = values.add_list()
    for _ in range(10):
        var book = values.add_object()
        values.add_member(book, "title", values.add_string("Title"))
        values.add_member(book, "author", values.add_string("Author"))
        values.append(list, book)
    return list


struct ExecuteFtv1(Workload):
    """`server/execute-ftv1`."""

    var server: ApolloServer[NoPlugin]

    def __init__(out self) raises:
        var resolvers = Resolvers()
        resolvers.field("Query", "books", books)
        var options = ApolloServerOptions()
        options.node_env = String("production")
        options.inline_trace = InlineTraceOptions()
        self.server = ApolloServer.from_type_defs(
            (
                "type Query { books: [Book] } type Book { title: String author:"
                " String }"
            ),
            resolvers^,
            options^,
            NoPlugin(),
        )
        self.server.start()

    def run(mut self) raises -> Int:
        var request = GraphQLRequest(BOOKS_QUERY)
        var http = HTTPGraphQLRequest("POST")
        http.headers.set("apollo-federation-include-trace", "ftv1")
        request.http = http^
        var response = self.server.execute_operation(request^)
        if not response.extensions:
            raise Error("the response has no extensions.ftv1")
        return response.extensions.value().byte_length()


def main() raises:
    """Run the workloads."""
    measure("server/execute-operation-small", ExecuteOperation())
    measure("server/apq-hit", ApqHit())
    measure("server/execute-ftv1", ExecuteFtv1())
