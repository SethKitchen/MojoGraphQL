# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The ScorchQL demo: two federated subgraphs for a gateway to front.

`products` serves the catalog of a fire gear shop on port 4001, and
`reviews` serves the reviews of each product, and a `reviewAdded`
subscription, on port 4002. `gql_subgraph` builds each subgraph, and
`gql_server_ws` serves it over HTTP and `graphql-transport-ws` WebSocket.
`Product` is an entity in both subgraphs, and `Review.product` points back
into `products`, so a query plan or subscription has entity fetches in
both directions.

    make scorchql
    dist/scorchql-demo &
    dist/scorchql --config examples/scorchql/supergraph.yaml

`PRODUCTS_PORT` and `REVIEWS_PORT` change the ports. The program runs
until it gets `SIGINT` or `SIGTERM`.
"""

from std.os import getenv

from gql_execution.execute import ResolveInfo
from gql_execution.value import UNDEFINED, ValueKind, Values
from gql_http.server import ServerConfig, WorkerPool
from gql_http.socket import Sys
from gql_language.ast import Document, OperationType
from gql_language.parser import parse
from gql_server.plugin import ServerPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.types import GraphQLRequestContext
from gql_server_ws.server import start_server_ws
from gql_stream.stream import AnyStream, ListStream
from gql_subgraph.build_subgraph_schema import (
    SchemaModule,
    SubgraphResolvers,
    SubgraphSchema,
    build_subgraph_schema,
)
from gql_ws.graphql_ws import ProtocolMessage
from gql_ws.server import ServerConfig as WsServerConfig
from gql_ws.transport_server import Acknowledgement
from gql_ws_execution.executor import Hooks

comptime PRODUCTS_SDL = """extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key", "@shareable"])

"A fire gear shop."
type Query {
  "Every product in the catalog."
  products: [Product!]!
  "One product, by its id."
  product(id: ID!): Product
}

"Something the shop sells."
type Product @key(fields: "id") {
  id: ID!
  "The display name."
  name: String!
  "The price, in US dollars."
  price: Float!
  "How hot it burns, from 1 to 10."
  heatRating: Int!
  category: Category!
}

"The shelf a product is on."
enum Category {
  TORCHES
  FUEL
  SAFETY
}
"""
"""The SDL of the `products` subgraph."""

comptime REVIEWS_SDL = """extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key"])

type Query {
  "The newest reviews, newest first."
  latestReviews: [Review!]!
}

type Subscription {
  "Each customer review in turn."
  reviewAdded: Review!
}

type Product @key(fields: "id") {
  id: ID!
  "What customers say about the product."
  reviews: [Review!]!
  "The mean rating, or null when there are no reviews."
  averageRating: Float
}

