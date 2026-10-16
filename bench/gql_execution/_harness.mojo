# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The timing method of the gql_execution benchmarks.

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
from gql_execution.build_client_schema import build_client_schema
from gql_execution.execute import ExecutionArgs, execute
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import Schema

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


struct Execute(Movable, Workload):
    """Execute a parsed document against a schema: graphql-js
    `executeSync({ schema, document })`."""

    var schema: Schema
    """The schema, built outside the timer."""
    var document: Document
    """The document, parsed outside the timer."""

    def __init__(out self, sdl: String, query: String) raises:
        """Build the schema with `assumeValid: true`, and parse the query.

        Args:
            sdl: The schema's SDL.
            query: The query text.

        Raises:
            Error: If the SDL or the query is not valid.
        """
        var options = BuildOptions()
        options.assume_valid = True
        self.schema = build_schema(sdl, options)
        self.document = parse_document(query)

    def run(mut self) raises -> Int:
        """Execute the document.

        The schema was built with `assumeValid: true`, so graphql-js skips
        `assertValidSchema`; `assume_valid_schema` does the same.

        Returns:
            The number of values in the result.

        Raises:
            Error: If execution raises.
        """
        var args = ExecutionArgs()
        args.assume_valid_schema = True
        var result = execute(self.schema, self.document, args)
        return len(result.data.nodes) + len(result.errors)


struct ParseExecute(Movable, Workload):
    """Parse a query and execute it: graphql-js `graphqlSync({ schema,
    source })` without its validation."""

    var schema: Schema
    """The schema, built outside the timer."""
    var source: String
    """The query text."""

    def __init__(out self, sdl: String, var source: String) raises:
        """Build the schema.

        Args:
            sdl: The schema's SDL.
            source: The query text.

        Raises:
            Error: If the SDL is not valid.
        """
        self.schema = build_schema(sdl)
        self.source = source^

    def run(mut self) raises -> Int:
        """Parse and execute the query.

        Returns:
            The number of errors and values in the result.

        Raises:
            Error: If parsing or execution raises.
        """
        var document = parse_document(self.source)
        var args = ExecutionArgs()
        args.assume_valid_schema = True
        var result = execute(self.schema, document, args)
        return len(result.data.nodes) + len(result.errors)


struct BuildClientSchema(Movable, Workload):
    """Build a schema from an introspection result: graphql-js
    `buildClientSchema(result.data, { assumeValid: true })`."""

    var document: JsonDocument
    """The introspection result, parsed outside the timer, as graphql-js
    reads it from a JavaScript object."""
    var data: Int
    """The `data` value."""

    def __init__(out self, json: String) raises:
        """Parse the result.

        Args:
            json: The JSON text of the introspection response.

        Raises:
            Error: If the text is not JSON or has no `data`.
        """
        self.document = parse_json(json)
        self.data = self.document.get(self.document.root, "data")

    def run(mut self) raises -> Int:
        """Build the schema.

        Returns:
            The number of types in its type map.

        Raises:
            Error: If the result is not complete.
        """
        var schema = build_client_schema(
            self.document, self.data, assume_valid=True
        )
        return len(schema.type_map)
