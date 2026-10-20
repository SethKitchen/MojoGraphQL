# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The apollo-parser 0.8.6 parse benchmarks, against the recovering parser
of gql_compiler.

`bench/gql_language/apollo_rs.mojo` runs the same three workloads with the
gql_language parser, which stops at the first error. Here the parser is
`gql_compiler.parser`, which recovers as apollo-parser does, so the
`apollo-parser-recovering/<name>` workloads compare the same kind of
parser. The Rust baseline times the same closures under both names.

- `benches/query.rs`: `query_parser` and `many_aliases` run `parse_query`,
  which parses and then visits the selection set of each top-level field
  of each operation.
- `benches/supergraph.rs`: `supergraph_parser` runs `parse_schema`, which
  parses and then visits the type of each field of each object type.
"""

from gql_compiler.parser import parse_recovering
from gql_language.ast import Kind, NO_NODE, Role
from _harness import Workload, fixture, measure


struct RecoveringQuery(Movable, Workload):
    """The apollo-parser `parse_query`, with the recovering parser."""

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
            Error: If the text has a syntax error.
        """
        var tree = parse_recovering(self.text)
        if len(tree.errors) > 0:
            raise Error(String(tree.errors[0]))
        ref document = tree.document
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


struct RecoveringSchema(Movable, Workload):
    """The apollo-parser `parse_schema`, with the recovering parser."""

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
            Error: If the text has a syntax error.
        """
        var tree = parse_recovering(self.text)
        if len(tree.errors) > 0:
            raise Error(String(tree.errors[0]))
        ref document = tree.document
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


def main() raises:
    """Run the recovering parser workloads."""
    measure(
        "apollo-parser-recovering/query_parser",
        RecoveringQuery(fixture("apollo-parser-query.graphql")),
    )
    measure(
        "apollo-parser-recovering/many_aliases",
        RecoveringQuery(fixture("apollo-parser-alias.graphql")),
    )
    measure(
        "apollo-parser-recovering/supergraph_parser",
        RecoveringSchema(fixture("apollo-parser-supergraph.graphql")),
    )
