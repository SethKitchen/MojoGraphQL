# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for FieldsOnCorrectTypeRule, ported from graphql-js 16.14.2
`src/validation/__tests__/FieldsOnCorrectTypeRule-test.ts`."""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    parse_query,
    schema_of,
)
from gql_schema.definition import Schema
from gql_validation.rules import ValidationRule
from gql_validation.validate import validate
from std.testing import TestSuite, assert_equal

comptime RULE = ValidationRule.FIELDS_ON_CORRECT_TYPE
"""The rule under test."""

comptime TEST_SCHEMA = """
  interface Pet {
    name: String
  }

  type Dog implements Pet {
    name: String
    nickname: String
    barkVolume: Int
  }

  type Cat implements Pet {
    name: String
    nickname: String
    meowVolume: Int
  }

  union CatOrDog = Cat | Dog

  type Human {
    name: String
    pets: [Pet]
  }

  type Query {
    human: Human
  }
"""
"""The SDL of the `testSchema` of this upstream file."""


def correct_type_schema() raises -> Schema:
    """Build the `testSchema` of this upstream file.

    Returns:
        The schema.

    Raises:
        Error: Never; the SDL is valid.
    """
    return schema_of(TEST_SCHEMA)


def expect_errors(query: String, expected: List[String]) raises:
    """Check the errors of the rule over a document.

    Args:
        query: The document.
        expected: The formatted errors, in order.

    Raises:
        Error: When the errors differ.
    """
    expect_errors_with_schema(correct_type_schema(), RULE, query, expected)


def expect_valid(query: String) raises:
    """Check that the rule finds no error in a document.

    Args:
        query: The document.

    Raises:
        Error: When there is an error.
    """
    expect_valid_with_schema(correct_type_schema(), RULE, query)


def expect_error_message(
    schema: Schema, query: String, expected: String
) raises:
    """Check that the rule finds exactly one error, with this message, as
    upstream `expectErrorMessage`.

    Args:
        schema: The schema.
        query: The document.
        expected: The message.

    Raises:
        Error: When the errors differ.
    """
    var rules = List[ValidationRule]()
    rules.append(RULE)
    var errors = validate(schema, parse_query(query), rules)
    assert_equal(len(errors), 1)
    assert_equal(errors[0].message, expected)


def test_object_field_selection() raises:
    expect_valid(
        """
      fragment objectFieldSelection on Dog {
        __typename
        name
      }
    """
    )


def test_aliased_object_field_selection() raises:
    expect_valid(
        """
      fragment aliasedObjectFieldSelection on Dog {
        tn : __typename
        otherName : name
      }
    """
    )


def test_interface_field_selection() raises:
    expect_valid(
        """
      fragment interfaceFieldSelection on Pet {
        __typename
        name
      }
    """
    )


def test_aliased_interface_field_selection() raises:
    expect_valid(
        """
      fragment interfaceFieldSelection on Pet {
        otherName : name
      }
    """
    )


def test_lying_alias_selection() raises:
    expect_valid(
        """
      fragment lyingAliasSelection on Dog {
        name : nickname
      }
    """
    )


def test_ignores_fields_on_unknown_type() raises:
    expect_valid(
        """
      fragment unknownSelection on UnknownType {
        unknownField
      }
    """
    )


def test_reports_errors_when_type_is_known_again() raises:
    expect_errors(
        """
      fragment typeKnownAgain on Pet {
        unknown_pet_field {
          ... on Cat {
            unknown_cat_field
          }
        }
      }
    """,
        [
            'Cannot query field "unknown_pet_field" on type "Pet". (3:9)',
            'Cannot query field "unknown_cat_field" on type "Cat". (5:13)',
        ],
    )


def test_field_not_defined_on_fragment() raises:
    expect_errors(
        """
      fragment fieldNotDefined on Dog {
        meowVolume
      }
    """,
        [
            'Cannot query field "meowVolume" on type "Dog". Did you mean'
            ' "barkVolume"? (3:9)'
        ],
    )


def test_ignores_deeply_unknown_field() raises:
    expect_errors(
        """
      fragment deepFieldNotDefined on Dog {
        unknown_field {
          deeper_unknown_field
        }
      }
    """,
        ['Cannot query field "unknown_field" on type "Dog". (3:9)'],
    )


def test_sub_field_not_defined() raises:
    expect_errors(
        """
      fragment subFieldNotDefined on Human {
        pets {
          unknown_field
        }
      }
    """,
        ['Cannot query field "unknown_field" on type "Pet". (4:11)'],
    )


def test_field_not_defined_on_inline_fragment() raises:
    expect_errors(
        """
      fragment fieldNotDefined on Pet {
        ... on Dog {
          meowVolume
        }
      }
    """,
        [
            'Cannot query field "meowVolume" on type "Dog". Did you mean'
            ' "barkVolume"? (4:11)'
        ],
    )


def test_aliased_field_target_not_defined() raises:
    expect_errors(
        """
      fragment aliasedFieldTargetNotDefined on Dog {
        volume : mooVolume
      }
    """,
        [
            'Cannot query field "mooVolume" on type "Dog". Did you mean'
            ' "barkVolume"? (3:9)'
        ],
    )


def test_aliased_lying_field_target_not_defined() raises:
    expect_errors(
        """
      fragment aliasedLyingFieldTargetNotDefined on Dog {
        barkVolume : kawVolume
      }
    """,
        [
            'Cannot query field "kawVolume" on type "Dog". Did you mean'
            ' "barkVolume"? (3:9)'
        ],
    )


def test_not_defined_on_interface() raises:
    expect_errors(
        """
      fragment notDefinedOnInterface on Pet {
        tailLength
      }
    """,
        ['Cannot query field "tailLength" on type "Pet". (3:9)'],
    )


def test_defined_on_implementors_but_not_on_interface() raises:
    expect_errors(
        """
      fragment definedOnImplementorsButNotInterface on Pet {
        nickname
      }
    """,
        [
            'Cannot query field "nickname" on type "Pet". Did you mean to'
            ' use an inline fragment on "Cat" or "Dog"? (3:9)'
        ],
    )


def test_meta_field_selection_on_union() raises:
    expect_valid(
        """
      fragment directFieldSelectionOnUnion on CatOrDog {
        __typename
      }
    """
    )


def test_direct_field_selection_on_union() raises:
    expect_errors(
        """
      fragment directFieldSelectionOnUnion on CatOrDog {
        directField
      }
    """,
        ['Cannot query field "directField" on type "CatOrDog". (3:9)'],
    )


def test_defined_on_implementors_queried_on_union() raises:
    expect_errors(
        """
      fragment definedOnImplementorsQueriedOnUnion on CatOrDog {
        name
      }
    """,
        [
            'Cannot query field "name" on type "CatOrDog". Did you mean to'
            ' use an inline fragment on "Pet", "Cat", or "Dog"? (3:9)'
        ],
    )


def test_valid_field_in_inline_fragment() raises:
    expect_valid(
        """
      fragment objectFieldSelection on Pet {
        ... on Dog {
          name
        }
        ... {
          name
        }
      }
    """
    )


def test_works_with_no_suggestions() raises:
    var schema = schema_of(
        """
        type T {
          fieldWithVeryLongNameThatWillNeverBeSuggested: String
        }
        type Query { t: T }
      """
    )
    expect_error_message(
        schema, "{ t { f } }", 'Cannot query field "f" on type "T".'
    )


def test_works_with_no_small_numbers_of_type_suggestions() raises:
    var schema = schema_of(
        """
        union T = A | B
        type Query { t: T }

        type A { f: String }
        type B { f: String }
      """
    )
    expect_error_message(
        schema,
        "{ t { f } }",
        (
            'Cannot query field "f" on type "T". Did you mean to use an inline'
            ' fragment on "A" or "B"?'
        ),
    )


def test_works_with_no_small_numbers_of_field_suggestions() raises:
    var schema = schema_of(
        """
        type T {
          y: String
          z: String
        }
        type Query { t: T }
      """
    )
    expect_error_message(
        schema,
        "{ t { f } }",
        'Cannot query field "f" on type "T". Did you mean "y" or "z"?',
    )


def test_only_shows_one_set_of_suggestions_at_a_time_preferring_types() raises:
    var schema = schema_of(
        """
        interface T {
          y: String
          z: String
        }
        type Query { t: T }

        type A implements T {
          f: String
          y: String
          z: String
        }
        type B implements T {
          f: String
          y: String
          z: String
        }
      """
    )
    expect_error_message(
        schema,
        "{ t { f } }",
        (
            'Cannot query field "f" on type "T". Did you mean to use an inline'
            ' fragment on "A" or "B"?'
        ),
    )


def test_sort_type_suggestions_based_on_inheritance_order() raises:
    var interface_schema = schema_of(
        """
        interface T { bar: String }
        type Query { t: T }

        interface Z implements T {
          foo: String
          bar: String
        }

        interface Y implements Z & T {
          foo: String
          bar: String
        }

        type X implements Y & Z & T {
          foo: String
          bar: String
        }
      """
    )
    expect_error_message(
        interface_schema,
        "{ t { foo } }",
        (
            'Cannot query field "foo" on type "T". Did you mean to use an'
            ' inline fragment on "Z", "Y", or "X"?'
        ),
    )

    var union_schema = schema_of(
        """
        interface Animal { name: String }
        interface Mammal implements Animal { name: String }

        interface Canine implements Animal & Mammal { name: String }
        type Dog implements Animal & Mammal & Canine { name: String }

        interface Feline implements Animal & Mammal { name: String }
        type Cat implements Animal & Mammal & Feline { name: String }

        union CatOrDog = Cat | Dog
        type Query { catOrDog: CatOrDog }
      """
    )
    expect_error_message(
        union_schema,
        "{ catOrDog { name } }",
        (
            'Cannot query field "name" on type "CatOrDog". Did you mean to use'
            ' an inline fragment on "Animal", "Mammal", "Canine", "Dog", or'
            ' "Feline"?'
        ),
    )


def test_limits_lots_of_type_suggestions() raises:
    var schema = schema_of(
        """
        union T = A | B | C | D | E | F
        type Query { t: T }

        type A { f: String }
        type B { f: String }
        type C { f: String }
        type D { f: String }
        type E { f: String }
        type F { f: String }
      """
    )
    expect_error_message(
        schema,
        "{ t { f } }",
        (
            'Cannot query field "f" on type "T". Did you mean to use an inline'
            ' fragment on "A", "B", "C", "D", or "E"?'
        ),
    )


def test_limits_lots_of_field_suggestions() raises:
    var schema = schema_of(
        """
        type T {
          u: String
          v: String
          w: String
          x: String
          y: String
          z: String
        }
        type Query { t: T }
      """
    )
    expect_error_message(
        schema,
        "{ t { f } }",
        (
            'Cannot query field "f" on type "T". Did you mean "u", "v", "w",'
            ' "x", or "y"?'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
