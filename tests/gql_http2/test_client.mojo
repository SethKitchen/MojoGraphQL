# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_http2.client`: h2c with prior knowledge, the fallback to
HTTP/1.1, the reuse and retry of connections, and the errors.

The servers run in worker processes: gql_http2 for HTTP/2, gql_http for
HTTP/1.1, and scripted peers that close or stay quiet. Ported from h2
v0.4.20 `tests/h2-tests/tests/client_request.rs` for the parts that a
whole-response client has.
"""

from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.server import ServerConfig as HttpConfig
from gql_http.server import start_workers as start_http1
from gql_http.socket import (
    ECONNRESET,
    Faults,
    IPv4Address,
    POLLIN,
    Sys,
    SysCall,
)
from gql_http.status import Method, Status
from gql_http2.client import (
    Client,
    ClientConfig,
    ClientConnection,
    Protocol,
    Response,
    http_error,
)
from gql_http2.error import H2Error, H2ErrorKind, Reason
from gql_http2.server import ServerConfig, start_workers
from gql_http2.session import ServerSession, SocketTransport, serve_transport
from std.testing import TestSuite, assert_equal, assert_false, assert_true


@fieldwise_init
struct App(Handler):
    """Echoes the request; `/binary` is not UTF-8; `/stream-fail` breaks."""

    var count: Int

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        self.count += 1
        if request.path() == "/binary":
            response.write(List[UInt8](length=2, fill=0xFF))
            return
        if request.path() == "/stream-fail":
            response.begin_chunked()
            raise Error("broken")
        response.add_header("Content-Type", "text/plain")
        response.add_header("X-Echo", "yes")
        response.write_text(request.method_text())
        response.write_text(" ")
        response.write_text(request.target())
        response.write_text(" ")
        var ua = request.header("user-agent")
        if ua:
            response.write_text(ua.value())
        response.write_text(" ")
        response.write(request.body())


def _h2_server() raises -> Int:
    """Start one gql_http2 worker; return its port. Workers die with the
    suite."""
    var config = ServerConfig()
    config.http.host = IPv4Address.LOOPBACK
    config.http.port = 0
    var pool = start_workers(App(0), config)
    var port = pool.port
    pool.pids.clear()
    return port


def _h1_server() raises -> Int:
    """Start one gql_http worker; return its port."""
    var config = HttpConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    var pool = start_http1(App(0), config)
    var port = pool.port
    pool.pids.clear()
    return port


def _url(port: Int, path: StringSlice) -> String:
    return "http://127.0.0.1:" + String(port) + String(path)


def test_h2_requests() raises:
    var port = _h2_server()
    var client = Client()
    var response = client.post(_url(port, "/graphql"), "application/json", "{}")
    assert_true(response.protocol == Protocol.HTTP_2)
    assert_equal(response.status.code, 200)
    assert_equal(response.text(), "POST /graphql  {}")
    assert_equal(String(response.header("X-ECHO").value()), "yes")
    assert_false(Bool(response.header("x-missing")))
    assert_false(Bool(response.header("x-ech")))
    assert_true(response.header_count() >= 3)
    assert_equal(String(response.header_name(0)), "date")
    assert_true(String(response.header_value(0)).endswith("GMT"))
    assert_equal(len(response.body()), 17)
    # The connection is kept for the next request.
    var endpoint = client.endpoint(_url(port, "/x"))
    var headers = Headers()
    headers.add("User-Agent", "test")
    headers.add("Connection", "keep-alive")
    headers.add("Host", "dropped")
    var again = client.send(
        endpoint, Method.GET, "/q?1", headers, List[UInt8]()
    )
    assert_equal(again.text(), "GET /q?1 test ")
    assert_equal(client.connections(), 1)
    var get = client.get(_url(port, "/g"))
    assert_equal(get.text(), "GET /g  ")
    assert_false(client.speaks_http1(endpoint))
    client.close()
    assert_equal(client.connections(), 0)


def test_fallback_to_http1() raises:
    var port = _h1_server()
    var client = Client()
    var response = client.get(_url(port, "/one"))
    assert_true(response.protocol == Protocol.HTTP_1_1)
    assert_equal(response.text(), "GET /one  ")
    assert_equal(String(response.header("content-type").value()), "text/plain")
    var endpoint = client.endpoint(_url(port, "/"))
    assert_true(client.speaks_http1(endpoint))
    assert_equal(client.connections(), 0)
    # Later requests go with HTTP/1.1 at once.
    response = client.get(_url(port, "/two"))
    assert_true(response.protocol == Protocol.HTTP_1_1)
    # Without the fallback, an HTTP/1.1 server is an error.
    var config = ClientConfig()
    config.fallback = False
    var strict = Client(config)
    var failed = False
    try:
        _ = strict.get(_url(port, "/three"))
    except e:
        failed = e.kind == ErrorKind.PROTOCOL
    assert_true(failed)


def test_without_prior_knowledge() raises:
    var port = _h2_server()
    var config = ClientConfig()
    config.prior_knowledge = False
    var client = Client(config)
    var response = client.get(_url(port, "/plain"))
    assert_true(response.protocol == Protocol.HTTP_1_1)
    assert_equal(response.text(), "GET /plain  ")


def test_response_errors() raises:
    var port = _h2_server()
    var client = Client()
    var binary = client.get(_url(port, "/binary"))
    var failed = False
    try:
        _ = binary.text()
    except e:
        failed = e.kind == ErrorKind.PROTOCOL
    assert_true(failed)
    # A stream that the server resets.
    failed = False
    try:
        _ = client.get(_url(port, "/stream-fail"))
    except e:
        failed = e.kind == ErrorKind.PROTOCOL and "INTERNAL_ERROR" in e.message
    assert_true(failed)
    # A method without a name.
    var endpoint = client.endpoint(_url(port, "/"))
    failed = False
    try:
        _ = client.send(endpoint, Method.OTHER, "/", Headers(), List[UInt8]())
    except e:
        failed = e.kind == ErrorKind.USAGE
    assert_true(failed)


def test_http_error() raises:
    assert_true(http_error(H2Error.io("x")).kind == ErrorKind.CLOSED)
    assert_true(
        http_error(H2Error(H2ErrorKind.TIMEOUT, Reason.CANCEL, 1, "t")).kind
        == ErrorKind.TIMEOUT
    )
    assert_true(http_error(H2Error.usage("u")).kind == ErrorKind.USAGE)
    assert_true(
        http_error(H2Error.stream(1, Reason.CANCEL, "s")).kind
        == ErrorKind.PROTOCOL
    )
    assert_equal(String(Protocol.HTTP_2), "HTTP/2")
    assert_equal(String(Protocol.HTTP_1_1), "HTTP/1.1")
    assert_equal(String(Protocol(7)), "invalid")
    assert_false(Protocol(2).is_valid())
    assert_true(Protocol.HTTP_2.is_valid())


def _listener(mut sys: Sys) raises -> Tuple[Int, Int]:
    """A loopback listener and its port."""
    var fd = sys.socket()
    if sys.bind(fd, IPv4Address.LOOPBACK, 0) < 0:
        raise Error("bind failed")
    _ = sys.listen(fd, 16)
    return (fd, sys.local_port(fd))


def _accept(mut sys: Sys, listener: Int) -> Int:
    _ = sys.poll(listener, POLLIN, 3000)
    return sys.accept(listener)


comptime CLOSE = 0
"""Answer one request, then close without GOAWAY."""
comptime GOAWAY_LATER = 1
"""Answer one request; send GOAWAY when the next one arrives."""
comptime GOAWAY_NOW = 2
"""Answer one request with GOAWAY right after the response."""
comptime SLAM = 3
"""Close the connection as soon as it is accepted."""


def _goaway_bytes() -> List[UInt8]:
    """A GOAWAY frame: last stream 1, NO_ERROR."""
    var out: List[UInt8] = [0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]
    return out^


def _wait_read(mut sys: Sys, fd: Int) -> Int:
    var buffer = List[UInt8](length=65536, fill=0)
    _ = sys.poll(fd, POLLIN, 3000)
    return sys.recv(fd, buffer.unsafe_ptr(), len(buffer))


def _serve_one(mut sys: Sys, fd: Int, mode: Int):
    """Answer the first request of a connection in one of the modes."""
    if mode == SLAM:
        sys.close(fd)
        return
    var session = ServerSession()
    var app = App(0)
    session.start()
    var buffer = List[UInt8](length=65536, fill=0)
    while app.count == 0:
        _ = sys.poll(fd, POLLIN, 3000)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n <= 0:
            break
        session.receive(app, Span(buffer)[:n])
        if app.count > 0 and mode == GOAWAY_NOW:
            session.conn.out.extend(Span(_goaway_bytes()))
        _ = sys.send(fd, session.conn.out.unsafe_ptr(), len(session.conn.out))
        session.conn.out.clear()
    if mode == GOAWAY_LATER:
        _ = _wait_read(sys, fd)
        var goaway = _goaway_bytes()
        _ = sys.send(fd, goaway.unsafe_ptr(), len(goaway))
    if mode != CLOSE:
        while _wait_read(sys, fd) > 0:
            pass
    sys.close(fd)


def _flaky(modes: List[Int]) raises -> Int:
    """Fork a peer that answers one request per connection in each mode,
    then serves its last connection fully; return its port."""
    var sys = Sys()
    var listen = _listener(sys)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        for mode in modes:
            _serve_one(sys, _accept(sys, listen[0]), mode)
        var app = App(0)
        var transport = SocketTransport(_accept(sys, listen[0]))
        try:
            serve_transport(app, transport)
        except:
            pass
        sys.exit_now(0)
    sys.close(listen[0])
    return listen[1]


def test_retry_after_close() raises:
    # A reused connection that the server closed: GET goes again on a new
    # connection; POST does not, as the server could have taken it.
    var port = _flaky([CLOSE, CLOSE])
    var client = Client()
    assert_equal(client.get(_url(port, "/1")).text(), "GET /1  ")
    assert_equal(client.get(_url(port, "/2")).text(), "GET /2  ")
    var failed = False
    try:
        _ = client.post(_url(port, "/3"), "text/plain", "x")
    except e:
        failed = e.kind == ErrorKind.CLOSED
    assert_true(failed)


def test_retry_after_goaway() raises:
    # A GOAWAY that refuses the request on a reused connection: any method
    # goes again on a new connection.
    var port = _flaky([GOAWAY_LATER, GOAWAY_NOW])
    var client = Client()
    assert_equal(client.get(_url(port, "/a")).text(), "GET /a  ")
    assert_equal(client.post(_url(port, "/b"), "a/b", "z").text(), "POST /b  z")
    # The GOAWAY came with the response: the next request does not use
    # that connection.
    assert_equal(client.get(_url(port, "/c")).text(), "GET /c  ")
    assert_equal(client.connections(), 1)


def _quiet(answer: List[UInt8]) raises -> Int:
    """Fork a peer that sends some bytes and then reads forever."""
    var sys = Sys()
    var listen = _listener(sys)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        var fd = _accept(sys, listen[0])
        _ = sys.send(fd, answer.unsafe_ptr(), len(answer))
        var buffer = List[UInt8](length=4096, fill=0)
        while True:
            _ = sys.poll(fd, POLLIN, 3000)
            if sys.recv(fd, buffer.unsafe_ptr(), len(buffer)) == 0:
                break
        sys.exit_now(0)
    sys.close(listen[0])
    return listen[1]


def test_timeout_and_connection_error() raises:
    var config = ClientConfig()
    config.http.timeout_ms = 150
    config.fallback = False
    var client = Client(config)
    var quiet_url = _url(_quiet(List[UInt8]()), "/")
    var failed = False
    try:
        _ = client.get(quiet_url)
    except e:
        failed = e.kind == ErrorKind.TIMEOUT
    assert_true(failed)
    # SETTINGS, then a PING on a stream: a connection error.
    var bad: List[UInt8] = [0, 0, 0, 4, 0, 0, 0, 0, 0]
    var ping: List[UInt8] = [0, 0, 8, 6, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
    bad.extend(Span(ping))
    var bad_url = _url(_quiet(bad), "/")
    var other = Client()
    failed = False
    try:
        _ = other.get(bad_url)
    except e:
        failed = e.kind == ErrorKind.PROTOCOL and "PROTOCOL_ERROR" in e.message
    assert_true(failed)


def test_connect_errors() raises:
    var sys = Sys()
    var listen = _listener(sys)
    sys.close(listen[0])
    var client = Client()
    var failed = False
    try:
        _ = client.get(_url(listen[1], "/"))
    except e:
        failed = e.kind == ErrorKind.CONNECT
    assert_true(failed)
    var calls: List[SysCall] = [SysCall.SOCKET, SysCall.CONNECT, SysCall.POLL]
    var kinds: List[ErrorKind] = [
        ErrorKind.OS,
        ErrorKind.CONNECT,
        ErrorKind.TIMEOUT,
    ]
    var port = _h2_server()
    for index in range(len(calls)):
        var faulty = Client()
        faulty.sys.faults = Faults(calls[index], 111, 0, 1)
        failed = False
        try:
            _ = faulty.get(_url(port, "/"))
        except e:
            failed = e.kind == kinds[index]
        assert_true(failed, String(index))


def test_connection_transport_errors() raises:
    var port = _h2_server()
    var sys = Sys()
    var fd = sys.socket()
    _ = sys.connect(fd, IPv4Address.LOOPBACK, port)
    _ = sys.poll(fd, 4, 2000)
    var transport = SocketTransport(fd)
    transport.sys.faults = Faults(SysCall.RECV, ECONNRESET, 0, 1)
    var connection = ClientConnection[SocketTransport](transport^)
    var failed = False
    try:
        _ = connection.send(
            "GET", "http", "x", "/", Headers(), List[UInt8](), 1000
        )
    except e:
        failed = e.kind == H2ErrorKind.IO and e.message.startswith(
            "read failed"
        )
    assert_true(failed)
    assert_true(connection.conn.closed)
    assert_false(connection.usable())
    connection.close()
    # A close whose GOAWAY cannot go out still closes.
    var other = sys.socket()
    _ = sys.connect(other, IPv4Address.LOOPBACK, port)
    _ = sys.poll(other, 4, 2000)
    var broken = SocketTransport(other)
    broken.sys.faults = Faults(SysCall.SEND, 32, 0, 1)
    var second = ClientConnection[SocketTransport](broken^)
    assert_true(second.usable())
    second.close()
    assert_equal(second.transport.fd(), -1)


def test_client_edges() raises:
    var port = _h2_server()
    var client = Client()
    var response = client.get(_url(port, "/e"))
    # A name of the same length that differs.
    assert_false(Bool(response.header("x-ecHX")))
    # Two servers, and an address with no server: the lists are searched
    # past the entries of other endpoints.
    var second = _h2_server()
    _ = client.get(_url(second, "/s"))
    _ = client.get(_url(port, "/again"))
    assert_equal(client.connections(), 2)
    var h1 = _h1_server()
    var h1b = _h1_server()
    _ = client.get(_url(h1, "/1"))
    _ = client.get(_url(h1b, "/2"))
    _ = client.get(_url(h1, "/3"))
    var elsewhere = client.endpoint("http://127.0.0.2:" + String(h1) + "/")
    assert_false(client.speaks_http1(elsewhere))
    var failed = False
    try:
        _ = client.get("http://127.0.0.2:" + String(port) + "/")
    except e:
        failed = e.kind == ErrorKind.CONNECT
    assert_true(failed)


def test_read_edges() raises:
    # EINTR on read waits again.
    var port = _h2_server()
    var sys = Sys()
    var fd = sys.socket()
    _ = sys.connect(fd, IPv4Address.LOOPBACK, port)
    _ = sys.poll(fd, 4, 2000)
    var transport = SocketTransport(fd)
    transport.sys.faults = Faults(SysCall.RECV, 4, 0, 1)
    var connection = ClientConnection[SocketTransport](transport^)
    var response = connection.send(
        "GET", "http", "x", "/intr", Headers(), List[UInt8](), 2000
    )
    assert_equal(response.text(), "GET /intr  ")
    connection.close()
    # A server that ends its side: the read sees the end.
    var half = _half_closed()
    var other = sys.socket()
    _ = sys.connect(other, IPv4Address.LOOPBACK, half)
    _ = sys.poll(other, 4, 2000)
    var second = ClientConnection[SocketTransport](SocketTransport(other))
    var failed = False
    try:
        _ = second.send("GET", "http", "x", "/", Headers(), List[UInt8](), 2000)
    except e:
        failed = e.kind == H2ErrorKind.IO and "closed" in e.message
    assert_true(failed)


def _half_closed() raises -> Int:
    """Fork a peer that ends its side of the connection at once and reads
    until the client closes."""
    var sys = Sys()
    var listen = _listener(sys)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        var fd = _accept(sys, listen[0])
        _ = sys.shutdown_write(fd)
        while _wait_read(sys, fd) > 0:
            pass
        sys.exit_now(0)
    sys.close(listen[0])
    return listen[1]


def test_retry_that_fails() raises:
    # The retry of a GET on a new connection fails too: the error goes to
    # the caller.
    var port = _flaky([CLOSE, SLAM])
    var client = Client()
    _ = client.get(_url(port, "/1"))
    var failed = False
    try:
        _ = client.get(_url(port, "/2"))
    except e:
        failed = e.kind == ErrorKind.CLOSED
    assert_true(failed)
    assert_equal(client.connections(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
