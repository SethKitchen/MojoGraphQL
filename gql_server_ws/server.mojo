# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Subscriptions over WebSocket for an Apollo Server, on the port of its
HTTP server.

`start_server_ws` serves an `ApolloServer` on one port. A request with
`Upgrade: websocket` on `ServerConfig.path` becomes a graphql-transport-ws
connection: gql_ws_execution parses, validates and runs each operation
against the schema and the resolvers of the server, and each event of a
subscription is a `next`. Any other request goes to the standalone handler
of gql_server: CORS, the JSON body, `execute_http_graphql_request`, and
the held `multipart/mixed` responses of `@defer` and `@stream`.

`ApolloWsServer.stop` drains both protocols. Each WebSocket closes with
1001, each HTTP connection finishes its response, and then the
`server_will_stop` hooks of the plugins run.

This module ports the setup of Apollo Server 5.5.1
`docs/source/data/subscriptions.mdx`: `useServer({ schema }, wsServer)` of
graphql-ws on the `http.Server` of Apollo Server, with
`ApolloServerPluginDrainHttpServer` (`plugin/drainHttpServer/index.ts`)
and a plugin whose `drainServer` calls `serverCleanup.dispose()`.

Differences from upstream:
- The drain is `ApolloWsServer.stop`, not two plugins with
  `drainServer`: the plugin trait of gql_server has no `drainServer`.
  The order is that of upstream `stop`: the drain, then
  `serverWillStop`.
- As upstream, the plugins of the request pipeline do not run for
  WebSocket operations: graphql-ws runs `execute` and `subscribe` on the
  schema. `Hooks` of gql_ws_execution take the place of the `onConnect`,
  `roots` and `onClose` options of `useServer`.
- The `subscriptionCallback` plugin (`plugin/subscriptionCallback`), the
  HTTP callback protocol of the Apollo Router, is not ported. It needs an
  HTTP client that posts each event and a heartbeat timer, and it serves
  a router, not a WebSocket client.
- Execution is synchronous, in the one loop of gql_ws: the server runs in
  the process that calls it, not in gql_http worker processes.
"""

from std.time import perf_counter_ns

from gql_http.error import HttpError
from gql_server.plugin import ServerPlugin
from gql_server.server import ApolloServer, ContextFunction, default_context
from gql_server.standalone import MAX_BODY_BYTES, StandaloneHandler
from gql_server.subscription_callback import (
    SubscriptionCallbackOptions,
    SubscriptionCallbackPlugin,
)
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.server import Server, ServerConfig, listen
from gql_ws.transport_server import TransportOptions, TransportServer
from gql_ws_execution.executor import GraphQLExecution, Hooks


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


struct ApolloWsServer[P: ServerPlugin, K: Hooks](Movable):
    """A running Apollo Server with HTTP and WebSocket on one port.

    Parameters:
        P: The type of the plugins.
        K: The type of the hooks of the WebSocket operations.
    """

    var loop: Server[
        TransportServer[GraphQLExecution[Self.K]], StandaloneHandler[Self.P]
    ]
    """The event loop of both protocols."""
    var url: String
    """The URL of the server, such as `http://localhost:4000/`."""

    def __init__(
        out self,
        var loop: Server[
            TransportServer[GraphQLExecution[Self.K]], StandaloneHandler[Self.P]
        ],
    ):
        """Hold a running loop.

        Args:
            loop: The loop.
        """
        self.loop = loop^
        self.url = "http://localhost:" + String(self.loop.port) + "/"

    def port(self) -> Int:
        """Return the local port.

        Returns:
            The port of both protocols.
        """
        return self.loop.port

    def server(
        mut self,
    ) -> ref[self.loop.http1.handler.server] ApolloServer[Self.P]:
        """Return the Apollo Server.

        Returns:
            The server of the HTTP requests, with its plugins.
        """
        return self.loop.http1.handler.server

    def poll(mut self, timeout_ms: Int) raises -> Int:
        """Run one turn of the loop.

        Args:
            timeout_ms: The longest wait for an event; -1 for no limit.

        Returns:
            What `gql_ws.server.Server.poll` returns.

        Raises:
            Error: When `epoll_wait` fails, or the transport fails.
        """
        return self.loop.poll(timeout_ms)

    def stopped(self) -> Bool:
        """Return True when a drain has ended.

        Returns:
            Whether no connection is open after `begin_shutdown`.
        """
        return self.loop.stopped()

    def begin_shutdown(mut self):
        """Begin the drain: stop accepting, close each WebSocket with 1001,
        and let each HTTP response finish."""
        self.loop.begin_shutdown()

    def run(mut self) raises:
        """Run the loop until a drain ends, then stop the Apollo Server.

        Call `listen_signals` first to begin the drain on `SIGTERM` or
        `SIGINT`, as `stopOnTerminationSignals` of upstream.

        Raises:
            Error: The errors of the loop, and of `server_will_stop`.
        """
        self.loop.run()
        self.server().stop()

    def listen_signals(mut self) raises HttpError:
        """Begin the drain on `SIGTERM` or `SIGINT`.

        Raises:
            HttpError: `OS` when the `signalfd` cannot be opened or watched.
        """
        self.loop.listen_signals()

    def stop(mut self, timeout_ms: Int = 10000) raises:
        """Drain, then stop the Apollo Server: upstream `stop` with
        `ApolloServerPluginDrainHttpServer` and `serverCleanup.dispose()`.

        A connection that is still open at the end of `timeout_ms` is
        closed, as `stopGracePeriodMillis` of upstream, 10 seconds at
        first.

        Args:
            timeout_ms: How long the drain can take.

        Raises:
            Error: The errors of the loop, and of `server_will_stop`.
        """
        self.loop.begin_shutdown()
        var deadline = _now_ms() + timeout_ms
        while not self.loop.stopped() and _now_ms() < deadline:
            _ = self.loop.poll(10)
        if not self.loop.stopped():
            self.loop.close()
        self.server().stop()


def start_server_ws[
    P: ServerPlugin, K: Hooks
](
    var server: ApolloServer[P],
    var hooks: K,
    var config: ServerConfig = ServerConfig(),
    context: ContextFunction = default_context,
    options: TransportOptions = TransportOptions(),
) raises -> ApolloWsServer[P, K]:
    """Start an Apollo Server, and serve it over HTTP and over
    graphql-transport-ws on one port.

    Parameters:
        P: The type of the plugins.
        K: The type of the hooks.

    Args:
        server: The server; it must not be started.
        hooks: The hooks of the WebSocket operations.
        config: The configuration; port 4000 and every path by default.
            The body limit becomes 50 MiB, as the standalone server. With
            no subprotocol, the server offers `graphql-transport-ws`.
        context: The context function of the HTTP requests.
        options: The options of the graphql-transport-ws transport.

    Returns:
        The running server.

    Raises:
        Error: When the server cannot start, or the port cannot be opened.
    """
    server.start()
    config.http.limits.max_body_bytes = MAX_BODY_BYTES
    if len(config.protocols) == 0:
        config.protocols.append(String(GRAPHQL_TRANSPORT_WS_PROTOCOL))
    var executor = GraphQLExecution(
        server.internals.schema.copy(),
        server.internals.resolvers.copy(),
        hooks^,
    )
    var loop = listen(
        TransportServer(executor^, options),
        StandaloneHandler[P](server^, context),
        config,
    )
    return ApolloWsServer[P, K](loop^)
