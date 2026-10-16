# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The timing method and the workloads that the gql_language benchmarks share.

`measure` warms a workload up, then runs `ROUNDS` rounds of at least
`ROUND_NS` nanoseconds each. It prints the fastest round as
`BENCH <workload> <ns per op>`, which `tools/bench.mojo` reads. The baselines
in `bench/baselines/` use the same method.

Each workload struct does one operation per `run` call. Work that the
upstream benchmark does outside its timer, such as parsing the document
that a print benchmark prints, happens in the struct's constructor.
"""

from std.benchmark import keep
from std.pathlib import Path
from std.time import perf_counter_ns

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.lexer import Lexer
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_language.source import Source
from gql_language.token_kind import TokenKind

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


struct Parse(Movable, Workload):
    """Parse a text: graphql-js `parse(text)`."""

    var text: String
    """The GraphQL text."""

    def __init__(out self, var text: String):
        """Hold the text to parse.

        Args:
            text: The GraphQL text.
        """
        self.text = text^

    def run(mut self) raises -> Int:
        """Parse the text once.

        Returns:
            The node count plus the token count.

        Raises:
            Error: If the text is not a valid GraphQL document.
        """
        var document = parse_document(self.text)
        return len(document.nodes) + document.token_count


struct ParseTwo(Movable, Workload):
    """Parse two texts, as apollo-compiler `parse_ast(schema, query)`."""

    var first: String
    """The first text, the schema."""
    var second: String
    """The second text, the query."""

    def __init__(out self, var first: String, var second: String):
        """Hold the texts to parse.

        Args:
            first: The schema text.
            second: The query text.
        """
        self.first = first^
        self.second = second^

    def run(mut self) raises -> Int:
        """Parse both texts once.

        Returns:
            The sum of the node counts.

        Raises:
            Error: If a text is not a valid GraphQL document.
        """
        var schema = parse_document(self.first)
        var query = parse_document(self.second)
        return len(schema.nodes) + len(query.nodes)


struct ParsePrint(Movable, Workload):
    """Parse a text and print it again: graphql-js `print(parse(text))`."""

    var text: String
    """The GraphQL text."""

    def __init__(out self, var text: String):
        """Hold the text to parse and print.

        Args:
            text: The GraphQL text.
        """
        self.text = text^

    def run(mut self) raises -> Int:
        """Parse and print the text once.

        Returns:
            The printed length.

        Raises:
            Error: If the text is not a valid GraphQL document.
        """
        return print_ast(parse_document(self.text)).byte_length()


struct Print(Movable, Workload):
    """Print a document parsed once, outside the timer: graphql-js
    `print(document)`."""

    var document: Document
    """The document to print."""

    def __init__(out self, text: StringSlice) raises:
        """Parse the document to print.

        Args:
            text: The GraphQL text.

        Raises:
            Error: If the text is not a valid GraphQL document.
        """
        self.document = parse_document(text)

    def run(mut self) raises -> Int:
        """Print the document once.

        Returns:
            The printed length.
        """
        return print_ast(self.document).byte_length()


struct Lex(Movable, Workload):
    """Read every token of a text to the end of the file.

    The source is built once and reused, as graphql-go-tools reuses its
    input and apollo-parser borrows the text.
    """

    var source: Optional[Source]
    """The source, between operations."""

    def __init__(out self, text: StringSlice) raises:
        """Build the source to read.

        Args:
            text: The GraphQL text.

        Raises:
            Error: Never; the default source offset is valid.
        """
        self.source = Source(text)

    def run(mut self) raises -> Int:
        """Read every token once.

        Returns:
            The token count.

        Raises:
            Error: If the text has a lexical error.
        """
        var lexer = Lexer(self.source.take())
        var count = 0
        try:
            while lexer.advance().kind != TokenKind.EOF:
                count += 1
        except e:
            raise Error(String(e))
        self.source = lexer^.take_source()
        return count


struct ParseWalkQuery(Movable, Workload):
    """apollo-parser `parse_query`: parse, then visit the selection set of
    each field at the top of each operation."""

    var text: String
    """The GraphQL text."""

    def __init__(out self, var text: String):
        """Hold the text to parse.

        Args:
            text: The GraphQL text of an executable document.
        """
        self.text = text^

    def run(mut self) raises -> Int:
        """Parse and walk once.

        Returns:
            The sum of the selection set indexes found.

        Raises:
            Error: If the text is not a valid GraphQL document.
        """
        var document = parse_document(self.text)
        var sink = 0
        var definition = document.first_child(document.root)
        while definition != NO_NODE:
            if document.kind(definition) == Kind.OPERATION_DEFINITION:
                var selections = document.child(definition, Role.SELECTION_SET)
                var selection = document.first_child(selections)
                while selection != NO_NODE:
                    if document.kind(selection) == Kind.FIELD:
                        sink += document.child(selection, Role.SELECTION_SET)
                    selection = document.next_sibling(selection)
            definition = document.next_sibling(definition)
        return sink


struct ParseWalkSchema(Movable, Workload):
    """apollo-parser `parse_schema`: parse, then visit the type of each
    field of each object type definition."""

    var text: String
    """The GraphQL text."""

    def __init__(out self, var text: String):
        """Hold the text to parse.

        Args:
            text: The GraphQL text of a schema.
        """
        self.text = text^

    def run(mut self) raises -> Int:
        """Parse and walk once.

        Returns:
            The sum of the type indexes found.

        Raises:
            Error: If the text is not a valid GraphQL document.
        """
        var document = parse_document(self.text)
        var sink = 0
        var definition = document.first_child(document.root)
        while definition != NO_NODE:
            if document.kind(definition) == Kind.OBJECT_TYPE_DEFINITION:
                var field = document.first_child(definition)
                while field != NO_NODE:
                    if document.role(field) == Role.FIELD:
                        sink += document.child(field, Role.TYPE)
                    field = document.next_sibling(field)
            definition = document.next_sibling(definition)
        return sink
