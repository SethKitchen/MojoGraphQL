# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_server.standalone`, ported from Apollo Server 5.5.1
`src/__tests__/standalone/standaloneSpecific.test.ts` and the body parser
cases of `packages/integration-testsuite/src/httpServerTests.ts`
(`throws an error if POST body is empty`, `... is missing even with
content-type`, `... invalid content-type`, `... POST JSON is malformed`,
`responses have content-length headers`). Every expected response comes
from Apollo Server 5.5.1 `startStandaloneServer`, with `NODE_ENV`
`production` for the pages of `finalhandler`.

The handler gets each request from a `gql_http` `RequestReader`, so most
tests need no socket. One test starts the server and sends a request.

Upstream cases that are not ported: the `stopping` and draining cases,
which need a Node.js HTTP server; and the `cors` and `context` options of
`expressMiddleware`, which is not ported.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _helpers import SDL, context, options, resolvers
from gql_http.client import Client
from gql_http.parser import Limits, RequestReader
from gql_http.server import ResponseWriter, ServerConfig
from gql_http.socket import IPv4Address
from _incremental import ALPHA_9_ACCEPT, INCREMENTAL_SDL, incremental_resolvers
from _plugins import Recorder
from gql_http.body import BodyPoll
from gql_server.plugin import NoPlugin, ServerPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.standalone import (
    StandaloneHandler,
    request_headers,
    start_standalone_server,
)

comptime OK = '{"data":{"testString":"it works"}}\n'
"""The content of `{ testString }`."""


def _handler() raises -> StandaloneHandler[NoPlugin]:
    var server = ApolloServer.from_type_defs(
        SDL, resolvers(), options(), NoPlugin()
    )
    server.start()
    return StandaloneHandler(server^, context)


def _send(
    mut handler: StandaloneHandler[NoPlugin], raw: String
) raises -> ResponseWriter:
    var reader = RequestReader(Limits())
    reader.append(raw.as_bytes())
    _ = reader.next()
    var writer = ResponseWriter()
    writer.begin(reader.request, -1, True)
    handler.handle(reader.request, writer)
    return writer^


def _post(content_type: String, body: String, extra: String = "") -> String:
    return (
        "POST /graphql HTTP/1.1\r\nHost: x\r\nContent-Type: "
        + content_type
        + "\r\n"
        + extra
        + "Content-Length: "
        + String(body.byte_length())
        + "\r\n\r\n"
        + body
    )


def _fields(writer: ResponseWriter) -> String:
    return String(unsafe_from_utf8=writer.headers.data)


def _body(writer: ResponseWriter) -> String:
    return String(unsafe_from_utf8=writer.body)


def test_post() raises:
    var handler = _handler()
    var writer = _send(
        handler, _post("application/json", '{"query":"{ testString }"}')
    )
    assert_equal(writer.status.code, 200)
    assert_equal(
        _fields(writer),
        "Access-Control-Allow-Origin: *\r\ncache-control: no-store\r\n"
        + "content-type: application/json; charset=utf-8\r\n",
    )
    assert_equal(_body(writer), OK)


def test_get_and_head() raises:
    var handler = _handler()
    var writer = _send(
        handler,
        "GET /?query=%7BtestString%7D HTTP/1.1\r\nHost: x\r\n"
        + "apollo-require-preflight: t\r\n\r\n",
    )
    assert_equal(writer.status.code, 200)
    assert_equal(_body(writer), OK)
    writer = _send(
        handler,
        "HEAD / HTTP/1.1\r\nHost: x\r\napollo-require-preflight: t\r\n\r\n",
    )
    assert_equal(writer.status.code, 405)
    assert_true("allow: GET, POST" in _fields(writer))


def test_cors_preflight() raises:
    var handler = _handler()
    var writer = _send(
        handler,
        "OPTIONS / HTTP/1.1\r\nHost: x\r\nOrigin: http://x\r\n"
        + "Access-Control-Request-Method: POST\r\n"
        + "Access-Control-Request-Headers: content-type,x-foo\r\n\r\n",
    )
    assert_equal(writer.status.code, 204)
    assert_equal(
        _fields(writer),
        "Access-Control-Allow-Origin: *\r\n"
        + "Access-Control-Allow-Methods: GET,HEAD,PUT,PATCH,POST,DELETE\r\n"
        + "Vary: Access-Control-Request-Headers\r\n"
        + "Access-Control-Allow-Headers: content-type,x-foo\r\n",
    )
    writer = _send(handler, "OPTIONS / HTTP/1.1\r\nHost: x\r\n\r\n")
    assert_equal(writer.status.code, 204)
    assert_false("Allow-Headers" in _fields(writer))


