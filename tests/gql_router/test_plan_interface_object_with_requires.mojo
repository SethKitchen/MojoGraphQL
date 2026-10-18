# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/interface_object_with_requires.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import interface_object_with_requires
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_interface_object_requiring_interface_fields() raises:
    assert_equal(
        _plan(
            interface_object_with_requires.sdl(),
            """
        query {
          anotherUsers {
            id
            name
            username
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        anotherUsers {
          __typename
          id
        }
      }
    },
    Flatten(path: \"anotherUsers.@\") {
      Fetch(service: \"a\") {
        {
          ... on NodeWithName {
            __typename
            id
          }
        } =>
        {
          ... on NodeWithName {
            name
          }
        }
      },
    },
    Flatten(path: \"anotherUsers.@\") {
      Fetch(service: \"b\") {
        {
          ... on NodeWithName {
            __typename
            name
            id
          }
        } =>
        {
          ... on NodeWithName {
            username
          }
        }
      },
    },
  },
},""",
    )


def test_interface_field_from_remote_graph_with_requires() raises:
    assert_equal(
        _plan(
            interface_object_with_requires.sdl(),
            """
        query {
          users {
            id
            name
            username
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        users {
          __typename
          id
          name
        }
      }
    },
    Flatten(path: \"users.@\") {
      Fetch(service: \"b\") {
        {
          ... on NodeWithName {
            __typename
            name
            id
          }
        } =>
        {
          ... on NodeWithName {
            username
          }
        }
      },
    },
  },
},""",
    )


def test_inline_fragment_on_interface_object_for_remote_type_field() raises:
    assert_equal(
        _plan(
            interface_object_with_requires.sdl(),
            """
        query {
          anotherUsers {
            ... on User {
              age
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
        anotherUsers {
          __typename
          id
        }
      }
    },
    Flatten(path: \"anotherUsers.@\") {
      Fetch(service: \"a\") {
        {
          ... on NodeWithName {
            __typename
            id
          }
        } =>
        {
          ... on NodeWithName {
            __typename
            ... on User {
              age
            }
          }
        }
      },
    },
  },
},""",
    )


def test_inline_fragment_on_local_type_behind_interface() raises:
    assert_equal(
        _plan(
            interface_object_with_requires.sdl(),
            """
        query {
          users {
            ... on User {
              age
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      users {
        __typename
        ... on User {
          age
        }
      }
    }
  },
},""",
    )


def test_interface_object_field_with_requires_and_inline_fragment() raises:
    assert_equal(
        _plan(
            interface_object_with_requires.sdl(),
            """
        query {
          anotherUsers {
            ... on User {
              age
              id
              name
              username
            }
            id
            name
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        anotherUsers {
          __typename
          id
        }
      }
    },
    Flatten(path: \"anotherUsers.@\") {
      Fetch(service: \"a\") {
        {
          ... on NodeWithName {
            __typename
            id
          }
        } =>
        {
          ... on NodeWithName {
            __typename
            name
            ... on User {
              age
              name
            }
          }
        }
      },
    },
    Flatten(path: \"anotherUsers.@\") {
      Fetch(service: \"b\") {
        {
          ... on NodeWithName {
            __typename
            name
            id
          }
        } =>
        {
          ... on NodeWithName {
            username
            id
          }
        }
      },
    },
  },
},""",
    )


def test_interface_field_from_remote_graph_with_requires_and_inline_fragment() raises:
    assert_equal(
        _plan(
            interface_object_with_requires.sdl(),
            """
        query {
          users {
            ... on User {
              age
              id
              name
              username
            }
            id
            name
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        users {
          __typename
          ... on User {
            __typename
            age
            id
            name
          }
          id
          name
        }
      }
    },
    Flatten(path: \"users.@|[User]\") {
      Fetch(service: \"b\") {
        {
          ... on NodeWithName {
            __typename
            name
            id
          }
        } =>
        {
          ... on NodeWithName {
            username
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
