# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for OverlappingFieldsCanBeMergedRule, ported from graphql-js 16.14.2
`src/validation/__tests__/OverlappingFieldsCanBeMergedRule-test.ts`.

This file holds the `return types must be unambiguous` describe block, in
upstream order. The other upstream cases are ported in
`test_overlapping_fields_can_be_merged.mojo`.
"""

from _harness import (
    expect_errors_with_schema,
    expect_valid_with_schema,
    schema_of,
)
from gql_schema.definition import Schema
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED
"""The rule under test."""

comptime BOX_SCHEMA = """
      interface SomeBox {
        deepBox: SomeBox
        unrelatedField: String
      }

      type StringBox implements SomeBox {
        scalar: String
        deepBox: StringBox
        unrelatedField: String
        listStringBox: [StringBox]
        stringBox: StringBox
        intBox: IntBox
      }

      type IntBox implements SomeBox {
        scalar: Int
        deepBox: IntBox
        unrelatedField: String
        listStringBox: [StringBox]
        stringBox: StringBox
        intBox: IntBox
      }

      interface NonNullStringBox1 {
        scalar: String!
      }

      type NonNullStringBox1Impl implements SomeBox & NonNullStringBox1 {
        scalar: String!
        unrelatedField: String
        deepBox: SomeBox
      }

      interface NonNullStringBox2 {
        scalar: String!
      }

      type NonNullStringBox2Impl implements SomeBox & NonNullStringBox2 {
        scalar: String!
        unrelatedField: String
        deepBox: SomeBox
      }

      type Connection {
        edges: [Edge]
      }

      type Edge {
        node: Node
      }

      type Node {
        id: ID
        name: String
      }

      type Query {
        someBox: SomeBox
        connection: Connection
      }
    """
"""The SDL of the upstream describe block schema."""


def _schema() raises -> Schema:
    """Build the describe block schema."""
    return schema_of(BOX_SCHEMA)


def test_conflicting_return_types_which_potentially_overlap() raises:
    # This is invalid since an object could potentially be both the Object
    # type IntBox and the interface type NonNullStringBox1. While that
    # condition does not exist in the current schema, the schema could
    # expand in the future to allow this. Thus it is invalid.
    expect_errors_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ...on IntBox {
                scalar
              }
              ...on NonNullStringBox1 {
                scalar
              }
            }
          }
        """,
        [
            'Fields "scalar" conflict because they return conflicting types'
            ' "Int" and "String!". Use different aliases on the fields to fetch'
            " both if this was intentional. (5:17, 8:17)"
        ],
    )


def test_compatible_return_shapes_on_different_return_types() raises:
    # In this case `deepBox` returns `SomeBox` in the first usage, and
    # `StringBox` in the second usage. These return types are not the same!
    # however this is valid because the return *shapes* are compatible.
    expect_valid_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ... on SomeBox {
                deepBox {
                  unrelatedField
                }
              }
              ... on StringBox {
                deepBox {
                  unrelatedField
                }
              }
            }
          }
        """,
    )


def test_disallows_differing_return_types_despite_no_overlap() raises:
    expect_errors_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ... on IntBox {
                scalar
              }
              ... on StringBox {
                scalar
              }
            }
          }
        """,
        [
            'Fields "scalar" conflict because they return conflicting types'
            ' "Int" and "String". Use different aliases on the fields to fetch'
            " both if this was intentional. (5:17, 8:17)"
        ],
    )


def test_reports_correctly_when_a_non_exclusive_follows_an_exclusive() raises:
    expect_errors_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ... on IntBox {
                deepBox {
                  ...X
                }
              }
            }
            someBox {
              ... on StringBox {
                deepBox {
                  ...Y
                }
              }
            }
            memoed: someBox {
              ... on IntBox {
                deepBox {
                  ...X
                }
              }
            }
            memoed: someBox {
              ... on StringBox {
                deepBox {
                  ...Y
                }
              }
            }
            other: someBox {
              ...X
            }
            other: someBox {
              ...Y
            }
          }
          fragment X on SomeBox {
            scalar
          }
          fragment Y on SomeBox {
            scalar: unrelatedField
          }
        """,
        [
            'Fields "other" conflict because subfields "scalar" conflict'
            ' because "scalar" and "unrelatedField" are different fields. Use'
            " different aliases on the fields to fetch both if this was"
            " intentional. (31:13, 39:13, 34:13, 42:13)"
        ],
    )


def test_disallows_differing_return_type_nullability_despite_no_overlap() raises:
    expect_errors_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ... on NonNullStringBox1 {
                scalar
              }
              ... on StringBox {
                scalar
              }
            }
          }
        """,
        [
            'Fields "scalar" conflict because they return conflicting types'
            ' "String!" and "String". Use different aliases on the fields to'
            " fetch both if this was intentional. (5:17, 8:17)"
        ],
    )