comptime MISSING = (
    '{"errors":[{"message":"POST body missing, invalid Content-Type, or JSON'
    ' object has no keys.","extensions":{"code":"BAD_REQUEST"}}]}\n'
)
comptime QUERY = '{"query":"{ testString }"}'


def _page(reason: String) -> String:
    return (
        '<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
        "<title>Error</title>\n</head>\n<body>\n<pre>"
        + reason
        + "</pre>\n</body>\n</html>\n"
    )


comptime PAGE_FIELDS = (
    "Access-Control-Allow-Origin: *\r\n"
    "Content-Security-Policy: default-src 'none'\r\n"
    "X-Content-Type-Options: nosniff\r\n"
    "Content-Type: text/html; charset=utf-8\r\n"
)


def test_throws_an_error_if_post_body_is_empty() raises:
    var handler = _handler()
    var writer = _send(handler, _post("application/json", ""))
    assert_equal(writer.status.code, 400)
    assert_equal(_body(writer), MISSING)
    writer = _send(
        handler,
        "POST / HTTP/1.1\r\nHost: x\r\nContent-Type: application/json\r\n\r\n",
    )
    assert_equal(writer.status.code, 400)
    assert_equal(_body(writer), MISSING)


def test_a_body_that_is_not_json() raises:
    var handler = _handler()
    var writer = _send(handler, _post("text/plain", QUERY))
    assert_equal(writer.status.code, 400)
    assert_true("Cross-Site Request Forgery" in _body(writer))
    writer = _send(
        handler,
        "POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 26\r\n\r\n" + QUERY,
    )
    assert_equal(writer.status.code, 400)
    assert_true("Cross-Site Request Forgery" in _body(writer))
    writer = _send(handler, _post("invalid", QUERY))
    assert_equal(writer.status.code, 400)
    assert_equal(_body(writer), MISSING)


def test_throws_an_error_if_post_json_is_malformed() raises:
    var handler = _handler()
    var bodies: List[String] = [
        String('{"query":'),
        String("   "),
        String('"str"'),
    ]
    var index = 0
    while index < len(bodies):
        var writer = _send(handler, _post("application/json", bodies[index]))
        assert_equal(writer.status.code, 400)
        assert_equal(_fields(writer), PAGE_FIELDS)
        assert_equal(_body(writer), _page("Bad Request"))
        index += 1


def test_a_charset_that_is_not_utf_8() raises:
    var handler = _handler()
    var writer = _send(
        handler, _post("application/json; charset=latin1", QUERY)
    )
    assert_equal(writer.status.code, 415)
    assert_equal(_fields(writer), PAGE_FIELDS)
    assert_equal(_body(writer), _page("Unsupported Media Type"))
    writer = _send(
        handler, _post("application/json; charset=UTF-8", " \r\n" + QUERY)
    )
    assert_equal(writer.status.code, 200)
    assert_equal(_body(writer), OK)


def test_chunked_bodies_and_batches() raises:
    var handler = _handler()
    var writer = _send(
        handler,
        "POST / HTTP/1.1\r\nHost: x\r\nContent-Type: application/json\r\n"
        + "Transfer-Encoding: chunked\r\n\r\n1a\r\n"
        + QUERY
        + "\r\n0\r\n\r\n",
    )
    assert_equal(writer.status.code, 200)
    assert_equal(_body(writer), OK)
    writer = _send(handler, _post("application/json", "[]"))
    assert_equal(writer.status.code, 400)
    assert_equal(
        _body(writer),
        '{"errors":[{"message":"Operation batching disabled.","extensions":'
        + '{"code":"BAD_REQUEST"}}]}\n',
    )


def test_request_headers_join_as_node_js_does() raises:
    var raw = String(
        "GET / HTTP/1.1\r\nHost: a\r\nReferer: r\r\nReferer: s\r\n"
        "Cookie: x=1\r\n"
        "X-Foo: 1\r\nCookie: y=2\r\nx-foo: 2\r\nContent-Type: a/b\r\n"
        "content-type: c/d\r\nUser-Agent: u\r\nUser-Agent: v\r\n\r\n"
    )
    var reader = RequestReader(Limits())
    reader.append(raw.as_bytes())
    _ = reader.next()
    var headers = request_headers(reader.request)
    assert_equal(headers.get("referer").value(), "r")
    assert_equal(headers.get("cookie").value(), "x=1; y=2")
    assert_equal(headers.get("x-foo").value(), "1, 2")
    assert_equal(headers.get("content-type").value(), "a/b")
    assert_equal(headers.get("user-agent").value(), "u")
    assert_equal(len(headers), 6)


