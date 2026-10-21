# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The standalone HTTP server: Apollo Server over `gql_http`.

Port of Apollo Server 5.5.1 `standalone/index.ts`
(`startStandaloneServer`), with the parts of its MIT middleware that it
uses: the default `cors()` of `cors` 2.8.6, `bodyParser.json` of
`body-parser` 2.3.0 with the charset check of Apollo Server, the way
Node.js `node:http` joins repeated header fields, and the production
page of `finalhandler` 2.1.1.

The server answers every path, as upstream. Each request goes through the
CORS headers, the JSON body parser and `execute_http_graphql_request`.

**Differences from upstream.**
- The server runs in `gql_http` worker processes, not in one Node.js
  process. Each worker has its own copy of the caches.
- A body parser error gets the production page of `finalhandler`, such
  as `<pre>Bad Request</pre>`. Upstream shows the stack when `NODE_ENV`
  is not `production`.
- The body must be UTF-8. A `utf-16` or `utf-32` charset gets 415, where
  upstream decodes it, and bytes that are not UTF-8 get 400.
- A body over 50 MiB gets the 413 response of `gql_http`.
- A `multipart/mixed` response of incremental delivery is held: its first
  part goes out at once, and the loop of `gql_http` polls the later parts
  each `ServerConfig.stream_poll_ms`. A client that goes away closes the
  results.
"""

from std.memory import ArcPointer

from gql_execution.value import Values
from gql_http.body import BodyPoll
from gql_http.parser import Request
from gql_http.server import (
    Handler,
    ResponseWriter,
    ServerConfig,
    WorkerPool,
    start_workers,
)
from gql_http.status import Status
from gql_json.parser import parse_bytes
from gql_json.value import JsonDocument
from gql_server.http_types import HTTPGraphQLRequest, HeaderMap, lower_ascii
from gql_server.incremental import IncrementalResults
from gql_server.negotiator import media_type_parameter, mime_essence
from gql_server.plugin import ServerPlugin
from gql_server.server import ApolloServer, ContextFunction, default_context

comptime MAX_BODY_BYTES = 50 * 1024 * 1024
"""The body limit of upstream: `limit: '50mb'`."""

comptime _SINGLE_FIELDS: Array[StaticString, 17] = [
    "age",
    "authorization",
    "content-length",
    "content-type",
    "etag",
    "expires",
    "from",
    "host",
    "if-modified-since",
    "if-unmodified-since",
    "last-modified",
    "location",
    "max-forwards",
    "proxy-authorization",
    "referer",
    "retry-after",
    "user-agent",
]


def _is_single_field(name: String) -> Bool:
    """Whether Node.js keeps only the first field with a name."""
    var names = materialize[_SINGLE_FIELDS]()
    var index = 0
    while index < 17 and names[index] != name:
        index += 1
    return index < 17


def request_headers(request: Request) -> HeaderMap:
    """Read the header fields of a request as Node.js `req.headers` and
    upstream join them.

    A repeated field is joined with `, `, and `cookie` with `; `. Node.js
    keeps only the first of a repeated `content-type`, `host` and the
    other fields that can have one value.

    Args:
        request: The request.

    Returns:
        The fields, with lowercase names.
    """
    var out = HeaderMap()
    var index = 0
    while index < request.header_count():
        var raw = request.header_name(index)
        var at = out.find(raw)
        if at < 0:
            out.names.append(lower_ascii(raw))
            out.values.append(String(request.header_value(index)))
        elif not _is_single_field(out.names[at]):
            out.values[at] += "; " if out.names[at] == "cookie" else ", "
            out.values[at] += request.header_value(index)
        index += 1
    return out^


def _error_page(mut response: ResponseWriter, status: Int) raises:
    """Write the production page of `finalhandler`."""
    var code = Status(status)
    response.set_status(code)
    response.add_header("Content-Security-Policy", "default-src 'none'")
    response.add_header("X-Content-Type-Options", "nosniff")
    response.add_header("Content-Type", "text/html; charset=utf-8")
    response.write_text(
        '<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
        "<title>Error</title>\n</head>\n<body>\n<pre>"
        + String(code.reason())
        + "</pre>\n</body>\n</html>\n"
    )


def _is_json_space(byte: UInt8) -> Bool:
    return byte == 32 or byte == 9 or byte == 10 or byte == 13


def read_json_body(
    request: Request, headers: HeaderMap, mut body: HTTPGraphQLRequest
) -> Int:
    """Read the content of a request as `bodyParser.json` reads it.

    Args:
        request: The request.
        headers: Its fields, as `request_headers` reads them.
        body: The request to fill; its `body` gets the JSON value.

    Returns:
        0 when the body is read or skipped, or the status of the error:
        400 for JSON that is not an object or an array, 415 for a charset
        that is not UTF-8.
    """
    if request.content_length < 0 and not request.chunked:
        return 0
    var content_type = headers.get("content-type")
    if not content_type:
        return 0
    var essence = mime_essence(content_type.value())
    if not essence or essence.value() != "application/json":
        return 0
    var charset = lower_ascii(
        media_type_parameter(content_type.value(), "charset").or_else("utf-8")
    )
    if charset != "utf-8":
        # Upstream reads the other UTF charsets; see the module docstring.
        return 415
    var bytes = request.body()
    if len(bytes) == 0:
        body.body = JsonDocument()
        body.body.root = body.body.add_object()
        return 0
    var first = 0
    while first < len(bytes) and _is_json_space(bytes[first]):
        first += 1
    if first == len(bytes) or (bytes[first] != 123 and bytes[first] != 91):
        return 400
    try:
        var copy = List[UInt8](capacity=len(bytes))
        copy.extend(bytes)
        body.body = parse_bytes(copy^)
    except:
        return 400
    return 0


struct StandaloneHandler[P: ServerPlugin](Handler):
    """The `gql_http` handler of the standalone server.

    Parameters:
        P: The type of the plugins.
    """

    var server: ApolloServer[Self.P]
    """The GraphQL server."""
    var context: ContextFunction
    """The context function."""
    var held_ids: List[Int]
    """The connections of the held `multipart/mixed` responses."""
    var held: List[ArcPointer[IncrementalResults]]
    """The results of each held response, in the order of `held_ids`."""

    def __init__(
        out self,
        var server: ApolloServer[Self.P],
        context: ContextFunction = default_context,
    ):
        """Make a handler.

        Args:
            server: The GraphQL server, started.
            context: The context function.
        """
        self.server = server^
        self.context = context
        self.held_ids = List[Int]()
        self.held = List[ArcPointer[IncrementalResults]]()

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer a request: CORS, the JSON body, then the GraphQL server.

        Args:
            request: The request.
            response: The response.

        Raises:
            HttpError: When a header field of the response is not valid.
        """
        response.add_header("Access-Control-Allow-Origin", "*")
        var method = String(request.method_text()).upper()
        var headers = request_headers(request)
        if method == "OPTIONS":
            response.add_header(
                "Access-Control-Allow-Methods", "GET,HEAD,PUT,PATCH,POST,DELETE"
            )
            response.add_header("Vary", "Access-Control-Request-Headers")
            var asked = headers.get("access-control-request-headers")
            if asked:
                response.add_header(
                    "Access-Control-Allow-Headers", asked.value()
                )
            response.set_status(Status(204))
            return
        var http_request = HTTPGraphQLRequest(method)
        var failed = read_json_body(request, headers, http_request)
        if failed != 0:
            _error_page(response, failed)
            return
        var query = request.query()
        if query.byte_length() > 0:
            http_request.search = "?" + String(query)
        http_request.headers = headers^
        var answer = self.server.execute_http_graphql_request(
            http_request^, self.context
        )
        response.set_status(
            Status(answer.status if answer.status != 0 else 200)
        )
        var index = 0
        while index < len(answer.headers):
            response.add_header(
                answer.headers.names[index], answer.headers.values[index]
            )
            index += 1
        response.write_text(answer.body)
        if answer.chunks:
            # The first part goes out now; the loop polls the later parts.
            response.begin_chunked()
            response.hold()
            # `hold` holds every response but a HEAD response, and
            # `ApolloServer` answers HEAD with 405 and no parts.
            self.held_ids.append(response.connection())
            self.held.append(answer.chunks.value())

    def _find(self, id: Int) -> Int:
        """Return the index of the held response of a connection, or -1."""
        var index = 0
        while index < len(self.held_ids):
            if self.held_ids[index] == id:
                return index
            index += 1
        return -1

    def _release(mut self, index: Int):
        """Forget a held response."""
        var last = len(self.held_ids) - 1
        self.held_ids[index] = self.held_ids[last]
        self.held[index] = self.held[last].copy()
        _ = self.held_ids.pop()
        _ = self.held.pop()

    def poll_body(mut self, id: Int, mut out: List[UInt8]) -> BodyPoll:
        """Write the next parts of a `multipart/mixed` response.

        Args:
            id: The connection of the response.
            out: Gets the bytes of the parts.

        Returns:
            What `ApolloServer.poll_chunk` returns; `DONE` for a
            connection with no held response.
        """
        var index = self._find(id)
        if index < 0:
            return BodyPoll.DONE
        var result = self.server.poll_chunk(self.held[index], out)
        if result == BodyPoll.DONE or result == BodyPoll.ERROR:
            self._release(index)
        return result

    def body_closed(mut self, id: Int):
        """Stop the results of a response whose client went away.

        Args:
            id: The connection of the response.
        """
        var index = self._find(id)
        if index >= 0:
            self.held[index][].close()
            self._release(index)


