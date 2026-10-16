# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/PossibleTypeExtensionsRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite


def test_no_extensions() raises:
    expect_valid_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      scalar FooScalar
      type FooObject
      interface FooInterface
      union FooUnion
      enum FooEnum
      input FooInputObject
    """,
    )


def test_one_extension_per_type() raises:
    expect_valid_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      scalar FooScalar
      type FooObject
      interface FooInterface
      union FooUnion
      enum FooEnum
      input FooInputObject

      extend scalar FooScalar @dummy
      extend type FooObject @dummy
      extend interface FooInterface @dummy
      extend union FooUnion @dummy
      extend enum FooEnum @dummy
      extend input FooInputObject @dummy
    """,
    )


def test_many_extensions_per_type() raises:
    expect_valid_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      scalar FooScalar
      type FooObject
      interface FooInterface
      union FooUnion
      enum FooEnum
      input FooInputObject

      extend scalar FooScalar @dummy
      extend type FooObject @dummy
      extend interface FooInterface @dummy
      extend union FooUnion @dummy
      extend enum FooEnum @dummy
      extend input FooInputObject @dummy

      extend scalar FooScalar @dummy
      extend type FooObject @dummy
      extend interface FooInterface @dummy
      extend union FooUnion @dummy
      extend enum FooEnum @dummy
      extend input FooInputObject @dummy
    """,
    )


def test_extending_unknown_type() raises:
    expect_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      type Known

      extend scalar Unknown @dummy
      extend type Unknown @dummy
      extend interface Unknown @dummy
      extend union Unknown @dummy
      extend enum Unknown @dummy
      extend input Unknown @dummy
    """,
        [
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (4:21)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (5:19)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (6:24)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (7:20)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (8:19)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (9:20)'
            ),
        ],
    )


def test_does_not_consider_non_type_definitions() raises:
    expect_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      query Foo { __typename }
      fragment Foo on Query { __typename }
      directive @Foo on SCHEMA

      extend scalar Foo @dummy
      extend type Foo @dummy
      extend interface Foo @dummy
      extend union Foo @dummy
      extend enum Foo @dummy
      extend input Foo @dummy
    """,
        [
            'Cannot extend type "Foo" because it is not defined. (6:21)',
            'Cannot extend type "Foo" because it is not defined. (7:19)',
            'Cannot extend type "Foo" because it is not defined. (8:24)',
            'Cannot extend type "Foo" because it is not defined. (9:20)',
            'Cannot extend type "Foo" because it is not defined. (10:19)',
            'Cannot extend type "Foo" because it is not defined. (11:20)',
        ],
    )


def test_extending_with_different_kinds() raises:
    expect_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      scalar FooScalar
      type FooObject
      interface FooInterface
      union FooUnion
      enum FooEnum
      input FooInputObject

      extend type FooScalar @dummy
      extend interface FooObject @dummy
      extend union FooInterface @dummy
      extend enum FooUnion @dummy
      extend input FooEnum @dummy
      extend scalar FooInputObject @dummy
    """,
        [
            'Cannot extend non-object type "FooScalar". (2:7, 9:7)',
            'Cannot extend non-interface type "FooObject". (3:7, 10:7)',
            'Cannot extend non-union type "FooInterface". (4:7, 11:7)',
            'Cannot extend non-enum type "FooUnion". (5:7, 12:7)',
            'Cannot extend non-input object type "FooEnum". (6:7, 13:7)',
            'Cannot extend non-scalar type "FooInputObject". (7:7, 14:7)',
        ],
    )


def test_extending_types_within_existing_schema() raises:
    expect_valid_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      extend scalar FooScalar @dummy
      extend type FooObject @dummy
      extend interface FooInterface @dummy
      extend union FooUnion @dummy
      extend enum FooEnum @dummy
      extend input FooInputObject @dummy
    """,
        schema_sdl="""
      scalar FooScalar
      type FooObject
      interface FooInterface
      union FooUnion
      enum FooEnum
      input FooInputObject
    """,
    )


def test_extending_unknown_types_within_existing_schema() raises:
    expect_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      extend scalar Unknown @dummy
      extend type Unknown @dummy
      extend interface Unknown @dummy
      extend union Unknown @dummy
      extend enum Unknown @dummy
      extend input Unknown @dummy
    """,
        [
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (2:21)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (3:19)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (4:24)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (5:20)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (6:19)'
            ),
            (
                'Cannot extend type "Unknown" because it is not defined. Did'
                ' you mean "Known"? (7:20)'
            ),
        ],
        schema_sdl="""type Known""",
    )


def test_extending_types_with_different_kinds_within_existing_schema() raises:
    expect_sdl(
        SDLRule.POSSIBLE_TYPE_EXTENSIONS,
        """
      extend type FooScalar @dummy
      extend interface FooObject @dummy
      extend union FooInterface @dummy
      extend enum FooUnion @dummy
      extend input FooEnum @dummy
      extend scalar FooInputObject @dummy
    """,
        [
            'Cannot extend non-object type "FooScalar". (2:7)',
            'Cannot extend non-interface type "FooObject". (3:7)',
            'Cannot extend non-union type "FooInterface". (4:7)',
            'Cannot extend non-enum type "FooUnion". (5:7)',
            'Cannot extend non-input object type "FooEnum". (6:7)',
            'Cannot extend non-scalar type "FooInputObject". (7:7)',
        ],
        schema_sdl="""
      scalar FooScalar
      type FooObject
      interface FooInterface
      union FooUnion
      enum FooEnum
      input FooInputObject
    """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
