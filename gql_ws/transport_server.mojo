# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The server of `graphql-transport-ws`: a `WsHandler` that runs the
protocol on each WebSocket, with many operations on one socket.

`TransportServer` acknowledges a `connection_init`, answers a `ping`,
and gives each `subscribe` to a `GraphQLExecutor`. The executor returns a
result, errors, or an event stream. A result is one `next` and a
`complete`. Errors are one `error`. A stream goes into a gql_stream
`EventLoop`: each event is a `next`, the end is a `complete`, and a
failure is an `error`. A `complete` from the client cancels its stream.
The loop watches the descriptor of the event loop, so a published event
wakes it.

The close codes and reasons are those of graphql-ws: 4406 without the
subprotocol, 4408 when no `connection_init` comes within
`connection_init_wait_timeout_ms`, 4429 for a second one, 4403 when the
executor refuses the connection, 4401 for a `subscribe` before the
acknowledgement, 4409 for an id in use, 4400 for an invalid message, and
4500 when the executor fails.

This module ports graphql-ws 6.4.1 `src/server.ts` (`makeServer`,
`handleProtocols`) and the `ws` adapter of `src/use/ws.ts`, with
`tests/server.test.ts` and `tests/use.test.ts`.

Differences from upstream:

- **Executor.** The hooks `onConnect`, `onSubscribe`, `onOperation`,
  `onNext`, `onError`, `onComplete` and `onClose` are one
  `GraphQLExecutor`. Parsing, validation and execution are the work of
  the executor; `gql_ws_execution` has one on gql_execution.
- **Synchronous execution.** The executor returns at once. An operation
  that a `complete` cancels before it returns does not exist here.
- **Back pressure.** A `next` that does not fit in the output of a slow
  client closes the socket with 1013 `Write buffer full`. graphql-ws
  buffers without a limit in `ws`.
- **Keep-alive.** The `ws` adapter pings each socket every 12 seconds.
  Here a client keeps the connection alive with protocol pings.
"""

from gql_stream.event_loop import EventLoop
from gql_stream.stream import AnyStream

from gql_ws.error import WsError, WsErrorKind
from gql_ws.frame import CloseCode
from gql_ws.graphql_ws import (
    BAD_REQUEST,
    CONNECTION_INITIALISATION_TIMEOUT,
    FORBIDDEN,
    GRAPHQL_TRANSPORT_WS_PROTOCOL,
    INTERNAL_SERVER_ERROR,
    MessageType,
    ProtocolMessage,
    SUBSCRIBER_ALREADY_EXISTS,
    SUBPROTOCOL_NOT_ACCEPTABLE,
    TOO_MANY_INITIALISATION_REQUESTS,
    UNAUTHORIZED,
    error_payload,
    id_message,
    limit_close_reason,
    parse_message,
    payload_message,
)
from gql_ws.protocol import Message
from gql_ws.server import Sockets, WsHandler


@fieldwise_init
struct OperationKind(Equatable, ImplicitlyCopyable, Writable):
    """What an executor made of a `subscribe`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime RESULT = OperationKind(0)
    """One execution result: one `next`, then `complete`."""
    comptime ERRORS = OperationKind(1)
    """GraphQL errors before execution: one `error`."""
    comptime STREAM = OperationKind(2)
    """An event stream: a `next` for each event."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the kind.

        Args:
            writer: The destination.
        """
        writer.write(self.value)


