# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/requires.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import two_same_service_calls
from _fixtures import simplest_requires
from _fixtures import requires_local_sibling
from _fixtures import simple_requires
from _fixtures import two_fields_same_subgraph_same_requirement
from _fixtures import simple_requires_with_child
from _fixtures import keys_mashup
from _fixtures import deep_requires
from _fixtures import nested_key_requires_reentry
from _fixtures import chained_requires_after_hop
from _fixtures import requires_from_two_subgraphs
from _fixtures import requires_after_two_hops
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_two_same_service_calls_with_args_conflicts() raises:
    assert_equal(
        _plan(
            two_same_service_calls.sdl(),
            """
        query {
          products {
            isExpensive # price(withDiscount: false)
            reducedPrice # price(withDiscount: true)
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"inventory\") {
      {
        products {
          __typename
          upc
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"products\") {
        {
          ... on Product {
            __typename
            upc
          }
        } =>
        {
          ... on Product {
            price(withDiscount: true)
            _internal_qp_alias_0: price(withDiscount: false)
          }
        }
      },
    },
    BatchFetch(service: \"inventory\") {
      {
        _e0 {
          paths: [
            \"products.@\"
          ]
          {
            ... on Product {
              __typename
              price: _internal_qp_alias_0
              upc
            }
          }
        }
        _e1 {
          paths: [
            \"products.@\"
          ]
          {
            ... on Product {
              __typename
              price
              upc
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Product {
            reducedPrice
          }
        }
        _e1: _entities(representations: $__batch_reps_1) {
          ... on Product {
            isExpensive
          }
        }
      }
    },
  },
},""",
    )


def test_two_same_service_calls() raises:
    assert_equal(
        _plan(
            two_same_service_calls.sdl(),
            """
        query {
          products {
            isExpensive
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"inventory\") {
      {
        products {
          __typename
          upc
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"products\") {
        {
          ... on Product {
            __typename
            upc
          }
        } =>
        {
          ... on Product {
            price(withDiscount: true)
          }
        }
      },
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"inventory\") {
        {
          ... on Product {
            __typename
            price
            upc
          }
        } =>
        {
          ... on Product {
            isExpensive
          }
        }
      },
    },
  },
},""",
    )


def test_simplest_requires() raises:
    assert_equal(
        _plan(
            simplest_requires.sdl(),
            """
        query {
          products {
            isExpensive
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          __typename
          upc
          price
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"inventory\") {
        {
          ... on Product {
            __typename
            price
            upc
          }
        } =>
        {
          ... on Product {
            isExpensive
          }
        }
      },
    },
  },
},""",
    )


def test_simplest_requires_with_local_sibling() raises:
    assert_equal(
        _plan(
            requires_local_sibling.sdl(),
            """
        query {
          products {
            isExpensive
            isAvailable
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          __typename
          upc
          price
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"inventory\") {
        {
          ... on Product {
            __typename
            price
            upc
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


def test_simple_requires() raises:
    assert_equal(
        _plan(
            simple_requires.sdl(),
            """
        query {
          products {
            shippingEstimate
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          __typename
          upc
          price
          weight
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"inventory\") {
        {
          ... on Product {
            __typename
            price
            weight
            upc
          }
        } =>
        {
          ... on Product {
            shippingEstimate
          }
        }
      },
    },
  },
},""",
    )


def test_two_fields_same_subgraph_same_requirement() raises:
    assert_equal(
        _plan(
            two_fields_same_subgraph_same_requirement.sdl(),
            """
        query {
          products {
            shippingEstimate
            shippingEstimate2
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          __typename
          upc
          price
          weight
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"inventory\") {
        {
          ... on Product {
            __typename
            price
            weight
            upc
          }
        } =>
        {
          ... on Product {
            shippingEstimate2
            shippingEstimate
          }
        }
      },
    },
  },
},""",
    )


def test_simple_requires_with_child() raises:
    assert_equal(
        _plan(
            simple_requires_with_child.sdl(),
            """
        query {
          products {
            shippingEstimate {
              price
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          __typename
          upc
          price
          weight
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"inventory\") {
        {
          ... on Product {
            __typename
            price
            weight
            upc
          }
        } =>
        {
          ... on Product {
            shippingEstimate {
              price
            }
          }
        }
      },
    },
  },
},""",
    )


def test_keys_mashup() raises:
    assert_equal(
        _plan(
            keys_mashup.sdl(),
            """
        query {
          b {
            id
            a {
              id
              name
              nameInB
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        b {
          id
          a {
            __typename
            id
            compositeId {
              two
              three
            }
          }
        }
      }
    },
    Flatten(path: \"b.a.@\") {
      Fetch(service: \"a\") {
        {
          ... on A {
            __typename
            id
          }
        } =>
        {
          ... on A {
            name
          }
        }
      },
    },
    Flatten(path: \"b.a.@\") {
      Fetch(service: \"b\") {
        {
          ... on A {
            __typename
            name
            id
            compositeId {
              two
              three
            }
          }
        } =>
        {
          ... on A {
            nameInB
          }
        }
      },
    },
  },
},""",
    )


def test_deep_requires() raises:
    assert_equal(
        _plan(
            deep_requires.sdl(),
            """
        query {
          feed {
            author {
              id
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        feed {
          __typename
          id
        }
      }
    },
    Flatten(path: \"feed.@\") {
      Fetch(service: \"b\") {
        {
          ... on Post {
            __typename
            id
          }
        } =>
        {
          ... on Post {
            comments(limit: 3) {
              __typename
              id
            }
          }
        }
      },
    },
    Flatten(path: \"feed.@.comments.@\") {
      Fetch(service: \"a\") {
        {
          ... on Comment {
            __typename
            id
          }
        } =>
        {
          ... on Comment {
            authorId
          }
        }
      },
    },
    Flatten(path: \"feed.@\") {
      Fetch(service: \"b\") {
        {
          ... on Post {
            __typename
            comments {
              authorId
            }
            id
          }
        } =>
        {
          ... on Post {
            author {
              id
            }
          }
        }
      },
    },
  },
},""",
    )


def test_requires_reentry_selects_entity_typename() raises:
    assert_equal(
        _plan(
            nested_key_requires_reentry.sdl(),
            """
        query {
          productSearchResult(partialCriteria: \"partialCriteria\") {
            bestOffer {
              price
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"subgraph-a\") {
      {
        productSearchResult(partialCriteria: \"partialCriteria\") {
          __typename
          searchCriteria {
            partialCriteria
            __typename
          }
        }
      }
    },
    Flatten(path: \"productSearchResult.searchCriteria\") {
      Fetch(service: \"subgraph-b\") {
        {
          ... on ProductSearchCriteria {
            __typename
            partialCriteria
          }
        } =>
        {
          ... on ProductSearchCriteria {
            fullCriteria
          }
        }
      },
    },
    Flatten(path: \"productSearchResult\") {
      Fetch(service: \"subgraph-a\") {
        {
          ... on ProductSearchResultResponse {
            __typename
            searchCriteria {
              fullCriteria
              partialCriteria
            }
          }
        } =>
        {
          ... on ProductSearchResultResponse {
            bestOffer {
              price
            }
          }
        }
      },
    },
  },
},""",
    )


def test_chained_requires_after_entity_hop() raises:
    assert_equal(
        _plan(
            chained_requires_after_hop.sdl(),
            """
        {
          user {
            orders {
              name
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"users\") {
      {
        user {
          __typename
          id
        }
      }
    },
    Flatten(path: \"user\") {
      Fetch(service: \"orders\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            orders {
              __typename
              id
              sku
            }
          }
        }
      },
    },
    Flatten(path: \"user.orders.@\") {
      Fetch(service: \"grading\") {
        {
          ... on Order {
            __typename
            sku
            id
          }
        } =>
        {
          ... on Order {
            grade
          }
        }
      },
    },
    Flatten(path: \"user.orders.@\") {
      Fetch(service: \"catalog\") {
        {
          ... on Order {
            __typename
            grade
            id
          }
        } =>
        {
          ... on Order {
            name
          }
        }
      },
    },
  },
},""",
    )


def test_requires_from_two_subgraphs_after_entity_hop() raises:
    assert_equal(
        _plan(
            requires_from_two_subgraphs.sdl(),
            """
        {
          user {
            orders {
              name
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"users\") {
      {
        user {
          __typename
          id
        }
      }
    },
    Flatten(path: \"user\") {
      Fetch(service: \"orders\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            orders {
              __typename
              id
              sku
            }
          }
        }
      },
    },
    Flatten(path: \"user.orders.@\") {
      Fetch(service: \"warehouse\") {
        {
          ... on Order {
            __typename
            id
          }
        } =>
        {
          ... on Order {
            weight
          }
        }
      },
    },
    Flatten(path: \"user.orders.@\") {
      Fetch(service: \"catalog\") {
        {
          ... on Order {
            __typename
            sku
            weight
            id
          }
        } =>
        {
          ... on Order {
            name
          }
        }
      },
    },
  },
},""",
    )


def test_requires_after_two_entity_hops() raises:
    assert_equal(
        _plan(
            requires_after_two_hops.sdl(),
            """
        {
          user {
            cart {
              orders {
                name
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        user {
          __typename
          id
        }
      }
    },
    Flatten(path: \"user\") {
      Fetch(service: \"b\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            cart {
              __typename
              id
            }
          }
        }
      },
    },
    Flatten(path: \"user.cart\") {
      Fetch(service: \"c\") {
        {
          ... on Cart {
            __typename
            id
          }
        } =>
        {
          ... on Cart {
            orders {
              __typename
              id
              sku
            }
          }
        }
      },
    },
    Flatten(path: \"user.cart.orders.@\") {
      Fetch(service: \"catalog\") {
        {
          ... on Order {
            __typename
            sku
            id
          }
        } =>
        {
          ... on Order {
            name
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
