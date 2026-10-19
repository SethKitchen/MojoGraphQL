# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time one HTTP/2 over TLS round trip between `Https2Client` and
`listen_https2`.

    mojo build -I . -o .cache/bin/https2 bench/gql_https2/roundtrip.mojo
    .cache/bin/https2

`https2/roundtrip-small-json`: a server in a child process answers each
small GraphQL POST to `/graphql` with `{"data":{"hello":"world"}}`. The
client in this process sends the requests one after the other, one stream
at a time, on one TLS 1.3 connection with ALPN `h2`, which it verifies
against the certificate in `bench/fixtures/tls/`. The handshake is outside
the timer. The number is nanoseconds per round trip: the best of `ROUNDS`
rounds of `REQUESTS` requests. The baseline in `bench/baselines/rust-tls`
runs hyper with h2 and rustls on both ends, each on its own thread, under
the same workload.
"""

from std.time import perf_counter_ns

from gql_http.client import ClientConfig
from gql_http.headers import Headers
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig
from gql_http.socket import IPv4Address, SIGKILL, Sys
from gql_http.status import Method
from gql_http2.client import Protocol
from gql_tls.context import TlsContext
from gql_tls.openssl import OpenSsl
from gql_https2.client import Https2Client
from gql_https2.server import listen_https2

comptime CERT = "bench/fixtures/tls/cert.pem"
"""The certificate of `localhost`, which the client trusts."""
comptime KEY = "bench/fixtures/tls/key.pem"
"""The private key of `CERT`."""
comptime QUERY = '{"query":"{ hello }"}'
"""The content of each request."""
comptime ANSWER = '{"data":{"hello":"world"}}'
"""The content of each response."""
comptime WARMUP = 2000
"""The round trips before the first round."""
comptime REQUESTS = 20000
"""The round trips of a round."""
comptime ROUNDS = 5
"""How many rounds run."""


@fieldwise_init
struct Hello(Handler):
    """Answers every request with the same small JSON response."""

    var requests: Int
    """How many requests the server answered."""

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
        response.write_text(ANSWER)


def start_server() raises -> Tuple[Int, Int]:
    """Run the HTTP/2 over TLS server in a child process.

    Returns:
        The process id and the port of the server.

    Raises:
        Error: When the server cannot start.
    """
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.reuse_port = False
    var context = TlsContext.server(OpenSsl(), CERT, KEY)
    var server = listen_https2(Hello(0), context^, config)
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
    return (pid, port)


def round_trips(mut client: Https2Client, url: String, count: Int) raises:
    """Send `count` requests, and check each response.

    Args:
        client: The client.
        url: The URL of the server.
        count: How many requests to send.

    Raises:
        Error: When a request fails or a response is wrong.
    """
    # The host resolves once, as a connection of the baseline does.
    var endpoint = client.endpoint(url)
    var target = endpoint.target.copy()
    var headers = Headers()
    headers.add("Content-Type", "application/json")
    var body = StaticString(QUERY).as_bytes()
    var index = 0
    while index < count:
        var response = client.send(endpoint, Method.POST, target, headers, body)
        if response.protocol != Protocol.HTTP_2 or response.text() != ANSWER:
            raise Error("unexpected response: " + response.text())
        index += 1


def measure(url: String) raises -> Float64:
    """Connect, warm up, and time the rounds.

    Args:
        url: The URL of the server.

    Returns:
        The best time of a round trip, in nanoseconds.

    Raises:
        Error: When a request fails or a response is wrong.
    """
    var client = Https2Client.create(
        OpenSsl(), CERT, True, True, ClientConfig()
    )
    round_trips(client, url, WARMUP)
    var best = Float64(1e18)
    var round = 0
    while round < ROUNDS:
        var start = perf_counter_ns()
        round_trips(client, url, REQUESTS)
        var took = Float64(Int(perf_counter_ns() - start)) / REQUESTS
        best = min(best, took)
        round += 1
    return best


def main() raises:
    """Start the server, time the round trips, and stop the server.

    Raises:
        Error: When the server cannot start, or a round trip fails.
    """
    var server = start_server()
    var pid = server[0]
    var url = "https://localhost:" + String(server[1]) + "/graphql"
    var sys = Sys()
    var best: Float64
    try:
        best = measure(url)
    except e:
        _ = sys.kill(pid, SIGKILL)
        _ = sys.wait(pid, True)
        raise e^
    _ = sys.kill(pid, SIGKILL)
    _ = sys.wait(pid, True)
    print("BENCH https2/roundtrip-small-json", Float64(Int(best * 10.0)) / 10.0)
