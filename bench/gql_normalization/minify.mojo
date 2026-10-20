# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The minifier benchmark, against graphql-go-tools v2 `astminify`.

`go-tools/Minify` is `BenchmarkMinify` of `v2/pkg/astminify/minify_test.go`:
it minifies `bench/fixtures/go-tools-minify-operation1.graphql` against
`bench/fixtures/go-tools-minify-simpleschema.graphql`, with `sort_ast`. The
schema is built once, outside the timer, as the upstream benchmark parses
it before `b.ResetTimer`. One `Minifier` and one output string are used
again in each operation, as the upstream benchmark reuses its minifier and
its buffer. The baseline is `bench/baselines/go-normalization/minify.go`.
"""

from std.pathlib import Path

from gql_normalization.minify import Minifier, MinifyOptions
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from _harness import Workload, measure

comptime FIXTURES = "bench/fixtures/"
"""The directory of the fixtures, from the repository root."""


struct Minify(Movable, Workload):
    """Minify one operation against a schema."""

    var operation: String
    """The operation text."""
    var schema: Schema
    """The schema, built outside the timer."""
    var minifier: Minifier
    """The minifier, used again in each operation."""
    var out: String
    """The output, cleared in each operation."""

    def __init__(out self, var operation: String, var schema: Schema):
        """Keep the operation and the schema.

        Args:
            operation: The operation text.
            schema: The schema.
        """
        self.operation = operation^
        self.schema = schema^
        self.minifier = Minifier()
        self.out = String("")

    def run(mut self) raises -> Int:
        """Minify the operation.

        Returns:
            The length of the minified text.

        Raises:
            Error: If the operation does not minify.
        """
        self.out = String("")
        _ = self.minifier.minify(
            self.operation,
            self.schema,
            MinifyOptions(pretty=False, sort_ast=True),
            self.out,
        )
        return self.out.byte_length()


def main() raises:
    measure(
        "go-tools/Minify",
        Minify(
            Path(FIXTURES + "go-tools-minify-operation1.graphql").read_text(),
            build_schema(
                Path(
                    FIXTURES + "go-tools-minify-simpleschema.graphql"
                ).read_text()
            ),
        ),
    )
