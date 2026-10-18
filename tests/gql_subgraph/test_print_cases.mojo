# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `_service.sdl` and `print_subgraph_schema` on SDL that the
upstream suites do not cover: extensions before definitions, directive
arguments, definitions of the graphql-js directives, schema extensions,
the link specification, descriptions and the order of `_Entity`.

`@apollo/subgraph` 2.14.4 has no tests of these cases. The expected text
comes from `@apollo/subgraph` 2.14.4 itself, run in Node.js with the same
SDL: `printSubgraphSchema`, `_service.sdl`, and graphql-js `printType` of
the query type of the executable schema.
"""

from std.testing import TestSuite, assert_equal, assert_true
from _helpers import assert_service_sdl, subgraph, type_sdl
from gql_subgraph.print_subgraph_schema import print_subgraph_schema

comptime FED = 'extend schema @link(url: "https://specs.apollo.dev/federation/'
comptime QUERY = "type Query {\n  a: Int\n}"


def _print(sdl: String) raises -> String:
    return print_subgraph_schema(subgraph(sdl))


def test_an_import_without_an_alias() raises:
    var schema = subgraph(
        FED
        + 'v2.0", import: [{ name: "@key" }]) type Query { a: Int } type T'
        ' @key(fields: "id") { id: ID }'
    )
    assert_equal(
        print_subgraph_schema(schema),
        (
            'extend schema\n  @link(url: "https://specs.apollo.dev/federation/'
            'v2.0", import: [{name: "@key"}])\n\n'
            + QUERY
            + '\n\ntype T\n  @key(fields: "id")\n{\n  id: ID\n}'
        ),
    )
    assert_true(schema.sdl.endswith("\n\nunion _Entity = T"))


def test_a_custom_directive_on_the_schema() raises:
    assert_equal(
        _print(
            "directive @custom on SCHEMA\nschema @custom { query: Query } type"
            " Query { a: Int }"
        ),
        (
            "schema\n  @custom\n{\n  query: Query\n}\n\ndirective @custom on"
            " SCHEMA\n\n"
            + QUERY
        ),
    )


def test_extensions_before_their_definitions() raises:
    assert_equal(
        _print(
            "directive @custom on SCALAR | INTERFACE | UNION | ENUM |"
            " INPUT_OBJECT\nextend scalar X @custom\nscalar X\nextend"
            " interface I @custom\ninterface I { a: Int }\nextend union U"
            " @custom\nunion U = Query\nextend enum E @custom\nenum E {"
            " A }\nextend input In @custom\ninput In { a: Int }\ntype Query {"
            " a: Int x: X i: I u: U e: E f(in: In): Int }"
        ),
        (
            "directive @custom on SCALAR | INTERFACE | UNION | ENUM |"
            " INPUT_OBJECT\n\nscalar X\n\nextend scalar X\n  @custom\n\n"
            "interface I {\n  a: Int\n}\n\nextend interface I\n  @custom\n\n"
            "union U = Query\n\nextend union U\n  @custom\n\nenum E {\n  A\n}"
            "\n\nextend enum E\n  @custom\n\ninput In {\n  a: Int\n}\n\n"
            "extend input In\n  @custom\n\ntype Query {\n  a: Int\n  x: X\n"
            "  i: I\n  u: U\n  e: E\n  f(in: In): Int\n}"
        ),
    )


def test_directive_arguments_of_each_kind() raises:
    assert_equal(
        _print(
            "directive @custom(a: String, b: [Int], c: Point) on"
            " FIELD_DEFINITION\ninput Point { x: Int y: Int }\ntype Query { a:"
            " Int @custom(a: null, b: [1, 2], c: { x: 1, y: 2 }) }"
        ),
        (
            "directive @custom(a: String, b: [Int], c: Point) on"
            " FIELD_DEFINITION\n\ninput Point {\n  x: Int\n  y: Int\n}\n\ntype"
            " Query {\n  a: Int @custom(a: null, b: [1, 2], c: {x: 1, y:"
            " 2})\n}"
        ),
    )


def test_definitions_of_the_graphql_directives() raises:
    assert_equal(
        _print(
            "directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD |"
            " INLINE_FRAGMENT\ndirective @include(if: Boolean!) on FIELD |"
            " FRAGMENT_SPREAD | INLINE_FRAGMENT\ndirective @specifiedBy(url:"
            " String!) on SCALAR\ndirective @oneOf on INPUT_OBJECT\ntype"
            " Query { a: Int }"
        ),
        QUERY,
    )
    var schema = subgraph(
        'directive @deprecated(reason: String = "No longer supported") on'
        " FIELD_DEFINITION | ENUM_VALUE | ARGUMENT_DEFINITION |"
        " INPUT_FIELD_DEFINITION\n"
        + FED
        + 'v2.0", import: ["@key"])\ntype Query { a: Int @deprecated }'
    )
    assert_equal(
        print_subgraph_schema(schema),
        (
            'extend schema\n  @link(url: "https://specs.apollo.dev/federation/'
            'v2.0", import: ["@key"])\n\ntype Query {\n  a: Int @deprecated\n}'
        ),
    )
    assert_true(
        '\n\ndirective @deprecated(reason: String = "No longer supported") on'
        in schema.sdl
    )


def test_a_root_type_in_a_schema_extension() raises:
    assert_equal(
        _print(
            "extend schema { mutation: M } type Query { a: Int } type M {"
            " b: Int }"
        ),
        (
            "schema {\n  query: Query\n}\n\nextend schema {\n  mutation: M\n}"
            "\n\n"
            + QUERY
            + "\n\ntype M {\n  b: Int\n}"
        ),
    )


comptime LINK_SPEC = '@link(url: "https://specs.apollo.dev/link/v1.0")'


def test_the_definitions_of_the_link_specification() raises:
    assert_equal(
        _print(
            "extend schema "
            + LINK_SPEC
            + " @link(url:"
            ' "https://specs.apollo.dev/federation/v2.0", import:'
            ' ["@key"])\ndirective @link(url: String, as: String, for:'
            " link__Purpose, import: [link__Import]) repeatable on"
            " SCHEMA\nscalar link__Import\nenum link__Purpose { SECURITY"
            " EXECUTION }\ntype Query { a: Int }"
        ),
        (
            'extend schema\n  @link(url: "https://specs.apollo.dev/federation/'
            'v2.0", import: ["@key"])\n\n'
            + QUERY
        ),
    )


def test_a_link_to_the_link_specification_alone() raises:
    var schema = subgraph(
        "extend schema " + LINK_SPEC + " type Query { a: Int }"
    )
    assert_equal(print_subgraph_schema(schema), QUERY)
    assert_service_sdl(
        schema,
        (
            "extend schema\n  "
            + LINK_SPEC
            + "\n\ndirective @link(url: String, as: String, for:"
            " link__Purpose, import: [link__Import]) repeatable on"
            " SCHEMA\n\ndirective @key(fields: _FieldSet!, resolvable: Boolean"
            " = true) repeatable on OBJECT | INTERFACE\n\ndirective"
            " @requires(fields: _FieldSet!) on FIELD_DEFINITION\n\ndirective"
            " @provides(fields: _FieldSet!) on FIELD_DEFINITION\n\ndirective"
            " @external(reason: String) on OBJECT |"
            " FIELD_DEFINITION\n\ndirective @tag(name: String!) repeatable on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | UNION |"
            " ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT"
            " | INPUT_FIELD_DEFINITION\n\ndirective @extends on OBJECT |"
            " INTERFACE\n\ntype Query {\n  a: Int\n  _service:"
            ' _Service!\n}\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve"
            ' fields.\n  """\n  SECURITY\n\n  """\n  `EXECUTION` features'
            " provide metadata necessary for operation execution.\n "
            ' """\n  EXECUTION\n}\n\nscalar link__Import\n\nscalar'
            " _FieldSet\n\nscalar _Any\n\ntype _Service {\n  sdl: String\n}"
        ),
    )


