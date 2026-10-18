# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/requires_fragments.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import requires_with_fragments
from _fixtures import requires_union_type_condition
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_requires_with_fragments_on_interfaces() raises:
    assert_equal(
        _plan(
            requires_with_fragments.sdl(),
            """
        query {
          userFromA {
            permissions
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        userFromA {
          __typename
          id
          profile {
            displayName
            __typename
            ... on GuestAccount {
              guestToken
              accountType
            }
            ... on AdminAccount {
              adminLevel
              accountType
            }
          }
        }
      }
    },
    Flatten(path: \"userFromA\") {
      Fetch(service: \"b\") {
        {
          ... on User {
            __typename
            profile {
              displayName
              ... on AdminAccount {
                accountType
                adminLevel
              }
              ... on GuestAccount {
                accountType
                guestToken
              }
            }
            id
          }
        } =>
        {
          ... on User {
            permissions
          }
        }
      },
    },
  },
},""",
    )


def test_requires_with_union_type_condition() raises:
    assert_equal(
        _plan(
            requires_union_type_condition.sdl(),
            """
        query {
          products {
            price
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"catalog\") {
      {
        products {
          __typename
          id
          book {
            title
          }
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"pricing\") {
        {
          ... on Product {
            __typename
            book {
              title
            }
            id
          }
        } =>
        {
          ... on Product {
            price
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
