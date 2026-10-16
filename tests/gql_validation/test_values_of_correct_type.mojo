# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for ValuesOfCorrectTypeRule, ported from graphql-js 16.14.2
`src/validation/__tests__/ValuesOfCorrectTypeRule-test.ts`.

This file has the scalar, enum, list and non-null cases. The input object,
oneOf, directive and variable default cases are in
`test_values_of_correct_type_objects.mojo`.
"""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.VALUES_OF_CORRECT_TYPE
"""The rule under test."""


# Valid values


def test_good_int_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            intArgField(intArg: 2)
          }
        }
      """,
    )


def test_good_negative_int_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            intArgField(intArg: -2)
          }
        }
      """,
    )


def test_good_boolean_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            booleanArgField(booleanArg: true)
          }
        }
      """,
    )


def test_good_string_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            stringArgField(stringArg: "foo")
          }
        }
      """,
    )


def test_good_float_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            floatArgField(floatArg: 1.1)
          }
        }
      """,
    )


def test_good_negative_float_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            floatArgField(floatArg: -1.1)
          }
        }
      """,
    )


def test_int_into_float() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            floatArgField(floatArg: 1)
          }
        }
      """,
    )


def test_int_into_id() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            idArgField(idArg: 1)
          }
        }
      """,
    )


def test_string_into_id() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            idArgField(idArg: "someIdString")
          }
        }
      """,
    )


def test_good_enum_value() raises:
    expect_valid(
        RULE,
        """
        {
          dog {
            doesKnowCommand(dogCommand: SIT)
          }
        }
      """,
    )


def test_enum_with_undefined_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            enumArgField(enumArg: UNKNOWN)
          }
        }
      """,
    )


def test_enum_with_null_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            enumArgField(enumArg: NO_FUR)
          }
        }
      """,
    )


def test_null_into_nullable_type() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            intArgField(intArg: null)
          }
        }
      """,
    )

    expect_valid(
        RULE,
        """
        {
          dog(a: null, b: null, c:{ requiredField: true, intField: null }) {
            name
          }
        }
      """,
    )


# Invalid String values


def test_int_into_string() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            stringArgField(stringArg: 1)
          }
        }
      """,
        ["String cannot represent a non string value: 1 (4:39)"],
    )


def test_float_into_string() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            stringArgField(stringArg: 1.0)
          }
        }
      """,
        ["String cannot represent a non string value: 1.0 (4:39)"],
    )


def test_boolean_into_string() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            stringArgField(stringArg: true)
          }
        }
      """,
        ["String cannot represent a non string value: true (4:39)"],
    )


def test_unquoted_string_into_string() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            stringArgField(stringArg: BAR)
          }
        }
      """,
        ["String cannot represent a non string value: BAR (4:39)"],
    )


# Invalid Int values


def test_string_into_int() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            intArgField(intArg: "3")
          }
        }
      """,
        ['Int cannot represent non-integer value: "3" (4:33)'],
    )


def test_big_int_into_int() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            intArgField(intArg: 829384293849283498239482938)
          }
        }
      """,
        [
            "Int cannot represent non 32-bit signed integer value:"
            " 829384293849283498239482938 (4:33)"
        ],
    )


def test_unquoted_string_into_int() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            intArgField(intArg: FOO)
          }
        }
      """,
        ["Int cannot represent non-integer value: FOO (4:33)"],
    )


def test_simple_float_into_int() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            intArgField(intArg: 3.0)
          }
        }
      """,
        ["Int cannot represent non-integer value: 3.0 (4:33)"],
    )


def test_float_into_int() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            intArgField(intArg: 3.333)
          }
        }
      """,
        ["Int cannot represent non-integer value: 3.333 (4:33)"],
    )


# Invalid Float values


def test_string_into_float() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            floatArgField(floatArg: "3.333")
          }
        }
      """,
        ['Float cannot represent non numeric value: "3.333" (4:37)'],
    )


def test_boolean_into_float() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            floatArgField(floatArg: true)
          }
        }
      """,
        ["Float cannot represent non numeric value: true (4:37)"],
    )


def test_unquoted_into_float() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            floatArgField(floatArg: FOO)
          }
        }
      """,
        ["Float cannot represent non numeric value: FOO (4:37)"],
    )


# Invalid Boolean value


def test_int_into_boolean() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            booleanArgField(booleanArg: 2)
          }
        }
      """,
        ["Boolean cannot represent a non boolean value: 2 (4:41)"],
    )


def test_float_into_boolean() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            booleanArgField(booleanArg: 1.0)
          }
        }
      """,
        ["Boolean cannot represent a non boolean value: 1.0 (4:41)"],
    )


def test_string_into_boolean() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            booleanArgField(booleanArg: "true")
          }
        }
      """,
        ['Boolean cannot represent a non boolean value: "true" (4:41)'],
    )


def test_unquoted_into_boolean() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            booleanArgField(booleanArg: TRUE)
          }
        }
      """,
        ["Boolean cannot represent a non boolean value: TRUE (4:41)"],
    )


# Invalid ID value


def test_float_into_id() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            idArgField(idArg: 1.0)
          }
        }
      """,
        ["ID cannot represent a non-string and non-integer value: 1.0 (4:31)"],
    )


