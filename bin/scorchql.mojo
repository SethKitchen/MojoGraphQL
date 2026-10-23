# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `scorchql` program: a federated GraphQL gateway with an explorer.

    make scorchql
    dist/scorchql --config examples/scorchql/supergraph.yaml
    dist/scorchql publish --gateway http://localhost:4000 \\
        --name products --url http://localhost:4001/

`serve` (the default command) forks the worker processes of the gateway,
then stays in the foreground. Every `--poll` seconds it reads the SDL of
each published subgraph again, and publishes each change, so a subgraph
that deploys a new schema reaches the gateway without a publish. Stop the
program with `SIGINT` or `SIGTERM`.

`--config` reads a Rover `supergraph.yaml` at start, and publishes each
subgraph with its `routing_url`. A subgraph that cannot be read is skipped
with a warning; the poll publishes it when it comes up.

`publish`, `remove` and `refresh` send one request to a running gateway,
print the JSON answer, and exit with 0 when the gateway accepted it.
"""

from std.ffi import external_call
from std.memory import ArcPointer
from std.os.path import dirname
from std.sys import argv, exit, stderr
from std.time import sleep

from gql_http.client import Client, ClientConfig
from gql_http.server import (
    ServerConfig,
    WorkerPool,
    open_listener,
)
from gql_http.socket import Sys
from gql_http3.quic import Quic
from gql_router_stream.server import router_server_config
from gql_scorchql.cli import (
    CliOptions,
    CommandKind,
    SubscriptionMode,
    USAGE,
    VERSION,
    gateway_config,
    parse_cli,
    send_admin,
)
from gql_scorchql.gateway import (
    Gateway,
    GatewayConfig,
    GatewayWsHandler,
    SharedGateway,
    refresh_registry,
    serve_gateway,
)
from gql_scorchql.introspect import fetch_subgraph_sdl
from gql_scorchql.registry import Registry, read_file
from gql_seamstress.config import SchemaSourceKind, parse_supergraph_config
from gql_tls.context import TlsContext
from gql_tls.error import TlsError
from gql_tls.openssl import OpenSsl
from gql_tls.server import TlsProtocol, listen_tls
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL
from gql_ws.protocol import WsConfig
from gql_ws.server import ServerConfig as WsServerConfig
from gql_ws.server import Sockets
from gql_ws_http2.session import WsH2Session
from gql_ws_http3.server import ServerConfig as WsH3Config
from gql_ws_http3.server import listen_ws_h3


struct _WsH2Tls(TlsProtocol):
    """WebSockets (RFC 8441) and requests on each HTTP/2 over TLS
    connection."""

    var http: SharedGateway
    var handler: GatewayWsHandler
    var sockets: Sockets
    var protocols: List[String]
    var path: String
    var conns: List[Int]
    var sessions: List[WsH2Session]

    def __init__(
        out self,
        shared: ArcPointer[Gateway],
        protocols: List[String],
        path: String,
    ) raises:
        self.http = SharedGateway(shared)
        self.handler = GatewayWsHandler(shared)
        self.sockets = Sockets(WsConfig(), 30000)
        self.protocols = protocols.copy()
        self.path = path
        self.conns = List[Int]()
        self.sessions = List[WsH2Session]()

    def protocol(self) -> String:
        return "h2"

    def _index(self, conn: Int) -> Int:
        var index = 0
        while index < len(self.conns):
            if self.conns[index] == conn:
                return index
            index += 1
        return -1

    def open(mut self, conn: Int, mut out: List[UInt8]) raises:
        var session = WsH2Session(
            protocols=self.protocols.copy(), path=self.path
        )
        session.start()
        out.extend(Span(session.session.conn.out))
        session.session.conn.out.clear()
        self.conns.append(conn)
        self.sessions.append(session^)

    def receive(
        mut self, conn: Int, data: List[UInt8], mut out: List[UInt8]
    ) raises -> Bool:
        ref session = self.sessions[self._index(conn)]
        session.receive(self.http, self.handler, self.sockets, Span(data))
        self.handler.on_tick(self.sockets)
        session.flush(self.handler, self.sockets)
        out.extend(Span(session.session.conn.out))
        session.session.conn.out.clear()
        return not session.is_done()

    def close(mut self, conn: Int):
        var index = self._index(conn)
        if index < 0:
            return
        self.sessions[index].close_all(self.handler, self.sockets)
        _ = self.sessions.pop(index)
        _ = self.conns.pop(index)


def _hostname() -> String:
    """Return the host name of this machine, or `localhost`."""
    var buffer = List[UInt8](length=256, fill=0)
    var rc = external_call["gethostname", Int32](buffer.unsafe_ptr(), Int(255))
    if rc != 0 or buffer[0] == 0:
        return "localhost"
    var length = 0
    while length < 255 and buffer[length] != 0:
        length += 1
    return String(StringSlice(unsafe_from_utf8=Span(buffer)[:length]))


def _seed(path: String, mut registry: Registry, mut client: Client) raises:
    """Publish the subgraphs of a `supergraph.yaml`."""
    var config = parse_supergraph_config(read_file(path))
    var root = dirname(path)
    for ref subgraph in config.subgraphs:
        var source = subgraph.schema.copy()
        var url = subgraph.routing_url.or_else(source.subgraph_url)
        var sdl: String
        try:
            if source.kind == SchemaSourceKind.FILE:
                var file = source.file
                if not file.startswith("/") and root != "":
                    file = root + "/" + file
                sdl = read_file(file)
            elif source.kind == SchemaSourceKind.SDL:
                sdl = source.sdl
            elif source.kind == SchemaSourceKind.SUBGRAPH_INTROSPECTION:
                sdl = fetch_subgraph_sdl(client, source.subgraph_url)
            else:
                print(
                    "warning: skipped "
                    + subgraph.name
                    + ": GraphOS sources are not supported",
                    file=stderr,
                )
                continue
        except e:
            print(
                "warning: skipped " + subgraph.name + ": " + String(e),
                file=stderr,
            )
            continue
        var result = registry.publish(subgraph.name, url, sdl)
        if result.accepted:
            print(
                "🔥 published "
                + subgraph.name
                + (" (changed)" if result.changed else " (unchanged)")
            )
        else:
            print(
                "warning: "
                + subgraph.name
                + " was refused:\n  "
                + String("\n  ").join(result.errors),
                file=stderr,
            )


def _admin(options: CliOptions) raises:
    """Run `publish`, `remove` or `refresh`, and exit."""
    var client = Client()
    var answer: Tuple[Int, String]
    try:
        answer = send_admin(client, options)
    except e:
        print("error: " + String(e), file=stderr)
        exit(1)
        return
    print(answer[1])
    if answer[0] < 200 or answer[0] > 299:
        exit(1)


def _run_https(var handler: Gateway, options: CliOptions) raises:
    """Serve HTTPS with h2, HTTP/1.1 and WebSockets over h2 until a
    shutdown."""
    var context = TlsContext.server(
        OpenSsl(), options.tls_cert.value(), options.tls_key.value()
    )
    var config = ServerConfig()
    config.host = options.host
    config.port = options.https_port
    var ws = router_server_config(
        handler.config.subscriptions,
        WsServerConfig(),
        handler.config.graphql_path,
    )
    var shared = ArcPointer(handler^)
    var h2 = _WsH2Tls(shared, ws.protocols, ws.path)
    var server = listen_tls(SharedGateway(shared), context^, config, h2^)
    server.run()


def _run_h3(var handler: Gateway, options: CliOptions) raises:
    """Serve HTTP/3 and WebSockets over HTTP/3 until a shutdown."""
    var ws = router_server_config(
        handler.config.subscriptions,
        WsServerConfig(),
        handler.config.graphql_path,
    )
    var config = WsH3Config()
    config.h3.host = options.host
    config.h3.port = options.https_port
    config.path = ws.path
    config.protocols = ws.protocols.copy()
    var shared = ArcPointer(handler^)
    var server = listen_ws_h3(
        GatewayWsHandler(shared),
        SharedGateway(shared),
        options.tls_cert.value(),
        options.tls_key.value(),
        config,
        Quic(OpenSsl()),
    )
    while server.h3.fd >= 0:
        _ = server.poll(-1)


def _serve_tls(options: CliOptions, config: GatewayConfig, h3: Bool):
    """Serve HTTPS or HTTP/3 in this process, then end it."""
    var code = 0
    var name = "HTTP/3" if h3 else "HTTPS"
    try:
        var handler = Gateway(config.copy())
        try:
            if h3:
                _run_h3(handler^, options)
            else:
                _run_https(handler^, options)
        except e:
            print("error: " + name + " failed: " + String(e), file=stderr)
            code = 1
    except e:
        print("error: " + name + " failed: " + String(e), file=stderr)
        code = 1
    var sys = Sys()
    sys.exit_now(code)


def _fork_server(
    mut pool: WorkerPool,
    options: CliOptions,
    config: GatewayConfig,
    h3: Bool,
) raises:
    """Fork a process that serves HTTPS or HTTP/3, and watch it."""
    var sys = Sys()
    var parent = sys.pid()
    var pid = sys.fork()
    if pid < 0:
        raise Error("fork failed")
    if pid == 0:
        _ = sys.die_with_parent()
        if sys.parent_pid() != parent:
            sys.exit_now(1)
        _serve_tls(options, config, h3)
    pool.pids.append(pid)


def _close_all(mut sys: Sys, fds: List[Int]):
    """Close every descriptor of a list."""
    for fd in fds:
        sys.close(fd)


def _run_ws_worker(
    config: GatewayConfig,
    http_config: ServerConfig,
    listeners: List[Int],
    index: Int,
    port: Int,
    parent: Int,
):
    """Run one HTTP/1.1 and WebSocket worker process."""
    var sys = Sys()
    _close_all(sys, listeners)
    _ = sys.die_with_parent()
    var code = 0
    if sys.parent_pid() != parent:
        code = 1
    else:
        try:
            var gateway = Gateway(config.copy())
            var ws = WsServerConfig()
            ws.http = http_config.copy()
            ws.http.port = port
            var server = serve_gateway(gateway^, ws^)
            server.listen_signals()
            server.run()
        except:
            code = 1
    sys.exit_now(code)


def _start_gateway_workers(
    mut config: GatewayConfig, server: ServerConfig
) raises -> WorkerPool:
    """Fork `server.workers` processes that serve HTTP/1.1, SSE, multipart
    and WebSocket on one port."""
    var sys = Sys()
    var count = max(server.workers, 1)
    var listeners = List[Int]()
    var port = server.port
    while len(listeners) < count:
        try:
            var listener = open_listener(
                sys, server.host, port, server.backlog, True
            )
            port = listener.port
            listeners.append(listener.fd)
        except e:
            _close_all(sys, listeners)
            raise Error(String(e))
    config.http_port = port
    var parent = sys.pid()
    var pids = List[Int]()
    var child = -1
    while len(pids) < count:
        var pid = sys.fork()
        if pid == 0:
            child = len(pids)
            break
        if pid < 0:
            _close_all(sys, listeners)
            var started = WorkerPool(pids^, port)
            _ = started.stop(1000)
            raise Error("fork failed")
        pids.append(pid)
    if child >= 0:
        _run_ws_worker(config, server, listeners, child, port, parent)
    _close_all(sys, listeners)
    return WorkerPool(pids^, port)


def main() raises:
    """Run one command line."""
    var args = List[String]()
    var raw = argv()
    for index in range(1, len(raw)):
        args.append(String(raw[index]))
    var options: CliOptions
    try:
        options = parse_cli(args)
    except e:
        print("error: " + String(e) + "\n\nRun 'scorchql --help'.", file=stderr)
        exit(2)
        return
    if options.command == CommandKind.HELP:
        print(USAGE, end="")
        return
    if options.command == CommandKind.VERSION:
        print(VERSION)
        return
    if options.command != CommandKind.SERVE:
        _admin(options)
        return

    var config = gateway_config(options)
    var static = Bool(options.supergraph)
    var registry = Registry(options.registry)
    var client_config = ClientConfig()
    client_config.timeout_ms = 5000
    if not static:
        registry.open()
        if options.config:
            var seed_client = Client(client_config)
            _seed(options.config.value(), registry, seed_client)
    var gateway = Gateway(config.copy())
    var count = (
        len(gateway.streams[0].hub[].router.schema.subgraph_names) if len(
            gateway.streams
        )
        > 0 else 0
    )
    if gateway.load_error != "":
        print("warning: " + gateway.load_error, file=stderr)

    var server = ServerConfig()
    server.host = options.host
    server.port = options.port
    server.workers = options.workers
    var pool = _start_gateway_workers(config, server)
    if options.tls_cert:
        _fork_server(pool, options, config, False)
        if options.h3:
            _fork_server(pool, options, config, True)

    var shown = options.host_text
    if shown == "0.0.0.0":
        shown = _hostname()
    var base = "http://" + shown + ":" + String(pool.port)
    var ws_base = "ws://" + shown + ":" + String(pool.port)
    print("🔥 ScorchQL is burning on " + base + "/")
    print("   GraphQL:   " + base + options.path)
    print(
        "   WebSocket: "
        + ws_base
        + options.path
        + "  ("
        + GRAPHQL_TRANSPORT_WS_PROTOCOL
        + ")"
    )
    print("   Explorer:  " + base + "/")
    if options.tls_cert:
        var secure = "https://" + shown + ":" + String(options.https_port)
        print("   HTTPS:     " + secure + "/  (h2, HTTP/1.1, WebSocket on h2)")
        if options.h3:
            print(
                "   HTTP/3:    "
                + secure
                + "/  (QUIC on UDP "
                + String(options.https_port)
                + ", WebSocket on h3, announced with Alt-Svc)"
            )
    if options.host_text == "0.0.0.0":
        print(
            "   Listening on every interface; use this machine's IP address"
            " from other machines."
        )
    if static:
        print(
            "   Supergraph: "
            + options.supergraph.value()
            + " ("
            + String(count)
            + " subgraphs)"
        )
    else:
        print(
            "   Registry:  "
            + options.registry
            + " ("
            + String(count)
            + " subgraphs)"
        )
        if not options.token:
            print(
                "   warning: publishing needs no token; set --token or"
                " SCORCHQL_TOKEN on a shared network."
            )
        if options.poll_seconds > 0:
            print(
                "   Polling each subgraph for SDL changes every "
                + String(options.poll_seconds)
                + " s."
            )

    var client = Client(client_config)
    var elapsed = 0
    while len(pool.pids) > 0:
        sleep(1.0)
        var index = len(pool.pids) - 1
        while index >= 0:
            var ended = pool.sys.wait(pool.pids[index], False)
            if ended[0] == pool.pids[index]:
                print(
                    "warning: worker "
                    + String(ended[0])
                    + " ended with code "
                    + String(ended[1]),
                    file=stderr,
                )
                _ = pool.pids.pop(index)
            index -= 1
        elapsed += 1
        if static or options.poll_seconds == 0:
            continue
        if elapsed < options.poll_seconds:
            continue
        elapsed = 0
        try:
            for ref outcome in refresh_registry(registry, client):
                if outcome.status == "updated":
                    print("🔥 " + outcome.name + " changed; recomposed.")
        except e:
            print("warning: the poll failed: " + String(e), file=stderr)
    exit(1)
