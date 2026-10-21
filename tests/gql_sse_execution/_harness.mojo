# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_sse_execution suite: a schema with `@defer` and
`@stream`, root values, and raw loopback clients."""

from gql_execution.execute import Resolvers
from gql_execution.value import Values
from gql_http.server import Handler, Server, ServerConfig, listen
from gql_http.socket import EAGAIN, IPv4Address, Sys
from gql_json.parser import parse as parse_json
from gql_language.ast import Document, OperationType
from gql_schema.build import build_schema
from gql_sse.server import SseHandler
from gql_sse_execution.executor import GraphQLExecution, Roots
from gql_stream.stream import AnyStream, ListStream

comptime SDL = """
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT
directive @stream(initialCount: Int! = 0, if: Boolean! = true, label: String) on FIELD
type Hero { id: ID name: String }
type Query { hero: Hero a: String }
type Mutation { m: String }
type Subscription { greetings: String }
"""
"""The schema of the suite, with the directives of incremental delivery."""

comptime ROOT = '{"hero":{"id":"1","name":"Luke"},"a":"A","m":"M"}'
"""The root value of queries and mutations."""


struct TestRoot(Roots):
    """The JSON root for queries; for a subscription, a root whose
    `greetings` is a stream of two events, or none when `streams` is
    False."""

    var streams: Bool

    def __init__(out self, streams: Bool = True):
        self.streams = streams

    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        if document.operation(operation) != OperationType.SUBSCRIPTION:
            var value = parse_json(ROOT)
            return values.add_json(value, value.root)
        var root = values.add_object()
        if self.streams:
            var stream = ListStream.of_json(
                ['{"greetings":"hi"}', '{"greetings":"hey"}']
            )
            values.add_member(
                root, "greetings", values.add_stream(AnyStream(stream^))
            )
        return root


def execution(
    incremental: Bool = True, streams: Bool = True
) raises -> GraphQLExecution[TestRoot]:
    """Make an executor of the schema of the suite."""
    return GraphQLExecution(
        build_schema(SDL), Resolvers(), TestRoot(streams), incremental
    )


def config() -> ServerConfig:
    """Return a configuration on a free loopback port."""
    var c = ServerConfig()
    c.host = IPv4Address.LOOPBACK
    c.port = 0
    c.stream_poll_ms = 1
    return c^


def sse_server(
    incremental: Bool = True, streams: Bool = True
) raises -> Server[SseHandler[GraphQLExecution[TestRoot]]]:
    """Serve the executor over SSE on a free loopback port."""
    return listen(SseHandler(execution(incremental, streams)), config())


def encode(text: StringSlice) -> String:
    """Percent-encode a query string value."""
    var out = String()
    var bytes = text.as_bytes()
    var i = 0
    while i < len(bytes):
        var b = bytes[i]
        if (
            (b >= 48 and b <= 57)
            or (b >= 65 and b <= 90)
            or (b >= 97 and b <= 122)
        ):
            out += chr(Int(b))
        else:
            out += "%"
            out += StaticString("0123456789ABCDEF")[
                byte = Int(b >> 4) : Int(b >> 4) + 1
            ]
            out += StaticString("0123456789ABCDEF")[
                byte = Int(b & 15) : Int(b & 15) + 1
            ]
        i += 1
    return out


def exchange[
    H: Handler
](mut server: Server[H], request: StringSlice) raises -> String:
    """Send one request on a new connection; return what comes back."""
    var sys = Sys()
    var fd = sys.socket()
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, server.port)
    if rc < 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    var bytes = request.as_bytes()
    var sent = 0
    while sent < len(bytes):
        var n = sys.send(
            fd, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
        )
        if n == -EAGAIN:
            _ = server.poll(2)
            continue
        if n < 0:
            raise Error("send failed: " + String(n))
        sent += n
    var out = List[UInt8]()
    var buffer = List[UInt8](length=65536, fill=0)
    var quiet = 0
    while quiet < 20:
        _ = server.poll(2)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n > 0:
            out.extend(Span(buffer)[:n])
            quiet = 0
        elif n == 0:
            break
        else:
            quiet += 1
    sys.close(fd)
    return String(unsafe_from_utf8=out)


def request(
    method: StringSlice,
    target: StringSlice,
    accept: StringSlice = "",
    token: StringSlice = "",
    body: StringSlice = "",
) -> String:
    """Write a request; a body is JSON."""
    var text = (
        String(method) + " " + String(target) + " HTTP/1.1\r\nHost: x\r\n"
    )
    if accept.byte_length() > 0:
        text += "Accept: " + String(accept) + "\r\n"
    if token.byte_length() > 0:
        text += "x-graphql-event-stream-token: " + String(token) + "\r\n"
    if body.byte_length() > 0:
        text += "Content-Type: application/json\r\n"
    text += "Content-Length: " + String(body.byte_length()) + "\r\n\r\n"
    return text + String(body)
