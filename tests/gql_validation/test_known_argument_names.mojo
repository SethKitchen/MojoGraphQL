# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for KnownArgumentNamesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/KnownArgumentNamesRule-test.ts`.

Not ported here: the seven cases of the `within SDL` describe block. They
test `KnownArgumentNamesOnDirectivesRule`, and they are ported in
`tests/gql_schema/test_sdl_known_argument_names.mojo`.
"""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_single_arg_is_known() raises:
    expect_valid(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      fragment argOnRequiredArg on Dog {
        doesKnowCommand(dogCommand: SIT)
      }
    """,
    )


def test_multiple_args_are_known() raises:
    expect_valid(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      fragment multipleArgs on ComplicatedArgs {
        multipleReqs(req1: 1, req2: 2)
      }
    """,
    )


def test_ignores_args_of_unknown_fields() raises:
    expect_valid(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      fragment argOnUnknownField on Dog {
        unknownField(unknownArg: SIT)
      }
    """,
    )


def test_multiple_args_in_reverse_order_are_known() raises:
    expect_valid(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      fragment multipleArgsReverseOrder on ComplicatedArgs {
        multipleReqs(req2: 2, req1: 1)
      }
    """,
    )


def test_no_args_on_optional_arg() raises:
    expect_valid(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      fragment noArgOnOptionalArg on Dog {
        isHouseTrained
      }
    """,
    )


def test_args_are_known_deeply() raises:
    expect_valid(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      {
        dog {
          doesKnowCommand(dogCommand: SIT)
        }
        human {
          pet {
            ... on Dog {
              doesKnowCommand(dogCommand: SIT)
            }
          }
        }
      }
    """,
    )


def test_directive_args_are_known() raises:
    expect_valid(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      {
        dog @skip(if: true)
      }
    """,
    )


def test_field_args_are_invalid() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      {
        dog @skip(unless: true)
      }
    """,
        ['Unknown argument "unless" on directive "@skip". (3:19)'],
    )


def test_directive_without_args_is_valid() raises:
    expect_valid(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      {
        dog @onField
      }
    """,
    )


def test_arg_passed_to_directive_without_arg_is_reported() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      {
        dog @onField(if: true)
      }
    """,
        ['Unknown argument "if" on directive "@onField". (3:22)'],
    )


def test_misspelled_directive_args_are_reported() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      {
        dog @skip(iff: true)
      }
    """,
        [
            'Unknown argument "iff" on directive "@skip". Did you mean "if"?'
            " (3:19)"
        ],
    )


def test_invalid_arg_name() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      fragment invalidArgName on Dog {
        doesKnowCommand(unknown: true)
      }
    """,
        ['Unknown argument "unknown" on field "Dog.doesKnowCommand". (3:25)'],
    )


def test_misspelled_arg_name_is_reported() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      fragment invalidArgName on Dog {
        doesKnowCommand(DogCommand: true)
      }
    """,
        [
            'Unknown argument "DogCommand" on field "Dog.doesKnowCommand".'
            ' Did you mean "dogCommand"? (3:25)'
        ],
    )


def test_unknown_args_amongst_known_args() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      fragment oneGoodArgOneInvalidArg on Dog {
        doesKnowCommand(whoKnows: 1, dogCommand: SIT, unknown: true)
      }
    """,
        [
            (
                'Unknown argument "whoKnows" on field "Dog.doesKnowCommand".'
                " (3:25)"
            ),
            'Unknown argument "unknown" on field "Dog.doesKnowCommand". (3:55)',
        ],
    )


def test_unknown_args_deeply() raises:
    expect_errors(
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        """
      {
        dog {
          doesKnowCommand(unknown: true)
        }
        human {
          pet {
            ... on Dog {
              doesKnowCommand(unknown: true)
            }
          }
        }
      }
    """,
        [
            'Unknown argument "unknown" on field "Dog.doesKnowCommand". (4:27)',
            'Unknown argument "unknown" on field "Dog.doesKnowCommand". (9:31)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