def test_start_standalone_server() raises:
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.workers = 1
    var server = ApolloServer.from_type_defs(
        SDL, resolvers(), options(), NoPlugin()
    )
    var running = start_standalone_server(server^, config^, context)
    assert_equal(
        running.url, "http://localhost:" + String(running.pool.port) + "/"
    )
    var client = Client()
    var response = client.post(
        "http://127.0.0.1:" + String(running.pool.port) + "/graphql",
        "application/json",
        QUERY,
    )
    assert_equal(response.status.code, 200)
    assert_equal(response.text(), OK)
    client.close_idle()
    assert_equal(running.stop(), 0)


def _incremental_handler[
    P: ServerPlugin
](var plugin: P) raises -> StandaloneHandler[P]:
    var server_options = ApolloServerOptions()
    server_options.node_env = String("test")
    var server = ApolloServer.from_type_defs(
        INCREMENTAL_SDL, incremental_resolvers(), server_options^, plugin^
    )
    server.start()
    return StandaloneHandler(server^, context)


def _send_to[
    P: ServerPlugin
](
    mut handler: StandaloneHandler[P], raw: String, fd: Int
) raises -> ResponseWriter:
    var reader = RequestReader(Limits())
    reader.append(raw.as_bytes())
    _ = reader.next()
    var writer = ResponseWriter()
    writer.begin(reader.request, fd, True)
    handler.handle(reader.request, writer)
    return writer^


def _deferred(query: String, method: String = "POST") -> String:
    var body = '{"query":"' + query + '"}'
    return (
        method
        + " /graphql HTTP/1.1\r\nHost: x\r\nContent-Type: application/json"
        + "\r\nAccept: "
        + ALPHA_9_ACCEPT
        + "\r\nContent-Length: "
        + String(body.byte_length())
        + "\r\n\r\n"
        + body
    )


def test_held_multipart_responses() raises:
    var handler = _incremental_handler(NoPlugin())
    # Two held responses: a stream of three items, and a deferred field.
    var stream = _send_to(handler, _deferred("{ testStrings @stream }"), 7)
    assert_true(stream.held())
    var deferred = _send_to(
        handler, _deferred("{ testString ... @defer { barrierString } }"), 8
    )
    assert_true(deferred.held())
    assert_true(deferred.chunked())
    var out = List[UInt8]()
    assert_equal(handler.poll_body(8, out), BodyPoll.DONE)
    assert_true(
        String(unsafe_from_utf8=out).endswith(
            '"completed":[{"id":"0"}]}\r\n-----\r\n'
        )
    )
    # The stream is not ready at once; then it gives one part.
    out.clear()
    var polled = handler.poll_body(7, out)
    var turns = 0
    while polled == BodyPoll.PENDING and turns < 100:
        polled = handler.poll_body(7, out)
        turns += 1
    assert_equal(polled, BodyPoll.READY)
    assert_true('"items":["it works"]' in String(unsafe_from_utf8=out))
    # A client that goes away closes the results; the id is forgotten.
    handler.body_closed(7)
    handler.body_closed(7)
    out.clear()
    assert_equal(handler.poll_body(7, out), BodyPoll.DONE)
    assert_equal(len(out), 0)
    # A HEAD request gets 405 and no parts, so it is not held.
    var head = _send_to(
        handler,
        _deferred("{ testString ... @defer { barrierString } }", "HEAD"),
        9,
    )
    assert_equal(head.status.code, 405)
    assert_false(head.held())
    assert_equal(len(handler.held_ids), 0)


def test_held_response_whose_hook_raises() raises:
    var handler = _incremental_handler(
        Recorder("", "willSendSubsequentPayload")
    )
    var writer = _send_to(
        handler, _deferred("{ testString ... @defer { barrierString } }"), 7
    )
    assert_true(writer.held())
    var out = List[UInt8]()
    assert_equal(handler.poll_body(7, out), BodyPoll.ERROR)
    assert_equal(len(handler.held_ids), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