def test_boolean_into_id() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            idArgField(idArg: true)
          }
        }
      """,
        ["ID cannot represent a non-string and non-integer value: true (4:31)"],
    )


def test_unquoted_into_id() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            idArgField(idArg: SOMETHING)
          }
        }
      """,
        [
            "ID cannot represent a non-string and non-integer value:"
            " SOMETHING (4:31)"
        ],
    )


# Invalid Enum value


def test_int_into_enum() raises:
    expect_errors(
        RULE,
        """
        {
          dog {
            doesKnowCommand(dogCommand: 2)
          }
        }
      """,
        ['Enum "DogCommand" cannot represent non-enum value: 2. (4:41)'],
    )


def test_float_into_enum() raises:
    expect_errors(
        RULE,
        """
        {
          dog {
            doesKnowCommand(dogCommand: 1.0)
          }
        }
      """,
        ['Enum "DogCommand" cannot represent non-enum value: 1.0. (4:41)'],
    )


def test_string_into_enum() raises:
    expect_errors(
        RULE,
        """
        {
          dog {
            doesKnowCommand(dogCommand: "SIT")
          }
        }
      """,
        [
            'Enum "DogCommand" cannot represent non-enum value: "SIT".'
            ' Did you mean the enum value "SIT"? (4:41)'
        ],
    )


def test_boolean_into_enum() raises:
    expect_errors(
        RULE,
        """
        {
          dog {
            doesKnowCommand(dogCommand: true)
          }
        }
      """,
        ['Enum "DogCommand" cannot represent non-enum value: true. (4:41)'],
    )


def test_unknown_enum_value_into_enum() raises:
    expect_errors(
        RULE,
        """
        {
          dog {
            doesKnowCommand(dogCommand: JUGGLE)
          }
        }
      """,
        ['Value "JUGGLE" does not exist in "DogCommand" enum. (4:41)'],
    )


def test_different_case_enum_value_into_enum() raises:
    expect_errors(
        RULE,
        """
        {
          dog {
            doesKnowCommand(dogCommand: sit)
          }
        }
      """,
        [
            'Value "sit" does not exist in "DogCommand" enum. Did you mean'
            ' the enum value "SIT"? (4:41)'
        ],
    )


# Valid List value


def test_good_list_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            stringListArgField(stringListArg: ["one", null, "two"])
          }
        }
      """,
    )


def test_empty_list_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            stringListArgField(stringListArg: [])
          }
        }
      """,
    )


def test_valid_list_value_null_value() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            stringListArgField(stringListArg: null)
          }
        }
      """,
    )


def test_single_value_into_list() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            stringListArgField(stringListArg: "one")
          }
        }
      """,
    )


# Invalid List value


def test_incorrect_item_type() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            stringListArgField(stringListArg: ["one", 2])
          }
        }
      """,
        ["String cannot represent a non string value: 2 (4:55)"],
    )


def test_single_value_of_incorrect_type() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            stringListArgField(stringListArg: 1)
          }
        }
      """,
        ["String cannot represent a non string value: 1 (4:47)"],
    )


# Valid non-nullable value


def test_arg_on_optional_arg() raises:
    expect_valid(
        RULE,
        """
        {
          dog {
            isHouseTrained(atOtherHomes: true)
          }
        }
      """,
    )


def test_no_arg_on_optional_arg() raises:
    expect_valid(
        RULE,
        """
        {
          dog {
            isHouseTrained
          }
        }
      """,
    )


def test_multiple_args() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            multipleReqs(req1: 1, req2: 2)
          }
        }
      """,
    )


def test_multiple_args_reverse_order() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            multipleReqs(req2: 2, req1: 1)
          }
        }
      """,
    )


def test_no_args_on_multiple_optional() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            multipleOpts
          }
        }
      """,
    )


def test_one_arg_on_multiple_optional() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            multipleOpts(opt1: 1)
          }
        }
      """,
    )


def test_second_arg_on_multiple_optional() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            multipleOpts(opt2: 1)
          }
        }
      """,
    )


def test_multiple_required_args_on_mixed_list() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4)
          }
        }
      """,
    )


def test_multiple_required_and_one_optional_arg_on_mixed_list() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4, opt1: 5)
          }
        }
      """,
    )


def test_all_required_and_optional_args_on_mixed_list() raises:
    expect_valid(
        RULE,
        """
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4, opt1: 5, opt2: 6)
          }
        }
      """,
    )


# Invalid non-nullable value


def test_incorrect_value_type() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            multipleReqs(req2: "two", req1: "one")
          }
        }
      """,
        [
            'Int cannot represent non-integer value: "two" (4:32)',
            'Int cannot represent non-integer value: "one" (4:45)',
        ],
    )


def test_incorrect_value_and_missing_argument_provided_required_arguments_rule() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            multipleReqs(req1: "one")
          }
        }
      """,
        ['Int cannot represent non-integer value: "one" (4:32)'],
    )


def test_invalid_non_nullable_value_null_value() raises:
    expect_errors(
        RULE,
        """
        {
          complicatedArgs {
            multipleReqs(req1: null)
          }
        }
      """,
        ['Expected value of type "Int!", found null. (4:32)'],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
