# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A scripted `GraphQLExecutor` and helpers for the graphql-transport-ws
suites.

The query of a `subscribe` says what the executor does:

- `result`: one result, `{"data":{"hello":"world"}}`.
- `errors`: one validation error.
- `list:N`: a stream of N events `{"data":{"n":i}}`.
- `fail`: a stream of one event that then fails with `kaboom`.
- `pubsub`: a stream of the events published on `T`.
- `boom`: the executor raises.
"""

from _server_util import Plain, Peer, config
from gql_http.socket import IPv4Address
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream, ListStream
from gql_ws.graphql_ws import GRAPHQL_TRANSPORT_WS_PROTOCOL, ProtocolMessage
from gql_ws.protocol import Message, MessageKind
from gql_ws.server import Server, ServerConfig, listen
from gql_ws.transport_server import (
    Acknowledgement,
    GraphQLExecutor,
    Operation,
    TransportOptions,
    TransportServer,
)


struct Scripted(GraphQLExecutor):
    """The executor of the suites."""

    var pubsub: PubSub
    var connects: Int
    var closes: Int
    var code: Int
    var reason: String
    var params: String

    def __init__(out self):
        self.pubsub = PubSub()
        self.connects = 0
        self.closes = 0
        self.code = 0
        self.reason = String()
        self.params = String()

    def on_connect(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Acknowledgement:
        self.connects += 1
        self.params = message.payload_json()
        if message.member("forbid") >= 0:
            return Acknowledgement(False, String())
        if message.member("boom") >= 0:
            raise Error("connect failed")
        return Acknowledgement(True, message.member_json("ack"))

    def operation(
        mut self, socket: Int, message: ProtocolMessage
    ) raises -> Operation:
        var query = message.member_string("query")
        if query == "result":
            return Operation.result('{"data":{"hello":"world"}}')
        if query == "errors":
            return Operation.errors('[{"message":"Cannot query field"}]')
        if query == "fail":
            var events = List[Event]()
            events.append(Event.parse('{"data":{"n":0}}'))
            return Operation.of_stream(AnyStream(ListStream(events^, "kaboom")))
        if query == "pubsub":
            return Operation.of_stream(AnyStream(self.pubsub.subscribe("T")))
        if query.startswith("list:"):
            var count = Int(query[byte=5:])
            var events = List[Event]()
            var index = 0
            while index < count:
                events.append(
                    Event.parse('{"data":{"n":' + String(index) + "}}")
                )
                index += 1
            return Operation.of_stream(AnyStream(ListStream(events^)))
        if query == "huge":
            var events = List[Event]()
            events.append(
                Event.parse('{"data":{"s":"' + String("x") * 100000 + '"}}')
            )
            return Operation.of_stream(AnyStream(ListStream(events^)))
        if query == "long":
            raise Error(String("x") * 200)
        raise Error("boom")

    def on_close(mut self, socket: Int, code: UInt16, reason: String):
        self.closes += 1
        self.code = Int(code)
        self.reason = reason


def gql_config() -> ServerConfig:
    var c = config()
    c.protocols = [GRAPHQL_TRANSPORT_WS_PROTOCOL]
    return c^


def gql_server(
    options: TransportOptions = TransportOptions(),
    c: ServerConfig = gql_config(),
) raises -> Server[TransportServer[Scripted], Plain]:
    return listen(TransportServer(Scripted(), options), Plain(), c)


def texts(mut peer: Peer) raises -> List[String]:
    """The text messages that came, and `close <code> <reason>` for a close."""
    var out = List[String]()
    var got = peer.messages()
    for m in got:
        if m.kind == MessageKind.CLOSE:
            out.append("close " + String(m.code.value) + " " + String(m.text()))
        elif m.kind == MessageKind.TEXT:
            out.append(String(m.text()))
    return out^


def joined(items: List[String]) -> String:
    return "\n".join(items)