"One customer review."
type Review {
  id: ID!
  "From 1 to 5 flames."
  rating: Int!
  body: String!
  author: String!
  product: Product!
}
"""
"""The SDL of the `reviews` subgraph."""

comptime _PRODUCT_COUNT = 4

# id, name, category, price, heat rating.
comptime _PRODUCTS: Array[StaticString, 20] = [
    "1",
    "Ember Torch",
    "TORCHES",
    "49.99",
    "7",
    "2",
    "Inferno Fuel Canister",
    "FUEL",
    "12.5",
    "9",
    "3",
    "Phoenix Fire Blanket",
    "SAFETY",
    "24",
    "1",
    "4",
    "Blaze Pocket Lighter",
    "TORCHES",
    "8.75",
    "4",
]

comptime _REVIEW_COUNT = 5

# id, product id, rating, author, body.
comptime _REVIEWS: Array[StaticString, 25] = [
    "r1",
    "1",
    "5",
    "Ash",
    "Lit the campfire in one try.",
    "r2",
    "1",
    "4",
    "Cinder",
    "Hot, bright and a bit heavy.",
    "r3",
    "2",
    "5",
    "Flint",
    "Burns clean and long.",
    "r4",
    "3",
    "5",
    "Sparky",
    "Put out a pan fire in seconds.",
    "r5",
    "4",
    "3",
    "Ash",
    "Works, but the flame is small.",
]


def _product_field(index: Int, column: Int) -> StaticString:
    """Return a column of a product row."""
    return materialize[_PRODUCTS]()[index * 5 + column]


def _review_field(index: Int, column: Int) -> StaticString:
    """Return a column of a review row."""
    return materialize[_REVIEWS]()[index * 5 + column]


def _string(mut values: Values, object: Int, key: String, text: StringSlice):
    """Add a string member to an object."""
    values.add_member(object, key, values.add_string(text))


def _number(mut values: Values, object: Int, key: String, text: StringSlice):
    """Add a number member, from its text, to an object."""
    var number: Float64 = 0
    try:
        number = atof(text)
    except:
        pass
    values.add_member(object, key, values.add_number(number))


def _find_product(values: Values, id: Int) -> Int:
    """Return the row of the product whose id is the value `id`, or -1."""
    if values.kind(id) != ValueKind.STRING:
        return -1
    for index in range(_PRODUCT_COUNT):
        if values.string(id) == _product_field(index, 0):
            return index
    return -1


def _product(mut values: Values, index: Int) -> Int:
    """Make the `products` object of a row, or `null` for -1."""
    if index < 0:
        return values.add_null()
    var product = values.add_object()
    _string(values, product, "id", _product_field(index, 0))
    _string(values, product, "name", _product_field(index, 1))
    _string(values, product, "category", _product_field(index, 2))
    _number(values, product, "price", _product_field(index, 3))
    _number(values, product, "heatRating", _product_field(index, 4))
    return product


def _query_products(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Query.products`: every product."""
    var out = values.add_list()
    for index in range(_PRODUCT_COUNT):
        values.append(out, _product(values, index))
    return out


