# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time incremental delivery over `multipart/mixed` against Apollo Server
5.5.1 with graphql-js 17.0.0-alpha.9.

    mojo build -I . -o .cache/bin/si bench/gql_server/incremental.mojo
    .cache/bin/si

- `server/defer-multipart`: `execute_http_graphql_request` of a `POST` of
  `{ books { title ... @defer { author } } }`, with 10 books and
  `accept: multipart/mixed; incrementalSpec=v0.2`, then every part of the
  `multipart/mixed` body. Upstream runs `executeHTTPGraphQLRequest` and
  reads each chunk of its `asyncIterator`.

The baseline is `bench/baselines/js-server/incremental/bench.mjs`. Both
servers use `node_env` `production`.
"""

from _harness import Workload, measure
from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_http.body import BodyPoll
from gql_json.parser import parse as parse_json
from gql_server.http_types import HTTPGraphQLRequest
from gql_server.plugin import NoPlugin
from gql_server.server import ApolloServer, ApolloServerOptions

comptime SDL = """
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT
type Query { books: [Book] }
type Book { title: String author: String }
"""
"""The schema, with the `@defer` definition of graphql-js 17."""

comptime BODY = '{"query":"{ books { title ... @defer { author } } }"}'
"""The content of the request."""


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


struct DeferMultipart(Workload):
    """`server/defer-multipart`."""

    var server: ApolloServer[NoPlugin]

    def __init__(out self) raises:
        var resolvers = Resolvers()
        resolvers.field("Query", "books", books)
        var options = ApolloServerOptions()
        options.node_env = String("production")
        self.server = ApolloServer.from_type_defs(
            SDL, resolvers^, options^, NoPlugin()
        )
        self.server.start()

    def run(mut self) raises -> Int:
        var request = HTTPGraphQLRequest("POST")
        request.headers.set("content-type", "application/json")
        request.headers.set("accept", "multipart/mixed; incrementalSpec=v0.2")
        request.body = parse_json(BODY)
        var response = self.server.execute_http_graphql_request(request^)
        if not response.chunks:
            raise Error("not incremental: " + response.body)
        var length = response.body.byte_length()
        var chunks = response.chunks.value()
        var out = List[UInt8]()
        while True:
            out.clear()
            var result = self.server.poll_chunk(chunks, out)
            length += len(out)
            if result == BodyPoll.DONE:
                return length
            if result == BodyPoll.ERROR:
                raise Error("the body failed")


def main() raises:
    """Run the workload and print its `BENCH` line."""
    measure("server/defer-multipart", DeferMultipart())
