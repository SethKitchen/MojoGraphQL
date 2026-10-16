# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for ScalarLeafsRule, ported from graphql-js 16.14.2
`src/validation/__tests__/ScalarLeafsRule-test.ts`.

Every upstream case is ported. `object type having only one selection`
builds its document node by node, as upstream builds a `DocumentNode`
literal, because the parser cannot make an empty selection set.
"""

from _harness import expect_errors, expect_valid, format_errors, test_schema
from gql_language.ast import Document, Kind, OperationType, Role
from gql_validation.rules import ValidationRule
from gql_validation.validate import validate
from std.testing import TestSuite, assert_equal


def test_valid_scalar_selection() raises:
    expect_valid(
        ValidationRule.SCALAR_LEAFS,
        """
      fragment scalarSelection on Dog {
        barks
      }
    """,
    )


def test_object_type_missing_selection() raises:
    expect_errors(
        ValidationRule.SCALAR_LEAFS,
        """
      query directQueryOnObjectWithoutSubFields {
        human
      }
    """,
        [
            'Field "human" of type "Human" must have a selection of'
            ' subfields. Did you mean "human { ... }"? (3:9)'
        ],
    )


def test_interface_type_missing_selection() raises:
    expect_errors(
        ValidationRule.SCALAR_LEAFS,
        """
      {
        human { pets }
      }
    """,
        [
            'Field "pets" of type "[Pet]" must have a selection of'
            ' subfields. Did you mean "pets { ... }"? (3:17)'
        ],
    )


def test_valid_scalar_selection_with_args() raises:
    expect_valid(
        ValidationRule.SCALAR_LEAFS,
        """
      fragment scalarSelectionWithArgs on Dog {
        doesKnowCommand(dogCommand: SIT)
      }
    """,
    )


def test_scalar_selection_not_allowed_on_boolean() raises:
    expect_errors(
        ValidationRule.SCALAR_LEAFS,
        """
      fragment scalarSelectionsNotAllowedOnBoolean on Dog {
        barks { sinceWhen }
      }
    """,
        [
            'Field "barks" must not have a selection since type "Boolean"'
            " has no subfields. (3:15)"
        ],
    )


def test_scalar_selection_not_allowed_on_enum() raises:
    expect_errors(
        ValidationRule.SCALAR_LEAFS,
        """
      fragment scalarSelectionsNotAllowedOnEnum on Cat {
        furColor { inHexDec }
      }
    """,
        [
            'Field "furColor" must not have a selection since type'
            ' "FurColor" has no subfields. (3:18)'
        ],
    )


def test_scalar_selection_not_allowed_with_args() raises:
    expect_errors(
        ValidationRule.SCALAR_LEAFS,
        """
      fragment scalarSelectionsNotAllowedWithArgs on Dog {
        doesKnowCommand(dogCommand: SIT) { sinceWhen }
      }
    """,
        [
            'Field "doesKnowCommand" must not have a selection since type'
            ' "Boolean" has no subfields. (3:42)'
        ],
    )


def test_scalar_selection_not_allowed_with_directives() raises:
    expect_errors(
        ValidationRule.SCALAR_LEAFS,
        """
      fragment scalarSelectionsNotAllowedWithDirectives on Dog {
        name @include(if: true) { isAlsoHumanName }
      }
    """,
        [
            'Field "name" must not have a selection since type "String" has'
            " no subfields. (3:33)"
        ],
    )


def test_scalar_selection_not_allowed_with_directives_and_args() raises:
    expect_errors(
        ValidationRule.SCALAR_LEAFS,
        """
      fragment scalarSelectionsNotAllowedWithDirectivesAndArgs on Dog {
        doesKnowCommand(dogCommand: SIT) @include(if: true) { sinceWhen }
      }
    """,
        [
            'Field "doesKnowCommand" must not have a selection since type'
            ' "Boolean" has no subfields. (3:61)'
        ],
    )


def test_object_type_having_only_one_selection() raises:
    var document = Document()
    var operation = document.add_child(
        document.root,
        Kind.OPERATION_DEFINITION,
        Role.DEFINITION,
        OperationType.QUERY.value,
    )
    var selections = document.add_child(
        operation, Kind.SELECTION_SET, Role.SELECTION_SET
    )
    var field = document.add_child(selections, Kind.FIELD, Role.SELECTION)
    _ = document.add_name(field, Role.NAME, "human")
    _ = document.add_child(field, Kind.SELECTION_SET, Role.SELECTION_SET)
    var rules = List[ValidationRule]()
    rules.append(ValidationRule.SCALAR_LEAFS)
    var errors = validate(test_schema(), document, rules)
    assert_equal(
        format_errors(errors),
        (
            'Field "human" of type "Human" must have at least one field'
            " selected. ()"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
