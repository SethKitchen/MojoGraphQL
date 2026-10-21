# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Serve a router that streams: HTTP streams and WebSocket.

Port of the transports of Hive Router `1a29df9`: the streamed responses of
`bin/router/src/pipeline/mod.rs` and `shared_state.rs`, and the
`graphql-transport-ws` server of `pipeline/websocket_server.rs`.

`RouterStreamHandler` is a `gql_http` handler. It answers the GraphQL path
with `gql_router_stream.http.answer_request`, and holds each streamed
response: the server loop calls `poll_body`, which frames the next results.
A quiet SSE or Apollo multipart stream gets a heartbeat after
`HEARTBEAT_MS`, as upstream. The probes `/health` and `/readiness` answer
200.

`RouterWsExecutor` is the `GraphQLExecutor` of a `gql_ws` `TransportServer`:
a `subscribe` runs a query or a mutation as one `next`, and a
subscription as a stream of `next` messages. `RouterWsHandler` adds the
subgraph sockets of the hub to the loop of the server.

`serve_router` makes one `gql_ws` server for both: an upgrade on the
WebSocket path is a `graphql-transport-ws` connection, and every other
request goes to `RouterStreamHandler`.

**Differences from upstream.** The router runs on one thread. The
WebSocket headers of `connection_init` and of `extensions` are not
forwarded, because the router forwards no headers. An `@defer` over
WebSocket runs as one result.
"""

from std.memory import ArcPointer
from std.time import perf_counter_ns

from gql_http.body import BodyPoll
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.status import Status
from gql_router.exec_http import SubgraphTransport
from gql_router.router_server import HEALTH_PATH, READINESS_PATH
from gql_router_stream.defer import DeferredResponse
from gql_router_stream.encode import HEARTBEAT_MS, StreamFormat
from gql_router_stream.http import StreamAnswer, answer_request
from gql_router_stream.subscription import (
    RouterSubscription,
    StreamHub,
    open_subscription,
)
from gql_router_stream.defer import has_defer
from gql_router_stream.config import SubscriptionsConfig
from gql_router.pipeline import PipelineError
from gql_json.value import NO_NODE as NO_JSON
from gql_http.socket import EPOLL_CTL_ADD, EPOLLIN, Sys
from gql_stream.stream import AnyStream
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL, ProtocolMessage
from gql_ws.protocol import Message
from gql_ws.server import Server, ServerConfig, Sockets, WsHandler, listen
from gql_ws.transport_server import (
    Acknowledgement,
    GraphQLExecutor,
    Operation,
    TransportOptions,
    TransportServer,
)


comptime _BATCH = 64
"""The most results that one poll of a held response frames."""


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


struct _Held[T: SubgraphTransport](Movable):
    """One held response."""

    var subscription: Optional[RouterSubscription[Self.T]]
    var deferred: Optional[DeferredResponse]
    var format: StreamFormat
    var last_ms: Int
    var started: Bool

    def __init__(out self, var answer: StreamAnswer[Self.T]):
        self.subscription = (
            answer.subscription.take() if answer.subscription else None
        )
        self.deferred = answer.deferred.take() if answer.deferred else None
        self.format = answer.format
        self.last_ms = _now_ms()
        self.started = False


struct RouterStreamHandler[T: SubgraphTransport](Handler):
    """The `gql_http` handler of a router that streams.

    Parameters:
        T: The transport of the router.
    """

    var hub: ArcPointer[StreamHub[Self.T]]
    """The router and its subgraph streams."""
    var path: String
    """The GraphQL path; other paths answer 404."""
    var held: List[Optional[_Held[Self.T]]]
    """The held response of each connection, by its id."""
    var batch: Int
    """The most results that one poll of a held response frames."""
    var heartbeat_ms: Int
    """The quiet time before a heartbeat."""

    def __init__(
        out self,
        hub: ArcPointer[StreamHub[Self.T]],
        path: String = "/graphql",
        batch: Int = _BATCH,
        heartbeat_ms: Int = HEARTBEAT_MS,
    ):
        """Make a handler.

        Args:
            hub: The shared hub.
            path: The GraphQL path.
            batch: The most results that one poll frames.
            heartbeat_ms: The quiet time before a heartbeat.
        """
        self.hub = hub
        self.path = path
        self.held = List[Optional[_Held[Self.T]]]()
        self.batch = batch
        self.heartbeat_ms = heartbeat_ms

    def streams(self) -> Int:
        """Count the held responses.

        Returns:
            The count.
        """
        var count = 0
        for index in range(len(self.held)):
            ref entry = self.held[index]
            if entry:
                count += 1
        return count

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one HTTP request.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: When the response cannot be written.
        """
        if request.path() != self.path:
            if (
                request.path() == HEALTH_PATH
                or request.path() == READINESS_PATH
            ):
                response.set_status(Status(200))
                return
            response.error(Status(404))
            return
        var content_type: Optional[String] = None
        var found = request.header("content-type")
        if found:
            content_type = String(found.value())
        var accept = String()
        var accepted = request.header("accept")
        if accepted:
            accept = String(accepted.value())
        var answer = answer_request(
            self.hub,
            request.method,
            request.query(),
            content_type,
            accept,
            List[UInt8](request.body()),
        )
        response.set_status(Status(answer.status))
        response.add_header("Content-Type", answer.content_type)
        if not answer.is_stream:
            response.write(Span(answer.body))
            return
        response.begin_chunked()
        response.write_chunk(Span(answer.body))
        response.hold()
        var id = response.connection()
        while len(self.held) <= id:
            self.held.append(None)
        self.held[id] = _Held(answer^)

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        """Frame the next results of a held response.

        Args:
            id: The connection.
            out: The destination of the bytes.

        Returns:
            `READY` with bytes, `PENDING`, or `DONE` at the end.

        Raises:
            Error: When the response of a deferred operation is not JSON.
        """
        if id >= len(self.held) or not self.held[id]:
            return BodyPoll.DONE
        ref held = self.held[id].value()
        var json = List[UInt8]()
        if held.deferred:
            ref deferred = held.deferred.value()
            if not held.started:
                held.started = True
                deferred.write_initial(
                    self.hub[].router.schema.metadata.possible_types
                )
                held.format.result(out, Span(deferred.initial))
                if not deferred.done:
                    return BodyPoll.READY
            if deferred.next(self.hub[].router, json) == BodyPoll.READY:
                held.format.result(out, Span(json))
            held.format.end(out)
            self.held[id] = None
            return BodyPoll.DONE
        self.hub[].refresh()
        ref subscription = held.subscription.value()
        var count = 0
        while count < self.batch:
            json.clear()
            var state = subscription.next_body(json)
            if state == BodyPoll.PENDING:
                break
            if state == BodyPoll.DONE:
                held.format.end(out)
                self.held[id] = None
                return BodyPoll.DONE
            held.format.result(out, Span(json))
            held.last_ms = _now_ms()
            count += 1
        if len(out) > 0:
            return BodyPoll.READY
        if (
            held.format.has_heartbeat()
            and _now_ms() - held.last_ms >= self.heartbeat_ms
        ):
            held.format.heartbeat(out)
            held.last_ms = _now_ms()
            return BodyPoll.READY
        return BodyPoll.PENDING

    def body_closed(mut self, id: Int):
        """Close the subscription of a response whose client went away.

        Args:
            id: The connection.
        """
        if id < len(self.held):
            self.held[id] = None


