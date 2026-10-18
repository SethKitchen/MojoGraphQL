# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/include_skip.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import simple_include_skip
from _fixtures import simple_interface_object
from _fixtures import union_overfetching
from _fixtures import products_example
from _fixtures import abstract_types
from _fixtures import override_requires
from _fixtures import bench_supergraph
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_include_basic_test() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            price
            neverCalledInclude @include(if: $bool)
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @include(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Include(if: $bool) {
      Sequence {
        Flatten(path: \"product\") {
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
        Flatten(path: \"product\") {
          Fetch(service: \"c\") {
            {
              ... on Product {
                __typename
                isExpensive
                id
              }
            } =>
            {
              ... on Product {
                neverCalledInclude
              }
            }
          },
        },
      },
    },
  },
},""",
    )


def test_include_fragment_test() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            price
            ... on Product @include(if: $bool) {
              neverCalledInclude
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean) {
        product {
          price
          ... on Product @include(if: $bool) {
            __typename
            id
            price
          }
        }
      }
    },
    Include(if: $bool) {
      Sequence {
        Flatten(path: \"product|[Product]\") {
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
        Flatten(path: \"product|[Product]\") {
          Fetch(service: \"c\") {
            {
              ... on Product {
                __typename
                isExpensive
                id
              }
            } =>
            {
              ... on Product {
                neverCalledInclude
              }
            }
          },
        },
      },
    },
  },
},""",
    )


def test_skip_basic_test() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean = false) {
          product {
            price
            skip @skip(if: $bool)
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean=false) {
        product {
          __typename
          price
          id
          ... on Product @skip(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Skip(if: $bool) {
      Sequence {
        Flatten(path: \"product\") {
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
        Flatten(path: \"product\") {
          Fetch(service: \"c\") {
            {
              ... on Product {
                __typename
                isExpensive
                id
              }
            } =>
            {
              ... on Product {
                skip
              }
            }
          },
        },
      },
    },
  },
},""",
    )


def test_skip_and_include_field_condition_test() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($skip: Boolean = false, $include: Boolean = true) {
          product {
            price
            neverCalledInclude @skip(if: $skip) @include(if: $include)
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($include:Boolean=true,$skip:Boolean=false) {
        product {
          __typename
          price
          id
          ... on Product @skip(if: $skip) @include(if: $include) {
            price
            __typename
            id
          }
        }
      }
    },
    Skip(if: $skip) {
      Include(if: $include) {
        Sequence {
          Flatten(path: \"product\") {
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
          Flatten(path: \"product\") {
            Fetch(service: \"c\") {
              {
                ... on Product {
                  __typename
                  isExpensive
                  id
                }
              } =>
              {
                ... on Product {
                  neverCalledInclude
                }
              }
            },
          },
        },
      },
    },
  },
},""",
    )


def test_skip_and_include_fragment_condition_test() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($skip: Boolean = false, $include: Boolean = true) {
          product {
            price
            ... on Product @skip(if: $skip) @include(if: $include) {
              neverCalledInclude
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($include:Boolean=true,$skip:Boolean=false) {
        product {
          price
          ... on Product @skip(if: $skip) @include(if: $include) {
            __typename
            id
            price
          }
        }
      }
    },
    Skip(if: $skip) {
      Include(if: $include) {
        Sequence {
          Flatten(path: \"product|[Product]\") {
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
          Flatten(path: \"product|[Product]\") {
            Fetch(service: \"c\") {
              {
                ... on Product {
                  __typename
                  isExpensive
                  id
                }
              } =>
              {
                ... on Product {
                  neverCalledInclude
                }
              }
            },
          },
        },
      },
    },
  },
},""",
    )


def test_include_at_root_fetch_test() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            id
            price @include(if: $bool)
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($bool:Boolean) {
      product {
        id
        price @include(if: $bool)
      }
    }
  },
},""",
    )


def test_include_fragment_at_root_fetch_test() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            id
            ... on Product @include(if: $bool) {
              price
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($bool:Boolean) {
      product {
        id
        ... on Product @include(if: $bool) {
          price
        }
      }
    }
  },
},""",
    )


def test_include_interface_at_root_fetch_test() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query ($bool: Boolean) {
          accounts {
            id
            name @include(if: $bool)
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    query ($bool:Boolean) {
      accounts {
        id
        name @include(if: $bool)
      }
    }
  },
},""",
    )


