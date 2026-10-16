# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.sdl_validation`, ported from graphql-js 16.14.2
`src/validation/__tests__/KnownDirectivesRule-test.ts`."""

from _sdl_harness import ALL_RULES, expect_sdl, expect_valid_sdl
from gql_schema.sdl_validation import SDLRule
from std.testing import TestSuite
from _sdl_fixtures import (
    TEST_SCHEMA,
    SCHEMA_WITH_DIRECTIVES,
    SCHEMA_WITH_SDL_DIRECTIVES,
    TEST_SCHEMA_WITH_DIRECTIVES,
)


def test_with_no_directives() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
      query Foo {
        name
        ...Frag
      }

      fragment Frag on Dog {
        name
      }
    """,
        schema_sdl=SCHEMA_WITH_DIRECTIVES,
    )


def test_with_standard_directives() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
      {
        human @skip(if: false) {
          name
          pets {
            ... on Dog @include(if: true) {
              name
            }
          }
        }
      }
    """,
        schema_sdl=SCHEMA_WITH_DIRECTIVES,
    )


def test_with_unknown_directive() raises:
    expect_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
      {
        human @unknown(directive: "value") {
          name
        }
      }
    """,
        [
            'Unknown directive "@unknown". (3:15)',
        ],
        schema_sdl=SCHEMA_WITH_DIRECTIVES,
    )


def test_with_many_unknown_directives() raises:
    expect_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
      {
        __typename @unknown
        human @unknown {
          name
          pets @unknown {
            name
          }
        }
      }
    """,
        [
            'Unknown directive "@unknown". (3:20)',
            'Unknown directive "@unknown". (4:15)',
            'Unknown directive "@unknown". (6:16)',
        ],
        schema_sdl=SCHEMA_WITH_DIRECTIVES,
    )


def test_with_well_placed_directives() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
      query ($var: Boolean @onVariableDefinition) @onQuery {
        human @onField {
          ...Frag @onFragmentSpread
          ... @onInlineFragment {
            name @onField
          }
        }
      }

      mutation @onMutation {
        someField @onField
      }

      subscription @onSubscription {
        someField @onField
      }

      fragment Frag on Human @onFragmentDefinition {
        name @onField
      }
    """,
        schema_sdl=SCHEMA_WITH_DIRECTIVES,
    )


def test_with_misplaced_directives() raises:
    expect_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
      query ($var: Boolean @onQuery) @onMutation {
        human @onQuery {
          ...Frag @onQuery
          ... @onQuery {
            name @onQuery
          }
        }
      }

      mutation @onQuery {
        someField @onQuery
      }

      subscription @onQuery {
        someField @onQuery
      }

      fragment Frag on Human @onQuery {
        name @onQuery
      }
    """,
        [
            (
                'Directive "@onQuery" may not be used on VARIABLE_DEFINITION.'
                " (2:28)"
            ),
            'Directive "@onMutation" may not be used on QUERY. (2:38)',
            'Directive "@onQuery" may not be used on FIELD. (3:15)',
            'Directive "@onQuery" may not be used on FRAGMENT_SPREAD. (4:19)',
            'Directive "@onQuery" may not be used on INLINE_FRAGMENT. (5:15)',
            'Directive "@onQuery" may not be used on FIELD. (6:18)',
            'Directive "@onQuery" may not be used on MUTATION. (11:16)',
            'Directive "@onQuery" may not be used on FIELD. (12:19)',
            'Directive "@onQuery" may not be used on SUBSCRIPTION. (15:20)',
            'Directive "@onQuery" may not be used on FIELD. (16:19)',
            (
                'Directive "@onQuery" may not be used on FRAGMENT_DEFINITION.'
                " (19:30)"
            ),
            'Directive "@onQuery" may not be used on FIELD. (20:14)',
        ],
        schema_sdl=SCHEMA_WITH_DIRECTIVES,
    )


def test_with_directive_defined_inside_sdl() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
        type Query {
          foo: String @test
        }

        directive @test on FIELD_DEFINITION
      """,
    )


def test_with_standard_directive() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
        type Query {
          foo: String @deprecated
        }
      """,
    )


def test_with_overridden_standard_directive() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
        schema @deprecated {
          query: Query
        }
        directive @deprecated on SCHEMA
      """,
    )


