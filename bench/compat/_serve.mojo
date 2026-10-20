# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Serve one subgraph of the compatibility suite over HTTP, as
`startStandaloneServer` does in the subgraphs of the suite.

`products.mojo`, `users.mojo` and `inventory.mojo` call `serve_subgraph`.
"""

from std.os import getenv

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

        Raises:
            Error: Never.
        """
        self.subgraph.attach(ctx.values)


def serve_subgraph(
    var subgraph: SubgraphSchema,
    name: String,
    port_variable: StringSlice,
    default_port: Int,
) raises:
    """Serve a subgraph until the process is stopped.

    Args:
        subgraph: The subgraph.
        name: The name of the subgraph, for the ready message.
        port_variable: The environment variable that can set the port.
        default_port: The port when the variable is not set.

    Raises:
        Error: When the server cannot start.
    """
    var schema = subgraph.schema.copy()
    var resolvers = subgraph.resolvers.resolvers.copy()
    var server = ApolloServer[SubgraphPlugin](
        schema^, resolvers^, ApolloServerOptions(), SubgraphPlugin(subgraph^)
    )
    var config = ServerConfig()
    config.port = Int(getenv(String(port_variable), String(default_port)))
    var running = start_standalone_server(server^, config^)
    print(name, "subgraph ready at", running.url, flush=True)
    _ = running.pool.wait()