def test_include_interface_fragment_at_root_fetch_test() raises:
    assert_equal(
        _plan(
            simple_interface_object.sdl(),
            """
        query ($bool: Boolean) {
          accounts {
            id
            ... on Account @include(if: $bool) {
              name
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"b\") {
    query ($bool:Boolean) {
      accounts {
        id
        ... on Account @include(if: $bool) {
          name
        }
      }
    }
  },
},""",
    )


def test_include_union_fragment_at_root_fetch_test() raises:
    assert_equal(
        _plan(
            union_overfetching.sdl(),
            """
        query ($bool: Boolean) {
          review {
            ... on UserReview @include(if: $bool) {
              product {
                id
              }
            }
            ... on AnonymousReview @include(if: $bool) {
              product {
                id
              }
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    query ($bool:Boolean) {
      review {
        __typename
        ... on UserReview {
          product @include(if: $bool) {
            ...a
          }
        }
        ... on AnonymousReview {
          product @include(if: $bool) {
            ...a
          }
        }
      }
    }
    fragment a on Product {
      id
    }
  },
},""",
    )


def test_plans_query_with_nested_directive_only_inline_fragments() raises:
    _ = _plan(
        products_example.sdl(),
        """
        fragment User on User {
          id
          username
          name
        }

        fragment Review on Review {
          id
          body
        }

        fragment Product on Product {
          inStock
          name
          price
          shippingEstimate
          upc
          weight
        }

        query TestQuery($user: Boolean = true, $product: Boolean = true, $reviews: Boolean = true) {
          users {
            ...User
            ... @include(if: $reviews) {
              reviews {
                ...Review
                product {
                  ...Product
                  reviews {
                    ...Review
                    ... @include(if: $user) {
                      author {
                        ...User
                        reviews {
                          ...Review
                          ... @include(if: $product) {
                            product {
                              ...Product
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          ... @include(if: $product) {
            topProducts {
              ...Product
              reviews {
                ...Review
                author {
                  ...User
                  ... @include(if: $reviews) {
                    reviews {
                      ...Review
                      product {
                        ...Product
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """,
        PlannerOverrideContext.default(),
    )


def test_plans_query_with_field_level_include_skip_conditions() raises:
    _ = _plan(
        products_example.sdl(),
        """
        fragment User on User {
          id
          username
          name
        }

        fragment Review on Review {
          id
          body
        }

        fragment Product on Product {
          inStock
          name
          price
          shippingEstimate
          upc
          weight
        }

        query TestQuery($user: Boolean = true, $product: Boolean = true, $reviews: Boolean = true) {
          users {
            ...User
            reviews @include(if: $reviews) {
              ...Review
              product {
                ...Product
                reviews {
                  ...Review
                  author @include(if: $user) {
                    ...User
                    reviews {
                      ...Review
                      product @include(if: $product) {
                        ...Product
                      }
                    }
                  }
                }
              }
            }
          }
          topProducts @include(if: $product) {
            ...Product
            reviews {
              ...Review
              author {
                ...User
                reviews @include(if: $reviews) {
                  ...Review
                  product {
                    ...Product
                  }
                }
              }
            }
          }
        }
        """,
        PlannerOverrideContext.default(),
    )


def test_qp_include_field_level() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            price # graph A
            name @include(if: $bool) # graph B
            isCheap # graph B
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @include(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        ($bool:Boolean) {
          ... on Product {
            isCheap
            ... on Product @include(if: $bool) {
              name
            }
          }
        }
      },
    },
  },
},""",
    )


def test_qp_include_field_level_unconditional_before_conditional() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            price # graph A
            isCheap # graph B - requires `price`
            name @include(if: $bool) # graph B - requires `price`
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @include(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        ($bool:Boolean) {
          ... on Product {
            ... on Product @include(if: $bool) {
              name
            }
            isCheap
          }
        }
      },
    },
  },
},""",
    )


