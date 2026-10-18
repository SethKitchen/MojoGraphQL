# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/requires_circular.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import requires_circular
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_requires_circular_1() raises:
    assert_equal(
        _plan(
            requires_circular.sdl(),
            """
        {
          feed {
            byNovice
          }
        }
        """,
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
            author {
              __typename
              id
            }
          }
        }
      },
    },
    Flatten(path: \"feed.@.author\") {
      Fetch(service: \"a\") {
        {
          ... on Author {
            __typename
            id
          }
        } =>
        {
          ... on Author {
            yearsOfExperience
          }
        }
      },
    },
    Flatten(path: \"feed.@\") {
      Fetch(service: \"b\") {
        {
          ... on Post {
            __typename
            author {
              yearsOfExperience
            }
            id
          }
        } =>
        {
          ... on Post {
            byNovice
          }
        }
      },
    },
  },
},""",
    )


def test_requires_circular_2() raises:
    assert_equal(
        _plan(
            requires_circular.sdl(),
            """
        {
          feed {
            byExpert
          }
        }
        """,
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
            author {
              __typename
              id
            }
          }
        }
      },
    },
    Flatten(path: \"feed.@.author\") {
      Fetch(service: \"a\") {
        {
          ... on Author {
            __typename
            id
          }
        } =>
        {
          ... on Author {
            yearsOfExperience
          }
        }
      },
    },
    Flatten(path: \"feed.@\") {
      Fetch(service: \"b\") {
        {
          ... on Post {
            __typename
            author {
              yearsOfExperience
            }
            id
          }
        } =>
        {
          ... on Post {
            byNovice
          }
        }
      },
    },
    Flatten(path: \"feed.@\") {
      Fetch(service: \"a\") {
        {
          ... on Post {
            __typename
            byNovice
            id
          }
        } =>
        {
          ... on Post {
            byExpert
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
