# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The ScorchQL gateway: HTTP, SSE, multipart and WebSocket handlers for
the router, the explorer and the registry.

A `Gateway` serves one supergraph. In registry mode, the subgraphs come
from a `Registry`, and a client publishes them over HTTP. Before each
request, at most once every `GatewayConfig.reload_interval_ms`, the
gateway reads the registry revision. When the revision has changed, it
reads the new supergraph and makes a new `gql_router_stream` stream hub
and router. So every worker process follows a publish without a restart.
In static mode, the supergraph is fixed and the publish endpoints answer
`409`.

| Method and path | Answer |
| --- | --- |
| `GET /` | The explorer page |
| `GET <graphql path>` from a browser, without `query` | The explorer page |
| `GET` or `POST <graphql path>` | The GraphQL response or stream of the router |
| `Upgrade: websocket` on `<graphql path>` | `graphql-transport-ws` over WebSocket |
| `GET /health` | `{"status":"pass"}` |
| `GET /favicon.svg` | The ScorchQL flame |
| `GET /scorchql/state` | The mode, the revision and the subgraphs, as JSON |
| `GET /scorchql/supergraph.graphql` | The supergraph SDL |
| `POST /scorchql/plan` | The query plan of `{query, operationName}` |
| `POST /scorchql/publish` | Publish `{name, url, sdl}`; without `sdl`, the gateway reads it from the subgraph |
| `POST /scorchql/remove` | Remove the subgraph `{name}` |
| `POST /scorchql/refresh` | Read the SDL of every subgraph again, and publish each change |

When `GatewayConfig.publish_token` is set, the last three need the header
`Authorization: Bearer <token>`.

Before the first publish, a GraphQL request answers `503` with the code
`NO_SUPERGRAPH`, and a WebSocket `subscribe` gets an `error` message with
the same code.

Subscriptions and `@defer` stream through `gql_router_stream`: over
`graphql-transport-ws` WebSocket (`GatewayWsHandler`), Server-Sent Events
(`text/event-stream`), incremental delivery (`multipart/mixed`), or Apollo
multipart HTTP (`multipart/mixed;subscriptionSpec=1.0`).

When `GatewayConfig.h3_port` is set, each answer has an `Alt-Svc` header
that announces HTTP/3 on that port.

`Gateway.answer` does the work on plain values, so that a test can call it
without a socket. `serve_gateway` opens one `gql_ws` server that serves
WebSocket and HTTP/1.1 on the same port.

