# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueFieldDefinitionNamesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_fields() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      type SomeObject
      interface SomeInterface
      input SomeInputObject
    """,
    )


def test_one_field() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      type SomeObject {
        foo: String
      }

      interface SomeInterface {
        foo: String
      }

      input SomeInputObject {
        foo: String
      }
    """,
    )


def test_multiple_fields() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      type SomeObject {
        foo: String
        bar: String
      }

      interface SomeInterface {
        foo: String
        bar: String
      }

      input SomeInputObject {
        foo: String
        bar: String
      }
    """,
    )


def test_duplicate_fields_inside_the_same_type_definition() raises:
    expect_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      type SomeObject {
        foo: String
        bar: String
        foo: String
      }

      interface SomeInterface {
        foo: String
        bar: String
        foo: String
      }

      input SomeInputObject {
        foo: String
        bar: String
        foo: String
      }
    """,
        [
            'Field "SomeObject.foo" can only be defined once. (3:9, 5:9)',
            'Field "SomeInterface.foo" can only be defined once. (9:9, 11:9)',
            (
                'Field "SomeInputObject.foo" can only be defined once. (15:9,'
                " 17:9)"
            ),
        ],
    )


def test_extend_type_with_new_field() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      type SomeObject {
        foo: String
      }
      extend type SomeObject {
        bar: String
      }
      extend type SomeObject {
        baz: String
      }

      interface SomeInterface {
        foo: String
      }
      extend interface SomeInterface {
        bar: String
      }
      extend interface SomeInterface {
        baz: String
      }

      input SomeInputObject {
        foo: String
      }
      extend input SomeInputObject {
        bar: String
      }
      extend input SomeInputObject {
        baz: String
      }
    """,
    )


def test_extend_type_with_duplicate_field() raises:
    expect_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      extend type SomeObject {
        foo: String
      }
      type SomeObject {
        foo: String
      }

      extend interface SomeInterface {
        foo: String
      }
      interface SomeInterface {
        foo: String
      }

      extend input SomeInputObject {
        foo: String
      }
      input SomeInputObject {
        foo: String
      }
    """,
        [
            'Field "SomeObject.foo" can only be defined once. (3:9, 6:9)',
            'Field "SomeInterface.foo" can only be defined once. (10:9, 13:9)',
            (
                'Field "SomeInputObject.foo" can only be defined once. (17:9,'
                " 20:9)"
            ),
        ],
    )


def test_duplicate_field_inside_extension() raises:
    expect_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      type SomeObject
      extend type SomeObject {
        foo: String
        bar: String
        foo: String
      }

      interface SomeInterface
      extend interface SomeInterface {
        foo: String
        bar: String
        foo: String
      }

      input SomeInputObject
      extend input SomeInputObject {
        foo: String
        bar: String
        foo: String
      }
    """,
        [
            'Field "SomeObject.foo" can only be defined once. (4:9, 6:9)',
            'Field "SomeInterface.foo" can only be defined once. (11:9, 13:9)',
            (
                'Field "SomeInputObject.foo" can only be defined once. (18:9,'
                " 20:9)"
            ),
        ],
    )


def test_duplicate_field_inside_different_extensions() raises:
    expect_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      type SomeObject
      extend type SomeObject {
        foo: String
      }
      extend type SomeObject {
        foo: String
      }

      interface SomeInterface
      extend interface SomeInterface {
        foo: String
      }
      extend interface SomeInterface {
        foo: String
      }

      input SomeInputObject
      extend input SomeInputObject {
        foo: String
      }
      extend input SomeInputObject {
        foo: String
      }
    """,
        [
            'Field "SomeObject.foo" can only be defined once. (4:9, 7:9)',
            'Field "SomeInterface.foo" can only be defined once. (12:9, 15:9)',
            (
                'Field "SomeInputObject.foo" can only be defined once. (20:9,'
                " 23:9)"
            ),
        ],
    )


def test_adding_new_field_to_the_type_inside_existing_schema() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      extend type SomeObject {
        foo: String
      }

      extend interface SomeInterface {
        foo: String
      }

      extend input SomeInputObject {
        foo: String
      }
    """,
        schema_sdl="""
      type SomeObject
      interface SomeInterface
      input SomeInputObject
    """,
    )


def test_adding_conflicting_fields_to_existing_schema_twice() raises:
    expect_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      extend type SomeObject {
        foo: String
      }
      extend interface SomeInterface {
        foo: String
      }
      extend input SomeInputObject {
        foo: String
      }

      extend type SomeObject {
        foo: String
      }
      extend interface SomeInterface {
        foo: String
      }
      extend input SomeInputObject {
        foo: String
      }
    """,
        [
            (
                'Field "SomeObject.foo" already exists in the schema. It cannot'
                " also be defined in this type extension. (3:9)"
            ),
            (
                'Field "SomeInterface.foo" already exists in the schema. It'
                " cannot also be defined in this type extension. (6:9)"
            ),
            (
                'Field "SomeInputObject.foo" already exists in the schema. It'
                " cannot also be defined in this type extension. (9:9)"
            ),
            (
                'Field "SomeObject.foo" already exists in the schema. It cannot'
                " also be defined in this type extension. (13:9)"
            ),
            (
                'Field "SomeInterface.foo" already exists in the schema. It'
                " cannot also be defined in this type extension. (16:9)"
            ),
            (
                'Field "SomeInputObject.foo" already exists in the schema. It'
                " cannot also be defined in this type extension. (19:9)"
            ),
        ],
        schema_sdl="""
      type SomeObject {
        foo: String
      }

      interface SomeInterface {
        foo: String
      }

      input SomeInputObject {
        foo: String
      }
    """,
    )


def test_adding_fields_to_existing_schema_twice() raises:
    expect_sdl(
        SDLRule.UNIQUE_FIELD_DEFINITION_NAMES,
        """
      extend type SomeObject {
        foo: String
      }
      extend type SomeObject {
        foo: String
      }

      extend interface SomeInterface {
        foo: String
      }
      extend interface SomeInterface {
        foo: String
      }

      extend input SomeInputObject {
        foo: String
      }
      extend input SomeInputObject {
        foo: String
      }
    """,
        [
            'Field "SomeObject.foo" can only be defined once. (3:9, 6:9)',
            'Field "SomeInterface.foo" can only be defined once. (10:9, 13:9)',
            (
                'Field "SomeInputObject.foo" can only be defined once. (17:9,'
                " 20:9)"
            ),
        ],
        schema_sdl="""
      type SomeObject
      interface SomeInterface
      input SomeInputObject
    """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
