# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/interface.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import corrupted_supergraph_node_id
from _fixtures import abstract_types
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_node_query_with_aliases_on_interface_field() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account: node(id: \"a1\") {
            __typename
          }
          chat: node(id: \"c1\") {
            __typename
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      account: node(id: \"a1\") {
        ...a
      }
      chat: node(id: \"c1\") {
        ...a
      }
    }
    fragment a on Node {
      __typename
    }
  },
},""",
    )


def test_node_query_with_inline_fragments_on_object_types() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account: node(id: \"a1\") {
            ... on Account {
              id
              username
            }
          }
          chat: node(id: \"c1\") {
            ... on Chat {
              id
              text
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Parallel {
    Fetch(service: \"b\") {
      {
        chat: node(id: \"c1\") {
          __typename
          ... on Chat {
            id
            text
          }
        }
      }
    },
    Fetch(service: \"a\") {
      {
        account: node(id: \"a1\") {
          __typename
          ... on Account {
            id
            username
          }
        }
      }
    },
  },
},""",
    )


def test_node_query_with_cross_type_inline_fragments() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account: node(id: \"a1\") {
            ... on Chat {
              id
            }
          }
          chat: node(id: \"c1\") {
            ... on Account {
              id
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Parallel {
    Fetch(service: \"a\") {
      {
        chat: node(id: \"c1\") {
          __typename
          ... on Account {
            id
          }
        }
      }
    },
    Fetch(service: \"b\") {
      {
        account: node(id: \"a1\") {
          __typename
          ... on Chat {
            id
          }
        }
      }
    },
  },
},""",
    )


def test_node_query_with_typename_and_cross_type_fragments() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account: node(id: \"a1\") {
            __typename
            ... on Chat {
              id
            }
          }
          chat: node(id: \"c1\") {
            __typename
            ... on Account {
              id
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Parallel {
    Fetch(service: \"a\") {
      {
        chat: node(id: \"c1\") {
          __typename
          ... on Account {
            id
          }
        }
      }
    },
    Fetch(service: \"b\") {
      {
        account: node(id: \"a1\") {
          __typename
          ... on Chat {
            id
          }
        }
      }
    },
  },
},""",
    )


def test_direct_object_query_chat_by_id() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          chat(id: \"c1\") {
            id
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      chat(id: \"c1\") {
        id
      }
    }
  },
},""",
    )


def test_direct_object_query_account_by_id() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account(id: \"a1\") {
            id
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
      }
    }
  },
},""",
    )


def test_object_query_with_nested_object_field() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          chat(id: \"c1\") {
            id
            text
            account {
              id
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        chat(id: \"c1\") {
          __typename
          id
          text
        }
      }
    },
    Flatten(path: \"chat\") {
      Fetch(service: \"a\") {
        {
          ... on Chat {
            __typename
            id
          }
        } =>
        {
          ... on Chat {
            account {
              id
            }
          }
        }
      },
    },
  },
},""",
    )


def test_object_query_with_nested_list_field() raises:
    assert_equal(
        _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account(id: \"a1\") {
            id
            username
            chats {
              id
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
        account(id: \"a1\") {
          __typename
          id
          username
        }
      }
    },
    Flatten(path: \"account\") {
      Fetch(service: \"b\") {
        {
          ... on Account {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            chats {
              id
            }
          }
        }
      },
    },
  },
},""",
    )


