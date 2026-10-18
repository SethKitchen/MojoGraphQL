# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The timing method of the gql_seamstress benchmarks.

The method is the one of every benchmark of the project: a warm-up of at
least 200 ms, then the fastest of 5 rounds of at least one second each.
"""

from std.benchmark import keep
from std.time import perf_counter_ns

comptime ROUND_NS = 1_000_000_000
"""The least time of one round."""
comptime ROUNDS = 5
"""The rounds; the fastest one counts."""
comptime WARMUP_NS = 200_000_000
"""The least time of the warm-up."""


trait Workload(Deinitable):
    """One benchmark operation, run again and again."""

    def run(mut self) raises -> Int:
        """Do one operation.

        Returns:
            A number that depends on the work, so it is not optimized away.

        Raises:
            Error: If the operation fails.
        """
        ...


def _round[W: Workload](mut work: W, iterations: Int) raises -> Int:
    """Run a workload a number of times, and return the nanoseconds."""
    var sink = 0
    var start = perf_counter_ns()
    for _ in range(iterations):
        sink += work.run()
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    return elapsed


def measure[W: Workload](name: StringSlice, var work: W) raises:
    """Time one workload and print its `BENCH` line.

    Parameters:
        W: The workload type.

    Args:
        name: The workload id, such as `seamstress/graph-introspect-github`.
        work: The workload.

    Raises:
        Error: If an operation fails.
    """
    var iterations = 1
    var warm = 0
    while True:
        var elapsed = _round(work, iterations)
        warm += elapsed
        if elapsed * 4 >= WARMUP_NS or warm >= WARMUP_NS:
            var per_op = max(elapsed // iterations, 1)
            iterations = max(ROUND_NS // per_op, 1)
            break
        iterations *= 2
    var best = Float64.MAX
    for _ in range(ROUNDS):
        var elapsed = _round(work, iterations)
        best = min(best, Float64(elapsed) / Float64(iterations))
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0, flush=True)
