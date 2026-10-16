# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/KnownTypeNamesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite
from _sdl_fixtures import (
    TEST_SCHEMA,
    SCHEMA_WITH_DIRECTIVES,
    SCHEMA_WITH_SDL_DIRECTIVES,
    TEST_SCHEMA_WITH_DIRECTIVES,
)


def test_known_type_names_are_valid() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
      query Foo(
        $var: String
        $required: [Int!]!
        $introspectionType: __EnumValue
      ) {
        user(id: 4) {
          pets { ... on Pet { name }, ...PetFields, ... { name } }
        }
      }

      fragment PetFields on Pet {
        name
      }
    """,
        schema_sdl=TEST_SCHEMA,
    )


def test_unknown_type_names_are_invalid() raises:
    expect_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
      query Foo($var: [JumbledUpLetters!]!) {
        user(id: 4) {
          name
          pets { ... on Badger { name }, ...PetFields }
        }
      }
      fragment PetFields on Peat {
        name
      }
    """,
        [
            'Unknown type "JumbledUpLetters". (2:24)',
            'Unknown type "Badger". (5:25)',
            'Unknown type "Peat". Did you mean "Pet" or "Cat"? (8:29)',
        ],
        schema_sdl=TEST_SCHEMA,
    )


def test_references_to_standard_scalars_that_are_missing_in_schema() raises:
    expect_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
      query ($id: ID, $float: Float, $int: Int) {
        __typename
      }
    """,
        [
            'Unknown type "ID". (2:19)',
            'Unknown type "Float". (2:31)',
            'Unknown type "Int". (2:44)',
        ],
        schema_sdl="""type Query { foo: String }""",
    )


def test_use_standard_types() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
        type Query {
          string: String
          int: Int
          float: Float
          boolean: Boolean
          id: ID
          introspectionType: __EnumValue
        }
      """,
    )


def test_reference_types_defined_inside_the_same_document() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
        union SomeUnion = SomeObject | AnotherObject

        type SomeObject implements SomeInterface {
          someScalar(arg: SomeInputObject): SomeScalar
        }

        type AnotherObject {
          foo(arg: SomeInputObject): String
        }

        type SomeInterface {
          someScalar(arg: SomeInputObject): SomeScalar
        }

        input SomeInputObject {
          someScalar: SomeScalar
        }

        scalar SomeScalar

        type RootQuery {
          someInterface: SomeInterface
          someUnion: SomeUnion
          someScalar: SomeScalar
          someObject: SomeObject
        }

        schema {
          query: RootQuery
        }
      """,
    )


def test_unknown_type_references() raises:
    expect_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
        type A
        type B

        type SomeObject implements C {
          e(d: D): E
        }

        union SomeUnion = F | G

        interface SomeInterface {
          i(h: H): I
        }

        input SomeInput {
          j: J
        }

        directive @SomeDirective(k: K) on QUERY

        schema {
          query: L
          mutation: M
          subscription: N
        }
      """,
        [
            'Unknown type "C". Did you mean "A" or "B"? (5:36)',
            'Unknown type "D". Did you mean "A", "B", or "ID"? (6:16)',
            'Unknown type "E". Did you mean "A" or "B"? (6:20)',
            'Unknown type "F". Did you mean "A" or "B"? (9:27)',
            'Unknown type "G". Did you mean "A" or "B"? (9:31)',
            'Unknown type "H". Did you mean "A" or "B"? (12:16)',
            'Unknown type "I". Did you mean "A", "B", or "ID"? (12:20)',
            'Unknown type "J". Did you mean "A" or "B"? (16:14)',
            'Unknown type "K". Did you mean "A" or "B"? (19:37)',
            'Unknown type "L". Did you mean "A" or "B"? (22:18)',
            'Unknown type "M". Did you mean "A" or "B"? (23:21)',
            'Unknown type "N". Did you mean "A" or "B"? (24:25)',
        ],
    )


def test_does_not_consider_non_type_definitions() raises:
    expect_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
        query Foo { __typename }
        fragment Foo on Query { __typename }
        directive @Foo on QUERY

        type Query {
          foo: Foo
        }
      """,
        [
            'Unknown type "Foo". (7:16)',
        ],
    )


def test_reference_standard_types_inside_extension_document() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
        type SomeType {
          string: String
          int: Int
          float: Float
          boolean: Boolean
          id: ID
          introspectionType: __EnumValue
        }
      """,
        schema_sdl="""type Foo""",
    )


def test_reference_types_inside_extension_document() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
        type QueryRoot {
          foo: Foo
          bar: Bar
        }

        scalar Bar

        schema {
          query: QueryRoot
        }
      """,
        schema_sdl="""type Foo""",
    )


def test_unknown_type_references_inside_extension_document() raises:
    expect_sdl(
        SDLRule.KNOWN_TYPE_NAMES,
        """
        type B

        type SomeObject implements C {
          e(d: D): E
        }

        union SomeUnion = F | G

        interface SomeInterface {
          i(h: H): I
        }

        input SomeInput {
          j: J
        }

        directive @SomeDirective(k: K) on QUERY

        schema {
          query: L
          mutation: M
          subscription: N
        }
      """,
        [
            'Unknown type "C". Did you mean "A" or "B"? (4:36)',
            'Unknown type "D". Did you mean "A", "B", or "ID"? (5:16)',
            'Unknown type "E". Did you mean "A" or "B"? (5:20)',
            'Unknown type "F". Did you mean "A" or "B"? (8:27)',
            'Unknown type "G". Did you mean "A" or "B"? (8:31)',
            'Unknown type "H". Did you mean "A" or "B"? (11:16)',
            'Unknown type "I". Did you mean "A", "B", or "ID"? (11:20)',
            'Unknown type "J". Did you mean "A" or "B"? (15:14)',
            'Unknown type "K". Did you mean "A" or "B"? (18:37)',
            'Unknown type "L". Did you mean "A" or "B"? (21:18)',
            'Unknown type "M". Did you mean "A" or "B"? (22:21)',
            'Unknown type "N". Did you mean "A" or "B"? (23:25)',
        ],
        schema_sdl="""type A""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
