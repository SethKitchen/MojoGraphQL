# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A GraphQL over Server-Sent Events server: a `gql_http` handler.

`SseHandler` answers each request as graphql-sse 2.6.3 `createHandler`
does. In the distinct connections mode, a request that accepts
`text/event-stream` gets its own stream of `next` events and one
`complete`. In the single connection mode, `PUT` reserves a token, a GET
with the token opens its stream, each `POST` adds an operation to it, and
`DELETE` stops one.

The handler holds each stream with `ResponseWriter.hold`, and the server
loop polls it through `poll_body`. When the client goes away,
`body_closed` closes the streams of its operations.

Differences from upstream: the server writes the `connection` field
itself, so the handler does not add `connection: keep-alive`. A stream
with an `ERROR` poll ends the connection without `complete`, as an
iterator that throws does.
"""

from std.random import random_ui64
from std.time import perf_counter_ns

from gql_http.body import BodyPoll
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.status import Method, Status
from gql_http.url import parse_query, query_value
from gql_json.writer import write_string
from gql_sse.event import StreamEvent, print_message, print_ping
from gql_sse.handler import (
    EVENT_STREAM_TYPE,
    JSON_TYPE,
    TOKEN_HEADER_KEY,
    TOKEN_QUERY_KEY,
    Prepared,
    PreparedKind,
    SseExecutor,
    error_json,
    parse_request,
)
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker

comptime PING_MS = 12000
"""How often a quiet stream gets a ping comment, as upstream."""
comptime _BUDGET = 1 << 15
"""The bytes that one `poll_body` makes before it yields."""


struct _Op(Movable):
    """One operation of a stream: a result, or a stream of results."""

    var id: String
    var stream: Optional[AnyStream]
    var result: String
    var error: String

    def __init__(out self, id: String, var prepared: Prepared):
        self.id = id
        self.result = prepared.json
        self.error = String()
        self.stream = None
        if prepared.stream:
            self.stream = prepared.stream.take()


struct _EventStream(Movable):
    """The operations of one event stream; `token` is empty when the
    stream is a distinct connection."""

    var token: String
    var conn: Int
    var ops: List[_Op]
    var last_ms: Int
    var live: Bool

    def __init__(out self, token: String):
        self.token = token
        self.conn = -1
        self.ops = List[_Op]()
        self.last_ms = 0
        self.live = True


def _now_ms() -> Int:
    return Int(perf_counter_ns() // 1_000_000)


struct SseHandler[X: SseExecutor](Handler):
    """Serves GraphQL over SSE on a `gql_http` server.

    Parameters:
        X: The type of the executor.
    """

    var executor: Self.X
    """The executor of the operations."""
    var ping_ms: Int
    """How often a quiet stream gets a ping; 12000 at first."""
    var _streams: List[_EventStream]
    var _by_conn: List[Int]
    var _waker: Waker
    var _tokens: Int

    def __init__(out self, var executor: Self.X) raises:
        """Make a handler.

        Args:
            executor: The executor of the operations.

        Raises:
            Error: Never; the waker opens no descriptor.
        """
        self.executor = executor^
        self.ping_ms = PING_MS
        self._streams = List[_EventStream]()
        self._by_conn = List[Int]()
        self._waker = Waker.noop()
        self._tokens = 0

    def streams(self) -> Int:
        """Return the count of event streams, reserved or open.

        Returns:
            The count.
        """
        var count = 0
        var i = 0
        while i < len(self._streams):
            if self._streams[i].live:
                count += 1
            i += 1
        return count

    def operations(self, token: StringSlice) -> Int:
        """Return the count of operations of a reserved stream.

        Args:
            token: The token of the stream.

        Returns:
            The count, or -1 when no stream has the token.
        """
        var slot = self._find(token)
        if slot < 0:
            return -1
        return len(self._streams[slot].ops)

    def _find(self, token: StringSlice) -> Int:
        """Return the slot of the live stream of a token, or -1."""
        var i = 0
        while i < len(self._streams):
            if self._streams[i].live and self._streams[i].token == token:
                return i
            i += 1
        return -1

    def _add(mut self, token: String) -> Int:
        """Make a stream in a free slot."""
        var i = 0
        while i < len(self._streams):
            if not self._streams[i].live:
                self._streams[i] = _EventStream(token)
                return i
            i += 1
        self._streams.append(_EventStream(token))
        return len(self._streams) - 1

    def _token(mut self, request: Request) -> String:
        """Return the token of the header or of the query, or a new one."""
        var header = request.header(TOKEN_HEADER_KEY)
        if header and header.value().byte_length() > 0:
            return String(header.value())
        try:
            var value = query_value(
                parse_query(request.query()), TOKEN_QUERY_KEY
            )
            if value and value.value().byte_length() > 0:
                return value.value()
        except:
            pass
        # A random version 4 UUID, as upstream makes.
        self._tokens += 1
        var out = String()
        var i = 0
        while i < 32:
            if i == 8 or i == 12 or i == 16 or i == 20:
                out += "-"
            var digit = Int(random_ui64(0, 15))
            if i == 12:
                digit = 4
            elif i == 16:
                digit = 8 | (digit & 3)
            out += StaticString("0123456789abcdef")[byte = digit : digit + 1]
            i += 1
        return out

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one request, as the upstream `handler` does.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: The errors of the executor; the client gets a 500.
        """
        var accept = String("*/*")
        var header = request.header("accept")
        if header:
            accept = String(header.value())
        var token = self._token(request)
        var slot = self._find(token)
        if accept == "text/event-stream":
            if slot >= 0:
                if self._streams[slot].conn >= 0:
                    return _refuse(
                        response,
                        Status.CONFLICT,
                        error_json("Stream already open"),
                    )
                return self._open(slot, response)
            var outcome = parse_request(request)
            if not outcome.params:
                return _refuse(response, outcome.status, outcome.json)
            var prepared = self.executor.prepare(
                request, outcome.params.value(), True
            )
            if prepared.kind == PreparedKind.RESPONSE:
                return _refuse(
                    response, prepared.status, prepared.json, prepared.allow
                )
            slot = self._add(String())
            self._streams[slot].ops.append(_Op(String(), prepared^))
            return self._open(slot, response)
        if request.method == Method.PUT:
            if accept != "*/*" and accept != "text/plain":
                return _refuse(response, Status.NOT_ACCEPTABLE, "")
            if slot >= 0:
                return _refuse(
                    response,
                    Status.CONFLICT,
                    error_json("Stream already registered"),
                )
            _ = self._add(token)
            response.set_status(Status.CREATED)
            response.add_header("content-type", "text/plain; charset=utf-8")
            response.write_text(token)
            return
        if request.method == Method.DELETE:
            if slot < 0:
                return _refuse(
                    response, Status.NOT_FOUND, error_json("Stream not found")
                )
            var id = String()
            try:
                var value = query_value(
                    parse_query(request.query()), "operationId"
                )
                if value:
                    id = value.value()
            except:
                pass
            if id.byte_length() == 0:
                return _refuse(
                    response,
                    Status.BAD_REQUEST,
                    error_json("Operation ID is missing"),
                )
            self._stop(slot, id)
            return
        if request.method != Method.GET and request.method != Method.POST:
            return _refuse(
                response,
                Status.METHOD_NOT_ALLOWED,
                "",
                "GET, POST, PUT, DELETE",
            )
        if slot < 0:
            return _refuse(
                response, Status.NOT_FOUND, error_json("Stream not found")
            )
        if (
            accept != "*/*"
            and accept != "application/*"
            and accept != "application/json"
        ):
            return _refuse(response, Status.NOT_ACCEPTABLE, "")
        var outcome = parse_request(request)
        if not outcome.params:
            return _refuse(response, outcome.status, outcome.json)
        var id = outcome.params.value().operation_id()
        if id.byte_length() == 0:
            return _refuse(
                response,
                Status.BAD_REQUEST,
                error_json("Operation ID is missing"),
            )
        if self._op(slot, id) >= 0:
            return _refuse(
                response,
                Status.CONFLICT,
                error_json("Operation with ID already exists"),
            )
        var prepared = self.executor.prepare(
            request, outcome.params.value(), False
        )
        if prepared.kind == PreparedKind.RESPONSE:
            return _refuse(
                response, prepared.status, prepared.json, prepared.allow
            )
        self._streams[slot].ops.append(_Op(id, prepared^))
        response.set_status(Status.ACCEPTED)

    def _op(self, slot: Int, id: StringSlice) -> Int:
        """Return the index of an operation of a stream, or -1."""
        var i = 0
        while i < len(self._streams[slot].ops):
            if self._streams[slot].ops[i].id == id:
                return i
            i += 1
        return -1

    def _stop(mut self, slot: Int, id: StringSlice):
        """Stop an operation: close its stream and forget it."""
        var index = self._op(slot, id)
        if index < 0:
            return
        if self._streams[slot].ops[index].stream:
            self._streams[slot].ops[index].stream.value().close()
        _ = self._streams[slot].ops.pop(index)

    def _open(mut self, slot: Int, mut response: ResponseWriter) raises:
        """Begin the event stream of a slot on this connection."""
        var fd = response.connection()
        response.set_status(Status.OK)
        response.add_header("cache-control", "no-cache")
        response.add_header("content-encoding", "none")
        response.add_header("content-type", EVENT_STREAM_TYPE)
        response.begin_chunked()
        response.write_chunk(StaticString(":\n\n").as_bytes())
        response.hold()
        self._streams[slot].conn = fd
        self._streams[slot].last_ms = _now_ms()
        while len(self._by_conn) <= fd:
            self._by_conn.append(-1)
        self._by_conn[fd] = slot

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        """Write the messages of the operations of an open stream.

        Args:
            id: The connection of the stream.
            out: The destination of the messages.

        Returns:
            `READY` after messages, `PENDING` when there are none, and
            `DONE` when a distinct stream has completed.

        Raises:
            Error: The error of a stream of results; the connection ends.
        """
        if id >= len(self._by_conn) or self._by_conn[id] < 0:
            return BodyPoll.DONE
        var slot = self._by_conn[id]
        var distinct = self._streams[slot].token.byte_length() == 0
        var i = 0
        while i < len(self._streams[slot].ops) and len(out) < _BUDGET:
            if self._drain(slot, i, distinct, out):
                _ = self._streams[slot].ops.pop(i)
            else:
                i += 1
        var now = _now_ms()
        if distinct and len(self._streams[slot].ops) == 0:
            self._release(slot)
            return BodyPoll.DONE
        if len(out) == 0:
            if now - self._streams[slot].last_ms < self.ping_ms:
                return BodyPoll.PENDING
            print_ping(out)
        self._streams[slot].last_ms = now
        return BodyPoll.READY

    def _drain(
        mut self, slot: Int, index: Int, distinct: Bool, mut out: List[UInt8]
    ) raises -> Bool:
        """Write what one operation has now; return True at its end."""
        ref op = self._streams[slot].ops[index]
        if op.error.byte_length() > 0:
            raise Error(op.error)
        if not op.stream:
            _next(out, op.id, distinct, op.result)
            _complete(out, op.id, distinct)
            return True
        while len(out) < _BUDGET:
            var poll = op.stream.value().poll_next(self._waker)
            if poll.is_pending():
                return False
            if poll.is_done():
                _complete(out, op.id, distinct)
                return True
            if poll.is_error():
                if len(out) == 0:
                    raise Error(poll.message)
                # The results so far go out first; the error ends the
                # stream at the next poll.
                op.error = poll.message
                return False
            _next(out, op.id, distinct, poll.value().to_json())
        return False

    def _release(mut self, slot: Int):
        """Close the operations of a stream, and free its slot."""
        var i = 0
        while i < len(self._streams[slot].ops):
            if self._streams[slot].ops[i].stream:
                self._streams[slot].ops[i].stream.value().close()
            i += 1
        self._streams[slot].ops.clear()
        # A stream is released only while its connection is open.
        self._by_conn[self._streams[slot].conn] = -1
        self._streams[slot].conn = -1
        self._streams[slot].live = False

    def body_closed(mut self, id: Int):
        """Forget the stream of a connection that ended (`dispose`).

        Args:
            id: The connection.
        """
        if id < len(self._by_conn) and self._by_conn[id] >= 0:
            self._release(self._by_conn[id])


