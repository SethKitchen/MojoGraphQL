# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The timing method and the workloads of the gql_validation benchmarks.

The same method as `bench/gql_language/_harness.mojo`: `measure` warms a
workload up, then runs `ROUNDS` rounds of at least `ROUND_NS` nanoseconds
each, and prints the fastest round as `BENCH <workload> <ns per op>`.
Work that the upstream benchmark does outside its timer, such as building
and checking the schema, happens in the workload's constructor.

The schema is checked once, in the constructor. So each operation passes
`assume_valid_schema`, as graphql-js skips the check for a schema that it
built with `assumeValid` or checked before, and as apollo-compiler takes a
`Valid<Schema>`.
"""

from std.benchmark import keep
from std.pathlib import Path
from std.time import perf_counter_ns

from gql_language.ast import Document
from gql_language.parser import parse
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import Schema
from gql_schema.validate import assert_valid_schema
from gql_validation.rules import specified_rules
from gql_validation.validate import ValidationOptions, validate

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
        name: The file name, such as `github-schema.graphql`.

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


def checked_schema(sdl: String) raises -> Schema:
    """Build a schema from SDL and check it, as apollo-compiler
    `Schema::parse_and_validate` and graphql-js `buildSchema` do.

    Args:
        sdl: The SDL.

    Returns:
        The schema.

    Raises:
        Error: If the SDL or the schema is not valid.
    """
    var schema = build_schema(sdl)
    assert_valid_schema(schema)
    return schema^


def assumed_valid_schema(sdl: String) raises -> Schema:
    """Build a schema with no checks: graphql-js `buildSchema(sdl, {
    assumeValid: true })`.

    Args:
        sdl: The SDL.

    Returns:
        The schema.

    Raises:
        Error: If the SDL does not parse.
    """
    var options = BuildOptions()
    options.assume_valid = True
    return build_schema(sdl, options)


def _options() -> ValidationOptions:
    """Return the options of each timed validation."""
    var options = ValidationOptions()
    options.assume_valid_schema = True
    return options


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
        name: The workload id, such as `graphql-js/validate-invalid-query`.
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
    print("BENCH", name, Float64(Int(best * 10.0)) / 10.0)


struct Validate(Movable, Workload):
    """Validate a parsed document: graphql-js `validate(schema, document)`."""

    var schema: Schema
    """The schema, built and checked outside the timer."""
    var document: Document
    """The document, parsed outside the timer."""

    def __init__(out self, var schema: Schema, text: String) raises:
        """Parse the document once.

        Args:
            schema: The schema.
            text: The document's text.

        Raises:
            Error: If the text does not parse.
        """
        self.schema = schema^
        self.document = parse_document(text)

    def run(mut self) raises -> Int:
        """Validate the document with every specified rule.

        Returns:
            One more than the number of errors.

        Raises:
            Error: If the validation fails.
        """
        return (
            len(
                validate(
                    self.schema, self.document, specified_rules(), _options()
                )
            )
            + 1
        )


struct ParseValidate(Movable, Workload):
    """Parse and validate a document: apollo-compiler
    `ExecutableDocument::parse_and_validate(&schema, query, path)`."""

    var schema: Schema
    """The schema, built and checked outside the timer."""
    var text: String
    """The document's text."""

    def __init__(out self, var schema: Schema, var text: String):
        """Hold the schema and the text.

        Args:
            schema: The schema.
            text: The document's text.
        """
        self.schema = schema^
        self.text = text^

    def run(mut self) raises -> Int:
        """Parse the text and validate it with every specified rule.

        Returns:
            One more than the number of errors.

        Raises:
            Error: If the text does not parse.
        """
        var document = parse_document(self.text)
        return (
            len(validate(self.schema, document, specified_rules(), _options()))
            + 1
        )
