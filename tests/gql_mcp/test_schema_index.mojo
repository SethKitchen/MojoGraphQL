# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.schema_index`.

Ports of the tests of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-schema-index/src/lib.rs` (with the insta snapshot
`snapshots/apollo_schema_index__tests__search.snap`) and
`src/traverse.rs` (with `apollo_schema_index__traverse__tests__schema_traverse.snap`).
"""

from gql_mcp.text_analysis import expand_identifiers
from gql_mcp.schema_index import (
    RootTypes,
    field_norm_id,
    field_norm_table,
    format_f32,
    SchemaIndex,
    SearchOptions,
    traverse,
)
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import Schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _schema_index_fixture import SCHEMA, TRAVERSE


def _schema() raises -> Schema:
    var options = BuildOptions()
    options.assume_valid_sdl = True
    return build_schema(SCHEMA, options)


def _paths(index: SchemaIndex, term: String) -> List[String]:
    var terms = List[String]()
    terms.append(term)
    var results = index.search(terms, SearchOptions())
    var out = List[String]()
    for result in results:
        out.append(String(result))
    return out^


def _any_contains(paths: List[String], text: String) -> Bool:
    for path in paths:
        if text in path:
            return True
    return False


def test_search() raises:
    var schema = _schema()
    var index = SchemaIndex(schema, RootTypes.QUERY | RootTypes.MUTATION)
    var paths = _paths(index, "dimensions")
    var text = String()
    var i = 0
    while i < len(paths) and i < 10:
        if i > 0:
            text += "\n"
        text += paths[i]
        i += 1
    assert_equal(
        text,
        (
            "Mutation -> uploadMedia(Upload) -> Media -> metadata ->"
            " MediaMetadata -> dimensions -> Dimensions (6.170166)\nMutation ->"
            " uploadMedia(Upload) -> Media -> metadata -> MediaMetadata"
            " (6.0267076)\nQuery -> posts(PostFilter) -> Post -> media -> Media"
            " -> metadata -> MediaMetadata (5.0222564)\nQuery -> post(ID) ->"
            " Post -> media -> Media -> metadata -> MediaMetadata"
            " (5.0222564)\nQuery -> posts(PostFilter) -> Post -> media -> Media"
            " -> metadata -> MediaMetadata -> dimensions -> Dimensions"
            " (4.936133)\nQuery -> post(ID) -> Post -> media -> Media ->"
            " metadata -> MediaMetadata -> dimensions -> Dimensions (4.936133)"
        ),
    )


def test_search_interface_implementer_fields() raises:
    var schema = _schema()
    var index = SchemaIndex(schema, RootTypes.QUERY | RootTypes.MUTATION)
    var paths = _paths(index, "username")
    assert_true(len(paths) > 0)
    assert_true(_any_contains(paths, "User"))
    paths = _paths(index, "analytics")
    assert_true(len(paths) > 0)
    assert_true(_any_contains(paths, "Post"))


def test_search_camel_case_splitting() raises:
    var schema = _schema()
    var index = SchemaIndex(schema, RootTypes.QUERY | RootTypes.MUTATION)
    var paths = _paths(index, "post")
    assert_true(_any_contains(paths, "PostAnalytics"))
    assert_true(_any_contains(paths, "UpdatePostInput"))


def test_search_camel_case_query_term() raises:
    var schema = _schema()
    var index = SchemaIndex(schema, RootTypes.QUERY | RootTypes.MUTATION)
    assert_true(_any_contains(_paths(index, "CreatePost"), "Post"))


def test_search_camel_case_in_description() raises:
    var schema = _schema()
    var index = SchemaIndex(schema, RootTypes.QUERY | RootTypes.MUTATION)
    assert_true(_any_contains(_paths(index, "post"), "Tag"))


def test_expand_identifiers_splits_at_word_boundaries() raises:
    assert_equal(expand_identifiers("CreatePostInput"), "create post input")
    assert_equal(expand_identifiers("createPost"), "create post")
    assert_equal(expand_identifiers("getUserById"), "get user by id")
    assert_equal(expand_identifiers("PostConnection"), "post connection")
    assert_equal(expand_identifiers("HTMLParser"), "html parser")
    assert_equal(expand_identifiers("post"), "post")
    assert_equal(expand_identifiers("ID"), "id")
    assert_equal(expand_identifiers("get_user_by_id"), "get user by id")
    assert_equal(
        expand_identifiers("fieldName: TypeName"), "field name: type name"
    )
    assert_equal(
        expand_identifiers("firstName, lastName"), "first name, last name"
    )


def test_schema_traverse() raises:
    var schema = _schema()
    var all = RootTypes.QUERY | RootTypes.MUTATION | RootTypes.SUBSCRIPTION
    var text = String("\n")
    for item in traverse(schema, all):
        text += String(item.path) + "\n"
    assert_equal(text, TRAVERSE)


def test_format_f32() raises:
    assert_equal(format_f32(0.0), "0")
    assert_equal(format_f32(-1.5), "-1.5")
    assert_equal(format_f32(3.0), "3")
    assert_equal(format_f32(1e-7), "0.0000001")
    assert_equal(format_f32(1.5e20), "150000000000000000000")
    assert_equal(format_f32(123456.79), "123456.79")
    assert_equal(format_f32(0.1), "0.1")
    assert_equal(format_f32(6.0267076), "6.0267076")
    assert_equal(format_f32(100.0), "100")
    assert_equal(format_f32(0.00012), "0.00012")
    assert_equal(format_f32(16777216.0), "16777216")
    assert_equal(format_f32(2.5e-3), "0.0025")


def test_root_types_and_norms() raises:
    var all = RootTypes.QUERY | RootTypes.MUTATION | RootTypes.SUBSCRIPTION
    assert_true(all.is_valid())
    assert_false(RootTypes(8).is_valid())
    assert_true(all.contains(2))
    assert_false(RootTypes.QUERY.contains(1))
    assert_true(RootTypes.NONE == RootTypes(0))
    var table = field_norm_table()
    assert_equal(len(table), 256)
    assert_equal(table[40], 40)
    assert_equal(table[41], 42)
    assert_equal(table[57], 96)
    assert_equal(table[255], 2013265944)
    assert_equal(field_norm_id(table, 0), 0)
    assert_equal(field_norm_id(table, 41), 40)
    assert_equal(field_norm_id(table, 42), 41)
    assert_equal(field_norm_id(table, 3000000000), 255)


def test_options() raises:
    var schema = _schema()
    var index = SchemaIndex(schema, RootTypes.QUERY | RootTypes.MUTATION)
    var terms = List[String]()
    terms.append("dimensions")
    var results = index.search(terms, SearchOptions(1, 1, 0.0, 0.0))
    assert_equal(len(results), 1)
    assert_equal(
        String(results[0]),
        (
            "Mutation -> uploadMedia(Upload) -> Media -> metadata ->"
            " MediaMetadata -> dimensions -> Dimensions (3.5554154)"
        ),
    )
    assert_equal(len(index.search(List[String](), SearchOptions())), 0)
    var none = SchemaIndex(schema, RootTypes.NONE)
    assert_equal(len(none.search(terms, SearchOptions())), 0)


def test_many_types() raises:
    var sdl = String("type Query {")
    var types = String()
    var i = 0
    while i < 4200:
        sdl += " f" + String(i) + ": T" + String(i)
        types += "\ntype T" + String(i) + " { x: String }"
        i += 1
    var schema = build_schema(sdl + " }" + types)
    var index = SchemaIndex(schema, RootTypes.QUERY)
    var terms = List[String]()
    terms.append("x string")
    var results = index.search(terms, SearchOptions())
    assert_equal(len(results), 10)
    assert_equal(String(results[0].inner), "Query -> f4199 -> T4199")
    assert_equal(String(results[9].inner), "Query -> f4190 -> T4190")
    assert_equal(results[0].score, results[9].score)


comptime _DESCRIBED = """
"The root"
type Query {
  "Find a planet by its orbit"
  planet(id: ID): Planet
  "All the moons"
  moons: [Moon]
  kind: Kind
}
"A planet"
type Planet {
  "The orbit radius"
  orbit: Float
  "The moons of the planet"
  moons: [Moon]
}
type Moon {
  planet: Planet
}
"The kind of a body"
enum Kind {
  "A rocky planet"
  ROCKY
  "A gas giant with moons"
  GAS
  ICE
}
"""


def _joined(index: SchemaIndex, term: String) -> String:
    var text = String()
    for path in _paths(index, term):
        text += path + "\n"
    return text^


def test_descriptions() raises:
    var index = SchemaIndex(build_schema(_DESCRIBED), RootTypes.QUERY)
    assert_equal(
        _joined(index, "moons"),
        (
            "Query -> planet(ID) -> Planet (2.0631561)\nQuery -> moons -> Moon"
            " (2.029412)\nQuery -> moons -> Moon -> planet -> Planet"
            " (1.8292872)\nQuery (1.6088607)\nQuery -> kind -> Kind"
            " (0.66322136)\n"
        ),
    )
    assert_equal(
        _joined(index, "gas rocky"), "Query -> kind -> Kind (5.264669)\n"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
