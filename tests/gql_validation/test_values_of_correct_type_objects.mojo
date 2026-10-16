# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for ValuesOfCorrectTypeRule, ported from graphql-js 16.14.2
`src/validation/__tests__/ValuesOfCorrectTypeRule-test.ts`.

This file has the input object, oneOf, directive and variable default
cases. The scalar, enum, list and non-null cases are in
`test_values_of_correct_type.mojo`.

Not ported, because a schema built from SDL cannot give a scalar a custom
`parseValue` or `parseLiteral` function:

- `reports original error for custom scalar which throws` (the scalar
  `parseValue` throws, and the test reads `originalError`).
- `reports error for custom scalar that returns undefined` (the scalar
  `parseValue` returns `undefined`).

`allows custom scalar to accept complex literals` is ported: its scalar has
the default `parseLiteral`, which SDL `scalar Any` expresses.
"""

from _harness import (
    expect_errors,
    expect_valid,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.VALUES_OF_CORRECT_TYPE
"""The rule under test."""


# Valid input object value


def test_optional_arg_despite_required_field_in_type() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField
          }
        }
      """,
    )


def test_partial_object_only_required() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: { requiredField: true })
          }
        }
      """,
    )


def test_partial_object_required_field_can_be_falsy() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: { requiredField: false })
          }
        }
      """,
    )


def test_partial_object_including_required() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: { requiredField: true, intField: 4 })
          }
        }
      """,
    )


def test_full_object() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: {
              requiredField: true,
              intField: 4,
              stringField: "foo",
              booleanField: false,
              stringListField: ["one", "two"]
            })
          }
        }
      """,
    )


def test_full_object_with_fields_in_different_order() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: {
              stringListField: ["one", "two"],
              booleanField: false,
              requiredField: true,
              stringField: "foo",
              intField: 4,
            })
          }
        }
      """,
    )


# Valid oneOf input object value


def test_exactly_one_field() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            oneOfArgField(oneOfArg: { stringField: "abc" })
          }
        }
      """,
    )


def test_exactly_one_non_nullable_variable() raises:
    expect_valid(
        RULE,
        """
        query ($string: String!) {
          complicatedArgs {
            oneOfArgField(oneOfArg: { stringField: $string })
          }
        }
      """,
    )


# Invalid input object value


def test_partial_object_missing_required() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: { intField: 4 })
          }
        }
      """,
        [
            'Field "ComplexInput.requiredField" of required type'
            ' "Boolean!" was not provided. (4:41)'
        ],
    )


def test_partial_object_invalid_field_type() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: {
              stringListField: ["one", 2],
              requiredField: true,
            })
          }
        }
      """,
        ["String cannot represent a non string value: 2 (5:40)"],
    )


def test_partial_object_null_to_non_null_field() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: {
              requiredField: true,
              nonNullField: null,
            })
          }
        }
      """,
        ['Expected value of type "Boolean!", found null. (6:29)'],
    )


def test_partial_object_unknown_field_arg() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            complexArgField(complexArg: {
              requiredField: true,
              invalidField: "value"
            })
          }
        }
      """,
        [
            'Field "invalidField" is not defined by type "ComplexInput".'
            ' Did you mean "intField"? (6:15)'
        ],
    )


def test_allows_custom_scalar_to_accept_complex_literals() raises:
    var schema = schema_of(
        """
        scalar Any

        type Query {
          anyArg(arg: Any): String
        }
        """
    )
    expect_valid_with_schema(
        schema,
        RULE,
        """
          {
            test1: anyArg(arg: 123)
            test2: anyArg(arg: "abc")
            test3: anyArg(arg: [123, "abc"])
            test4: anyArg(arg: {deep: [123, "abc"]})
          }
        """,
    )


# Invalid oneOf input object value


def test_invalid_field_type() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            oneOfArgField(oneOfArg: { stringField: 2 })
          }
        }
      """,
        ["String cannot represent a non string value: 2 (4:52)"],
    )


def test_exactly_one_null_field() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            oneOfArgField(oneOfArg: { stringField: null })
          }
        }
      """,
        ['Field "OneOfInput.stringField" must be non-null. (4:37)'],
    )


def test_more_than_one_field() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            oneOfArgField(oneOfArg: { stringField: "abc", intField: 123 })
          }
        }
      """,
        [
            'OneOf Input Object "OneOfInput" must specify exactly one key.'
            " (4:37)"
        ],
    )


# Directive arguments


def test_with_directives_of_valid_types() raises:
    expect_valid(
        RULE,
        """
        {
          dog @include(if: true) {
            name
          }
          human @skip(if: false) {
            name
          }
        }
      """,
    )


def test_with_directive_with_incorrect_types() raises:
    expect_errors(
        RULE,
        """
        {
          dog @include(if: "yes") {
            name @skip(if: ENUM)
          }
        }
      """,
        [
            'Boolean cannot represent a non boolean value: "yes" (3:28)',
            "Boolean cannot represent a non boolean value: ENUM (4:28)",
        ],
    )


# Variable default values


def test_variables_with_valid_default_values() raises:
    expect_valid(
        RULE,
        """
        query WithDefaultValues(
          $a: Int = 1,
          $b: String = "ok",
          $c: ComplexInput = { requiredField: true, intField: 3 }
          $d: Int! = 123
        ) {
          dog { name }
        }
      """,
    )


def test_variables_with_valid_default_null_values() raises:
    expect_valid(
        RULE,
        """
        query WithDefaultValues(
          $a: Int = null,
          $b: String = null,
          $c: ComplexInput = { requiredField: true, intField: null }
        ) {
          dog { name }
        }
      """,
    )


def test_variables_with_invalid_default_null_values() raises:
    expect_errors(
        RULE,
        """
        query WithDefaultValues(
          $a: Int! = null,
          $b: String! = null,
          $c: ComplexInput = { requiredField: null, intField: null }
        ) {
          dog { name }
        }
      """,
        [
            'Expected value of type "Int!", found null. (3:22)',
            'Expected value of type "String!", found null. (4:25)',
            'Expected value of type "Boolean!", found null. (5:47)',
        ],
    )


def test_variables_with_invalid_default_values() raises:
    expect_errors(
        RULE,
        """
        query InvalidDefaultValues(
          $a: Int = "one",
          $b: String = 4,
          $c: ComplexInput = "NotVeryComplex"
        ) {
          dog { name }
        }
      """,
        [
            'Int cannot represent non-integer value: "one" (3:21)',
            "String cannot represent a non string value: 4 (4:24)",
            (
                'Expected value of type "ComplexInput", found'
                ' "NotVeryComplex". (5:30)'
            ),
        ],
    )


def test_variables_with_complex_invalid_default_values() raises:
    expect_errors(
        RULE,
        """
        query WithDefaultValues(
          $a: ComplexInput = { requiredField: 123, intField: "abc" }
        ) {
          dog { name }
        }
      """,
        [
            "Boolean cannot represent a non boolean value: 123 (3:47)",
            'Int cannot represent non-integer value: "abc" (3:62)',
        ],
    )


def test_complex_variables_missing_required_field() raises:
    expect_errors(
        RULE,
        """
        query MissingRequiredField($a: ComplexInput = {intField: 3}) {
          dog { name }
        }
      """,
        [
            'Field "ComplexInput.requiredField" of required type'
            ' "Boolean!" was not provided. (2:55)'
        ],
    )


def test_list_variables_with_invalid_item() raises:
    expect_errors(
        RULE,
        """
        query InvalidItem($a: [String] = ["one", 2]) {
          dog { name }
        }
      """,
        ["String cannot represent a non string value: 2 (2:50)"],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
