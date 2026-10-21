# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Subgraph subscriptions over `graphql-transport-ws`, and their pool.

Port of Hive Router `1a29df9`
`bin/router/src/executor/executors/websocket_pool.rs` (`WebSocketPool`,
`PooledWebSocketExecutor`, `ConnectionOwner::run`) and the message
handling of `executor/executors/websocket_client.rs`
(`handle_text_frame`, `WsClientError`).

`WsPool.subscribe` sends a `subscribe` on an open connection to the same
subgraph URL, or opens one with `gql_ws.transport_client`. With
`reuse_connections`, the operations share the connection; without it,
each one has its own. `pump` reads every connection without a wait and
gives each `next` payload to its operation. An `error` message is the
event `{"errors":...}`, and then the operation ends, as upstream. A closed
connection is the event of `WsClientError::ConnectionClosed` for each of
its operations.

A connection without operations stays open for `idle_timeout_ms`, then
`sweep` closes it.

**Differences from upstream.** The pool runs on the thread of its owner,
without tasks; `subscribe` connects and waits for the `connection_ack`
before it returns. The connection fingerprint of the forwarded headers is
not ported, so the key of a connection is the subgraph and its URL.
"""

from std.time import perf_counter_ns

from gql_ws.error import WsError
from gql_ws.graphql_ws import MessageType
from gql_ws.transport_client import ClientEvent, TransportClient


comptime CONNECTION_CLOSED = (
    '{"errors":[{"message":"Connection closed","extensions":'
    + '{"code":"WS_CONNECTION_CLOSED"}}]}'
)
"""The event of a closed connection, as upstream
`From<WsClientError> for SubgraphResponse`."""


def _now_ms() -> Int:
    """Return a monotonic time in milliseconds."""
    return Int(perf_counter_ns() // 1_000_000)


def websocket_url(url: StringSlice, path: StringSlice) -> String:
    """Make the WebSocket URL of a subgraph URL, as upstream.

    Args:
        url: The `http://` or `https://` URL of the subgraph.
        path: The WebSocket path, or empty for the path of the URL.

    Returns:
        The `ws://` or `wss://` URL.
    """
    var text = String(url)
    var rest = text
    var scheme = String("ws://")
    if text.startswith("https://"):
        scheme = "wss://"
        rest = String(text[byte=8:])
    elif text.startswith("http://"):
        rest = String(text[byte=7:])
    if path.byte_length() == 0:
        return scheme + rest
    var slash = rest.find("/")
    var authority = rest if slash < 0 else String(rest[byte=:slash])
    return scheme + authority + String(path)


struct _Connection(Movable):
    """One open WebSocket to a subgraph."""

    var client: TransportClient
    var key: String
    var operations: Int
    var shared: Bool
    var idle_since_ms: Int
    var open: Bool

    def __init__(
        out self, var client: TransportClient, key: String, shared: Bool
    ):
        self.client = client^
        self.key = key
        self.operations = 0
        self.shared = shared
        self.idle_since_ms = 0
        self.open = True


struct _Operation(Copyable, Movable):
    """One subscription on a connection."""

    var connection: Int
    var id: String
    var events: List[List[UInt8]]
    var done: Bool
    var active: Bool

    def __init__(out self, connection: Int, id: String):
        self.connection = connection
        self.id = id
        self.events = List[List[UInt8]]()
        self.done = False
        self.active = True


struct WsPool(Movable):
    """The subgraph WebSocket connections of a router."""

    var reuse_connections: Bool
    """Whether operations to one URL share a connection."""
    var idle_timeout_ms: Int
    """How long a connection without operations stays open."""
    var ack_timeout_ms: Int
    """The longest wait for a `connection_ack`; 0 waits without a limit."""
    var _connections: List[_Connection]
    var _operations: List[_Operation]

    def __init__(
        out self,
        reuse_connections: Bool = True,
        idle_timeout_ms: Int = 50000,
        ack_timeout_ms: Int = 10000,
    ):
        """Make an empty pool.

        Args:
            reuse_connections: Whether operations share a connection.
            idle_timeout_ms: The idle time before a connection closes.
            ack_timeout_ms: The longest wait for a `connection_ack`.
        """
        self.reuse_connections = reuse_connections
        self.idle_timeout_ms = idle_timeout_ms
        self.ack_timeout_ms = ack_timeout_ms
        self._connections = List[_Connection]()
        self._operations = List[_Operation]()

    def connection_count(self) -> Int:
        """Count the open connections.

        Returns:
            The count.
        """
        var count = 0
        for index in range(len(self._connections)):
            ref connection = self._connections[index]
            if connection.open:
                count += 1
        return count

    def fds(self) -> List[Int]:
        """Return the descriptor of each open connection.

        Returns:
            The descriptors, for a loop to watch.
        """
        var out = List[Int]()
        for index in range(len(self._connections)):
            ref connection = self._connections[index]
            if connection.open:
                out.append(connection.client.socket.fd)
        return out^

    def _connection_for(mut self, url: String) raises WsError -> Int:
        """Find a shared open connection to a URL, or open one."""
        if self.reuse_connections:
            for index in range(len(self._connections)):
                ref connection = self._connections[index]
                # With `reuse_connections`, every connection is shared.
                if connection.open and connection.key == url:
                    return index
        var client = TransportClient.connect(url, "", self.ack_timeout_ms)
        var connection = _Connection(client^, url, self.reuse_connections)
        for index in range(len(self._connections)):
            if not self._connections[index].open:
                self._connections[index] = connection^
                return index
        self._connections.append(connection^)
        return len(self._connections) - 1

    def subscribe(
        mut self, url: String, payload: StringSlice
    ) raises WsError -> Int:
        """Start a subscription.

        Args:
            url: The `ws://` URL of the subgraph.
            payload: The JSON of the `subscribe` payload: the query and
                its variables.

        Returns:
            The operation id for `take` and `release`.

        Raises:
            WsError: When the connection, the handshake or the send fails.
        """
        var index = self._connection_for(url)
        var id: String
        try:
            id = self._connections[index].client.subscribe(payload)
        except e:
            self._close(index)
            raise e^
        self._connections[index].operations += 1
        var operation = _Operation(index, id)
        for slot in range(len(self._operations)):
            if not self._operations[slot].active:
                self._operations[slot] = operation^
                return slot
        self._operations.append(operation^)
        return len(self._operations) - 1

    def _find(self, connection: Int, id: StringSlice) -> Int:
        """Find the running operation with an id on a connection.

        The client drops a message whose operation has ended, and an
        operation ends in the client before it ends here. So the
        operation of each message that `next` gives is in the list.
        """
        var slot = 0
        while not (
            self._operations[slot].active
            and not self._operations[slot].done
            and self._operations[slot].connection == connection
            and self._operations[slot].id == id
        ):
            slot += 1
        return slot

    def _close(mut self, connection: Int):
        """Close an open connection; each of its operations gets the event
        of a closed connection and ends."""
        self._connections[connection].open = False
        self._connections[connection].client.socket.disconnect()
        var slot = 0
        while slot < len(self._operations):
            ref operation = self._operations[slot]
            slot += 1
            if (
                operation.active
                and not operation.done
                and operation.connection == connection
            ):
                operation.events.append(
                    List[UInt8](StringSlice(CONNECTION_CLOSED).as_bytes())
                )
                operation.done = True

    def pump(mut self):
        """Read each connection without a wait, and route its messages, as
        upstream `handle_text_frame`."""
        var event = ClientEvent()
        for index in range(len(self._connections)):
            while self._connections[index].open:
                var got: Bool
                try:
                    got = self._connections[index].client.next(event, 0)
                except:
                    self._close(index)
                    break
                if not got:
                    break
                ref operation = self._operations[self._find(index, event.id)]
                if event.type == MessageType.NEXT:
                    operation.events.append(
                        List[UInt8](event.payload.as_bytes())
                    )
                elif event.type == MessageType.ERROR:
                    var errors = '{"errors":' + event.payload + "}"
                    operation.events.append(List[UInt8](errors.as_bytes()))
                    operation.done = True
                else:
                    operation.done = True

    def take(mut self, operation: Int, mut events: List[List[UInt8]]) -> Bool:
        """Move the events of an operation.

        Args:
            operation: The id from `subscribe`.
            events: The destination; one JSON text per event.

        Returns:
            True when the operation has ended: no event follows.
        """
        ref op = self._operations[operation]
        for item in op.events:
            events.append(item.copy())
        op.events = List[List[UInt8]]()
        return op.done

    def release(mut self, operation: Int, now_ms: Int = -1):
        """End an operation: send `complete` when it is still running, and
        free its connection.

        Args:
            operation: The id from `subscribe`.
            now_ms: The current time, or -1 for the clock.
        """
        ref op = self._operations[operation]
        if not op.active:
            return
        op.active = False
        var index = op.connection
        ref connection = self._connections[index]
        if not connection.open:
            return
        if not op.done:
            try:
                connection.client.complete(op.id)
            except:
                self._close(index)
                return
        connection.operations -= 1
        if connection.operations == 0:
            if not connection.shared:
                self._close(index)
            else:
                connection.idle_since_ms = now_ms if now_ms >= 0 else _now_ms()

    def sweep(mut self, now_ms: Int = -1):
        """Close the shared connections without operations that are idle
        for `idle_timeout_ms`.

        Args:
            now_ms: The current time, or -1 for the clock.
        """
        var now = now_ms if now_ms >= 0 else _now_ms()
        for index in range(len(self._connections)):
            ref connection = self._connections[index]
            if (
                connection.open
                and connection.operations == 0
                and now - connection.idle_since_ms >= self.idle_timeout_ms
            ):
                self._close(index)
