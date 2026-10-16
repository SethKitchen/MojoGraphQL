# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests beyond upstream for the classes of OverlappingFieldsCanBeMergedRule:
they cover the groups that are sorted into classes of equal fields.

Each group has 9 or more fields with one response name, or two groups give
32 or more pairs, so that the classes are used. The cases include impure
fields, too many classes, inline fragments, unknown parent types and the
class cache. The expected errors are the output of graphql-js 16.14.2 for
the same schema and documents.
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


def test_one_leaf_written_nine_times() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        "{ hello hello hello hello hello hello hello hello hello }",
    )


def test_equal_leaves_on_different_parent_types() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        "{ u { ... on A { y } ... on B { y } y y y y y y y } }",
    )


def test_a_leaf_then_a_field_with_a_sub_selection() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        "{ obj obj obj obj obj obj obj obj obj { x } }",
    )


def test_a_field_with_a_sub_selection_then_a_leaf() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        "{ obj { x } obj }",
    )


def test_too_many_classes_to_gain() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ a: obj { x } a: obj { y } a: obj { z } a: obj { x y } a: obj { x"
            " } a: obj { y } a: obj { z } a: obj { x z } a: obj { o { x } } }"
        ),
    )


def test_pure_fields_and_a_fragment_of_impure_fields() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ ...F a: obj { x } a: obj { x } a: obj { x } a: obj { x } a: obj"
            " { x } a: obj { x } a: obj { x } a: obj { x } } fragment F on"
            " Query { a: obj { ...G } a: obj { ...G } a: obj { ...G } a: obj {"
            " ...G } } fragment G on Obj { x }"
        ),
    )


def test_classes_between_fields_and_a_fragment() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ ...F a: obj { x } a: obj { x } a: obj { x } a: obj { x } a: obj"
            " { x } a: obj { x } a: obj { x } a: obj { x } } fragment F on"
            " Query { a: obj { x } a: obj { x } a: obj { x: y } a: obj { x } }"
        ),
        [
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:8, 1:17,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:21, 1:30,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:34, 1:43,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:47, 1:56,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:60, 1:69,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:73, 1:82,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:86, 1:95,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:99, 1:108,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:136, 1:145,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:149, 1:158,"
                " 1:162, 1:171)"
            ),
            (
                'Fields "a" conflict because subfields "x" conflict because "y"'
                ' and "x" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:162, 1:171,"
                " 1:178, 1:187)"
            ),
        ],
    )


def test_many_type_meta_fields() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            '{ a: __type(name: "A") { name } a: __type(name: "A") { name } a:'
            ' __type(name: "A") { name } a: __type(name: "A") { name } a:'
            ' __type(name: "A") { name } a: __type(name: "A") { name } a:'
            ' __type(name: "A") { name } a: __type(name: "A") { name } a:'
            ' __type(name: "A") { name } }'
        ),
    )


def test_a_schema_meta_field_below_equal_fields() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ a: obj { __schema { types } } a: obj { __schema { types } } a:"
            " obj { __schema { types } } a: obj { __schema { types } } a: obj {"
            " __schema { types } } a: obj { __schema { types } } a: obj {"
            " __schema { types } } a: obj { __schema { types } } a: obj {"
            " __schema { types } } }"
        ),
    )


def test_inline_fragments_with_no_type_condition() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ a: obj { ... { x } } a: obj { ... { x } } a: obj { ... { x } }"
            " a: obj { ... { x } } a: obj { ... { x } } a: obj { ... { x } } a:"
            " obj { ... { x } } a: obj { ... { x } } a: obj { ... { x } } }"
        ),
    )


def test_inline_fragments_with_a_fragment_spread() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ a: obj { ... on Obj { ...G } } a: obj { ... on Obj { ...G } } a:"
            " obj { ... on Obj { ...G } } a: obj { ... on Obj { ...G } } a: obj"
            " { ... on Obj { ...G } } a: obj { ... on Obj { ...G } } a: obj {"
            " ... on Obj { ...G } } a: obj { ... on Obj { ...G } } a: obj { ..."
            " on Obj { ...G } } } fragment G on Obj { x }"
        ),
    )


def test_sub_selections_on_an_unknown_parent_type() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ ... on Unknown { a { x } a { x } a { x } a { x } a { x } a { x }"
            " a { x } a { x } a { x } } }"
        ),
    )


