# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The timing method of the gql_schema benchmarks.

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
from gql_schema.build import BuildOptions, build_ast_schema, build_schema
from gql_schema.sdl_validation import validate_sdl

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


struct BuildAstSchema(Movable, Workload):
    """Build a schema from a parsed document: graphql-js
    `buildASTSchema(document, { assumeValid: true })`."""

    var document: Document
    """The SDL document, parsed outside the timer."""
    var options: BuildOptions
    """`assumeValid: true`, as the upstream benchmark passes."""

    def __init__(out self, text: String) raises:
        """Parse the SDL once.

        Args:
            text: The SDL.

        Raises:
            Error: If the text is not a valid document.
        """
        self.document = parse_document(text)
        self.options = BuildOptions()
        self.options.assume_valid = True

    def run(mut self) raises -> Int:
        """Build the schema.

        graphql-js keeps its AST for the next run. Here the schema owns the
        document, so the document moves in and is taken back: it is not
        copied.

        Returns:
            The number of types in its type map.

        Raises:
            Error: If the build fails.
        """
        var documents = List[Document]()
        documents.append(Document())
        swap(documents[0], self.document)
        var schema = build_ast_schema(documents^, self.options)
        var count = len(schema.type_map)
        var back = schema^.take_documents()
        swap(self.document, back[0])
        return count


struct BuildSchema(Movable, Workload):
    """Parse SDL and build a schema: graphql-js
    `buildSchema(text, { assumeValid: true })`."""

    var text: String
    """The SDL."""
    var options: BuildOptions
    """`assumeValid: true`: no SDL validation."""

    def __init__(out self, var text: String):
        """Hold the SDL.

        Args:
            text: The SDL.
        """
        self.text = text^
        self.options = BuildOptions()
        self.options.assume_valid = True

    def run(mut self) raises -> Int:
        """Parse and build.

        Returns:
            The number of types in the type map.

        Raises:
            Error: If the text is not valid SDL.
        """
        return len(build_schema(self.text, self.options).type_map)


struct ValidateSdl(Movable, Workload):
    """Check SDL: graphql-js `validateSDL(documentAST)`."""

    var documents: List[Document]
    """The SDL document, parsed outside the timer."""

    def __init__(out self, text: String) raises:
        """Parse the SDL once.

        Args:
            text: The SDL.

        Raises:
            Error: If the text is not a valid document.
        """
        self.documents = List[Document]()
        self.documents.append(parse_document(text))

    def run(mut self) raises -> Int:
        """Check the SDL.

        Returns:
            The number of errors, plus one.

        Raises:
            Error: Never.
        """
        return len(validate_sdl(self.documents)) + 1
