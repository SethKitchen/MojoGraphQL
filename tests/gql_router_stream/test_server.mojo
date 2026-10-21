# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the server of a router that streams, in this process.

Follows the probes, the streamed responses and the heartbeat of Hive Router
`1a29df9` `bin/router/src/pipeline/mod.rs` and `pipeline/sse.rs`, and the
`subscribe` checks of `pipeline/websocket_server.rs`. The subgraphs run in
a child process; the router and the client run here.
"""

from std.memory import ArcPointer

from _e2e import start_subgraphs
from _supergraph import sdl
from gql_http.body import BodyPoll
from gql_http.server import Handler
from gql_http.server import Server as HttpServer
from gql_http.server import ServerConfig as HttpConfig
from gql_http.server import listen as http_listen
from gql_http.server import open_listener
from gql_http.socket import EAGAIN, POLLIN, Faults, IPv4Address, Sys, SysCall
from gql_router.exec_http import CannedTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router_stream.config import subscriptions_config_from_json
from gql_router_stream.server import (
    RouterStreamHandler,
    RouterWsExecutor,
    RouterWsHandler,
    router_server_config,
    serve_router,
)
from gql_router_stream.subscription import StreamHub
from gql_ws.graphql_ws import parse_message
from gql_ws.server import Server as WsServer
from gql_ws.server import ServerConfig, Sockets, WsHandler
from gql_ws.transport_server import OperationKind
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime ENABLED = '{"subscriptions":{"enabled":true}}'
comptime SUBSCRIBE = '{"query":"subscription { reviewAdded { id } }"}'
comptime SSE = "text/event-stream"


def _hub(
    base: String, config: String = ENABLED
) raises -> ArcPointer[StreamHub[CannedTransport]]:
    var transport = CannedTransport()
    transport.add(
        "products", "{topProducts{upc}}", '{"data":{"topProducts":[]}}'
    )
    return ArcPointer(
        StreamHub(
            Router(RouterSchema(sdl(base)), transport^),
            subscriptions_config_from_json(config),
        )
    )


def _http_config() -> HttpConfig:
    var config = HttpConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    return config^


def _connect(mut sys: Sys, port: Int) raises -> Int:
    var fd = sys.socket()
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, port)
    if rc < 0 and rc != -115:
        raise Error("connect failed: " + String(rc))
    return fd


def _send(mut sys: Sys, fd: Int, text: String) raises:
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


def _post(body: String, accept: String) -> String:
    return (
        "POST /graphql HTTP/1.1\r\nHost: x\r\nContent-Type: application/json"
        + "\r\nAccept: "
        + accept
        + "\r\nContent-Length: "
        + String(body.byte_length())
        + "\r\n\r\n"
        + body
    )


def _get(path: String) -> String:
    return "GET " + path + " HTTP/1.1\r\nHost: x\r\n\r\n"


def _recv_some(mut sys: Sys, fd: Int, mut out: String):
    var buffer = List[UInt8](length=65536, fill=0)
    var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
    if n > 0:
        out += String(unsafe_from_utf8=Span(buffer)[:n])


def _receive[
    H: Handler
](
    mut server: HttpServer[H], mut sys: Sys, fd: Int, until: String
) raises -> String:
    """Run the server until the client has `until`; at most two seconds."""
    var out = String()
    for _ in range(1000):
        _ = server.poll(2)
        _recv_some(sys, fd, out)
        if until in out:
            return out^
    return out^


def _ws_receive[
    W: WsHandler, H: Handler
](
    mut server: WsServer[W, H], mut sys: Sys, fd: Int, until: String
) raises -> String:
    """Run the server until the client has `until`; at most two seconds."""
    var out = String()
    for _ in range(1000):
        _ = server.poll(2)
        _recv_some(sys, fd, out)
        if until in out:
            return out^
    return out^


def test_probes_and_unknown_paths() raises:
    var hub = _hub("http://x")
    var config = ServerConfig()
    config.http.host = IPv4Address.LOOPBACK
    config.http.port = 0
    var server = serve_router(hub, config^)
    var sys = Sys()
    var fd = _connect(sys, server.port)
    _send(sys, fd, _get("/health"))
    var health = _ws_receive(server, sys, fd, "\r\n\r\n")
    _send(sys, fd, _get("/readiness"))
    var readiness = _ws_receive(server, sys, fd, "\r\n\r\n")
    _send(sys, fd, _get("/nope"))
    var nope = _ws_receive(server, sys, fd, "\r\n\r\n")
    sys.close(fd)
    assert_true(health.startswith("HTTP/1.1 200"), health)
    assert_true(readiness.startswith("HTTP/1.1 200"), readiness)
    assert_true(nope.startswith("HTTP/1.1 404"), nope)


def test_the_websocket_path_of_the_server() raises:
    var off = router_server_config(
        subscriptions_config_from_json("{}"), ServerConfig(), "/graphql"
    )
    assert_equal(off.path, " ")
    var same = router_server_config(
        subscriptions_config_from_json('{"websocket":{"enabled":true}}'),
        ServerConfig(),
        "/graphql",
    )
    assert_equal(same.path, "/graphql")
    var own = router_server_config(
        subscriptions_config_from_json(
            '{"websocket":{"enabled":true,"path":"/ws"}}'
        ),
        ServerConfig(),
        "/graphql",
    )
    assert_equal(own.path, "/ws")


def test_a_query_is_one_response() raises:
    var server = http_listen(
        RouterStreamHandler(_hub("http://x")), _http_config()
    )
    var sys = Sys()
    var fd = _connect(sys, server.port)
    _send(
        sys,
        fd,
        _post('{"query":"{ topProducts { upc } }"}', "application/json"),
    )
    var text = _receive(server, sys, fd, "topProducts")
    sys.close(fd)
    assert_true(text.endswith('{"data":{"topProducts":[]}}'), text)
    assert_equal(server.handler.streams(), 0)


def test_a_subscription_streams_in_batches() raises:
    var subgraphs = start_subgraphs()
    var hub = _hub("http://127.0.0.1:" + String(subgraphs.port))
    var server = http_listen(RouterStreamHandler(hub, batch=2), _http_config())
    var sys = Sys()
    var fd = _connect(sys, server.port)
    _send(sys, fd, _post(SUBSCRIBE, SSE))
    var text = _receive(server, sys, fd, "event: complete")
    sys.close(fd)
    subgraphs.stop()
    assert_equal(text.count("event: next"), 11)
    assert_true(text.find("event: complete") > 0, text)
    assert_equal(server.handler.streams(), 0)


def test_a_quiet_stream_gets_heartbeats_until_the_client_leaves() raises:
    # A child answers two requests with the head of an SSE stream, and then
    # stays quiet.
    var sys = Sys()
    var listener = open_listener(sys, IPv4Address.LOOPBACK, 0, 8, False)
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        var open = List[Int]()
        for _ in range(400):
            if len(open) == 2:
                break
            if sys.poll(listener.fd, POLLIN, 5) <= 0:
                continue
            var fd = sys.accept(listener.fd)
            if fd < 0:
                continue
            var buffer = List[UInt8](length=4096, fill=0)
            _ = sys.poll(fd, POLLIN, 1000)
            _ = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
            var reply = String(
                "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n"
                "Transfer-Encoding: chunked\r\n\r\n"
            )
            _ = sys.send(fd, reply.unsafe_ptr(), reply.byte_length())
            open.append(fd)
        _ = sys.poll(-1, 0, 300)
        for fd in open:
            sys.close(fd)
        sys.exit_now(0)
    sys.close(listener.fd)
    var hub = _hub("http://127.0.0.1:" + String(listener.port))
    var server = http_listen(
        RouterStreamHandler(hub, heartbeat_ms=20), _http_config()
    )
    var fd = _connect(sys, server.port)
    _send(sys, fd, _post(SUBSCRIBE, SSE))
    var text = _receive(server, sys, fd, ":\n\n\r\n")
    assert_true(text.endswith("\r\n\r\n3\r\n:\n\n\r\n"), text)
    assert_equal(server.handler.streams(), 1)
    # Incremental delivery has no heartbeat: a quiet stream sends nothing.
    var quiet = _connect(sys, server.port)
    _send(sys, quiet, _post(SUBSCRIBE, "multipart/mixed"))
    var head = _receive(server, sys, quiet, "\r\n\r\n")
    for _ in range(50):
        _ = server.poll(2)
        _recv_some(sys, quiet, head)
    assert_true(head.endswith("\r\n\r\n"), head)
    assert_equal(server.handler.streams(), 2)
    sys.close(quiet)
    # The client goes away: the server closes the held response.
    sys.close(fd)
    for _ in range(200):
        _ = server.poll(2)
        if server.handler.streams() == 0:
            break
    assert_equal(server.handler.streams(), 0)
    _ = sys.wait(pid, True)


def test_a_connection_without_a_held_response() raises:
    var handler = RouterStreamHandler(_hub("http://x"))
    var out = List[UInt8]()
    assert_true(handler.poll_body(9999, out) == BodyPoll.DONE)
    handler.body_closed(9999)
    # A connection whose response has ended.
    handler.held.append(None)
    assert_true(handler.poll_body(0, out) == BodyPoll.DONE)
    assert_equal(len(out), 0)


def _operation(
    mut executor: RouterWsExecutor[CannedTransport], payload: String
) raises -> String:
    var message = parse_message(
        '{"id":"1","type":"subscribe","payload":' + payload + "}"
    )
    var operation = executor.operation(1, message)
    var kind = "result" if operation.kind == OperationKind.RESULT else (
        "errors" if operation.kind == OperationKind.ERRORS else "stream"
    )
    return kind + " " + operation.json


def test_the_subscribe_of_a_websocket() raises:
    var executor = RouterWsExecutor(_hub("http://x"))
    var acknowledgement = executor.on_connect(
        1, parse_message('{"type":"connection_init"}')
    )
    assert_true(acknowledgement.permitted)
    var data = String('result {"data":{"topProducts":[]}}')
    assert_equal(
        _operation(
            executor,
            '{"query":"query Q { topProducts { upc } }","operationName":"Q"}',
        ),
        data,
    )
    # A null name and null variables are the same as none.
    assert_equal(
        _operation(
            executor,
            '{"query":"{ topProducts { upc } }","operationName":null,'
            + '"variables":null}',
        ),
        data,
    )
    # The router forwards the variable to the subgraph, which has no canned
    # answer for that text: the result has the error of the fetch.
    var forwarded = _operation(
        executor,
        '{"query":"query($b: Boolean!) { topProducts @include(if: $b)'
        + ' { upc } }","variables":{"b":true}}',
    )
    assert_true(forwarded.startswith("result "), forwarded)
    assert_true("no canned response" in forwarded, forwarded)
    # `@defer` over WebSocket is one result.
    assert_equal(
        _operation(
            executor, '{"query":"{ topProducts { ... @defer { upc } } }"}'
        ),
        data,
    )
    var bad = _operation(executor, '{"query":"{"}')
    assert_true(bad.startswith('errors [{"message":'), bad)
    executor.on_close(1, 1000, "")


def test_the_websocket_handler() raises:
    var sys = Sys()
    sys.faults = Faults(SysCall.EPOLL_CREATE, 24, 0, 1)
    var message = String("no error")
    try:
        _ = RouterWsHandler(_hub("http://x"), sys=sys^)
    except error:
        message = String(error)
    assert_equal(message, "epoll_create failed: 24")
    var handler = RouterWsHandler(_hub("http://x"))
    var sockets = Sockets(ServerConfig().ws, 1000)
    handler.on_close(sockets, 7, 1000, "")
    assert_true(handler.fd() >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
