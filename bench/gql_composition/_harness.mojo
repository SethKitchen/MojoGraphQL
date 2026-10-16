# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The timing method of the gql_composition benchmarks.

The same method as `bench/gql_language/_harness.mojo`: `measure` warms a
workload up, then runs `ROUNDS` rounds of at least `ROUND_NS` nanoseconds
each, and prints the fastest round as `BENCH <workload> <ns per op>`.
Work that the upstream benchmark does outside its timer happens in the
workload's constructor.
"""

from std.benchmark import keep
from std.pathlib import Path
from std.time import perf_counter_ns

from gql_language.ast import Document
from gql_language.parser import parse
from gql_composition.validate import Subgraph, validate_subgraphs

comptime FIXTURES = "bench/fixtures/"
"""The directory of the fixtures, from the repository root."""
comptime ROUND_NS = 1_000_000_000
"""The shortest round, in nanoseconds."""
comptime ROUNDS = 5
"""How many timed rounds each workload runs."""
comptime WARMUP_NS = 200_000_000
"""How long each workload warms up, in nanoseconds."""


def fixture(name: String) raises -> String:
    """Read a fixture from `bench/fixtures/`.

    Args:
        name: The file name, such as `kitchen-sink.graphql`.

    Returns:
        The file's text.

    Raises:
        Error: If the file cannot be read.
    """
    return Path(FIXTURES + name).read_text()


def parse_document(text: StringSlice) raises -> Document:
    """Parse a document, with a plain `Error` on failure.

    Args:
        text: The GraphQL text.

    Returns:
        The document.

    Raises:
        Error: If the text is not a valid GraphQL document.
    """
    try:
        return parse(text)
    except e:
        raise Error(String(e))


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
    """Run a workload a number of times.

    Parameters:
        W: The workload type.

    Args:
        work: The workload.
        iterations: How many operations to run.

    Returns:
        The elapsed time in nanoseconds.

    Raises:
        Error: If an operation fails.
    """
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
        name: The workload id, such as `shared/parse-kitchen-sink`.
        work: The workload.

    Raises:
        Error: If an operation fails.
    """
    # Warm up, and find how many iterations fill a round.
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
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


def fixture_subgraphs(directory: String) raises -> List[Subgraph]:
    """Parse each `.graphql` file of a fixture directory as a subgraph,
    named after the file, in name order.

    Args:
        directory: The directory in `bench/fixtures/`, such as
            `hive-dgs`.

    Returns:
        The subgraphs.

    Raises:
        Error: If a file cannot be read or does not parse.
    """
    var names = List[String]()
    for path in Path(FIXTURES + directory).listdir():
        var name = String(path)
        if name.endswith(".graphql"):
            names.append(name)
    sort(names)
    var out = List[Subgraph]()
    for ref name in names:
        var text = Path(FIXTURES + directory + "/" + name).read_text()
        out.append(
            Subgraph(
                String(name.removesuffix(".graphql")),
                None,
                parse_document(text),
            )
        )
    return out^


struct ValidateSubgraphs(Movable, Workload):
    """Run the subgraph phase of composition on parsed subgraphs."""

    var subgraphs: List[Subgraph]
    """The subgraphs, parsed in setup."""

    def __init__(out self, directory: String) raises:
        """Parse the subgraphs of a fixture directory.

        Args:
            directory: The directory in `bench/fixtures/`.

        Raises:
            Error: If a subgraph does not parse, or is not valid.
        """
        self.subgraphs = fixture_subgraphs(directory)
        var errors = validate_subgraphs(self.subgraphs)
        if len(errors) != 0:
            raise Error(
                directory + " has subgraph errors: " + String(errors[0])
            )

    def run(mut self) raises -> Int:
        """Validate the subgraphs once.

        Returns:
            One more than the number of errors.

        Raises:
            Error: If validation raises.
        """
        return len(validate_subgraphs(self.subgraphs)) + 1
