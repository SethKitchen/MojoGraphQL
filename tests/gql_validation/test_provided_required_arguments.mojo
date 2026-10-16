# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for ProvidedRequiredArgumentsRule, ported from graphql-js 16.14.2
`src/validation/__tests__/ProvidedRequiredArgumentsRule-test.ts`.

Not ported here: the six cases of the `within SDL` describe block. They
test `ProvidedRequiredArgumentsOnDirectivesRule`, and they are ported in
`tests/gql_schema/test_sdl_provided_required_arguments.mojo`.
"""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_ignores_unknown_arguments() raises:
    expect_valid(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
      {
        dog {
          isHouseTrained(unknownArgument: true)
        }
      }
    """,
    )


def test_arg_on_optional_arg() raises:
    expect_valid(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
        {
          dog {
            isHouseTrained
          }
        }
      """,
    )


def test_no_arg_on_non_null_field_with_default() raises:
    expect_valid(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
        {
          complicatedArgs {
            nonNullFieldWithDefault
          }
        }
      """,
    )


def test_multiple_args() raises:
    expect_valid(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
        {
          complicatedArgs {
            multipleOptAndReq(req1: 3, req2: 4, opt1: 5, opt2: 6)
          }
        }
      """,
    )


def test_missing_one_non_nullable_argument() raises:
    expect_errors(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
        {
          complicatedArgs {
            multipleReqs(req2: 2)
          }
        }
      """,
        [
            'Field "multipleReqs" argument "req1" of type "Int!" is required,'
            " but it was not provided. (4:13)"
        ],
    )


def test_missing_multiple_non_nullable_arguments() raises:
    expect_errors(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
        {
          complicatedArgs {
            multipleReqs
          }
        }
      """,
        [
            (
                'Field "multipleReqs" argument "req1" of type "Int!" is'
                " required, but it was not provided. (4:13)"
            ),
            (
                'Field "multipleReqs" argument "req2" of type "Int!" is'
                " required, but it was not provided. (4:13)"
            ),
        ],
    )


def test_incorrect_value_and_missing_argument() raises:
    expect_errors(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
        {
          complicatedArgs {
            multipleReqs(req1: "one")
          }
        }
      """,
        [
            'Field "multipleReqs" argument "req2" of type "Int!" is required,'
            " but it was not provided. (4:13)"
        ],
    )


def test_ignores_unknown_directives() raises:
    expect_valid(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
        {
          dog @unknown
        }
      """,
    )


def test_with_directives_of_valid_types() raises:
    expect_valid(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
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


def test_with_directive_with_missing_types() raises:
    expect_errors(
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        """
        {
          dog @include {
            name @skip
          }
        }
      """,
        [
            (
                'Directive "@include" argument "if" of type "Boolean!" is'
                " required, but it was not provided. (3:15)"
            ),
            (
                'Directive "@skip" argument "if" of type "Boolean!" is'
                " required, but it was not provided. (4:18)"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
