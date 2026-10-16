# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.stdio`.

There is no upstream unit test of the stdio transport (the upstream
`tests/stdio_stdout.rs` runs the binary); the expected lines are the
binary's replies.
"""

from gql_http.socket import Sys
from gql_mcp.operation import RawOperation
from gql_mcp.server import McpServer, ServerConfig
from gql_mcp.stdio import serve_stream
from gql_schema.build import build_schema
from std.testing import TestSuite, assert_equal, assert_true


def _server() raises -> McpServer:
    return McpServer(
        ServerConfig(),
        build_schema("type Query { a: Int }"),
        List[RawOperation](),
    )


def _run(input: StringSlice) raises -> Tuple[Int, String]:
    var server = _server()
    var sys = Sys()
    var inp = sys.pipe()
    var out = sys.pipe()
    var bytes = input.as_bytes()
    _ = sys.write(inp[1], bytes.unsafe_ptr(), len(bytes))
    sys.close(inp[1])
    var lines = serve_stream(server, inp[0], out[1])
    sys.close(inp[0])
    sys.close(out[1])
    var buffer = List[UInt8](length=65536, fill=0)
    var got = List[UInt8]()
    var n = sys.read(out[0], buffer.unsafe_ptr(), len(buffer))
    while n > 0:
        got.extend(Span(buffer)[:n])
        n = sys.read(out[0], buffer.unsafe_ptr(), len(buffer))
    sys.close(out[0])
    return (lines, String(unsafe_from_utf8=got^))


def test_lines() raises:
    var result = _run(
        '{"jsonrpc":"2.0","id":1,"method":"ping"}\r\n'
        + "not json\n\n"
        + '{"jsonrpc":"2.0","method":"notifications/initialized"}\n'
        + '[1]\n {"jsonrpc":"2.0","id":"s","method":"ping"} '
    )
    assert_equal(result[0], 6)
    assert_equal(
        result[1],
        '{"jsonrpc":"2.0","id":1,"result":{}}\n'
        + '{"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid'
        ' request"}}\n'
        + '{"jsonrpc":"2.0","id":"s","result":{}}\n',
    )
    assert_equal(_run("")[0], 0)


def test_failures() raises:
    var server = _server()
    assert_true(serve_stream(server, -1, 1) < 0)
    var sys = Sys()
    for text in [
        '{"jsonrpc":"2.0","id":1,"method":"ping"}\n',
        '{"jsonrpc":"2.0","id":1,"method":"ping"}',
    ]:
        var inp = sys.pipe()
        var bytes = StringSlice(text).as_bytes()
        _ = sys.write(inp[1], bytes.unsafe_ptr(), len(bytes))
        sys.close(inp[1])
        assert_true(serve_stream(server, inp[0], -1) < 0)
        sys.close(inp[0])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