def test_the_order_of_the_entities() raises:
    var schema = subgraph(
        'type Query { a: Int } type b1 @key(fields: "id") { id: ID } type B1'
        ' @key(fields: "id") { id: ID } type _b @key(fields: "id") { id: ID }'
        ' type B0 @key(fields: "id") { id: ID } type Ba @key(fields: "id") {'
        ' id: ID } type bA @key(fields: "id") { id: ID } type b @key(fields:'
        ' "id") { id: ID }'
    )
    assert_true(
        schema.sdl.endswith(
            "\n\nunion _Entity = _b | b | B0 | b1 | B1 | bA | Ba"
        )
    )


def test_descriptions_that_a_block_string_cannot_hold() raises:
    var schema = subgraph(
        '"\\nschema description"\nschema { query: Q }\n"\\ndirective'
        ' description"\ndirective @d("\\narg" a: Int) on'
        ' FIELD_DEFINITION\n"\\nenum"\nenum E { "\\nvalue" A }\ntype Q {'
        ' "\\nfield" a: E @d }'
    )
    assert_equal(
        print_subgraph_schema(schema),
        (
            '"""schema description"""\nschema {\n  query: Q\n}\n\n"""directive'
            ' description"""\ndirective @d(\n  """arg"""\n  a: Int\n) on'
            ' FIELD_DEFINITION\n\n"""enum"""\nenum E {\n  """value"""\n '
            ' A\n}\n\ntype Q {\n  """field"""\n  a: E @d\n}'
        ),
    )
    assert_true(
        schema.sdl.startswith(
            '"""\n\nschema description\n"""\nschema {\n  query: Q\n}\n\n'
            '"""\n\ndirective description\n"""\ndirective @d(\n  """\n  \n '
            ' arg\n  """\n  a: Int\n) on FIELD_DEFINITION\n\n'
        )
    )
    assert_equal(
        type_sdl(schema, "Q"),
        'type Q {\n  """field"""\n  a: E\n  _service: _Service!\n}',
    )


def test_a_description_that_a_block_string_holds() raises:
    assert_equal(
        _print('"plain" type Query { a: Int }'), '"""plain"""\n' + QUERY
    )


def test_a_description_with_a_control_character() raises:
    var schema = subgraph(
        '"a\\u0001b"\ntype Query { a("a\\u0001b" x: Int): Int }'
    )
    assert_equal(
        print_subgraph_schema(schema),
        (
            '"""a\x01b"""\ntype Query {\n  a(\n    """a\x01b"""\n    x: Int\n '
            " ): Int\n}"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
