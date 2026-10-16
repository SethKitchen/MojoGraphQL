# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/UniqueEnumValueNamesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_values() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      enum SomeEnum
    """,
    )


def test_one_value() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      enum SomeEnum {
        FOO
      }
    """,
    )


def test_multiple_values() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      enum SomeEnum {
        FOO
        BAR
      }
    """,
    )


def test_duplicate_values_inside_the_same_enum_definition() raises:
    expect_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      enum SomeEnum {
        FOO
        BAR
        FOO
      }
    """,
        [
            'Enum value "SomeEnum.FOO" can only be defined once. (3:9, 5:9)',
        ],
    )


def test_extend_enum_with_new_value() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      enum SomeEnum {
        FOO
      }
      extend enum SomeEnum {
        BAR
      }
      extend enum SomeEnum {
        BAZ
      }
    """,
    )


def test_extend_enum_with_duplicate_value() raises:
    expect_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      extend enum SomeEnum {
        FOO
      }
      enum SomeEnum {
        FOO
      }
    """,
        [
            'Enum value "SomeEnum.FOO" can only be defined once. (3:9, 6:9)',
        ],
    )


def test_duplicate_value_inside_extension() raises:
    expect_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      enum SomeEnum
      extend enum SomeEnum {
        FOO
        BAR
        FOO
      }
    """,
        [
            'Enum value "SomeEnum.FOO" can only be defined once. (4:9, 6:9)',
        ],
    )


def test_duplicate_value_inside_different_extensions() raises:
    expect_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      enum SomeEnum
      extend enum SomeEnum {
        FOO
      }
      extend enum SomeEnum {
        FOO
      }
    """,
        [
            'Enum value "SomeEnum.FOO" can only be defined once. (4:9, 7:9)',
        ],
    )


def test_adding_new_value_to_the_type_inside_existing_schema() raises:
    expect_valid_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      extend enum SomeEnum {
        FOO
      }
    """,
        schema_sdl="""enum SomeEnum""",
    )


def test_adding_conflicting_value_to_existing_schema_twice() raises:
    expect_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      extend enum SomeEnum {
        FOO
      }
      extend enum SomeEnum {
        FOO
      }
    """,
        [
            (
                'Enum value "SomeEnum.FOO" already exists in the schema. It'
                " cannot also be defined in this type extension. (3:9)"
            ),
            (
                'Enum value "SomeEnum.FOO" already exists in the schema. It'
                " cannot also be defined in this type extension. (6:9)"
            ),
        ],
        schema_sdl="""
      enum SomeEnum {
        FOO
      }
    """,
    )


def test_adding_enum_values_to_existing_schema_twice() raises:
    expect_sdl(
        SDLRule.UNIQUE_ENUM_VALUE_NAMES,
        """
      extend enum SomeEnum {
        FOO
      }
      extend enum SomeEnum {
        FOO
      }
    """,
        [
            'Enum value "SomeEnum.FOO" can only be defined once. (3:9, 6:9)',
        ],
        schema_sdl="""enum SomeEnum""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
