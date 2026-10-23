# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Run a subscription through the router: one subgraph stream, and the
rest of the plan for each event.

Port of the subscription part of `execute_query_plan` of Hive Router
`1a29df9` `bin/router/src/executor/execution/plan.rs`, with the protocol
choice of `SubgraphExecutorMap::subscribe` (`executor/executors/map.rs`).

`StreamHub` holds the router, the subscription configuration and the
subgraph WebSocket pool. One hub serves every client of a server. Its
copies are `ArcPointer`s that share it, on one thread.

`open_subscription` sends the subscription fetch of a prepared request to
its subgraph, over WebSocket or over HTTP streaming, as
`SubscriptionsConfig.protocol_for_subgraph` picks. A `RouterSubscription`
then gives one response for each subgraph event: the router runs the
nodes after the `Subscription` node, such as the entity fetches, and
projects the event, in `Router.subscription_event`. A failure of the
subgraph stream or of an event is one last response with the error, and
the stream ends, as upstream.

`RouterSubscription` is a `gql_stream` `EventStream` for the WebSocket
server. `next_body` gives the same responses as bytes, for the HTTP
streams. A subscription that waits keeps its waker in the hub, and
`StreamHub.pump` wakes it when a subgraph socket has bytes. `fd` is the
epoll descriptor of the subgraph sockets, for the loop of a server.

