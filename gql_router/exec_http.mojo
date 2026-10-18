# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Send subgraph requests: the request body, the transport, and HTTP.

Port of `build_request_body`, `is_valid_graphql_content_type` and the HTTP
part of `HTTPSubgraphExecutor::execute` of Hive Router `1a29df9`
`bin/router/src/executor/executors/http.rs`, and of the
`SubgraphExecutor` trait of `executors/common.rs`.

`SubgraphTransport` is the trait that the executor sends each request
through. `HttpTransport` sends it over `gql_http`. A test can give its own
transport, such as subgraphs that run in the same process.

**Differences from upstream.** The transport is a type parameter, not a
boxed trait object in a map. The operation name is not written into the
query, because this port has no operation name factory. A transport
failure is a `SubgraphFailure` value, not an error type. There is no
compression, no deduplication of in-flight requests, and no TLS.
"""

from gql_http.client import Client, Endpoint
from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.status import Method
from gql_json.value import JsonDocument
from gql_json.writer import write_string
from gql_router.exec_value import write_value


@fieldwise_init
struct SubgraphFailure(Equatable, ImplicitlyCopyable, Movable):
    """Why a subgraph request failed before it had a response."""

    var value: UInt8
    """The failure's index; see `is_valid`."""

    comptime NONE = SubgraphFailure(0)
    """The request has a response."""
    comptime REQUEST_FAILURE = SubgraphFailure(1)
    """The request could not be sent: `SUBREQUEST_HTTP_ERROR`."""
    comptime REQUEST_TIMEOUT = SubgraphFailure(2)
    """The request timed out: `SUBGRAPH_REQUEST_TIMEOUT`."""
    comptime RESPONSE_FAILURE = SubgraphFailure(3)
    """The response could not be read: `SUBGRAPH_RESPONSE_FAILURE`."""
    comptime UNKNOWN_SUBGRAPH = SubgraphFailure(4)
    """No endpoint is known: `SUBGRAPH_STATIC_ENDPOINT_NOT_FOUND`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the five failures.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 4


struct SubgraphHttpResponse(Movable):
    """What a transport returns for one request."""

    var failure: SubgraphFailure
    """`NONE`, or why there is no response."""
    var failure_text: String
    """The description of the failure."""
    var status: Int
    """The HTTP status code."""
    var content_type: String
    """The `Content-Type` value."""
    var has_content_type: Bool
    """Whether the response has a `Content-Type`."""
    var body: List[UInt8]
    """The response body."""

    def __init__(out self, status: Int, content_type: String, var body: List[UInt8]):
        """Make a response.

        Args:
            status: The HTTP status code.
            content_type: The `Content-Type` value.
            body: The body.
        """
        self.failure = SubgraphFailure.NONE
        self.failure_text = String()
        self.status = status
        self.content_type = content_type
        self.has_content_type = True
        self.body = body^

    @staticmethod
    def failed(failure: SubgraphFailure, text: String) -> SubgraphHttpResponse:
        """Make the result of a request that failed.

        Args:
            failure: Why it failed.
            text: The description.

        Returns:
            A result with no response.
        """
        var out = SubgraphHttpResponse(0, String(), List[UInt8]())
        out.has_content_type = False
        out.failure = failure
        out.failure_text = text
        return out^


trait SubgraphTransport(Movable):
    """What the executor sends each subgraph request through, as upstream
    `SubgraphExecutor`."""

    def send(mut self, subgraph: String, var body: List[UInt8]) -> SubgraphHttpResponse:
        """Send one GraphQL request to a subgraph.

        Args:
            subgraph: The subgraph name.
            body: The JSON request body.

        Returns:
            The response, or the failure.
        """
        ...


def build_request_body(
    query: String,
    variable_names: List[String],
    variables: JsonDocument,
    variable_nodes: List[Int],
    raw_names: List[String],
    raw_values: List[List[UInt8]],
) -> List[UInt8]:
    """Write the JSON body of a subgraph request, as upstream
    `build_request_body`.

    Args:
        query: The operation text.
        variable_names: The names of the client variables the fetch uses.
        variables: The document with their values.
        variable_nodes: The value of each name, parallel to the names.
        raw_names: The names of the variables already in JSON form.
        raw_values: Their JSON text, parallel to `raw_names`.

    Returns:
        `{"query":...,"variables":{...}}`; `variables` is left out when
        there are none.
    """
    var body = List[UInt8](capacity=query.byte_length() + 64)
    body.extend('{"query":'.as_bytes())
    write_string(body, query.as_bytes())
    var first = True
    var index = 0
    while index < len(variable_names):
        if first:
            body.extend(',"variables":{'.as_bytes())
        else:
            body.append(UInt8(ord(",")))
        first = False
        body.append(UInt8(ord('"')))
        body.extend(variable_names[index].as_bytes())
        body.extend('":'.as_bytes())
        write_value(variables, variable_nodes[index], body)
        index += 1
    index = 0
    while index < len(raw_names):
        if first:
            body.extend(',"variables":{'.as_bytes())
        else:
            body.append(UInt8(ord(",")))
        first = False
        body.append(UInt8(ord('"')))
        body.extend(raw_names[index].as_bytes())
        body.extend('":'.as_bytes())
        body.extend(Span(raw_values[index]))
        index += 1
    if not first:
        body.append(UInt8(ord("}")))
    body.append(UInt8(ord("}")))
    return body^


def is_valid_graphql_content_type(value: StringSlice) -> Bool:
    """Return True if a `Content-Type` is a GraphQL response type, as
    upstream `is_valid_graphql_content_type`.

    Args:
        value: The header value.

    Returns:
        Whether its essence is `application/json` or
        `application/graphql-response+json`, in any case.
    """
    var essence = String(value)
    var semicolon = essence.find(";")
    if semicolon >= 0:
        var head = String(essence[byte=:semicolon])
        essence = head^
    essence = String(essence.strip()).lower()
    return (
        essence == "application/json"
        or essence == "application/graphql-response+json"
    )


def failure_of(error: HttpError) -> SubgraphFailure:
    """Map a `gql_http` error to a subgraph failure.

    Args:
        error: The transport error.

    Returns:
        `REQUEST_TIMEOUT` for a timeout, `RESPONSE_FAILURE` for a bad or
        too large response, and `REQUEST_FAILURE` otherwise.
    """
    if error.kind == ErrorKind.TIMEOUT:
        return SubgraphFailure.REQUEST_TIMEOUT
    if error.kind == ErrorKind.PROTOCOL or error.kind == ErrorKind.LIMIT:
        return SubgraphFailure.RESPONSE_FAILURE
    return SubgraphFailure.REQUEST_FAILURE


struct HttpTransport(SubgraphTransport):
    """Send subgraph requests over HTTP/1.1 with `gql_http.client`, as
    upstream `HTTPSubgraphExecutor`."""

    var client: Client
    """The client, with its pool of keep-alive connections."""
    var names: List[String]
    """The subgraph names."""
    var endpoints: List[Endpoint]
    """The endpoint of each subgraph, parallel to `names`."""
    var headers: Headers
    """The fields of every request."""

    def __init__(out self, names: List[String], urls: List[String]) raises:
        """Resolve the URL of each subgraph once.

        Args:
            names: The subgraph names.
            urls: The URL of each subgraph, parallel to `names`.

        Raises:
            Error: When a URL is not a valid `http` URL.
        """
        self.client = Client()
        self.names = names.copy()
        self.endpoints = List[Endpoint]()
        self.headers = Headers()
        self.headers.add("content-type", "application/json; charset=utf-8")
        var index = 0
        while index < len(urls):
            self.endpoints.append(self.client.endpoint(urls[index]))
            index += 1

    def send(mut self, subgraph: String, var body: List[UInt8]) -> SubgraphHttpResponse:
        """Send one request, as upstream `HTTPSubgraphExecutor::execute`.

        Args:
            subgraph: The subgraph name.
            body: The JSON request body.

        Returns:
            The response, or the failure.
        """
        var index = 0
        while index < len(self.names) and self.names[index] != subgraph:
            index += 1
        if index == len(self.names):
            return SubgraphHttpResponse.failed(
                SubgraphFailure.UNKNOWN_SUBGRAPH,
                "Static endpoint not found for subgraph. This is an internal"
                + " error and should not happen.",
            )
        try:
            var endpoint = self.endpoints[index].copy()
            var target = endpoint.target
            var response = self.client.send(
                endpoint,
                Method.POST,
                target,
                self.headers,
                Span(body),
            )
            var content_type = response.header("content-type")
            var out = SubgraphHttpResponse(
                response.status.code,
                String(content_type.value()) if content_type else String(),
                List[UInt8](response.body()),
            )
            out.has_content_type = Bool(content_type)
            return out^
        except error:
            return SubgraphHttpResponse.failed(failure_of(error), error.message)
