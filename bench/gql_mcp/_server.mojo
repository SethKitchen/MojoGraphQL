# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A runnable gql_mcp server, configured on the command line.

    _server
    _server stdio <schema.graphql> <endpoint> [operation paths...]
    _server http <port> <schema.graphql> <endpoint> [operation paths...]

Without arguments it serves stdio with the configuration of
`bench/baselines/rust-mcp/config.yaml`, from the environment that
`_driver.mojo` sets. It turns on the four built-in tools, as the upstream weather example
does. Phase 1 has no YAML configuration; this program stands in for the
upstream binary in the benchmarks.
"""

from std.os import getenv
from std.sys import argv

from gql_http.server import ServerConfig as HttpConfig
from gql_http.socket import IPv4Address
from gql_mcp.http_transport import listen_http
from gql_mcp.operation_source import load_operations
from gql_mcp.server import McpServer, ServerConfig
from gql_mcp.stdio import serve_stream
from gql_schema.build import build_schema


def main() raises:
    var args = argv()
    if len(args) == 1:
        _bench()
        return
    if len(args) < 4:
        print("usage: _server stdio|http [port] <schema> <endpoint> [paths...]")
        return
    var mode = String(args[1])
    var first = 2
    var port = 8000
    if mode == "http":
        port = Int(String(args[2]))
        first = 3
    var sdl: String
    with open(String(args[first]), "r") as file:
        sdl = file.read()
    var config = ServerConfig()
    config.endpoint = String(args[first + 1])
    config.execute_enabled = True
    config.introspect_enabled = True
    config.search_enabled = True
    config.validate_enabled = True
    var paths = List[String]()
    var index = first + 2
    while index < len(args):
        paths.append(String(args[index]))
        index += 1
    var server = McpServer(config^, build_schema(sdl), load_operations(paths))
    if mode == "http":
        var http = HttpConfig()
        http.host = IPv4Address.LOOPBACK
        http.port = port
        var listener = listen_http(server^, http)
        listener.listen_signals()
        listener.run()
        return
    _ = serve_stream(server, 0, 1)


def _bench() raises:
    """Serve stdio with the configuration of
    `bench/baselines/rust-mcp/config.yaml`, from the driver's environment."""
    var root = getenv("MCP_BENCH_ROOT", ".")
    var sdl: String
    with open(root + "/bench/fixtures/github-schema.graphql", "r") as file:
        sdl = file.read()
    var config = ServerConfig()
    config.endpoint = getenv("APOLLO_MCP_ENDPOINT")
    config.enable_output_schema = True
    config.execute_enabled = True
    config.introspect_enabled = True
    config.search_enabled = True
    config.validate_enabled = True
    var paths = List[String]()
    paths.append(getenv("MCP_BENCH_DIR") + "/operations")
    var server = McpServer(config^, build_schema(sdl), load_operations(paths))
    _ = serve_stream(server, 0, 1)
