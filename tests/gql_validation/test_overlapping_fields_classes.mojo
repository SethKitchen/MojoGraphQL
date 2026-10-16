# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the classes of equal fields of OverlappingFieldsCanBeMergedRule.

graphql-js has no such tests: the classes are a speedup of this port. Each
group here has enough fields for the classes to be used. The expected errors
are the output of graphql-js 16.14.2 for the same documents.
"""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime SDL = (
    "type Query { hello(a: Int, s: String): String other: String obj: Obj objs:"
    " [Obj] } type Obj { x: Int y: String z: Int }"
)
"""The schema of every case."""


def test_a_leaf_that_differs_among_equal_leaves() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ a: hello a: hello a: hello a: hello a: hello a: other a: hello"
            " a: hello a: hello a: hello a: hello }"
        ),
        [
            (
                'Fields "a" conflict because "hello" and "other" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:3, 1:48)"
            ),
            (
                'Fields "a" conflict because "hello" and "other" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:12, 1:48)"
            ),
            (
                'Fields "a" conflict because "hello" and "other" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:21, 1:48)"
            ),
            (
                'Fields "a" conflict because "hello" and "other" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:30, 1:48)"
            ),
            (
                'Fields "a" conflict because "hello" and "other" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:39, 1:48)"
            ),
            (
                'Fields "a" conflict because "other" and "hello" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:48, 1:57)"
            ),
            (
                'Fields "a" conflict because "other" and "hello" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:48, 1:66)"
            ),
            (
                'Fields "a" conflict because "other" and "hello" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:48, 1:75)"
            ),
            (
                'Fields "a" conflict because "other" and "hello" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:48, 1:84)"
            ),
            (
                'Fields "a" conflict because "other" and "hello" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:48, 1:93)"
            ),
        ],
    )


def test_a_sub_selection_that_differs_among_equal_fields() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ o: obj { x } o: obj { x } o: obj { x } o: obj { x } o: obj { x }"
            " o: obj { x } o: obj { x: y } o: obj { x } o: obj { x } o: obj {"
            " x } }"
        ),
        [
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:3, 1:12,"
                " 1:81, 1:90)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:16, 1:25,"
                " 1:81, 1:90)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:29, 1:38,"
                " 1:81, 1:90)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:42, 1:51,"
                " 1:81, 1:90)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:55, 1:64,"
                " 1:81, 1:90)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:68, 1:77,"
                " 1:81, 1:90)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "y"'
                ' and "x" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:81, 1:90,"
                " 1:97, 1:106)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "y"'
                ' and "x" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:81, 1:90,"
                " 1:110, 1:119)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "y"'
                ' and "x" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:81, 1:90,"
                " 1:123, 1:132)"
            ),
        ],
    )


def test_fragment_spreads_among_equal_fields() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ o: obj { x } o: obj { x } o: obj { x } o: obj { x } o: obj { x }"
            " o: obj { ...F } o: obj { ...F } o: obj { x } o: obj { x } o: obj"
            " { x } } fragment F on Obj { x: y }"
        ),
        [
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:3, 1:12,"
                " 1:68, 1:161)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:16, 1:25,"
                " 1:68, 1:161)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:29, 1:38,"
                " 1:68, 1:161)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:42, 1:51,"
                " 1:68, 1:161)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:55, 1:64,"
                " 1:68, 1:161)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:68, 1:109,"
                " 1:100, 1:161)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:68, 1:122,"
                " 1:113, 1:161)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "y" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:68, 1:135,"
                " 1:126, 1:161)"
            ),
        ],
    )


def test_equal_fields_with_a_repeated_argument() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ hello(a: 1, a: 2) hello(a: 1, a: 2) hello(a: 1, a: 2) hello(a:"
            " 1, a: 2) hello(a: 1, a: 2) hello(a: 1, a: 2) hello(a: 1, a: 2)"
            " hello(a: 1, a: 2) hello(a: 1, a: 2) }"
        ),
        [
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:21)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:39)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:57)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:75)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:93)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:111)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:129)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:147)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:21, 1:39)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:21, 1:57)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:21, 1:75)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:21, 1:93)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:21, 1:111)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:21, 1:129)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:21, 1:147)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:39, 1:57)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:39, 1:75)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:39, 1:93)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:39, 1:111)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:39, 1:129)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:39, 1:147)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:57, 1:75)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:57, 1:93)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:57, 1:111)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:57, 1:129)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:57, 1:147)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:75, 1:93)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:75, 1:111)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:75, 1:129)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:75, 1:147)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:93, 1:111)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:93, 1:129)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:93, 1:147)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:111, 1:129)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:111, 1:147)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:129, 1:147)"
            ),
        ],
    )


def test_equal_fields_in_two_fragments() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ ...A ...B } fragment A on Query { o: obj { x } o: obj { x } o:"
            " obj { x } o: obj { x } o: obj { x } o: obj { x } } fragment B on"
            " Query { o: obj { x } o: obj { x } o: obj { x } o: obj { x } o:"
            " obj { x } o: objs { x } }"
        ),
        [
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:37, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:50, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:63, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:76, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:89, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:102, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:139, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:152, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:165, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:178, 1:204)"
            ),
            (
                'Fields "o" conflict because "obj" and "objs" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:191, 1:204)"
            ),
        ],
    )


def test_equal_values_written_two_ways() raises:
    expect_valid_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            '{ hello(s: "A") hello(s: "A") hello(s: "A") hello(s: "A") hello(s:'
            ' "A") hello(s: "A") hello(s: "A") hello(s: "A") hello(s: "A")'
            ' hello(s: "\\u0041") }'
        ),
    )


def test_many_typename_fields() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ __typename __typename __typename __typename __typename"
            " __typename __typename __typename __typename __typename: other }"
        ),
        [
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:3, 1:102)"
            ),
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:14, 1:102)"
            ),
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:25, 1:102)"
            ),
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:36, 1:102)"
            ),
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:47, 1:102)"
            ),
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:58, 1:102)"
            ),
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:69, 1:102)"
            ),
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:80, 1:102)"
            ),
            (
                'Fields "__typename" conflict because "__typename" and "other"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:91, 1:102)"
            ),
        ],
    )


def test_many_schema_fields() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ __schema { types { name } } __schema { types { name } } __schema"
            " { types { name } } __schema { types { name } } __schema { types {"
            " name } } __schema { types { name } } __schema { types { name } }"
            " __schema { types { name } } __schema { types { name: kind } } }"
        ),
        [
            (
                'Fields "__schema" conflict because subfields "types" conflict'
                ' because subfields "name" conflict because "name" and "kind"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:3, 1:14, 1:22, 1:227,"
                " 1:238, 1:246)"
            ),
            (
                'Fields "__schema" conflict because subfields "types" conflict'
                ' because subfields "name" conflict because "name" and "kind"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:31, 1:42, 1:50, 1:227,"
                " 1:238, 1:246)"
            ),
            (
                'Fields "__schema" conflict because subfields "types" conflict'
                ' because subfields "name" conflict because "name" and "kind"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:59, 1:70, 1:78, 1:227,"
                " 1:238, 1:246)"
            ),
            (
                'Fields "__schema" conflict because subfields "types" conflict'
                ' because subfields "name" conflict because "name" and "kind"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:87, 1:98, 1:106,"
                " 1:227, 1:238, 1:246)"
            ),
            (
                'Fields "__schema" conflict because subfields "types" conflict'
                ' because subfields "name" conflict because "name" and "kind"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:115, 1:126, 1:134,"
                " 1:227, 1:238, 1:246)"
            ),
            (
                'Fields "__schema" conflict because subfields "types" conflict'
                ' because subfields "name" conflict because "name" and "kind"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:143, 1:154, 1:162,"
                " 1:227, 1:238, 1:246)"
            ),
            (
                'Fields "__schema" conflict because subfields "types" conflict'
                ' because subfields "name" conflict because "name" and "kind"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:171, 1:182, 1:190,"
                " 1:227, 1:238, 1:246)"
            ),
            (
                'Fields "__schema" conflict because subfields "types" conflict'
                ' because subfields "name" conflict because "name" and "kind"'
                " are different fields. Use different aliases on the fields to"
                " fetch both if this was intentional. (1:199, 1:210, 1:218,"
                " 1:227, 1:238, 1:246)"
            ),
        ],
    )


def test_equal_inline_fragments() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ o: obj { ... on Obj { x } } o: obj { ... on Obj { x } } o: obj {"
            " ... on Obj { x } } o: obj { ... on Obj { x } } o: obj { ... on"
            " Obj { x } } o: obj { ... on Obj { x } } o: obj { ... on Obj { x }"
            " } o: obj { ... on Obj { x } } o: obj { ... on Obj { x: z } } }"
        ),
        [
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "z" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:3, 1:25,"
                " 1:227, 1:249)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "z" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:31, 1:53,"
                " 1:227, 1:249)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "z" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:59, 1:81,"
                " 1:227, 1:249)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "z" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:87, 1:109,"
                " 1:227, 1:249)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "z" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:115, 1:137,"
                " 1:227, 1:249)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "z" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:143, 1:165,"
                " 1:227, 1:249)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "z" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:171, 1:193,"
                " 1:227, 1:249)"
            ),
            (
                'Fields "o" conflict because subfields "x" conflict because "x"'
                ' and "z" are different fields. Use different aliases on the'
                " fields to fetch both if this was intentional. (1:199, 1:221,"
                " 1:227, 1:249)"
            ),
        ],
    )


def test_an_argument_that_differs_among_equal_leaves() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ hello(a: 1) hello(a: 1) hello(a: 1) hello(a: 1) hello(a: 1)"
            " hello(a: 1) hello(a: 1) hello(a: 1) hello(a: 2) hello(a: 1) }"
        ),
        [
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:99)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:15, 1:99)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:27, 1:99)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:39, 1:99)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:51, 1:99)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:63, 1:99)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:75, 1:99)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:87, 1:99)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:99, 1:111)"
            ),
        ],
    )


def test_equal_fields_with_two_arguments_in_any_order() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            '{ hello(a: 1, s: "x") hello(a: 1, s: "x") hello(a: 1, s: "x")'
            ' hello(a: 1, s: "x") hello(a: 1, s: "x") hello(s: "x", a: 1)'
            ' hello(s: "x", a: 1) hello(s: "x", a: 1) hello(s: "x", a: 1)'
            ' hello(s: "x", a: 1) hello(s: "y", a: 1) }'
        ),
        [
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:3, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:23, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:43, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:63, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:83, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:103, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:123, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:143, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:163, 1:203)"
            ),
            (
                'Fields "hello" conflict because they have differing arguments.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (1:183, 1:203)"
            ),
        ],
    )


def test_equal_fields_with_an_unknown_parent() raises:
    expect_errors_with_schema(
        schema_of(SDL),
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        (
            "{ o: obj { w { x } } o: obj { w { x } } o: obj { w { x } } o: obj"
            " { w { x } } o: obj { w { x } } o: obj { w { x } } o: obj { w { x"
            " } } o: obj { w { x } } o: obj { w { x: y } } }"
        ),
        [
            (
                'Fields "o" conflict because subfields "w" conflict because'
                ' subfields "x" conflict because "x" and "y" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:3, 1:12, 1:16, 1:155, 1:164, 1:168)"
            ),
            (
                'Fields "o" conflict because subfields "w" conflict because'
                ' subfields "x" conflict because "x" and "y" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:22, 1:31, 1:35, 1:155, 1:164, 1:168)"
            ),
            (
                'Fields "o" conflict because subfields "w" conflict because'
                ' subfields "x" conflict because "x" and "y" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:41, 1:50, 1:54, 1:155, 1:164, 1:168)"
            ),
            (
                'Fields "o" conflict because subfields "w" conflict because'
                ' subfields "x" conflict because "x" and "y" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:60, 1:69, 1:73, 1:155, 1:164, 1:168)"
            ),
            (
                'Fields "o" conflict because subfields "w" conflict because'
                ' subfields "x" conflict because "x" and "y" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:79, 1:88, 1:92, 1:155, 1:164, 1:168)"
            ),
            (
                'Fields "o" conflict because subfields "w" conflict because'
                ' subfields "x" conflict because "x" and "y" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:98, 1:107, 1:111, 1:155, 1:164,"
                " 1:168)"
            ),
            (
                'Fields "o" conflict because subfields "w" conflict because'
                ' subfields "x" conflict because "x" and "y" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:117, 1:126, 1:130, 1:155, 1:164,"
                " 1:168)"
            ),
            (
                'Fields "o" conflict because subfields "w" conflict because'
                ' subfields "x" conflict because "x" and "y" are different'
                " fields. Use different aliases on the fields to fetch both if"
                " this was intentional. (1:136, 1:145, 1:149, 1:155, 1:164,"
                " 1:168)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
