# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/override_requires.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import override_requires
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_override_with_requires_many() raises:
    assert_equal(
        _plan(
            override_requires.sdl(),
            """
        query {
          userInA {
            id
            name
            aName
            cName
          }
          userInB {
            id
            name
            aName
            cName
          }
          userInC {
            id
            name
            aName
            cName
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Parallel {
      Fetch(service: \"c\") {
        {
          userInC {
            __typename
            id
          }
        }
      },
      Fetch(service: \"b\") {
        {
          userInB {
            __typename
            id
            name
          }
        }
      },
      Fetch(service: \"a\") {
        {
          userInA {
            __typename
            id
          }
        }
      },
    },
    Parallel {
      BatchFetch(service: \"b\") {
        {
          _e0 {
            paths: [
              \"userInC\"
              \"userInA\"
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
      Flatten(path: \"userInB\") {
        Fetch(service: \"c\") {
          {
            ... on User {
              __typename
              name
              id
            }
          } =>
          {
            ... on User {
              cName
            }
          }
        },
      },
      Flatten(path: \"userInB\") {
        Fetch(service: \"a\") {
          {
            ... on User {
              __typename
              name
              id
            }
          } =>
          {
            ... on User {
              aName
            }
          }
        },
      },
    },
    Parallel {
      BatchFetch(service: \"c\") {
        {
          _e0 {
            paths: [
              \"userInC\"
              \"userInA\"
            ]
            {
              ... on User {
                __typename
                name
                id
              }
            }
          }
        }
        {
          _e0: _entities(representations: $__batch_reps_0) {
            ... on User {
              cName
            }
          }
        }
      },
      BatchFetch(service: \"a\") {
        {
          _e0 {
            paths: [
              \"userInC\"
              \"userInA\"
            ]
            {
              ... on User {
                __typename
                name
                id
              }
            }
          }
        }
        {
          _e0: _entities(representations: $__batch_reps_0) {
            ... on User {
              aName
            }
          }
        }
      },
    },
  },
},""",
    )


def test_override_with_requires_cname_in_c() raises:
    assert_equal(
        _plan(
            override_requires.sdl(),
            """
        query {
          userInC {
            cName
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"c\") {
      {
        userInC {
          __typename
          id
        }
      }
    },
    Flatten(path: \"userInC\") {
      Fetch(service: \"b\") {
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
    Flatten(path: \"userInC\") {
      Fetch(service: \"c\") {
        {
          ... on User {
            __typename
            name
            id
          }
        } =>
        {
          ... on User {
            cName
          }
        }
      },
    },
  },
},""",
    )


def test_override_with_requires_cname_in_a() raises:
    assert_equal(
        _plan(
            override_requires.sdl(),
            """
        query {
          userInA {
            cName
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        userInA {
          __typename
          id
        }
      }
    },
    Flatten(path: \"userInA\") {
      Fetch(service: \"b\") {
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
    Flatten(path: \"userInA\") {
      Fetch(service: \"c\") {
        {
          ... on User {
            __typename
            name
            id
          }
        } =>
        {
          ... on User {
            cName
          }
        }
      },
    },
  },
},""",
    )


def test_override_with_requires_aname_in_a() raises:
    assert_equal(
        _plan(
            override_requires.sdl(),
            """
        query {
          userInA {
            aName
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        userInA {
          __typename
          id
        }
      }
    },
    Flatten(path: \"userInA\") {
      Fetch(service: \"b\") {
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
    Flatten(path: \"userInA\") {
      Fetch(service: \"a\") {
        {
          ... on User {
            __typename
            name
            id
          }
        } =>
        {
          ... on User {
            aName
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
