# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-go-tools v2 benchmarks.

- `pkg/astparser/parser_test.go`: `BenchmarkParseStarwars`,
  `BenchmarkParseGithub`, `BenchmarkSelectionSet`,
  `BenchmarkIntrospectionQuery`, `BenchmarkKitchenSink` and `BenchmarkParse`
  each parse one input.
- `pkg/astprinter/astprinter_test.go`: `BenchmarkPrint` parses
  `benchmarkTestOperation` once, outside the timer, and times only the
  print.
- `pkg/lexer/lexer_test.go`: `BenchmarkLexer` reads every token of
  `introspectionQuery` to the end of the file.
"""

from _harness import Lex, Parse, Print, fixture, measure


def main() raises:
    """Run the graphql-go-tools workloads."""
    var introspection = fixture("go-tools-introspection-query.graphql")
    measure(
        "go-tools/ParseStarwars",
        Parse(fixture("go-tools-starwars.schema.graphql")),
    )
    measure(
        "go-tools/ParseGithub", Parse(fixture("go-tools-github.schema.graphql"))
    )
    measure(
        "go-tools/SelectionSet",
        Parse(fixture("go-tools-selection-set.graphql")),
    )
    measure("go-tools/IntrospectionQuery", Parse(introspection.copy()))
    measure(
        "go-tools/KitchenSink", Parse(fixture("go-tools-kitchen-sink.graphql"))
    )
    measure("go-tools/Parse", Parse(fixture("go-tools-parse-input.graphql")))
    measure(
        "go-tools/Print", Print(fixture("go-tools-print-operation.graphql"))
    )
    measure("go-tools/Lexer", Lex(introspection))
