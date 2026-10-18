# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.rules_graphql`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_executable_locations() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @f on"
                    " FIELD_DEFINITION\nquery Q @f { a @f }\nfragment G on"
                    " Query @f { ... on Query @f { a } ...G @f }\nquery V($v:"
                    " String @f) { a }\nmutation M @f { a }\nsubscription S @f"
                    " { a }\n"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type String",
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on QUERY.',
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on FIELD.',
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " FRAGMENT_DEFINITION."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " INLINE_FRAGMENT."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " FRAGMENT_SPREAD."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " VARIABLE_DEFINITION."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on MUTATION.',
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " SUBSCRIPTION."
            ),
        ],
    )


def test_executable_arguments() raises:
    check(
        [
            sg(
                "a",
                "type Query { a(x: Int): String }\nquery Q { a(x: 1, x: 2) }\n",
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] There can be only one argument named "x".',
        ],
    )


def test_type_system_locations() raises:
    check(
        [
            sg(
                "a",
                (
                    "directive @f on FIELD_DEFINITION\ntype Query { a: String"
                    " }\nscalar S @f\nextend scalar S @f\ntype O @f { a(x: Int"
                    " @f): Int }\nextend type O @f\ninterface I @f { a: Int"
                    " }\nextend interface I @f\nunion U @f = O\nextend union U"
                    " @f\nenum E @f { A @f }\nextend enum E @f\ninput In @f {"
                    " x: Int @f }\nextend input In @f\nextend input In { y: Int"
                    " @f }\nschema @f { query: Query }\nextend schema"
                    " @f\ndirective @g(x: Int @f) on OBJECT\n"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on SCHEMA.',
            (
                '[INVALID_GRAPHQL] [a] The directive "@f" can only be used once'
                " at this location."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on SCHEMA.',
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " ARGUMENT_DEFINITION."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on SCALAR.',
            (
                '[INVALID_GRAPHQL] [a] The directive "@f" can only be used once'
                " at this location."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on SCALAR.',
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on OBJECT.',
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " ARGUMENT_DEFINITION."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@f" can only be used once'
                " at this location."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on OBJECT.',
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " INTERFACE."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@f" can only be used once'
                " at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " INTERFACE."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on UNION.',
            (
                '[INVALID_GRAPHQL] [a] The directive "@f" can only be used once'
                " at this location."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on UNION.',
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on ENUM.',
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " ENUM_VALUE."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@f" can only be used once'
                " at this location."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on ENUM.',
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " INPUT_OBJECT."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " INPUT_FIELD_DEFINITION."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@f" can only be used once'
                " at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " INPUT_OBJECT."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@f" may not be used on'
                " ARGUMENT_DEFINITION."
            ),
        ],
    )


def test_lone_schema_definition() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\nschema { query: Query }\nschema"
                    " { query: Query }\n"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Must provide only one schema definition.",
            "[INVALID_GRAPHQL] [a] There can be only one query type in schema.",
        ],
    )


def test_unique_operation_types() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ntype M { a: Int }\nschema {"
                    " query: Query mutation: M mutation: M }\nextend schema {"
                    " query: Query subscription: M subscription: M }\n"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] There can be only one mutation type in"
                " schema."
            ),
            "[INVALID_GRAPHQL] [a] There can be only one query type in schema.",
            (
                "[INVALID_GRAPHQL] [a] There can be only one subscription type"
                " in schema."
            ),
        ],
    )


def test_unique_type_names() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ntype T { a: Int }\ntype T { b:"
                    " Int }\nscalar S\nscalar S\ninterface I { a: Int"
                    " }\ninterface I { b: Int }\nunion U = T\nunion U = T\nenum"
                    " E { A }\nenum E { B }\ninput In { a: Int }\ninput In { b:"
                    " Int }\n"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] There can be only one type named "T".',
            '[INVALID_GRAPHQL] [a] There can be only one type named "S".',
            '[INVALID_GRAPHQL] [a] There can be only one type named "I".',
            '[INVALID_GRAPHQL] [a] There can be only one type named "U".',
            '[INVALID_GRAPHQL] [a] There can be only one type named "E".',
            '[INVALID_GRAPHQL] [a] There can be only one type named "In".',
        ],
    )


def test_implements_non_interface() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ntype T implements O & S & U & E"
                    " & In & I & J & Missing { a: Int }\nextend type T"
                    " implements O\ntype O { a: Int }\nscalar S\nunion U ="
                    " O\nenum E { A }\ninput In { a: Int }\ninterface I { a:"
                    " Int }\nextend interface J { a: Int }\n"
                ),
            ),
        ],
        [
            "THROWS Expected O to be an object type",
        ],
    )


