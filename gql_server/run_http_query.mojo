# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Run a GraphQL request that came over HTTP, and batches of them.

Port of Apollo Server 5.5.1 `runHttpQuery.ts` (`runHttpQuery` and its
checks of the request), `httpBatching.ts`
(`runPotentiallyBatchedHttpQuery`, `runBatchedHttpQuery`),
`preventCsrf.ts`, and `MEDIA_TYPES` and
`chooseContentTypeForSingleResultResponse` of `ApolloServer.ts`. The
query string is read as the WHATWG `URLSearchParams` reads it.

**Differences from upstream.**
- The operations of a batch run one after the other, not at the same
  time. When two of them fail with `BAD_REQUEST`, the first one in the
  batch gives the error; upstream gives the first one to fail.
- The first part of a `multipart/mixed` body is `HTTPGraphQLResponse.body`.
  The server writes the later parts from `HTTPGraphQLResponse.chunks`.
- `stringifyResult` is not an option: the content is always upstream
  `prettyJSONStringify`.
"""

from gql_execution.value import Values
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE as NO_JSON
from gql_json.value import JsonDocument, JsonKind
from gql_server.errors import (
    ServerError,
    bad_request_error,
    ensure_graphql_error,
)
from gql_server.http_types import (
    HTTPGraphQLHead,
    HTTPGraphQLRequest,
    HTTPGraphQLResponse,
    HeaderMap,
)
from gql_server.incremental import (
    BATCH_NOT_SUPPORTED_MESSAGE,
    MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2,
    MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9,
    MULTIPART_MIXED_NO_DEFER_SPEC,
    NOT_ACCEPTED_MESSAGE,
    first_part,
)
from gql_server.negotiator import mime_essence, preferred_media_type
from gql_server.plugin import ServerPlugin
from gql_server.request_pipeline import (
    ServerInternals,
    internal_execute_operation,
    js_truthy,
)
from gql_server.types import (
    GraphQLRequest,
    GraphQLResponse,
    pretty_json_stringify,
)

comptime APPLICATION_JSON = "application/json; charset=utf-8"
"""`MEDIA_TYPES.APPLICATION_JSON`."""
comptime APPLICATION_JSON_GRAPHQL_CALLBACK = (
    "application/json; callbackSpec=1.0; charset=utf-8"
)
"""`MEDIA_TYPES.APPLICATION_JSON_GRAPHQL_CALLBACK`."""
comptime APPLICATION_GRAPHQL_RESPONSE_JSON = (
    "application/graphql-response+json; charset=utf-8"
)
"""`MEDIA_TYPES.APPLICATION_GRAPHQL_RESPONSE_JSON`."""
comptime TEXT_HTML = "text/html"
"""`MEDIA_TYPES.TEXT_HTML`."""

comptime NON_PREFLIGHTED_CONTENT_TYPES = (
    "application/x-www-form-urlencoded, multipart/form-data, text/plain"
)
"""The content types that a browser sends without a preflight, joined as
the CSRF message writes them."""


def choose_content_type_for_single_result_response(
    headers: HeaderMap,
) -> Optional[String]:
    """Choose the content type of a response from the `accept` field:
    upstream `chooseContentTypeForSingleResultResponse`.

    Args:
        headers: The fields of the request.

    Returns:
        `application/json; charset=utf-8` without an `accept` field, else
        the type that `accept` prefers, or None when it takes none.
    """
    return _choose_content_type(headers.get("accept"))


def _negotiate(
    mut internals: ServerInternals, accept: Optional[String]
) -> Optional[String]:
    """`_choose_content_type`, with the last answer kept: clients send the
    same `accept` field again and again."""
    if (
        accept
        and internals.accept_memo
        and (internals.accept_memo.value() == accept.value())
    ):
        return internals.accept_memo_result.copy()
    var result = _choose_content_type(accept)
    internals.accept_memo = accept.copy()
    internals.accept_memo_result = result.copy()
    return result^


def _choose_content_type(accept: Optional[String]) -> Optional[String]:
    if not accept or accept.value().byte_length() == 0:
        return String(APPLICATION_JSON)
    var available: List[String] = [
        APPLICATION_JSON,
        APPLICATION_GRAPHQL_RESPONSE_JSON,
        APPLICATION_JSON_GRAPHQL_CALLBACK,
    ]
    return preferred_media_type(accept, available)


def prefers_html(request: HTTPGraphQLRequest) -> Bool:
    """Return True for a `GET` whose `accept` field prefers HTML: upstream
    `prefersHTML`.

    Args:
        request: The request.

    Returns:
        Whether to answer with the landing page.
    """
    var accept = request.headers.get("accept")
    if request.method != "GET" or not accept:
        return False
    if accept.value().byte_length() == 0:
        return False
    var available: List[String] = [
        APPLICATION_JSON,
        APPLICATION_GRAPHQL_RESPONSE_JSON,
        MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2,
        MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9,
        MULTIPART_MIXED_NO_DEFER_SPEC,
        TEXT_HTML,
    ]
    var preferred = preferred_media_type(accept, available)
    return preferred and preferred.value() == TEXT_HTML


def prevent_csrf(
    headers: HeaderMap, request_headers: List[String]
) raises ServerError:
    """Refuse a request that a browser could send without a CORS
    preflight: upstream `preventCsrf`.

    A request passes when its `content-type` is not a MIME type, or is not
    `application/x-www-form-urlencoded`, `multipart/form-data` or
    `text/plain`; or when one of `request_headers` has a value.

    Args:
        headers: The fields of the request.
        request_headers: The names of the fields that prove a preflight.

    Raises:
        ServerError: `BAD_REQUEST` with the upstream message, when the
            request does not pass.
    """
    var content_type = headers.get("content-type")
    if content_type:
        var essence = mime_essence(content_type.value())
        if not essence:
            return
        var name = essence.value()
        if (
            name != "application/x-www-form-urlencoded"
            and name != "multipart/form-data"
            and name != "text/plain"
        ):
            return
    var index = 0
    while index < len(request_headers):
        var value = headers.get(request_headers[index])
        if value and value.value().byte_length() > 0:
            return
        index += 1
    var names = String("")
    index = 0
    while index < len(request_headers):
        names += (", " if index > 0 else "") + request_headers[index]
        index += 1
    raise bad_request_error(
        "This operation has been blocked as a potential Cross-Site Request"
        " Forgery (CSRF). Please either specify a 'content-type' header"
        " (with a type that is not one of "
        + NON_PREFLIGHTED_CONTENT_TYPES
        + ") or provide a non-empty value for one of the following headers: "
        + names
        + "\n"
    )


@fieldwise_init
struct SearchParam(Copyable, Movable):
    """One pair of a query string, decoded."""

    var name: String
    """The name."""
    var value: String
    """The value."""


def _hex(byte: UInt8) -> Int:
    if byte >= 48 and byte <= 57:
        return Int(byte) - 48
    var lower = byte | 32
    if lower >= 97 and lower <= 102:
        return Int(lower) - 87
    return -1


def _decode(text: Span[UInt8, _]) -> String:
    """Percent-decode a part of a query string, with `+` as a space, as
    the WHATWG URL standard does: a bad escape stays as it is, and bytes
    that are not UTF-8 become U+FFFD."""
    var out = List[UInt8](capacity=len(text))
    var index = 0
    while index < len(text):
        var byte = text[index]
        if byte == 43:
            out.append(32)
        elif (
            byte == 37
            and index + 2 < len(text)
            and _hex(text[index + 1]) >= 0
            and _hex(text[index + 2]) >= 0
        ):
            out.append(
                UInt8(_hex(text[index + 1]) * 16 + _hex(text[index + 2]))
            )
            index += 2
        else:
            out.append(byte)
        index += 1
    return String(from_utf8_lossy=out)


def search_params(search: StringSlice) -> List[SearchParam]:
    """Read a query string: WHATWG `new URLSearchParams(search)`.

    Args:
        search: The query string, with or without its `?`.

    Returns:
        The pairs, in order; empty pairs are skipped.
    """
    var bytes = search.as_bytes()
    var start = 1 if len(bytes) > 0 and bytes[0] == 63 else 0
    var out = List[SearchParam]()
    while start <= len(bytes):
        var end = start
        while end < len(bytes) and bytes[end] != 38:
            end += 1
        if end > start:
            var equals = start
            while equals < end and bytes[equals] != 61:
                equals += 1
            var value_start = min(equals + 1, end)
            out.append(
                SearchParam(
                    _decode(bytes[start:equals]),
                    _decode(bytes[value_start:end]),
                )
            )
        start = end + 1
    return out^


def _is_record(json: JsonDocument, node: Int) -> Bool:
    """Upstream `isStringRecord`: an object that is not an array."""
    return node != NO_JSON and json.kind(node) == JsonKind.OBJECT


def _post_request(
    var http: HTTPGraphQLRequest,
) raises ServerError -> GraphQLRequest:
    """Read the request of a `POST` from its JSON content."""
    var out = GraphQLRequest()
    swap(out.json, http.body)
    ref json = out.json
    var body = json.root
    if not _is_record(json, body) or json.length(body) == 0:
        raise bad_request_error(
            "POST body missing, invalid Content-Type, or JSON object has no"
            " keys."
        )
    var query = json.find(body, "query")
    var kind = json.kind(query) if query != NO_JSON else JsonKind.NULL
    if kind != JsonKind.STRING and js_truthy(json, query):
        if kind == JsonKind.OBJECT and _is_document(json, query):
            raise bad_request_error(
                "GraphQL queries must be strings. It looks like you're sending"
                " the internal graphql-js representation of a parsed query in"
                " your request instead of a request in the GraphQL query"
                " language. You can convert an AST to a string using the"
                " `print` function from `graphql`, or use a client like"
                " `apollo-client` which converts the internal representation"
                " to a string for you."
            )
        raise bad_request_error("GraphQL queries must be strings.")
    var variables = json.find(body, "variables")
    var extensions = json.find(body, "extensions")
    var operation_name = json.find(body, "operationName")
    if _kind_is(json, variables, JsonKind.STRING):
        raise bad_request_error(
            "`variables` in a POST body should be provided as an object, not"
            " a recursively JSON-encoded string."
        )
    if _kind_is(json, extensions, JsonKind.STRING):
        raise bad_request_error(
            "`extensions` in a POST body should be provided as an object, not"
            " a recursively JSON-encoded string."
        )
    if _present_not_null(json, extensions) and not _is_record(json, extensions):
        raise bad_request_error(
            "`extensions` in a POST body must be an object if provided."
        )
    if _present_not_null(json, variables) and not _is_record(json, variables):
        raise bad_request_error(
            "`variables` in a POST body must be an object if provided."
        )
    if _present_not_null(json, operation_name) and not _kind_is(
        json, operation_name, JsonKind.STRING
    ):
        raise bad_request_error(
            "`operationName` in a POST body must be a string if provided."
        )
    if kind == JsonKind.STRING:
        out.query = json.string_value(query)
    if _kind_is(json, operation_name, JsonKind.STRING):
        out.operation_name = json.string_value(operation_name)
    if _is_record(json, variables):
        out.variables = variables
    if _is_record(json, extensions):
        out.extensions = extensions
    out.http = http^
    return out^


def _kind_is(json: JsonDocument, node: Int, kind: JsonKind) -> Bool:
    return node != NO_JSON and json.kind(node) == kind


def _present_not_null(json: JsonDocument, node: Int) -> Bool:
    return node != NO_JSON and json.kind(node) != JsonKind.NULL


def _is_document(json: JsonDocument, node: Int) -> Bool:
    """Whether an object has `kind` equal to `"Document"`."""
    var kind = json.find(node, "kind")
    return _kind_is(json, kind, JsonKind.STRING) and (
        json.string_value(kind) == "Document"
    )


def _once(
    params: List[SearchParam], name: StringSlice
) raises ServerError -> Optional[String]:
    """Upstream `searchParamIfSpecifiedOnce`."""
    var found = Optional[String](None)
    for ref param in params:
        if param.name == name:
            if found:
                raise bad_request_error(
                    "The '"
                    + String(name)
                    + "' search parameter may only be specified once."
                )
            found = param.value.copy()
    return found^


def _json_once(
    params: List[SearchParam], name: StringSlice, mut json: JsonDocument
) raises ServerError -> Int:
    """Upstream `jsonParsedSearchParamIfSpecifiedOnce`: the parsed object
    in `json`, or `NO_JSON`."""
    var text = _once(params, name)
    if not text:
        return NO_JSON
    var parsed: JsonDocument
    try:
        parsed = parse_json(text.value())
    except:
        raise bad_request_error(
            "The " + String(name) + " search parameter contains invalid JSON."
        )
    if not _is_record(parsed, parsed.root):
        raise bad_request_error(
            "The "
            + String(name)
            + " search parameter should contain a JSON-encoded object."
        )
    return json.add_copy(parsed, parsed.root)


def _get_request(
    var http: HTTPGraphQLRequest,
) raises ServerError -> GraphQLRequest:
    """Read the request of a `GET` from its query string."""
    var content_type = http.headers.get("content-type")
    if content_type:
        var essence = mime_essence(content_type.value())
        if not essence or essence.value() != "application/json":
            raise bad_request_error(
                (
                    "GET requests may not have a content-type header other than"
                    " application/json."
                ),
                HTTPGraphQLHead(415),
            )
    var params = search_params(http.search)
    var out = GraphQLRequest(_once(params, "query"))
    out.operation_name = _once(params, "operationName")
    out.variables = _json_once(params, "variables", out.json)
    out.extensions = _json_once(params, "extensions", out.json)
    http.body = JsonDocument()
    out.http = http^
    return out^


def _incremental_response(
    var response: GraphQLResponse, accept: Optional[String]
) raises ServerError -> HTTPGraphQLResponse:
    """The `chunked` response of an `incremental` body: the end of upstream
    `runHttpQuery`, with the first part of `writeMultipartBody`."""
    var available: List[String] = [
        MULTIPART_MIXED_NO_DEFER_SPEC,
        MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9,
        MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2,
    ]
    var preferred = preferred_media_type(accept, available)
    if (
        not accept
        or not preferred
        or (
            preferred.value() != MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2
            and preferred.value() != MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9
        )
    ):
        raise bad_request_error(NOT_ACCEPTED_MESSAGE, HTTPGraphQLHead(406))
    # The parameter of the media type, after `multipart/mixed; `.
    var spec = (
        "deferSpec=20220824" if preferred.value()
        == MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2 else "incrementalSpec=v0.2"
    )
    response.http.headers.set(
        "content-type", 'multipart/mixed; boundary="-"; ' + spec
    )
    var initial = response.to_json()
    var has_next = initial.find('"hasNext":false') < 0
    var head = HTTPGraphQLHead()
    swap(head, response.http)
    var out = HTTPGraphQLResponse(head^, first_part(initial, has_next))
    swap(out.chunks, response.subsequent_results)
    return out^


def run_http_query[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    var http_request: HTTPGraphQLRequest,
    mut values: Values,
    context_value: Int,
    var head: HTTPGraphQLHead,
    request_is_batched: Bool,
) raises ServerError -> HTTPGraphQLResponse:
    """Run one GraphQL request of an HTTP request: upstream
    `runHttpQuery`.

    Parameters:
        P: The type of the plugins.

    Args:
        internals: The configuration and the caches of the server.
        plugin: The plugins.
        http_request: The HTTP request; `body` is its JSON content.
        values: The arena of the context value.
        context_value: The context value.
        head: The head that the response starts with.
        request_is_batched: Whether the head is shared by a batch.

    Returns:
        The response, with its content type and its JSON content.

    Raises:
        ServerError: `BAD_REQUEST` for a request that is not valid, with
            its status: 400, 405 for another method, 406 when `accept`
            takes no JSON type, 415 for a `GET` with another content
            type; or `Internal server error` when a plugin hook raises.
    """
    var graphql_request: GraphQLRequest
    if http_request.method == "POST":
        graphql_request = _post_request(http_request^)
    elif http_request.method == "GET":
        graphql_request = _get_request(http_request^)
    else:
        var http = HTTPGraphQLHead(405)
        http.headers.set("allow", "GET, POST")
        raise bad_request_error(
            "Apollo Server supports only GET/POST requests.", http^
        )
    var accept = graphql_request.http.value().headers.get("accept")
    var response: GraphQLResponse
    try:
        response = internal_execute_operation(
            internals,
            plugin,
            graphql_request^,
            head^,
            values,
            context_value,
            request_is_batched,
        )
    except e:
        raise ensure_graphql_error(e)
    if response.is_incremental():
        return _incremental_response(response^, accept)
    if not response.http.headers.has("content-type"):
        var content_type = _negotiate(internals, accept)
        if not content_type:
            raise bad_request_error(
                "An 'accept' header was provided for this request which does"
                " not accept "
                + APPLICATION_JSON
                + " or "
                + APPLICATION_GRAPHQL_RESPONSE_JSON,
                HTTPGraphQLHead(406),
            )
        response.http.headers.set("content-type", content_type.value())
    var body = pretty_json_stringify(response.to_json())
    var out_head = HTTPGraphQLHead()
    swap(out_head, response.http)
    return HTTPGraphQLResponse(out_head^, body^)


def run_potentially_batched_http_query[
    P: ServerPlugin
](
    mut internals: ServerInternals,
    mut plugin: P,
    var http_request: HTTPGraphQLRequest,
    mut values: Values,
    context_value: Int,
) raises ServerError -> HTTPGraphQLResponse:
    """Run an HTTP request that can hold a batch of operations: upstream
    `runPotentiallyBatchedHttpQuery`.

    A `POST` with a JSON array runs each item as an operation. The items
    share the context value, which each operation copies, and one head.
    The content is the JSON array of their results.

    Parameters:
        P: The type of the plugins.

    Args:
        internals: The configuration and the caches of the server.
        plugin: The plugins.
        http_request: The HTTP request.
        values: The arena of the context value.
        context_value: The context value.

    Returns:
        The response.

    Raises:
        ServerError: As `run_http_query` raises; `Operation batching
            disabled.` for a batch when `allow_batched_http_requests` is
            off; and `No operations found in request.` for an empty one.
    """
    ref body = http_request.body
    if not (
        http_request.method == "POST"
        and body.root != NO_JSON
        and body.kind(body.root) == JsonKind.ARRAY
    ):
        return run_http_query(
            internals,
            plugin,
            http_request^,
            values,
            context_value,
            HTTPGraphQLHead(),
            False,
        )
    if not internals.allow_batched_http_requests:
        raise bad_request_error("Operation batching disabled.")
    if body.length(body.root) == 0:
        raise bad_request_error("No operations found in request.")
    var shared = HTTPGraphQLHead()
    var text = String("[")
    var item = body.first(body.root)
    while item != NO_JSON:
        var single = HTTPGraphQLRequest(http_request.method)
        single.headers = http_request.headers.copy()
        single.search = http_request.search
        single.body.root = single.body.add_copy(body, item)
        var response = run_http_query(
            internals, plugin, single^, values, context_value, shared^, True
        )
        if response.is_chunked():
            # Upstream throws a plain `Error`: status 500.
            raise ServerError(String(BATCH_NOT_SUPPORTED_MESSAGE))
        if text.byte_length() > 1:
            text += ","
        text += response.body
        shared = HTTPGraphQLHead(response.status)
        swap(shared.headers, response.headers)
        item = body.next(item)
    return HTTPGraphQLResponse(shared^, text + "]")
