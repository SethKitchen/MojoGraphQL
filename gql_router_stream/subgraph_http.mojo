# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Subgraph subscriptions over HTTP streaming.

Port of `HTTPSubgraphExecutor::subscribe` of Hive Router `1a29df9`
`bin/router/src/executor/executors/http.rs`, with the errors of
`executor/executors/error.rs`.

`HttpSubscription.open` posts the subscription with
`Accept: multipart/mixed;subscriptionSpec="1.0", text/event-stream` and
reads the head of the response. A status that is not 2xx and a content
type that is not `multipart/mixed` or `text/event-stream` fail, as
upstream. `poll` reads what has arrived without a wait, and parses it with
`gql_router_stream.subgraph_parse`.

**Differences from upstream.** The request and the head are read with a
wait, on the thread of the router; then `poll` does not wait. Each
subscription has its own connection, as upstream, which does not pool a
streamed response.
"""

from gql_http.client import Client, PendingRequest, ResponseStream
from gql_http.headers import Headers
from gql_http.socket import POLLIN
from gql_http.status import Method
from gql_router.graphql_error import error_json
from gql_router.exec_plan import plan_error
from gql_router_stream.subgraph_parse import (
    MultipartParser,
    SseParser,
    parse_boundary_from_header,
)


comptime SUBSCRIPTION_ACCEPT = (
    'multipart/mixed;subscriptionSpec="1.0", text/event-stream'
)
"""The `Accept` header of a subgraph subscription, as upstream."""


struct StreamError(Copyable, Movable, Writable):
    """A failure of a subgraph stream, as upstream
    `SubgraphExecutorError`."""

    var code: String
    """The error code, such as `SUBGRAPH_STREAM_STATUS_CODE_NOT_OK`."""
    var message: String
    """The message."""

    def __init__(out self, code: String, message: String):
        """Make a failure.

        Args:
            code: The error code.
            message: The message.
        """
        self.code = code
        self.message = message

    def body(self, subgraph: String) -> List[UInt8]:
        """Write the event of the failure, as upstream
        `serialize_masked_failure` without masking.

        Args:
            subgraph: The subgraph name, for `extensions.service`.

        Returns:
            `{"errors":[...]}` with the message, the code and the service.
        """
        var text = (
            '{"errors":['
            + error_json(plan_error(self.message, self.code, subgraph, ""))
            + "]}"
        )
        return List[UInt8](text.as_bytes())

    def write_to(self, mut writer: Some[Writer]):
        """Write the code and the message.

        Args:
            writer: The destination.
        """
        writer.write(self.code, ": ", self.message)


struct HttpSubscription(Movable):
    """One subgraph subscription over HTTP streaming."""

    var client: Client
    """The client that holds the connection."""
    var stream: ResponseStream
    """The response."""
    var is_sse: Bool
    """Whether the content is `text/event-stream`."""
    var sse: SseParser
    """The parser of an SSE content."""
    var multipart: MultipartParser
    """The parser of a multipart content."""
    var done: Bool
    """Whether the stream has ended."""
    var _chunk: List[UInt8]

    def __init__(
        out self,
        var client: Client,
        var stream: ResponseStream,
        is_sse: Bool,
        boundary: String,
    ):
        """Wrap an open response.

        Args:
            client: The client of the connection.
            stream: The response, after its head.
            is_sse: Whether the content is SSE.
            boundary: The multipart boundary, or empty for SSE.
        """
        self.client = client^
        self.stream = stream^
        self.is_sse = is_sse
        self.sse = SseParser()
        self.multipart = MultipartParser(boundary)
        self.done = False
        self._chunk = List[UInt8]()

    @staticmethod
    def open(
        url: String, body: List[UInt8], timeout_ms: Int = 30000
    ) raises StreamError -> HttpSubscription:
        """Send a subscription and read the head of its response.

        Args:
            url: The `http://` URL of the subgraph.
            body: The JSON body of the request.
            timeout_ms: The longest wait for the head, and for each read.

        Returns:
            The open subscription.

        Raises:
            StreamError: `SUBREQUEST_HTTP_ERROR` when the request fails,
                `SUBGRAPH_RESPONSE_FAILURE` when the head does not come,
                `SUBGRAPH_STREAM_STATUS_CODE_NOT_OK` for a status that is
                not 2xx, `SUBGRAPH_SUBSCRIPTION_UNSUPPORTED_CONTENT_TYPE`
                and `SUBGRAPH_SUBSCRIPTION_MULTIPART_BOUNDARY_PARSE_FAILURE`.
        """
        var client = Client()
        client.config.timeout_ms = timeout_ms
        var pending: PendingRequest
        try:
            var endpoint = client.endpoint(url)
            var target = endpoint.target
            var headers = Headers()
            headers.add("content-type", "application/json")
            headers.add("accept", SUBSCRIPTION_ACCEPT)
            pending = client.start(
                endpoint, Method.POST, target, headers, Span(body)
            )
        except e:
            raise StreamError(
                "SUBREQUEST_HTTP_ERROR",
                "Failed to send request to subgraph: " + String(e),
            )
        var stream: ResponseStream
        try:
            stream = client.stream(pending^)
        except e:
            raise StreamError(
                "SUBGRAPH_RESPONSE_FAILURE",
                "Failed to receive response: " + String(e),
            )
        var status = stream.response.status
        # The client reads past each 1xx response, and refuses a code below
        # 100, so only the upper bound of 2xx is left to check.
        if status.code > 299:
            client.close_stream(stream)
            raise StreamError(
                "SUBGRAPH_STREAM_STATUS_CODE_NOT_OK",
                "Subgraph stream responded with a not-OK status code '"
                + String(status.code)
                + " "
                + String(status.reason())
                + "'",
            )
        var content_type = String()
        var found = stream.response.header("content-type")
        if found:
            content_type = String(found.value())
        if content_type.startswith("multipart/mixed"):
            var boundary: String
            try:
                boundary = parse_boundary_from_header(content_type)
            except e:
                client.close_stream(stream)
                raise StreamError(
                    "SUBGRAPH_SUBSCRIPTION_MULTIPART_BOUNDARY_PARSE_FAILURE",
                    "Failed to parse multipart boundary from Content-Type"
                    + " header: "
                    + String(e),
                )
            return HttpSubscription(client^, stream^, False, boundary)
        if content_type.startswith("text/event-stream"):
            return HttpSubscription(client^, stream^, True, String())
        client.close_stream(stream)
        raise StreamError(
            "SUBGRAPH_SUBSCRIPTION_UNSUPPORTED_CONTENT_TYPE",
            "Unsupported content-type '"
            + content_type
            + "': expected 'multipart/mixed' or 'text/event-stream' for"
            + " HTTP subscriptions",
        )

    def fd(self) -> Int:
        """Return the descriptor of the connection.

        Returns:
            The descriptor, or -1 after the end.
        """
        return self.stream.fd

    def poll(
        mut self, mut events: List[List[UInt8]]
    ) raises StreamError -> Bool:
        """Read what has arrived and append its events, without a wait.

        Args:
            events: The destination; one JSON text per event.

        Returns:
            True when the stream has ended.

        Raises:
            StreamError: `SUBGRAPH_SUBSCRIPTION_SSE_STREAM_ERROR` or
                `SUBGRAPH_SUBSCRIPTION_MULTIPART_STREAM_ERROR` when the
                content is invalid or the read fails.
        """
        if self.done:
            return True
        try:
            self._read(events)
        except e:
            self.close()
            if self.is_sse:
                raise StreamError(
                    "SUBGRAPH_SUBSCRIPTION_SSE_STREAM_ERROR",
                    "Error reading SSE subscription stream: " + String(e),
                )
            raise StreamError(
                "SUBGRAPH_SUBSCRIPTION_MULTIPART_STREAM_ERROR",
                "Error reading multipart subscription stream: " + String(e),
            )
        if self.done:
            self.close()
        return self.done

    def _read(mut self, mut events: List[List[UInt8]]) raises:
        """Read and parse until no byte waits, or the stream ends."""
        # The head can arrive with the first bytes of the content.
        var buffered = self.stream.body._end > 0
        while buffered or self.client.sys.poll(self.stream.fd, POLLIN, 0) > 0:
            buffered = False
            self._chunk.clear()
            var more: Bool
            try:
                more = self.client.read_body(self.stream, self._chunk)
            except e:
                raise Error("Stream read error: " + String(e))
            if not more:
                self.done = True
                return
            if self.is_sse:
                self.sse.feed(Span(self._chunk))
                self.done = self.sse.take(events)
            else:
                self.multipart.feed(Span(self._chunk))
                self.done = self.multipart.take(events)
            if self.done:
                return

    def close(mut self):
        """Close the connection; the subgraph sees the client go away."""
        self.done = True
        self.client.close_stream(self.stream)