def _next(mut out: List[UInt8], id: String, distinct: Bool, json: String):
    """Write a `next` message; in the single connection mode the data is
    `{"id":<id>,"payload":<result>}`."""
    if distinct:
        print_message(out, StreamEvent.NEXT, json)
        return
    var data = List[UInt8]()
    data.extend(StaticString('{"id":').as_bytes())
    write_string(data, id.as_bytes())
    data.extend(StaticString(',"payload":').as_bytes())
    data.extend(json.as_bytes())
    data.append(125)
    print_message(out, StreamEvent.NEXT, StringSlice(unsafe_from_utf8=data))


def _complete(mut out: List[UInt8], id: String, distinct: Bool):
    """Write a `complete` message; with `{"id":<id>}` in the single
    connection mode."""
    if distinct:
        print_message(out, StreamEvent.COMPLETE, "")
        return
    var data = List[UInt8]()
    data.extend(StaticString('{"id":').as_bytes())
    write_string(data, id.as_bytes())
    data.append(125)
    print_message(out, StreamEvent.COMPLETE, StringSlice(unsafe_from_utf8=data))


def _refuse(
    mut response: ResponseWriter,
    status: Status,
    json: String,
    allow: StringSlice = "",
) raises:
    """Answer with a status, and a JSON body when there is one."""
    response.set_status(status)
    if allow.byte_length() > 0:
        response.add_header("allow", allow)
    if json.byte_length() > 0:
        response.add_header("content-type", JSON_TYPE)
        response.write_text(json)
