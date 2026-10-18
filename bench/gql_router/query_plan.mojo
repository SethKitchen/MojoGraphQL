# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time the query planner on the Hive Router benchmark operation.

    mojo build -I . -o .cache/bin/query_plan bench/gql_router/query_plan.mojo
    .cache/bin/query_plan

The program prints `BENCH hive-router/query_plan <ns per op>`, which
`tools/bench.mojo` reads. The workload is `query_plan` of Hive Router
`1a29df9` `bin/router/benches/qp_benches.rs`: the supergraph state, the
graph and the normalized `TestQuery` are built once, and each operation
walks the operation, finds the best combination, builds and optimizes the
fetch graph, and builds the query plan. The baseline in
`bench/baselines/rust-router` runs the same steps of upstream Hive Router.
The fixtures are upstream `bench/supergraph.graphql` and
`bench/operation.graphql`.

The timing method is the one of `bench/gql_json/json.mojo`: warm up, then
rounds of at least `ROUND_NS` each, and report the fastest round.
"""

from std.benchmark import keep
from std.pathlib import Path
from std.time import perf_counter_ns

from gql_router.operation import OperationDefinition
from gql_router.planner import Planner

comptime FIXTURES = "bench/fixtures/hive-router-qp/"
"""The directory of the fixtures, from the repository root."""
comptime ROUND_NS = 1_000_000_000
"""The shortest round, in nanoseconds."""
comptime ROUNDS = 5
"""How many timed rounds the workload runs."""
comptime WARMUP_NS = 200_000_000
"""How long the workload warms up, in nanoseconds."""


def _run(
    mut planner: Planner, operation: OperationDefinition, iterations: Int
) raises -> Int:
    """Plan an operation a number of times.

    Args:
        planner: The planner.
        operation: The normalized operation.
        iterations: How many times to plan.

    Returns:
        The elapsed time in nanoseconds.

    Raises:
        Error: If planning fails.
    """
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        var mark = planner.store.mark()
        var plan = planner.plan(operation)
        sink += len(plan.nodes)
        planner.store.rollback(mark)
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def main() raises:
    """Run the `query_plan` workload."""
    var sdl = Path(FIXTURES + "supergraph.graphql").read_text()
    var query = Path(FIXTURES + "operation.graphql").read_text()
    var planner = Planner(sdl)
    var operation = planner.normalize(query, String("TestQuery"))
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _run(planner, operation, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            iterations = max(ROUND_NS // per_op, 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _run(planner, operation, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH", "hive-router/query_plan", Float64(Int(best * 10.0)) / 10.0)
