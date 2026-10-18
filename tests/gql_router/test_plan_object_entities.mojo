# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/object_entities.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import testing
from _fixtures import parent_entity_call
from _fixtures import parent_entity_call_complex
from _fixtures import complex_entity_call
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_testing() raises:
    assert_equal(
        _plan(
            testing.sdl(),
            """
            query {
              products {
                price {
                  amount
                  currency
                }
                isAvailable
              }
            }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"store\") {
      {
        products {
          __typename
          id
        }
      }
    },
    Flatten(path: \"products\") {
      Fetch(service: \"info\") {
        {
          ... on Product {
            __typename
            id
          }
        } =>
        {
          ... on Product {
            isAvailable
            uuid
          }
        }
      },
    },
    Flatten(path: \"products\") {
      Fetch(service: \"cost\") {
        {
          ... on Product {
            __typename
            uuid
          }
        } =>
        {
          ... on Product {
            price {
              amount
              currency
            }
          }
        }
      },
    },
  },
},""",
    )


def test_parent_entity_call() raises:
    assert_equal(
        _plan(
            parent_entity_call.sdl(),
            """
        query {
          products {
            category {
              details {
                products
              }
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        products {
          __typename
          id
          pid
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"c\") {
        {
          ... on Product {
            __typename
            id
            pid
          }
        } =>
        {
          ... on Product {
            category {
              details {
                products
              }
            }
          }
        }
      },
    },
  },
},""",
    )


def test_parent_entity_call_complex() raises:
    assert_equal(
        _plan(
            parent_entity_call_complex.sdl(),
            """
        query {
          productFromD(id: \"1\") {
            id
            name
            category {
              id
              name
              details
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"d\") {
      {
        productFromD(id: \"1\") {
          __typename
          id
          name
        }
      }
    },
    Parallel {
      Flatten(path: \"productFromD\") {
        Fetch(service: \"a\") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              category {
                details
              }
            }
          }
        },
      },
      Flatten(path: \"productFromD\") {
        Fetch(service: \"b\") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              category {
                __typename
                id
              }
            }
          }
        },
      },
    },
    Flatten(path: \"productFromD.category\") {
      Fetch(service: \"c\") {
        {
          ... on Category {
            __typename
            id
          }
        } =>
        {
          ... on Category {
            name
          }
        }
      },
    },
  },
},""",
    )


def test_complex_entity_call() raises:
    assert_equal(
        _plan(
            complex_entity_call.sdl(),
            """
        {
          topProducts {
            products {
              id
              price {
                price
              }
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        topProducts {
          products {
            __typename
            id
            category {
              tag
              id
            }
          }
        }
      }
    },
    Flatten(path: \"topProducts.products.@\") {
      Fetch(service: \"link\") {
        {
          ... on Product {
            __typename
            id
          }
        } =>
        {
          ... on Product {
            pid
          }
        }
      },
    },
    Flatten(path: \"topProducts.products.@\") {
      Fetch(service: \"price\") {
        {
          ... on Product {
            __typename
            id
            pid
            category {
              id
              tag
            }
          }
        } =>
        {
          ... on Product {
            price {
              price
            }
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
