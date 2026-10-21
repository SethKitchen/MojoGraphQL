# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""GraphQL over HTTP with incremental delivery as `multipart/mixed`.

`IncrementalHandler` answers a GET or a JSON POST with the executor of an
SSE server. One result goes out as `application/json`. A stream of
results, such as the payloads of `@defer`, goes out as the parts of
`multipart/mixed; boundary="-"; deferSpec=20220824`, the format that
Apollo Server 4 writes and meros reads. The response is held, and the
server loop polls it.

The module ports no code. A client that does not accept
`multipart/mixed` gets a 406 for a stream of results, as Apollo Server 4
does for `@defer` without the `deferSpec` accept.
"""

from gql_http.body import BodyPoll
from gql_http.multipart import INCREMENTAL_CONTENT_TYPE
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.status import Status
from gql_sse.bridge import HeldBodies, MultipartBody
from gql_sse.handler import (
    JSON_TYPE,
    PreparedKind,
    SseExecutor,
    error_json,
    parse_request,
)


struct IncrementalHandler[X: SseExecutor](Handler):
    """Serves operations over HTTP, with `multipart/mixed` for streams.

    Parameters:
        X: The type of the executor.
    """

    var executor: Self.X
    """The executor of the operations."""
    var bodies: HeldBodies[MultipartBody]
    """The multipart bodies of the held responses."""

    def __init__(out self, var executor: Self.X):
        """Make a handler.

        Args:
            executor: The executor of the operations.
        """
        self.executor = executor^
        self.bodies = HeldBodies[MultipartBody]()

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one operation.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: The errors of the executor; the client gets a 500.
        """
        var outcome = parse_request(request)
        if not outcome.params:
            return _answer(response, outcome.status, outcome.json)
        var prepared = self.executor.prepare(
            request, outcome.params.value(), False
        )
        if prepared.kind == PreparedKind.RESPONSE:
            if prepared.allow.byte_length() > 0:
                response.add_header("allow", prepared.allow)
            return _answer(response, prepared.status, prepared.json)
        if prepared.kind == PreparedKind.RESULT:
            return _answer(response, Status.OK, prepared.json)
        var accept = request.header("accept")
        if not accept or accept.value().find("multipart/mixed") < 0:
            return _answer(
                response,
                Status.NOT_ACCEPTABLE,
                error_json(
                    "Incremental delivery needs an accept of multipart/mixed"
                ),
            )
        response.add_header("content-type", INCREMENTAL_CONTENT_TYPE)
        response.begin_chunked()
        response.hold()
        self.bodies.add(
            response.connection(), MultipartBody(prepared.stream.take())
        )

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        """Write the parts that are ready.

        Args:
            id: The connection.
            out: The destination.

        Returns:
            The result of the multipart body.

        Raises:
            Error: Never.
        """
        return self.bodies.poll(id, out)

    def body_closed(mut self, id: Int):
        """Drop the body of a connection that ended.

        Args:
            id: The connection.
        """
        self.bodies.drop(id)


def _answer(mut response: ResponseWriter, status: Status, json: String) raises:
    """Answer with a status and a JSON body, if any."""
    response.set_status(status)
    if json.byte_length() > 0:
        response.add_header("content-type", JSON_TYPE)
        response.write_text(json)