def test_with_directive_defined_in_schema_extension() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
          directive @test on OBJECT

          extend type Query @test
        """,
        schema_sdl="""
        type Query {
          foo: String
        }
      """,
    )


def test_with_directive_used_in_schema_extension() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
          extend type Query @test
        """,
        schema_sdl="""
        directive @test on OBJECT

        type Query {
          foo: String
        }
      """,
    )


def test_with_unknown_directive_in_schema_extension() raises:
    expect_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
          extend type Query @unknown
        """,
        [
            'Unknown directive "@unknown". (2:29)',
        ],
        schema_sdl="""
        type Query {
          foo: String
        }
      """,
    )


def test_with_well_placed_directives_2() raises:
    expect_valid_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
          type MyObj implements MyInterface @onObject {
            myField(myArg: Int @onArgumentDefinition): String @onFieldDefinition
          }

          extend type MyObj @onObject

          scalar MyScalar @onScalar

          extend scalar MyScalar @onScalar

          interface MyInterface @onInterface {
            myField(myArg: Int @onArgumentDefinition): String @onFieldDefinition
          }

          extend interface MyInterface @onInterface

          union MyUnion @onUnion = MyObj | Other

          extend union MyUnion @onUnion

          enum MyEnum @onEnum {
            MY_VALUE @onEnumValue
          }

          extend enum MyEnum @onEnum

          input MyInput @onInputObject {
            myField: Int @onInputFieldDefinition
          }

          extend input MyInput @onInputObject

          schema @onSchema {
            query: MyQuery
          }

          extend schema @onSchema
          
          directive @myDirective on OBJECT
        """,
        schema_sdl=SCHEMA_WITH_SDL_DIRECTIVES,
    )


def test_with_misplaced_directives_2() raises:
    expect_sdl(
        SDLRule.KNOWN_DIRECTIVES,
        """
          type MyObj implements MyInterface @onInterface {
            myField(myArg: Int @onInputFieldDefinition): String @onInputFieldDefinition
          }

          scalar MyScalar @onEnum

          interface MyInterface @onObject {
            myField(myArg: Int @onInputFieldDefinition): String @onInputFieldDefinition
          }

          union MyUnion @onEnumValue = MyObj | Other

          enum MyEnum @onScalar {
            MY_VALUE @onUnion
          }

          input MyInput @onEnum {
            myField: Int @onArgumentDefinition
          }

          schema @onObject {
            query: MyQuery
          }

          extend schema @onObject
          
          extend type MyObj @onDirective
        """,
        [
            'Directive "@onInterface" may not be used on OBJECT. (2:45)',
            (
                'Directive "@onInputFieldDefinition" may not be used on'
                " ARGUMENT_DEFINITION. (3:32)"
            ),
            (
                'Directive "@onInputFieldDefinition" may not be used on'
                " FIELD_DEFINITION. (3:65)"
            ),
            'Directive "@onEnum" may not be used on SCALAR. (6:27)',
            'Directive "@onObject" may not be used on INTERFACE. (8:33)',
            (
                'Directive "@onInputFieldDefinition" may not be used on'
                " ARGUMENT_DEFINITION. (9:32)"
            ),
            (
                'Directive "@onInputFieldDefinition" may not be used on'
                " FIELD_DEFINITION. (9:65)"
            ),
            'Directive "@onEnumValue" may not be used on UNION. (12:25)',
            'Directive "@onScalar" may not be used on ENUM. (14:23)',
            'Directive "@onUnion" may not be used on ENUM_VALUE. (15:22)',
            'Directive "@onEnum" may not be used on INPUT_OBJECT. (18:25)',
            (
                'Directive "@onArgumentDefinition" may not be used on'
                " INPUT_FIELD_DEFINITION. (19:26)"
            ),
            'Directive "@onObject" may not be used on SCHEMA. (22:18)',
            'Directive "@onObject" may not be used on SCHEMA. (26:25)',
            'Directive "@onDirective" may not be used on OBJECT. (28:29)',
        ],
        schema_sdl=SCHEMA_WITH_SDL_DIRECTIVES,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
