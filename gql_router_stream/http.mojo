# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL over HTTP answers of a router that streams.

Port of the response modes of `graphql_request_handler` and
`execute_pipeline` of Hive Router `1a29df9` `bin/router/src/pipeline/mod.rs`,
`handle_pipeline_error` of `pipeline/error.rs`, and
`SharedRouterStreamResponse::into_response` of `shared_state.rs`.

`answer_request` negotiates the response mode of the `Accept` header,
decodes the request, and runs it:

- A subscription needs `subscriptions.enabled` and a stream type in the
  `Accept` header; otherwise it fails with `SUBSCRIPTIONS_NOT_SUPPORTED`.
  It is a stream of the negotiated type, SSE, incremental delivery or
  Apollo multipart HTTP, with one result for each subgraph event.
- A query or a mutation with `@defer` is a stream when the client accepts
  one; see `gql_router_stream.defer`.
- Another query or mutation is one response of the negotiated single
  type. A client that accepts only a stream gets `UNSUPPORTED_CONTENT_TYPE`.
- An error is one JSON response, or, when the client accepts only a
  stream, status 200 and a stream of the one error, as upstream.
"""

from std.memory import ArcPointer

from gql_http.status import Method
from gql_router.exec_http import SubgraphTransport
from gql_router.pipeline import PipelineError, client_error
from gql_router.router_server import (
    GraphQLParams,
    read_get_params,
    read_post_params,
)
from gql_router_stream.defer import DeferredResponse, has_defer
from gql_router_stream.encode import StreamFormat
from gql_router_stream.negotiate import (
    ResponseMode,
    StreamContentType,
    negotiate,
)
from gql_router_stream.subscription import (
    RouterSubscription,
    StreamHub,
    open_subscription,
)


struct StreamAnswer[T: SubgraphTransport](Movable):
    """One response: a single body, or a stream.

    Parameters:
        T: The transport of the router.
    """

    var status: Int
    """The HTTP status code."""
    var content_type: String
    """The `Content-Type` of the response."""
    var body: List[UInt8]
    """The single body, or the first results of a stream, framed."""
    var is_stream: Bool
    """Whether more content follows `body`."""
    var format: StreamFormat
    """The framing of a stream."""
    var subscription: Optional[RouterSubscription[Self.T]]
    """The results of a subscription."""
    var deferred: Optional[DeferredResponse]
    """The payloads of an operation with `@defer`."""

    def __init__(
        out self, status: Int, var content_type: String, var body: List[UInt8]
    ):
        """Make a single answer.

        Args:
            status: The HTTP status code.
            content_type: The response type.
            body: The body.
        """
        self.status = status
        self.content_type = content_type^
        self.body = body^
        self.is_stream = False
        self.format = StreamFormat(StreamContentType.SSE)
        self.subscription = None
        self.deferred = None

    @staticmethod
    def stream(format: StreamFormat) -> Self:
        """Make the answer of a stream, with no content yet.

        Args:
            format: The framing.

        Returns:
            A 200 answer of the stream type.
        """
        var answer = Self(200, String(format.content_type()), List[UInt8]())
        answer.is_stream = True
        answer.format = format
        return answer^


def _errors_answer[
    T: SubgraphTransport
](error: PipelineError, mode: ResponseMode) -> StreamAnswer[T]:
    """Answer a pipeline error, as upstream `handle_pipeline_error`."""
    var body = List[UInt8](error.body().as_bytes())
    if mode.stream_only():
        var answer = StreamAnswer[T].stream(StreamFormat(mode.stream))
        answer.format.result(answer.body, Span(body))
        answer.format.end(answer.body)
        answer.is_stream = False
        return answer^
    return StreamAnswer[T](
        error.status_code(mode.prefer_status_ok_for_errors()),
        String(mode.single),
        body^,
    )


def answer_request[
    T: SubgraphTransport
](
    hub: ArcPointer[StreamHub[T]],
    method: Method,
    query_string: StringSlice,
    content_type: Optional[String],
    accept: StringSlice,
    var body: List[UInt8],
) -> StreamAnswer[T]:
    """Answer one GraphQL request of a router that streams.

    Args:
        hub: The router and its subgraph streams.
        method: The request method.
        query_string: The text after `?` of the target.
        content_type: The `Content-Type` value, when there is one.
        accept: The `Accept` value, or empty.
        body: The request content.

    Returns:
        The answer. A stream answer that `is_stream` has more content, and
        its `subscription` or `deferred` makes it.

    Parameters:
        T: The transport of the router.
    """
    var mode: ResponseMode
    try:
        mode = negotiate(accept)
    except error:
        return _errors_answer[T](error, ResponseMode.json())
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
        if has_defer(query):
            var deferred = DeferredResponse.start(
                hub[].router,
                query,
                operation_name,
                params^.take_variables(),
                root,
                method == Method.GET,
                mode.can_stream(),
            )
            if not mode.can_stream():
                return StreamAnswer[T](
                    200, String(mode.single), deferred.initial.copy()
                )
            var format = StreamFormat(mode.stream)
            if mode.stream == StreamContentType.APOLLO_MULTIPART_HTTP:
                format = StreamFormat(StreamContentType.INCREMENTAL_DELIVERY)
            var answer = StreamAnswer[T].stream(format)
            answer.deferred = deferred^
            return answer^
        var streams = hub[].config.enabled and mode.can_stream()
        var prepared = hub[].router.prepare_request(
            query,
            operation_name,
            params^.take_variables(),
            root,
            method == Method.GET,
            streams,
        )
        if prepared.is_subscription():
            var answer = StreamAnswer[T].stream(StreamFormat(mode.stream))
            answer.subscription = open_subscription(hub, prepared)
            return answer^
        if not mode.can_single():
            raise client_error(
                "Content-Type header is not supported",
                "UNSUPPORTED_CONTENT_TYPE",
                415,
            )
        var response = hub[].router.run_prepared(prepared)
        var status = response.status
        return StreamAnswer[T](
            status, String(mode.single), response^.take_body()
        )
    except error:
        return _errors_answer[T](error, mode)