struct Operation(Movable):
    """The outcome of a `subscribe`."""

    var kind: OperationKind
    """The kind."""
    var json: String
    """The JSON of the result, or of the array of errors."""
    var stream: Optional[AnyStream]
    """The stream of a `STREAM`: each event is the JSON of a result."""

    def __init__(
        out self,
        kind: OperationKind,
        var json: String,
        var stream: Optional[AnyStream],
    ):
        """Make an outcome.

        Args:
            kind: The kind.
            json: The JSON text, or empty for a stream.
            stream: The stream, or None.
        """
        self.kind = kind
        self.json = json^
        self.stream = stream^

    @staticmethod
    def result(var json: String) -> Operation:
        """Make the outcome of a query, a mutation, or a subscription that
        failed with errors only.

        Args:
            json: The JSON of the `ExecutionResult`.

        Returns:
            The outcome.
        """
        return Operation(OperationKind.RESULT, json^, None)

    @staticmethod
    def errors(var json: String) -> Operation:
        """Make the outcome of errors before execution, such as validation
        errors.

        Args:
            json: The JSON array of the GraphQL errors.

        Returns:
            The outcome.
        """
        return Operation(OperationKind.ERRORS, json^, None)

    @staticmethod
    def of_stream(var stream: AnyStream) -> Operation:
        """Make the outcome of a subscription.

        Args:
            stream: The response stream.

        Returns:
            The outcome.
        """
        return Operation(OperationKind.STREAM, String(), stream^)


@fieldwise_init
struct Acknowledgement(Copyable, Movable):
    """The answer of an executor to a `connection_init`."""

    var permitted: Bool
    """Whether the connection is acknowledged; False closes it with 4403."""
    var payload: String
    """The JSON object for the `connection_ack`, or empty for none."""


