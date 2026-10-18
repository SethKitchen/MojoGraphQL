# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/interface_object.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import simple_interface_object
from _fixtures import interface_object_nested_list
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_interface_object_field_local() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query {
          # Resolves `[NodeWithName]`
          # where `NodeWithName` is an object type with @interfaceObject.
          anotherUsers {
            id
            name
            # The `username` field is in another subgraph.
            # We do not query `username` of a specific object type,
            # we query `NodeWithName.username`.
            # The `NodeWithName` is an interface type with `@key`, so
            # we're able to perform an entity call directly to NodeWithName,
            # and fetch it.
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
          username
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
  },
},""",
    )


def test_interface_object_field_remote() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
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


def test_interface_object_field_local_object_type() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
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


def test_interface_to_object_type_locally() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
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


def test_interface_object_with_inline_fragment_resolving_remote_interface_field_simple() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query {
          anotherUsers {
            ... on User {
              username
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
          }
        }
      },
    },
    Flatten(path: \"anotherUsers.@\") {
      Fetch(service: \"b\") {
        {
          ... on User {
            __typename
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


def test_interface_object_with_inline_fragment_resolving_remote_interface_field() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
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
            ... on User {
              age
              name
            }
            name
          }
        }
      },
    },
    Flatten(path: \"anotherUsers.@\") {
      Fetch(service: \"b\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on NodeWithName {
            id
            username
          }
        }
      },
    },
  },
},""",
    )


def test_interface_field_with_inline_fragment_resolving_remote_interface_object_field() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
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
          ... on User {
            __typename
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


def test_interface_object_field_local_direct_resolution() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query {
          accounts {
            name
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      accounts {
        name
      }
    }
  },
},""",
    )


def test_interface_object_field_with_inline_fragment_requiring_typename_check() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query {
          accounts {
            ... on Admin {
              name
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
        accounts {
          __typename
          id
        }
      }
    },
    Flatten(path: \"accounts.@\") {
      Fetch(service: \"a\") {
        {
          ... on Account {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            __typename
          }
        }
      },
    },
    Flatten(path: \"accounts.@\") {
      Fetch(service: \"b\") {
        {
          ... on Admin {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            name
          }
        }
      },
    },
  },
},""",
    )


def test_interface_object_field_local_with_remote_typename() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query {
          accounts {
            name
            __typename
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        accounts {
          __typename
          name
          id
        }
      }
    },
    Flatten(path: \"accounts.@\") {
      Fetch(service: \"a\") {
        {
          ... on Account {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            __typename
          }
        }
      },
    },
  },
},""",
    )


def test_interface_object_inline_fragment_with_remote_typename() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query {
          accounts {
            ... on Admin {
              __typename
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
        accounts {
          __typename
          id
        }
      }
    },
    Flatten(path: \"accounts.@\") {
      Fetch(service: \"a\") {
        {
          ... on Account {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            __typename
            ... on Admin {
              __typename
            }
          }
        }
      },
    },
  },
},""",
    )


def test_interface_object_local_id_remote_field() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query {
          accounts {
            id
            isActive
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        accounts {
          __typename
          id
        }
      }
    },
    Flatten(path: \"accounts.@\") {
      Fetch(service: \"c\") {
        {
          ... on Account {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            isActive
          }
        }
      },
    },
  },
},""",
    )


def test_interface_object_local_id_remote_field_with_inline_fragment() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query {
          accounts {
            # NOTE
            # id is available in the interfaceObject and can be resolved as there's no type condition involved
            id
            ... on Admin {
              isActive
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
        accounts {
          __typename
          id
        }
      }
    },
    Flatten(path: \"accounts.@\") {
      Fetch(service: \"a\") {
        {
          ... on Account {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            __typename
            ... on Admin {
              isActive
            }
          }
        }
      },
    },
  },
},""",
    )


def test_interface_object_list_field_with_type_condition() raises:
    assert_equal(
        _plan(
            interface_object_nested_list.sdl(),
            """
        {
          me {
            friends {
              ... on User {
                name
              }
              credits
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"social\") {
      {
        me {
          friends {
            __typename
            id
            credits
          }
        }
      }
    },
    Flatten(path: \"me.friends.@\") {
      Fetch(service: \"users\") {
        {
          ... on Account {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            __typename
            ... on User {
              name
            }
          }
        }
      },
    },
  },
},""",
    )


def test_interface_object_type_condition_on_root_field() raises:
    assert_equal(
        _plan(
            interface_object_nested_list.sdl(),
            """
        {
          me {
            ... on User {
              name
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"social\") {
      {
        me {
          __typename
          id
        }
      }
    },
    Flatten(path: \"me\") {
      Fetch(service: \"users\") {
        {
          ... on Account {
            __typename
            id
          }
        } =>
        {
          ... on Account {
            __typename
            ... on User {
              name
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
