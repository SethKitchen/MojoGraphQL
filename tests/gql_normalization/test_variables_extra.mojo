# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""More tests of the variable passes, beyond the upstream suite.

They reach each case of `variablesExtractionVisitor`,
`inputCoercionForListVisitor`, `inputFieldDefaultInjectionVisitor` and
`variablesDefaultValueExtractionVisitor`, with the behavior of
graphql-go-tools v2 at 9ef6e24.
"""

from _norm import *
from std.testing import TestSuite

comptime SCHEMA = """
enum Color { RED }
input In { x: Int y: [Int] z: In2 w: String = "w" n: In2 = {q: 1} }
input In2 { q: Int r: [Int!] }
directive @flag(on: Boolean!) on FIELD
type Query {
  f(a: Int, b: [Int], c: String, i: In, l: [In], ll: [[In]], e: Color, n: Int!): String
  g: String
}
"""
"""A schema with lists of input objects and defaults."""


def test_extract_after_the_alphabet() raises:
    var definitions = String()
    var letter = 0
    while letter < 26:
        if letter > 0:
            definitions += ", "
        definitions += "$" + chr(ord("a") + letter) + ": Int"
        letter += 1
    run_vars(
        extract_pass,
        SCHEMA,
        "query (" + definitions + ') { f(c: "x") }',
        "query (" + definitions + ", $aa: String) { f(c: $aa) }",
        "",
        '{"aa":"x"}',
    )


def test_extract_in_two_operations() raises:
    run_vars(
        extract_pass,
        SCHEMA,
        "query A { f(a: 1) } query B { f(a: 1) }",
        "query A($a: Int) { f(a: $a) } query B($a: Int) { f(a: $a) }",
        "",
        '{"a":1}',
    )


def test_extract_skips_unknown_fields_and_arguments() raises:
    run_vars(
        extract_pass,
        SCHEMA,
        "{ unknown(a: 1) { x(b: 2) } f(zzz: 1) g }",
        "{ unknown(a: 1) { x(b: 2) } f(zzz: 1) g }",
        "",
        "",
    )


def test_extract_in_inline_fragment() raises:
    run_vars(
        extract_pass,
        SCHEMA,
        "{ ... on Query { f(a: 1) } }",
        "query ($a: Int) { ... on Query { f(a: $a) } }",
        "",
        '{"a":1}',
    )


def _coerce(operation: StringSlice, variables: StringSlice) raises:
    """Run `inputCoercionForList` on values that it leaves alone."""
    run_vars(
        coercion_pass,
        SCHEMA,
        operation,
        String(operation),
        variables,
        String(variables),
    )


def test_coercion_leaves_values() raises:
    _coerce("query ($b: [Int]) { f(b: $b) }", '{"b":[]}')
    _coerce("query ($v: Unknown) { g }", '{"v":{"a":1}}')
    _coerce("query ($v: Int) { g }", '{"v":{"a":1}}')
    _coerce(
        "query ($i: In) { f(i: $i) } fragment F on Query { g }",
        '{"i":{"zzz":1,"z":{}}}',
    )


def _inject(
    operation: StringSlice, variables: StringSlice, expected: StringSlice
) raises:
    """Run `injectInputFieldDefaults`."""
    run_vars(
        inject_defaults_pass,
        SCHEMA,
        operation,
        String(operation),
        variables,
        expected,
    )


def test_inject_leaves_values() raises:
    _inject("query ($v: Unknown) { g }", '{"v":{}}', '{"v":{}}')
    _inject(
        "query ($i: In) { f(i: $i) }",
        '{"i":{"w":"a","n":{"q":2},"z":{"q":1}}}',
        '{"i":{"w":"a","n":{"q":2},"z":{"q":1}}}',
    )
    _inject("query ($l: [In]) { f(l: $l) }", '{"l":{"x":1}}', '{"l":{"x":1}}')
    _inject("query ($i: In) { f(i: $i) }", '{"i":[1]}', '{"i":[1]}')
    _inject("query ($i: In) { f(i: $i) }", '{"i":null}', '{"i":null}')
    _inject("query ($l: [In]) { f(l: $l) }", '{"l":[]}', '{"l":[]}')


def test_inject_into_nested_lists() raises:
    _inject(
        "query ($ll: [[In]]) { f(ll: $ll) }",
        '{"ll":[[{}],null,[null]]}',
        '{"ll":[[{"w":"w","n":{"q":1}}],null,[null]]}',
    )


def _defaults(
    operation: StringSlice,
    expected: StringSlice,
    variables: StringSlice,
    expected_variables: StringSlice,
) raises:
    """Run `extractVariablesDefaultValue`."""
    run_vars(
        default_values_pass,
        SCHEMA,
        operation,
        expected,
        variables,
        expected_variables,
    )


def test_defaults_in_lists_and_objects() raises:
    _defaults(
        "query ($v: Int = 1) { f(c: [$v]) }",
        "query ($v: Int) { f(c: [$v]) }",
        "",
        '{"v":1}',
    )
    _defaults(
        "query ($v: Int = 1) { f(i: {zzz: $v, x: 1, y: [$v]}) }",
        "query ($v: Int) { f(i: {zzz: $v, x: 1, y: [$v]}) }",
        "",
        '{"v":1}',
    )


def test_defaults_in_directive_arguments() raises:
    _defaults(
        (
            "query ($v: Boolean = true, $w: Boolean = false) { g @flag(on: $v)"
            " @unknown(a: $w) @include(zzz: $w) @include(if: true) @x }"
        ),
        (
            "query ($v: Boolean!, $w: Boolean) { g @flag(on: $v) @unknown(a:"
            " $w) @include(zzz: $w) @include(if: true) @x }"
        ),
        "",
        '{"w":false,"v":true}',
    )


def test_defaults_used_in_a_fragment() raises:
    _defaults(
        "fragment F on Query { f(n: $v) } query ($v: Int = 1) { ...F }",
        "fragment F on Query { f(n: $v) } query ($v: Int!) { ...F }",
        "",
        '{"v":1}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
