# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for OverlappingFieldsCanBeMergedRule, ported from graphql-js 16.14.2
`src/validation/__tests__/OverlappingFieldsCanBeMergedRule-test.ts`.

The `return types must be unambiguous` describe block is ported in
`test_overlapping_fields_can_be_merged_schemas.mojo`. All the other upstream
cases are ported here, in upstream order.
"""

from _harness import (
    expect_errors,
    expect_valid,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED
"""The rule under test."""


def test_unique_fields() raises:
    expect_valid(
        RULE,
        """
      fragment uniqueFields on Dog {
        name
        nickname
      }
    """,
    )


def test_identical_fields() raises:
    expect_valid(
        RULE,
        """
      fragment mergeIdenticalFields on Dog {
        name
        name
      }
    """,
    )


def test_identical_fields_with_identical_args() raises:
    expect_valid(
        RULE,
        """
      fragment mergeIdenticalFieldsWithIdenticalArgs on Dog {
        doesKnowCommand(dogCommand: SIT)
        doesKnowCommand(dogCommand: SIT)
      }
    """,
    )


def test_identical_fields_with_identical_directives() raises:
    expect_valid(
        RULE,
        """
      fragment mergeSameFieldsWithSameDirectives on Dog {
        name @include(if: true)
        name @include(if: true)
      }
    """,
    )


def test_different_args_with_different_aliases() raises:
    expect_valid(
        RULE,
        """
      fragment differentArgsWithDifferentAliases on Dog {
        knowsSit: doesKnowCommand(dogCommand: SIT)
        knowsDown: doesKnowCommand(dogCommand: DOWN)
      }
    """,
    )


def test_different_directives_with_different_aliases() raises:
    expect_valid(
        RULE,
        """
      fragment differentDirectivesWithDifferentAliases on Dog {
        nameIfTrue: name @include(if: true)
        nameIfFalse: name @include(if: false)
      }
    """,
    )


def test_different_skip_include_directives_accepted() raises:
    # Note: Differing skip/include directives don't create an ambiguous return
    # value and are acceptable in conditions where differing runtime values
    # may have the same desired effect of including or skipping a field.
    expect_valid(
        RULE,
        """
      fragment differentDirectivesWithDifferentAliases on Dog {
        name @include(if: true)
        name @include(if: false)
      }
    """,
    )


def test_same_aliases_with_different_field_targets() raises:
    expect_errors(
        RULE,
        """
      fragment sameAliasesWithDifferentFieldTargets on Dog {
        fido: name
        fido: nickname
      }
    """,
        [
            'Fields "fido" conflict because "name" and "nickname" are different'
            " fields. Use different aliases on the fields to fetch both if this"
            " was intentional. (3:9, 4:9)"
        ],
    )


def test_same_aliases_allowed_on_non_overlapping_fields() raises:
    # This is valid since no object can be both a "Dog" and a "Cat", thus
    # these fields can never overlap.
    expect_valid(
        RULE,
        """
      fragment sameAliasesWithDifferentFieldTargets on Pet {
        ... on Dog {
          name
        }
        ... on Cat {
          name: nickname
        }
      }
    """,
    )


def test_alias_masking_direct_field_access() raises:
    expect_errors(
        RULE,
        """
      fragment aliasMaskingDirectFieldAccess on Dog {
        name: nickname
        name
      }
    """,
        [
            'Fields "name" conflict because "nickname" and "name" are different'
            " fields. Use different aliases on the fields to fetch both if this"
            " was intentional. (3:9, 4:9)"
        ],
    )


def test_different_args_second_adds_an_argument() raises:
    expect_errors(
        RULE,
        """
      fragment conflictingArgs on Dog {
        doesKnowCommand
        doesKnowCommand(dogCommand: HEEL)
      }
    """,
        [
            'Fields "doesKnowCommand" conflict because they have differing'
            " arguments. Use different aliases on the fields to fetch both if"
            " this was intentional. (3:9, 4:9)"
        ],
    )


def test_different_args_second_missing_an_argument() raises:
    expect_errors(
        RULE,
        """
      fragment conflictingArgs on Dog {
        doesKnowCommand(dogCommand: SIT)
        doesKnowCommand
      }
    """,
        [
            'Fields "doesKnowCommand" conflict because they have differing'
            " arguments. Use different aliases on the fields to fetch both if"
            " this was intentional. (3:9, 4:9)"
        ],
    )


def test_conflicting_arg_values() raises:
    expect_errors(
        RULE,
        """
      fragment conflictingArgs on Dog {
        doesKnowCommand(dogCommand: SIT)
        doesKnowCommand(dogCommand: HEEL)
      }
    """,
        [
            'Fields "doesKnowCommand" conflict because they have differing'
            " arguments. Use different aliases on the fields to fetch both if"
            " this was intentional. (3:9, 4:9)"
        ],
    )


def test_conflicting_arg_names() raises:
    expect_errors(
        RULE,
        """
      fragment conflictingArgs on Dog {
        isAtLocation(x: 0)
        isAtLocation(y: 0)
      }
    """,
        [
            'Fields "isAtLocation" conflict because they have differing'
            " arguments. Use different aliases on the fields to fetch both if"
            " this was intentional. (3:9, 4:9)"
        ],
    )


def test_allows_different_args_where_no_conflict_is_possible() raises:
    # This is valid since no object can be both a "Dog" and a "Cat", thus
    # these fields can never overlap.
    expect_valid(
        RULE,
        """
      fragment conflictingArgs on Pet {
        ... on Dog {
          name(surname: true)
        }
        ... on Cat {
          name
        }
      }
    """,
    )


def test_allows_different_order_of_args() raises:
    var schema = schema_of(
        """
      type Query {
        someField(a: String, b: String): String
      }
    """
    )

    # This is valid since arguments are unordered, see:
    # https://spec.graphql.org/draft/#sec-Language.Arguments.Arguments-are-unordered
    expect_valid_with_schema(
        schema,
        RULE,
        """
        {
          someField(a: null, b: null)
          someField(b: null, a: null)
        }
      """,
    )


def test_allows_different_order_of_input_object_fields_in_arg_values() raises:
    var schema = schema_of(
        """
      input SomeInput {
        a: String
        b: String
      }

      type Query {
        someField(arg: SomeInput): String
      }
    """
    )

    # This is valid since input object fields are unordered, see:
    # https://spec.graphql.org/draft/#sec-Input-Object-Values.Input-object-fields-are-unordered
    expect_valid_with_schema(
        schema,
        RULE,
        """
        {
          someField(arg: { a: null, b: null })
          someField(arg: { b: null, a: null })
        }
      """,
    )


def test_encounters_conflict_in_fragments() raises:
    expect_errors(
        RULE,
        """
      {
        ...A
        ...B
      }
      fragment A on Type {
        x: a
      }
      fragment B on Type {
        x: b
      }
    """,
        [
            'Fields "x" conflict because "a" and "b" are different fields. Use'
            " different aliases on the fields to fetch both if this was"
            " intentional. (7:9, 10:9)"
        ],
    )


def test_reports_each_conflict_once() raises:
    expect_errors(
        RULE,
        """
      {
        f1 {
          ...A
          ...B
        }
        f2 {
          ...B
          ...A
        }
        f3 {
          ...A
          ...B
          x: c
        }
      }
      fragment A on Type {
        x: a
      }
      fragment B on Type {
        x: b
      }
    """,
        [
            (
                'Fields "x" conflict because "a" and "b" are different fields.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (18:9, 21:9)"
            ),
            (
                'Fields "x" conflict because "c" and "a" are different fields.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (14:11, 18:9)"
            ),
            (
                'Fields "x" conflict because "c" and "b" are different fields.'
                " Use different aliases on the fields to fetch both if this was"
                " intentional. (14:11, 21:9)"
            ),
        ],
    )


def test_deep_conflict() raises:
    expect_errors(
        RULE,
        """
      {
        field {
          x: a
        },
        field {
          x: b
        }
      }
    """,
        [
            'Fields "field" conflict because subfields "x" conflict because "a"'
            ' and "b" are different fields. Use different aliases on the fields'
            " to fetch both if this was intentional. (3:9, 4:11, 6:9, 7:11)"
        ],
    )


def test_deep_conflict_with_multiple_issues() raises:
    expect_errors(
        RULE,
        """
      {
        field {
          x: a
          y: c
        },
        field {
          x: b
          y: d
        }
      }
    """,
        [
            'Fields "field" conflict because subfields "x" conflict because "a"'
            ' and "b" are different fields and subfields "y" conflict because'
            ' "c" and "d" are different fields. Use different aliases on the'
            " fields to fetch both if this was intentional. (3:9, 4:11, 5:11,"
            " 7:9, 8:11, 9:11)"
        ],
    )


def test_very_deep_conflict() raises:
    expect_errors(
        RULE,
        """
      {
        field {
          deepField {
            x: a
          }
        },
        field {
          deepField {
            x: b
          }
        }
      }
    """,
        [
            'Fields "field" conflict because subfields "deepField" conflict'
            ' because subfields "x" conflict because "a" and "b" are different'
            " fields. Use different aliases on the fields to fetch both if this"
            " was intentional. (3:9, 4:11, 5:13, 8:9, 9:11, 10:13)"
        ],
    )


def test_reports_deep_conflict_to_nearest_common_ancestor() raises:
    expect_errors(
        RULE,
        """
      {
        field {
          deepField {
            x: a
          }
          deepField {
            x: b
          }
        },
        field {
          deepField {
            y
          }
        }
      }
    """,
        [
            'Fields "deepField" conflict because subfields "x" conflict because'
            ' "a" and "b" are different fields. Use different aliases on the'
            " fields to fetch both if this was intentional. (4:11, 5:13, 7:11,"
            " 8:13)"
        ],
    )


def test_reports_deep_conflict_to_nearest_common_ancestor_in_fragments() raises:
    expect_errors(
        RULE,
        """
      {
        field {
          ...F
        }
        field {
          ...F
        }
      }
      fragment F on T {
        deepField {
          deeperField {
            x: a
          }
          deeperField {
            x: b
          }
        },
        deepField {
          deeperField {
            y
          }
        }
      }
    """,
        [
            'Fields "deeperField" conflict because subfields "x" conflict'
            ' because "a" and "b" are different fields. Use different aliases'
            " on the fields to fetch both if this was intentional. (12:11,"
            " 13:13, 15:11, 16:13)"
        ],
    )


def test_reports_deep_conflict_in_nested_fragments() raises:
    expect_errors(
        RULE,
        """
      {
        field {
          ...F
        }
        field {
          ...I
        }
      }
      fragment F on T {
        x: a
        ...G
      }
      fragment G on T {
        y: c
      }
      fragment I on T {
        y: d
        ...J
      }
      fragment J on T {
        x: b
      }
    """,
        [
            'Fields "field" conflict because subfields "x" conflict because "a"'
            ' and "b" are different fields and subfields "y" conflict because'
            ' "c" and "d" are different fields. Use different aliases on the'
            " fields to fetch both if this was intentional. (3:9, 11:9, 15:9,"
            " 6:9, 22:9, 18:9)"
        ],
    )


def test_reports_deep_conflict_after_nested_fragments() raises:
    expect_errors(
        RULE,
        """
      fragment F on T {
        ...G
      }
      fragment G on T {
        ...H
      }
      fragment H on T {
        x: a
      }
      {
        x: b
        ...F
      }
    """,
        [
            'Fields "x" conflict because "b" and "a" are different fields. Use'
            " different aliases on the fields to fetch both if this was"
            " intentional. (12:9, 9:9)"
        ],
    )


def test_ignores_unknown_fragments() raises:
    expect_valid(
        RULE,
        """
      {
        field
        ...Unknown
        ...Known
      }

      fragment Known on T {
        field
        ...OtherUnknown
      }
    """,
    )


def test_does_not_infinite_loop_on_recursive_fragment() raises:
    expect_valid(
        RULE,
        """
      {
        ...fragA
      }

      fragment fragA on Human { name, relatives { name, ...fragA } }
    """,
    )


def test_does_not_infinite_loop_on_immediately_recursive_fragment() raises:
    expect_valid(
        RULE,
        """
      {
        ...fragA
      }

      fragment fragA on Human { name, ...fragA }
    """,
    )


def test_does_not_infinite_loop_on_recursive_fragment_with_a_field_named_after_fragment() raises:
    expect_valid(
        RULE,
        """
      {
        ...fragA
        fragA
      }

      fragment fragA on Query { ...fragA }
    """,
    )


def test_finds_invalid_cases_even_with_field_named_after_fragment() raises:
    expect_errors(
        RULE,
        """
      {
        fragA
        ...fragA
      }

      fragment fragA on Type {
        fragA: b
      }
    """,
        [
            'Fields "fragA" conflict because "fragA" and "b" are different'
            " fields. Use different aliases on the fields to fetch both if this"
            " was intentional. (3:9, 8:9)"
        ],
    )


def test_does_not_infinite_loop_on_transitively_recursive_fragment() raises:
    expect_valid(
        RULE,
        """
      {
        ...fragA
        fragB
      }

      fragment fragA on Human { name, ...fragB }
      fragment fragB on Human { name, ...fragC }
      fragment fragC on Human { name, ...fragA }
    """,
    )


def test_finds_invalid_case_even_with_immediately_recursive_fragment() raises:
    expect_errors(
        RULE,
        """
      fragment sameAliasesWithDifferentFieldTargets on Dog {
        ...sameAliasesWithDifferentFieldTargets
        fido: name
        fido: nickname
      }
    """,
        [
            'Fields "fido" conflict because "name" and "nickname" are different'
            " fields. Use different aliases on the fields to fetch both if this"
            " was intentional. (4:9, 5:9)"
        ],
    )


def test_does_not_infinite_loop_on_recursive_fragments_separated_by_fields() raises:
    expect_valid(
        RULE,
        """
      {
        ...fragA
        ...fragB
      }

      fragment fragA on T {
        x {
          ...fragA
          x {
            ...fragA
          }
        }
      }

      fragment fragB on T {
        x {
          ...fragB
          x {
            ...fragB
          }
        }
      }
    """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
