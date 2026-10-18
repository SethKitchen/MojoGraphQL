# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/provides.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import simple_provides
from _fixtures import nested_provides
from _fixtures import provides_on_union
from _fixtures import provides_on_interface
from _fixtures import provides_typename
from _fixtures import provides_typename_nested
from _fixtures import provides_typename_list
from _fixtures import provides_typename_interface
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_simple_provides() raises:
    assert_equal(
        _plan(
            simple_provides.sdl(),
            """
        query {
          products {
            reviews {
              author {
                username
              }
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          __typename
          upc
        }
      }
    },
    Flatten(path: \"products.@\") {
      Fetch(service: \"reviews\") {
        {
          ... on Product {
            __typename
            upc
          }
        } =>
        {
          ... on Product {
            reviews {
              author {
                username
              }
            }
          }
        }
      },
    },
  },
},""",
    )


def test_nested_provides() raises:
    assert_equal(
        _plan(
            nested_provides.sdl(),
            """
        query {
          products {
            id
            categories {
              id
              name
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"category\") {
    {
      products {
        id
        categories {
          id
          name
        }
      }
    }
  },
},""",
    )


def test_provides_on_union() raises:
    assert_equal(
        _plan(
            provides_on_union.sdl(),
            """
        query {
          media {
            ... on Book {
              id
              title
            }
            ... on Movie {
              id
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      media {
        __typename
        ... on Book {
          title
          id
        }
        ... on Movie {
          id
        }
      }
    }
  },
},""",
    )
    assert_equal(
        _plan(
            provides_on_union.sdl(),
            """
        query {
          media {
            ... on Book {
              id
              title
            }
            ... on Movie {
              id
              title
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
        media {
          __typename
          ... on Book {
            title
            id
          }
          ... on Movie {
            __typename
            id
          }
        }
      }
    },
    Flatten(path: \"media.@|[Movie]\") {
      Fetch(service: \"c\") {
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


def test_provides_on_interface_1_test() raises:
    assert_equal(
        _plan(
            provides_on_interface.sdl(),
            """
          query {
            media {
              id
              animals {
                id
                name
              }
            }
          }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      media {
        __typename
        ... on Book {
          animals {
            __typename
            id
            name
          }
        }
        id
      }
    }
  },
},""",
    )


def test_provides_fieldset_with_typename() raises:
    assert_equal(
        _plan(
            provides_typename.sdl(),
            """
        query {
          holder {
            item {
              __typename
              label
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"provider\") {
    {
      holder {
        item {
          __typename
          label
        }
      }
    }
  },
},""",
    )


def test_provides_fieldset_with_nested_typename() raises:
    assert_equal(
        _plan(
            provides_typename_nested.sdl(),
            """
        query {
          holder {
            item {
              __typename
              nested {
                __typename
                label
              }
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"provider\") {
    {
      holder {
        item {
          __typename
          nested {
            __typename
            label
          }
        }
      }
    }
  },
},""",
    )


def test_provides_fieldset_with_typename_on_list() raises:
    assert_equal(
        _plan(
            provides_typename_list.sdl(),
            """
        query {
          holder {
            items {
              __typename
              label
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"provider\") {
    {
      holder {
        items {
          __typename
          label
        }
      }
    }
  },
},""",
    )


def test_provides_fieldset_with_typename_on_interface() raises:
    assert_equal(
        _plan(
            provides_typename_interface.sdl(),
            """
        query {
          book {
            animals {
              __typename
              ... on Dog {
                __typename
                name
              }
            }
          }
        }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      book {
        animals {
          __typename
          ... on Dog {
            __typename
            name
          }
        }
      }
    }
  },
},""",
    )


def test_provides_on_interface_2_test() raises:
    assert_equal(
        _plan(
            provides_on_interface.sdl(),
            """
          query {
            media {
              id
              animals {
                id
                name
                ... on Cat {
                  age
                }
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
        media {
          __typename
          ... on Book {
            animals {
              __typename
              ... on Cat {
                __typename
                id
                name
              }
              ... on Dog {
                id
                name
              }
            }
          }
          id
        }
      }
    },
    Flatten(path: \"media|[Book].animals.@|[Cat]\") {
      Fetch(service: \"c\") {
        {
          ... on Cat {
            __typename
            id
          }
        } =>
        {
          ... on Cat {
            age
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