def _query_product(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Query.product`: the product with the `id`, or `null`."""
    return _product(values, _find_product(values, values.get(args, "id")))


def _product_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """`Product.__resolveReference` of `products`: by `id`."""
    return _product(values, _find_product(values, values.get(reference, "id")))


def products_resolvers() -> SubgraphResolvers:
    """Return the resolvers of the `products` subgraph.

    Returns:
        The resolver map.
    """
    var resolvers = SubgraphResolvers()
    resolvers.field("Query", "products", _query_products)
    resolvers.field("Query", "product", _query_product)
    resolvers.resolve_reference("Product", _product_reference)
    return resolvers^


def _review(mut values: Values, index: Int) -> Int:
    """Make the object of a review row; its product is a reference."""
    var review = values.add_object()
    _string(values, review, "id", _review_field(index, 0))
    _number(values, review, "rating", _review_field(index, 2))
    _string(values, review, "author", _review_field(index, 3))
    _string(values, review, "body", _review_field(index, 4))
    var product = values.add_object()
    _string(values, product, "id", _review_field(index, 1))
    values.add_member(review, "product", product)
    return review


def _review_events() -> List[String]:
    """Return the JSON root values of the `reviewAdded` subscription."""
    var events = List[String]()
    for index in range(_REVIEW_COUNT):
        events.append(
            '{"reviewAdded":{"id":"'
            + String(_review_field(index, 0))
            + '","rating":'
            + String(_review_field(index, 2))
            + ',"author":"'
            + String(_review_field(index, 3))
            + '","body":"'
            + String(_review_field(index, 4))
            + '","product":{"id":"'
            + String(_review_field(index, 1))
            + '"}}}'
        )
    return events^


def _latest_reviews(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Query.latestReviews`: every review, newest first."""
    var out = values.add_list()
    var index = _REVIEW_COUNT - 1
    while index >= 0:
        values.append(out, _review(values, index))
        index -= 1
    return out


def _reviews_of(mut values: Values, id: Int) -> Int:
    """Make the list of the reviews of a product id."""
    var out = values.add_list()
    if values.kind(id) != ValueKind.STRING:
        return out
    for index in range(_REVIEW_COUNT):
        if values.string(id) == _review_field(index, 1):
            values.append(out, _review(values, index))
    return out


def _product_reviews(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Product.reviews`: the reviews of the product."""
    return _reviews_of(values, values.get(source, "id"))


def _average_rating(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """`Product.averageRating`: the mean rating, or `null`."""
    var id = values.get(source, "id")
    if values.kind(id) != ValueKind.STRING:
        return values.add_null()
    var total: Float64 = 0
    var count = 0
    for index in range(_REVIEW_COUNT):
        if values.string(id) == _review_field(index, 1):
            try:
                total += atof(_review_field(index, 2))
            except:
                pass
            count += 1
    if count == 0:
        return values.add_null()
    return values.add_number(total / Float64(count))


def _review_product_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """`Product.__resolveReference` of `reviews`: the `id` alone."""
    var product = values.add_object()
    values.add_member(product, "id", values.copy(values.get(reference, "id")))
    return product


def reviews_resolvers() -> SubgraphResolvers:
    """Return the resolvers of the `reviews` subgraph.

    Returns:
        The resolver map.
    """
    var resolvers = SubgraphResolvers()
    resolvers.field("Query", "latestReviews", _latest_reviews)
    resolvers.field("Product", "reviews", _product_reviews)
    resolvers.field("Product", "averageRating", _average_rating)
    resolvers.resolve_reference("Product", _review_product_reference)
    return resolvers^


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


struct SubgraphHooks(Hooks):
    """WebSocket hooks for a demo subgraph: provides the `reviewAdded`
    subscription stream."""

    def __init__(out self):
        """Make the hooks."""
        pass

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        """Accept every WebSocket connection.

        Args:
            socket: The connection id.
            message: The `connection_init` message.

        Returns:
            An acknowledgement.
        """
        return Acknowledgement(True, String())

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        """Return the subscription stream root.

        Args:
            values: The arena of the operation.
            document: The operation document.
            operation: The operation node.

        Returns:
            The root value, or `UNDEFINED` for queries and mutations.
        """
        if document.operation(operation) != OperationType.SUBSCRIPTION:
            return UNDEFINED
        var root = values.add_object()
        values.add_member(
            root,
            "reviewAdded",
            values.add_stream(AnyStream(ListStream.of_json(_review_events()))),
        )
        return root

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        """Handle a closed connection.

        Args:
            socket: The connection id.
            code: The close code.
            reason: The close reason.
        """
        pass


def _start(
    name: String, sdl: StringSlice, var resolvers: SubgraphResolvers, port: Int
) raises -> WorkerPool:
    """Build one subgraph and serve it over HTTP and WebSocket in a child
    process."""
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(parse(sdl), resolvers^))
    var subgraph = build_subgraph_schema(modules^)
    var schema = subgraph.schema.copy()
    var map = subgraph.resolvers.resolvers.copy()
    var server = ApolloServer[SubgraphPlugin](
        schema^, map^, ApolloServerOptions(), SubgraphPlugin(subgraph^)
    )
    var config = WsServerConfig()
    config.http = ServerConfig()
    config.http.port = port
    var running = start_server_ws(server^, SubgraphHooks(), config^)
    var bound = running.port()
    var sys = Sys()
    var parent = sys.pid()
    var pid = sys.fork()
    if pid < 0:
        raise Error("fork failed")
    if pid == 0:
        _ = sys.die_with_parent()
        if sys.parent_pid() != parent:
            sys.exit_now(1)
        var code = 0
        try:
            running.listen_signals()
        except:
            code = 1
        if code == 0:
            try:
                running.run()
            except:
                code = 1
        sys.exit_now(code)
    running.loop.close()
    print(
        "🔥 "
        + name
        + " subgraph ready at http://localhost:"
        + String(bound)
        + "/"
    )
    var pids = List[Int]()
    pids.append(pid)
    return WorkerPool(pids^, bound)


def main() raises:
    """Serve both subgraphs until the process is stopped."""
    var products = _start(
        "products",
        PRODUCTS_SDL,
        products_resolvers(),
        Int(getenv("PRODUCTS_PORT", "4001")),
    )
    var reviews = _start(
        "reviews",
        REVIEWS_SDL,
        reviews_resolvers(),
        Int(getenv("REVIEWS_PORT", "4002")),
    )
    _ = products.wait()
    _ = reviews.wait()