def test_disallows_differing_return_type_list_despite_no_overlap() raises:
    var schema = _schema()
    expect_errors_with_schema(
        schema,
        RULE,
        """
          {
            someBox {
              ... on IntBox {
                box: listStringBox {
                  scalar
                }
              }
              ... on StringBox {
                box: stringBox {
                  scalar
                }
              }
            }
          }
        """,
        [
            'Fields "box" conflict because they return conflicting types'
            ' "[StringBox]" and "StringBox". Use different aliases on the'
            " fields to fetch both if this was intentional. (5:17, 10:17)"
        ],
    )

    expect_errors_with_schema(
        schema,
        RULE,
        """
          {
            someBox {
              ... on IntBox {
                box: stringBox {
                  scalar
                }
              }
              ... on StringBox {
                box: listStringBox {
                  scalar
                }
              }
            }
          }
        """,
        [
            'Fields "box" conflict because they return conflicting types'
            ' "StringBox" and "[StringBox]". Use different aliases on the'
            " fields to fetch both if this was intentional. (5:17, 10:17)"
        ],
    )


def test_disallows_differing_subfields() raises:
    expect_errors_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ... on IntBox {
                box: stringBox {
                  val: scalar
                  val: unrelatedField
                }
              }
              ... on StringBox {
                box: stringBox {
                  val: scalar
                }
              }
            }
          }
        """,
        [
            'Fields "val" conflict because "scalar" and "unrelatedField" are'
            " different fields. Use different aliases on the fields to fetch"
            " both if this was intentional. (6:19, 7:19)"
        ],
    )


def test_disallows_differing_deep_return_types_despite_no_overlap() raises:
    expect_errors_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ... on IntBox {
                box: stringBox {
                  scalar
                }
              }
              ... on StringBox {
                box: intBox {
                  scalar
                }
              }
            }
          }
        """,
        [
            'Fields "box" conflict because subfields "scalar" conflict because'
            ' they return conflicting types "String" and "Int". Use different'
            " aliases on the fields to fetch both if this was intentional."
            " (5:17, 6:19, 10:17, 11:19)"
        ],
    )


def test_allows_non_conflicting_overlapping_types() raises:
    expect_valid_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ... on IntBox {
                scalar: unrelatedField
              }
              ... on StringBox {
                scalar
              }
            }
          }
        """,
    )


def test_same_wrapped_scalar_return_types() raises:
    expect_valid_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ...on NonNullStringBox1 {
                scalar
              }
              ...on NonNullStringBox2 {
                scalar
              }
            }
          }
        """,
    )


def test_allows_inline_fragments_without_type_condition() raises:
    expect_valid_with_schema(
        _schema(),
        RULE,
        """
          {
            a
            ... {
              a
            }
          }
        """,
    )


def test_compares_deep_types_including_list() raises:
    expect_errors_with_schema(
        _schema(),
        RULE,
        """
          {
            connection {
              ...edgeID
              edges {
                node {
                  id: name
                }
              }
            }
          }

          fragment edgeID on Connection {
            edges {
              node {
                id
              }
            }
          }
        """,
        [
            'Fields "edges" conflict because subfields "node" conflict because'
            ' subfields "id" conflict because "name" and "id" are different'
            " fields. Use different aliases on the fields to fetch both if this"
            " was intentional. (5:15, 6:17, 7:19, 14:13, 15:15, 16:17)"
        ],
    )


def test_ignores_unknown_types() raises:
    expect_valid_with_schema(
        _schema(),
        RULE,
        """
          {
            someBox {
              ...on UnknownType {
                scalar
              }
              ...on NonNullStringBox2 {
                scalar
              }
            }
          }
        """,
    )


def test_works_for_field_names_that_are_js_keywords() raises:
    var schema_with_keywords = schema_of(
        """
        type Foo {
          constructor: String
        }

        type Query {
          foo: Foo
        }
      """
    )

    expect_valid_with_schema(
        schema_with_keywords,
        RULE,
        """
          {
            foo {
              constructor
            }
          }
        """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
