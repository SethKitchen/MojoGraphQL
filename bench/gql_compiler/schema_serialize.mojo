# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The apollo-compiler schema printer, against apollo-compiler 1.33.0.

`apollo-compiler/schema-serialize` times what the Rust baseline times:
`schema.to_string()` on the GitHub schema. The schema is built once,
outside the timer.
"""

from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.schema import Schema
from _harness import Workload, fixture, measure, parse_document


struct SchemaSerialize(Movable, Workload):
    """Print the GitHub schema."""

    var schema: Schema
    """The schema, built outside the timer."""

    def __init__(out self, text: String) raises:
        """Parse the SDL and build the schema once.

        Args:
            text: The SDL.

        Raises:
            Error: If the text is not a valid document.
        """
        var builder = SchemaBuilder()
        builder.add_ast(parse_document(text))
        self.schema = builder^.build_inner()[0].copy()

    def run(mut self) raises -> Int:
        """Print the schema.

        Returns:
            The length of the text.
        """
        return self.schema.to_string().byte_length()


def main() raises:
    """Run the apollo-compiler schema printing workload."""
    measure(
        "apollo-compiler/schema-serialize",
        SchemaSerialize(fixture("github-schema.graphql")),
    )
