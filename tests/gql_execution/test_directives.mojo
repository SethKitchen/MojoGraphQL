# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `@skip` and `@include` in `gql_execution.collect_fields`,
ported from graphql-js 16.14.2 `src/execution/__tests__/directives-test.ts`.

Every upstream case is ported. The root value's functions become plain
properties, which the default field resolver reads the same way. The cases
at the end are not upstream; their results were checked against
graphql-js 16.14.2 in Node.js.
"""

from std.testing import TestSuite, assert_equal
from _helpers import run

comptime SDL = (
    "type TestType { a: String b: String } schema { query: TestType }"
)
comptime ROOT = '{"a": "a", "b": "b"}'
comptime AB = '{"data":{"a":"a","b":"b"}}'
comptime A = '{"data":{"a":"a"}}'


def check(query: String, expected: String) raises:
    assert_equal(run(SDL, query, ROOT), expected)


def test_basic_query_works() raises:
    check("{ a, b }", AB)


def test_if_true_includes_scalar() raises:
    check("{ a, b @include(if: true) }", AB)


def test_if_false_omits_on_scalar() raises:
    check("{ a, b @include(if: false) }", A)


def test_unless_false_includes_scalar() raises:
    check("{ a, b @skip(if: false) }", AB)


def test_unless_true_omits_scalar() raises:
    check("{ a, b @skip(if: true) }", A)


def spread(directive: String) -> String:
    return (
        "query { a ...Frag " + directive + " } fragment Frag on TestType { b }"
    )


def test_if_false_omits_fragment_spread() raises:
    check(spread("@include(if: false)"), A)


def test_if_true_includes_fragment_spread() raises:
    check(spread("@include(if: true)"), AB)


def test_unless_false_includes_fragment_spread() raises:
    check(spread("@skip(if: false)"), AB)


def test_unless_true_omits_fragment_spread() raises:
    check(spread("@skip(if: true)"), A)


def inline(condition: String, directive: String) -> String:
    return "query { a ... " + condition + directive + " { b } }"


def test_if_false_omits_inline_fragment() raises:
    check(inline("on TestType ", "@include(if: false)"), A)


def test_if_true_includes_inline_fragment() raises:
    check(inline("on TestType ", "@include(if: true)"), AB)


def test_unless_false_includes_inline_fragment() raises:
    check(inline("on TestType ", "@skip(if: false)"), AB)


def test_unless_true_includes_inline_fragment() raises:
    check(inline("on TestType ", "@skip(if: true)"), A)


def test_if_false_omits_anonymous_inline_fragment() raises:
    check(inline("", "@include(if: false)"), A)


def test_if_true_includes_anonymous_inline_fragment() raises:
    check(inline("", "@include(if: true)"), AB)


def test_unless_false_includes_anonymous_inline_fragment() raises:
    check("query Q { a ... @skip(if: false) { b } }", AB)


def test_unless_true_includes_anonymous_inline_fragment() raises:
    check(inline("", "@skip(if: true)"), A)


def test_include_and_no_skip() raises:
    check("{ a b @include(if: true) @skip(if: false) }", AB)


def test_include_and_skip() raises:
    check("{ a b @include(if: true) @skip(if: true) }", A)


def test_no_include_or_skip() raises:
    check("{ a b @include(if: false) @skip(if: false) }", A)


# --- not upstream ------------------------------------------------------------


def test_directives_with_variables() raises:
    assert_equal(
        run(
            SDL,
            (
                "query ($skip: Boolean!, $show: Boolean!) { a @skip(if: $skip)"
                " b @include(if: $show) }"
            ),
            ROOT,
            '{"skip": true, "show": true}',
        ),
        '{"data":{"b":"b"}}',
    )


def test_a_directive_with_a_missing_variable_fails_the_operation() raises:
    assert_equal(
        run(SDL, "query ($skip: Boolean) { a @skip(if: $skip) }", ROOT),
        (
            '{"errors":[{"message":"Argument \\"if\\" of required type'
            ' \\"Boolean!\\" was provided the variable \\"$skip\\" which was'
            " not provided a runtime"
            ' value.","locations":[{"line":1,"column":38}]}],"data":null}'
        ),
    )


def test_other_directives_and_unknown_fragments_are_ignored() raises:
    check("{ a @deprecated ...Missing ... on Missing { b } }", A)


def test_a_fragment_on_an_interface_or_an_object_that_does_not_match() raises:
    assert_equal(
        run(
            """
            interface Named { name: String }
            type Dog implements Named { name: String }
            type Query { a: String }
            """,
            "{ ... on Named { name } ... on Dog { name } ... on Query { a } }",
            '{"a": "a"}',
        ),
        '{"data":{"a":"a"}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
