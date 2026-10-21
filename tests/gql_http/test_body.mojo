# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of streamed content: `gql_http.body`, held responses of
`gql_http.server`, and `BodyStream` and `Client.stream` of
`gql_http.client`. No upstream suite; the framing cases follow hyper
`proto::h1::encode` and `decode` tests."""

from _harness import config, connect, drain, loopback_pair, receive, send_text
from _peer import CLOSE, DROP, KEEP, Step, start_peer
from gql_http.body import (
    BodyPoll,
    BodyPump,
    BodySource,
    append_chunk,
    append_hex,
    append_last_chunk,
)
from gql_http.client import (
    BodyStream,
    Client,
    ResponseSource,
    read_response_head,
    Response,
)
from gql_http.error import HttpError
from gql_http.headers import Headers
from gql_http.parser import BodyKind, Limits, Request
from gql_http.server import (
    Handler,
    ResponseWriter,
    Server,
    ServerConfig,
    listen,
)
from gql_http.socket import EAGAIN, EINTR, EPIPE, Faults, Sys, SysCall
from gql_http.status import Method, Status
from std.time import perf_counter_ns
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _text(data: List[UInt8]) -> String:
    return String(unsafe_from_utf8=data)


struct Script(BodySource):
    """A source that gives its parts in turn. A part `.` is PENDING, `!`
    is ERROR, `?` raises; the last part comes with DONE."""

    var parts: List[String]
    var next: Int

    def __init__(out self, var parts: List[String]):
        self.parts = parts^
        self.next = 0

    def poll_body(mut self, mut out: List[UInt8]) raises -> BodyPoll:
        if self.next >= len(self.parts):
            return BodyPoll.DONE
        var part = self.parts[self.next]
        self.next += 1
        if part == ".":
            return BodyPoll.PENDING
        if part == "!":
            return BodyPoll.ERROR
        if part == "?":
            raise Error("source failed")
        out.extend(part.as_bytes())
        if self.next == len(self.parts):
            return BodyPoll.DONE
        return BodyPoll.READY


def test_body_poll() raises:
    assert_true(BodyPoll.READY.is_valid())
    assert_true(BodyPoll.ERROR.is_valid())
    assert_false(BodyPoll(4).is_valid())
    assert_equal(String(BodyPoll.READY), "READY")
    assert_equal(String(BodyPoll.PENDING), "PENDING")
    assert_equal(String(BodyPoll.DONE), "DONE")
    assert_equal(String(BodyPoll.ERROR), "ERROR")
    assert_equal(String(BodyPoll(9)), "BodyPoll(9)")


def test_framing() raises:
    var out = List[UInt8]()
    append_hex(out, 0)
    out.append(32)
    append_hex(out, 255)
    out.append(32)
    append_hex(out, 0x1A2B)
    assert_equal(_text(out), "0 ff 1a2b")
    out.clear()
    append_chunk(out, StaticString("").as_bytes())
    assert_equal(len(out), 0)
    append_chunk(out, StaticString("hello").as_bytes())
    append_last_chunk(out)
    assert_equal(_text(out), "5\r\nhello\r\n0\r\n\r\n")


def test_pump_fill() raises:
    var pump = BodyPump(Script(["ab", ".", "cde"]))
    assert_equal(pump.fill(), BodyPoll.PENDING)
    assert_equal(_text(pump.out), "2\r\nab\r\n")
    assert_false(pump.finished())
    assert_equal(pump.fill(), BodyPoll.DONE)
    assert_equal(_text(pump.out), "2\r\nab\r\n3\r\ncde\r\n0\r\n\r\n")
    # A pump that has ended reports its state again.
    assert_equal(pump.fill(), BodyPoll.DONE)
    var plain = BodyPump(Script(["ab", "cd"]), chunked=False)
    assert_equal(plain.fill(), BodyPoll.DONE)
    assert_equal(_text(plain.out), "abcd")
    var bad = BodyPump(Script(["ab", "!"]))
    assert_equal(bad.fill(), BodyPoll.ERROR)
    assert_equal(bad.state, BodyPoll.ERROR)
    var raising = BodyPump(Script(["?"]))
    assert_equal(raising.fill(), BodyPoll.ERROR)
    # Over the high-water mark the pump stops polling.
    var full = BodyPump(Script(["abcd", "efgh", "ij"]), high_water=4)
    assert_equal(full.fill(), BodyPoll.READY)
    assert_equal(_text(full.out), "4\r\nabcd\r\n")


def test_pump_send() raises:
    var sys = Sys()
    var pair = loopback_pair(sys)
    var pump = BodyPump(Script(["abcd", "efgh", "ij"]), high_water=4)
    assert_equal(pump.send(sys, pair.server), 0)
    assert_equal(pump.fill(), BodyPoll.READY)
    sys.faults = Faults(SysCall.SEND, EAGAIN, 0, 1)
    assert_equal(pump.send(sys, pair.server), 0)
    sys.faults = Faults(SysCall.SEND, EINTR, 0, 1)
    assert_equal(pump.send(sys, pair.server), 0)
    sys.faults = Faults(SysCall.SEND, EPIPE, 0, 1)
    assert_equal(pump.send(sys, pair.server), -EPIPE)
    assert_equal(pump.send(sys, pair.server), 9)
    assert_equal(pump.buffered(), 0)
    assert_equal(pump.fill(), BodyPoll.READY)
    assert_equal(pump.send(sys, pair.server), 9)
    assert_equal(pump.fill(), BodyPoll.DONE)
    assert_equal(pump.send(sys, pair.server), 12)
    assert_true(pump.finished())
    # A part larger than the socket takes: the sent bytes move out.
    var big = BodyPump(Script([String("x") * (1 << 23), "y"]), high_water=4)
    assert_equal(big.fill(), BodyPoll.READY)
    var total = big.buffered()
    var n = big.send(sys, pair.server)
    assert_true(n > 4 and n < total, String(n))
    assert_equal(big.sent, 0)
    assert_equal(big.buffered(), total - n)
    # Under the high-water mark the sent bytes stay until the end.
    var wide = BodyPump(Script([String("x") * (1 << 23)]), high_water=1 << 30)
    assert_equal(wide.fill(), BodyPoll.DONE)
    _ = drain(sys, pair.client)
    var m = wide.send(sys, pair.server)
    assert_true(m > 0 and m < wide.buffered() + m, String(m))
    assert_equal(wide.sent, m)
    pair.close(sys)


struct Pieces(ResponseSource):
    """A response source that gives its pieces in turn, then the end."""

    var pieces: List[String]
    var next: Int

    def __init__(out self, var pieces: List[String]):
        self.pieces = pieces^
        self.next = 0

    def read_more(
        mut self, mut data: List[UInt8], mut end: Int, deadline: Int
    ) raises HttpError -> Int:
        if self.next >= len(self.pieces):
            return 0
        var piece = self.pieces[self.next].as_bytes()
        self.next += 1
        if len(data) < end + len(piece):
            data.resize(end + len(piece), 0)
        var i = 0
        while i < len(piece):
            data[end + i] = piece[i]
            i += 1
        end += len(piece)
        return len(piece)


def _stream(
    var pieces: List[String], method: Method = Method.GET
) raises -> BodyStream:
    var source = Pieces(pieces^)
    var response = Response()
    return read_response_head(source, method, Limits(), 0, response)


def _all(var pieces: List[String]) raises -> String:
    """Read the whole content of a scripted response, part by part, and
    join the parts with `|`."""
    var source = Pieces(pieces^)
    var response = Response()
    var body = read_response_head(source, Method.GET, Limits(), 0, response)
    var text = String()
    var out = List[UInt8]()
    while body.read(source, out, 0):
        text += _text(out) + "|"
        out.clear()
    assert_false(body.read(source, out, 0))
    return text + ("keep" if body.keep_alive else "close")


comptime CHUNKED = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"


def _error(var pieces: List[String]) -> String:
    try:
        _ = _all(pieces^)
    except e:
        return String(e)
    return "no error"


def test_body_stream() raises:
    assert_equal(
        _all([CHUNKED + "3\r\nabc\r\n", "2\r\nde\r\n", "0\r\n\r\n"]),
        "abc|de|keep",
    )
    # The head and the whole content in one read.
    assert_equal(_all([CHUNKED + "1\r\na\r\n0\r\n\r\n"]), "a|keep")
    # A chunk split in the size line, and a trailer split.
    assert_equal(
        _all([CHUNKED + "1", "\r\nx\r\n0\r\nA: b", "\r\n\r\n"]), "x|keep"
    )
    # Bytes after the content: the connection cannot stay open.
    assert_equal(_all([CHUNKED + "0\r\n\r\nHTTP"]), "close")
    assert_equal(
        _all(["HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nab", "cde"]),
        "ab|cde|keep",
    )
    assert_equal(
        _all(["HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nabX"]), "ab|close"
    )
    assert_equal(_all(["HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"]), "keep")
    assert_equal(
        _all(["HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\nX"]), "close"
    )
    assert_equal(_all(["HTTP/1.1 204 No Content\r\n\r\n"]), "keep")
    assert_equal(_all(["HTTP/1.1 200 OK\r\n\r\nab", "cd"]), "ab|cd|close")
    var head = _stream(
        ["HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n"], Method.HEAD
    )
    assert_true(head.done)
    assert_equal(head.kind, BodyKind.NONE)


def test_body_stream_errors() raises:
    assert_equal(
        _error([CHUNKED + "zz\r\n"]), "protocol: invalid chunked content"
    )
    assert_equal(
        _error([CHUNKED + "fffffffffffffffffffff\r\n"]),
        "limit: the chunk is too large",
    )
    assert_equal(
        _error([CHUNKED + "3\r\nab"]),
        "closed: the connection closed in the content",
    )
    assert_equal(
        _error(["HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nab"]),
        "closed: the connection closed in the content",
    )


struct Streamer(Handler):
    """Holds `/sse` and `/sse?...`; gives each connection the parts of
    `parts` in turn. A part `*` is PENDING for ever, `.` is PENDING once,
    `!` is ERROR and `?` raises. Other paths get `plain`."""

    var parts: List[String]
    var next: List[Int]
    var closed: Int

    def __init__(out self, var parts: List[String]):
        self.parts = parts^
        self.next = List[Int](length=4096, fill=0)
        self.closed = 0

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        if not (request.path() == "/sse"):
            response.write_text("plain")
            return
        response.add_header("Content-Type", "text/event-stream")
        response.begin_chunked()
        response.hold()
        if request.target() == "/sse?fail":
            raise Error("after hold")

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        var index = self.next[id]
        if index >= len(self.parts):
            self.next[id] = 0
            return BodyPoll.DONE
        var part = self.parts[index]
        if part == "*":
            return BodyPoll.PENDING
        self.next[id] = index + 1
        if part == ".":
            return BodyPoll.PENDING
        if part == "!":
            return BodyPoll.ERROR
        if part == "?":
            raise Error("poll failed")
        if part.startswith("$"):
            # The last part comes with the end.
            self.next[id] = 0
            out.extend(part.as_bytes()[1:])
            return BodyPoll.DONE
        out.extend(part.as_bytes())
        return BodyPoll.READY

    def body_closed(mut self, id: Int):
        self.closed += 1
        self.next[id] = 0


def _drive[H: Handler](mut server: Server[H], turns: Int) raises:
    var turn = 0
    while turn < turns:
        _ = server.poll(2)
        turn += 1


def _drive_ms[H: Handler](mut server: Server[H], ms: Int) raises:
    var end = perf_counter_ns() + ms * 1_000_000
    while perf_counter_ns() < end:
        _ = server.poll(2)


def _server(var parts: List[String]) raises -> Server[Streamer]:
    return listen(Streamer(parts^), config())


comptime GET_SSE = "GET /sse HTTP/1.1\r\nHost: x\r\n\r\n"


def test_writer_hold() raises:
    var writer = ResponseWriter()
    var message = String("no error")
    try:
        writer.hold()
    except e:
        message = String(e)
    assert_equal(message, "usage: call begin_chunked first")
    assert_false(writer.held())
    assert_true(writer.chunked())
    assert_equal(writer.connection(), -1)
    writer.begin_chunked()
    writer.hold()
    assert_true(writer.held())
    writer.finish()
    # A held stream gets no last chunk from `finish`.
    assert_false(_text(writer.out).endswith("0\r\n\r\n"))
    writer.fail()
    assert_false(writer.held())


def test_held_stream() raises:
    var server = _server(["data: a\n\n", ".", "data: b\n\n"])
    var sys = Sys()
    var fd = connect(sys, server.port)
    # A request that comes during the stream waits for its end.
    send_text(sys, fd, GET_SSE + "GET /x HTTP/1.1\r\nHost: x\r\n\r\n")
    var text = receive(server, sys, fd)
    assert_true(text.find("Transfer-Encoding: chunked\r\n") > 0, text)
    assert_true(
        text.find("\r\n\r\n9\r\ndata: a\n\n\r\n9\r\ndata: b\n\n\r\n0\r\n\r\n")
        > 0,
        text,
    )
    assert_true(text.endswith("\r\n\r\nplain"), text)
    assert_equal(server.streams(), 0)
    assert_equal(server.open_connections, 1)
    # A held HEAD response ends at once.
    send_text(sys, fd, "HEAD /sse HTTP/1.1\r\nHost: x\r\n\r\n")
    text = receive(server, sys, fd)
    assert_true(text.startswith("HTTP/1.1 200 OK"), text)
    assert_equal(server.streams(), 0)
    sys.close(fd)
    _drive(server, 5)
    assert_equal(server.handler.closed, 0)


def test_held_stream_close() raises:
    # HTTP/1.0 gets the bytes as they are, and the end of the connection.
    var server = _server(["ab", "cd"])
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, "GET /sse HTTP/1.0\r\n\r\n")
    var text = receive(server, sys, fd)
    assert_true(text.endswith("\r\n\r\nabcd"), text)
    assert_equal(server.open_connections, 0)
    sys.close(fd)
    # `Connection: close` ends the connection after the last chunk.
    fd = connect(sys, server.port)
    send_text(
        sys, fd, "GET /sse HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
    )
    text = receive(server, sys, fd)
    assert_true(text.endswith("2\r\ncd\r\n0\r\n\r\n"), text)
    assert_equal(server.open_connections, 0)
    sys.close(fd)
    # A request after `Connection: close` is not answered; the server
    # lingers until the client closes.
    fd = connect(sys, server.port)
    send_text(
        sys,
        fd,
        "GET /sse HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\nGET /x",
    )
    text = receive(server, sys, fd)
    assert_true(text.endswith("2\r\ncd\r\n0\r\n\r\n"), text)
    sys.close(fd)
    _drive(server, 5)
    assert_equal(server.open_connections, 0)
    # A stream that ends on a later turn closes the connection too.
    var later = _server(["ab", ".", "cd"])
    fd = connect(sys, later.port)
    send_text(
        sys, fd, "GET /sse HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
    )
    text = receive(later, sys, fd)
    assert_true(text.endswith("2\r\nab\r\n2\r\ncd\r\n0\r\n\r\n"), text)
    assert_equal(later.open_connections, 0)
    sys.close(fd)


struct Plain(Handler):
    """A handler with the default `poll_body` and `body_closed`."""

    var count: Int

    def __init__(out self):
        self.count = 0

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        response.begin_chunked()
        response.hold()


def test_default_handler() raises:
    var plain = Plain()
    var out = List[UInt8]()
    assert_equal(plain.poll_body(3, out), BodyPoll.DONE)
    plain.body_closed(3)
    # A held response of the default handler ends at once.
    var server = listen(Plain(), config())
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, GET_SSE)
    var text = receive(server, sys, fd)
    assert_true(text.endswith("\r\n\r\n0\r\n\r\n"), text)
    sys.close(fd)


def test_held_stream_failures() raises:
    var server = _server(["ab", "!"])
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, GET_SSE)
    var text = receive(server, sys, fd)
    assert_true(text.endswith("2\r\nab\r\n"), text)
    assert_equal(server.open_connections, 0)
    assert_equal(server.handler.closed, 1)
    sys.close(fd)
    server.handler.parts = ["?"]
    fd = connect(sys, server.port)
    send_text(sys, fd, GET_SSE)
    _ = receive(server, sys, fd)
    assert_equal(server.open_connections, 0)
    assert_equal(server.handler.closed, 2)
    sys.close(fd)
    # A handler that raises after `hold` breaks the stream.
    fd = connect(sys, server.port)
    send_text(sys, fd, "GET /sse?fail HTTP/1.1\r\nHost: x\r\n\r\n")
    text = receive(server, sys, fd)
    assert_false(text.endswith("0\r\n\r\n"), text)
    assert_equal(server.streams(), 0)
    sys.close(fd)


def test_client_goes_away() raises:
    var server = _server(["a", "*"])
    var sys = Sys()
    var fd = connect(sys, server.port)
    var other = connect(sys, server.port)
    send_text(sys, fd, GET_SSE)
    _ = receive(server, sys, fd, 5)
    assert_equal(server.streams(), 1)
    # Another connection, open and not held, is not polled.
    _drive(server, 3)
    sys.close(fd)
    _drive(server, 10)
    assert_equal(server.streams(), 0)
    assert_equal(server.handler.closed, 1)
    sys.close(other)
    _drive(server, 5)


def test_shutdown_keeps_streams() raises:
    var c = config()
    c.shutdown_timeout_ms = 100
    var server = listen(Streamer(["a", ".", ".", ".", "b"]), c)
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, GET_SSE)
    _ = server.poll(5)
    _ = server.poll(5)
    server.begin_shutdown()
    # The live stream is not idle: it ends, and then the connection.
    assert_equal(server.open_connections, 1)
    var text = receive(server, sys, fd)
    assert_true(text.endswith("1\r\nb\r\n0\r\n\r\n"), text)
    assert_true(server.stopped())
    sys.close(fd)
    # A stream that does not end closes at the deadline.
    var other = listen(Streamer(["a", "*"]), c)
    fd = connect(sys, other.port)
    send_text(sys, fd, GET_SSE)
    _ = receive(other, sys, fd, 5)
    other.begin_shutdown()
    assert_equal(other.open_connections, 1)
    other.run()
    assert_equal(other.open_connections, 0)
    assert_equal(other.handler.closed, 1)
    sys.close(fd)


def test_quiet_and_slow_streams() raises:
    var c = config()
    c.idle_timeout_ms = 20
    c.stream_poll_ms = 1
    var big = String("x") * (1 << 24)
    var server = listen(Streamer(["a", "*"]), c)
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, GET_SSE)
    _ = receive(server, sys, fd, 5)
    # A quiet stream outlives the idle timeout.
    _drive_ms(server, 1100)
    assert_equal(server.streams(), 1)
    sys.close(fd)
    _drive(server, 5)
    # A client that reads nothing of a large stream times out.
    var slow = listen(Streamer([big, "*"]), c)
    fd = connect(sys, slow.port)
    send_text(sys, fd, GET_SSE)
    _drive(slow, 5)
    assert_equal(slow.open_connections, 1)
    var turn = 0
    while slow.open_connections > 0 and turn < 3000:
        _ = slow.poll(2)
        turn += 1
    assert_equal(slow.open_connections, 0)
    assert_equal(slow.handler.closed, 1)
    sys.close(fd)


def test_large_stream() raises:
    # Parts over a turn's budget, and a client that reads late.
    var part = String("y") * 40000
    var server = _server([part, part, part, "$" + String("z") * (1 << 22)])
    var sys = Sys()
    var fd = connect(sys, server.port)
    send_text(sys, fd, GET_SSE + "GET /x HTTP/1.1\r\nHost: x\r\n\r\n")
    _drive(server, 20)
    var text = receive(server, sys, fd)
    assert_true(text.endswith("\r\n\r\nplain"), String(text.byte_length()))
    assert_equal(server.streams(), 0)
    sys.close(fd)
    # With `Connection: close`, the end waits for the client to read it.
    fd = connect(sys, server.port)
    send_text(
        sys, fd, "GET /sse HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
    )
    _drive(server, 20)
    text = receive(server, sys, fd)
    assert_true(text.endswith("z\r\n0\r\n\r\n"), String(text.byte_length()))
    assert_equal(server.open_connections, 0)
    sys.close(fd)


def test_client_stream() raises:
    var peer = start_peer(
        [
            Step(CHUNKED + "3\r\nabc\r\n~2\r\nde\r\n0\r\n\r\n", KEEP),
            Step("HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nab", CLOSE),
        ]
    )
    var client = Client()
    var url = "http://127.0.0.1:" + String(peer.port) + "/"
    var endpoint = client.endpoint(url)
    var none = List[UInt8]()
    var stream = client.stream(
        client.start(endpoint, Method.GET, "/", Headers(), none)
    )
    assert_equal(stream.response.status, Status.OK)
    var out = List[UInt8]()
    assert_true(client.read_body(stream, out))
    assert_equal(_text(out), "abc")
    out.clear()
    assert_true(client.read_body(stream, out))
    assert_equal(_text(out), "de")
    assert_false(client.read_body(stream, out))
    assert_equal(client.idle_connections(), 1)
    assert_false(client.read_body(stream, out))
    # The pooled connection gets the next request; it ends early.
    var short = client.stream(
        client.start(endpoint, Method.GET, "/", Headers(), none)
    )
    out.clear()
    assert_true(client.read_body(short, out))
    var message = String("no error")
    try:
        _ = client.read_body(short, out)
    except e:
        message = String(e)
    assert_equal(message, "closed: the connection closed in the content")
    assert_equal(short.fd, -1)
    _ = peer.finish()


def test_client_stream_close() raises:
    var peer = start_peer([Step(CHUNKED + "3\r\nabc\r\n", KEEP)])
    var client = Client()
    var url = "http://127.0.0.1:" + String(peer.port) + "/"
    var endpoint = client.endpoint(url)
    var none = List[UInt8]()
    var stream = client.stream(
        client.start(endpoint, Method.GET, "/", Headers(), none)
    )
    var out = List[UInt8]()
    assert_true(client.read_body(stream, out))
    client.close_stream(stream)
    client.close_stream(stream)
    assert_equal(stream.fd, -1)
    _ = peer.finish()
    # A peer that closes before the head.
    var drop = start_peer([Step("", DROP)])
    url = "http://127.0.0.1:" + String(drop.port) + "/"
    endpoint = client.endpoint(url)
    var message = String("no error")
    try:
        _ = client.stream(
            client.start(endpoint, Method.GET, "/", Headers(), none)
        )
    except e:
        message = String(e)
    assert_equal(message, "closed: the connection closed before the response")
    _ = drop.finish()
    # Close-delimited content ends at the close, and the connection with it.
    var until = start_peer([Step("HTTP/1.1 200 OK\r\n\r\nab", CLOSE)])
    url = "http://127.0.0.1:" + String(until.port) + "/"
    endpoint = client.endpoint(url)
    var closing = client.stream(
        client.start(endpoint, Method.GET, "/", Headers(), none)
    )
    out.clear()
    while client.read_body(closing, out):
        pass
    assert_equal(_text(out), "ab")
    assert_equal(client.idle_connections(), 0)
    _ = until.finish()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
