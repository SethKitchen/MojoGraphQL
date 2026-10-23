# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the standalone server of `gql_server` under the gql_http load.

    mojo build -I . -o .cache/bin/server_http bench/gql_server/http.mojo
    .cache/bin/server_http

`server/http-post-small`: one worker process answers the small GraphQL
`POST` of `bench/gql_http/_loadgen.mojo`, `{"query":"{hello}"}`, through
the whole server: CORS, the JSON body, CSRF prevention, content
negotiation, the request pipeline and the cache control header. The load
is 64 keep-alive connections. The number is nanoseconds per request.

The program builds the load generator of gql_http and runs it against
itself: `http.mojo server` serves and prints `PORT <n>`, as the baseline
`node bench.mjs server` in `bench/baselines/js-server` does. Both run
under the same load generator.
"""

from std.subprocess import run
from std.sys import argv

from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_http.server import ServerConfig
from gql_http.socket import IPv4Address
from gql_server.plugin import NoPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.standalone import start_standalone_server

comptime WORKLOAD = "server/http-post-small"
"""The workload id."""


def hello(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Resolve `Query.hello`."""
    return values.add_string("world")


def serve() raises:
    """Serve on a free loopback port with one worker, until killed."""
    var resolvers = Resolvers()
    resolvers.field("Query", "hello", hello)
    var options = ApolloServerOptions()
    options.node_env = String("production")
    var server = ApolloServer.from_type_defs(
        "type Query { hello: String }", resolvers^, options^, NoPlugin()
    )
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.workers = 1
    config.idle_timeout_ms = 60000
    var running = start_standalone_server(server^, config^)
    print("PORT", running.pool.port, flush=True)
    _ = running.pool.wait()


def main() raises:
    """Serve, or build the load generator and run it against `serve`."""
    var args = argv()
    if len(args) > 1 and String(args[1]) == "server":
        serve()
        return
    var built = run(
        "([ -x .cache/bin/http_loadgen ] || (mkdir -p .cache/bin &&"
        " .venv/bin/mojo build -I . -o .cache/bin/http_loadgen"
        " bench/gql_http/_loadgen.mojo > /dev/null 2>&1)); echo __rc=$?"
    )
    if not built.strip().endswith("__rc=0"):
        raise Error("the load generator did not build: " + built)
    var output = run(
        ".cache/bin/http_loadgen "
        + WORKLOAD
        + " "
        + String(args[0])
        + " server; echo __rc=$?"
    )
    print(output.replace("__rc=0", "").strip())
    if not output.strip().endswith("__rc=0"):
        raise Error("the load failed")
