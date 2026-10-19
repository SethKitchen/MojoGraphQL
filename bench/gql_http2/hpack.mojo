# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time HPACK on the header block of a typical GraphQL request.

    mojo build -I . -o .cache/bin/http2_hpack bench/gql_http2/hpack.mojo
    .cache/bin/http2_hpack

The block has these 14 fields, in this order. The baselines must use the
same fields:

    :method: POST
    :scheme: http
    :authority: localhost:4000
    :path: /graphql
    content-type: application/json
    accept: application/graphql-response+json, application/json
    user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
        (KHTML, like Gecko) Chrome/126.0 Safari/537.36   (one line)
    accept-encoding: gzip, deflate, br
    accept-language: en-US,en;q=0.9
    origin: http://localhost:3000
    referer: http://localhost:3000/
    apollo-require-preflight: true
    x-request-id: 3f2b9c1e-8d4a-4b6f-9e2d-1a7c5b8e0f34
    content-length: 64

Each op works on a cold block: the first block of a connection, with an
empty dynamic table.

`http2/hpack-encode`: one op makes a new `Encoder` and encodes the 14
fields into a block. 2 fields are static table indexes; the others are
Huffman literals, and 10 of them go into the dynamic table. The block
buffer is reused.

`http2/hpack-decode`: one op makes a new `Decoder` and decodes that block
into a `HeaderList`, Huffman strings and table insertions included. The
list is reused.

The result is nanoseconds per header block, with the method of the other
benchmarks: a warm-up, then the fastest of 5 rounds of at least one
second each.
"""

from std.benchmark import keep
from std.time import perf_counter_ns

from gql_http2.hpack import Decoder, Encoder, HeaderList

comptime ROUND_NS = 1_000_000_000
"""The shortest round, in nanoseconds."""
comptime ROUNDS = 5
"""How many timed rounds a workload runs."""
comptime WARMUP_NS = 200_000_000
"""How long a workload warms up, in nanoseconds."""
comptime MAX_LIST_SIZE = 16384
"""The list size limit of the decoder."""


def _fields() -> HeaderList:
    """Return the fields of the request, the same as in the baselines.

    Returns:
        The 14 fields.
    """
    var fields = HeaderList()
    fields.add_text(":method", "POST")
    fields.add_text(":scheme", "http")
    fields.add_text(":authority", "localhost:4000")
    fields.add_text(":path", "/graphql")
    fields.add_text("content-type", "application/json")
    fields.add_text(
        "accept", "application/graphql-response+json, application/json"
    )
    fields.add_text(
        "user-agent",
        (
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like"
            " Gecko) Chrome/126.0 Safari/537.36"
        ),
    )
    fields.add_text("accept-encoding", "gzip, deflate, br")
    fields.add_text("accept-language", "en-US,en;q=0.9")
    fields.add_text("origin", "http://localhost:3000")
    fields.add_text("referer", "http://localhost:3000/")
    fields.add_text("apollo-require-preflight", "true")
    fields.add_text("x-request-id", "3f2b9c1e-8d4a-4b6f-9e2d-1a7c5b8e0f34")
    fields.add_text("content-length", "64")
    return fields^


def _encode(fields: HeaderList, mut out: List[UInt8], iterations: Int) -> Int:
    """Encode the fields with new encoders; return the nanoseconds.

    Args:
        fields: The fields.
        out: The block buffer, which each op clears.
        iterations: How many times to encode.

    Returns:
        The elapsed time.
    """
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        var encoder = Encoder()
        out.clear()
        encoder.encode(fields, out)
        sink += len(out) + encoder.table.count()
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def _decode(
    block: List[UInt8], mut out: HeaderList, iterations: Int
) raises -> Int:
    """Decode the cold block with new decoders; return the nanoseconds.

    Args:
        block: The cold block.
        out: The list, which each op clears.
        iterations: How many times to decode.

    Returns:
        The elapsed time.

    Raises:
        HpackError: If the block does not decode.
    """
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        var decoder = Decoder()
        out.clear()
        decoder.decode(Span(block), MAX_LIST_SIZE, out)
        sink += out.count() + decoder.table.count()
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def _report(name: StaticString, best: Float64):
    """Print one `BENCH` line.

    Args:
        name: The workload.
        best: The fastest time per op, in nanoseconds.
    """
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def _iterations(per_op: Int) -> Int:
    """Return how many ops make one round.

    Args:
        per_op: The nanoseconds of one op in the warm-up.

    Returns:
        The count, at least 1.
    """
    return max(ROUND_NS // max(per_op, 1), 1)


def main() raises:
    """Run both workloads and print their `BENCH` lines."""
    var fields = _fields()
    var block = List[UInt8]()
    var encoder = Encoder()
    encoder.encode(fields, block)
    var list = HeaderList()
    var decoder = Decoder()
    decoder.decode(Span(block), MAX_LIST_SIZE, list)
    if list.count() != fields.count():
        raise Error("the block did not decode")

    var out = List[UInt8]()
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _encode(fields, out, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            iterations = _iterations(elapsed // iterations)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _encode(fields, out, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    if out != block:
        raise Error("the cold block changed")
    _report("http2/hpack-encode", best)

    iterations = 1
    warm = 0
    while True:
        var elapsed = _decode(block, list, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            iterations = _iterations(elapsed // iterations)
            break
        iterations *= 2
    best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _decode(block, list, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    _report("http2/hpack-decode", best)
