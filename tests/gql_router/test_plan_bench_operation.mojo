# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot test of the benchmark operation.

Ports `test_bench_operation` of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/mod.rs`. The test plans upstream
`bench/operation.graphql` against `bench/supergraph.graphql` and compares
the plan with the upstream `Display` snapshot.

`preparing_a_plan_preserves_its_wire_form` of the same file is not ported:
it compares the `serde_json` form of a plan, and this port has no JSON form
of a plan.
"""

from _fixtures import bench_supergraph
from _plan_harness import _plan
from std.testing import TestSuite, assert_equal


def test_bench_operation() raises:
    assert_equal(
        _plan(bench_supergraph.sdl(), bench_supergraph.operation()),
        """QueryPlan {
  Sequence {
    Parallel {
      Fetch(service: "products") {
        {
          topProducts {
            __typename
            upc
            name
            price
            weight
          }
        }
      },
      Fetch(service: "accounts") {
        {
          users {
            __typename
            id
            username
            name
          }
        }
      },
    },
    Parallel {
      Flatten(path: "topProducts.@") {
        Fetch(service: "inventory") {
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
              inStock
            }
          }
        },
      },
      BatchFetch(service: "reviews") {
        {
          _e0 {
            paths: [
              "topProducts.@"
            ]
            {
              ... on Product {
                __typename
                upc
              }
            }
          }
          _e1 {
            paths: [
              "users.@"
            ]
            {
              ... on User {
                __typename
                id
              }
            }
          }
        }
        {
          _e0: _entities(representations: $__batch_reps_0) {
            ... on Product {
              reviews {
                ...a
              }
            }
          }
          _e1: _entities(representations: $__batch_reps_1) {
            ... on User {
              reviews {
                id
                body
                product {
                  __typename
                  upc
                  reviews {
                    ...a
                  }
                }
              }
            }
          }
        }
        fragment a on Review {
          id
          body
          author {
            __typename
            id
            username
            reviews {
              id
              body
              product {
                __typename
                upc
              }
            }
          }
        }
      },
    },
    Parallel {
      BatchFetch(service: "products") {
        {
          _e0 {
            paths: [
              "topProducts.@.reviews.@.author.reviews.@.product"
              "users.@.reviews.@.product"
              "users.@.reviews.@.product.reviews.@.author.reviews.@.product"
            ]
            {
              ... on Product {
                __typename
                upc
              }
            }
          }
        }
        {
          _e0: _entities(representations: $__batch_reps_0) {
            ... on Product {
              price
              weight
              name
            }
          }
        }
      },
      BatchFetch(service: "accounts") {
        {
          _e0 {
            paths: [
              "topProducts.@.reviews.@.author"
              "users.@.reviews.@.product.reviews.@.author"
            ]
            {
              ... on User {
                __typename
                id
              }
            }
          }
        }
        {
          _e0: _entities(representations: $__batch_reps_0) {
            ... on User {
              name
            }
          }
        }
      },
    },
    BatchFetch(service: "inventory") {
      {
        _e0 {
          paths: [
            "topProducts.@.reviews.@.author.reviews.@.product"
            "users.@.reviews.@.product"
            "users.@.reviews.@.product.reviews.@.author.reviews.@.product"
          ]
          {
            ... on Product {
              __typename
              upc
              price
              weight
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Product {
            inStock
            shippingEstimate
          }
        }
      }
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
