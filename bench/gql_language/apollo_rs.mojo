# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The apollo-rs benchmarks: apollo-parser 0.8.6 and apollo-compiler 1.x.

- apollo-parser `benches/query.rs`: `query_parser` and `many_aliases` run
  `parse_query`, which parses and then visits the selection set of each
  top-level field of each operation. `query_lexer` reads every token.
- apollo-parser `benches/supergraph.rs`: `supergraph_parser` runs
  `parse_schema`, which parses and then visits the type of each field of
  each object type. `supergraph_lexer` reads every token.
- apollo-compiler `benches/multi_source.rs`: `parse_ast` parses a schema
  and a query into two ASTs.

The walks here visit the gql_language AST the way the upstream walks visit
the apollo-parser CST.
"""

from _harness import Lex, ParseTwo, ParseWalkQuery, ParseWalkSchema
from _harness import fixture, measure


def main() raises:
    """Run the apollo-rs workloads."""
    var query = fixture("apollo-parser-query.graphql")
    var supergraph = fixture("apollo-parser-supergraph.graphql")
    measure("apollo-parser/query_parser", ParseWalkQuery(query.copy()))
    measure("apollo-parser/query_lexer", Lex(query))
    measure(
        "apollo-parser/many_aliases",
        ParseWalkQuery(fixture("apollo-parser-alias.graphql")),
    )
    measure(
        "apollo-parser/supergraph_parser", ParseWalkSchema(supergraph.copy())
    )
    measure("apollo-parser/supergraph_lexer", Lex(supergraph))
    measure(
        "apollo-compiler/simple_query-parse_ast",
        ParseTwo(
            fixture("apollo-compiler-simple-schema.graphql"),
            fixture("apollo-compiler-simple-query.graphql"),
        ),
    )
    measure(
        "apollo-compiler/supergraph-parse_ast",
        ParseTwo(
            supergraph.copy(),
            fixture("apollo-compiler-supergraph-query.graphql"),
        ),
    )
