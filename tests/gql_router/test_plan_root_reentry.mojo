# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/root_reentry.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import root_reentry
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_mutation_referencing_query() raises:
    assert_equal(
        _plan(
            root_reentry.sdl(),
            """
        mutation {
          doSomething {
            ok
            query {
              healthCheck
              user(id: 1) {
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
    Fetch(service: \"two\") {
      mutation {
        doSomething {
          ok
          query {
            healthCheck
            __typename
          }
        }
      }
    },
    Flatten(path: \"doSomething.query\") {
      Fetch(service: \"one\") {
        {
          user(id: 1) {
            name
          }
        }
      },
    },
  },
},""",
    )


def test_mutation_referencing_query_with_alias() raises:
    assert_equal(
        _plan(
            root_reentry.sdl(),
            """
        mutation {
          doSomething {
            ok
            info: query {
              healthCheck
              user(id: 1) {
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
    Fetch(service: \"two\") {
      mutation {
        doSomething {
          ok
          info: query {
            healthCheck
            __typename
          }
        }
      }
    },
    Flatten(path: \"doSomething.info\") {
      Fetch(service: \"one\") {
        {
          user(id: 1) {
            name
          }
        }
      },
    },
  },
},""",
    )


def test_mutation_referencing_query_with_condition() raises:
    assert_equal(
        _plan(
            root_reentry.sdl(),
            """
        mutation($withQuery: Boolean!) {
          doSomething {
            ok
            query @include(if: $withQuery) {
              healthCheck
              user(id: 1) {
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
    Fetch(service: \"two\") {
      mutation ($withQuery:Boolean!) {
        doSomething {
          ok
          query @include(if: $withQuery) {
            healthCheck
            __typename
          }
        }
      }
    },
    Include(if: $withQuery) {
      Flatten(path: \"doSomething.query\") {
        Fetch(service: \"one\") {
          {
            user(id: 1) {
              name
            }
          }
        },
      },
    },
  },
},""",
    )


def test_query_referencing_query() raises:
    assert_equal(
        _plan(
            root_reentry.sdl(),
            """
        query {
          healthCheck
          user(id: 1) {
            name
          }
          system {
            healthCheck
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Parallel {
    Fetch(service: \"one\") {
      {
        user(id: 1) {
          name
        }
      }
    },
    Fetch(service: \"two\") {
      {
        healthCheck
        system {
          healthCheck
        }
      }
    },
  },
},""",
    )


def test_query_referencing_query_cross_subgraphs() raises:
    assert_equal(
        _plan(
            root_reentry.sdl(),
            """
        query {
          healthCheck
          user(id: 1) {
            name
          }
          system {
            healthCheck
            user(id: 1) {
              name
            }
            system {
              healthCheck
              user(id: 1) {
                name
              }
              system {
                healthCheck
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Parallel {
    Fetch(service: \"one\") {
      {
        user(id: 1) {
          ...a
        }
        system {
          user(id: 1) {
            ...a
          }
          system {
            user(id: 1) {
              ...a
            }
          }
        }
      }
      fragment a on User {
        name
      }
    },
    Fetch(service: \"two\") {
      {
        healthCheck
        system {
          healthCheck
          system {
            healthCheck
            system {
              healthCheck
            }
          }
        }
      }
    },
  },
},""",
    )


def test_query_referncing_through_inner() raises:
    assert_equal(
        _plan(
            root_reentry.sdl(),
            """
        query {
          user(id: 1) {
            id
            name
          }
          inner {
            toQuery {
              user(id: 1) {
                id
                name
              }
            }
            toMutation {
              doSomething {
                ok
                query {
                  healthCheck
                  user(id: 1) {
                    name
                  }
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
    Parallel {
      Fetch(service: \"two\") {
        {
          inner {
            toMutation {
              doSomething {
                ok
                query {
                  healthCheck
                  __typename
                }
              }
            }
          }
        }
      },
      Fetch(service: \"one\") {
        {
          user(id: 1) {
            ...a
          }
          inner {
            toQuery {
              user(id: 1) {
                ...a
              }
            }
          }
        }
        fragment a on User {
          id
          name
        }
      },
    },
    Flatten(path: \"inner.toMutation.doSomething.query\") {
      Fetch(service: \"one\") {
        {
          user(id: 1) {
            name
          }
        }
      },
    },
  },
},""",
    )


def test_mutation_then_full_reentry_jump() raises:
    assert_equal(
        _plan(
            root_reentry.sdl(),
            """
      mutation {
        doSomething { # two
          query { # jump to one
            user(id: 1) { # one
              name # one
            }
          }
        }
      }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"two\") {
      mutation {
        doSomething {
          query {
            __typename
          }
        }
      }
    },
    Flatten(path: \"doSomething.query\") {
      Fetch(service: \"one\") {
        {
          user(id: 1) {
            name
          }
        }
      },
    },
  },
},""",
    )


def test_mutation_then_mixed_query() raises:
    assert_equal(
        _plan(
            root_reentry.sdl(),
            """
      mutation {
        doSomething { # two
          ok # two
          query { # one+two
            healthCheck # two
            user(id: 1) { # one
              name # one
            }
          }
        }
      }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"two\") {
      mutation {
        doSomething {
          ok
          query {
            healthCheck
            __typename
          }
        }
      }
    },
    Flatten(path: \"doSomething.query\") {
      Fetch(service: \"one\") {
        {
          user(id: 1) {
            name
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
