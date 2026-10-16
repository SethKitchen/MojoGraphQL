# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for VariablesInAllowedPositionRule, ported from graphql-js 16.14.2
`src/validation/__tests__/VariablesInAllowedPositionRule-test.ts`.

The upstream titles name types, such as `Boolean! => [String]`. A test name
writes `=>` as `to`, `T!` as `non_null_t` and `[T]` as `list_of_t`, so that
two titles do not give the same name.
"""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_boolean_to_boolean() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($booleanArg: Boolean)
      {
        complicatedArgs {
          booleanArgField(booleanArg: $booleanArg)
        }
      }
    """,
    )


def test_boolean_to_boolean_within_fragment() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      fragment booleanArgFrag on ComplicatedArgs {
        booleanArgField(booleanArg: $booleanArg)
      }
      query Query($booleanArg: Boolean)
      {
        complicatedArgs {
          ...booleanArgFrag
        }
      }
    """,
    )

    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($booleanArg: Boolean)
      {
        complicatedArgs {
          ...booleanArgFrag
        }
      }
      fragment booleanArgFrag on ComplicatedArgs {
        booleanArgField(booleanArg: $booleanArg)
      }
    """,
    )


def test_non_null_boolean_to_boolean() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($nonNullBooleanArg: Boolean!)
      {
        complicatedArgs {
          booleanArgField(booleanArg: $nonNullBooleanArg)
        }
      }
    """,
    )


def test_non_null_boolean_to_boolean_within_fragment() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      fragment booleanArgFrag on ComplicatedArgs {
        booleanArgField(booleanArg: $nonNullBooleanArg)
      }

      query Query($nonNullBooleanArg: Boolean!)
      {
        complicatedArgs {
          ...booleanArgFrag
        }
      }
    """,
    )


def test_list_of_string_to_list_of_string() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($stringListVar: [String])
      {
        complicatedArgs {
          stringListArgField(stringListArg: $stringListVar)
        }
      }
    """,
    )


def test_list_of_non_null_string_to_list_of_string() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($stringListVar: [String!])
      {
        complicatedArgs {
          stringListArgField(stringListArg: $stringListVar)
        }
      }
    """,
    )


def test_string_to_list_of_string_in_item_position() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($stringVar: String)
      {
        complicatedArgs {
          stringListArgField(stringListArg: [$stringVar])
        }
      }
    """,
    )


def test_non_null_string_to_list_of_string_in_item_position() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($stringVar: String!)
      {
        complicatedArgs {
          stringListArgField(stringListArg: [$stringVar])
        }
      }
    """,
    )


def test_complex_input_to_complex_input() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($complexVar: ComplexInput)
      {
        complicatedArgs {
          complexArgField(complexArg: $complexVar)
        }
      }
    """,
    )


def test_complex_input_to_complex_input_in_field_position() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($boolVar: Boolean = false)
      {
        complicatedArgs {
          complexArgField(complexArg: {requiredArg: $boolVar})
        }
      }
    """,
    )


def test_non_null_boolean_to_non_null_boolean_in_directive() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($boolVar: Boolean!)
      {
        dog @include(if: $boolVar)
      }
    """,
    )


def test_int_to_non_null_int() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($intArg: Int) {
        complicatedArgs {
          nonNullIntArgField(nonNullIntArg: $intArg)
        }
      }
    """,
        [
            'Variable "$intArg" of type "Int" used in position expecting'
            ' type "Int!". (2:19, 4:45)'
        ],
    )


