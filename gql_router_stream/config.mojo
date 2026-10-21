# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `subscriptions` and `websocket` configuration of the router.

Port of Hive Router `1a29df9` `bin/router/src/config/subscriptions.rs`
(`SubscriptionsConfig`, `CallbackConfig`, `WebSocketConfig`,
`SupergraphSubscriptionsConfig`, `SubscriptionProtocol`) and
`config/websocket.rs` (the WebSocket server of the router), with the
`reuse_connections` and `pool_idle_timeout` fields of
`config/traffic_shaping.rs` that the WebSocket pool reads.

`subscriptions_config_from_json` reads the JSON form of the YAML
configuration. An unknown field is an error, as upstream
`deny_unknown_fields`.

**Differences from upstream.** The configuration is JSON, not YAML.
`callback` is read, but a subscription to a callback subgraph fails: the
HTTP callback protocol is not ported. `listen` and the expressions of
`public_url` are not read.
"""

from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument, JsonKind


@fieldwise_init
struct SubscriptionProtocol(Equatable, ImplicitlyCopyable, Writable):
    """The protocol of the subscriptions to a subgraph, as upstream
    `SubscriptionProtocol`."""

    var value: UInt8
    """The index; see `is_valid`."""

    comptime HTTP = SubscriptionProtocol(0)
    """HTTP streaming: SSE, Apollo multipart or incremental delivery."""
    comptime WEBSOCKET = SubscriptionProtocol(1)
    """GraphQL over WebSocket, `graphql-transport-ws`."""
    comptime HTTP_CALLBACK = SubscriptionProtocol(2)
    """The HTTP callback protocol; not ported."""

    def is_valid(self) -> Bool:
        """Tell if the index names a protocol.

        Returns:
            True for the three protocols.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the protocol.

        Args:
            writer: The destination.
        """
        if self == SubscriptionProtocol.HTTP:
            writer.write("HTTP")
        elif self == SubscriptionProtocol.WEBSOCKET:
            writer.write("WebSocket")
        else:
            writer.write("HTTPCallback")


@fieldwise_init
struct HeadersSource(Equatable, ImplicitlyCopyable):
    """Where a WebSocket client gives its headers, as upstream
    `WebSocketHeadersSource`."""

    var value: UInt8
    """The index; see `is_valid`."""

    comptime NONE = HeadersSource(0)
    """No headers."""
    comptime CONNECTION = HeadersSource(1)
    """The payload of `connection_init`, the default."""
    comptime OPERATION = HeadersSource(2)
    """The extensions of each `subscribe`."""
    comptime BOTH = HeadersSource(3)
    """Both places."""

    def is_valid(self) -> Bool:
        """Tell if the index names a source.

        Returns:
            True for the four sources.
        """
        return self.value <= 3


struct SubscriptionsConfig(Copyable, Movable):
    """The `subscriptions` and `websocket` configuration."""

    var enabled: Bool
    """Whether the router accepts subscriptions; False by default."""
    var broadcast_capacity: Int
    """The events that one shared subscription buffers; 32."""
    var subgraph_buffer_capacity: Int
    """The events that one subgraph stream buffers; 1024."""
    var callback_subgraphs: List[String]
    """The subgraphs of `callback.subgraphs`."""
    var callback_path: String
    """`callback.path`; `/callback` by default."""
    var heartbeat_interval_ms: Int
    """`callback.heartbeat_interval`; 5000 by default."""
    var has_websocket: Bool
    """Whether `subscriptions.websocket` is set."""
    var websocket_all: Bool
    """Whether `subscriptions.websocket.all` is set."""
    var websocket_all_path: String
    """The path of `websocket.all`, or empty."""
    var websocket_subgraphs: List[String]
    """The subgraphs of `websocket.subgraphs`."""
    var websocket_paths: List[String]
    """The path of each of those subgraphs, or empty."""
    var reuse_connections: Bool
    """Whether subscriptions share one subgraph WebSocket; True."""
    var pool_idle_timeout_ms: Int
    """How long an unused pooled WebSocket stays open; 50000."""
    var server_enabled: Bool
    """`websocket.enabled`: the WebSocket server of the router."""
    var server_path: String
    """`websocket.path`, or empty for the GraphQL path."""
    var headers_source: HeadersSource
    """`websocket.headers.source`."""
    var headers_persist: Bool
    """`websocket.headers.persist`."""

    def __init__(out self):
        """Make the default configuration."""
        self.enabled = False
        self.broadcast_capacity = 32
        self.subgraph_buffer_capacity = 1024
        self.callback_subgraphs = List[String]()
        self.callback_path = String("/callback")
        self.heartbeat_interval_ms = 5000
        self.has_websocket = False
        self.websocket_all = False
        self.websocket_all_path = String()
        self.websocket_subgraphs = List[String]()
        self.websocket_paths = List[String]()
        self.reuse_connections = True
        self.pool_idle_timeout_ms = 50000
        self.server_enabled = False
        self.server_path = String()
        self.headers_source = HeadersSource.CONNECTION
        self.headers_persist = False

    def protocol_for_subgraph(
        self, subgraph: StringSlice
    ) -> SubscriptionProtocol:
        """Pick the protocol of a subgraph, as upstream
        `get_protocol_for_subgraph`.

        Args:
            subgraph: The subgraph name.

        Returns:
            `HTTP_CALLBACK` for a callback subgraph, `WEBSOCKET` when
            `websocket.all` or the subgraph is set, else `HTTP`.
        """
        for name in self.callback_subgraphs:
            if name == subgraph:
                return SubscriptionProtocol.HTTP_CALLBACK
        if self.websocket_all or self._ws_index(subgraph) >= 0:
            return SubscriptionProtocol.WEBSOCKET
        return SubscriptionProtocol.HTTP

    def websocket_path(self, subgraph: StringSlice) -> String:
        """Return the WebSocket path of a subgraph, as upstream
        `get_websocket_path`.

        Args:
            subgraph: The subgraph name.

        Returns:
            The path of the subgraph, else the path of `all`, else empty:
            the path of the subgraph URL.
        """
        var index = self._ws_index(subgraph)
        if index >= 0 and self.websocket_paths[index].byte_length() > 0:
            return self.websocket_paths[index]
        return self.websocket_all_path

    def accepts_connection_headers(self) -> Bool:
        """Tell if `connection_init` can carry headers.

        Returns:
            True for `connection` and `both`.
        """
        return (
            self.headers_source == HeadersSource.CONNECTION
            or self.headers_source == HeadersSource.BOTH
        )

    def accepts_operation_headers(self) -> Bool:
        """Tell if a `subscribe` can carry headers.

        Returns:
            True for `operation` and `both`.
        """
        return (
            self.headers_source == HeadersSource.OPERATION
            or self.headers_source == HeadersSource.BOTH
        )

    def _ws_index(self, subgraph: StringSlice) -> Int:
        """Return the index of a subgraph in `websocket.subgraphs`, or -1."""
        var index = 0
        while index < len(self.websocket_subgraphs):
            if self.websocket_subgraphs[index] == subgraph:
                return index
            index += 1
        return -1


def _require(
    document: JsonDocument, node: Int, kind: JsonKind, name: String
) raises:
    """Raise when a member does not have the kind it must have."""
    if document.kind(node) != kind:
        raise Error(
            "Invalid subscriptions config: " + name + " has the wrong type"
        )


def _check_keys(
    document: JsonDocument, node: Int, names: List[String], place: String
) raises:
    """Require an object whose members are all in `names`."""
    _require(document, node, JsonKind.OBJECT, place)
    var child = document.first(node)
    while child != NO_NODE:
        var key = String(document.key(child))
        if key not in names:
            raise Error(
                "Invalid subscriptions config: unknown field "
                + place
                + "."
                + key
            )
        child = document.next(child)


def _bool(
    document: JsonDocument, node: Int, key: String, default: Bool
) raises -> Bool:
    """Read a boolean member, or its default."""
    var found = document.find(node, key)
    if found == NO_NODE:
        return default
    _require(document, found, JsonKind.BOOLEAN, key)
    return document.bool_value(found)


def _int(
    document: JsonDocument, node: Int, key: String, default: Int
) raises -> Int:
    """Read a whole number member that is not negative, or its default."""
    var found = document.find(node, key)
    if found == NO_NODE:
        return default
    _require(document, found, JsonKind.NUMBER, key)
    var value = Int(document.as_int64(found))
    if value < 0:
        raise Error("Invalid subscriptions config: " + key + " is negative")
    return value


def _string(
    document: JsonDocument, node: Int, key: String, default: String
) raises -> String:
    """Read a string member, or its default."""
    var found = document.find(node, key)
    if found == NO_NODE:
        return default
    _require(document, found, JsonKind.STRING, key)
    return document.string_value(found)


def absolute_path(path: String) raises -> String:
    """Check a path, as upstream `AbsolutePath::try_from`.

    Args:
        path: The path.

    Returns:
        The path.

    Raises:
        Error: `path must be absolute (start with /), got: "<path>"`.
    """
    if not path.startswith("/"):
        raise Error('path must be absolute (start with /), got: "' + path + '"')
    return path


def duration_ms(text: String) raises -> Int:
    """Read a humantime duration such as `5s`, as upstream
    `humantime_serde`.

    Args:
        text: Digits and a unit: `ms`, `s`, `m` or `h`.

    Returns:
        The duration in milliseconds.

    Raises:
        Error: When the text is not a duration.
    """
    var bytes = text.as_bytes()
    var index = 0
    var number = 0
    while index < len(bytes) and bytes[index] >= 48 and bytes[index] <= 57:
        number = number * 10 + Int(bytes[index] - 48)
        index += 1
    var unit = String(text[byte=index:])
    if index > 0:
        if unit == "ms":
            return number
        if unit == "s":
            return number * 1000
        if unit == "m":
            return number * 60000
        if unit == "h":
            return number * 3600000
    raise Error("Invalid subscriptions config: invalid duration " + text)


def _read_callback(
    document: JsonDocument, node: Int, mut config: SubscriptionsConfig
) raises:
    """Read `subscriptions.callback`, as upstream `CallbackConfig`."""
    _check_keys(
        document,
        node,
        ["public_url", "path", "heartbeat_interval", "listen", "subgraphs"],
        "callback",
    )
    if document.find(node, "public_url") == NO_NODE:
        raise Error("Invalid subscriptions config: missing field `public_url`")
    _ = _string(document, node, "public_url", String())
    config.callback_path = absolute_path(
        _string(document, node, "path", "/callback")
    )
    var interval = _string(document, node, "heartbeat_interval", "5s")
    config.heartbeat_interval_ms = duration_ms(interval)
    var subgraphs = document.find(node, "subgraphs")
    if subgraphs != NO_NODE:
        _require(document, subgraphs, JsonKind.ARRAY, "subgraphs")
        for item in document.children(subgraphs):
            _require(document, item, JsonKind.STRING, "subgraphs")
            config.callback_subgraphs.append(document.string_value(item))


def _read_ws_path(
    document: JsonDocument, node: Int, place: String
) raises -> String:
    """Read one `WebSocketSubgraphConfig`: its optional path."""
    _check_keys(document, node, ["path"], place)
    var path = _string(document, node, "path", String())
    if path.byte_length() > 0:
        _ = absolute_path(path)
    return path


def _read_subgraph_ws(
    document: JsonDocument, node: Int, mut config: SubscriptionsConfig
) raises:
    """Read `subscriptions.websocket`, as upstream `WebSocketConfig`."""
    _check_keys(document, node, ["all", "subgraphs"], "websocket")
    config.has_websocket = True
    var all = document.find(node, "all")
    if all != NO_NODE:
        config.websocket_all = True
        config.websocket_all_path = _read_ws_path(document, all, "all")
    var subgraphs = document.find(node, "subgraphs")
    if subgraphs != NO_NODE:
        _require(document, subgraphs, JsonKind.OBJECT, "subgraphs")
        for item in document.children(subgraphs):
            config.websocket_subgraphs.append(document.key(item))
            config.websocket_paths.append(
                _read_ws_path(document, item, document.key(item))
            )


def _read_server(
    document: JsonDocument, node: Int, mut config: SubscriptionsConfig
) raises:
    """Read the top-level `websocket`, as upstream `config/websocket.rs`."""
    _check_keys(document, node, ["enabled", "path", "headers"], "websocket")
    config.server_enabled = _bool(document, node, "enabled", False)
    var path = _string(document, node, "path", String())
    if path.byte_length() > 0:
        config.server_path = absolute_path(path)
    var headers = document.find(node, "headers")
    if headers != NO_NODE:
        _check_keys(document, headers, ["source", "persist"], "headers")
        var source = _string(document, headers, "source", "connection")
        if source == "none":
            config.headers_source = HeadersSource.NONE
        elif source == "connection":
            config.headers_source = HeadersSource.CONNECTION
        elif source == "operation":
            config.headers_source = HeadersSource.OPERATION
        elif source == "both":
            config.headers_source = HeadersSource.BOTH
        else:
            raise Error(
                "Invalid subscriptions config: unknown headers source " + source
            )
        config.headers_persist = _bool(document, headers, "persist", False)


def _read_traffic(
    document: JsonDocument, node: Int, mut config: SubscriptionsConfig
) raises:
    """Read `traffic_shaping.all.pool_idle_timeout` and
    `traffic_shaping.all.websocket.reuse_connections`."""
    _check_keys(document, node, ["all"], "traffic_shaping")
    var all = document.find(node, "all")
    if all == NO_NODE:
        return
    _check_keys(document, all, ["pool_idle_timeout", "websocket"], "all")
    var idle = document.find(all, "pool_idle_timeout")
    if idle != NO_NODE:
        config.pool_idle_timeout_ms = duration_ms(
            _string(document, all, "pool_idle_timeout", String())
        )
    var websocket = document.find(all, "websocket")
    if websocket != NO_NODE:
        _check_keys(document, websocket, ["reuse_connections"], "websocket")
        config.reuse_connections = _bool(
            document, websocket, "reuse_connections", True
        )


def subscriptions_config_from_json(text: String) raises -> SubscriptionsConfig:
    """Read the streaming configuration of the router.

    Args:
        text: A JSON object with the optional members `subscriptions`,
            `websocket` and `traffic_shaping`. `{}` is the default.

    Returns:
        The configuration.

    Raises:
        Error: For an unknown field, a member of the wrong type, a path
            that is not absolute, or a bad duration.
        JsonError: When the text is not JSON.
    """
    var document = parse(text)
    var config = SubscriptionsConfig()
    _check_keys(
        document, 0, ["subscriptions", "websocket", "traffic_shaping"], "config"
    )
    var subscriptions = document.find(0, "subscriptions")
    if subscriptions != NO_NODE:
        _check_keys(
            document,
            subscriptions,
            [
                "enabled",
                "broadcast_capacity",
                "subgraph_buffer_capacity",
                "callback",
                "websocket",
            ],
            "subscriptions",
        )
        config.enabled = _bool(document, subscriptions, "enabled", False)
        config.broadcast_capacity = _int(
            document, subscriptions, "broadcast_capacity", 32
        )
        config.subgraph_buffer_capacity = _int(
            document, subscriptions, "subgraph_buffer_capacity", 1024
        )
        var callback = document.find(subscriptions, "callback")
        if callback != NO_NODE:
            _read_callback(document, callback, config)
        var websocket = document.find(subscriptions, "websocket")
        if websocket != NO_NODE:
            _read_subgraph_ws(document, websocket, config)
    var server = document.find(0, "websocket")
    if server != NO_NODE:
        _read_server(document, server, config)
    var traffic = document.find(0, "traffic_shaping")
    if traffic != NO_NODE:
        _read_traffic(document, traffic, config)
    return config^
