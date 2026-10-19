# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the checks of directives, arguments and values.

The cases follow upstream `src/validation/directive.rs`,
`src/validation/value.rs` and `src/validation/variable.rs` of
apollo-compiler 1.33.0 (`b7eee5c`). Each test validates a mixed document
and checks the `Error:` lines.
"""

from gql_compiler.validate_common import float_is_finite, int_fits_i32
from gql_compiler.validation import parse_mixed_validate
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime SCHEMA = """
scalar JSON
enum E { A }
input In { b: Int }
interface I { b: Int }
union U = Query
type Query {
  a(
    x: Int
    f: Float
    j: JSON
    e: E
    q: Query
    i: I
    u: U
    le: [E]
    li: [In]
    lq: [Query]
    n: Nope
  ): Int
}
"""
"""A schema with an argument of each kind. `Query` is an output type, so
the schema itself has errors for `q`, `i`, `u`, `lq` and `n`."""


def _errors(query: String) raises -> String:
    """Return the `Error:` lines of a query against `SCHEMA`, without the
    errors of the schema."""
    var all = String(parse_mixed_validate(SCHEMA + query, "t.graphql")[2])
    var out = String()
    for line in all.splitlines():
        if line.startswith("Error: ") and not (
            "must be of an input type" in line or "cannot find type" in line
        ):
            out += String(line) + "\n"
    return out^


def test_repeated_undefined_directive() raises:
    assert_equal(
        _errors("{ a @nope @nope }"),
        "Error: cannot find directive `@nope` in this document\n" * 2,
    )


def test_disallowed_variable_in_directive() raises:
    assert_equal(
        _errors("query($v: Int) { a @include(if: $v) }"),
        (
            "Error: variable `$v` of type `Int` cannot be used for argument"
            " `if` of type `Boolean!`\n"
        ),
    )


def test_required_directive_argument_is_null() raises:
    assert_equal(
        _errors("{ a @include(if: null) }"),
        (
            "Error: the required argument `@include(if:)` is not provided\n"
            "Error: expected value of type Boolean!, found null\n"
        ),
    )


def test_object_value_for_a_scalar() raises:
    assert_equal(
        _errors("{ a(x: {b: 1}) }"),
        "Error: expected value of type Int, found an input object\n",
    )


def test_value_for_an_undefined_type() raises:
    assert_equal(_errors("{ a(n: 1) }"), "")


def test_float_coercion() raises:
    var big = String("1") + String("0") * 400
    assert_equal(
        _errors("{ a(f: " + big + ") }"),
        (
            "Error: float cannot represent non-finite 64-bit floating point"
            " value\n"
        ),
    )
    assert_equal(
        _errors("{ a(f: 1e999) }"),
        (
            "Error: float cannot represent non-finite 64-bit floating point"
            " value\n"
        ),
    )


def test_variables_of_output_types() raises:
    assert_equal(
        _errors("query($q: Query, $i: I, $u: U) { a(q: $q, i: $i, u: $u) }"),
        (
            "Error: expected value of type Query, found a variable\n"
            "Error: expected value of type I, found a variable\n"
            "Error: expected value of type U, found a variable\n"
        ),
    )


def test_list_items() raises:
    assert_equal(
        _errors("{ a(le: [B], li: [{c: 1}], lq: [1]) }"),
        (
            "Error: value `B` does not exist on `E`\n"
            "Error: field `c` does not exist on `In`\n"
            "Error: expected value of type Query, found a list\n"
        ),
    )


def test_object_values() raises:
    assert_equal(_errors("{ a(j: {b: 1}) }"), "")
    assert_equal(
        _errors("{ a(e: {b: 1}) }"),
        "Error: expected value of type E, found an input object\n",
    )


def test_number_helpers() raises:
    assert_true(int_fits_i32("-2147483648"))
    assert_false(int_fits_i32("2147483648"))
    assert_false(int_fits_i32("99999999999"))
    assert_true(float_is_finite("1.5e10"))
    assert_false(float_is_finite("-1e999"))
    assert_false(float_is_finite("not a number"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
