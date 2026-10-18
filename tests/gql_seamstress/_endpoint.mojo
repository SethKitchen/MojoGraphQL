# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A stub GraphQL endpoint for the gql_seamstress suites, in a worker process.

It stands in for the httpmock servers of the upstream Rover tests. Each
path gives one fixed response:

- `/graph`: the introspection result of `GRAPH_SDL`;
- `/subgraph/<name>`: `_service { sdl }` with the SDL of that subgraph in
  `SUBGRAPHS`;
- `/headers`: `_service { sdl }` with an SDL whose description lists the
  request headers that start with `x-`;
- `/legacy`: an error for the modern introspection query, and the result
  of `GRAPH_SDL` for the legacy one;
- `/no-service`, `/partial`, `/null`, `/invalid`, `/no-data`,
  `/unauthorized`, `/status`: the failure cases;
- `/creds/<case>` and `/creds-partial/<case>`: a credential rejection
  with null or partial `data`, for the cases of the upstream
  `test_invalid_credentials_with_null_data` and
  `test_invalid_credentials_with_partial_data`.
"""

from gql_execution.introspection import introspection_from_schema
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, WorkerPool
from gql_http.server import start_workers
from gql_http.socket import IPv4Address
from gql_http.status import Status
from gql_json.writer import JsonWriter, stringify
from gql_schema.build import build_schema

comptime GRAPH_SDL = """
\"\"\"The root of every query.\"\"\"
type Query {
  \"\"\"Find a node by its ID.\"\"\"
  node(\"\"\"The ID of an object\"\"\" id: ID!): Node
  books(first: Int = 10, after: String, order: Order = ASC): [Book!]!
  search(text: String!, filter: SearchFilter): [SearchResult]
  legacy: String @deprecated
  old(arg: Int @deprecated(reason: "Use `arg2`.")): Int @deprecated(reason: "Use `new`.")
  long: String
}

type Mutation {
  addBook(input: BookInput!): Book
}

type Subscription {
  bookAdded: Book
}

\"\"\"An object with an ID.\"\"\"
interface Node {
  id: ID!
}

\"\"\"
A book.

It has a title and an author.
\"\"\"
type Book implements Node {
  id: ID!
  title: String
  author: Author
  tags: [[String!]]
}

type Author implements Node {
  id: ID!
  name: String @tagged(name: "x")
}

union SearchResult = Book | Author

enum Order {
  ASC
  \"\"\"Newest first.\"\"\"
  DESC
  RANDOM @deprecated(reason: "Not stable.")
}

input BookInput {
  title: String!
  tags: [String] = ["a", "b"]
  rating: Float = 1.5
  meta: SearchFilter = {text: "q", limit: 2}
}

input SearchFilter {
  text: String
  limit: Int = 5 @deprecated
}

\"\"\"A date, as `YYYY-MM-DD`.\"\"\"
scalar Date @specifiedBy(url: "https://example.com/date")

\"\"\"Marks a field with a name.\"\"\"
directive @tagged(name: String!, \"\"\"How strong\"\"\" weight: Int = 1) repeatable on FIELD_DEFINITION | OBJECT
"""
"""The schema that `/graph` introspects."""

comptime PRODUCTS_SDL = (
    'extend schema @link(url: "https://specs.apollo.dev/federation/v2.3",'
    ' import: ["@key"])\n\ntype Query {\n  products: [Product]\n}\n\ntype'
    ' Product @key(fields: "id") {\n  id: ID!\n  name: String\n}\n'
)
"""The SDL of the `products` subgraph."""

comptime REVIEWS_SDL = (
    'extend schema @link(url: "https://specs.apollo.dev/federation/v2.3",'
    ' import: ["@key"])\n\ntype Product @key(fields: "id") {\n  id: ID!\n '
    " reviews: [String]\n}\n"
)
"""The SDL of the `reviews` subgraph."""


def _service(sdl: StringSlice) -> String:
    """Return the response of `_service { sdl }`."""
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("data")
    writer.begin_object()
    writer.key("_service")
    writer.begin_object()
    writer.key("sdl")
    writer.string(sdl)
    writer.end_object()
    writer.end_object()
    writer.end_object()
    return writer^.take_string()


struct Endpoint(Handler):
    """Answers each path with a fixed GraphQL response."""

    var graph: String
    """The response of `/graph`."""

    def __init__(out self) raises:
        """Introspect `GRAPH_SDL` once."""
        var result = introspection_from_schema(build_schema(GRAPH_SDL))
        self.graph = '{"data":' + stringify(result, result.root) + "}"

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one request."""
        var path = String(request.path())
        var body = String(StringSlice(unsafe_from_utf8=request.body()))
        var text: String
        if path == "/graph":
            text = self.graph.copy()
        elif path == "/subgraph/products":
            text = _service(PRODUCTS_SDL)
        elif path == "/subgraph/reviews":
            text = _service(REVIEWS_SDL)
        elif path == "/subgraph/broken":
            text = _service("type Query {")
        elif path == "/headers":
            var seen = List[String]()
            for index in range(request.header_count()):
                var name = String(request.header_name(index)).lower()
                if name.startswith("x-"):
                    seen.append(
                        name + "=" + String(request.header_value(index))
                    )
            text = _service(
                '"""'
                + String(" ").join(seen)
                + '"""\ntype Query {\n  a: Int\n}\n'
            )
        elif path == "/legacy":
            if body.find("args(includeDeprecated") >= 0:
                text = (
                    '{"errors":[{"message":"Unknown argument'
                    ' \\"includeDeprecated\\" on field \\"__Field.args\\"."}]}'
                )
            else:
                text = self.graph.copy()
        elif path == "/no-service":
            text = (
                '{"errors":[{"message":"Cannot query field \\"_service\\" on'
                ' type \\"Query\\"."}]}'
            )
        elif path == "/partial":
            text = '{"data":{"__schema":null,"_service":null},"errors":[{"message":"boom"},{"message":"bang"}]}'
        elif path == "/null":
            text = '{"data":{"__schema":null,"_service":null}}'
        elif path == "/no-data":
            text = "{}"
        elif path == "/small":
            text = (
                '{"data":{"__schema":{"queryType":{"name":"Query"},"mutationType":null,'
                '"subscriptionType":null,"types":[{"kind":"OBJECT","name":"Query",'
                '"description":null,"fields":[{"name":"a","description":null,"args":[],'
                '"type":{"kind":"SCALAR","name":"Int","ofType":null},"isDeprecated":false,'
                '"deprecationReason":null}],"inputFields":null,"interfaces":[],'
                '"enumValues":null,"possibleTypes":null}],"directives":[]}}}'
            )
        elif path == "/no-service-partial":
            text = (
                '{"data":{},"errors":[{"message":"Cannot query field'
                ' \\"_service\\" on type \\"Query\\"."}]}'
            )
        elif path == "/empty-data":
            text = '{"data":{}}'
        elif path == "/sdl-number":
            text = '{"data":{"_service":{"sdl":5}}}'
        elif path == "/too-large":
            response.send(Status(413), "text/plain", "nope")
            return
        elif path == "/errors-null":
            text = (
                '{"data":{"_service":{"sdl":"type Query {\\n  a:'
                ' Int\\n}\\n"}},"errors":null}'
            )
        elif path == "/errors-empty":
            text = '{"errors":[]}'
        elif path == "/invalid-credentials":
            text = (
                '{"errors":[{"message":"Invalid Credentials for this graph"}]}'
            )
        elif path == "/data-null":
            text = '{"data":null}'
        elif path == "/array":
            text = "[1]"
        elif path == "/errors-odd":
            text = '{"data":{"__schema":null},"errors":[{"x":1},{"message":5}]}'
        elif path == "/service-no-sdl":
            text = '{"data":{"_service":{}}}'
        elif path == "/bad-kind":
            text = (
                '{"data":{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"OBJECT",'
                '"name":"Query","fields":[{"name":"a","args":[],"type":{"kind":"WHAT","name":"X"}}]}],'
                '"directives":[]}}}'
            )
        elif path == "/unknown-type":
            text = (
                '{"data":{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"OBJECT",'
                '"name":"Query","fields":[{"name":"a","args":[],"type":{"kind":"OBJECT","name":"Missing"}}]}],'
                '"directives":[]}}}'
            )
        elif path.startswith("/creds/") or path.startswith("/creds-partial/"):
            var messages: List[String] = [
                "Unauthorized",
                "Invalid credentials provided",
                "Unauthorized: Invalid credentials provided",
                "UNAUTHORIZED: INVALID CREDENTIALS PROVIDED",
            ]
            var number = Int(path[byte = path.rfind("/") + 1 :])
            var data = "null" if path.startswith("/creds/") else '{"inner":0}'
            text = (
                '{"data":'
                + data
                + ',"errors":[{"message":"'
                + messages[number]
                + '"}]}'
            )
        elif path == "/unauthorized":
            text = '{"errors":[{"message":"Unauthorized"}]}'
        elif path == "/status":
            response.send(Status.UNPROCESSABLE_CONTENT, "text/plain", "nope")
            return
        else:
            text = "not json"
        response.send(Status.OK, "application/json", text)


def start_endpoint() raises -> WorkerPool:
    """Start the stub in one worker process on a free loopback port.

    Returns:
        The pool; its `port` is the endpoint's port.
    """
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    return start_workers(Endpoint(), config)
