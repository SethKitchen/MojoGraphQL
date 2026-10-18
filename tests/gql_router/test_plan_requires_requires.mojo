# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/requires_requires.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.

The operation of `overlapping_requires_chains_survive_fetch_step_merges` is upstream
`tests/fixtures/overlapping_requires_chains.graphql`.
"""

from _fixtures import overlapping_requires_chains, requires_requires
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_one() raises:
    assert_equal(
        _plan(
            requires_requires.sdl(),
            """
        query {
          product {
            canAffordWithDiscount
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        product {
          __typename
          id
          hasDiscount
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"c\") {
        {
          ... on Product {
            __typename
            hasDiscount
            id
          }
        } =>
        {
          ... on Product {
            isExpensiveWithDiscount
          }
        }
      },
    },
    Flatten(path: \"product\") {
      Fetch(service: \"d\") {
        {
          ... on Product {
            __typename
            isExpensiveWithDiscount
            id
          }
        } =>
        {
          ... on Product {
            canAffordWithDiscount
          }
        }
      },
    },
  },
},""",
    )


def test_one_with_one_local() raises:
    assert_equal(
        _plan(
            requires_requires.sdl(),
            """
        query {
          product {
            fieldInD
            canAffordWithDiscount
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        product {
          __typename
          id
          hasDiscount
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"c\") {
        {
          ... on Product {
            __typename
            hasDiscount
            id
          }
        } =>
        {
          ... on Product {
            isExpensiveWithDiscount
          }
        }
      },
    },
    Flatten(path: \"product\") {
      Fetch(service: \"d\") {
        {
          ... on Product {
            __typename
            id
            isExpensiveWithDiscount
          }
        } =>
        {
          ... on Product {
            fieldInD
            canAffordWithDiscount
          }
        }
      },
    },
  },
},""",
    )


def test_two_fields_with_the_same_requirements() raises:
    assert_equal(
        _plan(
            requires_requires.sdl(),
            """
        query {
          product {
            canAffordWithDiscount
            canAffordWithDiscount2
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        product {
          __typename
          id
          hasDiscount
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"c\") {
        {
          ... on Product {
            __typename
            hasDiscount
            id
          }
        } =>
        {
          ... on Product {
            isExpensiveWithDiscount
          }
        }
      },
    },
    Flatten(path: \"product\") {
      Fetch(service: \"d\") {
        {
          ... on Product {
            __typename
            isExpensiveWithDiscount
            id
          }
        } =>
        {
          ... on Product {
            canAffordWithDiscount2
            canAffordWithDiscount
          }
        }
      },
    },
  },
},""",
    )


def test_one_more() raises:
    assert_equal(
        _plan(
            requires_requires.sdl(),
            """
        query {
          product {
            canAfford
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        product {
          __typename
          id
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"a\") {
        {
          ... on Product {
            __typename
            id
          }
        } =>
        {
          ... on Product {
            price
          }
        }
      },
    },
    Flatten(path: \"product\") {
      Fetch(service: \"c\") {
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
    Flatten(path: \"product\") {
      Fetch(service: \"d\") {
        {
          ... on Product {
            __typename
            isExpensive
            id
          }
        } =>
        {
          ... on Product {
            canAfford
          }
        }
      },
    },
  },
},""",
    )


def test_another_two_fields_with_the_same_requirements() raises:
    assert_equal(
        _plan(
            requires_requires.sdl(),
            """
        query {
          product {
            canAfford
            canAfford2
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        product {
          __typename
          id
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"a\") {
        {
          ... on Product {
            __typename
            id
          }
        } =>
        {
          ... on Product {
            price
          }
        }
      },
    },
    Flatten(path: \"product\") {
      Fetch(service: \"c\") {
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
    Flatten(path: \"product\") {
      Fetch(service: \"d\") {
        {
          ... on Product {
            __typename
            isExpensive
            id
          }
        } =>
        {
          ... on Product {
            canAfford2
            canAfford
          }
        }
      },
    },
  },
},""",
    )


def test_two_fields() raises:
    assert_equal(
        _plan(
            requires_requires.sdl(),
            """
        query {
          product {
            canAffordWithDiscount
            canAfford
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        product {
          __typename
          id
          hasDiscount
        }
      }
    },
    Parallel {
      Flatten(path: \"product\") {
        Fetch(service: \"c\") {
          {
            ... on Product {
              __typename
              hasDiscount
              id
            }
          } =>
          {
            ... on Product {
              isExpensiveWithDiscount
            }
          }
        },
      },
      Flatten(path: \"product\") {
        Fetch(service: \"a\") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              price
            }
          }
        },
      },
    },
    Flatten(path: \"product\") {
      Fetch(service: \"c\") {
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
    Flatten(path: \"product\") {
      Fetch(service: \"d\") {
        {
          ... on Product {
            __typename
            isExpensiveWithDiscount
            id
            isExpensive
          }
        } =>
        {
          ... on Product {
            canAffordWithDiscount
            canAfford
          }
        }
      },
    },
  },
},""",
    )


def test_two_fields_same_requirement_different_order() raises:
    assert_equal(
        _plan(
            requires_requires.sdl(),
            """
        query {
          product {
            canAffordWithAndWithoutDiscount
            canAffordWithAndWithoutDiscount2
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        product {
          __typename
          id
          hasDiscount
        }
      }
    },
    Parallel {
      Flatten(path: \"product\") {
        Fetch(service: \"c\") {
          {
            ... on Product {
              __typename
              hasDiscount
              id
            }
          } =>
          {
            ... on Product {
              isExpensiveWithDiscount
            }
          }
        },
      },
      Flatten(path: \"product\") {
        Fetch(service: \"a\") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              price
            }
          }
        },
      },
    },
    Flatten(path: \"product\") {
      Fetch(service: \"c\") {
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
    Flatten(path: \"product\") {
      Fetch(service: \"d\") {
        {
          ... on Product {
            __typename
            isExpensive
            isExpensiveWithDiscount
            id
          }
        } =>
        {
          ... on Product {
            canAffordWithAndWithoutDiscount2
            canAffordWithAndWithoutDiscount
          }
        }
      },
    },
  },
},""",
    )


def test_many() raises:
    assert_equal(
        _plan(
            requires_requires.sdl(),
            """
        query {
          product {
            id
            price
            hasDiscount
            isExpensive
            isExpensiveWithDiscount
            canAfford
            canAfford2
            canAffordWithDiscount
            canAffordWithDiscount2
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        product {
          __typename
          id
          hasDiscount
        }
      }
    },
    Parallel {
      Flatten(path: \"product\") {
        Fetch(service: \"c\") {
          {
            ... on Product {
              __typename
              hasDiscount
              id
            }
          } =>
          {
            ... on Product {
              isExpensiveWithDiscount
            }
          }
        },
      },
      Flatten(path: \"product\") {
        Fetch(service: \"a\") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              price
            }
          }
        },
      },
    },
    Flatten(path: \"product\") {
      Fetch(service: \"c\") {
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
    Flatten(path: \"product\") {
      Fetch(service: \"d\") {
        {
          ... on Product {
            __typename
            isExpensive
            id
            isExpensiveWithDiscount
          }
        } =>
        {
          ... on Product {
            canAfford2
            canAfford
            canAffordWithDiscount2
            canAffordWithDiscount
          }
        }
      },
    },
  },
},""",
    )


def test_overlapping_requires_chains_survive_fetch_step_merges() raises:
    assert_equal(
        _plan(requires_requires.sdl(), overlapping_requires_chains.sdl()),
        """QueryPlan {
  Sequence {
    Fetch(service: "b") {
      {
        product {
          __typename
          id
          hasDiscount
        }
      }
    },
    Parallel {
      Flatten(path: "product") {
        Fetch(service: "c") {
          {
            ... on Product {
              __typename
              hasDiscount
              id
            }
          } =>
          {
            ... on Product {
              isExpensiveWithDiscount
            }
          }
        },
      },
      Flatten(path: "product") {
        Fetch(service: "a") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              price
            }
          }
        },
      },
    },
    Flatten(path: "product") {
      Fetch(service: "c") {
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
    Flatten(path: "product") {
      Fetch(service: "d") {
        {
          ... on Product {
            __typename
            isExpensive
            id
            isExpensiveWithDiscount
          }
        } =>
        {
          ... on Product {
            canAfford
            requestedB: canAffordWithAndWithoutDiscount
            canAffordWithAndWithoutDiscount
            requestedA: canAffordWithAndWithoutDiscount
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