def test_node_query_with_id_on_interface_field() raises:
    with assert_raises():
        _ = _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          node(id: \"a1\") {
            id
          }
        }
        """,
            PlannerOverrideContext.default(),
        )


def test_node_query_with_multiple_type_fragments() raises:
    with assert_raises():
        _ = _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          node(id: \"a1\") {
            ... on Chat {
              id
            }
            ... on Account {
              id
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        )


def test_node_query_with_id_and_cross_type_fragment_overlap() raises:
    with assert_raises():
        _ = _plan(
            corrupted_supergraph_node_id.sdl(),
            """
        query {
          account: node(id: \"a1\") {
            id
            ... on Chat {
              id
            }
          }
          chat: node(id: \"c1\") {
            __typename
            ... on Account {
              id
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        )


def test_type_expand_interface_field() raises:
    assert_equal(
        _plan(
            abstract_types.sdl(),
            """
        query {
          products {
            id
            reviews {
              id
            }
          }
        }
      ,
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          id
          __typename
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"reviews\") {
        {
          ... on Book {
            __typename
            id
          }
          ... on Magazine {
            __typename
            id
          }
        } =>
        {
          ... on Book {
            reviews {
              ...a
            }
          }
          ... on Magazine {
            reviews {
              ...a
            }
          }
        }
        fragment a on Review {
          id
        }
      },
    },
  },
},""",
    )


def test_requires_on_field_with_args_test() raises:
    assert_equal(
        _plan(
            abstract_types.sdl(),
            """
        {
          book: similar(id: \"p1\") {
            id
            sku
            delivery(zip: \"1234\") {
              fastestDelivery
              estimatedDelivery
            }
          }
          magazine: similar(id: \"p2\") {
            id
            sku
            delivery(zip: \"1234\") {
              fastestDelivery
              estimatedDelivery
            }
          }
        }
      ,
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        book: similar(id: \"p1\") {
          ...a
        }
        magazine: similar(id: \"p2\") {
          ...a
        }
      }
      fragment a on Product {
        id
        __typename
        sku
        dimensions {
          weight
          size
        }
      }
    },
    BatchFetch(service: \"inventory\") {
      {
        _e0 {
          paths: [
            \"magazine.@\"
            \"book.@\"
          ]
          {
            ... on Book {
              __typename
              dimensions {
                size
                weight
              }
              id
            }
            ... on Magazine {
              __typename
              dimensions {
                size
                weight
              }
              id
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Book {
            delivery(zip: \"1234\") {
              ...a
            }
          }
          ... on Magazine {
            delivery(zip: \"1234\") {
              ...a
            }
          }
        }
      }
      fragment a on DeliveryEstimates {
        ... on DeliveryEstimates {
          fastestDelivery
          estimatedDelivery
        }
      }
    },
  },
},""",
    )


def test_nested_interface_field_with_inline_fragments() raises:
    assert_equal(
        _plan(
            abstract_types.sdl(),
            """
        query ($title: Boolean = true) {
          products {
            id
            reviews {
              product {
                id
                ... on Book @include(if: $title) {
                  title
                }
                ... on Magazine {
                  sku
                }
              }
            }
          }
        }
      ,
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          id
          __typename
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"reviews\") {
        {
          ... on Book {
            __typename
            id
          }
          ... on Magazine {
            __typename
            id
          }
        } =>
        {
          ... on Book {
            reviews {
              ...a
            }
          }
          ... on Magazine {
            reviews {
              ...a
            }
          }
        }
        fragment a on Review {
          product {
            id
            __typename
          }
        }
      },
    },
    Parallel {
      Include(if: $title) {
        Flatten(path: \"products.@.reviews.@.product|[Book]\") {
          Fetch(service: \"books\") {
            {
              ... on Book {
                __typename
                id
              }
            } =>
            {
              ... on Book {
                title
              }
            }
          },
        },
      },
      Flatten(path: \"products.@.reviews.@.product|[Magazine]\") {
        Fetch(service: \"products\") {
          {
            ... on Magazine {
              __typename
              id
            }
          } =>
          {
            ... on Magazine {
              sku
            }
          }
        },
      },
    },
  },
},""",
    )


def test_nested_interface_field_with_redundant_inline_fragments() raises:
    assert_equal(
        _plan(
            abstract_types.sdl(),
            """
        query ($title: Boolean = true) {
          products {
            id
            reviews {
              product {
                id
                ... on Book @include(if: $title) {
                  title
                  ... on Book {
                    sku
                  }
                }
                ... on Magazine {
                  sku
                }
              }
            }
          }
        }
      ,
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          id
          __typename
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"reviews\") {
        {
          ... on Book {
            __typename
            id
          }
          ... on Magazine {
            __typename
            id
          }
        } =>
        {
          ... on Book {
            reviews {
              ...a
            }
          }
          ... on Magazine {
            reviews {
              ...a
            }
          }
        }
        fragment a on Review {
          product {
            id
            __typename
          }
        }
      },
    },
    Parallel {
      Include(if: $title) {
        Flatten(path: \"products.@.reviews.@.product|[Book]\") {
          Fetch(service: \"books\") {
            {
              ... on Book {
                __typename
                id
              }
            } =>
            {
              ... on Book {
                title
              }
            }
          },
        },
      },
      Flatten(path: \"products.@.reviews.@.product\") {
        Fetch(service: \"products\") {
          {
            ... on Book {
              __typename
              id
            }
            ... on Magazine {
              __typename
              id
            }
          } =>
          ($title:Boolean=true) {
            ... on Book @include(if: $title) {
              sku
            }
            ... on Magazine {
              sku
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
