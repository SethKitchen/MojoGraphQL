# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/requires_provides.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import requires_provides
from _fixtures import provides_requires_typename
from _fixtures import requires_nested_same_type
from _fixtures import provides_union_member
from _fixtures import provides_scope
from _fixtures import provides_copies
from _fixtures import requires_provided_after_hop
from _fixtures import requires_partly_provided_after_hop
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_simple_requires_provides() raises:
    assert_equal(
        _plan(
            requires_provides.sdl(),
            """
        query {
          me {
            reviews {
              id
              author {
                id
                username
              }
              product {
                inStock
              }
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"accounts\") {
      {
        me {
          __typename
          id
        }
      }
    },
    Flatten(path: \"me\") {
      Fetch(service: \"reviews\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            reviews {
              id
              author {
                id
                username
              }
              product {
                __typename
                upc
              }
            }
          }
        }
      },
    },
    Flatten(path: \"me.reviews.@.product\") {
      Fetch(service: \"inventory\") {
        {
          ... on Product {
            __typename
            upc
          }
        } =>
        {
          ... on Product {
            inStock
          }
        }
      },
    },
  },
},""",
    )


def test_provides_fieldset_with_typename_and_requires() raises:
    assert_equal(
        _plan(
            provides_requires_typename.sdl(),
            """
        query {
          review {
            author {
              username
              __typename
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"reviews\") {
      {
        review {
          __typename
          id
        }
      }
    },
    Flatten(path: \"review\") {
      Fetch(service: \"secrets\") {
        {
          ... on Review {
            __typename
            id
          }
        } =>
        {
          ... on Review {
            secret
          }
        }
      },
    },
    Flatten(path: \"review\") {
      Fetch(service: \"reviews\") {
        {
          ... on Review {
            __typename
            secret
            id
          }
        } =>
        {
          ... on Review {
            author {
              username
              __typename
            }
          }
        }
      },
    },
  },
},""",
    )


def test_requires_on_same_type_nested_in_entity_call() raises:
    assert_equal(
        _plan(
            requires_nested_same_type.sdl(),
            """
        {
          user {
            other {
              label
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
      Fetch(service: \"social\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            other {
              __typename
              id
            }
          }
        }
      },
    },
    Flatten(path: \"user.other\") {
      Fetch(service: \"names\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            name
          }
        }
      },
    },
    Flatten(path: \"user.other\") {
      Fetch(service: \"social\") {
        {
          ... on User {
            __typename
            name
            id
          }
        } =>
        {
          ... on User {
            label
          }
        }
      },
    },
  },
},""",
    )


def test_requires_on_same_type_nested_under_provides() raises:
    assert_equal(
        _plan(
            requires_nested_same_type.sdl(),
            """
        {
          user {
            related {
              other {
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
    Fetch(service: \"users\") {
      {
        user {
          __typename
          id
        }
      }
    },
    Flatten(path: \"user\") {
      Fetch(service: \"social\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            related {
              other {
                __typename
                id
              }
            }
          }
        }
      },
    },
    Flatten(path: \"user.related.other\") {
      Fetch(service: \"names\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            name
          }
        }
      },
    },
    Flatten(path: \"user.related.other\") {
      Fetch(service: \"social\") {
        {
          ... on User {
            __typename
            name
            id
          }
        } =>
        {
          ... on User {
            label
          }
        }
      },
    },
  },
},""",
    )


def test_provided_union_keeps_members_that_are_not_provided() raises:
    assert_equal(
        _plan(
            provides_union_member.sdl(),
            """
        {
          user {
            orders {
              item {
                ... on Book {
                  isbn
                  stock
                }
                ... on Movie {
                  title
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
              item {
                __typename
                ... on Book {
                  isbn
                  stock
                }
                ... on Movie {
                  __typename
                  id
                }
              }
            }
          }
        }
      },
    },
    Flatten(path: \"user.orders.@.item|[Movie]\") {
      Fetch(service: \"catalog\") {
        {
          ... on Movie {
            __typename
            id
          }
        } =>
        {
          ... on Movie {
            title
          }
        }
      },
    },
  },
},""",
    )


def test_provides_does_not_leak_to_another_parent() raises:
    assert_equal(
        _plan(
            provides_scope.sdl(),
            """
        {
          store {
            orders {
              sku
              weight
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
        store {
          __typename
          id
        }
      }
    },
    Flatten(path: \"store\") {
      Fetch(service: \"orders\") {
        {
          ... on Store {
            __typename
            id
          }
        } =>
        {
          ... on Store {
            orders {
              __typename
              id
              weight
            }
          }
        }
      },
    },
    Flatten(path: \"store.orders.@\") {
      Fetch(service: \"catalog\") {
        {
          ... on Order {
            __typename
            id
          }
        } =>
        {
          ... on Order {
            sku
          }
        }
      },
    },
  },
},""",
    )


def test_provides_does_not_apply_to_another_field() raises:
    assert_equal(
        _plan(
            provides_scope.sdl(),
            """
        {
          user {
            pastOrders {
              sku
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
            pastOrders {
              __typename
              id
            }
          }
        }
      },
    },
    Flatten(path: \"user.pastOrders.@\") {
      Fetch(service: \"catalog\") {
        {
          ... on Order {
            __typename
            id
          }
        } =>
        {
          ... on Order {
            sku
          }
        }
      },
    },
  },
},""",
    )


def test_provides_reaches_copies_made_earlier() raises:
    assert_equal(
        _plan(
            provides_copies.sdl(),
            """
        {
          user {
            orders {
              sku
              product {
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
              sku
              product {
                name
              }
            }
          }
        }
      },
    },
  },
},""",
    )


def test_requires_provided_after_entity_hop() raises:
    assert_equal(
        _plan(
            requires_provided_after_hop.sdl(),
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
              sku
              name
            }
          }
        }
      },
    },
  },
},""",
    )


def test_requires_partly_provided_after_entity_hop() raises:
    assert_equal(
        _plan(
            requires_partly_provided_after_hop.sdl(),
            """
        query ($x: Boolean!) {
          user {
            orders {
              name @include(if: $x)
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
        ($x:Boolean!) {
          ... on User {
            orders {
              __typename
              id
              sku @include(if: $x)
            }
          }
        }
      },
    },
    Include(if: $x) {
      Sequence {
        Flatten(path: \"user.orders.@\") {
          Fetch(service: \"catalog\") {
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
          Fetch(service: \"orders\") {
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
    },
  },
},""",
    )


def test_requires_provided_through_type_condition() raises:
    assert_equal(
        _plan(
            provides_union_member.sdl(),
            """
        {
          user {
            orders {
              label
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
              item {
                __typename
                ... on Book {
                  isbn
                }
              }
              label
            }
          }
        }
      },
    },
  },
},""",
    )


def test_requires_provided_through_interface_condition() raises:
    assert_equal(
        _plan(
            provides_scope.sdl(),
            """
        {
          user {
            orders {
              mediaLabel
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
              media {
                __typename
                ... on Book {
                  isbn
                }
              }
              mediaLabel
            }
          }
        }
      },
    },
  },
},""",
    )


def test_provides_on_field_returning_its_own_type() raises:
    assert_equal(
        _plan(
            provides_copies.sdl(),
            """
        {
          user {
            label
            related {
              label
              related {
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
    Fetch(service: \"users\") {
      {
        user {
          __typename
          id
        }
      }
    },
    Flatten(path: \"user\") {
      Fetch(service: \"names\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            name
          }
        }
      },
    },
    Flatten(path: \"user\") {
      Fetch(service: \"social\") {
        {
          ... on User {
            __typename
            id
            name
          }
        } =>
        {
          ... on User {
            related {
              name
              label
              related {
                name
                label
              }
            }
            label
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
