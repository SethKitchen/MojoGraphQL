# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/mutations.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import mutations
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_mutations() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          addProduct(input: { name: \"new\", price: 599.99 }) {
            name
            price
            isExpensive
            isAvailable
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      mutation {
        addProduct(input: {name: \"new\", price: 599.99}) {
          __typename
          name
          price
          id
        }
      }
    },
    Flatten(path: \"addProduct\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
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


def test_many_fields_two_same_graph() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          five: add(num: 5)
          ten: multiply(by: 2)
          twelve: add(num: 2)
          final: delete
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"c\") {
      mutation {
        five: add(num: 5)
      }
    },
    Fetch(service: \"a\") {
      mutation {
        ten: multiply(by: 2)
      }
    },
    Fetch(service: \"c\") {
      mutation {
        twelve: add(num: 2)
      }
    },
    Fetch(service: \"b\") {
      mutation {
        final: delete
      }
    },
  },
},""",
    )
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          five: add(num: 5)
          seven: add(num: 2)
          fourteen: multiply(by: 2)
          sixteen: add(num: 2)
          final: delete
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"c\") {
      mutation {
        five: add(num: 5)
        seven: add(num: 2)
      }
    },
    Fetch(service: \"a\") {
      mutation {
        fourteen: multiply(by: 2)
      }
    },
    Fetch(service: \"c\") {
      mutation {
        sixteen: add(num: 2)
      }
    },
    Fetch(service: \"b\") {
      mutation {
        final: delete
      }
    },
  },
},""",
    )


def test_three_fields_in_a_row_same_graph() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          one: add(num: 1)
          two: add(num: 2)
          three: add(num: 3)
          final: delete
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"c\") {
      mutation {
        one: add(num: 1)
        two: add(num: 2)
        three: add(num: 3)
      }
    },
    Fetch(service: \"b\") {
      mutation {
        final: delete
      }
    },
  },
},""",
    )


def test_next_field_waits_for_entity_fetch_of_previous_one() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          create: addProduct(input: { name: \"new\", price: 599.99 }) {
            isExpensive
          }
          count: add(num: 1)
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      mutation {
        create: addProduct(input: {name: \"new\", price: 599.99}) {
          __typename
          id
          price
        }
      }
    },
    Flatten(path: \"create\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        {
          ... on Product {
            isExpensive
          }
        }
      },
    },
    Fetch(service: \"c\") {
      mutation {
        count: add(num: 1)
      }
    },
  },
},""",
    )


def test_next_field_waits_for_conditional_entity_fetch_of_previous_one() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation ($includeRemote: Boolean!) {
          create: addProduct(input: { name: \"new\", price: 599.99 }) {
            ... on Product @include(if: $includeRemote) {
              isExpensive
            }
          }
          count: add(num: 1)
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      mutation ($includeRemote:Boolean!) {
        create: addProduct(input: {name: \"new\", price: 599.99}) {
          ... on Product @include(if: $includeRemote) {
            __typename
            id
            price
          }
        }
      }
    },
    Include(if: $includeRemote) {
      Flatten(path: \"create|[Product]\") {
        Fetch(service: \"b\") {
          {
            ... on Product {
              __typename
              price
              id
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
    Fetch(service: \"c\") {
      mutation {
        count: add(num: 1)
      }
    },
  },
},""",
    )


def test_neighbours_in_one_graph_share_a_fetch_when_first_needs_another_fetch() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          create: addProduct(input: { name: \"new\", price: 599.99 }) {
            isExpensive
          }
          double: multiply(by: 2)
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      mutation {
        create: addProduct(input: {name: \"new\", price: 599.99}) {
          __typename
          id
          price
        }
        double: multiply(by: 2)
      }
    },
    Flatten(path: \"create\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
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


def test_next_graph_waits_for_entity_fetch_of_the_group() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          create: addProduct(input: { name: \"new\", price: 599.99 }) {
            isExpensive
          }
          double: multiply(by: 2)
          count: add(num: 1)
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      mutation {
        create: addProduct(input: {name: \"new\", price: 599.99}) {
          __typename
          id
          price
        }
        double: multiply(by: 2)
      }
    },
    Flatten(path: \"create\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        {
          ... on Product {
            isExpensive
          }
        }
      },
    },
    Fetch(service: \"c\") {
      mutation {
        count: add(num: 1)
      }
    },
  },
},""",
    )


def test_next_graph_waits_for_entity_fetch_of_a_later_field_in_the_group() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          double: multiply(by: 2)
          create: addProduct(input: { name: \"new\", price: 599.99 }) {
            isExpensive
          }
          count: add(num: 1)
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      mutation {
        double: multiply(by: 2)
        create: addProduct(input: {name: \"new\", price: 599.99}) {
          __typename
          id
          price
        }
      }
    },
    Flatten(path: \"create\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        {
          ... on Product {
            isExpensive
          }
        }
      },
    },
    Fetch(service: \"c\") {
      mutation {
        count: add(num: 1)
      }
    },
  },
},""",
    )


def test_next_graph_waits_for_entity_fetch_to_the_same_graph() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          create: addProduct(input: { name: \"new\", price: 599.99 }) {
            isExpensive
          }
          double: multiply(by: 2)
          final: delete
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      mutation {
        create: addProduct(input: {name: \"new\", price: 599.99}) {
          __typename
          id
          price
        }
        double: multiply(by: 2)
      }
    },
    Flatten(path: \"create\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        {
          ... on Product {
            isExpensive
          }
        }
      },
    },
    Fetch(service: \"b\") {
      mutation {
        final: delete
      }
    },
  },
},""",
    )


def test_fields_of_one_graph_with_another_graph_between_stay_apart() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation {
          one: add(num: 1)
          create: addProduct(input: { name: \"new\", price: 599.99 }) {
            isExpensive
          }
          two: add(num: 2)
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"c\") {
      mutation {
        one: add(num: 1)
      }
    },
    Fetch(service: \"a\") {
      mutation {
        create: addProduct(input: {name: \"new\", price: 599.99}) {
          __typename
          id
          price
        }
      }
    },
    Flatten(path: \"create\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        {
          ... on Product {
            isExpensive
          }
        }
      },
    },
    Fetch(service: \"c\") {
      mutation {
        two: add(num: 2)
      }
    },
  },
},""",
    )


def test_conditional_field_stays_in_its_group() raises:
    assert_equal(
        _plan(
            mutations.sdl(),
            """
        mutation ($x: Boolean!) {
          one: add(num: 1) @include(if: $x)
          two: add(num: 2)
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"c\") {
    mutation ($x:Boolean!) {
      one: add(num: 1) @include(if: $x)
      two: add(num: 2)
    }
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
