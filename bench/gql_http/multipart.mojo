# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time `MultipartDecoder` on a `multipart/mixed` body of incremental
delivery.

    mojo build -I . -o .cache/bin/http_multipart bench/gql_http/multipart.mojo
    .cache/bin/http_multipart

`multipart/parse-100-parts`: a new decoder of the boundary `-` reads one
body of 100 parts, each a JSON subsequent payload of `@defer`, and the
close delimiter. The JSON of each part is parsed, as meros parses each
`application/json` part. The baseline is meros 1.3.2 (Node.js) on the same
bytes, in `bench/baselines/js-sse`, with the same method: a warm-up, then
the fastest of 5 rounds of at least one second each.
"""

from std.benchmark import keep
from std.time import perf_counter_ns

from gql_http.multipart import MultipartDecoder, MultipartEncoder
from gql_json.parser import parse

comptime ROUNDS = 5
"""How many rounds are timed."""
comptime ROUND_NS = 1_000_000_000
"""The least length of a round, in nanoseconds."""
comptime WARMUP_NS = 500_000_000
"""How long a workload warms up, in nanoseconds."""
comptime PARTS = 100
"""The parts of the body."""
comptime PART = (
    '{"incremental":[{"id":"0","data":{"name":"Luke"}}],'
    '"completed":[{"id":"0"}],"hasNext":true}'
)
"""The body of each part."""


def body() raises -> List[UInt8]:
    """The content: `PARTS` JSON parts and the close delimiter."""
    var out = List[UInt8]()
    var encoder = MultipartEncoder()
    for _ in range(PARTS):
        encoder.part(out, StaticString(PART).as_bytes())
    encoder.end(out)
    return out^


def run(content: List[UInt8], iterations: Int) raises -> Int:
    """Decode the content a number of times; return the nanoseconds."""
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        var decoder = MultipartDecoder()
        _ = decoder.feed(content)
        decoder.finish()
        var parts = decoder.take()
        for index in range(len(parts)):
            var json = parse(parts[index].text())
            sink += json.root
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def main() raises:
    """Run the workload and print its `BENCH` line."""
    var content = body()
    var check = MultipartDecoder()
    if check.feed(content) != PARTS:
        raise Error("the decoder read the wrong count of parts")
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = run(content, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            iterations = max(ROUND_NS // max(elapsed // iterations, 1), 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = run(content, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH multipart/parse-100-parts", Float64(Int(best * 10.0)) / 10.0)