**Differences from upstream.** The subscription request is sent, and the
head of an HTTP response is read, with a wait. The router does not share
one subgraph subscription between equal client subscriptions
(`active_subscriptions` deduplication), and has no broadcast buffer. The
HTTP callback protocol is not ported: a callback subgraph gives the error
`SUBGRAPH_HTTP_CALLBACK_NOT_SUPPORTED`.
"""

from std.memory import ArcPointer
from std.time import perf_counter_ns

from gql_http.body import BodyPoll
from gql_http.socket import EPOLL_CTL_ADD, EPOLL_CTL_DEL, EPOLLIN, Sys
from gql_router.exec_http import SubgraphTransport
from gql_router.exec_variables import CoerceVariablesPayload
from gql_router.pipeline import PipelineError, PreparedRequest, Router
from gql_router_stream.config import SubscriptionProtocol, SubscriptionsConfig
from gql_router_stream.subgraph_http import HttpSubscription, StreamError
from gql_router_stream.subgraph_ws import WsPool, websocket_url
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.waker import Waker

comptime _ = String().as_bytes()


struct StreamHub[T: SubgraphTransport](Movable):
    """The router and the subgraph streams of every subscription.

    Parameters:
        T: The transport of the queries and entity fetches.
    """

    var router: Router[Self.T]
    """The router."""
    var config: SubscriptionsConfig
    """The subscription configuration."""
    var pool: WsPool
    """The subgraph WebSocket connections."""
    var sys: Sys
    """The system calls."""
    var epoll: Int
    """The epoll descriptor of the subgraph sockets."""
    var watched: List[Int]
    """The pool connections in `epoll`."""
    var waiting: List[Waker]
    """The wakers of the subscriptions that wait for an event."""
    var active: Int
    """The count of open subscriptions."""
    var last_pump_ns: Int
    """When `pump` last ran."""

    def __init__(
        out self,
        var router: Router[Self.T],
        var config: SubscriptionsConfig,
        var sys: Sys = Sys(),
    ) raises:
        """Make a hub.

        Args:
            router: The router.
            config: The subscription configuration.
            sys: The system calls; a test injects faults here.

        Raises:
            Error: When the epoll instance cannot open.
        """
        self.router = router^
        self.pool = WsPool(
            config.reuse_connections, config.pool_idle_timeout_ms
        )
        self.config = config^
        self.sys = sys^
        self.epoll = self.sys.epoll_create()
        if self.epoll < 0:
            raise Error("epoll_create failed: " + String(-self.epoll))
        self.watched = List[Int]()
        self.waiting = List[Waker]()
        self.active = 0
        self.last_pump_ns = 0

    def __deinit__(deinit self):
        """Close the epoll descriptor."""
        self.sys.close(self.epoll)

    def fd(self) -> Int:
        """Return the descriptor that is readable when a subgraph socket
        has bytes.

        Returns:
            The epoll descriptor.
        """
        return self.epoll

    def url_of(self, subgraph: StringSlice) -> String:
        """Return the URL of a subgraph.

        Args:
            subgraph: The subgraph name.

        Returns:
            The URL from the supergraph, or empty for an unknown name.
        """
        ref schema = self.router.schema
        var index = 0
        while index < len(schema.subgraph_names):
            if schema.subgraph_names[index] == subgraph:
                return schema.subgraph_urls[index]
            index += 1
        return String()

    def watch(mut self, fd: Int):
        """Add a subgraph socket to the epoll set.

        Args:
            fd: The descriptor.
        """
        _ = self.sys.epoll_ctl(self.epoll, EPOLL_CTL_ADD, fd, EPOLLIN)

    def unwatch(mut self, fd: Int):
        """Remove a subgraph socket from the epoll set, before it closes.

        Args:
            fd: The descriptor.
        """
        _ = self.sys.epoll_ctl(self.epoll, EPOLL_CTL_DEL, fd, 0)

    def sync_pool(mut self):
        """Watch each open pool connection, and forget the closed ones."""
        var open = self.pool.fds()
        var index = 0
        while index < len(self.watched):
            if self.watched[index] in open:
                index += 1
            else:
                _ = self.watched.pop(index)
        for fd in open:
            if fd not in self.watched:
                self.watched.append(fd)
                self.watch(fd)

    def park(mut self, waker: Waker):
        """Keep the waker of a subscription that waits.

        Args:
            waker: The waker.
        """
        self.waiting.append(waker.copy())

    def pump(mut self):
        """Read the subgraph WebSockets, and wake each waiting
        subscription."""
        self.last_pump_ns = Int(perf_counter_ns())
        self.pool.pump()
        self.pool.sweep()
        self.sync_pool()
        var wake = self.waiting^
        self.waiting = List[Waker]()
        for waker in wake:
            waker.wake()

    def refresh(mut self):
        """Run `pump` when it has not run in the last millisecond."""
        if Int(perf_counter_ns()) - self.last_pump_ns >= 1_000_000:
            self.pump()


struct RouterSubscription[T: SubgraphTransport](EventStream):
    """One client subscription: a subgraph stream and the router.

    Parameters:
        T: The transport of the entity fetches.
    """

    var hub: ArcPointer[StreamHub[Self.T]]
    """The shared hub."""
    var slot: Int
    """The pinned slot of the operation."""
    var variables: CoerceVariablesPayload
    """The coerced variables."""
    var subgraph: String
    """The subgraph of the subscription fetch."""
    var ws_operation: Int
    """The operation in the WebSocket pool, or -1."""
    var http: Optional[HttpSubscription]
    """The HTTP stream, when the subgraph uses HTTP."""
    var queue: List[List[UInt8]]
    """The subgraph events that are not executed yet."""
    var head: Int
    """The next event of `queue`."""
    var ended: Bool
    """Whether the subgraph stream has ended."""
    var failure: List[UInt8]
    """The last response, with an error, or empty."""
    var finished: Bool
    """Whether the stream gave its last response."""
    var released: Bool
    """Whether the slot and the source are released."""

    def __init__(
        out self,
        hub: ArcPointer[StreamHub[Self.T]],
        slot: Int,
        var variables: CoerceVariablesPayload,
        var subgraph: String,
    ):
        """Make a subscription without a source; `open_subscription`
        opens it.

        Args:
            hub: The shared hub.
            slot: The slot of the operation; this pins it.
            variables: The coerced variables.
            subgraph: The subgraph of the subscription fetch.
        """
        self.hub = hub
        self.slot = slot
        self.variables = variables^
        self.subgraph = subgraph^
        self.ws_operation = -1
        self.http = None
        self.queue = List[List[UInt8]]()
        self.head = 0
        self.ended = False
        self.failure = List[UInt8]()
        self.finished = False
        self.released = False
        self.hub[].router.pin(slot)
        self.hub[].active += 1

    def __deinit__(deinit self):
        """Release the source and the slot."""
        self._release()

    def fail(mut self, error: StreamError):
        """End the subgraph stream with an error: the next response is the
        error, and the stream ends.

        Args:
            error: The failure.
        """
        self.failure = error.body(self.subgraph)
        self.ended = True

    def _fill(mut self):
        """Move the events of the subgraph stream to the queue."""
        if self.ended:
            return
        if self.ws_operation >= 0:
            self.ended = self.hub[].pool.take(self.ws_operation, self.queue)
            return
        try:
            self.ended = self.http.value().poll(self.queue)
        except error:
            self.fail(error)

    def next_body(mut self, mut out: List[UInt8]) -> BodyPoll:
        """Give the next response, without a wait.

        Args:
            out: Where the JSON of the response goes.

        Returns:
            `READY` with a response, `PENDING` when no event has come, and
            `DONE` after the last response.
        """
        if self.finished:
            return BodyPoll.DONE
        if self.head == len(self.queue):
            self.queue.clear()
            self.head = 0
            self._fill()
        if self.head < len(self.queue):
            var event = self.queue[self.head].copy()
            self.queue[self.head] = List[UInt8]()
            self.head += 1
            try:
                out.extend(
                    self.hub[].router.subscription_event(
                        self.slot, self.variables, event^
                    )
                )
            except error:
                self.fail(
                    StreamError(
                        "SUBREQUEST_MALFORMED_RESPONSE",
                        "Failed to deserialize subgraph response: "
                        + String(error),
                    )
                )
                self.queue.clear()
                self.head = 0
                return self.next_body(out)
            return BodyPoll.READY
        if not self.ended:
            return BodyPoll.PENDING
        self.finished = True
        self._release()
        if len(self.failure) > 0:
            out.extend(Span(self.failure))
            return BodyPoll.READY
        return BodyPoll.DONE

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Give the next response as an event, as an `EventStream`.

        Args:
            waker: The waker; the hub keeps it while the stream waits.

        Returns:
            `READY` with the response, `PENDING`, or `DONE`.
        """
        var out = List[UInt8]()
        var state = self.next_body(out)
        if state == BodyPoll.PENDING:
            self.hub[].park(waker)
            return Poll.pending()
        if state == BodyPoll.DONE:
            return Poll.done()
        return event_poll(out)

    def _release(mut self):
        """Close the subgraph stream and unpin the slot, once."""
        if self.released:
            return
        self.released = True
        if self.ws_operation >= 0:
            self.hub[].pool.release(self.ws_operation)
            self.hub[].sync_pool()
        if self.http:
            self.hub[].unwatch(self.http.value().fd())
            self.http.value().close()
        self.hub[].router.unpin(self.slot)
        self.hub[].active -= 1

    def close(mut self):
        """End the stream: the subgraph sees the client go away."""
        self.finished = True
        self._release()


