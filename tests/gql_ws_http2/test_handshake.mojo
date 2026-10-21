# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_ws_http2.handshake`: the extended `CONNECT` of RFC 8441
section 4 and its answer.

There is no upstream suite: tungstenite has no HTTP/2 handshake. The cases
follow RFC 8441 section 5 (the example) and the subprotocol cases of
tungstenite 0.30.0 `src/handshake/client.rs`, as `tests/gql_ws` has them.
"""

from gql_http2.hpack import HeaderList
from gql_ws.error import WsError, WsErrorKind
from gql_ws_http2.handshake import (
    client_head,
    offered_protocols,
    reject_head,
    response_head,
    server_accept,
    verify_head,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _value(fields: HeaderList, name: StringSlice) -> String:
    """The first value of a field, or `<none>`."""
    var index = 0
    while index < fields.count():
        if fields.name_text(index) == name:
            return String(fields.value_text(index))
        index += 1
    return String("<none>")


def _status(fields: HeaderList, protocols: List[String]) raises -> Int:
    """The status of the refusal of a head, or 0 when it is accepted."""
    try:
        _ = server_accept(fields, protocols)
    except e:
        assert_true(e.kind == WsErrorKind.HANDSHAKE)
        return e.status
    return 0


def test_rfc8441_example() raises:
    # RFC 8441 section 5: the request of the chat example.
    var fields = client_head("https", "server.example.com", "/chat", ["chat"])
    assert_equal(_value(fields, ":method"), "CONNECT")
    assert_equal(_value(fields, ":protocol"), "websocket")
    assert_equal(_value(fields, ":scheme"), "https")
    assert_equal(_value(fields, ":path"), "/chat")
    assert_equal(_value(fields, ":authority"), "server.example.com")
    assert_equal(_value(fields, "sec-websocket-version"), "13")
    assert_equal(_value(fields, "sec-websocket-protocol"), "chat")
    var accepted = server_accept(fields, ["superchat", "chat"])
    assert_equal(accepted.path, "/chat")
    assert_equal(accepted.protocol, "chat")
    var answer = response_head(accepted.protocol)
    assert_equal(_value(answer, ":status"), "200")
    assert_equal(verify_head(200, answer, ["chat"]), "chat")


def test_offered_protocols() raises:
    var fields = client_head("http", "a", "/", ["one", "two"])
    fields.add_text("Sec-WebSocket-Protocol", " three ,, four")
    var offered = offered_protocols(fields)
    assert_equal(len(offered), 4)
    assert_equal(offered[0], "one")
    assert_equal(offered[1], "two")
    assert_equal(offered[2], "three")
    assert_equal(offered[3], "four")
    # The client's order wins, and an unknown protocol is skipped.
    var accepted = server_accept(fields, ["four", "two"])
    assert_equal(accepted.protocol, "two")
    var none = server_accept(client_head("http", "a", "/", []), ["x"])
    assert_equal(none.protocol, "")
    assert_equal(_value(response_head(""), "sec-websocket-protocol"), "<none>")
    assert_equal(
        _value(client_head("http", "a", "/", []), "sec-websocket-protocol"),
        "<none>",
    )


def test_refusals() raises:
    var get = HeaderList()
    get.add_text(":method", "GET")
    get.add_text(":path", "/")
    assert_equal(_status(get, []), 405)
    var no_method = HeaderList()
    assert_equal(_status(no_method, []), 405)
    var no_protocol = HeaderList()
    no_protocol.add_text(":method", "CONNECT")
    assert_equal(_status(no_protocol, []), 400)
    var other = HeaderList()
    other.add_text(":method", "CONNECT")
    other.add_text(":protocol", "the-bread-protocol")
    assert_equal(_status(other, []), 400)
    var no_version = HeaderList()
    no_version.add_text(":method", "CONNECT")
    no_version.add_text(":protocol", "WebSocket")
    assert_equal(_status(no_version.copy(), []), 426)
    var old = no_version.copy()
    old.add_text("sec-websocket-version", "8")
    assert_equal(_status(old, []), 426)
    var bare = no_version.copy()
    bare.add_text("sec-websocket-version", "13")
    assert_equal(_status(bare.copy(), []), 0)
    # Without :path, the path is empty; the connection refuses that first.
    assert_equal(server_accept(bare, []).path, "")


def test_reject_head() raises:
    var version = reject_head(WsError(WsErrorKind.HANDSHAKE, "v", 0, 426))
    assert_equal(_value(version, ":status"), "426")
    assert_equal(_value(version, "sec-websocket-version"), "13")
    var method = reject_head(WsError(WsErrorKind.HANDSHAKE, "m", 0, 405))
    assert_equal(_value(method, ":status"), "405")
    assert_equal(_value(method, "sec-websocket-version"), "<none>")
    # An error without a status of its own is 400.
    var plain = reject_head(WsError(WsErrorKind.PROTOCOL, "p", 0, 0))
    assert_equal(_value(plain, ":status"), "400")


def _verify_error(
    status: Int, fields: HeaderList, protocols: List[String]
) -> String:
    """The text of the refusal of an answer, or empty."""
    try:
        _ = verify_head(status, fields, protocols)
    except e:
        return e.message
    return String()


def test_verify_head() raises:
    var empty = HeaderList()
    assert_equal(_verify_error(404, empty, []), "HTTP error: 404")
    assert_equal(_verify_error(101, empty, []), "HTTP error: 101")
    assert_equal(verify_head(204, empty, []), "")
    # client.rs: the subprotocol cases.
    assert_equal(
        _verify_error(200, empty, ["graphql-transport-ws"]),
        "SubProtocol error: Server sent no subprotocol",
    )
    var chosen = response_head("graphql-transport-ws")
    assert_equal(
        _verify_error(200, chosen, []),
        "SubProtocol error: Server sent a subprotocol but none was requested",
    )
    assert_equal(
        _verify_error(200, chosen, ["chat"]),
        "SubProtocol error: Server sent an invalid subprotocol",
    )
    assert_false(
        verify_head(200, chosen, ["chat", "graphql-transport-ws"]) == ""
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
