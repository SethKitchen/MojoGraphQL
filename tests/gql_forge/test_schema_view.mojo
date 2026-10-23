# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_forge.schema_view`."""

from gql_forge.schema_view import (
    root_type_name,
    schema_index_from_sdl,
    schema_index_json,
    type_ref_text,
    user_type_names,
    write_type_names,
    write_user_types,
)
from gql_json.writer import JsonWriter
from gql_schema.build import build_schema
from gql_schema.definition import NO_TYPE, TypeRef
from std.testing import TestSuite, assert_equal, assert_true


comptime SDL = """type Query {
  product(id: ID!): Product
}

type Product implements Node {
  id: ID!
  tags: [String!]!
}

interface Node {
  id: ID!
}

union Search = Product

enum Status {
  HOT
}

input Filter {
  q: String
}
"""


def test_type_ref_and_roots() raises:
    var schema = build_schema(SDL)
    var product = schema.type_named("Product")
    assert_equal(type_ref_text(schema, TypeRef.of(product)), "Product")
    var unknown = TypeRef.of(-3)
    assert_equal(type_ref_text(schema, unknown), "Unknown")
    assert_equal(root_type_name(schema, schema.query_type), "Query")
    assert_equal(root_type_name(schema, NO_TYPE), "")
    assert_equal(root_type_name(schema, Int32(-2)), "")
    assert_equal(root_type_name(schema, Int32(9999)), "")
    var json = schema_index_from_sdl(SDL)
    assert_true(json.find("[String!]!") >= 0)


def test_schema_index() raises:
    var json = schema_index_from_sdl(SDL)
    assert_true(json.find('"queryType":"Query"') >= 0)
    assert_true(json.find('"name":"Product"') >= 0)
    assert_true(json.find('"kind":"INTERFACE"') >= 0)
    assert_true(json.find('"kind":"UNION"') >= 0)
    assert_true(json.find('"kind":"ENUM"') >= 0)
    assert_true(json.find('"kind":"INPUT_OBJECT"') >= 0)
    assert_true(json.find("HOT") >= 0)
    var names = user_type_names(build_schema(SDL))
    assert_true(len(names) >= 5)
    _ = schema_index_json(build_schema("type Query { a: String }"))
    var schema = build_schema(SDL)
    schema.type_map.append(Int32(-1))
    schema.type_map.append(Int32(9999))
    _ = user_type_names(schema)
    var types_writer = JsonWriter()
    write_user_types(types_writer, schema)
    _ = types_writer^.take_string()
    schema.type_lists.append(Int32(-1))
    schema.type_lists.append(Int32(9999))
    var writer = JsonWriter()
    write_type_names(writer, schema, len(schema.type_lists) - 2, 2)
    assert_true(writer^.take_string().find("Unknown") >= 0)
    _ = schema_index_json(
        build_schema(
            "type Query { a: String }\ntype Mutation { b: String }\n"
            + "type Subscription { c: String }\n"
        )
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