def event_poll(body: List[UInt8]) -> Poll:
    """Make the poll result of one response.

    Args:
        body: The JSON of the response.

    Returns:
        `READY` with the response as an event, or `ERROR` when the body is
        not JSON.
    """
    try:
        return Poll.ready(Event.parse(StringSlice(unsafe_from_utf8=body)))
    except error:
        return Poll.error(String(error))


def open_subscription[
    T: SubgraphTransport
](
    hub: ArcPointer[StreamHub[T]], prepared: PreparedRequest
) raises PipelineError -> RouterSubscription[T]:
    """Open the subgraph stream of a prepared subscription.

    Args:
        hub: The shared hub.
        prepared: A subscription from `Router.prepare_request`.

    Returns:
        The subscription. A subgraph stream that fails to open gives one
        response with the error, and ends.

    Raises:
        PipelineError: When the plan has no `Subscription` node.

    Parameters:
        T: The transport of the entity fetches.
    """
    var start = hub[].router.subscription_start(prepared)
    var subscription = RouterSubscription[T](
        hub, prepared.slot, prepared.variables.copy(), start.subgraph
    )
    var protocol = hub[].config.protocol_for_subgraph(start.subgraph)
    var url = hub[].url_of(start.subgraph)
    if protocol == SubscriptionProtocol.HTTP_CALLBACK:
        subscription.fail(
            StreamError(
                "SUBGRAPH_HTTP_CALLBACK_NOT_SUPPORTED",
                "The HTTP callback protocol is not supported",
            )
        )
        return subscription^
    if protocol == SubscriptionProtocol.WEBSOCKET:
        var ws = websocket_url(url, hub[].config.websocket_path(start.subgraph))
        try:
            subscription.ws_operation = hub[].pool.subscribe(
                ws, StringSlice(unsafe_from_utf8=start.body)
            )
        except error:
            subscription.fail(
                StreamError(
                    "SUBGRAPH_WEBSOCKET_CONNECT_FAILURE",
                    "Failed to connect WebSocket to '"
                    + ws
                    + "': "
                    + String(error),
                )
            )
        hub[].sync_pool()
        return subscription^
    try:
        var http = HttpSubscription.open(url, start.body)
        hub[].watch(http.fd())
        subscription.http = http^
    except error:
        subscription.fail(error)
    return subscription^
