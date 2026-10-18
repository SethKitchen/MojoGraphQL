# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/root_types.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import shared_root
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_shared_root() raises:
    assert_equal(
        _plan(
            shared_root.sdl(),
            """
        query {
          product {
            id
            name {
              id
              brand
              model
            }
            category {
              id
              name
            }
            price {
              id
              amount
              currency
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Parallel {
    Fetch(service: \"price\") {
      {
        product {
          price {
            id
            amount
            currency
          }
        }
      }
    },
    Fetch(service: \"category\") {
      {
        product {
          category {
            id
            name
          }
          id
        }
      }
    },
    Fetch(service: \"name\") {
      {
        product {
          name {
            id
            brand
            model
          }
        }
      }
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
