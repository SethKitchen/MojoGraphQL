# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the streaming configuration of the router.

Ports the `tests` module of Hive Router `1a29df9`
`bin/router/src/config/subscriptions.rs` (the absolute callback path), and
adds the defaults, the protocol of each subgraph and the errors of the
JSON reader.
"""

from gql_router_stream.config import (
    HeadersSource,
    SubscriptionProtocol,
    absolute_path,
    duration_ms,
    subscriptions_config_from_json,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_callback_path_must_be_absolute() raises:
    with assert_raises(contains="path must be absolute (start with /)"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"callback": {"public_url":'
            ' "http://localhost:4000/callback", "path": "callback"}}}'
        )


def test_callback_path_absolute_is_accepted() raises:
    var config = subscriptions_config_from_json(
        '{"subscriptions": {"callback": {"public_url":'
        ' "http://localhost:4000/callback", "path": "/hook",'
        ' "heartbeat_interval": "2s", "subgraphs": ["a"]}}}'
    )
    assert_equal(config.callback_path, "/hook")
    assert_equal(config.heartbeat_interval_ms, 2000)
    assert_equal(len(config.callback_subgraphs), 1)


def test_callback_path_defaults_to_absolute() raises:
    var config = subscriptions_config_from_json(
        '{"subscriptions": {"callback": {"public_url": "http://x/callback"}}}'
    )
    assert_equal(config.callback_path, "/callback")
    assert_equal(config.heartbeat_interval_ms, 5000)
    var empty = subscriptions_config_from_json(
        '{"subscriptions": {"callback": {"public_url": "u", "subgraphs": []},'
        ' "websocket": {"subgraphs": {}}}}'
    )
    assert_equal(len(empty.callback_subgraphs), 0)
    assert_equal(len(empty.websocket_subgraphs), 0)


def test_callback_errors() raises:
    with assert_raises(contains="missing field `public_url`"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"callback": {}}}'
        )
    with assert_raises(contains="subgraphs has the wrong type"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"callback": {"public_url": "u",'
            ' "subgraphs": "a"}}}'
        )
    with assert_raises(contains="subgraphs has the wrong type"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"callback": {"public_url": "u",'
            ' "subgraphs": [1]}}}'
        )
    with assert_raises(contains="public_url has the wrong type"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"callback": {"public_url": 1}}}'
        )


def test_defaults() raises:
    var config = subscriptions_config_from_json("{}")
    assert_false(config.enabled)
    assert_equal(config.broadcast_capacity, 32)
    assert_equal(config.subgraph_buffer_capacity, 1024)
    assert_true(config.reuse_connections)
    assert_equal(config.pool_idle_timeout_ms, 50000)
    assert_false(config.server_enabled)
    assert_true(config.headers_source == HeadersSource.CONNECTION)
    assert_true(config.accepts_connection_headers())
    assert_false(config.accepts_operation_headers())
    assert_true(config.protocol_for_subgraph("a") == SubscriptionProtocol.HTTP)
    assert_equal(config.websocket_path("a"), "")


def test_subscriptions_members() raises:
    var config = subscriptions_config_from_json(
        '{"subscriptions": {"enabled": true, "broadcast_capacity": 4,'
        ' "subgraph_buffer_capacity": 8}}'
    )
    assert_true(config.enabled)
    assert_equal(config.broadcast_capacity, 4)
    assert_equal(config.subgraph_buffer_capacity, 8)
    with assert_raises(contains="broadcast_capacity is negative"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"broadcast_capacity": -1}}'
        )
    with assert_raises(contains="broadcast_capacity has the wrong type"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"broadcast_capacity": "1"}}'
        )
    with assert_raises(contains="enabled has the wrong type"):
        _ = subscriptions_config_from_json('{"subscriptions": {"enabled": 1}}')
    with assert_raises(contains="unknown field subscriptions.other"):
        _ = subscriptions_config_from_json('{"subscriptions": {"other": 1}}')
    with assert_raises(contains="config has the wrong type"):
        _ = subscriptions_config_from_json("[]")


def test_protocol_for_subgraph() raises:
    var config = subscriptions_config_from_json(
        '{"subscriptions": {"callback": {"public_url": "u", "subgraphs":'
        ' ["cb", "other"]}, "websocket": {"subgraphs": {"ws": {"path":'
        ' "/ws"}, "plain": {}}}}}'
    )
    assert_true(config.has_websocket)
    assert_false(config.websocket_all)
    assert_true(
        config.protocol_for_subgraph("cb") == SubscriptionProtocol.HTTP_CALLBACK
    )
    assert_true(
        config.protocol_for_subgraph("ws") == SubscriptionProtocol.WEBSOCKET
    )
    assert_true(
        config.protocol_for_subgraph("plain") == SubscriptionProtocol.WEBSOCKET
    )
    assert_true(
        config.protocol_for_subgraph("http") == SubscriptionProtocol.HTTP
    )
    assert_equal(config.websocket_path("ws"), "/ws")
    assert_equal(config.websocket_path("plain"), "")
    assert_equal(config.websocket_path("http"), "")
    var all = subscriptions_config_from_json(
        '{"subscriptions": {"websocket": {"all": {"path": "/all"}}}}'
    )
    assert_true(all.websocket_all)
    assert_true(
        all.protocol_for_subgraph("x") == SubscriptionProtocol.WEBSOCKET
    )
    assert_equal(all.websocket_path("x"), "/all")
    with assert_raises(contains="path must be absolute"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"websocket": {"all": {"path": "all"}}}}'
        )
    with assert_raises(contains="subgraphs has the wrong type"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"websocket": {"subgraphs": []}}}'
        )
    with assert_raises(contains="path has the wrong type"):
        _ = subscriptions_config_from_json(
            '{"subscriptions": {"websocket": {"all": {"path": 1}}}}'
        )


def test_websocket_server() raises:
    var config = subscriptions_config_from_json(
        '{"websocket": {"enabled": true, "path": "/ws", "headers":'
        ' {"source": "both", "persist": true}}}'
    )
    assert_true(config.server_enabled)
    assert_equal(config.server_path, "/ws")
    assert_true(config.headers_persist)
    assert_true(config.accepts_connection_headers())
    assert_true(config.accepts_operation_headers())
    var none = subscriptions_config_from_json(
        '{"websocket": {"headers": {"source": "none"}}}'
    )
    assert_true(none.headers_source == HeadersSource.NONE)
    assert_false(none.accepts_connection_headers())
    assert_false(none.accepts_operation_headers())
    var operation = subscriptions_config_from_json(
        '{"websocket": {"headers": {"source": "operation"}}}'
    )
    assert_true(operation.headers_source == HeadersSource.OPERATION)
    assert_true(operation.accepts_operation_headers())
    var connection = subscriptions_config_from_json(
        '{"websocket": {"headers": {"source": "connection"}}}'
    )
    assert_true(connection.headers_source == HeadersSource.CONNECTION)
    var default = subscriptions_config_from_json(
        '{"websocket": {"path": "", "headers": {}}}'
    )
    assert_equal(default.server_path, "")
    assert_true(default.headers_source == HeadersSource.CONNECTION)
    with assert_raises(contains="unknown headers source x"):
        _ = subscriptions_config_from_json(
            '{"websocket": {"headers": {"source": "x"}}}'
        )
    with assert_raises(contains="path must be absolute"):
        _ = subscriptions_config_from_json('{"websocket": {"path": "ws"}}')
    var bare = subscriptions_config_from_json('{"websocket": {}}')
    assert_false(bare.server_enabled)


def test_traffic_shaping() raises:
    var config = subscriptions_config_from_json(
        '{"traffic_shaping": {"all": {"pool_idle_timeout": "3m",'
        ' "websocket": {"reuse_connections": false}}}}'
    )
    assert_equal(config.pool_idle_timeout_ms, 180000)
    assert_false(config.reuse_connections)
    var empty = subscriptions_config_from_json('{"traffic_shaping": {}}')
    assert_true(empty.reuse_connections)
    var inner = subscriptions_config_from_json(
        '{"traffic_shaping": {"all": {}}}'
    )
    assert_equal(inner.pool_idle_timeout_ms, 50000)


def test_absolute_path() raises:
    assert_equal(absolute_path("/a"), "/a")
    with assert_raises(
        contains='path must be absolute (start with /), got: "a"'
    ):
        _ = absolute_path("a")


def test_duration_ms() raises:
    assert_equal(duration_ms("250ms"), 250)
    assert_equal(duration_ms("5s"), 5000)
    assert_equal(duration_ms("2m"), 120000)
    assert_equal(duration_ms("1h"), 3600000)
    with assert_raises(contains="invalid duration 5d"):
        _ = duration_ms("5d")
    with assert_raises(contains="invalid duration s"):
        _ = duration_ms("s")
    with assert_raises(contains="invalid duration  5s"):
        _ = duration_ms(" 5s")
    with assert_raises(contains="invalid duration 5"):
        _ = duration_ms("5")


def test_kinds() raises:
    assert_true(SubscriptionProtocol.HTTP_CALLBACK.is_valid())
    assert_false(SubscriptionProtocol(3).is_valid())
    assert_true(HeadersSource.BOTH.is_valid())
    assert_false(HeadersSource(4).is_valid())
    assert_equal(String(SubscriptionProtocol.HTTP), "HTTP")
    assert_equal(String(SubscriptionProtocol.WEBSOCKET), "WebSocket")
    assert_equal(String(SubscriptionProtocol.HTTP_CALLBACK), "HTTPCallback")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
