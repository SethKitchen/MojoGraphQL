# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/renamed_root_types.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import renamed_root_types
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_query_on_renamed_root_query_type() raises:
    assert_equal(
        _plan(
            renamed_root_types.sdl(),
            """
        query {
          product(id: \"1\") {
            name
            price
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      product(id: \"1\") {
        name
        price
      }
    }
  },
},""",
    )


def test_mutation_on_renamed_root_mutation_type() raises:
    assert_equal(
        _plan(
            renamed_root_types.sdl(),
            """
        mutation {
          addProduct(input: { name: \"new\", price: 599.99 }) {
            name
            price
            isExpensive
            isAvailable
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      mutation {
        addProduct(input: {name: \"new\", price: 599.99}) {
          __typename
          name
          price
          id
        }
      }
    },
    Flatten(path: \"addProduct\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        {
          ... on Product {
            isExpensive
            isAvailable
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
