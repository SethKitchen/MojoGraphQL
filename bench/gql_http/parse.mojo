# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time `parse_request_head` on a typical GraphQL POST from a browser.

    mojo build -I . -o .cache/bin/http_parse bench/gql_http/parse.mojo
    .cache/bin/http_parse

`http/parse-request`: one op parses the request line and the 14 fields,
checks them, and finds the framing of the content (`Content-Length`). The
`Request` is reused, as the server reuses it. The baselines run httparse
(Rust), llhttp through `node:_http_common` (Node.js) and `http.ReadRequest`
(Go) on the same bytes, with the same method: a warm-up, then the fastest
of 5 rounds of at least one second each.
"""

from std.benchmark import keep
from std.time import perf_counter_ns

from gql_http.parser import Limits, ParseState, Request, parse_request_head

comptime REQUEST = (
    "POST /graphql HTTP/1.1\r\n"
    "Host: localhost:4000\r\n"
    "Connection: keep-alive\r\n"
    "Content-Length: 126\r\n"
    'sec-ch-ua: "Chromium";v="128", "Not;A=Brand";v="24"\r\n'
    "accept: application/graphql-response+json, application/json\r\n"
    "content-type: application/json\r\n"
    "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML,"
    " like Gecko) Chrome/128.0.0.0 Safari/537.36\r\n"
    "Origin: http://localhost:4000\r\n"
    "Sec-Fetch-Site: same-origin\r\n"
    "Sec-Fetch-Mode: cors\r\n"
    "Referer: http://localhost:4000/\r\n"
    "Accept-Encoding: gzip, deflate, br\r\n"
    "Accept-Language: en-US,en;q=0.9\r\n"
    "\r\n"
    '{"query":"query Hero($episode: Episode) { hero(episode: $episode) {'
    ' name friends { name } } }","variables":{"episode":"JEDI"}}'
)
"""The request, the same bytes as in the baselines."""
comptime ROUND_NS = 1_000_000_000
"""The shortest round, in nanoseconds."""
comptime ROUNDS = 5
"""How many timed rounds the workload runs."""
comptime WARMUP_NS = 200_000_000
"""How long the workload warms up, in nanoseconds."""


def _run(
    data: List[UInt8], mut request: Request, iterations: Int
) raises -> Int:
    """Parse the request a number of times; return the nanoseconds.

    Args:
        data: The bytes of the request.
        request: The request to fill.
        iterations: How many times to parse.

    Returns:
        The elapsed time.

    Raises:
        Error: If the request does not parse.
    """
    var limits = Limits()
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        var result = parse_request_head(
            data.unsafe_ptr(), len(data), limits, request
        )
        if result.state != ParseState.COMPLETE:
            raise Error("the request did not parse")
        sink += result.size + request.content_length
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def main() raises:
    """Run the workload and print its `BENCH` line."""
    var data = List[UInt8](StaticString(REQUEST).as_bytes())
    var request = Request()
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _run(data, request, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            iterations = max(ROUND_NS // per_op, 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _run(data, request, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH http/parse-request", Float64(Int(best * 10.0)) / 10.0)
