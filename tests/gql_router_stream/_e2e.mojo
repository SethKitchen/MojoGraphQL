# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The servers of the end-to-end suites, each in a child process.

The subgraphs follow Hive Router `1a29df9` `bench/subgraphs`: `reviews`
has `reviewAdded` and `reviewAddedForProduct`, with the 11 reviews of
`reviews.rs`, and `products` resolves the `Product` entities of
`products.rs`. `reviews` is a Mojo GraphQL server: `gql_execution` runs
each subscription, over `graphql-transport-ws` with `gql_ws_execution`,
and over SSE or multipart HTTP with `gql_sse_execution` and the
`gql_sse` bodies.
"""

from std.memory import ArcPointer

from _supergraph import sdl
from gql_execution.execute import Resolvers
from gql_execution.value import UNDEFINED, Values
from gql_http.parser import Request
from gql_http.body import BodyPoll
from gql_http.server import Handler, Listener, ResponseWriter, open_listener
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_http.status import Status
from gql_json.parser import parse_bytes
from gql_language.ast import Document, OperationType
from gql_router.exec_http import HttpTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router_stream.config import subscriptions_config_from_json
from gql_router_stream.server import (
    RouterStreamHandler,
    RouterWsHandler,
    router_server_config,
)
from gql_router_stream.subscription import StreamHub
from gql_schema.build import build_schema
from gql_sse.bridge import HeldBodies, MultipartBody, SseBody
from gql_sse.handler import PreparedKind, parse_request
from gql_sse_execution.executor import GraphQLExecution as SseExecution
from gql_sse_execution.executor import Roots
from gql_stream.stream import AnyStream, ListStream
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL, ProtocolMessage
from gql_ws.server import ServerConfig, listen
from gql_http.client import Client
from gql_ws.transport_server import Acknowledgement, TransportServer
from gql_ws_execution.executor import GraphQLExecution as WsExecution, Hooks


comptime REVIEWS_SDL = (
    "type Query { _ignored: String }"
    " type Subscription { reviewAdded(step: Int = 1, intervalInMs: Int ="
    " 1000): Review reviewAddedForProduct(productUpc: String!,"
    " intervalInMs: Int = 1000): Review }"
    " type Review { id: ID! body: String product: Product }"
    " type Product { upc: String! }"
)
"""The schema of the `reviews` subgraph."""


def upcs() -> List[String]:
    """The product of each of the 11 reviews of upstream `reviews.rs`."""
    return ["1", "1", "1", "1", "2", "2", "2", "2", "3", "4", "4"]


def product_name(upc: StringSlice) raises -> String:
    """Return the name of a product of upstream `products.rs`."""
    var names = ["Table", "Couch", "Glass", "Chair", "TV", "Lamp"]
    var index = Int(atol(upc)) - 1
    if index < 0 or index >= len(names):
        return "Unknown"
    return names[index]


def review_events(field: String, product: String = "") -> List[String]:
    """Return the event of each review, as the root value of an event."""
    var UPCS = upcs()
    var events = List[String]()
    for index in range(len(UPCS)):
        if product.byte_length() > 0 and UPCS[index] != product:
            continue
        events.append(
            '{"'
            + field
            + '":{"id":"'
            + String(index + 1)
            + '","body":"Review '
            + String(index + 1)
            + '","product":{"upc":"'
            + UPCS[index]
            + '"}}}'
        )
    return events^


def review_root(
    mut values: Values, document: Document, operation: Int
) raises -> Int:
    """The root of a subscription: a stream of the reviews."""
    if document.operation(operation) != OperationType.SUBSCRIPTION:
        return UNDEFINED
    var text = String(unsafe_from_utf8=Span(document.source.bytes))
    var field = String("reviewAdded")
    var product = String()
    if text.find("reviewAddedForProduct") >= 0:
        field = "reviewAddedForProduct"
        product = "2"
    var root = values.add_object()
    values.add_member(
        root,
        field,
        values.add_stream(
            AnyStream(ListStream.of_json(review_events(field, product)))
        ),
    )
    return root


struct ReviewRoots(Roots):
    """The roots of the SSE side of `reviews`."""

    def __init__(out self):
        pass

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        return review_root(values, document, operation)


struct ReviewHooks(Hooks):
    """The hooks of the WebSocket side of `reviews`."""

    def __init__(out self):
        pass

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        return Acknowledgement(True, String())

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        return review_root(values, document, operation)

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        pass


def _entities(body: Span[UInt8, _]) raises -> String:
    """Answer an `_entities` request of `products`."""
    var document = parse_bytes(List[UInt8](body))
    var variables = document.find(document.root, "variables")
    var reps = document.find(variables, "representations")
    var parts = List[String]()
    for rep in document.children(reps):
        var upc = document.string_value(document.find(rep, "upc"))
        parts.append('{"name":"' + product_name(upc) + '"}')
    return '{"data":{"_entities":[' + ",".join(parts) + "]}}"


struct SubgraphHttp(Handler):
    """The HTTP side of the subgraphs: `products`, and the HTTP streams of
    `reviews`."""

    var reviews: SseExecution[ReviewRoots]
    var multipart: Bool
    var fail_products: Bool
    var fail_reviews: Bool
    var sse: HeldBodies[SseBody]
    var parts: HeldBodies[MultipartBody]

    def __init__(
        out self,
        multipart: Bool = False,
        fail_products: Bool = False,
        fail_reviews: Bool = False,
    ) raises:
        self.reviews = SseExecution(
            build_schema(REVIEWS_SDL), Resolvers(), ReviewRoots()
        )
        self.multipart = multipart
        self.fail_products = fail_products
        self.fail_reviews = fail_reviews
        self.sse = HeldBodies[SseBody]()
        self.parts = HeldBodies[MultipartBody]()

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        if request.path() == "/health":
            return
        if request.path() == "/products":
            response.add_header("Content-Type", "application/json")
            if self.fail_products:
                response.set_status(Status(500))
                response.write_text(
                    '{"errors":[{"message":"Something Went Wrong!"}]}'
                )
                return
            var text = String(unsafe_from_utf8=request.body())
            if text.find("topProducts") >= 0:
                response.write_text(
                    '{"data":{"topProducts":[{"name":"Table","upc":"1"}]}}'
                )
                return
            response.write_text(_entities(request.body()))
            return
        if self.fail_reviews:
            response.set_status(Status(500))
            return
        var outcome = parse_request(request)
        var prepared = self.reviews.prepare(
            request, outcome.params.value(), True
        )
        if prepared.kind != PreparedKind.STREAM:
            response.add_header("Content-Type", "application/json")
            response.write_text(prepared.json)
            return
        if self.multipart:
            response.add_header(
                "Content-Type",
                'multipart/mixed;boundary="graphql";subscriptionSpec=1.0',
            )
        else:
            response.add_header("Content-Type", "text/event-stream")
        response.begin_chunked()
        response.hold()
        var stream = prepared.stream.take()
        if self.multipart:
            self.parts.add(
                response.connection(), MultipartBody(stream^, "graphql")
            )
        else:
            self.sse.add(response.connection(), SseBody(stream^))

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        if self.multipart:
            return self.parts.poll(id, out)
        return self.sse.poll(id, out)

    def body_closed(mut self, id: Int):
        self.parts.drop(id)
        self.sse.drop(id)


@fieldwise_init
struct Child(Movable):
    """A server in a child process, and its port."""

    var pid: Int
    var port: Int

    def stop(self):
        """Kill the child and wait for it."""
        var sys = Sys()
        _ = sys.kill(self.pid, SIGKILL)
        _ = sys.wait(self.pid, True)


def _free_port() raises -> Int:
    """Return a port that no socket listens on now."""
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 64, False)
    sys.close(listener.fd)
    return listener.port


def wait_for(port: Int) raises:
    """Wait until a child answers `/health`."""
    for _ in range(400):
        try:
            var client = Client()
            var response = client.get(
                "http://127.0.0.1:" + String(port) + "/health"
            )
            if response.status.code == 200:
                return
        except:
            pass
        var sys = Sys()
        _ = sys.poll(-1, 0, 5)
    raise Error("the child did not start")


def start_subgraphs(
    multipart: Bool = False,
    fail_products: Bool = False,
    fail_reviews: Bool = False,
) raises -> Child:
    """Run the subgraphs in a child for at most five seconds."""
    var port = _free_port()
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            var config = ServerConfig()
            config.http.port = port
            config.path = "/reviews"
            config.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
            var executor = WsExecution(
                build_schema(REVIEWS_SDL), Resolvers(), ReviewHooks()
            )
            var ws = TransportServer(executor^)
            var http = SubgraphHttp(multipart, fail_products, fail_reviews)
            var server = listen(ws^, http^, config)
            for _ in range(5000):
                _ = server.poll(1)
        except:
            pass
        sys.exit_now(0)
    wait_for(port)
    return Child(pid, port)


def start_router(subgraphs: Int, config_json: String) raises -> Child:
    """Run the router in a child for at most five seconds."""
    var port = _free_port()
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            var schema = RouterSchema(
                sdl("http://127.0.0.1:" + String(subgraphs))
            )
            var transport = HttpTransport(
                schema.subgraph_names, schema.subgraph_urls
            )
            var hub = ArcPointer(
                StreamHub(
                    Router(schema^, transport^),
                    subscriptions_config_from_json(config_json),
                )
            )
            var config = ServerConfig()
            config.http.port = port
            config = router_server_config(hub[].config, config^, "/graphql")
            var ws = RouterWsHandler(hub)
            var http = RouterStreamHandler(hub)
            var server = listen(ws^, http^, config)
            for _ in range(5000):
                _ = server.poll(1)
        except e:
            print("router child failed:", e)
        sys.exit_now(0)
    wait_for(port)
    return Child(pid, port)
