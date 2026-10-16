# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for KnownTypeNamesRule, ported from graphql-js 16.14.2
`src/validation/__tests__/KnownTypeNamesRule-test.ts`.

Not ported here: the `within SDL` cases (`expectSDLValidationErrors`). They
are ported in `tests/gql_schema/test_sdl_known_type_names.mojo`.
"""

from _harness import (
    expect_errors,
    expect_errors_with_schema,
    expect_valid,
    schema_of,
)
from gql_validation.rules import ValidationRule
from std.testing import TestSuite


def test_known_type_names_are_valid() raises:
    expect_valid(
        ValidationRule.KNOWN_TYPE_NAMES,
        """
      query Foo(
        $var: String
        $required: [Int!]!
        $introspectionType: __EnumValue
      ) {
        user(id: 4) {
          pets { ... on Pet { name }, ...PetFields, ... { name } }
        }
      }

      fragment PetFields on Pet {
        name
      }
    """,
    )


def test_unknown_type_names_are_invalid() raises:
    expect_errors(
        ValidationRule.KNOWN_TYPE_NAMES,
        """
      query Foo($var: [JumbledUpLetters!]!) {
        user(id: 4) {
          name
          pets { ... on Badger { name }, ...PetFields }
        }
      }
      fragment PetFields on Peat {
        name
      }
    """,
        [
            'Unknown type "JumbledUpLetters". (2:24)',
            'Unknown type "Badger". (5:25)',
            'Unknown type "Peat". Did you mean "Pet" or "Cat"? (8:29)',
        ],
    )


def test_references_to_standard_scalars_that_are_missing_in_schema() raises:
    var schema = schema_of("type Query { foo: String }")
    var query = """
      query ($id: ID, $float: Float, $int: Int) {
        __typename
      }
    """
    expect_errors_with_schema(
        schema,
        ValidationRule.KNOWN_TYPE_NAMES,
        query,
        [
            'Unknown type "ID". (2:19)',
            'Unknown type "Float". (2:31)',
            'Unknown type "Int". (2:44)',
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
