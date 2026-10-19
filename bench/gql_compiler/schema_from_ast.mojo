# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The apollo-compiler schema build, against apollo-compiler 1.33.0.

`apollo-compiler/schema-from-ast` times what the Rust baseline times:
`Schema::builder().add_ast(&github).build()`. The GitHub schema is parsed
once, outside the timer. Each run copies a builder that holds the built-in
types, as upstream `SchemaBuilder::new` clones its static one.
"""

from gql_language.ast import Document
from gql_compiler.from_ast import SchemaBuilder
from _harness import Workload, fixture, measure, parse_document


struct SchemaFromAst(Movable, Workload):
    """Build a `Schema` from the parsed GitHub schema."""

    var document: Document
    """The SDL document, parsed outside the timer."""
    var built_in: SchemaBuilder
    """A builder with only the built-in types, made once."""

    def __init__(out self, text: String) raises:
        """Parse the SDL and make the built-in builder once.

        Args:
            text: The SDL.

        Raises:
            Error: If the text is not a valid document.
        """
        self.document = parse_document(text)
        self.built_in = SchemaBuilder.built_in()

    def run(mut self) raises -> Int:
        """Build the schema.

        Upstream shares the AST through `Arc`. Here the schema owns its
        documents, so the document moves in and is taken back: it is not
        copied.

        Returns:
            The number of types.

        Raises:
            Error: If the build fails.
        """
        var builder = self.built_in.copy()
        var document = Document()
        swap(document, self.document)
        builder.add_ast(document^)
        var result = builder^.build_inner()
        var count = len(result[0].types)
        swap(self.document, result[0].sources[1])
        return count


def main() raises:
    """Run the apollo-compiler schema workload."""
    measure(
        "apollo-compiler/schema-from-ast",
        SchemaFromAst(fixture("github-schema.graphql")),
    )
