# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for Hive `sortSDL`.

The expected text is what `sortSDL` then graphql-js `print` produces.
The `test_upstream_*` cases port Hive Federation Composition v0.27.0
`__tests__/graphql/sort-sdl.spec.ts`; they compare the printed document.
"""

from gql_composition.sort_sdl import sort_sdl
from std.testing import TestSuite, assert_equal


def test_sort_sdl_orders_types_fields_and_trims_strings() raises:
    var result = sort_sdl(
        "type Query {\n"
        '  b: String @tag(name: "z") @deprecated(reason: " old ")\n'
        "  a(z: Int, a: String): User\n"
        "}\n"
        "type User implements Zoo & Able {\n"
        "  z: String\n"
        '  a: ID @requires(fields: "b  c")\n'
        "}\n"
        "interface Zoo { z: String b: String }\n"
        "interface Able { a: String }\n"
        "enum Color { Z A }\n"
        '"""\n'
        "  hello\n"
        '"""\n'
        "scalar Date\n"
        "input Filter { b: String a: Int }\n"
        "union Search = Zebra | Apple\n"
    )
    assert_equal(result, _SORTED)


comptime _SORTED = '''enum Color {
  A
  Z
}

input Filter {
  a: Int
  b: String
}

interface Able {
  a: String
}

interface Zoo {
  b: String
  z: String
}

type Query {
  a(z: Int, a: String): User
  b: String @deprecated(reason: "old") @tag(name: "z")
}

type User implements Able & Zoo {
  a: ID @requires(fields: "b  c")
  z: String
}

"""hello"""
scalar Date

union Search = Apple | Zebra'''


def test_upstream_object_types() raises:
    assert_equal(
        sort_sdl("type C\ntype B\ntype A"), "type A\n\ntype B\n\ntype C"
    )
    assert_equal(
        sort_sdl("type A { c: String b: String a: String }"),
        "type A {\n  a: String\n  b: String\n  c: String\n}",
    )
    assert_equal(sort_sdl("type A @c @b @a"), "type A @a @b @c")
    assert_equal(
        sort_sdl(
            "interface C\ninterface B\ninterface A\ntype D implements C & B & A"
        ),
        (
            "interface A\n\ninterface B\n\ninterface C\n\ntype D implements A &"
            " B & C"
        ),
    )


def test_upstream_scalars() raises:
    assert_equal(
        sort_sdl("scalar C\nscalar B\nscalar A"),
        "scalar A\n\nscalar B\n\nscalar C",
    )


def test_upstream_interface_type_definitions() raises:
    assert_equal(sort_sdl("interface A @c @b @a"), "interface A @a @b @c")
    assert_equal(
        sort_sdl("interface A { c: String b: String a: String }"),
        "interface A {\n  a: String\n  b: String\n  c: String\n}",
    )


def test_upstream_enum_type_and_value_definitions() raises:
    assert_equal(sort_sdl("enum A @c @b @a"), "enum A @a @b @c")
    assert_equal(sort_sdl("enum A { c b a }"), "enum A {\n  a\n  b\n  c\n}")
    assert_equal(sort_sdl("enum A { a @c @b @a }"), "enum A {\n  a @a @b @c\n}")


def test_upstream_union_type_definitions() raises:
    assert_equal(sort_sdl("union A @c @b @a"), "union A @a @b @c")
    assert_equal(sort_sdl("union A = C | B | A"), "union A = A | B | C")


def test_upstream_fields_directive_definitions_and_directives() raises:
    assert_equal(
        sort_sdl("type A { a: String @c @b @a }"),
        "type A {\n  a: String @a @b @c\n}",
    )
    assert_equal(
        sort_sdl(
            "directive @directive on OBJECT | FIELD_DEFINITION | INTERFACE"
        ),
        "directive @directive on FIELD_DEFINITION | INTERFACE | OBJECT",
    )
    assert_equal(
        sort_sdl("type A { a: String @directive(c: 1 b: 2 a: 3) }"),
        "type A {\n  a: String @directive(a: 3, b: 2, c: 1)\n}",
    )


def test_sort_sdl_keys_directives_by_argument_values() raises:
    var result = sort_sdl(
        "type T @d(a: ENUM) @d(a: 1) @d(a: 1.5) @d(a: true) @d(a: false)"
        ' @d(a: [1, 2]) @d(a: {x: 1}) @d(a: null) @d(a: "  ") @c'
        " @d(b: 1, a: 2) @d(a: 2, b: 1) { f: Int }"
    )
    assert_equal(
        result,
        (
            'type T @c @d(a: "") @d(a: 1) @d(a: [1, 2]) @d(a: 1.5) @d(a: 2, b:'
            " 1) @d(a: 2, b: 1) @d(a: ENUM) @d(a: null) @d(a: {x: 1}) @d(a:"
            " false) @d(a: true) {\n  f: Int\n}"
        ),
    )


def test_sort_sdl_sorts_directive_locations() raises:
    var result = sort_sdl(
        "directive @x(b: Int, a: Int) repeatable on OBJECT | FIELD_DEFINITION"
        " | ENUM\ndirective @w on SCHEMA"
    )
    assert_equal(
        result,
        (
            "directive @w on SCHEMA\n\ndirective @x(b: Int, a: Int) repeatable"
            " on ENUM | FIELD_DEFINITION | OBJECT"
        ),
    )


def test_sort_sdl_puts_a_prefix_first() raises:
    var result = sort_sdl("type Q { ab: Int a: Int abc: Int }")
    assert_equal(result, "type Q {\n  a: Int\n  ab: Int\n  abc: Int\n}")


def test_sort_sdl_keeps_the_order_of_extensions() raises:
    var result = sort_sdl(
        "schema @b @a { query: Q mutation: M }\n"
        "extend schema @z @y { subscription: S }\n"
        "scalar S @z @y\n"
        "extend scalar S @z @y\n"
        "extend type Q implements Z & Y @z @y { b: Int a: Int }\n"
        "extend interface I @z @y { b: Int a: Int }\n"
        "extend input N @z @y { b: Int a: Int }\n"
        "extend enum E @z @y { B A }\n"
        "extend union U @z @y = Z | Y\n"
        "enum F { A @z @y }"
    )
    assert_equal(result, _EXTENSIONS)


comptime _EXTENSIONS = """enum F {
  A @y @z
}

extend enum E @z @y {
  B
  A
}

extend input N @z @y {
  b: Int
  a: Int
}

extend interface I @z @y {
  b: Int
  a: Int
}

extend type Q implements Z & Y @z @y {
  b: Int
  a: Int
}

scalar S @y @z

extend scalar S @z @y

schema @a @b {
  query: Q
  mutation: M
}

extend schema @z @y {
  subscription: S
}

extend union U @z @y = Z | Y"""


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
