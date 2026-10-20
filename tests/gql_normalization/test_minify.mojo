# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_normalization.minify` and `gql_normalization.go_printer`,
ported from graphql-go-tools v2 at 9ef6e24 `v2/pkg/astminify/minify_test.go`.

`TestMinifier_Minify` is kept: each of its ten cases compares the minified
output with `fixtures/operation<N>.min.graphql.golden`. Its comparisons of
the normalized outputs need `astnormalization`, so they are not here. The
other tests cover the rest of the minifier and the printer. Their expected
texts are the outputs of the upstream Go code for the same inputs.
"""

from _minify_fixtures import (
    MINIFIED_1,
    MINIFIED_10,
    MINIFIED_2,
    MINIFIED_3,
    MINIFIED_4,
    MINIFIED_5,
    MINIFIED_6,
    MINIFIED_7,
    MINIFIED_8,
    MINIFIED_9,
    OPERATION_1,
    OPERATION_10,
    OPERATION_2,
    OPERATION_3,
    OPERATION_4,
    OPERATION_5,
    OPERATION_6,
    OPERATION_7,
    OPERATION_8,
    OPERATION_9,
    SIMPLE_OPERATION,
    SIMPLE_SCHEMA,
)
from gql_language.ast import Document, Role
from gql_language.parser import parse
from gql_language.source import Source
from gql_normalization.go_printer import print_compact, print_indent
from gql_normalization.minify import Minifier, MinifyOptions, minify
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

comptime EDGE_SCHEMA = """type Query { query: [Interface!]! a: ObjectA u: U }
union U = ObjectA | ObjectB
interface Interface { name: String! age: Int! }
type ObjectA implements Interface { name: String! age: Int! aField(a: String b: String c: String): ObjectA bField(a: String): ObjectB }
type ObjectB implements Interface { name: String! age: Int! aField(a: String b: String c: String): ObjectA bField(a: String): ObjectB }
type Mutation { m: ObjectA }
directive @abc(a: String b: String c: String) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
"""
"""A schema with a union, a mutation type and the `@abc` directive."""

comptime SORTED = MinifyOptions(pretty=False, sort_ast=True)
"""Compact output of a sorted operation."""


def _edge(
    operation: StringSlice, options: MinifyOptions = SORTED
) raises -> String:
    """Minify an operation against `EDGE_SCHEMA`."""
    return minify(operation, build_schema(EDGE_SCHEMA), options)


@fieldwise_init
struct _Case(Copyable, Movable):
    """One case of upstream `TestMinifier_Minify`."""

    var name: String
    var operation: String
    var minified: String


def test_minifier_minify() raises:
    var cases: List[_Case] = [
        _Case("operation1", OPERATION_1, MINIFIED_1),
        _Case("operation2", OPERATION_2, MINIFIED_2),
        _Case("operation3", OPERATION_3, MINIFIED_3),
        _Case("operation4", OPERATION_4, MINIFIED_4),
        _Case("operation5", OPERATION_5, MINIFIED_5),
        _Case("operation6", OPERATION_6, MINIFIED_6),
        _Case("operation7", OPERATION_7, MINIFIED_7),
        _Case("operation8", OPERATION_8, MINIFIED_8),
        _Case("operation9", OPERATION_9, MINIFIED_9),
        _Case("operation10", OPERATION_10, MINIFIED_10),
    ]
    var schema = build_schema(SIMPLE_SCHEMA)
    var options = MinifyOptions(pretty=True, sort_ast=True)
    for entry in cases:
        var minifier = Minifier()
        var out = String("")
        var made = minifier.minify(entry.operation, schema, options, out)
        assert_true(made, entry.name)
        assert_equal(out, entry.minified, entry.name)


def test_simple_operation() raises:
    var out = minify(
        SIMPLE_OPERATION,
        build_schema(SIMPLE_SCHEMA),
        MinifyOptions(pretty=True, sort_ast=True),
    )
    assert_equal(
        out,
        """{
    query {
        ...A
        ... on ObjectB {
            aField {
                ...A
            }
        }
        ... on ObjectC {
            aField {
                ...A
            }
        }
    }
}

