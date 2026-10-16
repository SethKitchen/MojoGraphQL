# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.validate_state`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_root_types_not_objects() raises:
    check(
        [
            sg("a", "schema { query: I mutation: U subscription: E }\ninterface I { a: Int }\nunion U = T\nenum E { A }\ntype T { a: Int }\n"),
        ],
        [
        ],
    )


def test_root_types_shared() raises:
    check(
        [
            sg("a", "schema { query: T mutation: T subscription: T }\ntype T { a: Int }\n"),
        ],
        [
        ],
    )


def test_root_types_two_shared() raises:
    check(
        [
            sg("a", "schema { query: T mutation: M subscription: M }\ntype T { a: Int }\ntype M { a: Int }\n"),
        ],
        [
        ],
    )


def test_root_types_shared_v2() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\nschema { query: T mutation: T }\ntype T { a: Int }\n"),
        ],
        [
        ],
    )


def test_root_type_unknown() raises:
    check(
        [
            sg("a", "schema { query: Missing }\ntype Query { a: String }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Cannot set schema query root to unknown type Missing",
            "[ROOT_QUERY_USED] [a] The schema has a type named \"Query\" but it is not set as the query root type (\"Missing\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
            "[INVALID_GRAPHQL] [a] Unknown type Missing",
        ],
    )


def test_directive_definitions() raises:
    check(
        [
            sg("a", "type Query { a: String }\ndirective @__d(__a: Int, b: T, c: Unknown, d: [In!]!, e: E, f: S, g: Int! @deprecated, h: Int! = 1 @deprecated, i: Int @deprecated, j: link__Import, k: link__Purpose) on OBJECT\ntype T { a: Int }\ninput In { a: Int }\nenum E { A }\nscalar S\ndirective @link(url: String, import: [link__Import]) repeatable on SCHEMA\nscalar link__Import\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Unknown",
            "[INVALID_GRAPHQL] [a] Unknown type link__Purpose",
            "[INVALID_GRAPHQL] [a] Name \"__d\" must not begin with \"__\", which is reserved by GraphQL introspection.",
            "[INVALID_GRAPHQL] [a] Name \"__a\" must not begin with \"__\", which is reserved by GraphQL introspection.",
            "[INVALID_GRAPHQL] [a] The type of @__d(b:) must be Input Type but got: T.",
            "[INVALID_GRAPHQL] [a] Name \"__d\" must not begin with \"__\", which is reserved by GraphQL introspection.",
        ],
    )


def test_type_names() raises:
    check(
        [
            sg("a", "type Query { a: String }\ntype __T { a: Int }\nscalar __S\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Name \"__T\" must not begin with \"__\", which is reserved by GraphQL introspection.",
            "[INVALID_GRAPHQL] [a] Name \"__S\" must not begin with \"__\", which is reserved by GraphQL introspection.",
        ],
    )


def test_empty_types() raises:
    check(
        [
            sg("a", "type Query { a: String }\ntype T\ninterface I\nunion U\nenum E\ninput In\nextend type Query { b: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Type T must define one or more fields.",
            "[INVALID_GRAPHQL] [a] Type I must define one or more fields.",
            "[INVALID_GRAPHQL] [a] Union type U must define one or more member types.",
            "[INVALID_GRAPHQL] [a] Enum type E must define one or more values.",
            "[INVALID_GRAPHQL] [a] Input Object type In must define one or more fields.",
        ],
    )


def test_empty_root_type() raises:
    check(
        [
            sg("a", "schema { query: Q mutation: M subscription: S }\ntype Q\ntype M\ntype S\n"),
        ],
        [
        ],
    )


def test_field_types() raises:
    check(
        [
            sg("a", "type Query { a: String }\ntype T { __a: Int b: In c: Unknown d(x: T, y: [T], z: T!, w: Unknown, __v: Int, u: In): Int e: [In!]! f: E g: S }\ninterface I { a: In }\ninput In { a: Int }\nenum E { A }\nscalar S\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Unknown",
            "[INVALID_GRAPHQL] [a] Unknown type Unknown",
            "[INVALID_GRAPHQL] [a] Name \"__a\" must not begin with \"__\", which is reserved by GraphQL introspection.",
            "[INVALID_GRAPHQL] [a] The type of \"T.b\" must be Output Type but got: \"In\".",
            "[INVALID_GRAPHQL] [a] The type of \"T.d(x:)\" must be Input Type but got \"T\".",
            "[INVALID_GRAPHQL] [a] The type of \"T.d(y:)\" must be Input Type but got \"[T]\", a ListType.",
            "[INVALID_GRAPHQL] [a] The type of \"T.d(z:)\" must be Input Type but got \"T!\", a NonNullType.",
            "[INVALID_GRAPHQL] [a] Name \"__v\" must not begin with \"__\", which is reserved by GraphQL introspection.",
            "[INVALID_GRAPHQL] [a] The type of \"T.e\" must be Output Type but got: \"[In!]!\".",
            "[INVALID_GRAPHQL] [a] The type of \"I.a\" must be Output Type but got: \"In\".",
        ],
    )


def test_deprecated_required_arguments() raises:
    check(
        [
            sg("a", "type Query { a: String }\ntype T { a(x: Int! @deprecated, y: Int! = 1 @deprecated, z: Int @deprecated, w: Int!): Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Required argument T.a(x:) cannot be deprecated.",
        ],
    )


def test_default_values() raises:
    check(
        [
            sg("a", "type Query { a: String }\nenum E { A B }\ninput In { x: Int y: E! z: [Int] }\nscalar S\ntype T { a(a1: Int = 1, a2: Int = 2147483648, a3: Int = -2147483648, a4: Int = -2147483649, a5: Int = 1.5, a6: Int = 12345678901, b1: Float = 1, b2: Float = 1.5, b3: Float = \"x\", c1: String = \"s\", c2: String = 1, d1: Boolean = true, d2: Boolean = 1, e1: ID = \"x\", e2: ID = 1, e3: ID = 1.5, f1: Int! = null, f2: Int = null, f3: [Int] = [1, 2], f4: [Int] = [1, \"x\"], f5: [Int] = 1, f6: [Int] = \"x\", f7: [[Int]] = [[1], [\"x\"]], g1: S = { any: 1 }, g2: In = { x: 1, y: A }, g3: In = { x: \"s\" }, g4: In = { q: 1 }, g5: In = 1, g6: In = {}, h1: E = A, h2: E = C, h3: E = \"A\", h4: E = \"C\", h5: E = 1, i1: Unknown = 1, j1: [In] = [{ x: 1 }], k1: E! = A): Int }\ninput In2 { a: Int = \"x\" b: E = B c: Int! = null }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Unknown",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: 2147483648) provided for argument T.a(a2:) of type Int.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: -2147483649) provided for argument T.a(a4:) of type Int.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: 1.5) provided for argument T.a(a5:) of type Int.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: 12345678901) provided for argument T.a(a6:) of type Int.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: \"x\") provided for argument T.a(b3:) of type Float.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: 1) provided for argument T.a(c2:) of type String.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: 1) provided for argument T.a(d2:) of type Boolean.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: 1.5) provided for argument T.a(e3:) of type ID.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: null) provided for argument T.a(f1:) of type Int!.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: [1, \"x\"]) provided for argument T.a(f4:) of type [Int].",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: \"x\") provided for argument T.a(f6:) of type [Int].",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: [[1], [\"x\"]]) provided for argument T.a(f7:) of type [[Int]].",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: {x: \"s\"}) provided for argument T.a(g3:) of type In.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: {q: 1}) provided for argument T.a(g4:) of type In.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: 1) provided for argument T.a(g5:) of type In.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: C) provided for argument T.a(h2:) of type E.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: \"C\") provided for argument T.a(h4:) of type E.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: 1) provided for argument T.a(h5:) of type E.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: \"x\") provided for input field In2.a of type Int.",
            "[INVALID_GRAPHQL] [a] Invalid default value (got: null) provided for input field In2.c of type Int!.",
        ],
    )


def test_input_fields() raises:
    check(
        [
            sg("a", "type Query { a: String }\ninput In { __a: Int b: T c: [T] d: T! e: Unknown f: Int! @deprecated g: Int! = 1 @deprecated h: Int @deprecated i: In2 }\ninput In2 { a: Int }\ntype T { a: Int }\ntype Use { a(x: In): Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Unknown",
            "[INVALID_GRAPHQL] [a] Name \"__a\" must not begin with \"__\", which is reserved by GraphQL introspection.",
            "[INVALID_GRAPHQL] [a] The type of In.b must be Input Type but got \"T\".",
            "[INVALID_GRAPHQL] [a] The type of In.c must be Input Type but got \"[T]\", a ListType.",
            "[INVALID_GRAPHQL] [a] The type of In.d must be Input Type but got \"T!\", a NonNullType.",
            "[INVALID_GRAPHQL] [a] Required input field In.f cannot be deprecated.",
        ],
    )


def test_union_members() raises:
    check(
        [
            sg("a", "type Query { a: String }\nunion U = T | I | E | Missing\nextend union U = T\ntype T { a: Int }\ninterface I { a: Int }\nenum E { A }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Missing",
            "[INVALID_GRAPHQL] [a] Union type U can only include Object types, it cannot include I.",
            "[INVALID_GRAPHQL] [a] Union type U can only include Object types, it cannot include E.",
            "[INVALID_GRAPHQL] [a] Union type U can only include Object types, it cannot include Missing.",
        ],
    )


def test_enum_values() raises:
    check(
        [
            sg("a", "type Query { a: String }\nenum E { __A B }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Name \"__A\" must not begin with \"__\", which is reserved by GraphQL introspection.",
        ],
    )


def test_interfaces() raises:
    check(
        [
            sg("a", "type Query { a: String }\ntype T implements I & O & T & Missing { a: Int }\ninterface I { a: Int }\ntype O { a: Int }\ninterface J implements J { a: Int }\n"),
        ],
        [
            "THROWS Expected T to be an interface type",
        ],
    )


def test_transitive_interfaces() raises:
    check(
        [
            sg("a", "type Query { a: String }\ninterface A { a: Int }\ninterface B implements A { a: Int }\ntype T implements B { a: Int }\ninterface C implements D { a: Int }\ninterface D implements C { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Type T must implement A because it is implemented by B.",
            "[INVALID_GRAPHQL] [a] Type C cannot implement D because it would create a circular reference.",
            "[INVALID_GRAPHQL] [a] Type D cannot implement C because it would create a circular reference.",
        ],
    )


def test_interface_fields() raises:
    check(
        [
            sg("a", "type Query { a: String }\ninterface I { a: Int b: Int! c: [Int] d: [Int!]! e: I f: U g(x: Int, y: String): Int h: Int missing: Int k: [[Int]] l: I! m: J }\ninterface J { a: Int }\nunion U = T | O\ntype O { a: Int }\ntype T implements I & J { a: Int! b: Int c: Int d: [Int]! e: T f: O g(x: String, z: Int!, w: Int): Int h(q: Int! = 1, r: Int!): Int k: [Int] l: T! m: O }\ninterface K implements I & J { a: String b: Int! c: [Int!] d: [Int!]! e: K f: U g(x: Int, y: String): Int h: Int missing: Int k: [[Int!]!] l: I m: K }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Interface field I.b expects type Int! but T.b of type Int is not a proper subtype.",
            "[INVALID_GRAPHQL] [a] Interface field I.c expects type [Int] but T.c of type Int is not a proper subtype.",
            "[INVALID_GRAPHQL] [a] Interface field I.d expects type [Int!]! but T.d of type [Int]! is not a proper subtype.",
            "[INVALID_GRAPHQL] [a] Interface field argument I.g(x:) expects type Int but T.g(x:) is type String.",
            "[INVALID_GRAPHQL] [a] Interface field argument I.g(y:) expected but T.g does not provide it.",
            "[INVALID_GRAPHQL] [a] Object field T.g includes required argument z that is missing from the Interface field I.g.",
            "[INVALID_GRAPHQL] [a] Object field T.h includes required argument r that is missing from the Interface field I.h.",
            "[INVALID_GRAPHQL] [a] Interface field I.missing expected but T does not provide it.",
            "[INVALID_GRAPHQL] [a] Interface field I.k expects type [[Int]] but T.k of type [Int] is not a proper subtype.",
            "[INVALID_GRAPHQL] [a] Interface field I.m expects type J but T.m of type O is not a proper subtype.",
            "[INVALID_GRAPHQL] [a] Interface field I.a expects type Int but K.a of type String is not a proper subtype.",
            "[INVALID_GRAPHQL] [a] Interface field I.l expects type I! but K.l of type I is not a proper subtype.",
            "[INVALID_GRAPHQL] [a] Interface field J.a expects type Int but K.a of type String is not a proper subtype.",
        ],
    )


def test_input_cycles() raises:
    check(
        [
            sg("a", "type Query { a: String }\ninput A { b: B! c: C }\ninput B { a: A! b: B! s: Int! l: [A!]! }\ninput C { c: C! d: D! }\ninput D { d: Int! x: Unknown! e: E! }\nenum E { X }\ntype Use { f(a: A, c: C): Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Unknown",
            "[INVALID_GRAPHQL] [a] Cannot reference Input Object \"A\" within itself through a series of non-null fields: \"b.a\".",
            "[INVALID_GRAPHQL] [a] Cannot reference Input Object \"B\" within itself through a series of non-null fields: \"b\".",
            "[INVALID_GRAPHQL] [a] Cannot reference Input Object \"C\" within itself through a series of non-null fields: \"c\".",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