def test_qp_include_field_level_all_merged_fields_conditional() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            price # graph A
            name @include(if: $bool) # graph B - requires `price`
            isCheap @include(if: $bool) # graph B - requires `price`
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @include(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Include(if: $bool) {
      Flatten(path: \"product\") {
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
              isCheap
              name
            }
          }
        },
      },
    },
  },
},""",
    )


def test_qp_skip_field_level() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            price # graph A
            name @skip(if: $bool) # graph B - requires `price`
            isCheap # graph B - requires `price`
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @skip(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        ($bool:Boolean) {
          ... on Product {
            isCheap
            ... on Product @skip(if: $bool) {
              name
            }
          }
        }
      },
    },
  },
},""",
    )


def test_qp_skip_field_level_unconditional_before_conditional() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            price # graph A
            isCheap # graph B - requires `price`
            name @skip(if: $bool) # graph B - requires `price`
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @skip(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        ($bool:Boolean) {
          ... on Product {
            ... on Product @skip(if: $bool) {
              name
            }
            isCheap
          }
        }
      },
    },
  },
},""",
    )


def test_qp_skip_field_level_all_merged_fields_conditional() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($bool: Boolean) {
          product {
            price # graph A
            name @skip(if: $bool) # graph B - requires `price`
            isCheap @skip(if: $bool) # graph B - requires `price`
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($bool:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @skip(if: $bool) {
            price
            __typename
            id
          }
        }
      }
    },
    Skip(if: $bool) {
      Flatten(path: \"product\") {
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
              isCheap
              name
            }
          }
        },
      },
    },
  },
},""",
    )


