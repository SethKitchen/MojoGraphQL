# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/fragments.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import corrupted_supergraph_node_id
from _fixtures import testing
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_multiple_inline_fragments_on_same_concrete_type_within_interface_fragment() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account(id: \"a1\") {
            ... on Node {
              ... on Account {
                id
              }
              ... on Account {
                username
              }
            }
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


def test_nested_same_name_directives_on_abstract_and_concrete_fragments() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query ($parent: Boolean!, $child: Boolean!) {
          account(id: \"a1\") {
            ... on Node @include(if: $parent) {
              ... on Account @include(if: $child) {
                username
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($child:Boolean!,$parent:Boolean!) {
      account(id: \"a1\") {
        ... on Account @include(if: $parent) {
          ... on Account @include(if: $child) {
            username
          }
        }
      }
    }
  },
},""",
    )


def test_nested_same_directive_same_arg_on_abstract_and_concrete_fragments() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query ($cond: Boolean!) {
          account(id: \"a1\") {
            ... on Node @include(if: $cond) {
              ... on Account @include(if: $cond) {
                username
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($cond:Boolean!) {
      account(id: \"a1\") {
        ... on Account @include(if: $cond) {
          username
        }
      }
    }
  },
},""",
    )


def test_nested_different_directives_on_abstract_and_concrete_fragments() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query ($skip: Boolean!, $include: Boolean!) {
          account(id: \"a1\") {
            ... on Node @skip(if: $skip) {
              ... on Account @include(if: $include) {
                username
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($include:Boolean!,$skip:Boolean!) {
      account(id: \"a1\") {
        ... on Account @skip(if: $skip) @include(if: $include) {
          username
        }
      }
    }
  },
},""",
    )


def test_parent_directive_only_on_abstract_fragment() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query ($parent: Boolean!) {
          account(id: \"a1\") {
            ... on Node @include(if: $parent) {
              ... on Account {
                username
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($parent:Boolean!) {
      account(id: \"a1\") {
        ... on Account @include(if: $parent) {
          username
        }
      }
    }
  },
},""",
    )


def test_reusable_fragment_with_mixed_include_conditions_on_concrete_parent() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query ($first: Boolean!, $second: Boolean!) {
          account(id: \"a1\") {
            ...AccountFields @include(if: $first)
            ...AccountFields @include(if: $second)
          }
        }

        fragment AccountFields on Account {
          username
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($first:Boolean!,$second:Boolean!) {
      account(id: \"a1\") {
        ... on Account @include(if: $first) {
          ...a
        }
        ... on Account @include(if: $second) {
          ...a
        }
      }
    }
    fragment a on Account {
      username
    }
  },
},""",
    )


def test_reusable_fragment_with_mixed_include_conditions_on_abstract_parent() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query ($first: Boolean!, $second: Boolean!) {
          account(id: \"a1\") {
            ... on Node {
              ...AccountFields @include(if: $first)
              ...AccountFields @include(if: $second)
            }
          }
        }

        fragment AccountFields on Account {
          username
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($first:Boolean!,$second:Boolean!) {
      account(id: \"a1\") {
        ... on Account @include(if: $first) {
          ...a
        }
        ... on Account @include(if: $second) {
          ...a
        }
      }
    }
    fragment a on Account {
      username
    }
  },
},""",
    )


def test_simple_inline_fragment() raises:
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
                ... on Product {
                  isAvailable
                }
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


def test_fragment_spread() raises:
    assert_equal(
        _plan(
            testing.sdl(),
            """
        fragment ProductInfo on Product {
          isAvailable
        }

        query {
          products {
            price {
              amount
              currency
            }
            ...ProductInfo
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