def test_int_to_non_null_int_within_fragment() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      fragment nonNullIntArgFieldFrag on ComplicatedArgs {
        nonNullIntArgField(nonNullIntArg: $intArg)
      }

      query Query($intArg: Int) {
        complicatedArgs {
          ...nonNullIntArgFieldFrag
        }
      }
    """,
        [
            'Variable "$intArg" of type "Int" used in position expecting'
            ' type "Int!". (6:19, 3:43)'
        ],
    )


def test_int_to_non_null_int_within_nested_fragment() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      fragment outerFrag on ComplicatedArgs {
        ...nonNullIntArgFieldFrag
      }

      fragment nonNullIntArgFieldFrag on ComplicatedArgs {
        nonNullIntArgField(nonNullIntArg: $intArg)
      }

      query Query($intArg: Int) {
        complicatedArgs {
          ...outerFrag
        }
      }
    """,
        [
            'Variable "$intArg" of type "Int" used in position expecting'
            ' type "Int!". (10:19, 7:43)'
        ],
    )


def test_string_over_boolean() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($stringVar: String) {
        complicatedArgs {
          booleanArgField(booleanArg: $stringVar)
        }
      }
    """,
        [
            'Variable "$stringVar" of type "String" used in position'
            ' expecting type "Boolean". (2:19, 4:39)'
        ],
    )


def test_string_to_list_of_string() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($stringVar: String) {
        complicatedArgs {
          stringListArgField(stringListArg: $stringVar)
        }
      }
    """,
        [
            'Variable "$stringVar" of type "String" used in position'
            ' expecting type "[String]". (2:19, 4:45)'
        ],
    )


def test_boolean_to_non_null_boolean_in_directive() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($boolVar: Boolean) {
        dog @include(if: $boolVar)
      }
    """,
        [
            'Variable "$boolVar" of type "Boolean" used in position'
            ' expecting type "Boolean!". (2:19, 3:26)'
        ],
    )


def test_string_to_non_null_boolean_in_directive() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($stringVar: String) {
        dog @include(if: $stringVar)
      }
    """,
        [
            'Variable "$stringVar" of type "String" used in position'
            ' expecting type "Boolean!". (2:19, 3:26)'
        ],
    )


def test_list_of_string_to_list_of_non_null_string() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query Query($stringListVar: [String])
      {
        complicatedArgs {
          stringListNonNullArgField(stringListNonNullArg: $stringListVar)
        }
      }
    """,
        [
            'Variable "$stringListVar" of type "[String]" used in position'
            ' expecting type "[String!]". (2:19, 5:59)'
        ],
    )


def test_int_to_non_null_int_fails_when_variable_provides_null_default_value() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
        query Query($intVar: Int = null) {
          complicatedArgs {
            nonNullIntArgField(nonNullIntArg: $intVar)
          }
        }
      """,
        [
            'Variable "$intVar" of type "Int" used in position expecting'
            ' type "Int!". (2:21, 4:47)'
        ],
    )


def test_int_to_non_null_int_when_variable_provides_non_null_default_value() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
        query Query($intVar: Int = 1) {
          complicatedArgs {
            nonNullIntArgField(nonNullIntArg: $intVar)
          }
        }""",
    )


def test_int_to_non_null_int_when_optional_argument_provides_default_value() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
        query Query($intVar: Int) {
          complicatedArgs {
            nonNullFieldWithDefault(nonNullIntArg: $intVar)
          }
        }""",
    )


def test_boolean_to_non_null_boolean_in_directive_with_default_value_with_option() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
        query Query($boolVar: Boolean = false) {
          dog @include(if: $boolVar)
        }""",
    )


def test_allows_exactly_one_non_nullable_variable() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query ($string: String!) {
        complicatedArgs {
          oneOfArgField(oneOfArg: { stringField: $string })
        }
      }
    """,
    )


def test_undefined_variable_in_one_of_input_object() raises:
    expect_valid(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      {
        complicatedArgs {
          oneOfArgField(oneOfArg: { stringField: $undefinedVariable })
        }
      }
    """,
    )


def test_forbids_one_nullable_variable() raises:
    expect_errors(
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        """
      query ($string: String) {
        complicatedArgs {
          oneOfArgField(oneOfArg: { stringField: $string })
        }
      }
    """,
        [
            'Variable "$string" is of type "String" but must be'
            " non-nullable to be used for OneOf Input Object"
            ' "OneOfInput". (2:14, 4:50)'
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
