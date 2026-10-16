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
from gql_server.plugin import NoPlugin
from gql_server.server import ApolloServer
from gql_server.standalone import (
    StandaloneHandler,
    request_headers,
    start_standalone_server,
)

comptime OK = '{"data":{"testString":"it works"}}\n'
"""The content of `{ testString }`."""


def _handler() raises -> StandaloneHandler[NoPlugin]:
    var server = ApolloServer.from_type_defs(SDL, resolvers(), options(), NoPlugin())
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
    var writer = _send(handler, _post("application/json", '{"query":"{ testString }"}'))
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
        handler, "HEAD / HTTP/1.1\r\nHost: x\r\napollo-require-preflight: t\r\n\r\n"
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
