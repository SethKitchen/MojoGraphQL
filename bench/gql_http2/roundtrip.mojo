# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the gql_http2 server under the load of `_h2load.mojo`.

    mojo build -I . -o .cache/bin/roundtrip bench/gql_http2/roundtrip.mojo
    .cache/bin/roundtrip

`http2/roundtrip-small-json`: one worker process answers each small
GraphQL `POST` with `{"data":{"hello":"world"}}` over one h2c connection
that stays open, one stream at a time. The number is nanoseconds per
round trip. The baseline in `bench/baselines/rust-http2` runs hyper with
h2 on a tokio runtime with one thread, under the same load generator.
"""

from _h2load import RESPONSE_BODY, run_load
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import IPv4Address
from gql_http2.server import ServerConfig, start_workers


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
    config.http.host = IPv4Address.LOOPBACK
    config.http.port = 0
    config.http.workers = 1
    var pool = start_workers(Hello(0), config)
    try:
        run_load("http2/roundtrip-small-json", pool.port)
    except e:
        _ = pool.stop(1000)
        raise e^
    _ = pool.stop(3000)
