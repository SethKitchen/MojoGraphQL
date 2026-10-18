# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/overrides.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import simple_overrides
from _fixtures import override_type_interface
from _fixtures import simple_progressive_overrides
from _fixtures import union_progressive_override
from _fixtures import provides_progressive_override
from _fixtures import provides_union_progressive_override
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_single_simple_overrides() raises:
    assert_equal(
        _plan(
            simple_overrides.sdl(),
            """
        query {
          feed {
            createdAt
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      feed {
        createdAt
      }
    }
  },
},""",
    )


def test_two_fields_simple_overrides() raises:
    assert_equal(
        _plan(
            simple_overrides.sdl(),
            """
        query {
          aFeed {
            createdAt
          }
          bFeed {
            createdAt
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Parallel {
      Fetch(service: \"b\") {
        {
          bFeed {
            createdAt
          }
        }
      },
      Fetch(service: \"a\") {
        {
          aFeed {
            __typename
            id
          }
        }
      },
    },
    Flatten(path: \"aFeed.@\") {
      Fetch(service: \"b\") {
        {
          ... on Post {
            __typename
            id
          }
        } =>
        {
          ... on Post {
            createdAt
          }
        }
      },
    },
  },
},""",
    )


def test_override_object_field_but_interface_is_requested() raises:
    assert_equal(
        _plan(
            override_type_interface.sdl(),
            """
        query {
          feed {
            id
            createdAt
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
          id
          __typename
          ... on ImagePost {
            __typename
            id
          }
        }
      }
    },
    Flatten(path: \"feed.@|[ImagePost]\") {
      Fetch(service: \"b\") {
        {
          ... on ImagePost {
            __typename
            id
          }
        } =>
        {
          ... on ImagePost {
            createdAt
          }
        }
      },
    },
  },
},""",
    )


def test_progressive_override_percentage_test() raises:
    assert_equal(
        _plan(
            simple_progressive_overrides.sdl(),
            """
        query {
          aFeed {
            createdAt
          }
          bFeed {
            createdAt
          }
        }
        """,
            PlannerOverrideContext.from_percentage(50.0),
        ),
        """QueryPlan {
  Sequence {
    Parallel {
      Fetch(service: \"b\") {
        {
          bFeed {
            createdAt
          }
        }
      },
      Fetch(service: \"a\") {
        {
          aFeed {
            __typename
            id
          }
        }
      },
    },
    Flatten(path: \"aFeed.@\") {
      Fetch(service: \"b\") {
        {
          ... on Post {
            __typename
            id
          }
        } =>
        {
          ... on Post {
            createdAt
          }
        }
      },
    },
  },
},""",
    )
    assert_equal(
        _plan(
            simple_progressive_overrides.sdl(),
            """
        query {
          aFeed {
            createdAt
          }
          bFeed {
            createdAt
          }
        }
        """,
            PlannerOverrideContext.from_percentage(90.0),
        ),
        """QueryPlan {
  Sequence {
    Parallel {
      Fetch(service: \"b\") {
        {
          bFeed {
            __typename
            id
          }
        }
      },
      Fetch(service: \"a\") {
        {
          aFeed {
            createdAt
          }
        }
      },
    },
    Flatten(path: \"bFeed.@\") {
      Fetch(service: \"a\") {
        {
          ... on Post {
            __typename
            id
          }
        } =>
        {
          ... on Post {
            createdAt
          }
        }
      },
    },
  },
},""",
    )


def test_progressive_override_flag_test() raises:
    assert_equal(
        _plan(
            simple_progressive_overrides.sdl(),
            """
        query {
          feed {
            id
          }
        }
        """,
            PlannerOverrideContext.from_flag("feed_in_b"),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      feed {
        id
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            simple_progressive_overrides.sdl(),
            """
        query {
          feed {
            id
          }
        }
        """,
            PlannerOverrideContext.from_flag("different_flag"),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      feed {
        id
      }
    }
  },
},""",
    )


def test_progressive_override_of_union_field() raises:
    assert_equal(
        _plan(
            union_progressive_override.sdl(),
            """
        query {
          me {
            media {
              ... on Book {
                id
              }
              ... on Movie {
                id
              }
            }
          }
        }
        """,
            PlannerOverrideContext.from_flag("media_in_b"),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      me {
        media {
          __typename
          ... on Book {
            id
          }
          ... on Movie {
            id
          }
        }
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            union_progressive_override.sdl(),
            """
        query {
          me {
            media {
              ... on Book {
                id
              }
              ... on Movie {
                id
              }
            }
          }
        }
        """,
            PlannerOverrideContext.from_flag("different_flag"),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        me {
          __typename
          id
        }
      }
    },
    Flatten(path: \"me\") {
      Fetch(service: \"a\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            media {
              __typename
              ... on Book {
                id
              }
              ... on Movie {
                id
              }
            }
          }
        }
      },
    },
  },
},""",
    )


def test_progressive_override_of_provides_field() raises:
    assert_equal(
        _plan(
            provides_progressive_override.sdl(),
            """
        query {
          me {
            orders {
              sku
            }
          }
        }
        """,
            PlannerOverrideContext.from_flag("orders_in_b"),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      me {
        orders {
          sku
        }
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            provides_progressive_override.sdl(),
            """
        query {
          me {
            orders {
              sku
            }
          }
        }
        """,
            PlannerOverrideContext.from_flag("different_flag"),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        me {
          __typename
          id
        }
      }
    },
    Flatten(path: \"me\") {
      Fetch(service: \"a\") {
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
            }
          }
        }
      },
    },
  },
},""",
    )


def test_progressive_override_of_provides_union_field() raises:
    assert_equal(
        _plan(
            provides_union_progressive_override.sdl(),
            """
        query {
          me {
            media {
              ... on Book {
                title
              }
              ... on Movie {
                title
              }
            }
          }
        }
        """,
            PlannerOverrideContext.from_flag("media_in_b"),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      me {
        media {
          __typename
          ... on Book {
            title
          }
          ... on Movie {
            title
          }
        }
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            provides_union_progressive_override.sdl(),
            """
        query {
          me {
            media {
              ... on Book {
                title
              }
              ... on Movie {
                title
              }
            }
          }
        }
        """,
            PlannerOverrideContext.from_flag("different_flag"),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      {
        me {
          __typename
          id
        }
      }
    },
    Flatten(path: \"me\") {
      Fetch(service: \"a\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        {
          ... on User {
            media {
              __typename
              ... on Book {
                title
              }
              ... on Movie {
                title
              }
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
