# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for PossibleFragmentSpreadsRule, ported from graphql-js 16.14.2
`src/validation/__tests__/PossibleFragmentSpreadsRule-test.ts`."""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime TEST_SDL = """
  interface Being {
    name: String
  }

  interface Pet implements Being {
    name: String
  }

  type Dog implements Being & Pet {
    name: String
    barkVolume: Int
  }

  type Cat implements Being & Pet {
    name: String
    meowVolume: Int
  }

  union CatOrDog = Cat | Dog

  interface Intelligent {
    iq: Int
  }

  type Human implements Being & Intelligent {
    name: String
    pets: [Pet]
    iq: Int
  }

  type Alien implements Being & Intelligent {
    name: String
    iq: Int
  }

  union DogOrHuman = Dog | Human

  union HumanOrAlien = Human | Alien

  type Query {
    catOrDog: CatOrDog
    dogOrHuman: DogOrHuman
    humanOrAlien: HumanOrAlien
  }
"""
"""The SDL of the upstream `testSchema` of this file."""


def _expect_errors(query: String, expected: List[String]) raises:
    """Check the errors of the rule against the schema of this file.

    Args:
        query: The document.
        expected: The formatted errors, in order.

    Raises:
        Error: When the errors differ.
    """
    var schema = schema_of(TEST_SDL)
    expect_errors_with_schema(
        schema, ValidationRule.POSSIBLE_FRAGMENT_SPREADS, query, expected
    )


def _expect_valid(query: String) raises:
    """Check that the rule finds no error against the schema of this file.

    Args:
        query: The document.

    Raises:
        Error: When there is an error.
    """
    var schema = schema_of(TEST_SDL)
    expect_valid_with_schema(
        schema, ValidationRule.POSSIBLE_FRAGMENT_SPREADS, query
    )


def test_of_the_same_object() raises:
    _expect_valid(
        """
      fragment objectWithinObject on Dog { ...dogFragment }
      fragment dogFragment on Dog { barkVolume }
    """
    )


def test_of_the_same_object_with_inline_fragment() raises:
    _expect_valid(
        """
      fragment objectWithinObjectAnon on Dog { ... on Dog { barkVolume } }
    """
    )


def test_object_into_an_implemented_interface() raises:
    _expect_valid(
        """
      fragment objectWithinInterface on Pet { ...dogFragment }
      fragment dogFragment on Dog { barkVolume }
    """
    )


def test_object_into_containing_union() raises:
    _expect_valid(
        """
      fragment objectWithinUnion on CatOrDog { ...dogFragment }
      fragment dogFragment on Dog { barkVolume }
    """
    )


def test_union_into_contained_object() raises:
    _expect_valid(
        """
      fragment unionWithinObject on Dog { ...catOrDogFragment }
      fragment catOrDogFragment on CatOrDog { __typename }
    """
    )


def test_union_into_overlapping_interface() raises:
    _expect_valid(
        """
      fragment unionWithinInterface on Pet { ...catOrDogFragment }
      fragment catOrDogFragment on CatOrDog { __typename }
    """
    )


def test_union_into_overlapping_union() raises:
    _expect_valid(
        """
      fragment unionWithinUnion on DogOrHuman { ...catOrDogFragment }
      fragment catOrDogFragment on CatOrDog { __typename }
    """
    )


def test_interface_into_implemented_object() raises:
    _expect_valid(
        """
      fragment interfaceWithinObject on Dog { ...petFragment }
      fragment petFragment on Pet { name }
    """
    )


def test_interface_into_overlapping_interface() raises:
    _expect_valid(
        """
      fragment interfaceWithinInterface on Pet { ...beingFragment }
      fragment beingFragment on Being { name }
    """
    )


def test_interface_into_overlapping_interface_in_inline_fragment() raises:
    _expect_valid(
        """
      fragment interfaceWithinInterface on Pet { ... on Being { name } }
    """
    )


def test_interface_into_overlapping_union() raises:
    _expect_valid(
        """
      fragment interfaceWithinUnion on CatOrDog { ...petFragment }
      fragment petFragment on Pet { name }
    """
    )


def test_ignores_incorrect_type_caught_by_fragments_on_composite_types_rule() raises:
    _expect_valid(
        """
      fragment petFragment on Pet { ...badInADifferentWay }
      fragment badInADifferentWay on String { name }
    """
    )


def test_ignores_unknown_fragments_caught_by_known_fragment_names_rule() raises:
    _expect_valid(
        """
      fragment petFragment on Pet { ...UnknownFragment }
    """
    )


def test_different_object_into_object() raises:
    _expect_errors(
        """
      fragment invalidObjectWithinObject on Cat { ...dogFragment }
      fragment dogFragment on Dog { barkVolume }
    """,
        [
            (
                'Fragment "dogFragment" cannot be spread here as objects of'
                ' type "Cat" can never be of type "Dog". (2:51)'
            ),
        ],
    )


def test_different_object_into_object_in_inline_fragment() raises:
    _expect_errors(
        """
      fragment invalidObjectWithinObjectAnon on Cat {
        ... on Dog { barkVolume }
      }
    """,
        [
            (
                'Fragment cannot be spread here as objects of type "Cat" can'
                ' never be of type "Dog". (3:9)'
            ),
        ],
    )


def test_object_into_not_implementing_interface() raises:
    _expect_errors(
        """
      fragment invalidObjectWithinInterface on Pet { ...humanFragment }
      fragment humanFragment on Human { pets { name } }
    """,
        [
            (
                'Fragment "humanFragment" cannot be spread here as objects of'
                ' type "Pet" can never be of type "Human". (2:54)'
            ),
        ],
    )


def test_object_into_not_containing_union() raises:
    _expect_errors(
        """
      fragment invalidObjectWithinUnion on CatOrDog { ...humanFragment }
      fragment humanFragment on Human { pets { name } }
    """,
        [
            (
                'Fragment "humanFragment" cannot be spread here as objects of'
                ' type "CatOrDog" can never be of type "Human". (2:55)'
            ),
        ],
    )


def test_union_into_not_contained_object() raises:
    _expect_errors(
        """
      fragment invalidUnionWithinObject on Human { ...catOrDogFragment }
      fragment catOrDogFragment on CatOrDog { __typename }
    """,
        [
            (
                'Fragment "catOrDogFragment" cannot be spread here as objects'
                ' of type "Human" can never be of type "CatOrDog". (2:52)'
            ),
        ],
    )


def test_union_into_non_overlapping_interface() raises:
    _expect_errors(
        """
      fragment invalidUnionWithinInterface on Pet { ...humanOrAlienFragment }
      fragment humanOrAlienFragment on HumanOrAlien { __typename }
    """,
        [
            (
                'Fragment "humanOrAlienFragment" cannot be spread here as'
                ' objects of type "Pet" can never be of type "HumanOrAlien".'
                " (2:53)"
            ),
        ],
    )


def test_union_into_non_overlapping_union() raises:
    _expect_errors(
        """
      fragment invalidUnionWithinUnion on CatOrDog { ...humanOrAlienFragment }
      fragment humanOrAlienFragment on HumanOrAlien { __typename }
    """,
        [
            (
                'Fragment "humanOrAlienFragment" cannot be spread here as'
                ' objects of type "CatOrDog" can never be of type'
                ' "HumanOrAlien". (2:54)'
            ),
        ],
    )


def test_interface_into_non_implementing_object() raises:
    _expect_errors(
        """
      fragment invalidInterfaceWithinObject on Cat { ...intelligentFragment }
      fragment intelligentFragment on Intelligent { iq }
    """,
        [
            (
                'Fragment "intelligentFragment" cannot be spread here as'
                ' objects of type "Cat" can never be of type "Intelligent".'
                " (2:54)"
            ),
        ],
    )


def test_interface_into_non_overlapping_interface() raises:
    _expect_errors(
        """
      fragment invalidInterfaceWithinInterface on Pet {
        ...intelligentFragment
      }
      fragment intelligentFragment on Intelligent { iq }
    """,
        [
            (
                'Fragment "intelligentFragment" cannot be spread here as'
                ' objects of type "Pet" can never be of type "Intelligent".'
                " (3:9)"
            ),
        ],
    )


def test_interface_into_non_overlapping_interface_in_inline_fragment() raises:
    _expect_errors(
        """
      fragment invalidInterfaceWithinInterfaceAnon on Pet {
        ...on Intelligent { iq }
      }
    """,
        [
            (
                'Fragment cannot be spread here as objects of type "Pet" can'
                ' never be of type "Intelligent". (3:9)'
            ),
        ],
    )


def test_interface_into_non_overlapping_union() raises:
    _expect_errors(
        """
      fragment invalidInterfaceWithinUnion on HumanOrAlien { ...petFragment }
      fragment petFragment on Pet { name }
    """,
        [
            (
                'Fragment "petFragment" cannot be spread here as objects of'
                ' type "HumanOrAlien" can never be of type "Pet". (2:62)'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
