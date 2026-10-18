# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/arguments.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import requires_with_argument_conflict
from _fixtures import audit_requires_arguments
from _fixtures import simple_requires_args
from _fixtures import arguments_requires
from _fixtures import spotify_supergraph
from _fixtures import parent_entity_call_complex
from _fixtures import requires_argument_conflict_after_hop
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_fed_audit_requires_with_argument_conflict() raises:
    assert_equal(
        _plan(
            requires_with_argument_conflict.sdl(),
            """
        query {
          products {
            upc
            name
            shippingEstimate
            shippingEstimateEUR
            isExpensiveCategory
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        products {
          __typename
          upc
          name
          price(currency: \"USD\")
          weight
          _internal_qp_alias_0: price(currency: \"EUR\")
          category {
            averagePrice(currency: \"USD\")
          }
        }
      }
    },
    BatchFetch(service: \"a\") {
      {
        _e0 {
          paths: [
            \"products.@\"
          ]
          {
            ... on Product {
              __typename
              category {
                averagePrice
              }
              upc
              price: _internal_qp_alias_0
              weight
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
              weight
              upc
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Product {
            isExpensiveCategory
            shippingEstimateEUR
          }
        }
        _e1: _entities(representations: $__batch_reps_1) {
          ... on Product {
            shippingEstimate
          }
        }
      }
    },
  },
},""",
    )


def test_requires_arguments_deeply_nested_requires() raises:
    assert_equal(
        _plan(
            audit_requires_arguments.sdl(),
            """
        query {
          feed {
            author {
              id
            }
            comments(limit: 1) {
              id
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"c\") {
      {
        feed {
          __typename
          id
        }
      }
    },
    Flatten(path: \"feed.@\") {
      Fetch(service: \"d\") {
        {
          ... on Post {
            __typename
            id
          }
        } =>
        {
          ... on Post {
            _internal_qp_alias_0: comments(limit: 3) {
              __typename
              id
            }
            comments(limit: 1) {
              id
            }
          }
        }
      },
    },
    Flatten(path: \"feed.@._internal_qp_alias_0.@\") {
      Fetch(service: \"c\") {
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
      Fetch(service: \"d\") {
        {
          ... on Post {
            __typename
            comments: _internal_qp_alias_0 {
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


def test_requires_arguments_deeply_nested_requires_with_variable() raises:
    assert_equal(
        _plan(
            audit_requires_arguments.sdl(),
            """
        query ($limit: Int = 1) {
          feed {
            author {
              id
            }
            comments(limit: $limit) {
              id
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"c\") {
      {
        feed {
          __typename
          id
        }
      }
    },
    Flatten(path: \"feed.@\") {
      Fetch(service: \"d\") {
        {
          ... on Post {
            __typename
            id
          }
        } =>
        ($limit:Int=1) {
          ... on Post {
            _internal_qp_alias_0: comments(limit: 3) {
              __typename
              id
            }
            comments(limit: $limit) {
              id
            }
          }
        }
      },
    },
    Flatten(path: \"feed.@._internal_qp_alias_0.@\") {
      Fetch(service: \"c\") {
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
      Fetch(service: \"d\") {
        {
          ... on Post {
            __typename
            comments: _internal_qp_alias_0 {
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


def test_requires_arguments_deeply_nested_requires_with_variables_and_fragments() raises:
    assert_equal(
        _plan(
            audit_requires_arguments.sdl(),
            """
        query ($limit: Int = 1) {
          feed {
            author {
              id
            }
            ...Foo
            ...Bar
          }
        }

        fragment Foo on Post {
          comments(limit: $limit) {
            id
          }
        }

        fragment Bar on Post {
          comments(limit: $limit) {
            id
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"c\") {
      {
        feed {
          __typename
          id
        }
      }
    },
    Flatten(path: \"feed.@\") {
      Fetch(service: \"d\") {
        {
          ... on Post {
            __typename
            id
          }
        } =>
        ($limit:Int=1) {
          ... on Post {
            _internal_qp_alias_0: comments(limit: 3) {
              __typename
              id
            }
            comments(limit: $limit) {
              id
            }
          }
        }
      },
    },
    Flatten(path: \"feed.@._internal_qp_alias_0.@\") {
      Fetch(service: \"c\") {
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
      Fetch(service: \"d\") {
        {
          ... on Post {
            __typename
            comments: _internal_qp_alias_0 {
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


def test_multiple_requires_with_args_that_conflicts() raises:
    assert_equal(
        _plan(
            simple_requires_args.sdl(),
            """
        {
          test {
            id
            fieldWithRequiresAndArgs # requires(fields: \"otherField(arg: 2)\")
            anotherWithRequiresAndArgs # requires(fields: \"otherField(arg: 3)\")
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        test {
          __typename
          id
        }
      }
    },
    Flatten(path: \"test\") {
      Fetch(service: \"b\") {
        {
          ... on Test {
            __typename
            id
          }
        } =>
        {
          ... on Test {
            otherField(arg: 2)
            _internal_qp_alias_0: otherField(arg: 3)
          }
        }
      },
    },
    BatchFetch(service: \"a\") {
      {
        _e0 {
          paths: [
            \"test\"
          ]
          {
            ... on Test {
              __typename
              otherField: _internal_qp_alias_0
              id
            }
          }
        }
        _e1 {
          paths: [
            \"test\"
          ]
          {
            ... on Test {
              __typename
              otherField
              id
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Test {
            anotherWithRequiresAndArgs
          }
        }
        _e1: _entities(representations: $__batch_reps_1) {
          ... on Test {
            fieldWithRequiresAndArgs
          }
        }
      }
    },
  },
},""",
    )


def test_multiple_plain_field_and_requires_with_args_that_conflicts() raises:
    assert_equal(
        _plan(
            simple_requires_args.sdl(),
            """
        {
          test {
            id
            fieldWithRequiresAndArgs # requires(fields: \"otherField(arg: 2)\")
            anotherWithRequiresAndArgs # requires(fields: \"otherField(arg: 3)\")
            otherField(arg: 1)
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        test {
          __typename
          id
        }
      }
    },
    Flatten(path: \"test\") {
      Fetch(service: \"b\") {
        {
          ... on Test {
            __typename
            id
          }
        } =>
        {
          ... on Test {
            _internal_qp_alias_0: otherField(arg: 2)
            _internal_qp_alias_1: otherField(arg: 3)
            otherField(arg: 1)
          }
        }
      },
    },
    BatchFetch(service: \"a\") {
      {
        _e0 {
          paths: [
            \"test\"
          ]
          {
            ... on Test {
              __typename
              otherField: _internal_qp_alias_1
              id
            }
          }
        }
        _e1 {
          paths: [
            \"test\"
          ]
          {
            ... on Test {
              __typename
              otherField: _internal_qp_alias_0
              id
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Test {
            anotherWithRequiresAndArgs
          }
        }
        _e1: _entities(representations: $__batch_reps_1) {
          ... on Test {
            fieldWithRequiresAndArgs
          }
        }
      }
    },
  },
},""",
    )


def test_multiple_plain_field_and_requires_with_args_that_does_not_conflicts_should_merge() raises:
    assert_equal(
        _plan(
            simple_requires_args.sdl(),
            """
        {
          test {
            id
            fieldWithRequiresAndArgs # requires(fields: \"otherField(arg: 2)\")
            otherField(arg: 2)
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        test {
          __typename
          id
        }
      }
    },
    Flatten(path: \"test\") {
      Fetch(service: \"b\") {
        {
          ... on Test {
            __typename
            id
          }
        } =>
        {
          ... on Test {
            otherField(arg: 2)
          }
        }
      },
    },
    Flatten(path: \"test\") {
      Fetch(service: \"a\") {
        {
          ... on Test {
            __typename
            otherField
            id
          }
        } =>
        {
          ... on Test {
            fieldWithRequiresAndArgs
          }
        }
      },
    },
  },
},""",
    )


def test_simple_requires_arguments() raises:
    assert_equal(
        _plan(
            simple_requires_args.sdl(),
            """
        {
          test {
            id
            fieldWithRequiresAndArgs
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        test {
          __typename
          id
        }
      }
    },
    Flatten(path: \"test\") {
      Fetch(service: \"b\") {
        {
          ... on Test {
            __typename
            id
          }
        } =>
        {
          ... on Test {
            otherField(arg: 2)
          }
        }
      },
    },
    Flatten(path: \"test\") {
      Fetch(service: \"a\") {
        {
          ... on Test {
            __typename
            otherField
            id
          }
        } =>
        {
          ... on Test {
            fieldWithRequiresAndArgs
          }
        }
      },
    },
  },
},""",
    )


def test_requires_with_arguments() raises:
    assert_equal(
        _plan(
            arguments_requires.sdl(),
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
            somethingElse
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
              somethingElse
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


def test_arguments_in_different_levels() raises:
    assert_equal(
        _plan(
            spotify_supergraph.sdl(),
            """
        query {
          album(id: \"5\") {
            albumType
            name
            genres
            tracks(limit: 5, offset: 10) {
              edges {
                node {
                  name
                }
              }
            }
          }

        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"spotify\") {
    {
      album(id: \"5\") {
        albumType
        name
        genres
        tracks(limit: 5, offset: 10) {
          edges {
            node {
              name
            }
          }
        }
      }
    }
  },
},""",
    )


def test_arguments_and_variables() raises:
    assert_equal(
        _plan(
            spotify_supergraph.sdl(),
            """
        query test($id: ID!, $limit: Int) {
          album(id: $id) {
            albumType
            name
            genres
            tracks(limit: $limit, offset: 10) {
              edges {
                node {
                  name
                }
              }
            }
          }

        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"spotify\") {
    query ($id:ID!,$limit:Int) {
      album(id: $id) {
        albumType
        name
        genres
        tracks(limit: $limit, offset: 10) {
          edges {
            node {
              name
            }
          }
        }
      }
    }
  },
},""",
    )


def test_arguments_with_aliases() raises:
    assert_equal(
        _plan(
            parent_entity_call_complex.sdl(),
            """
        query {
          firstProduct: productFromD(id: \"1\") {
            id
            name
            category {
              id
              name
              details
            }
          }
          secondProduct: productFromD(id: \"2\") {
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
        firstProduct: productFromD(id: \"1\") {
          ...a
        }
        secondProduct: productFromD(id: \"2\") {
          ...a
        }
      }
      fragment a on Product {
        __typename
        id
        name
      }
    },
    Parallel {
      BatchFetch(service: \"a\") {
        {
          _e0 {
            paths: [
              \"secondProduct\"
              \"firstProduct\"
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
              category {
                details
              }
            }
          }
        }
      },
      BatchFetch(service: \"b\") {
        {
          _e0 {
            paths: [
              \"secondProduct\"
              \"firstProduct\"
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
              category {
                __typename
                id
              }
            }
          }
        }
      },
    },
    BatchFetch(service: \"c\") {
      {
        _e0 {
          paths: [
            \"secondProduct.category\"
            \"firstProduct.category\"
          ]
          {
            ... on Category {
              __typename
              id
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Category {
            name
          }
        }
      }
    },
  },
},""",
    )


def test_arguments_variables_mixed() raises:
    assert_equal(
        _plan(
            parent_entity_call_complex.sdl(),
            """
        query test($secondProductId: ID!) {
          firstProduct: productFromD(id: \"1\") {
            id
            name
            category {
              id
              name
              details
            }
          }
          secondProduct: productFromD(id: $secondProductId) {
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
      query ($secondProductId:ID!) {
        firstProduct: productFromD(id: \"1\") {
          ...a
        }
        secondProduct: productFromD(id: $secondProductId) {
          ...a
        }
      }
      fragment a on Product {
        __typename
        id
        name
      }
    },
    Parallel {
      BatchFetch(service: \"a\") {
        {
          _e0 {
            paths: [
              \"secondProduct\"
              \"firstProduct\"
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
              category {
                details
              }
            }
          }
        }
      },
      BatchFetch(service: \"b\") {
        {
          _e0 {
            paths: [
              \"secondProduct\"
              \"firstProduct\"
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
              category {
                __typename
                id
              }
            }
          }
        }
      },
    },
    BatchFetch(service: \"c\") {
      {
        _e0 {
          paths: [
            \"secondProduct.category\"
            \"firstProduct.category\"
          ]
          {
            ... on Category {
              __typename
              id
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Category {
            name
          }
        }
      }
    },
  },
},""",
    )


def test_requires_with_argument_conflict_after_entity_hop() raises:
    assert_equal(
        _plan(
            requires_argument_conflict_after_hop.sdl(),
            """
        {
          user {
            orders {
              usd
              eur
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
              price(currency: \"USD\")
              _internal_qp_alias_0: price(currency: \"EUR\")
            }
          }
        }
      },
    },
    BatchFetch(service: \"catalog\") {
      {
        _e0 {
          paths: [
            \"user.orders.@\"
          ]
          {
            ... on Order {
              __typename
              price: _internal_qp_alias_0
              id
            }
          }
        }
        _e1 {
          paths: [
            \"user.orders.@\"
          ]
          {
            ... on Order {
              __typename
              price
              id
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Order {
            eur
          }
        }
        _e1: _entities(representations: $__batch_reps_1) {
          ... on Order {
            usd
          }
        }
      }
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
