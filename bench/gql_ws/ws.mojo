# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the gql_ws servers under the load of `_wsload.mojo`.

    mojo build -I . -o .cache/bin/ws bench/gql_ws/ws.mojo
    .cache/bin/ws

`ws/echo-roundtrip`: one server process echoes each text message, over 16
connections; nanoseconds per round trip. `graphql-ws/subscribe-1000-next`:
one server process runs `graphql-transport-ws` with gql_execution; each
`subscription { greetings }` gets 1000 events of a `PubSub`, and each
event is executed and sent as a `next`; nanoseconds per `next`. The
baselines in `bench/baselines/rust-ws` (tokio-tungstenite) and
`bench/baselines/js-ws` (`ws` and graphql-ws on Node.js) run their servers
with one thread under the same load generator.
"""

from _wsload import run_load
from gql_execution.execute import Resolvers
from gql_execution.value import UNDEFINED, Values
from gql_http.server import Listener, open_listener
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_language.ast import Document, OperationType
from gql_schema.build import build_schema
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL, ProtocolMessage
from gql_ws.protocol import Message, MessageKind
from gql_ws.server import (
    Server,
    ServerConfig,
    Sockets,
    UpgradeRequired,
    WsHandler,
)
from gql_ws.transport_server import Acknowledgement, TransportServer
from gql_ws_execution.executor import GraphQLExecution, Hooks

comptime EVENTS = 1000
"""The events of each subscription."""


struct Echo(WsHandler):
    """Echoes each text message."""

    def __init__(out self):
        pass

    def on_open(mut self, mut sockets: Sockets, id: Int) raises:
        pass

    def on_message(
        mut self, mut sockets: Sockets, id: Int, message: Message
    ) raises:
        if message.kind == MessageKind.TEXT:
            _ = sockets.send_text(id, message.text())

    def on_close(
        mut self, mut sockets: Sockets, id: Int, code: UInt16, reason: String
    ):
        pass

    def on_tick(mut self, mut sockets: Sockets) raises:
        pass

    def fd(self) -> Int:
        return -1

    def wait_ms(self) -> Int:
        return -1


struct Burst(Hooks):
    """Each subscription gets a new `PubSub` stream on `greetings`, and
    `EVENTS` events are published to it at once."""

    var pubsub: PubSub
    var event: Event

    def __init__(out self) raises:
        self.pubsub = PubSub()
        self.event = Event.parse('{"greetings":"hi"}')

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        return Acknowledgement(True, String())

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        if document.operation(operation) != OperationType.SUBSCRIPTION:
            return UNDEFINED
        var root = values.add_object()
        var stream = self.pubsub.subscribe("GREETINGS")
        values.add_member(
            root, "greetings", values.add_stream(AnyStream(stream^))
        )
        var index = 0
        while index < EVENTS:
            self.pubsub.publish("GREETINGS", self.event)
            index += 1
        return root

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        pass


def config() -> ServerConfig:
    var c = ServerConfig()
    c.http.host = IPv4Address.LOOPBACK
    c.http.idle_timeout_ms = 60000
    c.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
    return c^


def _spin[W: WsHandler](mut server: Server[W, UpgradeRequired]):
    """Run a loop until the process is killed."""
    try:
        while True:
            _ = server.poll(-1)
    except:
        pass


def _serve[W: WsHandler](var handler: W, listener: Listener):
    """Run a server until the process is killed."""
    try:
        var server = Server(
            handler^, UpgradeRequired(), config(), listener, Sys()
        )
        _spin(server)
    except:
        pass


def run_echo() raises:
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 1024, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        _serve(Echo(), listener)
        sys.exit_now(0)
    sys.close(listener.fd)
    run_load("ws/echo-roundtrip", listener.port)
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)


def run_graphql_ws() raises:
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 1024, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            var executor = GraphQLExecution(
                build_schema(
                    "type Query { hello: String }"
                    " type Subscription { greetings: String }"
                ),
                Resolvers(),
                Burst(),
            )
            _serve(TransportServer(executor^), listener)
        except:
            pass
        sys.exit_now(0)
    sys.close(listener.fd)
    run_load("graphql-ws/subscribe-1000-next", listener.port)
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)


def main() raises:
    """Run the workloads and print their `BENCH` lines."""
    run_echo()
    run_graphql_ws()