def test_sub_selections_below_typename() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            '{ a: obj { t: __typename { x(s: "a") x(s: "\\u0061") x(s: "a")'
            ' x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a") x(s:'
            ' "\\u0061") x(s: "a") x(s: "\\u0061") } } a: obj { t: __typename {'
            ' x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a")'
            ' x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a") x(s:'
            ' "\\u0061") } } a: obj { t: __typename { x(s: "a") x(s: "\\u0061")'
            ' x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a")'
            ' x(s: "\\u0061") x(s: "a") x(s: "\\u0061") } } a: obj { t:'
            ' __typename { x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061")'
            ' x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a")'
            ' x(s: "\\u0061") } } a: obj { t: __typename { x(s: "a") x(s:'
            ' "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061")'
            ' x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061") } } a: obj {'
            ' t: __typename { x(s: "a") x(s: "\\u0061") x(s: "a") x(s:'
            ' "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061")'
            ' x(s: "a") x(s: "\\u0061") } } a: obj { t: __typename { x(s: "a")'
            ' x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a") x(s:'
            ' "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061") }'
            ' } a: obj { t: __typename { x(s: "a") x(s: "\\u0061") x(s: "a")'
            ' x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a") x(s:'
            ' "\\u0061") x(s: "a") x(s: "\\u0061") } } a: obj { t: __typename {'
            ' x(s: "a") x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a")'
            ' x(s: "\\u0061") x(s: "a") x(s: "\\u0061") x(s: "a") x(s:'
            ' "\\u0061") } } }'
        ),
    )


def test_sub_selections_below_a_type_meta_field() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            '{ a: __type(name: "A") { f: fields { n: name(s: "a") n: name(s:'
            ' "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n: name(s: "a")'
            ' n: name(s: "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n:'
            ' name(s: "a") n: name(s: "\\u0061") } f: fields { n: name(s: "a")'
            ' n: name(s: "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n:'
            ' name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n: name(s:'
            ' "\\u0061") n: name(s: "a") n: name(s: "\\u0061") } f: fields { n:'
            ' name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n: name(s:'
            ' "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n: name(s: "a")'
            ' n: name(s: "\\u0061") n: name(s: "a") n: name(s: "\\u0061") } f:'
            ' fields { n: name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n:'
            ' name(s: "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n:'
            ' name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n: name(s:'
            ' "\\u0061") } f: fields { n: name(s: "a") n: name(s: "\\u0061") n:'
            ' name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n: name(s:'
            ' "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n: name(s: "a")'
            ' n: name(s: "\\u0061") } f: fields { n: name(s: "a") n: name(s:'
            ' "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n: name(s: "a")'
            ' n: name(s: "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n:'
            ' name(s: "a") n: name(s: "\\u0061") } f: fields { n: name(s: "a")'
            ' n: name(s: "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n:'
            ' name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n: name(s:'
            ' "\\u0061") n: name(s: "a") n: name(s: "\\u0061") } f: fields { n:'
            ' name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n: name(s:'
            ' "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n: name(s: "a")'
            ' n: name(s: "\\u0061") n: name(s: "a") n: name(s: "\\u0061") } f:'
            ' fields { n: name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n:'
            ' name(s: "\\u0061") n: name(s: "a") n: name(s: "\\u0061") n:'
            ' name(s: "a") n: name(s: "\\u0061") n: name(s: "a") n: name(s:'
            ' "\\u0061") } } a: __type(name: "A") { name } }'
        ),
    )


def test_a_leaf_with_more_arguments_among_equal_leaves() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            '{ a: hello(a: 1, s: "x") a: hello(a: 1) a: hello(a: 1) a: hello(a:'
            " 1) a: hello(a: 1) a: hello(a: 1) a: hello(a: 1) a: hello(a: 1) a:"
            " hello(a: 1) }"
        ),
        [
            (
                'Fields "a" conflict because they have differing arguments. Use'
                " different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:26)"
            ),
            (
                'Fields "a" conflict because they have differing arguments. Use'
                " different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:41)"
            ),
            (
                'Fields "a" conflict because they have differing arguments. Use'
                " different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:56)"
            ),
            (
                'Fields "a" conflict because they have differing arguments. Use'
                " different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:71)"
            ),
            (
                'Fields "a" conflict because they have differing arguments. Use'
                " different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:86)"
            ),
            (
                'Fields "a" conflict because they have differing arguments. Use'
                " different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:101)"
            ),
            (
                'Fields "a" conflict because they have differing arguments. Use'
                " different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:116)"
            ),
            (
                'Fields "a" conflict because they have differing arguments. Use'
                " different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:131)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
