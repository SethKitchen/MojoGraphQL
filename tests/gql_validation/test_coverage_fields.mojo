# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests beyond upstream for the type and field rules: they cover
KnownTypeNamesRule on SDL definitions in an executable document,
FieldsOnCorrectTypeRule on an interface with no implementations and on a
first run that ends early, and NoDeprecatedCustomRule on an object value
at a scalar position and on an enum value that is not deprecated.

The expected errors come from graphql-js 16.14.2: each document was run
through `validate` with the same schema and rule.
"""

from _harness import (
    expect_errors,
    expect_errors_with_schema,
    expect_valid,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime SMALL_SDL = "type Query { a: String }"
"""A schema with no `Float`, `Int` or `ID`."""


# --- KnownTypeNamesRule -----------------------------------------------------


def test_type_defined_in_the_document() raises:
    expect_valid(
        ValidationRule.KNOWN_TYPE_NAMES,
        "type Foo { self: Foo } query ($x: Foo) { dog { name } }",
    )


def test_standard_type_names_in_sdl() raises:
    expect_valid_with_schema(
        schema_of(SMALL_SDL),
        ValidationRule.KNOWN_TYPE_NAMES,
        "type Foo { f: Float i: ID } extend type Query { b: Int }",
    )


def test_standard_type_name_outside_sdl() raises:
    expect_errors_with_schema(
        schema_of(SMALL_SDL),
        ValidationRule.KNOWN_TYPE_NAMES,
        "query ($f: Float) { a }",
        ['Unknown type "Float". (1:12)'],
    )


def test_sdl_suggests_standard_and_defined_types() raises:
    expect_errors_with_schema(
        schema_of(SMALL_SDL),
        ValidationRule.KNOWN_TYPE_NAMES,
        "type Flot { f: Flaot }",
        ['Unknown type "Flaot". Did you mean "Float" or "Flot"? (1:16)'],
    )
    expect_errors_with_schema(
        schema_of(SMALL_SDL),
        ValidationRule.KNOWN_TYPE_NAMES,
        "type Strung { f: Strin } query ($s: Strin) { a }",
        [
            'Unknown type "Strin". Did you mean "String" or "Strung"? (1:18)',
            'Unknown type "Strin". Did you mean "String" or "Strung"? (1:37)',
        ],
    )


def test_sdl_suggests_introspection_types() raises:
    expect_errors_with_schema(
        schema_of(SMALL_SDL),
        ValidationRule.KNOWN_TYPE_NAMES,
        "directive @d(a: __TypeKnd) on FIELD",
        [
            'Unknown type "__TypeKnd". Did you mean "__TypeKind" or'
            ' "__Type"? (1:17)'
        ],
    )


# --- FieldsOnCorrectTypeRule ------------------------------------------------


def test_interface_with_no_implementations() raises:
    expect_errors_with_schema(
        schema_of("interface I { a: String } type Query { i: I }"),
        ValidationRule.FIELDS_ON_CORRECT_TYPE,
        "{ i { b } }",
        ['Cannot query field "b" on type "I". Did you mean "a"? (1:7)'],
    )


def test_first_run_ends_before_the_last_type() raises:
    expect_errors_with_schema(
        schema_of(
            "type A { x: Int } type C { x: Int } type B { x: Int } union U = A"
            " | C | B type Query { u: U }"
        ),
        ValidationRule.FIELDS_ON_CORRECT_TYPE,
        "{ u { x } }",
        [
            'Cannot query field "x" on type "U". Did you mean to use an'
            ' inline fragment on "A", "B", or "C"? (1:7)'
        ],
    )


# --- NoDeprecatedCustomRule -------------------------------------------------


def test_object_value_at_a_scalar_position() raises:
    expect_valid(
        ValidationRule.NO_DEPRECATED_CUSTOM,
        "{ complicatedArgs { intArgField(intArg: {a: 1}) } }",
    )


def test_enum_value_that_is_not_deprecated() raises:
    expect_valid(
        ValidationRule.NO_DEPRECATED_CUSTOM,
        "{ complicatedArgs { enumArgField(enumArg: BROWN) } }",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
