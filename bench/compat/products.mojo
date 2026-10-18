# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `products` subgraph of the Apollo Federation subgraph compatibility
suite (f9520a4, MIT), served over HTTP: the Mojo counterpart of
`implementations/apollo-server/index.js`.

`gql_subgraph` builds the subgraph from `tests/gql_subgraph/_products.mojo`,
and the `gql_server` standalone server serves it. The port is 4001, or the
value of `PRODUCTS_PORT`. Run it from the repository root:

    .venv/bin/mojo run -I . -I tests/gql_subgraph bench/compat/products.mojo

This program is not a benchmark. It is in `bench/` because it uses two
packages, and neither one depends on the other.
"""

from std.os import getenv

from _products import build_products
from gql_http.server import ServerConfig
from gql_server.plugin import ServerPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.standalone import start_standalone_server
from gql_server.types import GraphQLRequestContext
from gql_subgraph.build_subgraph_schema import SubgraphSchema


struct SubgraphPlugin(ServerPlugin):
    """A plugin that lets the federation resolvers of a subgraph run in
    the server: it attaches the subgraph to each operation."""

    var subgraph: SubgraphSchema
    """The subgraph that the server serves."""

    def __init__(out self, var subgraph: SubgraphSchema):
        """Hold the subgraph.

        Args:
            subgraph: The subgraph.
        """
        self.subgraph = subgraph^

    def execution_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        """Attach the subgraph to the arena of the operation.

        Args:
            ctx: The request context.
        """
        self.subgraph.attach(ctx.values)


def main() raises:
    """Serve the `products` subgraph until the process is stopped."""
    var subgraph = build_products()
    var schema = subgraph.schema.copy()
    var resolvers = subgraph.resolvers.resolvers.copy()
    var server = ApolloServer[SubgraphPlugin](
        schema^, resolvers^, ApolloServerOptions(), SubgraphPlugin(subgraph^)
    )
    var config = ServerConfig()
    config.port = Int(getenv("PRODUCTS_PORT", "4001"))
    var running = start_standalone_server(server^, config^)
    print("Products subgraph ready at", running.url)
    _ = running.pool.wait()