def _errors_array(error: PipelineError) -> String:
    """Return the JSON array of the errors of a pipeline error."""
    var body = error.body()
    # `body` is `{"errors":[...]}`.
    return String(body[byte = 10 : body.byte_length() - 1])


struct RouterWsExecutor[T: SubgraphTransport](GraphQLExecutor):
    """The `graphql-transport-ws` executor of a router that streams.

    Parameters:
        T: The transport of the router.
    """

    var hub: ArcPointer[StreamHub[Self.T]]
    """The router and its subgraph streams."""

    def __init__(out self, hub: ArcPointer[StreamHub[Self.T]]):
        """Make an executor.

        Args:
            hub: The shared hub.
        """
        self.hub = hub

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        """Acknowledge each connection.

        Args:
            socket: The connection id.
            message: The `connection_init`.

        Returns:
            An acknowledgement without a payload.

        Raises:
            Error: Never; the trait allows it.
        """
        return Acknowledgement(True, String())

    def operation(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Operation:
        """Run one `subscribe`, as upstream `websocket_server.rs`.

        Args:
            socket: The connection id.
            message: The `subscribe`, with `query`, `operationName` and
                `variables`.

        Returns:
            One result for a query or a mutation, a stream for a
            subscription, and the errors of a request that fails.

        Raises:
            Error: When the response of the router is not JSON.
        """
        # `parse_message` refuses a `subscribe` whose `query` is not a
        # string, whose `operationName` is not a string or null, and whose
        # `variables` are not an object or null. So the checks of upstream
        # are not here.
        var query = message.document.string_value(message.member("query"))
        var operation_name: Optional[String] = None
        var name_node = message.member("operationName")
        if name_node != NO_JSON:
            operation_name = message.document.string_value(name_node)
        var root = message.member("variables")
        try:
            if has_defer(query):
                var deferred = DeferredResponse.start(
                    self.hub[].router,
                    query,
                    operation_name,
                    message.document.copy(),
                    root,
                    False,
                    False,
                )
                return Operation.result(
                    String(unsafe_from_utf8=Span(deferred.initial))
                )
            var prepared = self.hub[].router.prepare_request(
                query,
                operation_name,
                message.document.copy(),
                root,
                False,
                self.hub[].config.enabled,
            )
            if prepared.is_subscription():
                return Operation.of_stream(
                    AnyStream(open_subscription(self.hub, prepared))
                )
            var response = self.hub[].router.run_prepared(prepared)
            return Operation.result(
                String(unsafe_from_utf8=Span(response^.take_body()))
            )
        except error:
            return Operation.errors(_errors_array(error))

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        """Forget a connection; its streams close with it.

        Args:
            socket: The connection id.
            code: The close code.
            reason: The close reason.
        """
        pass


struct RouterWsHandler[T: SubgraphTransport](WsHandler):
    """The WebSocket handler of a router: `graphql-transport-ws`, and the
    subgraph sockets of the hub in the loop of the server.

    Parameters:
        T: The transport of the router.
    """

    var hub: ArcPointer[StreamHub[Self.T]]
    """The router and its subgraph streams."""
    var transport: TransportServer[RouterWsExecutor[Self.T]]
    """The protocol server."""
    var sys: Sys
    """The system calls."""
    var epoll: Int
    """An epoll of the protocol loop and of the hub, for the server."""

    def __init__(
        out self,
        hub: ArcPointer[StreamHub[Self.T]],
        options: TransportOptions = TransportOptions(),
        var sys: Sys = Sys(),
    ) raises:
        """Make a handler.

        Args:
            hub: The shared hub.
            options: The protocol options.
            sys: The system calls; a test injects faults here.

        Raises:
            Error: When an epoll instance cannot open.
        """
        self.hub = hub
        self.transport = TransportServer(RouterWsExecutor(hub), options)
        self.sys = sys^
        self.epoll = self.sys.epoll_create()
        if self.epoll < 0:
            raise Error("epoll_create failed: " + String(-self.epoll))
        _ = self.sys.epoll_ctl(
            self.epoll, EPOLL_CTL_ADD, self.transport.fd(), EPOLLIN
        )
        _ = self.sys.epoll_ctl(self.epoll, EPOLL_CTL_ADD, hub[].fd(), EPOLLIN)

    def __deinit__(deinit self):
        """Close the epoll descriptor."""
        self.sys.close(self.epoll)

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        """Start a connection.

        Args:
            sockets: The open connections.
            id: The socket.

        Raises:
            Error: The errors of the protocol server.
        """
        self.transport.on_open(sockets, id)

    def on_message(
        mut self, mut sockets: Sockets, id: Int, message: Message
    ) raises:
        """Handle one message.

        Args:
            sockets: The open connections.
            id: The socket.
            message: The message.

        Raises:
            Error: The errors of the protocol server.
        """
        self.transport.on_message(sockets, id, message)

    def on_close(
        mut self, mut sockets: Sockets, id: Int, code: UInt16, reason: String
    ):
        """End a connection and its subscriptions.

        Args:
            sockets: The open connections.
            id: The socket.
            code: The close code.
            reason: The close reason.
        """
        self.transport.on_close(sockets, id, code, reason)

    def on_tick(mut self, mut sockets: Sockets) raises:
        """Read the subgraph sockets, wake their subscriptions, and send
        their results.

        Args:
            sockets: The open connections.

        Raises:
            Error: The errors of the protocol server.
        """
        self.hub[].pump()
        self.transport.on_tick(sockets)

    def fd(self) -> Int:
        """Return the descriptor that is readable when there is work.

        Returns:
            The epoll of the protocol loop and of the hub.
        """
        return self.epoll

    def wait_ms(self) -> Int:
        """Return the longest wait of the loop.

        Returns:
            The wait of the protocol server.
        """
        return self.transport.wait_ms()


def serve_router[
    T: SubgraphTransport
](
    hub: ArcPointer[StreamHub[T]],
    var config: ServerConfig,
    path: String = "/graphql",
) raises -> Server[RouterWsHandler[T], RouterStreamHandler[T]]:
    """Make a server of a router that streams, on the port of `config`.

    Args:
        hub: The shared hub.
        config: The `gql_ws` configuration; `router_server_config` sets
            its WebSocket path.
        path: The GraphQL path.

    Returns:
        The server; call `run` or `poll`.

    Raises:
        Error: When the socket or an epoll cannot open.

    Parameters:
        T: The transport of the router.
    """
    config = router_server_config(hub[].config, config^, path)
    return listen(
        RouterWsHandler[T](hub), RouterStreamHandler[T](hub, path), config
    )


def router_server_config(
    subscriptions: SubscriptionsConfig, var config: ServerConfig, path: String
) -> ServerConfig:
    """Set the WebSocket path and subprotocol of a router server, as the
    `websocket` configuration says.

    Args:
        subscriptions: The `websocket` configuration: `enabled` and `path`.
        config: The `gql_ws` configuration.
        path: The GraphQL path, the default WebSocket path.

    Returns:
        The configuration with `path` and `protocols`. Without
        `websocket.enabled`, the WebSocket path is one that no request
        target has, so every request is plain HTTP.
    """
    config.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
    if not subscriptions.server_enabled:
        config.path = " "
    elif subscriptions.server_path.byte_length() > 0:
        config.path = subscriptions.server_path
    else:
        config.path = path
    return config^
