# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.lexicographic_sort_schema`, ported from graphql-js
16.14.2 `src/utilities/__tests__/lexicographicSortSchema-test.ts`.

More tests check what the printed SDL does not show: the sorted specified
directives, lookups by name in long member lists, the order of the
implementations of an interface, and that the source schema does not
change.
"""

from _helpers import dedent
from gql_schema.build import build_schema
from gql_schema.definition import NO_TYPE, Schema
from gql_schema.lexicographic_sort_schema import lexicographic_sort_schema
from gql_schema.print import print_introspection_schema, print_schema
from std.testing import TestSuite, assert_equal, assert_true


def sort_sdl(sdl: String) raises -> String:
    """Return SDL built, sorted and printed, as `sortSDL`."""
    return print_schema(lexicographic_sort_schema(build_schema(sdl)))


def test_sorts_fields() raises:
    assert_equal(
        sort_sdl(
            """
      input Bar {
        barB: String!
        barA: String
        barC: [String]
      }

      interface FooInterface {
        fooB: String!
        fooA: String
        fooC: [String]
      }

      type FooType implements FooInterface {
        fooC: [String]
        fooA: String
        fooB: String!
      }

      type Query {
        dummy(arg: Bar): FooType
      }
    """
        ),
        dedent(
            """
            input Bar {
              barA: String
              barB: String!
              barC: [String]
            }

            interface FooInterface {
              fooA: String
              fooB: String!
              fooC: [String]
            }

            type FooType implements FooInterface {
              fooA: String
              fooB: String!
              fooC: [String]
            }

            type Query {
              dummy(arg: Bar): FooType
            }
            """
        ),
    )


def test_sorts_implemented_interfaces() raises:
    assert_equal(
        sort_sdl(
            """
      interface FooA {
        dummy: String
      }

      interface FooB {
        dummy: String
      }

      interface FooC implements FooB & FooA {
        dummy: String
      }

      type Query implements FooB & FooA & FooC {
        dummy: String
      }
    """
        ),
        dedent(
            """
            interface FooA {
              dummy: String
            }

            interface FooB {
              dummy: String
            }

            interface FooC implements FooA & FooB {
              dummy: String
            }

            type Query implements FooA & FooB & FooC {
              dummy: String
            }
            """
        ),
    )


def test_sorts_types_in_union() raises:
    assert_equal(
        sort_sdl(
            """
      type FooA {
        dummy: String
      }

      type FooB {
        dummy: String
      }

      type FooC {
        dummy: String
      }

      union FooUnion = FooB | FooA | FooC

      type Query {
        dummy: FooUnion
      }
    """
        ),
        dedent(
            """
            type FooA {
              dummy: String
            }

            type FooB {
              dummy: String
            }

            type FooC {
              dummy: String
            }

            union FooUnion = FooA | FooB | FooC

            type Query {
              dummy: FooUnion
            }
            """
        ),
    )


def test_sorts_enum_values() raises:
    assert_equal(
        sort_sdl(
            """
      enum Foo {
        B
        C
        A
      }

      type Query {
        dummy: Foo
      }
    """
        ),
        dedent(
            """
            enum Foo {
              A
              B
              C
            }

            type Query {
              dummy: Foo
            }
            """
        ),
    )


def test_sorts_field_arguments() raises:
    assert_equal(
        sort_sdl(
            """
      type Query {
        dummy(argB: Int!, argA: String, argC: [Float]): ID
      }
    """
        ),
        dedent(
            """
            type Query {
              dummy(argA: String, argB: Int!, argC: [Float]): ID
            }
            """
        ),
    )


def test_sorts_types() raises:
    assert_equal(
        sort_sdl(
            """
      type Query {
        dummy(arg1: FooF, arg2: FooA, arg3: FooG): FooD
      }

      type FooC implements FooE {
        dummy: String
      }

      enum FooG {
        enumValue
      }

      scalar FooA

      input FooF {
        dummy: String
      }

      union FooD = FooC | FooB

      interface FooE {
        dummy: String
      }

      type FooB {
        dummy: String
      }
    """
        ),
        dedent(
            """
            scalar FooA

            type FooB {
              dummy: String
            }

            type FooC implements FooE {
              dummy: String
            }

            union FooD = FooB | FooC

            interface FooE {
              dummy: String
            }

            input FooF {
              dummy: String
            }

            enum FooG {
              enumValue
            }

            type Query {
              dummy(arg1: FooF, arg2: FooA, arg3: FooG): FooD
            }
            """
        ),
    )


def test_sorts_directive_arguments() raises:
    assert_equal(
        sort_sdl(
            """
      directive @test(argC: Float, argA: String, argB: Int) on FIELD

      type Query {
        dummy: String
      }
    """
        ),
        dedent(
            """
            directive @test(argA: String, argB: Int, argC: Float) on FIELD

            type Query {
              dummy: String
            }
            """
        ),
    )


def test_sorts_directive_locations() raises:
    assert_equal(
        sort_sdl(
            """
      directive @test(argC: Float, argA: String, argB: Int) on UNION | FIELD | ENUM

      type Query {
        dummy: String
      }
    """
        ),
        dedent(
            """
            directive @test(argA: String, argB: Int, argC: Float) on ENUM | FIELD | UNION

            type Query {
              dummy: String
            }
            """
        ),
    )


def test_sorts_directives() raises:
    assert_equal(
        sort_sdl(
            """
      directive @fooC on FIELD

      directive @fooB on UNION

      directive @fooA on ENUM

      type Query {
        dummy: String
      }
    """
        ),
        dedent(
            """
            directive @fooA on ENUM

            directive @fooB on UNION

            directive @fooC on FIELD

            type Query {
              dummy: String
            }
            """
        ),
    )


def test_sorts_recursive_types() raises:
    assert_equal(
        sort_sdl(
            """
      interface FooC {
        fooB: FooB
        fooA: FooA
        fooC: FooC
      }

      type FooB implements FooC {
        fooB: FooB
        fooA: FooA
      }

      type FooA implements FooC {
        fooB: FooB
        fooA: FooA
      }

      type Query {
        fooC: FooC
        fooB: FooB
        fooA: FooA
      }
    """
        ),
        dedent(
            """
            type FooA implements FooC {
              fooA: FooA
              fooB: FooB
            }

            type FooB implements FooC {
              fooA: FooA
              fooB: FooB
            }

            interface FooC {
              fooA: FooA
              fooB: FooB
              fooC: FooC
            }

            type Query {
              fooA: FooA
              fooB: FooB
              fooC: FooC
            }
            """
        ),
    )


def test_sorts_specified_directives() raises:
    var sdl = "type Query { a: Int }"
    var original = build_schema(sdl)
    var printed = print_introspection_schema(
        lexicographic_sort_schema(original)
    )
    var deprecated = printed.find("directive @deprecated")
    var include = printed.find("directive @include")
    var one_of = printed.find("directive @oneOf")
    var skip = printed.find("directive @skip")
    var specified_by = printed.find("directive @specifiedBy")
    assert_true(deprecated >= 0)
    assert_true(deprecated < include and include < one_of)
    assert_true(one_of < skip and skip < specified_by)
    assert_true(
        printed.find(
            "\n) on ARGUMENT_DEFINITION | DIRECTIVE_DEFINITION | ENUM_VALUE |"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n"
        )
        > 0
    )
    # The source schema keeps its order.
    assert_equal(
        print_introspection_schema(original),
        print_introspection_schema(build_schema(sdl)),
    )


def numbered(prefix: String, count: Int, suffix: String) -> String:
    """Return `prefix<n>suffix` for n from count - 1 down to 0."""
    var out = String("")
    var index = count - 1
    while index >= 0:
        out += prefix + String(index) + suffix
        index -= 1
    return out^


def test_finds_members_of_long_lists() raises:
    var sdl = (
        "directive @many("
        + numbered("d", 20, ": Int ")
        + ") on FIELD\n"
        + "interface I { a: Int }\n"
        + "type Zed implements I { a: Int }\n"
        + "type Alpha implements I { a: Int }\n"
        + "enum E { "
        + numbered("V", 20, " ")
        + "}\n"
        + "input In { "
        + numbered("f", 20, ": Int ")
        + "}\n"
        + "type Query { "
        + numbered("q", 19, ": Int ")
        + "big("
        + numbered("a", 20, ": Int ")
        + "): E i: I x(input: In): Int }\n"
    )
    var original = build_schema(sdl)
    var sorted = lexicographic_sort_schema(original)
    var query = sorted.type_named("Query")
    var big = sorted.field_named(query, "big")
    assert_equal(sorted.fields[big].name, "big")
    assert_equal(sorted.fields[sorted.field_named(query, "q7")].name, "q7")
    assert_equal(sorted.field_named(query, "missing"), NO_TYPE)
    var argument = sorted.argument_named(big, "a13")
    assert_equal(sorted.input_values[argument].name, "a13")
    var enum_type = sorted.type_named("E")
    var value = sorted.enum_value_named(enum_type, "V11")
    assert_equal(sorted.enum_values[value].name, "V11")
    var input = sorted.type_named("In")
    var field = sorted.input_field_named(input, "f15")
    assert_equal(sorted.input_values[field].name, "f15")
    var many = sorted.directive_named("many")
    assert_equal(sorted.directives[many].name, "many")
    var directive_arg = sorted.directive_argument_named(many, "d3")
    assert_equal(sorted.input_values[directive_arg].name, "d3")
    # Natural order: a number compares as a number.
    var first = sorted.fields[Int(sorted.types[query].fields.start)].name
    assert_equal(first, "big")
    assert_equal(
        sorted.input_values[Int(sorted.fields[big].arguments.start) + 2].name,
        "a2",
    )
    # The implementations of an interface are in name order.
    var objects = sorted.possible_types(sorted.type_named("I"))
    assert_equal(len(objects), 2)
    assert_equal(sorted.types[objects[0]].name, "Alpha")
    assert_equal(sorted.types[objects[1]].name, "Zed")
    # Sorting again changes nothing, and the source schema is unchanged.
    var printed = print_schema(sorted)
    assert_equal(print_schema(lexicographic_sort_schema(sorted)), printed)
    assert_equal(print_schema(original), print_schema(build_schema(sdl)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
