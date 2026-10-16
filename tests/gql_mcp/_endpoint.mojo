# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A stub GraphQL endpoint for the gql_mcp suites, in a worker process.

It stands in for the mockito servers of the upstream tests. Each path
gives one fixed response; `/echo` answers with the request it got.
"""

from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, WorkerPool
from gql_http.server import start_workers
from gql_http.socket import IPv4Address
from gql_http.status import Status
from gql_json.writer import JsonWriter


struct Endpoint(Handler):
    """Answers each path with a fixed GraphQL response."""

    def __init__(out self):
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        var path = request.path()
        var body: String
        if path == "/invalid":
            body = "{ \"invalid_json\": 'foo' }"
        elif path == "/errors":
            body = '{"data":null,"errors":["an error"]}'
        elif path == "/partial":
            body = '{"data":{"createUsers":null},"errors":["a resolver error"]}'
        elif path == "/numbers":
            body = '{"a":1.0,"b":1e5,"c":-0,"d":12,"a":2.5,"e":null}'
        elif path == "/huge":
            body = '{"x":1e400}'
        elif path == "/null-errors":
            body = '{"data":{},"errors":null}'
        elif path == "/array":
            body = "[1]"
        elif path == "/status":
            response.send(
                Status.INTERNAL_SERVER_ERROR, "application/json", "{}"
            )
            return
        else:
            var writer = JsonWriter()
            writer.begin_object()
            writer.key("data")
            writer.begin_object()
            writer.key("target")
            writer.string(request.target())
            var index = 0
            while index < request.header_count():
                writer.key(request.header_name(index))
                writer.string(request.header_value(index))
                index += 1
            writer.key("body")
            writer.string(StringSlice(unsafe_from_utf8=request.body()))
            writer.end_object()
            writer.end_object()
            body = writer^.take_string()
        response.send(Status.OK, "application/json", body)


def start_endpoint() raises -> WorkerPool:
    """Start the stub in one worker process on a free loopback port.

    Returns:
        The pool; its `port` is the endpoint's port.
    """
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    return start_workers(Endpoint(), config)
