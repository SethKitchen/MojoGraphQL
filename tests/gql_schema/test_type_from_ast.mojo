# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.type_from_ast`.

graphql-js 16.14.2 has no `typeFromAST-test.ts`; these tests check the
cases of `src/utilities/typeFromAST.ts`: a named type, a list, a non-null,
wrappers inside wrappers, and a name that the schema does not have.
"""

from gql_language.parser import parse_type
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_schema.type_from_ast import type_from_ast
from std.testing import TestSuite, assert_equal, assert_false


def resolved(schema: Schema, text: String) raises -> String:
    """Return the type of a type reference as SDL writes it, or `none`."""
    var document = parse_type(text)
    var type = type_from_ast(schema, document, document.root)
    if not type:
        return "none"
    return schema.type_name(type.value())


def test_named_type() raises:
    var schema = build_schema("type Query { a: String }")
    assert_equal(resolved(schema, "String"), "String")
    assert_equal(resolved(schema, "Query"), "Query")


def test_wrapped_types() raises:
    var schema = build_schema("type Query { a: String }")
    assert_equal(resolved(schema, "[String]"), "[String]")
    assert_equal(resolved(schema, "String!"), "String!")
    assert_equal(resolved(schema, "[[Query!]]!"), "[[Query!]]!")


def test_unknown_type() raises:
    var schema = build_schema("type Query { a: String }")
    assert_equal(resolved(schema, "Missing"), "none")
    assert_equal(resolved(schema, "[Missing!]"), "none")
    var document = parse_type("Float")
    assert_false(Bool(type_from_ast(schema, document, document.root)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