trait GraphQLExecutor(Deinitable, Movable):
    """The GraphQL side of a `TransportServer`."""

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        """Accept or refuse a connection, as the `onConnect` hook.

        Args:
            socket: The connection id.
            message: The `connection_init`, with its parameters.

        Returns:
            Whether to acknowledge, and the payload of the ack.

        Raises:
            Error: Any error; the socket closes with 4500.
        """
        ...

    def operation(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Operation:
        """Run a `subscribe`: parse, validate and execute it.

        Args:
            socket: The connection id.
            message: The `subscribe`, with its payload.

        Returns:
            A result, errors, or a stream.

        Raises:
            Error: Any error; the socket closes with 4500.
        """
        ...

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        """Forget a connection, as the `onClose` hook.

        Args:
            socket: The connection id.
            code: The close code.
            reason: The close reason.
        """
        ...


@fieldwise_init
struct TransportOptions(Copyable, Movable):
    """The options of a `TransportServer`."""

    var connection_init_wait_timeout_ms: Int
    """How long a socket can wait before its `connection_init`; 3000 at
    first, and 0 waits without a limit."""
    var is_prod: Bool
    """Whether a close for a failure says `Internal server error` and not
    the error text; False at first."""

    def __init__(out self):
        """Make the upstream defaults."""
        self.connection_init_wait_timeout_ms = 3000
        self.is_prod = False


struct _Context(Copyable, Movable):
    """The state of one socket, as graphql-ws `Context`."""

    var id: Int
    var active: Bool
    var init_received: Bool
    var acknowledged: Bool
    var deadline_ms: Int
    var ops: Dict[String, Int]

    def __init__(out self):
        self.id = -1
        self.active = False
        self.init_received = False
        self.acknowledged = False
        self.deadline_ms = -1
        self.ops = Dict[String, Int]()


@fieldwise_init
struct _Route(Copyable, Movable):
    """The socket and the operation id of a stream in the loop."""

    var socket: Int
    var op: String


comptime _FD_MASK = (1 << 20) - 1
"""The descriptor bits of a connection id of `gql_ws.server`."""


struct TransportServer[E: GraphQLExecutor](WsHandler):
    """The `graphql-transport-ws` protocol on the sockets of a
    `gql_ws.server.Server`.

    Parameters:
        E: The type of the executor.
    """

    var executor: Self.E
    """The executor of the operations."""
    var options: TransportOptions
    """The options."""
    var loop: EventLoop
    """The event loop of the streams."""
    var _contexts: List[_Context]
    var _routes: List[_Route]
    var _waiting: Int

    def __init__(
        out self,
        var executor: Self.E,
        options: TransportOptions = TransportOptions(),
    ) raises:
        """Make a protocol server.

        Args:
            executor: The executor of the operations.
            options: The options.

        Raises:
            Error: When the event loop cannot open epoll.
        """
        self.executor = executor^
        self.options = options.copy()
        self.loop = EventLoop()
        self._contexts = List[_Context]()
        self._routes = List[_Route]()
        self._waiting = 0

    def _slot(mut self, id: Int) -> Int:
        """Return the index of the context of a socket, made when new."""
        var fd = id & _FD_MASK
        while len(self._contexts) <= fd:
            self._contexts.append(_Context())
        return fd

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        """Start the protocol on a socket, as `opened`.

        Args:
            sockets: The open connections.
            id: The socket.

        Raises:
            Error: Never.
        """
        ref ctx = self._contexts[self._slot(id)]
        ctx = _Context()
        ctx.id = id
        if sockets.protocol(id) != GRAPHQL_TRANSPORT_WS_PROTOCOL:
            _ = sockets.close(
                id, SUBPROTOCOL_NOT_ACCEPTABLE, "Subprotocol not acceptable"
            )
            return
        ctx.active = True
        var wait = self.options.connection_init_wait_timeout_ms
        if wait > 0:
            ctx.deadline_ms = sockets.now_ms + wait
            self._waiting += 1

    def on_message(
        mut self, mut sockets: Sockets, id: Int, message: Message
    ) raises:
        """Handle one message of the protocol.

        Args:
            sockets: The open connections.
            id: The socket.
            message: The WebSocket message.

        Raises:
            Error: Never; a failure closes the socket with 4500.
        """
        if not self._contexts[self._slot(id)].active:
            return
        var parsed: ProtocolMessage
        try:
            parsed = parse_message(message.text())
        except:
            _ = sockets.close(id, BAD_REQUEST, "Invalid message received")
            return
        try:
            self._handle(sockets, id, parsed)
        except e:
            var reason = String("Internal server error")
            if not self.options.is_prod:
                reason = limit_close_reason(String(e), reason)
            _ = sockets.close(id, INTERNAL_SERVER_ERROR, reason)

    def _send(mut self, mut sockets: Sockets, id: Int, text: String):
        """Send a message; a socket without room for it closes with 1013,
        and a socket that is closing drops it."""
        try:
            _ = sockets.send_text(id, text)
        except e:
            if e.kind == WsErrorKind.WRITE_BUFFER_FULL:
                _ = sockets.close(id, CloseCode.AGAIN, "Write buffer full")

    def _handle(
        mut self, mut sockets: Sockets, id: Int, message: ProtocolMessage
    ) raises:
        """Handle a valid message."""
        var type = message.type
        if type == MessageType.CONNECTION_INIT:
            if self._contexts[self._slot(id)].init_received:
                _ = sockets.close(
                    id,
                    TOO_MANY_INITIALISATION_REQUESTS,
                    "Too many initialisation requests",
                )
                return
            self._contexts[self._slot(id)].init_received = True
            if self._contexts[self._slot(id)].deadline_ms >= 0:
                self._contexts[self._slot(id)].deadline_ms = -1
                self._waiting -= 1
            var ack = self.executor.on_connect(id, message)
            if not ack.permitted:
                _ = sockets.close(id, FORBIDDEN, "Forbidden")
                return
            self._contexts[self._slot(id)].acknowledged = True
            self._send(
                sockets,
                id,
                payload_message(MessageType.CONNECTION_ACK, ack.payload),
            )
        elif type == MessageType.PING:
            self._send(
                sockets,
                id,
                payload_message(MessageType.PONG, message.payload_json()),
            )
        elif type == MessageType.PONG:
            return
        elif type == MessageType.SUBSCRIBE:
            self._subscribe(sockets, id, message)
        elif type == MessageType.COMPLETE:
            var found = self._contexts[self._slot(id)].ops.pop(message.id, -1)
            if found >= 0:
                _ = self.loop.cancel(found)
        else:
            raise Error(
                "Unexpected message of type "
                + String(type.text())
                + " received"
            )

    def _subscribe(
        mut self, mut sockets: Sockets, id: Int, message: ProtocolMessage
    ) raises:
        """Run a `subscribe`."""
        if not self._contexts[self._slot(id)].acknowledged:
            _ = sockets.close(id, UNAUTHORIZED, "Unauthorized")
            return
        var op = message.id
        if op in self._contexts[self._slot(id)].ops:
            _ = sockets.close(
                id,
                SUBSCRIBER_ALREADY_EXISTS,
                "Subscriber for " + op + " already exists",
            )
            return
        var outcome = self.executor.operation(id, message)
        if outcome.kind == OperationKind.ERRORS:
            self._send(
                sockets, id, id_message(MessageType.ERROR, op, outcome.json)
            )
            return
        if outcome.kind == OperationKind.RESULT:
            self._send(
                sockets, id, id_message(MessageType.NEXT, op, outcome.json)
            )
            self._send(sockets, id, id_message(MessageType.COMPLETE, op))
            return
        var stream = self.loop.add(outcome.stream.take())
        while len(self._routes) <= stream:
            self._routes.append(_Route(-1, String()))
        self._routes[stream] = _Route(id, op)
        self._contexts[self._slot(id)].ops[op] = stream

    def on_tick(mut self, mut sockets: Sockets) raises:
        """Close the sockets whose `connection_init` is late, and forward
        the events of the streams.

        Args:
            sockets: The open connections.

        Raises:
            Error: When the event loop fails.
        """
        if self._waiting > 0:
            self._expire(sockets)
        _ = self.loop.poll(0)
        var index = 0
        while index < len(self.loop.stream_events):
            var poll = self.loop.stream_events[index].poll.copy()
            var route = self._routes[self.loop.stream_events[index].id].copy()
            index += 1
            if poll.is_ready():
                var json = poll.event.value().to_json()
                self._send(
                    sockets,
                    route.socket,
                    id_message(MessageType.NEXT, route.op, json),
                )
                continue
            _ = self._contexts[self._slot(route.socket)].ops.pop(route.op, -1)
            if poll.is_done():
                self._send(
                    sockets,
                    route.socket,
                    id_message(MessageType.COMPLETE, route.op),
                )
            else:
                self._send(
                    sockets,
                    route.socket,
                    id_message(
                        MessageType.ERROR, route.op, error_payload(poll.message)
                    ),
                )

    def _expire(mut self, mut sockets: Sockets):
        """Close each socket whose `connection_init` did not come in time."""
        var now = sockets.now_ms
        var fd = 0
        while fd < len(self._contexts):
            ref ctx = self._contexts[fd]
            if ctx.deadline_ms >= 0 and now >= ctx.deadline_ms:
                ctx.deadline_ms = -1
                self._waiting -= 1
                _ = sockets.close(
                    ctx.id,
                    CONNECTION_INITIALISATION_TIMEOUT,
                    "Connection initialisation timeout",
                )
            fd += 1

    def on_close(
        mut self, mut sockets: Sockets, id: Int, code: UInt16, reason: String
    ):
        """Cancel the streams of a socket, and tell the executor.

        Args:
            sockets: The open connections.
            id: The socket.
            code: The close code.
            reason: The close reason.
        """
        ref ctx = self._contexts[self._slot(id)]
        for entry in ctx.ops.items():
            _ = self.loop.cancel(entry.value)
        ctx.ops.clear()
        ctx.active = False
        if ctx.deadline_ms >= 0:
            ctx.deadline_ms = -1
            self._waiting -= 1
        self.executor.on_close(id, code, reason)

    def fd(self) -> Int:
        """Return the descriptor of the event loop.

        Returns:
            The epoll descriptor; it is readable when a stream wakes.
        """
        return self.loop.fd()

    def wait_ms(self) -> Int:
        """Return the longest wait before `on_tick`.

        Returns:
            0 when a stream is awake, 100 while a `connection_init` is
            awaited, else -1.
        """
        if self.loop.wake_set[].pending() > 0:
            return 0
        if self._waiting > 0:
            return 100
        return -1
