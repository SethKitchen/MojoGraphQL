# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.http_transport`.

Ports the transport tests of Apollo MCP Server 2.0.0
`crates/apollo-mcp-server/src/server/states/running.rs` that apply to
phase 1 (`unknown_method_returns_http_not_found` and the Streamable HTTP
round trips); the statuses, texts and event framing are those of the
upstream binary.
"""

from _http import body_of, exchange, header_of, other, post
from gql_http.server import ServerConfig
from gql_http.socket import IPv4Address
from gql_mcp.http_transport import listen_http, new_session_id
from gql_mcp.operation import RawOperation
from gql_mcp.server import McpServer
from gql_mcp.server import ServerConfig as McpConfig
from gql_schema.build import build_schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime _INIT = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
comptime _PING = '{"jsonrpc":"2.0","id":3,"method":"ping"}'
comptime _NOTE = '{"jsonrpc":"2.0","method":"notifications/initialized"}'


def _config() -> ServerConfig:
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    return config^


def _mcp() raises -> McpServer:
    var config = McpConfig()
    config.validate_enabled = True
    return McpServer(
        config^, build_schema("type Query { a: Int }"), List[RawOperation]()
    )


def _status(response: String) -> String:
    return String(response[byte=9:12])


def test_session_ids() raises:
    var id = new_session_id()
    assert_equal(id.byte_length(), 36)
    assert_equal(String(id[byte=14:15]), "4")
    assert_true(String(id[byte=19:20]) in "89ab")
    assert_true(id != new_session_id())


def test_stateful_round_trip() raises:
    var server = listen_http(_mcp(), _config())
    var init = exchange(server, post(_INIT))
    assert_equal(_status(init), "200")
    assert_equal(header_of(init, "Content-Type"), "text/event-stream")
    assert_equal(header_of(init, "cache-control"), "no-cache")
    assert_equal(header_of(init, "x-accel-buffering"), "no")
    var id = header_of(init, "mcp-session-id")
    assert_equal(id.byte_length(), 36)
    assert_equal(
        body_of(init),
        "data: \nid: 0\nretry: 3000\n\ndata: "
        + '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18",'
        + '"capabilities":{"tools":{"listChanged":true}},"serverInfo":{"name":'
        + '"Apollo MCP Server","title":"Apollo MCP Server","version":"2.0.0",'
        + '"description":"A Model Context Protocol (MCP) server for exposing'
        + ' GraphQL APIs as tools.","websiteUrl":'
        + '"https://www.apollographql.com/docs/apollo-mcp-server"}}}\n\n',
    )
    var note = exchange(server, post(_NOTE, id))
    assert_equal(_status(note), "202")
    var first = exchange(server, post(_PING, id))
    assert_equal(
        body_of(first),
        (
            "data: \nid: 0/0\nretry: 3000\n\ndata:"
            ' {"jsonrpc":"2.0","id":3,"result":{}}\nid: 1/0\n\n'
        ),
    )
    var second = exchange(
        server, post('{"jsonrpc":"2.0","id":8,"method":"nope"}', id)
    )
    assert_equal(
        body_of(second),
        'data: \nid: 0/1\nretry: 3000\n\ndata: {"jsonrpc":"2.0","id":8,"error":'
        + '{"code":-32601,"message":"nope"}}\nid: 1/1\n\n',
    )
    var get = exchange(
        server,
        other(
            "GET",
            "/mcp",
            "Accept: text/event-stream\r\nMcp-Session-Id: " + id + "\r\n",
        ),
    )
    assert_equal(body_of(get), "data: \nid: 0\nretry: 3000\n\n")
    var deleted = exchange(
        server, other("DELETE", "/mcp", "Mcp-Session-Id: " + id + "\r\n")
    )
    assert_equal(_status(deleted), "202")
    var gone = exchange(server, post(_PING, id))
    assert_equal(_status(gone), "404")
    assert_equal(body_of(gone), "Not Found: Session not found")
    var again = exchange(
        server, other("DELETE", "/mcp", "Mcp-Session-Id: " + id + "\r\n")
    )
    assert_equal(_status(again), "202")
    server.close()


def _expect(response: String, status: StringSlice, body: StringSlice) raises:
    assert_equal(_status(response), status, response)
    assert_equal(body_of(response), body)


def test_stateful_refusals() raises:
    var server = listen_http(_mcp(), _config())
    var both = (
        "Not Acceptable: Client must accept both application/json and"
        " text/event-stream"
    )
    _expect(exchange(server, post(_INIT, accept="")), "406", both)
    _expect(
        exchange(server, post(_INIT, accept="application/json")), "406", both
    )
    _expect(
        exchange(server, post(_INIT, accept="text/event-stream")), "406", both
    )
    _expect(
        exchange(server, post(_INIT, content_type="text/plain")),
        "415",
        "Unsupported Media Type: Content-Type must be application/json",
    )
    _expect(
        exchange(server, post(_INIT, content_type="")),
        "415",
        "Unsupported Media Type: Content-Type must be application/json",
    )
    var garbage = exchange(server, post("garbage"))
    assert_equal(_status(garbage), "415")
    assert_true(
        body_of(garbage).startswith("fail to deserialize request body ")
    )
    _expect(
        exchange(server, post('{"id":9,"method":"ping"}')),
        "415",
        (
            "fail to deserialize request body data did not match any variant of"
            " untagged enum JsonRpcMessage"
        ),
    )
    var unexpected = "Unexpected message, expect initialize request"
    _expect(exchange(server, post(_PING)), "422", unexpected)
    _expect(exchange(server, post(_NOTE)), "422", unexpected)
    _expect(
        exchange(server, post(_PING, "nope")),
        "404",
        "Not Found: Session not found",
    )
    var put = exchange(server, other("PUT"))
    _expect(put, "405", "Method Not Allowed")
    assert_equal(header_of(put, "allow"), "GET, POST, DELETE")
    _expect(exchange(server, other("POST", "/other")), "404", "")
    _expect(
        exchange(server, other("GET")),
        "406",
        "Not Acceptable: Client must accept text/event-stream",
    )
    _expect(
        exchange(server, other("GET", "/mcp", "Accept: application/json\r\n")),
        "406",
        "Not Acceptable: Client must accept text/event-stream",
    )
    _expect(
        exchange(server, other("GET", "/mcp", "Accept: text/event-stream\r\n")),
        "400",
        "Bad Request: Session ID is required",
    )
    _expect(
        exchange(
            server,
            other(
                "GET",
                "/mcp",
                "Accept: text/event-stream\r\nMcp-Session-Id: x\r\n",
            ),
        ),
        "404",
        "Not Found: Session not found",
    )
    _expect(
        exchange(server, other("DELETE")),
        "400",
        "Bad Request: Session ID is required",
    )
    server.close()


def test_stateless() raises:
    var server = listen_http(_mcp(), _config(), False)
    _expect(
        exchange(server, post(_PING)),
        "200",
        'data: {"jsonrpc":"2.0","id":3,"result":{}}\n\n',
    )
    _expect(exchange(server, post(_NOTE)), "202", "")
    var init = exchange(server, post(_INIT))
    assert_equal(header_of(init, "mcp-session-id"), "")
    assert_true(
        body_of(init).startswith('data: {"jsonrpc":"2.0","id":1,"result":')
    )
    var call = exchange(
        server,
        post(
            (
                '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"validate","arguments":{"operation":"{'
                ' a }"}}}'
            ),
            extra="MCP-Protocol-Version: 2025-06-18\r\n",
        ),
    )
    _expect(
        call,
        "200",
        (
            "data:"
            ' {"jsonrpc":"2.0","id":5,"result":{"content":[{"type":"text","text":"Operation'
            ' is valid"}],"isError":false}}\n\n'
        ),
    )
    var delete = exchange(server, other("DELETE"))
    _expect(delete, "405", "Method Not Allowed")
    assert_equal(header_of(delete, "allow"), "POST")
    _expect(
        exchange(server, other("GET", "/mcp", "Accept: text/event-stream\r\n")),
        "405",
        "Method Not Allowed",
    )
    server.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
