# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The apollo-compiler executable document build, against apollo-compiler
1.33.0.

`apollo-compiler/executable-from-ast` times what the Rust baseline times:
`ExecutableDocument::builder(Some(&schema), &mut errors)` with
`add_ast_document(&query, true)` and `build()`. The GitHub schema is built
and the GitHub query is parsed once, outside the timer.
"""

from gql_language.ast import Document
from gql_compiler.executable import ExecutableDocument
from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.schema import Schema
from _harness import Workload, fixture, measure, parse_document


struct ExecutableFromAst(Movable, Workload):
    """Build an `ExecutableDocument` from the parsed GitHub query."""

    var schema: Schema
    """The GitHub schema, built outside the timer."""
    var document: Document
    """The query document, parsed outside the timer."""

    def __init__(out self, sdl: String, query: String) raises:
        """Build the schema and parse the query once.

        Args:
            sdl: The schema text.
            query: The query text.

        Raises:
            Error: If a text is not a valid document.
        """
        var builder = SchemaBuilder()
        builder.add_ast(parse_document(sdl))
        self.schema = builder^.build_inner()[0].copy()
        self.document = parse_document(query)

    def run(mut self) raises -> Int:
        """Build the executable document.

        Upstream borrows the AST. Here the executable document owns its
        documents, so the query moves in and is taken back: it is not
        copied.

        Returns:
            The number of operations and fragments, plus the errors.

        Raises:
            Error: If the build fails.
        """
        var document = Document()
        swap(document, self.document)
        var result = ExecutableDocument.from_ast(self.schema, document^)
        var count = (
            len(result[0].operations)
            + len(result[0].fragments)
            + len(result[1])
        )
        swap(self.document, result[0].sources[0])
        return count


def main() raises:
    """Run the apollo-compiler executable workload."""
    measure(
        "apollo-compiler/executable-from-ast",
        ExecutableFromAst(
            fixture("github-schema.graphql"), fixture("github-query.graphql")
        ),
    )
