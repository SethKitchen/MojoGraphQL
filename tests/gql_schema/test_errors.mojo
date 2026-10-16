# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.errors`.

graphql-js 16.14.2 has no test file for `new GraphQLError(message,
{ nodes })` with nodes from several documents. The expected locations,
`toString()` and `toJSON()` text come from graphql-js 16.14.2 in Node.js:
each location and each excerpt uses the source of its own node.
"""

from gql_language.ast import Document
from gql_language.parser import parse
from gql_language.source import Source
from gql_schema.build import build_ast_schema
from gql_schema.definition import AstRef, Schema
from gql_schema.errors import error_at, schema_error
from std.testing import TestSuite, assert_equal


def two_document_schema() raises -> Schema:
    """Build `type Query` from one document and its extension from a
    second, named document."""
    var documents = List[Document]()
    documents.append(parse("type Query {\n  a: Int\n}"))
    documents.append(
        parse(Source("\n\nextend type Query {\n  b: String\n}", "ext.graphql"))
    )
    return build_ast_schema(documents^)


def test_schema_error_with_nodes_in_two_documents() raises:
    var schema = two_document_schema()
    var query = schema.type_named("Query")
    ref named = schema.types[query]
    var field = schema.fields[schema.field_named(query, "a")].definition
    var extension = schema.ast_refs[Int(named.extensions.start)]
    var nodes: List[AstRef] = [field, extension, AstRef.NONE, named.definition]
    var error = schema_error("Two places.", schema, nodes)
    assert_equal(len(error.locations), 3)
    assert_equal(String(error.locations[0]), "2:3")
    assert_equal(String(error.locations[1]), "3:1")
    assert_equal(String(error.locations[2]), "1:1")
    assert_equal(
        String(error),
        (
            "Two places.\n\nGraphQL request:2:3\n1 | type Query {\n2 |   a:"
            " Int\n  |   ^\n3 | }\n\next.graphql:3:1\n2 |\n3 | extend type"
            " Query {\n  | ^\n4 |   b: String\n\nGraphQL request:1:1\n1 | type"
            " Query {\n  | ^\n2 |   a: Int"
        ),
    )
    assert_equal(
        error.to_json(),
        '{"message":"Two places.","locations":[{"line":2,"column":3},'
        + '{"line":3,"column":1},{"line":1,"column":1}]}',
    )


def test_error_at_with_no_node() raises:
    var schema = two_document_schema()
    var nodes: List[AstRef] = [AstRef.NONE, AstRef(0, -1), AstRef(-1, 0)]
    var error = error_at("None.", schema.documents, nodes)
    assert_equal(len(error.locations), 0)
    assert_equal(String(error), "None.")
    assert_equal(String(error_at("Empty.", schema.documents, [])), "Empty.")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