def test_qp_skip_and_include_field_level_all_merged_fields_conditional() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($skip: Boolean, $include: Boolean) {
          product {
            price # graph A
            name @skip(if: $skip) @include(if: $include) # graph B - requires `price`
            isCheap @skip(if: $skip) @include(if: $include) # graph B - requires `price`
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($include:Boolean,$skip:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @skip(if: $skip) @include(if: $include) {
            price
            __typename
            id
          }
        }
      }
    },
    Skip(if: $skip) {
      Include(if: $include) {
        Flatten(path: \"product\") {
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
                isCheap
                name
              }
            }
          },
        },
      },
    },
  },
},""",
    )


def test_qp_mixed_include_skip_field_level_keeps_conditions_scoped() raises:
    assert_equal(
        _plan(
            simple_include_skip.sdl(),
            """
        query ($include: Boolean, $skip: Boolean) {
          product {
            price # graph A
            name @include(if: $include) # graph B - requires `price`
            isCheap @skip(if: $skip) # graph B - requires `price`
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($include:Boolean,$skip:Boolean) {
        product {
          __typename
          price
          id
          ... on Product @include(if: $include) {
            ...a
          }
          ... on Product @skip(if: $skip) {
            ...a
          }
        }
      }
      fragment a on Product {
        price
        __typename
        id
      }
    },
    Flatten(path: \"product\") {
      Fetch(service: \"b\") {
        {
          ... on Product {
            __typename
            price
            id
          }
        } =>
        ($include:Boolean,$skip:Boolean) {
          ... on Product {
            ... on Product @skip(if: $skip) {
              isCheap
            }
            ... on Product @include(if: $include) {
              name
            }
          }
        }
      },
    },
  },
},""",
    )


def test_qp_nested_include_skip_conditions_in_complex_products_query() raises:
    assert_equal(
        _plan(
            products_example.sdl(),
            """
        query ($reviews: Boolean, $skipAuthor: Boolean, $nestedReviews: Boolean, $product: Boolean) {
          topProducts {
            name
            reviews @include(if: $reviews) {
              body
              author @skip(if: $skipAuthor) {
                name
                reviews @include(if: $nestedReviews) {
                  body
                  product @include(if: $product) {
                    name
                    shippingEstimate
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
    Fetch(service: \"products\") {
      {
        topProducts {
          __typename
          name
          upc
        }
      }
    },
    Include(if: $reviews) {
      Flatten(path: \"topProducts.@\") {
        Fetch(service: \"reviews\") {
          {
            ... on Product {
              __typename
              upc
            }
          } =>
          ($nestedReviews:Boolean,$product:Boolean,$skipAuthor:Boolean) {
            ... on Product {
              reviews {
                body
                author @skip(if: $skipAuthor) {
                  __typename
                  id
                  reviews @include(if: $nestedReviews) {
                    body
                    product @include(if: $product) {
                      __typename
                      upc
                    }
                  }
                }
              }
            }
          }
        },
      },
    },
    Parallel {
      Skip(if: $skipAuthor) {
        Include(if: $nestedReviews) {
          Include(if: $product) {
            Flatten(path: \"topProducts.@.reviews.@.author.reviews.@.product\") {
              Fetch(service: \"products\") {
                {
                  ... on Product {
                    __typename
                    upc
                  }
                } =>
                {
                  ... on Product {
                    price
                    weight
                    name
                  }
                }
              },
            },
          },
        },
      },
      Skip(if: $skipAuthor) {
        Flatten(path: \"topProducts.@.reviews.@.author\") {
          Fetch(service: \"accounts\") {
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
      },
    },
    Skip(if: $skipAuthor) {
      Include(if: $nestedReviews) {
        Include(if: $product) {
          Flatten(path: \"topProducts.@.reviews.@.author.reviews.@.product\") {
            Fetch(service: \"inventory\") {
              {
                ... on Product {
                  __typename
                  price
                  weight
                  upc
                }
              } =>
              {
                ... on Product {
                  shippingEstimate
                }
              }
            },
          },
        },
      },
    },
  },
},""",
    )


def test_qp_abstract_interface_mixed_conditions_stay_scoped() raises:
    assert_equal(
        _plan(
            abstract_types.sdl(),
            """
        query ($showReviews: Boolean, $hideSku: Boolean) {
          products {
            id
            sku @skip(if: $hideSku)
            reviewsCount @include(if: $showReviews)
            ... on Book @include(if: $showReviews) {
              title
            }
            ... on Magazine @skip(if: $hideSku) {
              title
            }
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      query ($hideSku:Boolean) {
        products {
          id
          __typename
          sku @skip(if: $hideSku)
        }
      }
    },
    Parallel {
      Include(if: $showReviews) {
        Flatten(path: \"products.@\") {
          Fetch(service: \"reviews\") {
            {
              ... on Book {
                __typename
                id
              }
              ... on Magazine {
                __typename
                id
              }
            } =>
            {
              ... on Book {
                reviewsCount
              }
              ... on Magazine {
                reviewsCount
              }
            }
          },
        },
      },
      Include(if: $showReviews) {
        Flatten(path: \"products.@|[Book]\") {
          Fetch(service: \"books\") {
            {
              ... on Book {
                __typename
                id
              }
            } =>
            {
              ... on Book {
                title
              }
            }
          },
        },
      },
      Skip(if: $hideSku) {
        Flatten(path: \"products.@|[Magazine]\") {
          Fetch(service: \"magazines\") {
            {
              ... on Magazine {
                __typename
                id
              }
            } =>
            {
              ... on Magazine {
                title
              }
            }
          },
        },
      },
    },
  },
},""",
    )


def test_qp_abstract_interface_shared_condition_can_skip_remote_fetch() raises:
    assert_equal(
        _plan(
            abstract_types.sdl(),
            """
        query ($showReviews: Boolean) {
          products {
            id
            reviewsCount @include(if: $showReviews)
            reviewsScore @include(if: $showReviews)
          }
        }
      """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"products\") {
      {
        products {
          id
          __typename
        }
      }
    },
    Include(if: $showReviews) {
      Flatten(path: \"products.@\") {
        Fetch(service: \"reviews\") {
          {
            ... on Book {
              __typename
              id
            }
            ... on Magazine {
              __typename
              id
            }
          } =>
          {
            ... on Book {
              reviewsCount
              reviewsScore
            }
            ... on Magazine {
              reviewsCount
              reviewsScore
            }
          }
        },
      },
    },
  },
},""",
    )


def test_qp_abstract_union_member_conditions_stay_scoped() raises:
    assert_equal(
        _plan(
            union_overfetching.sdl(),
            """
        query ($showUserReview: Boolean, $hideAnonymousReview: Boolean) {
          review {
            ... on UserReview @include(if: $showUserReview) {
              product {
                b
              }
            }
            ... on AnonymousReview @skip(if: $hideAnonymousReview) {
              product {
                c
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
      query ($hideAnonymousReview:Boolean,$showUserReview:Boolean) {
        review {
          __typename
          ... on UserReview {
            product @include(if: $showUserReview) {
              ...a
            }
          }
          ... on AnonymousReview {
            product @skip(if: $hideAnonymousReview) {
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
      Skip(if: $hideAnonymousReview) {
        Flatten(path: \"review|[AnonymousReview].product\") {
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
      },
      Include(if: $showUserReview) {
        Flatten(path: \"review|[UserReview].product\") {
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
  },
},""",
    )


def test_conditional_root_fragment_survives_merges() raises:
    assert_equal(
        _plan(
            override_requires.sdl(),
            """
        query ($x: Boolean!) {
          ... on Query @include(if: $x) {
            userInB {
              aName
              cName
            }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"b\") {
      query ($x:Boolean!) {
        ... on Query @include(if: $x) {
          userInB {
            __typename
            id
            ... on User @include(if: $x) {
              name
              __typename
              id
            }
          }
        }
      }
    },
    Parallel {
      Include(if: $x) {
        Flatten(path: \"|[Query].userInB\") {
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
      Include(if: $x) {
        Flatten(path: \"|[Query].userInB\") {
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
    },
  },
},""",
    )


def test_entity_call_under_nested_conditional_fragments() raises:
    assert_equal(
        _plan(
            override_requires.sdl(),
            """
        query ($a: Boolean!, $b: Boolean!) {
          userInA {
            id
            ... on User @include(if: $a) {
              ... on User @include(if: $b) {
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
    Fetch(service: \"a\") {
      query ($a:Boolean!,$b:Boolean!) {
        userInA {
          id
          ... on User @include(if: $a) {
            ... on User @include(if: $b) {
              __typename
              id
            }
          }
        }
      }
    },
    Include(if: $a) {
      Include(if: $b) {
        Flatten(path: \"userInA|[User]|[User]\") {
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
      },
    },
  },
},""",
    )


def test_batched_entity_calls_keep_the_condition_of_their_fragment() raises:
    assert_equal(
        _plan(
            bench_supergraph.sdl(),
            """
        query ($a: Boolean!, $b: Boolean!) {
          users {
            reviews {
              product {
                upc
                ... on Product @include(if: $a) {
                  notes
                  price @include(if: $b)
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
    Fetch(service: \"accounts\") {
      {
        users {
          __typename
          id
        }
      }
    },
    Flatten(path: \"users.@\") {
      Fetch(service: \"reviews\") {
        {
          ... on User {
            __typename
            id
          }
        } =>
        ($a:Boolean!) {
          ... on User {
            reviews {
              product {
                upc
                ... on Product @include(if: $a) {
                  __typename
                  upc
                }
              }
            }
          }
        }
      },
    },
    Include(if: $a) {
      Flatten(path: \"users.@.reviews.@.product|[Product]\") {
        Fetch(service: \"products\") {
          {
            ... on Product {
              __typename
              upc
            }
          } =>
          ($a:Boolean!,$b:Boolean!) {
            ... on Product {
              ... on Product @include(if: $b) {
                price
              }
              ... on Product @include(if: $a) {
                notes
              }
            }
          }
        },
      },
    },
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
