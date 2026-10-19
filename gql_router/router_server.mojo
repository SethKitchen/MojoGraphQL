# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Serve the router over HTTP with `gql_http`.

Port of the request decoding of Hive Router `1a29df9`
`bin/router/src/pipeline/execution_request.rs` (`decode_get`,
`decode_post`, `GraphQLPostBodySeed`) and of the response type choice of
`bin/router/src/pipeline/header.rs`.

`RouterHandler` is a `gql_http.server.Handler`. It answers the GraphQL
path, by default `/graphql`. A `GET` reads `query`, `operationName` and
`variables` from the query string. A `POST` must have a JSON
`Content-Type`, and reads the same members from a JSON body. Then
`Router.execute` runs the request. `serve_graphql` does the same work on
plain values, so that a test can call it without a socket.

**Differences from upstream.** There is no CORS, CSRF prevention,
persisted documents, request decompression, multipart, SSE or WebSocket
transport. `extensions` is read and ignored. The response type is
`application/graphql-response+json` when the `Accept` header names it
before `application/json` or `*/*`; otherwise it is `application/json`.
Upstream also answers `406` for an `Accept` header with no supported type.
"""

from gql_http.error import HttpError
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.status import Method, Status
from gql_http.url import QueryParam, parse_query, query_value
from gql_json.parser import parse, parse_bytes
from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.exec_http import SubgraphTransport
from gql_router.exec_value import key_is, string_text
from gql_router.pipeline import (
    PipelineError,
    Router,
    RouterResponse,
    client_error,
)

comptime JSON_TYPE = "application/json"
"""The legacy GraphQL over HTTP response type."""
comptime GRAPHQL_RESPONSE_TYPE = "application/graphql-response+json"
"""The GraphQL over HTTP response type."""


struct GraphQLParams(Movable):
    """The GraphQL members of a request, as upstream `GraphQLParams`."""

    var query: Optional[String]
    """The operation document, when the request has one."""
    var operation_name: Optional[String]
    """The operation to run."""
    var variables: JsonDocument
    """The document that holds the variables."""
    var variables_root: Int
    """The variables object, or `NO_NODE`."""

    def __init__(out self):
        """Start with no members."""
        self.query = None
        self.operation_name = None
        self.variables = JsonDocument()
        self.variables_root = NO_NODE

    def take_variables(deinit self) -> JsonDocument:
        """Return the document that holds the variables.

        Returns:
            The document; `variables_root` is a node of it.
        """
        return self.variables^


def _bad_body() -> PipelineError:
    """Return upstream `FailedToParseBody`."""
    return client_error("Failed to parse GraphQL request payload", "BAD_REQUEST")


def _bad_variables() -> PipelineError:
    """Return upstream `FailedToParseVariables`."""
    return client_error("Failed to parse GraphQL variables JSON", "BAD_REQUEST")


def read_get_params(query_string: StringSlice) raises PipelineError -> GraphQLParams:
    """Read the GraphQL members of a `GET` query string, as upstream
    `decode_get`.

    Args:
        query_string: The text after `?`, without the `?`.

    Returns:
        The members.

    Raises:
        PipelineError: `UNPROCESSABLE_QUERY_PARAMS` for a bad escape, and
            `BAD_REQUEST` when `variables` is not a JSON object or null.
    """
    var params: List[QueryParam]
    try:
        params = parse_query(query_string)
    except:
        raise client_error(
            "Failed to parse query parameters", "UNPROCESSABLE_QUERY_PARAMS"
        )
    var out = GraphQLParams()
    out.query = query_value(params, "query")
    out.operation_name = query_value(params, "operationName")
    var variables = query_value(params, "variables")
    if variables and variables.value().byte_length() > 0:
        try:
            out.variables = parse(variables.value())
        except:
            raise _bad_variables()
        var kind = out.variables.kind(out.variables.root)
        if kind == JsonKind.OBJECT:
            out.variables_root = out.variables.root
        elif kind != JsonKind.NULL:
            raise _bad_variables()
    return out^


def _optional_string(
    document: JsonDocument, node: Int
) raises PipelineError -> Optional[String]:
    """Read a member that is a string or `null`."""
    var kind = document.kind(node)
    if kind == JsonKind.NULL:
        return None
    if kind != JsonKind.STRING:
        raise _bad_body()
    return string_text(document, node)


def read_post_params(
    content_type: Optional[String], var body: List[UInt8]
) raises PipelineError -> GraphQLParams:
    """Read the GraphQL members of a `POST` body, as upstream
    `decode_post` and `GraphQLPostBodySeed`.

    Args:
        content_type: The `Content-Type` value, when the request has one.
        body: The request content.

    Returns:
        The members; the variables stay in the parsed body.

    Raises:
        PipelineError: For a missing or non-JSON `Content-Type`, a body
            that is not one JSON object, a repeated member, or a member of
            the wrong type.
    """
    if not content_type:
        raise client_error(
            "Content-Type header is missing", "MISSING_CONTENT_TYPE_HEADER", 406
        )
    if not (JSON_TYPE in content_type.value()):
        raise client_error(
            "Content-Type header is not supported", "UNSUPPORTED_CONTENT_TYPE", 415
        )
    var out = GraphQLParams()
    try:
        out.variables = parse_bytes(body^)
    except:
        raise _bad_body()
    ref document = out.variables
    if document.kind(document.root) != JsonKind.OBJECT:
        raise _bad_body()
    var seen_query = False
    var seen_name = False
    var seen_variables = False
    var member = document.first(document.root)
    while member != NO_NODE:
        if key_is(document, member, "query"):
            if seen_query:
                raise _bad_body()
            seen_query = True
            out.query = _optional_string(document, member)
        elif key_is(document, member, "operationName"):
            if seen_name:
                raise _bad_body()
            seen_name = True
            out.operation_name = _optional_string(document, member)
        elif key_is(document, member, "variables"):
            if seen_variables:
                raise _bad_body()
            seen_variables = True
            var kind = document.kind(member)
            if kind == JsonKind.OBJECT:
                out.variables_root = member
            elif kind != JsonKind.NULL:
                raise _bad_body()
        member = document.next(member)
    return out^


def prefers_graphql_response(accept: Optional[String]) -> Bool:
    """Return True if the response type is
    `application/graphql-response+json`, as upstream negotiation.

    Args:
        accept: The `Accept` value, when the request has one.

    Returns:
        Whether the GraphQL over HTTP type comes before `application/json`
        and `*/*` in the header.
    """
    if not accept:
        return False
    var text = accept.value()
    var graphql = text.find(GRAPHQL_RESPONSE_TYPE)
    if graphql < 0:
        return False
    var json = text.find(JSON_TYPE)
    var any = text.find("*/*")
    if json >= 0 and json < graphql:
        return False
    return not (any >= 0 and any < graphql)


struct HttpAnswer(Movable):
    """The status, the response type and the body of one request."""

    var status: Int
    """The HTTP status code."""
    var content_type: String
    """The `Content-Type` of the body."""
    var body: List[UInt8]
    """The JSON body."""

    def __init__(out self, status: Int, var content_type: String, var body: List[UInt8]):
        """Hold an answer.

        Args:
            status: The HTTP status code.
            content_type: The response type.
            body: The body.
        """
        self.status = status
        self.content_type = content_type^
        self.body = body^


def serve_graphql[
    T: SubgraphTransport
](
    mut router: Router[T],
    method: Method,
    query_string: StringSlice,
    content_type: Optional[String],
    accept: Optional[String],
    var body: List[UInt8],
) -> HttpAnswer:
    """Answer one GraphQL request, as upstream `graphql_request_handler`.

    Parameters:
        T: The transport to the subgraphs.

    Args:
        router: The router.
        method: The request method.
        query_string: The text after `?` of the target.
        content_type: The `Content-Type` value, when there is one.
        accept: The `Accept` value, when there is one.
        body: The request content.

    Returns:
        The answer.
    """
    var graphql = prefers_graphql_response(accept)
    var response_type = String(GRAPHQL_RESPONSE_TYPE if graphql else JSON_TYPE)
    var response: RouterResponse
    try:
        var params: GraphQLParams
        if method == Method.GET:
            params = read_get_params(query_string)
        elif method == Method.POST:
            params = read_post_params(content_type, body^)
        else:
            raise client_error(
                "Unsupported HTTP method: " + String(method),
                "METHOD_NOT_ALLOWED",
                405,
            )
        if not params.query:
            raise client_error(
                "Missing query parameter: query", "MISSING_QUERY_PARAM"
            )
        var query = params.query.value()
        var operation_name = params.operation_name
        var root = params.variables_root
        response = router.execute(
            query,
            operation_name,
            params^.take_variables(),
            root,
            method == Method.GET,
            not graphql,
        )
    except error:
        response = RouterResponse.from_error(error, not graphql)
    var status = response.status
    return HttpAnswer(status, response_type^, response^.take_body())


struct RouterHandler[T: SubgraphTransport](Handler):
    """The `gql_http` handler of the router.

    Parameters:
        T: The transport to the subgraphs.
    """

    var router: Router[Self.T]
    """The router."""
    var path: String
    """The GraphQL path; other paths answer `404`."""

    def __init__(out self, var router: Router[Self.T], path: String = "/graphql"):
        """Make a handler.

        Args:
            router: The router.
            path: The GraphQL path.
        """
        self.router = router^
        self.path = path

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one HTTP request.

        Args:
            request: The request.
            response: The response.

        Raises:
            HttpError: When the response cannot be written.
        """
        if request.path() != self.path:
            response.error(Status(404))
            return
        var answer = serve_graphql(
            self.router,
            request.method,
            request.query(),
            _header(request, "content-type"),
            _header(request, "accept"),
            List[UInt8](request.body()),
        )
        response.set_status(Status(answer.status))
        response.add_header("Content-Type", answer.content_type)
        response.write(Span(answer.body))


def _header(request: Request, name: StringSlice) -> Optional[String]:
    """Return a copy of the first value of a header field, or None."""
    var found = request.header(name)
    if not found:
        return None
    return String(found.value())
