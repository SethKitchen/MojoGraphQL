# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.server`: the lifecycle and the dispatch.

Ports the protocol-level tests of Apollo MCP Server 2.0.0
`crates/apollo-mcp-server/src/server/states/running.rs` that apply to
phase 1 (`get_info_*`, `excludes_output_schema_when_protocol_predates_it`,
`includes_output_schema_when_protocol_supports_it`, tool not found). The
expected replies are those of the upstream binary over stdio for the
weather example.
"""

from _endpoint import start_endpoint
from _weather_fixture import (
    ALERTS_OPERATION,
    ALL_OPERATION,
    FORECAST_OPERATION,
    WEATHER_SCHEMA,
    WEATHER_TOOLS_LIST,
)
from gql_json.parser import parse
from gql_mcp.operation import RawOperation
from gql_mcp.server import (
    McpServer,
    ServerConfig,
    ServerInfo,
    Session,
    is_known_protocol_version,
)
from gql_mcp.tool import MutationMode
from gql_schema.build import build_schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime _INIT = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
comptime _INFO = (
    '"serverInfo":{"name":"Apollo MCP Server","title":"Apollo MCP'
    ' Server","version":"2.0.0","description":"A Model Context Protocol (MCP)'
    " server for exposing GraphQL APIs as"
    ' tools.","websiteUrl":"https://www.apollographql.com/docs/apollo-mcp-server"}'
)
comptime _META = (
    '{"jsonrpc":"2.0","id":1,"error":{"code":-32602,"message":"request _meta is'
    " missing or has malformed required fields:"
    " io.modelcontextprotocol/protocolVersion,"
    ' io.modelcontextprotocol/clientCapabilities"}}'
)


def _operations() -> List[RawOperation]:
    var raw = List[RawOperation]()
    raw.append(
        RawOperation(String(FORECAST_OPERATION), String("forecast.graphql"))
    )
    raw.append(RawOperation(String(ALERTS_OPERATION), String("alerts.graphql")))
    raw.append(RawOperation(String(ALL_OPERATION), String("all.graphql")))
    raw.append(RawOperation(String("query { a }"), None))
    raw.append(RawOperation(String("query {"), None))
    return raw^


def _config(endpoint: String = "http://127.0.0.1:1/graphql") -> ServerConfig:
    var config = ServerConfig()
    config.endpoint = endpoint
    config.execute_enabled = True
    config.introspect_enabled = True
    config.validate_enabled = True
    config.search_enabled = True
    return config^


def _server(var config: ServerConfig) raises -> McpServer:
    return McpServer(config^, build_schema(WEATHER_SCHEMA), _operations())


def _reply(
    mut server: McpServer, mut session: Session, text: StringSlice
) -> String:
    var reply = server.handle(session, text)
    if reply:
        return reply.value()
    return "<none>"


def test_search_call_matches_upstream() raises:
    var server = _server(_config())
    var session = Session()
    _ = server.handle(session, _INIT)
    assert_equal(
        _reply(server, session, _call("search", '{"terms":["alert"]}')),
        '{"jsonrpc":"2.0","id":7,"result":{"content":[{"type":"text","text":"'
        + '\\"\\"\\"A weather alert\\"\\"\\"\\ntype Alert {\\n  \\"\\"\\"The'
        " severity"
        + ' of this alert\\"\\"\\"\\n  severity: String\\n  \\"\\"\\"A'
        " description of"
        + ' the alert\\"\\"\\"\\n  description: String\\n  \\"\\"\\"Information'
        " about"
        + ' how people should respond to the alert\\"\\"\\"\\n  instruction:'
        " String\\n}"
        + '\\n"},{"type":"text","text":"type Query {\\n  \\"\\"\\"Get the'
        " weather alerts"
        + ' for a state\\"\\"\\"\\n  alerts(\\n    \\"\\"\\"The two-letter'
        " state"
        + ' abbreviation (e.g., \'CO\' for Colorado)\\"\\"\\"\\n    state:'
        " String!,\\n"
        + '  ): [Alert]\\n}\\n"}],"isError":false}}',
    )


def test_lifecycle() raises:
    var server = _server(_config())
    var session = Session()
    assert_equal(
        _reply(server, session, '{"jsonrpc":"2.0","id":9,"method":"ping"}'),
        '{"jsonrpc":"2.0","id":9,"result":{}}',
    )
    assert_equal(
        _reply(
            server, session, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
        ),
        _META,
    )
    assert_equal(_reply(server, session, "garbage"), "<none>")
    assert_equal(
        _reply(server, session, "[1]"),
        '{"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid request"}}',
    )
    assert_equal(
        _reply(
            server,
            session,
            '{"jsonrpc":"2.0","method":"notifications/initialized"}',
        ),
        "<none>",
    )
    assert_equal(
        _reply(server, session, _INIT),
        '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18",'
        + '"capabilities":{"tools":{"listChanged":true}},'
        + _INFO
        + "}}",
    )
    assert_true(session.initialized)
    assert_equal(session.protocol_version, "2025-06-18")
    assert_equal(len(server.load_errors), 1)
    assert_true(
        server.load_errors[0].startswith(
            "Invalid operation: Could not parse GraphQL document: "
        )
    )


def test_tools_list_matches_upstream() raises:
    var server = _server(_config())
    var session = Session()
    _ = server.handle(session, _INIT)
    assert_equal(
        _reply(
            server,
            session,
            '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{"cursor":"x"}}',
        ),
        '{"jsonrpc":"2.0","id":2,"result":' + String(WEATHER_TOOLS_LIST) + "}",
    )


def _init(version: StringSlice) -> String:
    return (
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"'
        + String(version)
        + '","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
    )


def test_initialize_negotiation() raises:
    var server = _server(_config())
    for version in ["2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"]:
        var session = Session()
        assert_true(String(version) in _reply(server, session, _init(version)))
        assert_equal(session.protocol_version, version)
    var session = Session()
    assert_true('"2025-11-25"' in _reply(server, session, _init("2026-07-28")))
    assert_true(is_known_protocol_version("2024-11-05"))
    assert_false(is_known_protocol_version("1999-01-01"))
    var bad = List[String]()
    bad.append('{"jsonrpc":"2.0","id":1,"method":"initialize"}')
    bad.append('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
    bad.append(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":5}}'
    )
    bad.append(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":5,"clientInfo":{"name":"t","version":"1"}}}'
    )
    bad.append(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"t","version":"1"}}}'
    )
    bad.append(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}'
    )
    bad.append(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":5}}'
    )
    bad.append(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t"}}}'
    )
    bad.append(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"version":"1"}}}'
    )
    for text in bad:
        var fresh = Session()
        assert_equal(_reply(server, fresh, text), _META)
        assert_false(fresh.initialized)


def test_get_info_should_use_custom_metadata_when_config_provided() raises:
    var config = _config()
    config.server_info = ServerInfo("Custom", "9.9", None, None, None)
    config.instructions = String("Use me")
    var server = _server(config^)
    var session = Session()
    assert_equal(
        _reply(server, session, _INIT),
        '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18",'
        + '"capabilities":{"tools":{"listChanged":true}},"serverInfo":'
        + '{"name":"Custom","version":"9.9"},"instructions":"Use me"}}',
    )


def _call(name: StringSlice, arguments: StringSlice) -> String:
    return (
        '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"'
        + String(name)
        + '"'
        + (
            ',"arguments":' + String(arguments) if arguments.byte_length()
            > 0 else String()
        )
        + "}}"
    )


def test_other_methods() raises:
    var server = _server(_config())
    var session = Session()
    _ = server.handle(session, _INIT)
    var methods = List[String]()
    methods.append('"resources/list"}')
    methods.append('"resources/templates/list"}')
    methods.append('"prompts/list"}')
    methods.append('"logging/setLevel","params":{"level":"info"}}')
    methods.append('"prompts/get","params":{"name":"x"}}')
    methods.append('"prompts/get"}')
    methods.append('"PING"}')
    methods.append('"tools/call"}')
    methods.append('"tools/call","params":{"name":5}}')
    methods.append('"tools/call","params":{"name":"validate","arguments":5}}')
    var expected = List[String]()
    expected.append('"result":{"resources":[]}}')
    expected.append('"result":{"resourceTemplates":[]}}')
    expected.append('"result":{"prompts":[]}}')
    expected.append('"result":{}}')
    expected.append(
        '"error":{"code":-32602,"message":"Prompt \'x\' not found"}}'
    )
    expected.append('"error":{"code":-32601,"message":"prompts/get"}}')
    expected.append('"error":{"code":-32601,"message":"PING"}}')
    expected.append('"error":{"code":-32601,"message":"tools/call"}}')
    expected.append('"error":{"code":-32601,"message":"tools/call"}}')
    expected.append('"error":{"code":-32601,"message":"tools/call"}}')
    var index = 0
    while index < len(methods):
        assert_equal(
            _reply(
                server,
                session,
                '{"jsonrpc":"2.0","id":3,"method":' + methods[index],
            ),
            '{"jsonrpc":"2.0","id":3,' + expected[index],
        )
        index += 1
    assert_equal(
        _reply(server, session, _call("unknownTool", "{}")),
        (
            '{"jsonrpc":"2.0","id":7,"error":{"code":-32602,"message":"Tool'
            ' unknownTool not found"}}'
        ),
    )
    assert_equal(
        _reply(server, session, _call("validate", "")),
        '{"jsonrpc":"2.0","id":7,"result":{"content":[{"type":"text","text":'
        + '"Invalid input: invalid type: null, expected struct'
        ' Input"}],"isError":true}}',
    )
    assert_equal(
        _reply(server, session, _call("validate", "null")),
        _reply(server, session, _call("validate", "")),
    )
    assert_true(
        "Operation is valid"
        in _reply(
            server,
            session,
            _call(
                "validate",
                '{"operation":"{ alerts(state: \\"CO\\") { severity } }"}',
            ),
        )
    )
    assert_true(
        "type Query"
        in _reply(server, session, _call("introspect", '{"type_name":"Query"}'))
    )


def _sent(reply: String, key: StringSlice) raises -> String:
    """Return a member of what the echo endpoint got, from a tool reply."""
    var outer = parse(reply)
    var content = outer.get(outer.get(outer.root, "result"), "content")
    var text = outer.string_value(outer.get(outer.at(content, 0), "text"))
    var inner = parse(text)
    return inner.string_value(inner.get(inner.get(inner.root, "data"), key))


def test_calls_send_operations_to_the_endpoint() raises:
    var pool = start_endpoint()
    var base = "http://127.0.0.1:" + String(pool.port)
    var server = _server(_config(base + "/echo"))
    var session = Session()
    _ = server.handle(session, _INIT)
    var alerts = _reply(server, session, _call("GetAlerts", '{"state":"CO"}'))
    var bare = _reply(server, session, _call("GetAlerts", ""))
    var execute = _reply(
        server,
        session,
        _call("execute", '{"query":"{ a }","variables":{"b":1e5}}'),
    )
    var refused = _reply(
        server, session, _call("execute", '{"query":"mutation M { a }"}')
    )
    var huge = _reply(server, session, _call("GetAlerts", '{"state":1e400}'))
    server.client.close_idle()
    _ = pool.stop()
    assert_equal(
        _sent(alerts, "body"),
        '{"variables":{"state":"CO"},"query":"query GetAlerts($state: String!) '
        + "{\\n  alerts(state: $state) {\\n    severity\\n    description\\n"
        + '    instruction\\n  }\\n}\\n","extensions":{"clientLibrary":{"name":'
        + '"mcp","version":"2.0.0"}},"operationName":"GetAlerts"}',
    )
    assert_equal(_sent(alerts, "content-type"), "application/json")
    assert_true('"isError":false}}' in alerts)
    assert_false("structuredContent" in alerts)
    assert_true(_sent(bare, "body").startswith('{"variables":null,'))
    assert_equal(
        _sent(execute, "body"),
        '{"variables":{"b":100000.0},"query":"{ a }","extensions":'
        + '{"clientLibrary":{"name":"mcp","version":"2.0.0"}}}',
    )
    assert_true('"text":"Invalid operation type"}],"isError":true' in refused)
    assert_true('"text":"number out of range"}],"isError":true' in huge, huge)


def test_output_schema_follows_protocol_version() raises:
    var pool = start_endpoint()
    var base = "http://127.0.0.1:" + String(pool.port)
    var config = _config(base + "/errors")
    config.enable_output_schema = True
    var server = _server(config^)
    var new = Session()
    _ = server.handle(new, _INIT)
    var old = Session()
    _ = server.handle(old, _init("2025-03-26"))
    var new_list = _reply(
        server, new, '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
    )
    var old_list = _reply(
        server, old, '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
    )
    var new_call = _reply(server, new, _call("GetAlerts", '{"state":"CO"}'))
    var old_call = _reply(server, old, _call("GetAlerts", '{"state":"CO"}'))
    server.client.close_idle()
    _ = pool.stop()
    # includes_output_schema_when_protocol_supports_it
    assert_true('"outputSchema"' in new_list)
    # excludes_output_schema_when_protocol_predates_it
    assert_false('"outputSchema"' in old_list)
    assert_equal(
        new_call,
        '{"jsonrpc":"2.0","id":7,"result":{"content":[{"type":"text","text":'
        + '"{\\"data\\":null,\\"errors\\":[\\"an error\\"]}"}],'
        + '"structuredContent":{"data":null,"errors":["an'
        ' error"]},"isError":true}}',
    )
    assert_false("structuredContent" in old_call)


def test_mutation_mode_all() raises:
    var config = _config()
    config.mutation_mode = MutationMode.ALL
    var server = McpServer(
        config^,
        build_schema("type Query { a: Int } type Mutation { m: Int }"),
        List[RawOperation](),
    )
    var session = Session()
    _ = server.handle(session, _INIT)
    var list = _reply(
        server, session, '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
    )
    assert_true("root query (Query) or mutation (Mutation)" in list)
    assert_true('"readOnlyHint":false,"destructiveHint":true' in list)
    var shown = _reply(
        server, session, _call("introspect", '{"type_name":"Query","depth":0}')
    )
    assert_true("type Query" in shown)
    var empty = McpServer(
        ServerConfig(),
        build_schema("type Query { a: Int }"),
        List[RawOperation](),
    )
    assert_equal(empty.tools_list(session), '{"tools":[]}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()


def test_disabled_tools_are_not_found() raises:
    var config = ServerConfig()
    config.headers = List[Tuple[String, String]]()
    config.mutation_mode = MutationMode.ALL
    var server = McpServer(
        config^, build_schema("type Query { a: Int }"), List[RawOperation]()
    )
    var session = Session()
    _ = server.handle(session, _INIT)
    for name in ["introspect", "search", "execute", "validate"]:
        assert_equal(
            _reply(server, session, _call(name, "{}")),
            '{"jsonrpc":"2.0","id":7,"error":{"code":-32602,"message":"Tool '
            + String(name)
            + ' not found"}}',
        )
    var on = ServerConfig()
    on.introspect_enabled = True
    on.mutation_mode = MutationMode.ALL
    var no_mutation = McpServer(
        on^, build_schema("type Query { a: Int }"), List[RawOperation]()
    )
    assert_true(
        "root query (Query) or mutation (Mutation)"
        in no_mutation.tools_list(session)
    )
    assert_true(
        "type Query"
        in _reply(
            no_mutation, session, _call("introspect", '{"type_name":"Query"}')
        )
    )


def test_operation_headers() raises:
    var pool = start_endpoint()
    var base = "http://127.0.0.1:" + String(pool.port)
    var raw = List[RawOperation]()
    var good = RawOperation(String("query Good { a }"), None)
    good.headers.append((String("x-op"), String("1")))
    good.headers.append((String("Content-Type"), String("application/graphql")))
    raw.append(good^)
    var bad = RawOperation(String("query Bad { a }"), None)
    bad.headers.append((String("bad name"), String("1")))
    raw.append(bad^)
    var server = McpServer(
        _config(base + "/echo"), build_schema("type Query { a: Int }"), raw
    )
    var session = Session()
    _ = server.handle(session, _INIT)
    var sent = _reply(server, session, _call("Good", ""))
    var refused = _reply(server, session, _call("Bad", ""))
    server.client.close_idle()
    _ = pool.stop()
    assert_equal(_sent(sent, "x-op"), "1")
    assert_equal(_sent(sent, "Content-Type"), "application/graphql")
    assert_true('"isError":true' in refused, refused)