def test_unique_members() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\nenum E { A A }\nextend enum E {"
                    " A B }\ninput In { a: Int a: Int }\nextend input In { a:"
                    " Int }\ninterface I { a: Int a: Int }\nextend interface I"
                    " { a: Int }\ntype T { a: Int a: Int }\nextend type T { a:"
                    " Int }\nenum T2 { a }\ntype T2X { a: Int }\n"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Enum value "E.A" can only be defined once.',
            '[INVALID_GRAPHQL] [a] Enum value "E.A" can only be defined once.',
            '[INVALID_GRAPHQL] [a] Field "In.a" can only be defined once.',
            '[INVALID_GRAPHQL] [a] Field "In.a" can only be defined once.',
            '[INVALID_GRAPHQL] [a] Field "I.a" can only be defined once.',
            '[INVALID_GRAPHQL] [a] Field "I.a" can only be defined once.',
            '[INVALID_GRAPHQL] [a] Field "T.a" can only be defined once.',
            '[INVALID_GRAPHQL] [a] Field "T.a" can only be defined once.',
        ],
    )


def test_unique_argument_definitions() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @d(a: Int, a: Int) on"
                    " OBJECT\ntype T { f(a: Int, a: Int, b: Int): Int g: Int"
                    " }\nextend type T { h(a: Int, a: Int): Int }\ninterface I"
                    " { f(a: Int, a: Int): Int }\nextend interface I { g(b:"
                    " Int, b: Int): Int }\n"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Argument "@d(a:)" can only be defined once.',
            (
                '[INVALID_GRAPHQL] [a] Argument "T.f(a:)" can only be defined'
                " once."
            ),
            (
                '[INVALID_GRAPHQL] [a] Argument "T.h(a:)" can only be defined'
                " once."
            ),
            (
                '[INVALID_GRAPHQL] [a] Argument "I.f(a:)" can only be defined'
                " once."
            ),
            (
                '[INVALID_GRAPHQL] [a] Argument "I.g(b:)" can only be defined'
                " once."
            ),
        ],
    )


def test_unique_directives_per_location() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @o on OBJECT | SCHEMA"
                    " | FIELD_DEFINITION | ENUM_VALUE |"
                    " ARGUMENT_DEFINITION\ndirective @r repeatable on OBJECT |"
                    " SCHEMA\ntype T @o @o @r @r { a: Int @o @o b(x: Int @o"
                    " @o): Int }\nextend type T @o\nschema @o @r { query: Query"
                    " }\nextend schema @o @r\nenum E { A @o @o }\n"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] The directive "@o" can only be used once'
                " at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@o" can only be used once'
                " at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@o" can only be used once'
                " at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@o" can only be used once'
                " at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@o" can only be used once'
                " at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@o" can only be used once'
                " at this location."
            ),
        ],
    )


def test_unknown_and_duplicate_arguments() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @d(a: Int) on"
                    " OBJECT\ndirective @n on OBJECT\ntype T @d(a: 1, a: 2, b:"
                    ' 3) @n(x: 1) { a: Int @deprecated(reason: "x", reason:'
                    ' "y", other: 1) }\n'
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown argument "b" on directive "@d".',
            '[INVALID_GRAPHQL] [a] There can be only one argument named "a".',
            '[INVALID_GRAPHQL] [a] Unknown argument "x" on directive "@n".',
            (
                "[INVALID_GRAPHQL] [a] There can be only one argument named"
                ' "reason".'
            ),
        ],
    )


def test_unique_input_field_names() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @d(a: In) on"
                    " OBJECT\ninput In { x: Int y: In }\ntype T @d(a: { x: 1,"
                    " x: 2, y: { x: 1, x: 2 } }) { a: Int }\ntype T2 @d(a: { x:"
                    " 1, y: { x: 1 }, y: { x: 3 } }) { a: Int }\n"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] There can be only one input field named"
                ' "x".'
            ),
            (
                "[INVALID_GRAPHQL] [a] There can be only one input field named"
                ' "x".'
            ),
            (
                "[INVALID_GRAPHQL] [a] There can be only one input field named"
                ' "y".'
            ),
        ],
    )


def test_unique_directive_names() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @d on"
                    " OBJECT\ndirective @d on OBJECT\ndirective @e on OBJECT\n"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] There can be only one directive named "@d".',
        ],
    )


def test_required_arguments() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @d(a: Int!, b: String!"
                    ' = "x", c: [Int!]!, d: Int) on OBJECT |'
                    " FIELD_DEFINITION\ntype T @d { a: Int @d(a: 1, c: [1]) b:"
                    " Int @d(d: 1) }\n"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@d" argument "a" of type'
                ' "Int!" is required, but it was not provided.'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@d" argument "c" of type'
                ' "[Int!]!" is required, but it was not provided.'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@d" argument "a" of type'
                ' "Int!" is required, but it was not provided.'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@d" argument "c" of type'
                ' "[Int!]!" is required, but it was not provided.'
            ),
        ],
    )


