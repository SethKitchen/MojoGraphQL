# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the gql_http server under the load of `_loadgen.mojo`.

    mojo build -I . -o .cache/bin/http bench/gql_http/http.mojo
    .cache/bin/http

`http/keepalive-small-json`: one worker process answers each small GraphQL
POST with `{"data":{"hello":"world"}}`, over 64 keep-alive connections.
The number is nanoseconds per request: the inverse of the throughput. The
baselines in `bench/baselines/js-http`, `go-http` and `rust-http` run their
servers with one thread under the same load generator.
"""

from _loadgen import RESPONSE_BODY, run_load
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, start_workers
from gql_http.socket import IPv4Address


@fieldwise_init
struct Hello(Handler):
    """Answers every request with the same small JSON response."""

    var requests: Int
    """How many requests the worker answered."""

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Write the JSON response.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: Never; the content type is valid.
        """
        self.requests += 1
        response.add_header("Content-Type", "application/json")
        response.write_text(RESPONSE_BODY)


def main() raises:
    """Start one worker, load it, and stop it."""
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.workers = 1
    var pool = start_workers(Hello(0), config)
    try:
        run_load("http/keepalive-small-json", pool.port)
    except e:
        _ = pool.stop(1000)
        raise e^
    _ = pool.stop(3000)
