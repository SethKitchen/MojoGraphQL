# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time `parse` and `stringify` on the JSON benchmark fixtures.

    mojo build -I . -o .cache/bin/json bench/gql_json/json.mojo
    .cache/bin/json

The program prints one line per workload, `BENCH <workload> <ns per op>`,
which `tools/bench.mojo` reads. Each workload warms up, then runs rounds of
at least `ROUND_NS` nanoseconds each, and reports the fastest round. The
baselines in `bench/baselines/js-json`, `go-json` and `rust-json` use the
same method and the same workloads:

- `json/parse-introspection`: parse `github-schema.json`, the graphql-js
  16.14.2 introspection result of the GitHub schema (1.8 MB).
- `json/stringify-introspection`: write that parsed value as compact JSON.
- `json/parse-small-response` and `json/stringify-small-response`: the
  same for `small-response.json`, a typical 2 KB GraphQL response.
- `json/parse-variables`: parse `variables.json`, the variables of a
  request.

A parse starts from the text in memory and makes a new document. A
stringify starts from a parsed document and makes new UTF-8 bytes
(`stringify_bytes`), as `serde_json::to_vec` and astjson `MarshalTo` do.
"""

from std.benchmark import keep
from std.pathlib import Path
from std.time import perf_counter_ns

from gql_json.parser import parse
from gql_json.value import JsonDocument
from gql_json.writer import stringify_bytes

comptime FIXTURES = "bench/fixtures/"
"""The directory of the fixtures, from the repository root."""
comptime ROUND_NS = 1_000_000_000
"""The shortest round, in nanoseconds."""
comptime ROUNDS = 5
"""How many timed rounds each workload runs."""
comptime WARMUP_NS = 200_000_000
"""How long each workload warms up, in nanoseconds."""
comptime PARSE = 0
"""The workload selector for a parse."""
comptime STRINGIFY = 1
"""The workload selector for a stringify."""


def _once(work: Int, text: StringSlice, document: JsonDocument) raises -> Int:
    """Run one operation.

    Args:
        work: `PARSE` or `STRINGIFY`.
        text: The JSON text, for a parse.
        document: The parsed text, for a stringify.

    Returns:
        A number from the result, so the work cannot be optimized away.

    Raises:
        Error: If the text is not valid JSON.
    """
    if work == PARSE:
        try:
            var parsed = parse(text)
            return len(parsed.nodes)
        except e:
            raise Error(String(e))
    return len(stringify_bytes(document, document.root))


def _run(
    work: Int, text: StringSlice, document: JsonDocument, iterations: Int
) raises -> Int:
    """Run an operation a number of times.

    Args:
        work: `PARSE` or `STRINGIFY`.
        text: The JSON text.
        document: The parsed text.
        iterations: How many times to run.

    Returns:
        The elapsed time in nanoseconds.

    Raises:
        Error: If the text is not valid JSON.
    """
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        sink += _once(work, text, document)
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def measure(name: StringSlice, work: Int, text: StringSlice) raises:
    """Time one workload and print its `BENCH` line.

    Args:
        name: The workload name, such as `json/parse-introspection`.
        work: `PARSE` or `STRINGIFY`.
        text: The JSON text.

    Raises:
        Error: If the text is not valid JSON.
    """
    var document: JsonDocument
    try:
        document = parse(text)
    except e:
        raise Error(String(e))
    # Warm up, and find how many iterations fill a round.
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _run(work, text, document, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            iterations = max(ROUND_NS // per_op, 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _run(work, text, document, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def main() raises:
    """Run every JSON workload."""
    var introspection = Path(FIXTURES + "github-schema.json").read_text()
    var small = Path(FIXTURES + "small-response.json").read_text()
    var variables = Path(FIXTURES + "variables.json").read_text()
    measure("json/parse-introspection", PARSE, introspection)
    measure("json/stringify-introspection", STRINGIFY, introspection)
    measure("json/parse-small-response", PARSE, small)
    measure("json/stringify-small-response", STRINGIFY, small)
    measure("json/parse-variables", PARSE, variables)