def test_argument_values() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @v(a: Int, b: [Int],"
                    " c: E, d: In, e: Float, g: [Int]!, h: Int!, i: Unknown, j:"
                    " S, k: Q2) on OBJECT\nenum E { A }\ninput In { x: Int"
                    " }\nscalar S\ntype Q2 { a: Int }\ntype T1 @v(a: null, b:"
                    " [], c: 1, d: 1, e: 1, g: [], h: null, i: 1, j: { x: 1 },"
                    ' k: 1) { a: Int }\ntype T2 @v(a: "s", b: ["s"], c: A, d: {'
                    " x: 1 }, e: 1.5, g: 1, h: 1, j: 1, k: { a: 1 }) { a: Int"
                    ' }\ntype T3 @v(a: 1.5, b: 1, c: "A", d: [1], e: "x", g:'
                    " [[1]], h: [], k: A) { a: Int }\ntype T4 @v(a: true, b:"
                    " [true], c: [A], d: A, e: [], g: null, h: 1) { a: Int }\n"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Unknown",
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(a:)" of type "Int"'
                ' in application of "@v" to "T1".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(c:)" of type "E"'
                ' in application of "@v" to "T1".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(d:)" of type "In"'
                ' in application of "@v" to "T1".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(k:)" of type "Q2"'
                ' in application of "@v" to "T1".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(a:)" of type "Int"'
                ' in application of "@v" to "T2".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(b:)" of type'
                ' "[Int]" in application of "@v" to "T2".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(a:)" of type "Int"'
                ' in application of "@v" to "T3".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(c:)" of type "E"'
                ' in application of "@v" to "T3".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(d:)" of type "In"'
                ' in application of "@v" to "T3".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(e:)" of type'
                ' "Float" in application of "@v" to "T3".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(h:)" of type'
                ' "Int!" in application of "@v" to "T3".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(k:)" of type "Q2"'
                ' in application of "@v" to "T3".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(a:)" of type "Int"'
                ' in application of "@v" to "T4".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(b:)" of type'
                ' "[Int]" in application of "@v" to "T4".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(d:)" of type "In"'
                ' in application of "@v" to "T4".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(e:)" of type'
                ' "Float" in application of "@v" to "T4".'
            ),
            (
                "[INVALID_GRAPHQL] [a] The type of @v(k:) must be Input Type"
                " but got: Q2."
            ),
        ],
    )


def test_argument_value_coordinates() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @d(a: Int) on SCHEMA |"
                    " FIELD_DEFINITION | ARGUMENT_DEFINITION | OBJECT\ntype T {"
                    ' f(x: Int @d(a: "s")): Int @d(a: "t") }\nextend type T'
                    ' @d(a: "u")\nschema @d(a: "v") { query: Query }\nextend'
                    ' schema @d(a: "w")\n'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@d(a:)" of type "Int"'
                ' in application of "@d" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@d" can only be used once'
                " at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@d(a:)" of type "Int"'
                ' in application of "@d" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@d(a:)" of type "Int"'
                ' in application of "@d" to "T.f.x".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@d(a:)" of type "Int"'
                ' in application of "@d" to "T.f".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@d(a:)" of type "Int"'
                ' in application of "@d" to "T".'
            ),
        ],
    )


def test_specified_directives() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ntype T { a: Int"
                    ' @deprecated(reason: 1) @specifiedBy(url: "x") }\nscalar S'
                    ' @specifiedBy(url: "x") @deprecated\ninput In @oneOf { a:'
                    " Int }\nenum E { A @deprecated B @include(if: true) }\n"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@specifiedBy" may not be used'
                " on FIELD_DEFINITION."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@deprecated" may not be used'
                " on SCALAR."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@include" may not be used on'
                " ENUM_VALUE."
            ),
        ],
    )


def test_redefined_specified_directive() raises:
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @deprecated(reason:"
                    " String) on OBJECT\ntype T @deprecated { a: Int"
                    " @deprecated }\n"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@deprecated" may not be used'
                " on FIELD_DEFINITION."
            ),
        ],
    )


def test_argument_values_of_extended_types() raises:
    # The last definition of a type sets its kind: an extended enum still
    # wants an enum value, and an extended scalar takes any value.
    check(
        [
            sg(
                "a",
                (
                    "type Query { a: String }\ndirective @v(c: E, j: S) on"
                    " OBJECT\nenum E { A }\nextend enum E { B }\nscalar"
                    " S\nextend scalar S @v\ntype T1 @v(c: 1, j: 1) { a: Int"
                    " }\n"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Directive "@v" may not be used on SCALAR.',
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@v(c:)" of type "E"'
                ' in application of "@v" to "T1".'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