fragment A on ObjectA {
    __typename
    age
    name
}""",
    )


def test_compact_output_and_reuse() raises:
    var schema = build_schema(SIMPLE_SCHEMA)
    var minifier = Minifier()
    var expected = (
        "query MyQuery {query {...A ... on ObjectB {__typename aField {...A}"
        " age name} ... on ObjectC {__typename aField {...A} age name}}}"
        " fragment A on ObjectA {__typename age name}"
    )
    var first = String("")
    assert_true(minifier.minify(OPERATION_2, schema, SORTED, first))
    assert_equal(first, expected)
    var second = String("> ")
    assert_true(minifier.minify(OPERATION_2, schema, SORTED, second))
    assert_equal(second, "> " + expected)


def test_no_repeated_set() raises:
    var operation = "{ a { a: name name aField { x: name name } } }"
    var minifier = Minifier()
    var out = String("keep")
    assert_false(
        minifier.minify(operation, build_schema(EDGE_SCHEMA), SORTED, out)
    )
    assert_equal(out, "keep")
    assert_equal(_edge(operation), operation)


def test_default_options() raises:
    assert_equal(
        minify("{ a { name } a { name } }", build_schema(EDGE_SCHEMA)),
        "{a {...A} a {...A}} fragment A on ObjectA {name}",
    )


def test_nested_repeats() raises:
    assert_equal(
        _edge("{ a { aField { name } } a { aField { name } } }"),
        (
            "{a {...B} a {...B}} fragment A on ObjectA {name} fragment B on"
            " ObjectA {aField {...A}}"
        ),
    )


def test_aliases() raises:
    assert_equal(
        _edge(
            "{ a { x: aField { name } y: aField { name } aField { name } } }"
        ),
        (
            "{a {aField {...A} x: aField {...A} y: aField {...A}}} fragment A"
            " on ObjectA {name}"
        ),
    )


def test_directives_keep_sets_apart() raises:
    assert_equal(
        _edge(
            '{ a { aField @abc(b: "1", a: "2") { name age } bField { aField'
            ' @abc(a: "2", b: "1") { age name } } } }'
        ),
        (
            '{a {aField @abc(a: "2", b: "1") {...A} bField {aField @abc(a: "2",'
            ' b: "1") {...A}}}} fragment A on ObjectA @abc(a: "2", b: "1") {age'
            " name}"
        ),
    )
    assert_equal(
        _edge(
            "{ a { ... on ObjectA @abc { name } bField { ... on ObjectB @abc {"
            " name } ... on ObjectA @abc { name } } } }"
        ),
        (
            "{a {bField {...A ... on ObjectB @abc{name}} ...A}} fragment A on"
            " ObjectA @abc {name}"
        ),
    )
    assert_equal(
        _edge(
            "{ a { ... on ObjectA @skip(if: false) @abc { name } bField { ..."
            " on ObjectA @abc @skip(if: false) { name } } } }"
        ),
        (
            "{a {bField {...A} ...A}} fragment A on ObjectA @abc @skip(if:"
            " false) {name}"
        ),
    )


def test_operation_directives_and_arguments() raises:
    assert_equal(
        _edge(
            'query Q($v: String) @abc { a @abc(a: $v) { aField(c: "x", a: "y")'
            ' { name age } bField { aField(a: "y", c: "x") { age name } } } }'
        ),
        (
            'query Q($v: String)@abc {a @abc(a: $v) {aField(a: "y", c:'
            ' "x"){...A} bField {aField(a: "y", c: "x"){...A}}}} fragment A on'
            " ObjectA {age name}"
        ),
    )


def test_sort_with_fragment_spreads() raises:
    assert_equal(
        _edge(
            "{ a { ... on ObjectA { name } ...F name ... on ObjectA { age }"
            " aField @skip(if: false) @abc { name } bField { aField @abc"
            " @skip(if: false) { name } } } } fragment F on ObjectA { name }"
        ),
        (
            "{a {... on ObjectA {name} ...F aField @abc @skip(if: false) {...A}"
            " bField {aField @abc @skip(if: false) {...A}} name ... on ObjectA"
            " {age}}} fragment F on ObjectA {name} fragment A on ObjectA @abc"
            " @skip(if: false) {name}"
        ),
    )


def test_sort_with_inline_fragment_after_spread() raises:
    assert_equal(
        _edge(
            "{ a { ...F ... on ObjectA { age } aField { ...F ... on ObjectA {"
            " age } } } } fragment F on ObjectA { name }"
        ),
        (
            "{a {...F aField {...F ...A} ...A}} fragment F on ObjectA {name}"
            " fragment A on ObjectA {age}"
        ),
    )


def test_existing_fragments() raises:
    var operation = (
        "{ a { ...F aField { ...F } bField { aField { ...F } } } } fragment F"
        " on ObjectA { aField { name } bField { name } }"
    )
    var expected = (
        "{a {...F aField {...A} bField {aField {...A}}}} fragment F on ObjectA"
        " {aField {name} bField {name}} fragment A on ObjectA {...F}"
    )
    assert_equal(_edge(operation), expected)
    assert_equal(_edge(operation, MinifyOptions()), expected)


def test_mutation() raises:
    assert_equal(
        _edge("mutation { m { aField { name } bField { aField { name } } } }"),
        (
            "mutation{m {aField {...A} bField {aField {...A}}}} fragment A on"
            " ObjectA {name}"
        ),
    )


def test_unknown_fields() raises:
    assert_equal(
        _edge("{ a { unknown { name } other { name } } }"),
        "{a {other {...A} unknown {...A}}} fragment A on  {name}",
    )
    assert_equal(
        _edge(
            "{ nope { __typename { x } } a { __typename { x } unknown { y } } }"
        ),
        (
            "{a {__typename {...A} unknown {y}} nope {__typename {...A}}}"
            " fragment A on String {x}"
        ),
    )


def test_meta_fields() raises:
    assert_equal(
        _edge(
            "{ u { ... on ObjectA { name } ... { __typename } } a { aField {"
            " __typename } bField { __typename } ... { __typename } } }"
        ),
        (
            "{a {aField {...A} bField {__typename} ...A} u {...{__typename} ..."
            " on ObjectA {name}}} fragment A on ObjectA {__typename}"
        ),
    )
    assert_equal(
        _edge(
            '{ __schema { types { name } } __type(name: "x") { name } a {'
            " aField { name } b2: aField { name } } }"
        ),
        (
            '{__schema {types {...A}} __type(name: "x"){...A} a {aField {...B}'
            " b2: aField {...B}}} fragment A on __Type {name} fragment B on"
            " ObjectA {name}"
        ),
    )


def _pairs(count: Int) -> String:
    """Return an operation with `count` distinct sets that each repeat."""
    var operation = String("{ a { ")
    for i in range(1, count + 1):
        var n = String(i)
        operation += "p" + n + ": aField { n" + n + ": name } "
        operation += "q" + n + ": aField { n" + n + ": name } "
    return operation + "} }"


def test_fragment_names_after_z() raises:
    # Upstream takes sets of the same depth and type from a Go map, so its
    # letters change from run to run. The names are A to Z, then BA on,
    # and a name that the document has is skipped.
    var out = _edge(_pairs(30) + " fragment BA on ObjectA { name }")
    assert_equal(out.count("fragment BA on"), 1)
    assert_equal(out.count("fragment A on ObjectA {n1: name}"), 1)
    assert_equal(out.count("fragment Z on"), 1)
    assert_equal(out.count("fragment BB on"), 1)
    assert_equal(out.count("fragment BE on ObjectA {n9: name}"), 1)
    assert_equal(out.count("fragment BF on"), 0)


def test_too_many_fragments() raises:
    with assert_raises(contains="astminify: more than 676 fragments"):
        _ = _edge(_pairs(677))


def test_errors() raises:
    with assert_raises(
        contains="AST must have exactly one operation definition"
    ):
        _ = _edge("{ a { name } } { u { __typename } }")
    with assert_raises(
        contains="AST must have exactly one operation definition"
    ):
        _ = _edge("fragment F on ObjectA { name }")
    with assert_raises(contains='Unknown type "Nope".'):
        _ = _edge("{ a { ... on Nope { name } } }")
    with assert_raises(
        contains=(
            "operation type subscription is not defined; did you forget to"
            " merge the base schema?"
        )
    ):
        _ = _edge("subscription { m { name } }")


comptime PRINTER_OPERATION = """query Q($a: Int = 1 @d, $b: [String!]! @d @e(x: 1)) @op(a: "s") @op2 {
  x: f(a: 1, b: $a, c: [1, 2], d: {k: v, j: null}, e: true) @inc(if: $b) @k { g h @d }
  h @d
  ... on T @d { a }
  ... @d { b }
  ... { c }
  ...F @d
  ...G @d @e
  last
}
fragment F on T @fd { a ...G }
fragment G on T { b ... on U @x @y { c ...H @z } }
"""
"""A document with each part that the printer writes."""


def test_print_compact() raises:
    assert_equal(
        print_compact(parse(Source(PRINTER_OPERATION))),
        (
            'query Q($a: Int = 1 @d, $b: [String!]! @d @e(x: 1) )@op(a: "s")'
            " @op2 {x: f(a: 1, b: $a, c: [1,2], d: {k: v,j: null}, e:"
            " true)@inc(if: $b) @k {g h @d} h @d ... on T @d {a} ... @d {b}"
            " ...{c} ...F @d  ...G @d @e  last} fragment F on T @fd {a ...G}"
            " fragment G on T {b ... on U @x @y{c ...H @z}}"
        ),
    )


def test_print_indent() raises:
    assert_equal(
        print_indent(parse(Source(PRINTER_OPERATION)), "    "),
        """query Q($a: Int = 1 @d, $b: [String!]! @d @e(x: 1) )@op(a: "s") @op2 {
    x: f(a: 1, b: $a, c: [1,2], d: {k: v,j: null}, e: true)@inc(if: $b) @k {
        g
        h @d
    }
    h @d
    ... on T @d {
        a
    }
    ... @d {
        b
    }
    ...{
        c
    }
    ...F @d
    ...G @d @e
    last
}

