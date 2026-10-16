# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.minify`.

Ported from Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/introspection/minify.rs` (`mod tests`, 3
tests), with the snapshot
`introspection/snapshots/apollo_mcp_server__introspection__minify__tests__minify_schema.snap`.
"""

from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_mcp.minify import minify_type, normalize_description
from gql_mcp.tree_shake import DepthLimit, SchemaTreeShaker
from std.testing import TestSuite, assert_equal, assert_true

from _minify_fixture import MINIFY_EXPECTED, MINIFY_SCHEMA


def _apollo_order(schema: Schema) -> List[Int]:
    """The types in apollo-compiler order: the introspection types, the
    built-in scalars, then the schema's types."""
    var out = List[Int]()
    var introspection = List[Int]()
    var scalars = List[Int]()
    for type in range(len(schema.types)):
        ref named = schema.types[type]
        if not named.is_builtin:
            out.append(type)
        elif named.name.startswith("__"):
            introspection.append(type)
        else:
            scalars.append(type)
    introspection.extend(scalars^)
    introspection.extend(out^)
    return introspection^


def test_minify_schema() raises:
    var schema = build_schema(MINIFY_SCHEMA)
    var lines = List[String]()
    for type in _apollo_order(schema):
        lines.append(schema.types[type].name + ": " + minify_type(schema, type))
    var expected = String(String(MINIFY_EXPECTED).strip()).split("\n")
    assert_equal(len(lines), len(expected))
    var index = 0
    while index < len(lines):
        # The introspection types are the ones of graphql-js 16, not the
        # ones of apollo-compiler: compare their names only.
        if lines[index].startswith("__"):
            var name = lines[index].split(":")[0]
            assert_true(String(expected[index]).startswith(name + ":"))
        else:
            assert_equal(lines[index], String(expected[index]))
        index += 1


def test_normalize_description_collapses_whitespace_runs() raises:
    var desc = (
        "\n\t  The rich text converted to plain text\n\t\t(non wiki),   taking"
        " the\r\n  field renderer into account.  \n"
    )
    assert_equal(
        normalize_description(desc),
        (
            "The rich text converted to plain text (non wiki), taking the field"
            " renderer into account."
        ),
    )


def test_deprecation_reason_is_normalized() raises:
    var schema = build_schema(
        '''
            type Query {
              """
                Returns the thing.
                    Requires   opting in.
              """
              old: String @deprecated(reason: """
                  Use   `new`
                  instead.
              """)
              new: String
            }
        '''
    )
    assert_equal(
        minify_type(schema, schema.type_named("Query")),
        (
            'T:Query:"Returns the thing. Requires opting in."old:s@D("Use `new`'
            ' instead."),new:s'
        ),
    )


def test_minify_branches() raises:
    var schema = build_schema(
        "directive @tag on FIELD_DEFINITION\n"
        + "type Query { a(x: Int, y: [ID!]!): Float @tag @deprecated(reason:"
        + " null) b: Boolean @deprecated }\n"
        + "type Empty\nenum None\nunion Nobody\ninput In { f: Int = 1 }\n"
    )
    assert_equal(
        minify_type(schema, schema.type_named("Query")),
        "T:Query:a(x:i,y:[d!]!):f@D,b:b@D",
    )
    assert_equal(minify_type(schema, schema.type_named("Empty")), "T:Empty:")
    assert_equal(minify_type(schema, schema.type_named("None")), "E:None:")
    assert_equal(minify_type(schema, schema.type_named("Nobody")), "U:Nobody:")
    assert_equal(minify_type(schema, schema.type_named("In")), "I:In:f:i")
    assert_equal(normalize_description(""), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
