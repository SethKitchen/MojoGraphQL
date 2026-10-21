# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the gql_sse suites: an executor of synthetic payloads, a
stream that never ends, and raw loopback clients of a server that runs in
the same process."""

from gql_http.parser import Request
from gql_http.server import Handler, Server, ServerConfig, listen
from gql_http.socket import EAGAIN, IPv4Address, Sys
from gql_http.status import Method, Status
from gql_sse.handler import Prepared, RequestParams, SseExecutor, error_json
from gql_sse.server import SseHandler
from gql_stream.poll import Event, EventStream, Poll
from gql_stream.stream import AnyStream, ListStream
from gql_stream.waker import Waker


struct Forever(EventStream):
    """A stream that is always PENDING. It has a field: an empty type in
    an `AnyStream` box crashes at the free."""

    var polls: Int

    def __init__(out self):
        self.polls = 0

    def poll_next(mut self, mut waker: Waker) -> Poll:
        return Poll.pending()

    def close(mut self):
        self.polls = 0


struct Fake(SseExecutor):
    """Answers by the query: `syntax`, `mutation`, `invalid`, `raise`,
    `count:<n>`, `forever`, `fail`; any other query is one result."""

    var count: Int

    def __init__(out self):
        self.count = 0

    def prepare(
        mut self, request: Request, params: RequestParams, event_stream: Bool
    ) raises -> Prepared:
        self.count += 1
        var q = params.query
        if q == "syntax":
            return Prepared.response(
                Status.BAD_REQUEST, error_json("Syntax Error")
            )
        if q == "mutation" and request.method == Method.GET:
            return Prepared.response(
                Status.METHOD_NOT_ALLOWED,
                error_json("Cannot perform mutations over GET"),
                "POST",
            )
        if q == "invalid":
            if event_stream:
                return Prepared.result('{"errors":[{"message":"invalid"}]}')
            return Prepared.response(
                Status.BAD_REQUEST, '{"errors":[{"message":"invalid"}]}'
            )
        if q == "raise":
            raise Error("executor failed")
        if q.startswith("count:"):
            var n = Int(q[byte=6:])
            var texts = List[String]()
            var i = 0
            while i < n:
                texts.append('{"data":{"n":' + String(i) + "}}")
                i += 1
            return Prepared.of_stream(AnyStream(ListStream.of_json(texts)))
        if q == "forever":
            return Prepared.of_stream(AnyStream(Forever()))
        if q == "fail":
            return Prepared.of_stream(
                AnyStream(ListStream.of_json(['{"data":{}}'], "stream failed"))
            )
        if q == "fail0":
            return Prepared.of_stream(
                AnyStream(ListStream.of_json([], "stream failed"))
            )
        return Prepared.result('{"data":{"q":"' + q + '"}}')


def sse_server() raises -> Server[SseHandler[Fake]]:
    """Serve the fake executor on a free loopback port."""
    var c = ServerConfig()
    c.host = IPv4Address.LOOPBACK
    c.port = 0
    c.stream_poll_ms = 1
    return listen(SseHandler(Fake()), c)


def connect(mut sys: Sys, port: Int) raises -> Int:
    """Connect a non-blocking socket to the loopback port."""
    var fd = sys.socket()
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc < 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    return fd


def send_text(mut sys: Sys, fd: Int, text: StringSlice) raises:
    """Send all of a text."""
    var bytes = text.as_bytes()
    var sent = 0
    while sent < len(bytes):
        var n = sys.send(
            fd, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
        )
        if n == -EAGAIN:
            _ = sys.poll(fd, 4, 100)
            continue
        if n < 0:
            raise Error("send failed: " + String(n))
        sent += n


def receive[
    H: Handler
](
    mut server: Server[H], mut sys: Sys, fd: Int, turns: Int = 20
) raises -> String:
    """Run the server and read what the client gets until it is quiet."""
    var out = List[UInt8]()
    var buffer = List[UInt8](length=65536, fill=0)
    var quiet = 0
    while quiet < turns:
        _ = server.poll(2)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n > 0:
            out.extend(Span(buffer)[:n])
            quiet = 0
        elif n == 0:
            break
        else:
            quiet += 1
    return String(unsafe_from_utf8=out)


def exchange[
    H: Handler
](mut server: Server[H], request: StringSlice) raises -> String:
    """Send one request on a new connection; return what comes back."""
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, request)
    var text = receive(server, sys, fd)
    sys.close(fd)
    return text
