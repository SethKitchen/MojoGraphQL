# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the QPACK encoder and decoder on the header fields of a GraphQL
request over HTTP/3, and of its response.

    mojo build -I . -o .cache/bin/h3_qpack bench/gql_http3/qpack.mojo
    .cache/bin/h3_qpack

`qpack/encode-request`: one op encodes the 14 request fields into a field
section with the static table and literals (table capacity 0, as h3 runs
its connections). `qpack/decode-request`: one op decodes that section into
a reused `FieldList`. The `-response` workloads do the same for 8 response
fields. The baseline in `bench/baselines/rust-http3` runs h3's
`encode_stateless` and `decode_stateless` on the same fields, with the same
method: a warm-up, then the fastest of 5 rounds of at least one second
each.
"""

from std.benchmark import keep
from std.time import perf_counter_ns

from gql_http3.qpack import FieldList, QpackDecoder, QpackEncoder

comptime ROUND_NS = 1_000_000_000
"""The shortest round, in nanoseconds."""
comptime ROUNDS = 5
"""How many timed rounds a workload runs."""
comptime WARMUP_NS = 200_000_000
"""How long a workload warms up, in nanoseconds."""


def request_fields() -> FieldList:
    """Return the fields of a GraphQL POST from a browser.

    Returns:
        The 14 fields, the same as in the baseline.
    """
    var f = FieldList()
    f.add_text(":method", "POST")
    f.add_text(":scheme", "https")
    f.add_text(":authority", "api.example.com")
    f.add_text(":path", "/graphql")
    f.add_text("content-type", "application/json")
    f.add_text("accept", "application/graphql-response+json, application/json")
    f.add_text(
        "user-agent",
        (
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like"
            " Gecko) Chrome/128.0.0.0 Safari/537.36"
        ),
    )
    f.add_text("content-length", "126")
    f.add_text("origin", "https://app.example.com")
    f.add_text("referer", "https://app.example.com/")
    f.add_text("accept-encoding", "gzip, deflate, br")
    f.add_text("accept-language", "en-US,en;q=0.9")
    f.add_text("sec-fetch-mode", "cors")
    f.add_text("sec-fetch-site", "same-site")
    return f^


def response_fields() -> FieldList:
    """Return the fields of the response.

    Returns:
        The 8 fields, the same as in the baseline.
    """
    var f = FieldList()
    f.add_text(":status", "200")
    f.add_text(
        "content-type", "application/graphql-response+json; charset=utf-8"
    )
    f.add_text("content-length", "1534")
    f.add_text("date", "Sun, 18 Oct 2026 12:00:00 GMT")
    f.add_text("cache-control", "no-store")
    f.add_text("vary", "accept-encoding")
    f.add_text("access-control-allow-origin", "https://app.example.com")
    f.add_text("server", "MojoGraphQL")
    return f^


def _encode(fields: FieldList, iterations: Int) -> Int:
    """Encode the fields a number of times; return the nanoseconds."""
    var encoder = QpackEncoder()
    var block = List[UInt8](capacity=1024)
    var stream = List[UInt8]()
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        block.clear()
        _ = encoder.encode(0, fields, block, stream)
        sink += len(block)
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def _decode(block: List[UInt8], iterations: Int) raises -> Int:
    """Decode the section a number of times; return the nanoseconds."""
    var decoder = QpackDecoder()
    var fields = FieldList(1024)
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        if not decoder.decode(0, Span(block), fields):
            raise Error("the section blocked")
        sink += fields.count()
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def _time(name: StaticString, fields: FieldList, decode: Bool) raises:
    """Warm up, run the rounds, and print the `BENCH` line."""
    var block = List[UInt8]()
    var stream = List[UInt8]()
    var encoder = QpackEncoder()
    _ = encoder.encode(0, fields, block, stream)
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _decode(block, iterations) if decode else _encode(
            fields, iterations
        )
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            iterations = max(ROUND_NS // per_op, 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _decode(block, iterations) if decode else _encode(
            fields, iterations
        )
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def main() raises:
    """Run the four workloads and print their `BENCH` lines."""
    var request = request_fields()
    var response = response_fields()
    _time("qpack/encode-request", request, False)
    _time("qpack/decode-request", request, True)
    _time("qpack/encode-response", response, False)
    _time("qpack/decode-response", response, True)
