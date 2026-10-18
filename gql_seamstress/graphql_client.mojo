# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""One GraphQL request over HTTP, as Rover `rover-graphql` sends it.

Port of `GraphQLService::call` of Rover `crates/rover-graphql/src/lib.rs`
and of its `GraphQLServiceError` messages. The body is the graphql_client
`QueryBody`: `variables`, `query`, then `operationName`. A response is
read whatever its status:

- a body that is not JSON is a deserialization error that names the
  status;
- an `errors` list whose messages mention `unauthorized` or `invalid
  credentials` is a credentials error;
- other errors are a partial error when `data` is set, and a no-data
  error when it is not;
- a response with neither `data` nor `errors` is a no-data error.

**Differences from upstream.** Requests use `gql_http`, which speaks
plain `http` only: an `https` URL fails. A failed request is not retried.
The line and column of a deserialization error are where `gql_json`
stops, which can differ from where serde_json stops.
"""

from gql_http.client import Client
from gql_http.error import ErrorKind
from gql_http.headers import Headers
from gql_http.status import Method, Status
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_seamstress.config import Header
from gql_seamstress.output import RoverError, json_string


@fieldwise_init
struct GraphQLResponse(Movable):
    """The outcome of one request: the response data, or the error."""

    var document: JsonDocument
    """The parsed response; empty when it was not JSON."""
    var data: Int
    """The `data` object, or `NO_NODE` when there is an error."""
    var error: Optional[RoverError]
    """The error, or None."""
    var messages: List[String]
    """The `message` of each GraphQL error, for a no-data or partial
    error."""
    var status: Int
    """The HTTP status code; 0 when no response arrived."""


def _reason(code: Int) -> String:
    """Return the canonical reason phrase of the `http` crate."""
    if code == 413:
        return "Payload Too Large"
    if code == 422:
        return "Unprocessable Entity"
    return String(Status(code).reason())


def service_error(cause: String) -> RoverError:
    """Return Rover `RoverClientError::Service` with one cause.

    Args:
        cause: The message of the inner error.

    Returns:
        `Service error`, caused by `cause`.
    """
    var error = RoverError.of("Service error")
    error.causes.append(cause)
    return error^


def request_body(query: StringSlice, operation_name: StringSlice) -> String:
    """Return the JSON body of a query with no variables.

    Args:
        query: The query text.
        operation_name: The operation to run.

    Returns:
        `{"variables":{},"query":...,"operationName":...}`.
    """
    return (
        '{"variables":{},"query":'
        + json_string(query)
        + ',"operationName":'
        + json_string(operation_name)
        + "}"
    )


def _error(
    var document: JsonDocument, var error: RoverError, status: Int
) -> GraphQLResponse:
    """Return a failed response."""
    return GraphQLResponse(document^, NO_NODE, error^, List[String](), status)


def graphql_request(
    mut client: Client,
    url: StringSlice,
    query: StringSlice,
    operation_name: StringSlice,
    headers: List[Header],
) -> GraphQLResponse:
    """Send a query, as Rover `GraphQLService::call`.

    Args:
        client: The HTTP client.
        url: The endpoint.
        query: The query text.
        operation_name: The operation name.
        headers: The extra header fields; one with the name of a default
            field replaces it.

    Returns:
        The `data` of the response, or the Rover error.
    """
    var status = 0
    try:
        var fields = Headers()
        var content_type = String("application/json")
        for ref header in headers:
            if header.name.lower() == "content-type":
                content_type = header.value.copy()
        fields.add("Content-Type", content_type)
        for ref header in headers:
            if header.name.lower() != "content-type":
                fields.add(header.name, header.value)
        var endpoint = client.endpoint(url)
        var target = endpoint.target.copy()
        var body = request_body(query, operation_name)
        var response = client.send(
            endpoint, Method.POST, target, fields, body.as_bytes()
        )
        status = response.status.code
        var text = String(StringSlice(unsafe_from_utf8=response.body()))
        return _read(text, status)
    except e:
        var error = service_error("Upstream service error")
        error.causes.append(
            String("Connect error") if e.kind
            == ErrorKind.CONNECT else e.message.copy()
        )
        return _error(JsonDocument(), error^, status)


def _read(text: String, status: Int) -> GraphQLResponse:
    """Classify a response body, as upstream `GraphQLService::call`."""
    var document: JsonDocument
    try:
        document = parse_json(text)
    except e:
        var category = (
            "unexpected end-of-input" if e.offset
            >= text.byte_length() else "syntax"
        )
        return _error(
            JsonDocument(),
            service_error(
                "Deserialization error: the response (HTTP "
                + String(status)
                + " "
                + _reason(status)
                + ") had a "
                + category
                + " error at line "
                + String(e.line)
                + ", column "
                + String(e.column + 1)
            ),
            status,
        )
    var root = document.root
    if document.kind(root) != JsonKind.OBJECT:
        return _error(
            document^,
            service_error(
                "Deserialization error: the response (HTTP "
                + String(status)
                + " "
                + _reason(status)
                + ") had a data error at line 1, column "
                + String(
                    text.byte_length() - String(text).lstrip().byte_length() + 2
                )
            ),
            status,
        )
    var data = document.find(root, "data")
    if data != NO_NODE and document.kind(data) == JsonKind.NULL:
        data = NO_NODE
    var errors = document.find(root, "errors")
    if errors != NO_NODE and document.kind(errors) == JsonKind.ARRAY:
        var messages = List[String]()
        for item in document.children(errors):
            var message = document.find(item, "message")
            if message != NO_NODE and document.kind(message) == JsonKind.STRING:
                messages.append(document.string_value(message))
        for ref message in messages:
            var lower = message.lower()
            if (
                lower.find("unauthorized") >= 0
                or lower.find("invalid credentials") >= 0
            ):
                return _error(
                    document^,
                    service_error(
                        'Invalid credentials provided. See "Authenticating'
                        ' with GraphOS"'
                        " [https://www.apollographql.com/docs/rover/configuring]."
                    ),
                    status,
                )
        var cause = String("No data field provided")
        if data != NO_NODE:
            cause = "Data was returned, but with errors: " + String(" ").join(
                messages
            )
        var response = _error(document^, service_error(cause), status)
        response.messages = messages^
        return response^
    if data == NO_NODE:
        return _error(
            document^, service_error("No data field provided"), status
        )
    return GraphQLResponse(document^, data, None, List[String](), status)
