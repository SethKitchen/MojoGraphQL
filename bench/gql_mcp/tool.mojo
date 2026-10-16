# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the MCP tool of one large operation.

    mojo build -I . -o .cache/bin/tool bench/gql_mcp/tool.mojo
    .cache/bin/tool

`mcp/tool-from-operation-large`: `Operation.from_raw` of
`bench/fixtures/mcp-large-operation.graphql` against
`bench/fixtures/github-schema.graphql`, as the server does for each
operation file: parse the operation, tree-shake the schema for the
description, and build the JSON Schemas of the variables and of the result.
The output schema is on. The baseline in `bench/baselines/rust-mcp` times
upstream `Operation::from_raw` with the same arguments. The method is the
one of every benchmark: a warm-up of at least 200 ms, then the fastest of 5
rounds of at least one second each.
"""

from std.time import perf_counter_ns

from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.operation import Operation, RawOperation
from gql_mcp.tool import AnnotationOverrides, MutationMode
from gql_schema.build import build_schema
from gql_schema.definition import Schema


def _once(text: String, schema: Schema) raises -> Int:
    """Make the tool of the operation once."""
    var operation = Operation.from_raw(
        RawOperation(text.copy(), None),
        schema,
        CustomScalarMap(),
        MutationMode.NONE,
        False,
        False,
        True,
        Dict[String, AnnotationOverrides](),
        Dict[String, String](),
    )
    if not operation:
        raise Error("the operation is not a query")
    return operation.value().tool.name.byte_length()


def _run(iterations: Int, text: String, schema: Schema) raises -> Int:
    """Make the tool `iterations` times, and return the elapsed time."""
    var start = perf_counter_ns()
    var sink = 0
    for _ in range(iterations):
        sink += _once(text, schema)
    var elapsed = Int(perf_counter_ns() - start)
    if sink != iterations * 21:
        raise Error("unexpected tool name")
    return elapsed


def main() raises:
    """Run the workload and print its `BENCH` line."""
    var sdl: String
    with open("bench/fixtures/github-schema.graphql", "r") as file:
        sdl = file.read()
    var schema = build_schema(sdl)
    var text: String
    with open("bench/fixtures/mcp-large-operation.graphql", "r") as file:
        text = file.read()
    var iterations = 1
    while True:
        var elapsed = _run(iterations, text, schema)
        if elapsed >= 200_000_000:
            iterations = max(1_000_000_000 // max(elapsed // iterations, 1), 1)
            break
        iterations *= 2
    var best = Float64(1e300)
    for _ in range(5):
        var elapsed = _run(iterations, text, schema)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print(
        "BENCH mcp/tool-from-operation-large", Float64(Int(best * 10.0)) / 10.0
    )
