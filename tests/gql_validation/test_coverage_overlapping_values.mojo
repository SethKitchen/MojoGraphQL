# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests beyond upstream for the values and caches of
OverlappingFieldsCanBeMergedRule: they cover `same_value` on each kind of
value, `same_arguments` with more than 16 arguments, and the caches of
fragment pairs.

The expected errors are the output of graphql-js 16.14.2 for the same
schema and documents.
"""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime SDL = (
    "type Query { hello(a: Int, s: String): String other: String obj: Obj"
    " objs: [Obj] i: I u: U name: String } type Obj { x: Int y: String z:"
    " Int o: Obj } interface I { x: X } type A implements I { x: X y: Int"
    " obj: Obj } type B implements I { x: X y: Int name: String } type X {"
    " v: Int w: Int } union U = A | B"
)
"""The schema of every case."""


def test_argument_values_of_each_kind() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "query Q($v: Int, $w: Int) {\nk1: hello(a: 1) k1: hello(a:"
            ' "1")\nk2: hello(a: [1, 2]) k2: hello(a: [1, 2])\nk3: hello(a:'
            " [1]) k3: hello(a: [1, 2])\nk4: hello(a: [1, 2]) k4: hello(a:"
            " [1])\nk5: hello(a: [1, 3]) k5: hello(a: [1, 2])\nk6: hello(a: {a:"
            " 1, b: 2}) k6: hello(a: {b: 2, a: 1})\nk7: hello(a: {a: 1}) k7:"
            " hello(a: {a: 1, b: 2})\nk8: hello(a: {a: 1}) k8: hello(a: {b:"
            " 1})\nk9: hello(a: {a: 1}) k9: hello(a: {a: 2})\nk10: hello(a: {})"
            ' k10: hello(a: {})\nk11: hello(s: """x""") k11: hello(s:'
            ' "x")\nk12: hello(s: """x""") k12: hello(s: """x""")\nk13:'
            ' hello(s: "a") k13: hello(s: "\\u0061")\nk14: hello(s: "a") k14:'
            ' hello(s: "b")\nk15: hello(a: true) k15: hello(a: false)\nk16:'
            " hello(a: true) k16: hello(a: true)\nk17: hello(a: $v) k17:"
            " hello(a: $w)\nk18: hello(a: $v) k18: hello(a: $v)\nk19: hello(a:"
            " null) k19: hello(a: null)\nk20: hello(a: RED) k20: hello(a:"
            " BLUE)\nk21: hello(a: RED) k21: hello(a: RED)\nk22: hello(a: [])"
            " k22: hello(a: [])\nk23: hello(a: {a2: 1, a10: 2}) k23: hello(a:"
            " {a10: 2, a2: 1})\n}"
        ),
        [
            (
                'Fields "k1" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (2:1, 2:17)"
            ),
            (
                'Fields "k3" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (4:1, 4:19)"
            ),
            (
                'Fields "k4" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (5:1, 5:22)"
            ),
            (
                'Fields "k5" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (6:1, 6:22)"
            ),
            (
                'Fields "k7" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (8:1, 8:22)"
            ),
            (
                'Fields "k8" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (9:1, 9:22)"
            ),
            (
                'Fields "k9" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (10:1, 10:22)"
            ),
            (
                'Fields "k11" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (12:1, 12:24)"
            ),
            (
                'Fields "k14" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (15:1, 15:20)"
            ),
            (
                'Fields "k15" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (16:1, 16:21)"
            ),
            (
                'Fields "k17" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (18:1, 18:19)"
            ),
            (
                'Fields "k20" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (21:1, 21:20)"
            ),
        ],
    )


def test_more_than_sixteen_arguments() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ m1: hello(a1: 1, a2: 1, a3: 1, a4: 1, a5: 1, a6: 1, a7: 1, a8:"
            " 1, a9: 1, a10: 1, a11: 1, a12: 1, a13: 1, a14: 1, a15: 1, a16: 1,"
            " a17: 1) m1: hello(a17: 1, a16: 1, a15: 1, a14: 1, a13: 1, a12: 1,"
            " a11: 1, a10: 1, a9: 1, a8: 1, a7: 1, a6: 1, a5: 1, a4: 1, a3: 1,"
            " a2: 1, a1: 1) m2: hello(a1: 1, a2: 1, a3: 1, a4: 1, a5: 1, a6: 1,"
            " a7: 1, a8: 1, a9: 1, a10: 1, a11: 1, a12: 1, a13: 1, a14: 1, a15:"
            " 1, a16: 1, a17: 1) m2: hello(a1: 1, a2: 1, a3: 1, a4: 1, a5: 1,"
            " a6: 1, a7: 1, a8: 1, a9: 1, a10: 1, a11: 1, a12: 1, a13: 1, a14:"
            " 1, a15: 1, a16: 1, b17: 1) m3: hello(a1: 1, a2: 1, a3: 1, a4: 1,"
            " a5: 1, a6: 1, a7: 1, a8: 1, a9: 1, a10: 1, a11: 1, a12: 1, a13:"
            " 1, a14: 1, a15: 1, a16: 1, a17: 1, a17: 1) m3: hello(a1: 1, a2:"
            " 1, a3: 1, a4: 1, a5: 1, a6: 1, a7: 1, a8: 1, a9: 1, a10: 1, a11:"
            " 1, a12: 1, a13: 1, a14: 1, a15: 1, a16: 1, a17: 2, a17: 1) }"
        ),
        [
            (
                'Fields "m2" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:277, 1:414)"
            ),
        ],
    )


def test_a_fragment_compared_exclusively_then_not() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ i { ... on A { x { v ...F } } ... on B { x { v ...F } } ... on B"
            " { x { v ...F } } x { v ...F } } } fragment F on X { v: w }"
        ),
        [
            (
                'Fields "x" conflict because subfields "v" conflict because "v"'
                ' and "w" are different fields and subfields "v" conflict'
                ' because "v" and "w" are different fields. Use different'
                " aliases on the fields to fetch both if this was intentional."
                " (1:18, 1:22, 1:89, 1:85, 1:120, 1:120)"
            ),
            (
                'Fields "x" conflict because subfields "v" conflict because "v"'
                ' and "w" are different fields and subfields "v" conflict'
                ' because "v" and "w" are different fields. Use different'
                " aliases on the fields to fetch both if this was intentional."
                " (1:44, 1:48, 1:74, 1:70, 1:120, 1:120)"
            ),
        ],
    )


def test_one_fragment_spread_twice() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        "{ ...F ...F } fragment F on Query { hello }",
    )


def test_a_fragment_and_an_unknown_fragment() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        "{ ...F ...Missing } fragment F on Query { hello }",
    )


def test_an_object_and_a_leaf_type() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        "{ u { ... on A { v: obj } ... on B { v: name } } }",
        [
            (
                'Fields "v" conflict because they return conflicting types'
                ' "Obj" and "String". Use different aliases on the fields to'
                " fetch both if this was intentional. (1:18, 1:38)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
