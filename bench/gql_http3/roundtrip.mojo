# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time an HTTP/3 request round trip over localhost UDP.

    mojo build -I . -o .cache/bin/h3rt bench/gql_http3/roundtrip.mojo
    .cache/bin/h3rt

`h3/roundtrip-small-json`: an `H3Server` in a child process answers each
small GraphQL POST with `{"data":{"hello":"world"}}`. One `H3Client` sends
the requests one after another on one QUIC connection, after the
handshake. The number is nanoseconds per request. The baseline in
`bench/baselines/rust-http3` runs h3, h3-quinn and quinn the same way.
"""

from std.time import perf_counter_ns

from _certs import test_certs
from gql_http.client import ClientConfig
from gql_http.headers import Headers
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_http.status import Method
from gql_tls.openssl import OpenSsl
from gql_http3.client import H3Client
from gql_http3.quic import Quic, QuicContext
from gql_http3.server import H3Config, listen_h3

comptime REQUEST_BODY = '{"query":"{ hello }"}'
"""The content of each request."""
comptime RESPONSE_BODY = '{"data":{"hello":"world"}}'
"""The content of each response."""
comptime WARMUP = 200
"""The requests before the timing."""
comptime REQUESTS = 5000
"""The timed requests."""


struct Hello(Handler):
    """Answers every request with the same small JSON response."""

    def __init__(out self):
        """Make the handler."""
        pass

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Write the JSON response.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: Never; the content type is valid.
        """
        response.add_header("Content-Type", "application/json")
        response.write_text(RESPONSE_BODY)


def main() raises:
    """Start the server in a child, time the requests, and stop it."""
    var certs = test_certs()
    var config = H3Config()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    var server = listen_h3(
        Hello(), certs.cert, certs.key, config, Quic(OpenSsl())
    )
    var sys = Sys()
    var pid = sys.fork()
    if pid == 0:
        _ = sys.die_with_parent()
        try:
            server.run()
        except:
            pass
        sys.exit_now(0)
    var port = server.port
    server.close()
    var settings = ClientConfig()
    settings.timeout_ms = 5000
    var context = QuicContext.client(Quic(OpenSsl()), certs.cert)
    var client = H3Client(context^, settings)
    var url = "https://localhost:" + String(port) + "/graphql"
    # Resolve once, as the baseline connects once: getaddrinfo per request
    # would cost more than the HTTP/3 framing.
    var endpoint = client.endpoint(url)
    var headers = Headers()
    headers.add("Content-Type", "application/json")
    var body = List[UInt8](REQUEST_BODY.as_bytes())
    var index = 0
    var start = perf_counter_ns()
    while index < WARMUP + REQUESTS:
        if index == WARMUP:
            start = perf_counter_ns()
        var response = client.send(
            endpoint, Method.POST, "/graphql", headers, body
        )
        if response.status.code != 200:
            raise Error("unexpected status")
        index += 1
    var elapsed = Int(perf_counter_ns() - start)
    print("BENCH h3/roundtrip-small-json", elapsed // REQUESTS)
    client.close()
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)