Differences from upstream: none; there is no upstream.
"""

from std.memory import ArcPointer
from std.time import perf_counter_ns

from gql_http.body import BodyPoll
from gql_http.client import Client, ClientConfig
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import EPOLL_CTL_ADD, EPOLLIN, Sys
from gql_http.status import Method, Status
from gql_http.url import parse_query, query_value
from gql_json.parser import parse_bytes
from gql_json.value import NO_NODE as NO_JSON, JsonDocument, JsonKind
from gql_json.writer import JsonWriter
from gql_router.exec_http import HttpTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router.router_server import HttpAnswer
from gql_router_stream.config import SubscriptionsConfig
from gql_router_stream.defer import has_defer, plan_defer
from gql_router_stream.http import StreamAnswer, answer_request
from gql_router_stream.server import (
    RouterStreamHandler,
    RouterWsExecutor,
    router_server_config,
)
from gql_router_stream.subscription import StreamHub
from gql_scorchql.explorer import FAVICON_SVG, explorer_page
from gql_scorchql.introspect import fetch_subgraph_sdl
from gql_scorchql.registry import (
    PublishResult,
    PublishedSubgraph,
    Registry,
    publish_errors,
)
from gql_ws.graphql_ws import ProtocolMessage
from gql_ws.protocol import Message
from gql_ws.server import Server, ServerConfig, Sockets, WsHandler, listen
from gql_ws.transport_server import (
    Acknowledgement,
    GraphQLExecutor,
    Operation,
    TransportOptions,
    TransportServer,
)

comptime JSON_TYPE = "application/json; charset=utf-8"
"""The type of a JSON answer."""
comptime TEXT_TYPE = "text/plain; charset=utf-8"
"""The type of a text answer."""
comptime HTML_TYPE = "text/html; charset=utf-8"
"""The type of the explorer page."""
comptime SVG_TYPE = "image/svg+xml"
"""The type of the favicon."""


struct GatewayConfig(Copyable, Movable):
    """What a gateway serves, and where."""

    var title: String
    """The name in the explorer header and the browser tab."""
    var graphql_path: String
    """The GraphQL path; `/graphql` at first."""
    var registry_directory: Optional[String]
    """The registry directory, in registry mode."""
    var static_sdl: Optional[String]
    """The fixed supergraph SDL, in static mode."""
    var publish_token: Optional[String]
    """The bearer token that publish, remove and refresh need, if any."""
    var reload_interval_ms: Int
    """How often a worker reads the registry revision; 250 at first."""
    var introspect_timeout_ms: Int
    """The deadline of one `_service { sdl }` request; 5000 at first."""
    var http_port: Int
    """The port of plain HTTP/1.1, for the explorer; 0 when unknown."""
    var https_port: Int
    """The TCP port of HTTPS with h2 and HTTP/1.1; 0 when off."""
    var h3_port: Int
    """The UDP port of HTTP/3; 0 when off. When it is set, each answer
    announces it in `Alt-Svc`."""
    var subscriptions: SubscriptionsConfig
    """The subscription and WebSocket configuration of the router."""

    def __init__(out self):
        """Make the default configuration: registry mode in `.scorchql`,
        with subscriptions and WebSockets enabled."""
        self.title = "ScorchQL"
        self.graphql_path = "/graphql"
        self.registry_directory = String(".scorchql")
        self.static_sdl = None
        self.publish_token = None
        self.reload_interval_ms = 250
        self.introspect_timeout_ms = 5000
        self.http_port = 0
        self.https_port = 0
        self.h3_port = 0
        self.subscriptions = SubscriptionsConfig()
        self.subscriptions.enabled = True
        self.subscriptions.server_enabled = True
        self.subscriptions.websocket_all = True


@fieldwise_init
struct RefreshOutcome(Copyable, Movable):
    """What a refresh did with one subgraph."""

    var name: String
    """The subgraph name."""
    var status: String
    """`unchanged`, `updated` or `failed`."""
    var error: String
    """Why it failed; empty otherwise."""


def refresh_registry(
    mut registry: Registry, mut client: Client
) raises -> List[RefreshOutcome]:
    """Read the SDL of each published subgraph again, and publish each
    change.

    Args:
        registry: The registry.
        client: The HTTP client.

    Returns:
        One outcome per subgraph, by name.

    Raises:
        Error: When a registry file cannot be read or written.
    """
    var out = List[RefreshOutcome]()
    for ref subgraph in registry.subgraphs():
        var sdl: String
        try:
            sdl = fetch_subgraph_sdl(client, subgraph.url)
        except e:
            out.append(RefreshOutcome(subgraph.name, "failed", String(e)))
            continue
        var result = registry.publish(subgraph.name, subgraph.url, sdl)
        if not result.accepted:
            out.append(
                RefreshOutcome(
                    subgraph.name, "failed", String("\n").join(result.errors)
                )
            )
        elif result.changed:
            out.append(RefreshOutcome(subgraph.name, "updated", ""))
        else:
            out.append(RefreshOutcome(subgraph.name, "unchanged", ""))
    return out^


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


def _json_answer(status: Int, var json: String) -> HttpAnswer:
    """Make a JSON answer."""
    return HttpAnswer(status, JSON_TYPE, List[UInt8](json.as_bytes()))


def _text_answer(status: Int, content_type: String, text: String) -> HttpAnswer:
    """Make an answer of text."""
    return HttpAnswer(status, content_type, List[UInt8](text.as_bytes()))


def _error_answer(status: Int, errors: List[String]) -> HttpAnswer:
    """Make `{"ok":false,"errors":[...]}`."""
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("ok")
    writer.bool(False)
    writer.key("errors")
    writer.begin_array()
    for ref error in errors:
        writer.string(error)
    writer.end_array()
    writer.end_object()
    return _json_answer(status, writer^.take_string())


def _one_error(status: Int, message: String) -> HttpAnswer:
    """Make `{"ok":false,"errors":[message]}`."""
    var errors = List[String]()
    errors.append(message)
    return _error_answer(status, errors)


def _no_supergraph_message(load_error: String) -> String:
    """Return the message when no supergraph is loaded."""
    if load_error != "":
        return load_error
    return String(
        "No subgraphs are published yet. Publish one to POST /scorchql/publish."
    )


def _no_supergraph_errors(load_error: String) -> String:
    """Make the JSON error array when no supergraph is loaded."""
    var writer = JsonWriter()
    writer.begin_array()
    writer.begin_object()
    writer.key("message")
    writer.string(_no_supergraph_message(load_error))
    writer.key("extensions")
    writer.begin_object()
    writer.key("code")
    writer.string("NO_SUPERGRAPH")
    writer.end_object()
    writer.end_object()
    writer.end_array()
    return writer^.take_string()


def _graphql_error(status: Int, errors_array: String) -> HttpAnswer:
    """Make a GraphQL response with an error array and no data."""
    return _json_answer(status, '{"errors":' + errors_array + "}")


def _single(var answer: HttpAnswer) -> StreamAnswer[HttpTransport]:
    """Turn a plain HTTP answer into a single `StreamAnswer`."""
    return StreamAnswer[HttpTransport](
        answer.status, answer.content_type.copy(), answer.body.copy()
    )


def _drain_deferred(
    hub: ArcPointer[StreamHub[HttpTransport]],
    mut answer: StreamAnswer[HttpTransport],
) raises:
    """Write the payloads of a deferred answer into `answer.body`."""
    ref deferred = answer.deferred.value()
    deferred.write_initial(hub[].router.schema.metadata.possible_types)
    answer.format.result(answer.body, Span(deferred.initial))
    var json = List[UInt8]()
    if deferred.next(hub[].router, json) == BodyPoll.READY:
        answer.format.result(answer.body, Span(json))
    answer.format.end(answer.body)
    answer.deferred = None
    answer.is_stream = False


def _publish_answer(result: PublishResult) -> HttpAnswer:
    """Make the answer of a publish or a removal."""
    if not result.accepted:
        return _error_answer(422, result.errors)
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("ok")
    writer.bool(True)
    writer.key("changed")
    writer.bool(result.changed)
    writer.key("revision")
    writer.int(Int64(result.revision))
    writer.end_object()
    return _json_answer(200, writer^.take_string())


def wants_explorer(
    method: Method, query_string: StringSlice, accept: Optional[String]
) -> Bool:
    """Return True for a browser that opens the GraphQL path.

    Args:
        method: The request method.
        query_string: The text after `?`.
        accept: The `Accept` value, when there is one.

    Returns:
        Whether the request is a `GET` with no `query` parameter, from a
        client that accepts `text/html`.
    """
    if method != Method.GET or not accept:
        return False
    if not ("text/html" in accept.value()):
        return False
    try:
        return not query_value(parse_query(query_string), "query")
    except:
        return False


struct _Body(Movable):
    """The members of a JSON request body that the gateway reads."""

    var document: JsonDocument
    """The parsed body."""

    def __init__(out self, var body: List[UInt8]) raises:
        """Parse a body that must be one JSON object.

        Args:
            body: The body.

        Raises:
            Error: When it is not a JSON object.
        """
        self.document = parse_bytes(body^)
        if self.document.kind(self.document.root) != JsonKind.OBJECT:
            raise Error("The request body must be a JSON object.")

    def string(self, key: StringSlice) raises -> Optional[String]:
        """Return a member that is a string, or None for a missing or
        `null` member.

        Args:
            key: The member name.

        Returns:
            The string, or None.

        Raises:
            Error: When the member has another type.
        """
        var node = self.document.find(self.document.root, key)
        if node < 0 or self.document.kind(node) == JsonKind.NULL:
            return None
        if self.document.kind(node) != JsonKind.STRING:
            raise Error("'" + String(key) + "' must be a string.")
        return self.document.string_value(node)


struct Gateway(Handler):
    """A gateway: a streaming router for the current supergraph, the
    explorer and the registry endpoints."""

    var config: GatewayConfig
    """The configuration."""
    var registry: Optional[Registry]
    """The registry, in registry mode."""
    var streams: List[RouterStreamHandler[HttpTransport]]
    """The stream handler and hub of the current supergraph; empty before
    the first publish."""
    var sdl: String
    """The current supergraph SDL; empty before the first publish."""
    var revision: Int
    """The registry revision of `sdl`; -1 before the first load."""
    var load_error: String
    """Why the last supergraph could not be served; empty otherwise."""
    var checked_ms: Int
    """When the registry revision was read last."""
    var client: Client
    """The client that reads the SDL of a subgraph."""
    var sys: Sys
    """The system calls."""
    var epoll: Int
    """An epoll descriptor that watches the active stream hub."""

    def __init__(
        out self, var config: GatewayConfig, var sys: Sys = Sys()
    ) raises:
        """Make a gateway, and load its supergraph.

        Args:
            config: The configuration.
            sys: The system calls; a test injects faults here.

        Raises:
            Error: In static mode, when the supergraph cannot be served.
                In registry mode, when the directory cannot be created, or
                when an epoll instance cannot open.
        """
        var client_config = ClientConfig()
        client_config.timeout_ms = config.introspect_timeout_ms
        self.client = Client(client_config)
        self.config = config^
        self.registry = None
        self.streams = List[RouterStreamHandler[HttpTransport]]()
        self.sdl = ""
        self.revision = -1
        self.load_error = ""
        self.checked_ms = 0
        self.sys = sys^
        self.epoll = self.sys.epoll_create()
        if self.epoll < 0:
            raise Error("epoll_create failed: " + String(-self.epoll))
        if self.config.static_sdl:
            var sdl = self.config.static_sdl.value().copy()
            self._load(sdl)
            if self.load_error != "":
                raise Error(self.load_error)
            return
        var registry = Registry(
            self.config.registry_directory.or_else(".scorchql")
        )
        registry.open()
        self.registry = registry^
        self.reload()

    def __deinit__(deinit self):
        """Close the epoll descriptor."""
        self.sys.close(self.epoll)

    def _load(mut self, sdl: String):
        """Make a router and stream hub for a supergraph; keep the old one
        on failure."""
        try:
            var schema = RouterSchema(sdl)
            var transport = HttpTransport(
                schema.subgraph_names, schema.subgraph_urls
            )
            var hub = ArcPointer(
                StreamHub(
                    Router(schema^, transport^),
                    self.config.subscriptions.copy(),
                )
            )
            _ = self.sys.epoll_ctl(
                self.epoll, EPOLL_CTL_ADD, hub[].fd(), EPOLLIN
            )
            self.streams.clear()
            self.streams.append(
                RouterStreamHandler(hub^, self.config.graphql_path)
            )
            self.sdl = sdl
            self.load_error = ""
        except e:
            self.load_error = "The supergraph cannot be served: " + String(e)

    def reload(mut self):
        """Read the registry revision, and load a new supergraph when it
        has changed. A gateway in static mode does nothing."""
        self.checked_ms = _now_ms()
        if not self.registry:
            return
        var revision = self.registry.value().revision()
        if revision == self.revision:
            return
        self.revision = revision
        var sdl = self.registry.value().supergraph()
        if not sdl:
            self.streams.clear()
            self.sdl = ""
            self.load_error = ""
            return
        self._load(sdl.value())

    def maybe_reload(mut self):
        """Reload when `reload_interval_ms` has passed since the last read."""
        if _now_ms() - self.checked_ms >= self.config.reload_interval_ms:
            self.reload()

    def state_json(self) raises -> String:
        """Return the state that the explorer shows.

        Returns:
            `{"title", "graphqlPath", "mode", "revision",
            "publishRequiresToken", "httpPort", "httpsPort", "h3Port",
            "subscriptions", "loadError", "subgraphs"}`; each subgraph has
            `name`, `url`, `publishedAt` and `sdl`.

        Raises:
            Error: When a registry file cannot be read.
        """
        var writer = JsonWriter()
        writer.begin_object()
        writer.key("title")
        writer.string(self.config.title)
        writer.key("graphqlPath")
        writer.string(self.config.graphql_path)
        writer.key("mode")
        writer.string("registry" if self.registry else "static")
        writer.key("revision")
        writer.int(Int64(self.revision))
        writer.key("publishRequiresToken")
        writer.bool(Bool(self.config.publish_token))
        writer.key("httpPort")
        writer.int(Int64(self.config.http_port))
        writer.key("httpsPort")
        writer.int(Int64(self.config.https_port))
        writer.key("h3Port")
        writer.int(Int64(self.config.h3_port))
        writer.key("subscriptions")
        if not self.config.subscriptions.enabled:
            writer.string("off")
        elif self.config.subscriptions.websocket_all:
            writer.string("ws")
        else:
            writer.string("http")
        writer.key("loadError")
        if self.load_error == "":
            writer.null()
        else:
            writer.string(self.load_error)
        writer.key("subgraphs")
        writer.begin_array()
        var subgraphs = List[PublishedSubgraph]()
        if self.registry:
            subgraphs = self.registry.value().subgraphs()
        elif len(self.streams) > 0:
            ref schema = self.streams[0].hub[].router.schema
            for index in range(len(schema.subgraph_names)):
                subgraphs.append(
                    PublishedSubgraph(
                        schema.subgraph_names[index],
                        schema.subgraph_urls[index],
                        "",
                        0,
                    )
                )
        for ref subgraph in subgraphs:
            writer.begin_object()
            writer.key("name")
            writer.string(subgraph.name)
            writer.key("url")
            writer.string(subgraph.url)
            writer.key("publishedAt")
            writer.int(Int64(subgraph.published_at))
            writer.key("sdl")
            writer.string(subgraph.sdl)
            writer.end_object()
        writer.end_array()
        writer.end_object()
        return writer^.take_string()

    def _authorized(self, authorization: Optional[String]) -> Bool:
        """Return True when no token is set, or the request names it."""
        if not self.config.publish_token:
            return True
        if not authorization:
            return False
        return authorization.value() == (
            "Bearer " + self.config.publish_token.value()
        )

    def _plan(mut self, var body: List[UInt8]) -> HttpAnswer:
        """Answer `POST /scorchql/plan`."""
        if len(self.streams) == 0:
            return _one_error(503, "No subgraphs are published yet.")
        var query: Optional[String]
        var name: Optional[String]
        try:
            var parsed = _Body(body^)
            query = parsed.string("query")
            name = parsed.string("operationName")
        except e:
            return _one_error(400, String(e))
        if not query:
            return _one_error(400, "'query' is required.")
        var writer = JsonWriter()
        writer.begin_object()
        try:
            var source = query.value()
            if has_defer(source):
                source = plan_defer(source, name, JsonDocument(), NO_JSON).full
            var text = (
                self.streams[0]
                .hub[]
                .router.schema.planner.plan_text(source, name)
            )
            writer.key("ok")
            writer.bool(True)
            writer.key("plan")
            writer.string(text)
        except e:
            writer.key("ok")
            writer.bool(False)
            writer.key("errors")
            writer.begin_array()
            writer.string(String(e))
            writer.end_array()
        writer.end_object()
        return _json_answer(200, writer^.take_string())

    def _publish(mut self, var body: List[UInt8]) raises -> HttpAnswer:
        """Answer `POST /scorchql/publish`."""
        var name: Optional[String]
        var url: Optional[String]
        var sdl: Optional[String]
        try:
            var parsed = _Body(body^)
            name = parsed.string("name")
            url = parsed.string("url")
            sdl = parsed.string("sdl")
        except e:
            return _one_error(400, String(e))
        if not name or not url:
            return _one_error(400, "'name' and 'url' are required.")
        var invalid = publish_errors(name.value(), url.value())
        if len(invalid) > 0:
            return _error_answer(422, invalid)
        if not sdl:
            try:
                sdl = fetch_subgraph_sdl(self.client, url.value())
            except e:
                return _one_error(
                    422,
                    "Cannot read the SDL of '"
                    + name.value()
                    + "' from "
                    + url.value()
                    + ": "
                    + String(e),
                )
        var result = self.registry.value().publish(
            name.value(), url.value(), sdl.value()
        )
        self.reload()
        return _publish_answer(result)

    def _remove(mut self, var body: List[UInt8]) raises -> HttpAnswer:
        """Answer `POST /scorchql/remove`."""
        var name: Optional[String]
        try:
            name = _Body(body^).string("name")
        except e:
            return _one_error(400, String(e))
        if not name:
            return _one_error(400, "'name' is required.")
        var result = self.registry.value().remove(name.value())
        self.reload()
        return _publish_answer(result)

    def _refresh(mut self) raises -> HttpAnswer:
        """Answer `POST /scorchql/refresh`."""
        var outcomes = refresh_registry(self.registry.value(), self.client)
        self.reload()
        var writer = JsonWriter()
        writer.begin_object()
        writer.key("ok")
        writer.bool(True)
        writer.key("revision")
        writer.int(Int64(self.revision))
        writer.key("subgraphs")
        writer.begin_array()
        for ref outcome in outcomes:
            writer.begin_object()
            writer.key("name")
            writer.string(outcome.name)
            writer.key("status")
            writer.string(outcome.status)
            if outcome.error != "":
                writer.key("error")
                writer.string(outcome.error)
            writer.end_object()
        writer.end_array()
        writer.end_object()
        return _json_answer(200, writer^.take_string())

    def answer_stream(
        mut self,
        method: Method,
        path: StringSlice,
        query_string: StringSlice,
        content_type: Optional[String],
        accept: Optional[String],
        authorization: Optional[String],
        var body: List[UInt8],
    ) raises -> StreamAnswer[HttpTransport]:
        """Answer one request, keeping a streamed GraphQL response open.

        Args:
            method: The request method.
            path: The path of the target.
            query_string: The text after `?`.
            content_type: The `Content-Type` value, when there is one.
            accept: The `Accept` value, when there is one.
            authorization: The `Authorization` value, when there is one.
            body: The request content.

        Returns:
            The single or streamed answer.

        Raises:
            Error: When a registry file cannot be read or written.
        """
        if path == self.config.graphql_path:
            if wants_explorer(method, query_string, accept):
                return _single(_text_answer(200, HTML_TYPE, self._page()))
            if len(self.streams) == 0:
                return _single(
                    _graphql_error(503, _no_supergraph_errors(self.load_error))
                )
            return answer_request(
                self.streams[0].hub,
                method,
                query_string,
                content_type,
                accept.or_else(""),
                body^,
            )
        return _single(self._answer_other(method, path, authorization, body^))

    def _answer_other(
        mut self,
        method: Method,
        path: StringSlice,
        authorization: Optional[String],
        var body: List[UInt8],
    ) raises -> HttpAnswer:
        """Answer a request outside the GraphQL path."""
        if method == Method.GET:
            if path == "/" or path == "/index.html":
                return _text_answer(200, HTML_TYPE, self._page())
            if path == "/health":
                return _json_answer(200, '{"status":"pass"}')
            if path == "/favicon.svg" or path == "/favicon.ico":
                return _text_answer(200, SVG_TYPE, FAVICON_SVG)
            if path == "/scorchql/state":
                return _json_answer(200, self.state_json())
            if path == "/scorchql/supergraph.graphql":
                if self.sdl == "":
                    return _text_answer(
                        404, TEXT_TYPE, "No supergraph is composed yet.\n"
                    )
                return _text_answer(200, TEXT_TYPE, self.sdl)
            return _text_answer(404, TEXT_TYPE, "Not found\n")
        if method != Method.POST:
            return _text_answer(405, TEXT_TYPE, "Method not allowed\n")
        if path == "/scorchql/plan":
            return self._plan(body^)
        if (
            path != StaticString("/scorchql/publish")
            and path != StaticString("/scorchql/remove")
            and path != StaticString("/scorchql/refresh")
        ):
            return _text_answer(404, TEXT_TYPE, "Not found\n")
        if not self.registry:
            return _one_error(
                409,
                "This gateway serves a fixed supergraph; it has no registry.",
            )
        if not self._authorized(authorization):
            return _one_error(
                401, "This gateway needs 'Authorization: Bearer <token>'."
            )
        if path == "/scorchql/publish":
            return self._publish(body^)
        if path == "/scorchql/remove":
            return self._remove(body^)
        return self._refresh()

    def answer(
        mut self,
        method: Method,
        path: StringSlice,
        query_string: StringSlice,
        content_type: Optional[String],
        accept: Optional[String],
        authorization: Optional[String],
        var body: List[UInt8],
    ) raises -> HttpAnswer:
        """Answer one request as a single HTTP response.

        Args:
            method: The request method.
            path: The path of the target.
            query_string: The text after `?`.
            content_type: The `Content-Type` value, when there is one.
            accept: The `Accept` value, when there is one.
            authorization: The `Authorization` value, when there is one.
            body: The request content.

        Returns:
            The answer. When the operation uses `@defer` with a streaming
            `Accept` header, the initial and subsequent payloads are
            framed into `body`.

        Raises:
            Error: When a registry file cannot be read or written.
        """
        var stream = self.answer_stream(
            method,
            path,
            query_string,
            content_type,
            accept,
            authorization,
            body^,
        )
        if stream.deferred:
            _drain_deferred(self.streams[0].hub, stream)
        return HttpAnswer(
            stream.status, stream.content_type.copy(), stream.body.copy()
        )

    def _page(self) -> String:
        """Return the explorer page."""
        return explorer_page(self.config.title, self.config.graphql_path)

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one HTTP request, holding streamed responses open.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: When a registry file cannot be read or written, or the
                response cannot be written.
        """
        self.maybe_reload()
        var answer = self.answer_stream(
            request.method,
            request.path(),
            request.query(),
            _header(request, "content-type"),
            _header(request, "accept"),
            _header(request, "authorization"),
            List[UInt8](request.body()),
        )
        response.set_status(Status(answer.status))
        response.add_header("Content-Type", answer.content_type)
        response.add_header("Cache-Control", "no-store")
        if self.config.h3_port > 0:
            response.add_header(
                "Alt-Svc",
                'h3=":' + String(self.config.h3_port) + '"; ma=86400',
            )
        if not answer.is_stream:
            response.write(Span(answer.body))
            return
        response.begin_chunked()
        response.write_chunk(Span(answer.body))
        response.hold()
        self.streams[0].hold(response.connection(), answer^)

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        """Frame the next results of a held HTTP stream.

        Args:
            id: The connection.
            out: The destination of the bytes.

        Returns:
            `READY` with bytes, `PENDING`, or `DONE` at the end.

        Raises:
            Error: When the response of a deferred operation is not JSON.
        """
        if len(self.streams) == 0:
            return BodyPoll.DONE
        return self.streams[0].poll_body(id, out)

    def body_closed(mut self, id: Int):
        """Close the subscription of a response whose client went away.

        Args:
            id: The connection.
        """
        if len(self.streams) > 0:
            self.streams[0].body_closed(id)