fragment F on T @fd {
    a
    ...G
}

fragment G on T {
    b
    ... on U @x @y {
        c
        ...H @z
    }
}""",
    )


def test_print_operation_forms() raises:
    var document = parse(
        Source(
            'mutation @d { a(s: "x", b: """blk\n  q""", n: -1, f: -1.5e3, l:'
            " [], o: {}, t: false) }\nsubscription S { b }\nquery @x { c }\n{ d"
            " }\nmutation M($v: Int) { e(a: $v) @skip(if: true) @include(if:"
            " false) }\nquery ($v: Int) { f }\n"
        )
    )
    assert_equal(
        print_compact(document),
        (
            'mutation@d {a(s: "x", b: """blk\n  q""", n: -1, f: -1.5e3, l: [],'
            " o: {}, t: false)} subscription S {b} @x {c} {d} mutation M($v:"
            " Int){e(a: $v)@skip(if: true) @include(if: false)} query($v:"
            " Int){f}"
        ),
    )
    assert_equal(
        print_indent(document, "  "),
        (
            'mutation@d {\n  a(s: "x", b: """blk\n  q""", n: -1, f: -1.5e3, l:'
            " [], o: {}, t: false)\n}\n\nsubscription S {\n  b\n}\n\n@x {\n "
            " c\n}\n\n{\n  d\n}\n\nmutation M($v: Int){\n  e(a: $v)@skip(if:"
            " true) @include(if: false)\n}\n\nquery($v: Int){\n  f\n}"
        ),
    )


def test_print_program_added_strings() raises:
    var parsed = parse(Source('{ f(a: "x", b: """y""") }'))
    var document = Document()
    var copy = document.copy_subtree(
        parsed, parsed.first_child(parsed.root), Role.DEFINITION
    )
    document.append_child(document.root, copy)
    assert_equal(print_compact(document), '{f(a: "x", b: """y""")}')


def test_print_type_system_definition_raises() raises:
    var document = parse(Source("type T { a: Int }"))
    with assert_raises(contains="only executable definitions print"):
        _ = print_compact(document)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
