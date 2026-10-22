# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Shared fixtures of the `gql_scorchql` tests: two subgraph SDLs, a fake
subgraph server that serves HTTP, SSE and WebSocket subscriptions, and a
fresh registry directory for each test."""

from std.os import getenv
from std.time import perf_counter_ns

from gql_http.parser import Request
from gql_http.server import (
    Handler,
    ResponseWriter,
    ServerConfig,
    WorkerPool,
    open_listener,
)
from gql_http.socket import IPv4Address, Sys
from gql_json.parser import parse_bytes
from gql_json.value import JsonKind
from gql_scorchql.introspect import SERVICE_QUERY
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.protocol import Message
from gql_ws.server import ServerConfig as WsServerConfig
from gql_ws.server import Sockets, WsHandler, listen

comptime PRODUCTS_SDL = """extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key"])

type Query {
  products: [Product!]!
}

type Product @key(fields: "id") {
  id: ID!
  name: String!
}
"""

comptime REVIEWS_SDL = """extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key"])

type Subscription {
  reviewAdded: Review!
}

type Product @key(fields: "id") {
  id: ID!
  rating: Int!
}

type Review {
  id: ID!
  body: String!
  product: Product!
}
"""

comptime CONFLICT_SDL = """extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key"])

type Query {
  products: Int
}
"""

comptime PRODUCTS_DATA = (
    '{"data":{"products":[{"__typename":"Product","id":"1","name":"Torch"}]}}'
)
comptime PRODUCTS_ENTITIES = '{"data":{"_entities":[{"name":"Torch"}]}}'
comptime REVIEWS_DATA = '{"data":{"_entities":[{"rating":5}]}}'
comptime REVIEW_PAYLOAD = (
    '{"data":{"reviewAdded":{"id":"r1","body":"Hot!","product":'
    '{"__typename":"Product","id":"1"}}}}'
)
comptime REVIEW_SSE = "event: next\ndata: " + REVIEW_PAYLOAD + "\n\nevent: complete\n\n"


def fresh_directory(name: String) -> String:
    """Return a registry directory that no other test uses."""
    return (
        getenv("TMPDIR", "/tmp")
        + "/scorchql_"
        + name
        + "_"
        + String(perf_counter_ns())
    )


def loopback() -> ServerConfig:
    """Return a server configuration on a free loopback port."""
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.workers = 1
    return config^


def _escaped(sdl: String) -> String:
    """Write an SDL as the content of a JSON string."""
    return sdl.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


struct FakeWsSubgraph(WsHandler):
    """Answers `graphql-transport-ws` on `/reviews` with one `reviewAdded`
    event and `complete`."""

    def __init__(out self):
        pass

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        pass

    def on_message(
        mut self, mut sockets: Sockets, id: Int, message: Message
    ) raises:
        var text = String(message.text())
        if '"connection_init"' in text:
            _ = sockets.send_text(id, '{"type":"connection_ack"}')
        elif '"subscribe"' in text:
            var doc = parse_bytes(List[UInt8](text.as_bytes()))
            var op_id = doc.string_value(doc.find(doc.root, "id"))
            _ = sockets.send_text(
                id,
                '{"id":"'
                + op_id
                + '","type":"next","payload":'
                + REVIEW_PAYLOAD
                + "}",
            )
            _ = sockets.send_text(
                id, '{"id":"' + op_id + '","type":"complete"}'
            )

    def on_close(
        mut self, mut sockets: Sockets, id: Int, code: UInt16, reason: String
    ):
        pass

    def on_tick(mut self, mut sockets: Sockets) raises:
        pass

    def fd(self) -> Int:
        return -1

    def wait_ms(self) -> Int:
        return -1


struct FakeSubgraphs(Handler):
    """Answers as `products` on `/products` and `reviews` on `/reviews`:
    the SDL query, entity queries, root queries and SSE subscriptions.
    `/broken` answers the SDL query with an error, and `/bad` with a
    conflicting SDL."""

    def __init__(out self):
        """Make the handler."""
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one request.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: When the response cannot be written.
        """
        var path = request.path()
        if path == "/health":
            return
        var body = List[UInt8](request.body())
        var is_service = String(StringSlice(unsafe_from_utf8=Span(body))) == (
            SERVICE_QUERY
        )
        var document = parse_bytes(body^)
        var query = document.find(document.root, "query")
        var text = String("")
        if query >= 0 and document.kind(query) == JsonKind.STRING:
            text = document.string_value(query)
        if path == "/broken":
            response.add_header("Content-Type", "application/json")
            response.write_text('{"errors":[{"message":"down for repair"}]}')
            return
        if is_service:
            response.add_header("Content-Type", "application/json")
            var sdl = PRODUCTS_SDL
            if path == "/reviews":
                sdl = REVIEWS_SDL
            elif path == "/bad":
                sdl = CONFLICT_SDL
            response.write_text(
                '{"data":{"_service":{"sdl":"' + _escaped(sdl) + '"}}}'
            )
            return
        if "reviewAdded" in text:
            response.add_header("Content-Type", "text/event-stream")
            response.write_text(REVIEW_SSE)
            return
        response.add_header("Content-Type", "application/json")
        if "_entities" in text:
            if path == "/products":
                response.write_text(PRODUCTS_ENTITIES)
            else:
                response.write_text(REVIEWS_DATA)
        else:
            response.write_text(PRODUCTS_DATA)


def start_fake_subgraphs() raises -> WorkerPool:
    """Start `FakeSubgraphs` with both HTTP and `graphql-transport-ws`
    WebSocket on `/reviews` in one worker process."""
    var config = WsServerConfig()
    config.http = loopback()
    config.path = "/reviews"
    config.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
    var server = listen(FakeWsSubgraph(), FakeSubgraphs(), config)
    var port = server.port
    var sys = Sys()
    var parent = sys.pid()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        if sys.parent_pid() != parent:
            sys.exit_now(1)
        try:
            try:
                server.listen_signals()
            except:
                pass
            server.run()
        except:
            pass
        sys.exit_now(0)
    server.close()
    var pids = List[Int]()
    pids.append(pid)
    return WorkerPool(pids^, port)