struct SharedGateway(Copyable, Handler, Movable):
    """A gateway shared between an HTTP server and a WebSocket server in
    one event loop."""

    var shared: ArcPointer[Gateway]
    """The shared gateway."""

    def __init__(out self, shared: ArcPointer[Gateway]):
        """Share a gateway.

        Args:
            shared: The gateway.
        """
        self.shared = shared

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one HTTP request on the shared gateway.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: What `Gateway.handle` raises.
        """
        self.shared[].handle(request, response)

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        """Frame the next results of a held HTTP stream.

        Args:
            id: The connection.
            out: The destination of the bytes.

        Returns:
            What `Gateway.poll_body` returns.

        Raises:
            Error: What `Gateway.poll_body` raises.
        """
        return self.shared[].poll_body(id, out)

    def body_closed(mut self, id: Int):
        """Close the subscription of a response whose client went away.

        Args:
            id: The connection.
        """
        self.shared[].body_closed(id)


struct GatewayWsExecutor(GraphQLExecutor):
    """The `graphql-transport-ws` executor of a gateway."""

    var gateway: ArcPointer[Gateway]
    """The shared gateway."""

    def __init__(out self, gateway: ArcPointer[Gateway]):
        """Make an executor for a shared gateway.

        Args:
            gateway: The gateway.
        """
        self.gateway = gateway

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        """Acknowledge each WebSocket connection.

        Args:
            socket: The connection id.
            message: The `connection_init`.

        Returns:
            An acknowledgement without a payload.

        Raises:
            Error: Never; the trait allows it.
        """
        return Acknowledgement(True, String())

    def operation(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Operation:
        """Run one `subscribe` on the current supergraph of the gateway.

        Args:
            socket: The connection id.
            message: The `subscribe` message.

        Returns:
            One result for a query, a mutation or `@defer`, a stream for a
            subscription, and the errors of a request that fails or when no
            supergraph is published yet.

        Raises:
            Error: When the response of the router is not JSON.
        """
        self.gateway[].maybe_reload()
        if len(self.gateway[].streams) == 0:
            return Operation.errors(
                _no_supergraph_errors(self.gateway[].load_error)
            )
        var executor = RouterWsExecutor(self.gateway[].streams[0].hub)
        return executor.operation(socket, message)

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        """Forget a closed connection.

        Args:
            socket: The connection id.
            code: The close code.
            reason: The close reason.
        """
        pass


struct GatewayWsHandler(WsHandler):
    """The WebSocket handler of a gateway: `graphql-transport-ws`, and the
    subgraph sockets of the active stream hub in the server loop."""

    var gateway: ArcPointer[Gateway]
    """The shared gateway."""
    var transport: TransportServer[GatewayWsExecutor]
    """The `graphql-transport-ws` protocol server."""

    def __init__(
        out self,
        gateway: ArcPointer[Gateway],
        options: TransportOptions = TransportOptions(),
    ) raises:
        """Make a WebSocket handler for a shared gateway.

        Args:
            gateway: The shared gateway.
            options: The `graphql-transport-ws` protocol options.

        Raises:
            Error: When the event loop of the protocol server cannot open.
        """
        self.gateway = gateway
        self.transport = TransportServer(GatewayWsExecutor(gateway), options)
        _ = self.gateway[].sys.epoll_ctl(
            self.gateway[].epoll,
            EPOLL_CTL_ADD,
            self.transport.fd(),
            EPOLLIN,
        )

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        """Start a connection.

        Args:
            sockets: The open connections.
            id: The socket.

        Raises:
            Error: The errors of the protocol server.
        """
        self.transport.on_open(sockets, id)

    def on_message(
        mut self, mut sockets: Sockets, id: Int, message: Message
    ) raises:
        """Handle one WebSocket message.

        Args:
            sockets: The open connections.
            id: The socket.
            message: The message.

        Raises:
            Error: The errors of the protocol server.
        """
        self.transport.on_message(sockets, id, message)

    def on_close(
        mut self, mut sockets: Sockets, id: Int, code: UInt16, reason: String
    ):
        """End a connection and its subscriptions.

        Args:
            sockets: The open connections.
            id: The socket.
            code: The close code.
            reason: The close reason.
        """
        self.transport.on_close(sockets, id, code, reason)

    def on_tick(mut self, mut sockets: Sockets) raises:
        """Read the subgraph sockets of the active hub, wake its
        subscriptions, and send their results.

        Args:
            sockets: The open connections.

        Raises:
            Error: The errors of the protocol server.
        """
        if len(self.gateway[].streams) > 0:
            self.gateway[].streams[0].hub[].pump()
        self.transport.on_tick(sockets)

    def fd(self) -> Int:
        """Return the descriptor that is readable when there is work.

        Returns:
            The epoll of the protocol loop and of the gateway's stream hub.
        """
        return self.gateway[].epoll

    def wait_ms(self) -> Int:
        """Return the longest wait of the loop.

        Returns:
            The wait of the protocol server.
        """
        return self.transport.wait_ms()


def serve_gateway(
    var gateway: Gateway,
    var config: ServerConfig = ServerConfig(),
) raises -> Server[GatewayWsHandler, SharedGateway]:
    """Open an HTTP/1.1 and WebSocket server for a gateway, in this
    process.

    Args:
        gateway: The gateway.
        config: The `gql_ws` configuration; its WebSocket path and
            subprotocol are set from `gateway.config`.

    Returns:
        The server; call `run` or `poll`.

    Raises:
        Error: When the listening socket or epoll cannot open.
    """
    config = router_server_config(
        gateway.config.subscriptions, config^, gateway.config.graphql_path
    )
    var shared = ArcPointer(gateway^)
    return listen(GatewayWsHandler(shared), SharedGateway(shared), config)


def _header(request: Request, name: StringSlice) -> Optional[String]:
    """Return a copy of the first value of a header field, or None."""
    var found = request.header(name)
    if not found:
        return None
    return String(found.value())
