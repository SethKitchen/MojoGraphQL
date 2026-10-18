# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The code generation benchmark, against Apollo Kotlin `apollo-compiler`.

`apollo-kotlin/codegen-github-query` generates the models of the four
operations and the fragments of `bench/fixtures/github-query.graphql`,
against `bench/fixtures/github-schema.graphql`. The schema is built and
checked once, outside the timer, as `ApolloCompiler.buildCodegenSchema`
is in the baseline. Each operation reads the document from its file,
parses it, adds `__typename`, validates it, builds the `operationBased` IR
and writes the source, as `ApolloCompiler.buildSchemaAndOperationsSources`
and the rendering of each generated file do in the baseline,
`bench/baselines/kotlin-codegen`.
"""

from std.pathlib import Path

from gql_schema.definition import Schema

from gql_codegen.compiler import CodegenDocument, build_codegen_schema, compile

from _harness import Workload, measure

comptime FIXTURES = "bench/fixtures/"
"""The directory of the fixtures, from the repository root."""


struct Codegen(Movable, Workload):
    """Generate the models of an executable document."""

    var schema: Schema
    """The schema, built and checked outside the timer."""
    var path: String
    """The executable document's file."""

    def __init__(out self, var schema: Schema, var path: String):
        """Keep the schema and the document's path.

        Args:
            schema: The schema.
            path: The file of the executable document.
        """
        self.schema = schema^
        self.path = path^

    def run(mut self) raises -> Int:
        """Read the document and generate its models.

        Returns:
            The length of the generated source.

        Raises:
            Error: If the document does not compile.
        """
        var documents = List[CodegenDocument]()
        documents.append(
            CodegenDocument("github-query.graphql", Path(self.path).read_text())
        )
        var result = compile(self.schema, documents)
        if not result.succeeded():
            raise Error("the benchmark document does not compile")
        return result.source.byte_length()


def main() raises:
    var schema = build_codegen_schema(
        Path(FIXTURES + "github-schema.graphql").read_text()
    )
    measure(
        "apollo-kotlin/codegen-github-query",
        Codegen(schema^, FIXTURES + "github-query.graphql"),
    )