struct StandaloneServer(Movable):
    """A running standalone server: the result of upstream
    `startStandaloneServer`."""

    var url: String
    """The URL of the server, such as `http://localhost:4000/`."""
    var pool: WorkerPool
    """The worker processes."""

    def __init__(out self, var url: String, var pool: WorkerPool):
        """Hold a running server.

        Args:
            url: Its URL.
            pool: Its workers.
        """
        self.url = url^
        self.pool = pool^

    def stop(mut self, timeout_ms: Int = 10000) -> Int:
        """Stop the workers, with a graceful shutdown.

        Args:
            timeout_ms: How long to wait for the workers.

        Returns:
            What `WorkerPool.stop` returns.
        """
        return self.pool.stop(timeout_ms)


def start_standalone_server[
    P: ServerPlugin
](
    var server: ApolloServer[P],
    var config: ServerConfig = ServerConfig(),
    context: ContextFunction = default_context,
) raises -> StandaloneServer:
    """Start the server and serve it over HTTP: upstream
    `startStandaloneServer`.

    Parameters:
        P: The type of the plugins.

    Args:
        server: The GraphQL server; it must not be started.
        config: The `gql_http` configuration; port 4000 by default. The
            body limit becomes 50 MiB, as upstream.
        context: The context function.

    Returns:
        The running server and its URL.

    Raises:
        Error: When the server cannot start, or the port cannot be opened.
    """
    server.start()
    config.limits.max_body_bytes = MAX_BODY_BYTES
    var pool = start_workers(StandaloneHandler[P](server^, context), config)
    var url = "http://localhost:" + String(pool.port) + "/"
    return StandaloneServer(url^, pool^)
