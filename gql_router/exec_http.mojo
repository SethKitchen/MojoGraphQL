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
through. `HttpTransport` sends it over `gql_http`, on its own connection,
so the fetches of a `Parallel` node are in flight at the same time. A test
can give its own transport, such as subgraphs that run in the same process.

**Differences from upstream.** The transport is a type parameter, not a
boxed trait object in a map. A transport has no tasks: `start` sends a
request, and `finish` reads the oldest response, so the responses are read
in the order the requests were sent. The operation name is not written into the
query, because this port has no operation name factory. A transport
failure is a `SubgraphFailure` value, not an error type. There is no
compression, no deduplication of in-flight requests, and no TLS.
"""

from gql_http.client import Client, Endpoint, PendingRequest
from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.status import Method
from gql_json.value import JsonDocument
from gql_json.writer import write_string
from gql_router.exec_value import append_span, append_text, write_value


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

    def __init__(
        out self, status: Int, content_type: String, var body: List[UInt8]
    ):
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

    def take_body(deinit self) -> List[UInt8]:
        """Return the body.

        Returns:
            The response body.
        """
        return self.body^

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


trait SubgraphTransport(Deinitable, Movable):
    """What the executor sends each subgraph request through, as upstream
    `SubgraphExecutor`.

    `start` sends a request, and `finish` returns the response of the
    oldest request that is not finished. The executor starts every fetch of
    a `Parallel` node, then finishes each one, so a transport can have
    several requests in flight at once.
    """

    def start(mut self, subgraph: String, query: String, body: List[UInt8]):
        """Send one GraphQL request to a subgraph.

        Args:
            subgraph: The subgraph name.
            query: The operation text that the body holds.
            body: The JSON request body.
        """
        ...

    def finish(mut self) -> SubgraphHttpResponse:
        """Return the response of the oldest request that is not finished.

        The executor calls it once for each `start`.

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
    append_text(body, '{"query":')
    write_string(body, query.as_bytes())
    var first = True
    var index = 0
    while index < len(variable_names):
        if first:
            append_text(body, ',"variables":{')
        else:
            body.append(UInt8(ord(",")))
        first = False
        body.append(UInt8(ord('"')))
        append_text(body, variable_names[index])
        append_text(body, '":')
        write_value(variables, variable_nodes[index], body)
        index += 1
    index = 0
    while index < len(raw_names):
        if first:
            append_text(body, ',"variables":{')
        else:
            body.append(UInt8(ord(",")))
        first = False
        body.append(UInt8(ord('"')))
        append_text(body, raw_names[index])
        append_text(body, '":')
        append_span(body, Span(raw_values[index]))
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
    var in_flight: List[PendingRequest]
    """The requests that were sent, oldest first, whose responses are not
    read."""
    var failures: List[SubgraphHttpResponse]
    """The requests that failed before they were sent, oldest first."""
    var failed: List[Bool]
    """For each request that is not finished, oldest first: whether it is
    in `failures` and not in `in_flight`."""

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
        self.in_flight = List[PendingRequest]()
        self.failures = List[SubgraphHttpResponse]()
        self.failed = List[Bool]()
        var index = 0
        while index < len(urls):
            self.endpoints.append(self.client.endpoint(urls[index]))
            index += 1

    def send(
        mut self, subgraph: String, query: String, body: List[UInt8]
    ) -> SubgraphHttpResponse:
        """Send one request and read its response.

        Args:
            subgraph: The subgraph name.
            query: The operation text that the body holds.
            body: The JSON request body.

        Returns:
            The response, or the failure.
        """
        self.start(subgraph, query, body)
        return self.finish()

    def _fail(mut self, var failure: SubgraphHttpResponse):
        """Queue the result of a request that failed before it was sent."""
        self.failures.append(failure^)
        self.failed.append(True)

    def start(mut self, subgraph: String, query: String, body: List[UInt8]):
        """Send one request on its own connection, as the first half of
        upstream `HTTPSubgraphExecutor::execute`.

        Args:
            subgraph: The subgraph name.
            query: The operation text that the body holds.
            body: The JSON request body.
        """
        var index = 0
        while index < len(self.names) and self.names[index] != subgraph:
            index += 1
        if index == len(self.names):
            self._fail(
                SubgraphHttpResponse.failed(
                    SubgraphFailure.UNKNOWN_SUBGRAPH,
                    "Static endpoint not found for subgraph. This is an"
                    + " internal error and should not happen.",
                )
            )
            return
        try:
            var endpoint = self.endpoints[index].copy()
            var target = endpoint.target
            self.in_flight.append(
                self.client.start(
                    endpoint,
                    Method.POST,
                    target,
                    self.headers,
                    Span(body),
                )
            )
            self.failed.append(False)
        except error:
            self._fail(
                SubgraphHttpResponse.failed(failure_of(error), error.message)
            )

    def finish(mut self) -> SubgraphHttpResponse:
        """Read the response of the oldest request that is not finished.

        Returns:
            The response, or the failure.
        """
        if self.failed.pop(0):
            return self.failures.pop(0)
        try:
            var response = self.client.finish(self.in_flight.pop(0))
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


