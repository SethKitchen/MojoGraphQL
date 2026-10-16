# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.validate_subgraph`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_subgraph_spec_types_v1() raises:
    check(
        [
            sg("a", "type Query { _service: _Service! _entities(representations: [_Any!]!): [_Entity]! a: Int }\nscalar _Any\nunion _Entity = T\ntype _Service { sdl: String }\ntype T @key(fields: \"id\") { id: ID! }\n"),
        ],
        [
        ],
    )


def test_subgraph_spec_types_v2() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\ntype Query { _entities(representations: [_Any!]!): [_Entity]! a: Int _service: _Service! }\nextend type Query { _service: _Service! b: Int }\nscalar _Any\nunion _Entity = T\ntype _Service { sdl: String }\ntype T @key(fields: \"id\") { id: ID! }\n"),
        ],
        [
        ],
    )


def test_subgraph_spec_types_custom_query() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\nschema { query: Root }\ntype Root { _service: _Service! a: Int }\ntype Query { _service: _Service! }\ninput _Any { a: Int }\nunion _Entity = T\ntype _Service { sdl: String }\ntype T @key(fields: \"id\") { id: ID! }\n"),
        ],
        [
            "[ROOT_QUERY_USED] [a] The schema has a type named \"Query\" but it is not set as the query root type (\"Root\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
            "[INVALID_GRAPHQL] [a] Unknown type _Service",
        ],
    )


def test_subgraph_spec_names_of_other_kinds() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\ntype Query { a: Int }\ntype _Any { a: Int }\nenum _Entity { A }\ninterface _Service { a: Int }\nextend schema { mutation: M }\ntype M { a: Int }\n"),
        ],
        [
        ],
    )


def test_schema_extension_sets_query() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\nextend schema { query: Root }\ntype Root { _entities: Int a: Int }\n"),
        ],
        [
        ],
    )


def test_descriptions() raises:
    check(
        [
            sg("a", "\"\"\"schema\"\"\"\nschema { query: Query }\n\"type\"\ntype Query {\n  \"field\"\n  a(\"arg\" x: Int): Int\n}\n\"enum\"\nenum E {\n  \"value\"\n  A\n}\n\"input\"\ninput In {\n  \"input field\"\n  a: Int\n}\n\"directive\"\ndirective @d(\"arg\" x: Int) on OBJECT\n\"scalar\"\nscalar S\n\"union\"\nunion U = Query\n\"interface\"\ninterface I { a: Int }\n"),
        ],
        [
        ],
    )


def test_descriptions_v2() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\"type\"\ntype Query {\n  \"field\"\n  a(\"arg\" x: Int): Int\n}\n\"directive\"\ndirective @d(\"arg\" x: Int) on OBJECT\n"),
        ],
        [
        ],
    )


def test_own_link_import_scalar() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\ntype Query { a: Int }\nscalar link__Import\n"),
        ],
        [
        ],
    )


def test_own_link_directive() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\ntype Query { a: Int }\ndirective @link(url: String, as: String, import: [link__Import], for: link__Purpose) repeatable on SCHEMA\nscalar link__Import\nenum link__Purpose { SECURITY EXECUTION }\n"),
        ],
        [
        ],
    )


def test_own_link_directive_on_two_locations() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\ntype Query { a: Int }\ndirective @link(url: String, import: [link__Import]) repeatable on SCHEMA | OBJECT\nscalar link__Import\n"),
        ],
        [
        ],
    )


def test_only_subgraph_spec_types() raises:
    check(
        [
            sg("a", "scalar _Any\n"),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
