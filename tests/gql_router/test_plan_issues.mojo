# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/issues.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.

The tests whose upstream assertions are not snapshots are in
`test_plan_issues_assertions.mojo`.
"""

from _fixtures import simple_include_skip
from _fixtures import issue_281
from _fixtures import issue_190
from _fixtures import issue_939
from _fixtures import corrupted_supergraph_node_id
from _fixtures import issue_infinite_typename_interfaceobject
from _fixtures import issue_requires_self_dependency_false_positive
from _fixtures import issue_1539
from _fixtures import issue_1539_self_referential
from _fixtures import issue_1308
from _fixtures import issue_1309
from _fixtures import issue_1647
from _plan_harness import _plan
from gql_router.fetch_step import QueryPlannerOptions
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_issue_1189_variable_skip_is_preserved_in_subgraph_operation() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($v: Boolean!) {
          product @skip(if: $v) {
            price
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($v:Boolean!) {
      product @skip(if: $v) {
        price
      }
    }
  },
},""",
    )


def test_issue_281_test() raises:
    assert_equal(
        _plan(
            issue_281.sdl(),
            """
        {
          viewer {
            review {
              ... on AnonymousReview {
                __typename
                product {
                  b
                }
              }
              ... on UserReview {
                __typename
                product {
                  c
                  d
                }
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
        viewer {
          review {
            __typename
            ... on AnonymousReview {
              __typename
              product {
                ...a
              }
            }
            ... on UserReview {
              __typename
              product {
                ...a
              }
            }
          }
        }
      }
      fragment a on Product {
        __typename
        id
      }
    },
    BatchFetch(service: \"b\") {
      {
        _e0 {
          paths: [
            \"viewer.review|[UserReview].product\"
          ]
          {
            ... on Product {
              __typename
              id
            }
          }
        }
        _e1 {
          paths: [
            \"viewer.review|[AnonymousReview].product\"
          ]
          {
            ... on Product {
              __typename
              id
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Product {
            pid
          }
        }
        _e1: _entities(representations: $__batch_reps_1) {
          ... on Product {
            b
          }
        }
      }
    },
    Parallel {
      Flatten(path: \"viewer.review|[UserReview].product\") {
        Fetch(service: \"c\") {
          {
            ... on Product {
              __typename
              pid
            }
          } =>
          {
            ... on Product {
              c
            }
          }
        },
      },
      Flatten(path: \"viewer.review|[UserReview].product\") {
        Fetch(service: \"d\") {
          {
            ... on Product {
              __typename
              pid
            }
          } =>
          {
            ... on Product {
              d
            }
          }
        },
      },
    },
  },
},""",
    )


def test_issue_190_test() raises:
    assert_equal(
        _plan(
            issue_190.sdl(),
            """
        query(
          $included: Boolean!
        ) {
          recommender @include(if: $included) {
            id
            results {
              ...Recommendable_Product
              __typename
            }
            __typename
          }
        }

        fragment Recommendable_Product on Product {
          id
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"recommender\") {
    query ($included:Boolean!) {
      recommender @include(if: $included) {
        id
        results {
          __typename
          ... on Product {
            id
          }
        }
        __typename
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            issue_190.sdl(),
            """
        query(
          $included: Boolean!
        ) {
          recommender @include(if: $included) {
            id
            results {
              ...Recommendable_Product
            }
          }
        }

        fragment Recommendable_Product on Product {
          id
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"recommender\") {
    query ($included:Boolean!) {
      recommender @include(if: $included) {
        id
        results {
          __typename
          ... on Product {
            id
          }
        }
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            issue_190.sdl(),
            """
        query(
          $included: Boolean!
        ) {
          recommender @include(if: $included) {
            id
            results {
              ... on Product {
                id
              }
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"recommender\") {
    query ($included:Boolean!) {
      recommender @include(if: $included) {
        id
        results {
          __typename
          ... on Product {
            id
          }
        }
      }
    }
  },
},""",
    )


def test_issue_939_test() raises:
    assert_equal(
        _plan(
            issue_939.sdl(),
            """
        query SingleNode($id: ID!) {
          node(id: $id) {
            ... on MyNode {
              content {
                ... on ITextContent {
                  fragments {
                    contentNode {
                      content {
                        ... on ITextContent {
                          id
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"content\") {
    query ($id:ID!) {
      node(id: $id) {
        __typename
        ... on MyNode {
          content {
            __typename
            ... on TextContent {
              fragments {
                ...a
              }
            }
            ... on TextGroupContent {
              fragments {
                ...a
              }
            }
          }
        }
      }
    }
    fragment a on TextContentFragment {
      contentNode {
        content {
          __typename
          ... on TextContent {
            id
          }
          ... on TextGroupContent {
            id
          }
        }
      }
    }
  },
},""",
    )


comptime _FOLDING_QUERY = """
        query SingleNode($id: ID!) {
          node(id: $id) {
            ... on MyNode {
              content {
                ... on TextContent {
                  id
                }
                ... on TextGroupContent {
                  id
                }
              }
            }
          }
        }
        """
"""The operation of the abstract type folding test."""


def test_experimental_abstract_type_folding_folds_object_fragments_into_interface() raises:
    assert_equal(
        _plan(issue_939.sdl(), _FOLDING_QUERY),
        """QueryPlan {
  Fetch(service: \"content\") {
    query ($id:ID!) {
      node(id: $id) {
        __typename
        ... on MyNode {
          content {
            __typename
            ... on TextContent {
              id
            }
            ... on TextGroupContent {
              id
            }
          }
        }
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            issue_939.sdl(),
            _FOLDING_QUERY,
            PlannerOverrideContext.default(),
            QueryPlannerOptions(experimental_abstract_type_folding=True),
        ),
        """QueryPlan {
  Fetch(service: \"content\") {
    query ($id:ID!) {
      node(id: $id) {
        __typename
        ... on MyNode {
          content {
            __typename
            ... on ITextContent {
              id
            }
          }
        }
      }
    }
  },
},""",
    )


def test_issue_965_test() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account(id: \"a1\") {
            ...Test
          }
        }

        fragment Test on Account {
          ... on Node {
            id
          }
          username
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      account(id: \"a1\") {
        id
        username
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account(id: \"a1\") {
            ...Test
          }
        }

        fragment Test on Node {
          ... on Node {
            id
          }
          ... on Account {
            username
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      account(id: \"a1\") {
        id
        username
      }
    }
  },
},""",
    )


def test_issue_965_mixed_nested_fragments_with_directives_test() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query($outer: Boolean!, $inner: Boolean!, $skip: Boolean!) {
          account(id: \"a1\") {
            ...Test
          }
        }

        fragment Test on Account {
          ... on Account @include(if: $outer) {
            ...Inner @include(if: $inner)
          }
          ... on Account @skip(if: $skip) {
            username
          }
        }

        fragment Inner on Account {
          id
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($inner:Boolean!,$outer:Boolean!,$skip:Boolean!) {
      account(id: \"a1\") {
        ... on Account @include(if: $outer) {
          ... on Account @include(if: $inner) {
            id
          }
        }
        ... on Account @skip(if: $skip) {
          username
        }
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query($outer: Boolean!, $inner: Boolean!, $skip: Boolean!) {
          account(id: \"a1\") {
            ...Test
          }
        }

        fragment Test on Node {
          ... on Node @include(if: $outer) {
            ...Inner @include(if: $inner)
          }
          ... on Account @skip(if: $skip) {
            username
          }
        }

        fragment Inner on Node {
          ... {
            id
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($inner:Boolean!,$outer:Boolean!,$skip:Boolean!) {
      account(id: \"a1\") {
        ... on Account @include(if: $outer) {
          ... on Account @include(if: $inner) {
            id
          }
        }
        ... on Account @skip(if: $skip) {
          username
        }
      }
    }
  },
},""",
    )


def test_issue_interface_object_typename() raises:
    assert_equal(
        _plan(
            issue_infinite_typename_interfaceobject.sdl(),
            """
        {
          me {
            __typename
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"s3\") {
    {
      me {
        __typename
      }
    }
  },
},""",
    )


def test_requires_self_dependency_false_positive() raises:
    assert_equal(
        _plan(
            issue_requires_self_dependency_false_positive.sdl(),
            """
        {
          books {
            edition {
              book {
                catalogId
              }
            }
            isRecommended
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"library\") {
      {
        books {
          __typename
          edition {
            book {
              catalogId
            }
            isbn
          }
        }
      }
    },
    Flatten(path: \"books.@\") {
      Fetch(service: \"recommender\") {
        {
          ... on BookListing {
            __typename
            edition {
              book {
                catalogId
              }
              isbn
            }
          }
        } =>
        {
          ... on BookListing {
            isRecommended
          }
        }
      },
    },
  },
},""",
    )


def test_issue_1539_requires_after_entity_hop() raises:
    assert_equal(
        _plan(
            issue_1539.sdl(),
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


def test_issue_1539_requires_after_entity_hop_with_explicit_requirement() raises:
    assert_equal(
        _plan(
            issue_1539.sdl(),
            """
        {
          user {
            orders {
              sku
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
              sku
              id
            }
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


def test_issue_1539_requires_on_root_parent() raises:
    assert_equal(
        _plan(
            issue_1539.sdl(),
            """
        {
          order {
            name
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"orders\") {
      {
        order {
          __typename
          id
          sku
        }
      }
    },
    Flatten(path: \"order\") {
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


def test_issue_1539_requires_on_self_referential_entity() raises:
    assert_equal(
        _plan(
            issue_1539_self_referential.sdl(),
            """
        {
          order {
            related {
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
        order {
          __typename
          id
        }
      }
    },
    Flatten(path: \"order\") {
      Fetch(service: \"orders\") {
        {
          ... on Order {
            __typename
            id
          }
        } =>
        {
          ... on Order {
            related {
              __typename
              id
              sku
            }
          }
        }
      },
    },
    Flatten(path: \"order.related\") {
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


def test_issue_1308_conditional_rank_keeps_concrete_requires_types() raises:
    assert_equal(
        _plan(
            issue_1308.sdl(),
            """
        query ($includeRank: Boolean!) {
          cage {
            listings {
              rank @include(if: $includeRank)
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"catalog\") {
      {
        cage {
          __typename
          id
        }
      }
    },
    Flatten(path: \"cage\") {
      Fetch(service: \"search\") {
        {
          ... on Cage {
            __typename
            id
          }
        } =>
        ($includeRank:Boolean!) {
          ... on Cage {
            listings {
              __typename
              id
              ... on Listing @include(if: $includeRank) {
                pet {
                  __typename
                  id
                }
              }
            }
          }
        }
      },
    },
    Include(if: $includeRank) {
      Sequence {
        Flatten(path: \"cage.listings.@.pet\") {
          Fetch(service: \"catalog\") {
            {
              ... on Animal {
                __typename
                id
              }
            } =>
            {
              ... on Animal {
                __typename
                ... on Cat {
                  whiskers
                }
                ... on Dog {
                  tricks
                }
              }
            }
          },
        },
        Flatten(path: \"cage.listings.@\") {
          Fetch(service: \"ranking\") {
            {
              ... on Listing {
                __typename
                pet {
                  __typename
                  ... on Dog {
                    tricks
                  }
                  ... on Cat {
                    whiskers
                  }
                }
                id
              }
            } =>
            {
              ... on Listing {
                rank
              }
            }
          },
        },
      },
    },
  },
},""",
    )


def test_issue_1309_requires_through_entity_interface() raises:
    assert_equal(
        _plan(
            issue_1309.sdl(),
            """
        query {
          listings {
            rank
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"search\") {
      {
        listings {
          __typename
          id
          pet {
            __typename
            id
          }
        }
      }
    },
    Flatten(path: \"listings.@.pet\") {
      Fetch(service: \"catalog\") {
        {
          ... on Animal {
            __typename
            id
          }
        } =>
        {
          ... on Animal {
            __typename
            ... on Cat {
              whiskers
            }
            ... on Dog {
              tricks
            }
          }
        }
      },
    },
    Flatten(path: \"listings.@\") {
      Fetch(service: \"ranking\") {
        {
          ... on Listing {
            __typename
            pet {
              __typename
              ... on Dog {
                tricks
              }
              ... on Cat {
                whiskers
              }
            }
            id
          }
        } =>
        {
          ... on Listing {
            rank
          }
        }
      },
    },
  },
},""",
    )


def test_issue_1647_include_on_field_after_conditional_entity_call() raises:
    assert_equal(
        _plan(
            issue_1647.sdl(),
            """
        query ($withDetails: Boolean!, $id: ID! = \"\", $term: String! = \"\") {
          record(id: $id) @include(if: $withDetails) {
            ... on User {
              id
              email
              invoices
            }
          }
          listed: catalog {
            search(term: $term, kind: \"item\", source: \"store\") @include(if: $withDetails) {
              ... on Item {
                id
                label
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"accounts\") {
      query ($id:ID!=\"\",$term:String!=\"\",$withDetails:Boolean!) {
        record(id: $id) @include(if: $withDetails) {
          __typename
          ... on User {
            __typename
            id
            email
          }
        }
        listed: catalog {
          search(kind: \"item\", source: \"store\", term: $term) @include(if: $withDetails) {
            __typename
            ... on Item {
              id
              label
            }
          }
        }
      }
    },
    Include(if: $withDetails) {
      Flatten(path: \"record|[User]\") {
        Fetch(service: \"billing\") {
          {
            ... on User {
              __typename
              id
            }
          } =>
          {
            ... on User {
              invoices
            }
          }
        },
      },
    },
  },
},""",
    )


def test_issue_1647_include_on_fragment_after_conditional_entity_call() raises:
    assert_equal(
        _plan(
            issue_1647.sdl(),
            """
        query ($withDetails: Boolean!, $id: ID! = \"\", $term: String! = \"\") {
          record(id: $id) @include(if: $withDetails) {
            ... on User {
              id
              email
              invoices
            }
          }
          ... on Query @include(if: $withDetails) {
            listed: catalog {
              search(term: $term, kind: \"item\", source: \"store\") {
                ... on Item {
                  id
                  label
                }
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"accounts\") {
      query ($id:ID!=\"\",$term:String!=\"\",$withDetails:Boolean!) {
        record(id: $id) @include(if: $withDetails) {
          __typename
          ... on User {
            __typename
            id
            email
          }
        }
        ... on Query @include(if: $withDetails) {
          listed: catalog {
            search(kind: \"item\", source: \"store\", term: $term) {
              __typename
              ... on Item {
                id
                label
              }
            }
          }
        }
      }
    },
    Include(if: $withDetails) {
      Flatten(path: \"record|[User]\") {
        Fetch(service: \"billing\") {
          {
            ... on User {
              __typename
              id
            }
          } =>
          {
            ... on User {
              invoices
            }
          }
        },
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