struct CannedTransport(SubgraphTransport):
    """Answer subgraph requests in the same process with fixed responses.

    Each response is for one subgraph and one query. The first unused
    response that matches is sent; when every match is used, the first
    match is sent again. `reset` makes every response unused.
    """

    var subgraphs: List[String]
    """The subgraph of each response."""
    var queries: List[String]
    """The query of each response."""
    var statuses: List[Int]
    """The HTTP status of each response."""
    var content_types: List[String]
    """The `Content-Type` of each response."""
    var bodies: List[List[UInt8]]
    """The body of each response."""
    var used: List[Bool]
    """Whether each response was sent since the last `reset`."""
    var requests: List[String]
    """Every request body, in the order they came, when `record` is set."""
    var record: Bool
    """Whether to keep the request bodies."""
    var answers: List[SubgraphHttpResponse]
    """The answers that `start` made and `finish` did not return, oldest
    first."""

    def __init__(out self, record: Bool = False):
        """Start with no responses.

        Args:
            record: Whether to keep each request body.
        """
        self.answers = List[SubgraphHttpResponse]()
        self.subgraphs = List[String]()
        self.queries = List[String]()
        self.statuses = List[Int]()
        self.content_types = List[String]()
        self.bodies = List[List[UInt8]]()
        self.used = List[Bool]()
        self.requests = List[String]()
        self.record = record

    def add(
        mut self,
        subgraph: String,
        query: String,
        body: String,
        status: Int = 200,
        content_type: String = "application/json",
    ):
        """Add one response.

        Args:
            subgraph: The subgraph that answers.
            query: The query it answers.
            body: The response body.
            status: The HTTP status.
            content_type: The `Content-Type` value.
        """
        self.subgraphs.append(subgraph)
        self.queries.append(query)
        self.statuses.append(status)
        self.content_types.append(content_type)
        self.bodies.append(List[UInt8](body.as_bytes()))
        self.used.append(False)

    def reset(mut self):
        """Make every response unused, and forget the requests."""
        var index = 0
        while index < len(self.used):
            self.used[index] = False
            index += 1
        self.requests.clear()

    def send(
        mut self, subgraph: String, query: String, body: List[UInt8]
    ) -> SubgraphHttpResponse:
        """Answer one request with its fixed response.

        Args:
            subgraph: The subgraph name.
            query: The operation text that the body holds.
            body: The JSON request body.

        Returns:
            The response, or a `REQUEST_FAILURE` when none matches.
        """
        if self.record:
            self.requests.append(String(unsafe_from_utf8=Span(body)))
        var first = -1
        var index = 0
        while index < len(self.subgraphs):
            if (
                self.subgraphs[index] == subgraph
                and self.queries[index] == query
            ):
                if not self.used[index]:
                    first = index
                    break
                if first < 0:
                    first = index
            index += 1
        if first < 0:
            return SubgraphHttpResponse.failed(
                SubgraphFailure.REQUEST_FAILURE,
                "no canned response for subgraph " + subgraph,
            )
        self.used[first] = True
        var out = SubgraphHttpResponse(
            self.statuses[first],
            self.content_types[first],
            self.bodies[first].copy(),
        )
        out.has_content_type = self.content_types[first].byte_length() > 0
        return out^

    def start(mut self, subgraph: String, query: String, body: List[UInt8]):
        """Answer one request now, and keep the answer for `finish`.

        Args:
            subgraph: The subgraph name.
            query: The operation text that the body holds.
            body: The JSON request body.
        """
        self.answers.append(self.send(subgraph, query, body))

    def finish(mut self) -> SubgraphHttpResponse:
        """Return the answer of the oldest request that is not finished.

        Returns:
            The response, or a `REQUEST_FAILURE` when none matched.
        """
        return self.answers.pop(0)
