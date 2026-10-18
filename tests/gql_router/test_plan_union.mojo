# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/union.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import union_intersection
from _fixtures import partial_union
from _fixtures import partial_union_complex
from _fixtures import union_overfetching
from _fixtures import union_list
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_union_member_resolvable() raises:
    assert_equal(
        _plan(
            union_intersection.sdl(),
            """
        query {
          media {
            ... on Book {
              title
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      media {
        __typename
        ... on Book {
          title
        }
      }
    }
  },
},""",
    )


def test_union_member_unresolvable() raises:
    assert_equal(
        _plan(
            union_intersection.sdl(),
            """
        query {
          media {
            ... on Movie {
              title
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      media {
        __typename
      }
    }
  },
},""",
    )


def test_union_member_mix() raises:
    assert_equal(
        _plan(
            union_intersection.sdl(),
            """
        query {
          media {
            __typename
            ... on Book {
              title
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      media {
        __typename
        ... on Book {
          title
        }
      }
    }
  },
},""",
    )


def test_union_member_entity_call() raises:
    assert_equal(
        _plan(
            union_intersection.sdl(),
            """
        query {
          aMedia {
            __typename
            ... on Book {
              title
              aTitle
              bTitle
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        aMedia {
          __typename
          ... on Book {
            __typename
            title
            aTitle
            id
          }
        }
      }
    },
    Flatten(path: \"aMedia|[Book]\") {
      Fetch(service: \"b\") {
        {
          ... on Book {
            __typename
            id
          }
        } =>
        {
          ... on Book {
            bTitle
          }
        }
      },
    },
  },
},""",
    )


def test_union_member_entity_call_many_local() raises:
    assert_equal(
        _plan(
            union_intersection.sdl(),
            """
        query {
          viewer {
            song {
              __typename
              ... on Song {
                title
                aTitle
              }
              ... on Movie {
                title
                bTitle
              }
              ... on Book {
                title
                aTitle
                bTitle
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        viewer {
          song {
            __typename
            ... on Song {
              title
              aTitle
            }
            ... on Book {
              __typename
              title
              aTitle
              id
            }
          }
        }
      }
    },
    Flatten(path: \"viewer.song|[Book]\") {
      Fetch(service: \"b\") {
        {
          ... on Book {
            __typename
            id
          }
        } =>
        {
          ... on Book {
            bTitle
          }
        }
      },
    },
  },
},""",
    )


def test_union_member_entity_call_many() raises:
    assert_equal(
        _plan(
            union_intersection.sdl(),
            """
        query {
          viewer {
            media {
              __typename
              ... on Song {
                title
                aTitle
              }
              ... on Movie {
                title
                bTitle
              }
              ... on Book {
                title
                aTitle
                bTitle
              }
            }
            book {
              __typename
              ... on Song {
                title
                aTitle
              }
              ... on Movie {
                title
                bTitle
              }
              ... on Book {
                title
                aTitle
                bTitle
              }
            }
            song {
              __typename
              ... on Song {
                title
                aTitle
              }
              ... on Movie {
                title
                bTitle
              }
              ... on Book {
                title
                aTitle
                bTitle
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
      Fetch(service: \"b\") {
        {
          viewer {
            media {
              ...a
            }
            book {
              ...a
            }
          }
        }
        fragment a on ViewerMedia {
          __typename
          ... on Book {
            bTitle
          }
        }
      },
      Fetch(service: \"a\") {
        {
          viewer {
            media {
              ...a
            }
            book {
              ...a
            }
            song {
              __typename
              ... on Song {
                title
                aTitle
              }
              ... on Book {
                __typename
                title
                aTitle
                id
              }
            }
          }
        }
        fragment a on ViewerMedia {
          __typename
          ... on Book {
            aTitle
            title
          }
        }
      },
    },
    Flatten(path: \"viewer.song|[Book]\") {
      Fetch(service: \"b\") {
        {
          ... on Book {
            __typename
            id
          }
        } =>
        {
          ... on Book {
            bTitle
          }
        }
      },
    },
  },
},""",
    )


def test_partial_union_member_only_in_one_subgraph() raises:
    assert_equal(
        _plan(
            partial_union.sdl(),
            """
        query {
          getResponse {
            message
            actions {
              __typename
              ... on Alpha {
                id
                value
              }
              ... on Beta {
                id
                name
                details
              }
              ... on Gamma {
                id
                label
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      getResponse {
        message
        actions {
          __typename
          ... on Alpha {
            id
            value
          }
          ... on Beta {
            id
            name
            details
          }
          ... on Gamma {
            id
            label
          }
        }
      }
    }
  },
},""",
    )


def test_partial_union_members_missing_from_other_subgraph_only() raises:
    assert_equal(
        _plan(
            partial_union.sdl(),
            """
        query {
          getResponse {
            actions {
              __typename
              ... on Beta {
                name
              }
              ... on Gamma {
                label
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      getResponse {
        actions {
          __typename
          ... on Beta {
            name
          }
          ... on Gamma {
            label
          }
        }
      }
    }
  },
},""",
    )


def test_nested_partial_union_entity_representable_a_path_keeps_only_common_members() raises:
    assert_equal(
        _plan(
            partial_union_complex.sdl(),
            """
        query {
          rootA {
            wrapper {
              actions {
                __typename
                ... on Common {
                  label
                }
                ... on OnlyA {
                  a
                }
                ... on OnlyB {
                  b
                }
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      rootA {
        wrapper {
          actions {
            __typename
            ... on Common {
              label
            }
          }
        }
      }
    }
  },
},""",
    )


def test_nested_partial_union_entity_representable_b_path_keeps_only_common_members() raises:
    assert_equal(
        _plan(
            partial_union_complex.sdl(),
            """
        query {
          rootB {
            wrapper {
              actions {
                __typename
                ... on Common {
                  label
                }
                ... on OnlyA {
                  a
                }
                ... on OnlyB {
                  b
                }
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    {
      rootB {
        wrapper {
          actions {
            __typename
            ... on Common {
              label
            }
          }
        }
      }
    }
  },
},""",
    )


def test_nested_partial_union_missing_member_from_pinned_path_falls_back_to_typename() raises:
    assert_equal(
        _plan(
            partial_union_complex.sdl(),
            """
        query {
          rootA {
            wrapper {
              actions {
                __typename
                ... on OnlyB {
                  b
                }
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      rootA {
        wrapper {
          actions {
            __typename
          }
        }
      }
    }
  },
},""",
    )


def test_nested_partial_union_ambiguous_shareable_path_keeps_only_common_members() raises:
    assert_equal(
        _plan(
            partial_union_complex.sdl(),
            """
        query {
          shared {
            wrapper {
              actions {
                __typename
                ... on Common {
                  label
                }
                ... on OnlyA {
                  a
                }
                ... on OnlyB {
                  b
                }
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      shared {
        wrapper {
          actions {
            __typename
            ... on Common {
              label
            }
          }
        }
      }
    }
  },
},""",
    )


def test_nested_partial_union_uses_members_from_subgraph_reached_by_entity_move() raises:
    assert_equal(
        _plan(
            partial_union_complex.sdl(),
            """
        query {
          rootA {
            bWrapper {
              actions {
                __typename
                ... on Common {
                  label
                }
                ... on OnlyA {
                  a
                }
                ... on OnlyB {
                  b
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
    Fetch(service: \"a\") {
      {
        rootA {
          __typename
          id
        }
      }
    },
    Flatten(path: \"rootA\") {
      Fetch(service: \"b\") {
        {
          ... on Container {
            __typename
            id
          }
        } =>
        {
          ... on Container {
            bWrapper {
              actions {
                __typename
                ... on Common {
                  label
                }
                ... on OnlyB {
                  b
                }
              }
            }
          }
        }
      },
    },
  },
},""",
    )


def test_union_overfetching_test() raises:
    assert_equal(
        _plan(
            union_overfetching.sdl(),
            """
        query {
          review {
            ... on AnonymousReview {
              product {
                b
              }
            }
            ... on UserReview {
              product {
                c
                d
              }
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      {
        review {
          __typename
          ... on AnonymousReview {
            product {
              ...a
            }
          }
          ... on UserReview {
            product {
              ...a
            }
          }
        }
      }
      fragment a on Product {
        __typename
        id
      }
    },
    Parallel {
      Flatten(path: \"review|[UserReview].product\") {
        Fetch(service: \"d\") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              d
            }
          }
        },
      },
      Flatten(path: \"review|[UserReview].product\") {
        Fetch(service: \"c\") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              c
            }
          }
        },
      },
      Flatten(path: \"review|[AnonymousReview].product\") {
        Fetch(service: \"b\") {
          {
            ... on Product {
              __typename
              id
            }
          } =>
          {
            ... on Product {
              b
            }
          }
        },
      },
    },
  },
},""",
    )


def test_union_list_test() raises:
    assert_equal(
        _plan(
            union_list.sdl(),
            """
        {
          orders {
            ... on OrdersPageConnections {
              items {
                id
                items {
                  ... on PaperBook {
                    product {
                      id
                      name
                      slug
                    }
                  }
                  ... on DigitalBook {
                    product {
                      id
                      name
                      slug
                    }
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
    Fetch(service: \"a\") {
      {
        orders {
          __typename
          ... on OrdersPageConnections {
            items {
              id
              items {
                __typename
                ... on PaperBook {
                  product {
                    ...a
                  }
                }
                ... on DigitalBook {
                  product {
                    ...a
                  }
                }
              }
            }
          }
        }
      }
      fragment a on Product {
        __typename
        id
      }
    },
    Flatten(path: \"orders|[OrdersPageConnections].items.@.items.@.product\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            id
          }
        } =>
        {
          ... on Product {
            name
            slug
          }
        }
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
