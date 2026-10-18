# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan snapshot tests.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/alias.rs`. Each test plans an
operation and compares the plan with the upstream `Display` snapshot.
"""

from _fixtures import mismatch_mix
from _fixtures import requires_alias_entity_interface
from _fixtures import requires_alias_entity_calls
from _fixtures import override_requires
from _fixtures import adversarial_shape_mismatch
from _fixtures import circular_reference_interface
from _fixtures import testing
from _fixtures import child_type_mismatch
from _fixtures import mismatch_mix_enum_scalar
from _plan_harness import _plan
from gql_router.graph import PlannerOverrideContext
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
)


def test_client_alias_named_internal_type_mismatch() raises:
    assert_false(
        "_internal_qp_alias_0: strField"
        in _plan(
            mismatch_mix.sdl(),
            """
        query {
          i {
            _internal_qp_alias_0: __typename
            ... on TypeA { strField }
            ... on TypeB { strField }
          }
        }
        """,
            PlannerOverrideContext.default(),
        )
    )


def test_client_alias_named_internal_requires() raises:
    assert_equal(
        _plan(
            requires_alias_entity_interface.sdl(),
            """
        {
          things {
            _internal_qp_alias_0: id
            price(currency: \"GBP\")
            ... on Cat { eur }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"shop\") {
      {
        things {
          _internal_qp_alias_0: id
          __typename
          ... on Cat {
            __typename
            price(currency: \"GBP\")
            id
            _internal_qp_alias_1: price(currency: \"EUR\")
          }
          ... on Dog {
            price(currency: \"GBP\")
          }
        }
      }
    },
    Flatten(path: \"things.@|[Cat]\") {
      Fetch(service: \"pricing\") {
        {
          ... on Cat {
            __typename
            price: _internal_qp_alias_1
            id
          }
        } =>
        {
          ... on Cat {
            eur
          }
        }
      },
    },
  },
},""",
    )


def test_client_alias_named_like_a_key_field() raises:
    assert_equal(
        _plan(
            requires_alias_entity_calls.sdl(),
            """{ things { id: price(currency: \"USD\") } }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"catalog\") {
      {
        things {
          __typename
          _internal_qp_alias_0: id
        }
      }
    },
    Flatten(path: \"things.@\") {
      Fetch(service: \"shop\") {
        {
          ... on Thing {
            __typename
            id: _internal_qp_alias_0
          }
        } =>
        {
          ... on Thing {
            id: price(currency: \"USD\")
          }
        }
      },
    },
  },
},""",
    )


def test_client_alias_named_like_a_key_field_under_a_condition() raises:
    assert_equal(
        _plan(
            override_requires.sdl(),
            """query ($x: Boolean!) { userInA { id: name aName @include(if: $x) } }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"a\") {
      query ($x:Boolean!) {
        userInA {
          __typename
          _internal_qp_alias_0: id
          ... on User @include(if: $x) {
            __typename
            _internal_qp_alias_0: id
          }
        }
      }
    },
    Flatten(path: \"userInA\") {
      Fetch(service: \"b\") {
        {
          ... on User {
            __typename
            id: _internal_qp_alias_0
          }
        } =>
        ($x:Boolean!) {
          ... on User {
            ... on User @include(if: $x) {
              name
            }
            id: name
          }
        }
      },
    },
    Include(if: $x) {
      Flatten(path: \"userInA\") {
        Fetch(service: \"a\") {
          {
            ... on User {
              __typename
              name
              id: _internal_qp_alias_0
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
},""",
    )


def test_composite_list_shape_mismatch_gets_wire_key() raises:
    assert_equal(
        _plan(
            adversarial_shape_mismatch.sdl(),
            """
        query {
          things {
            ... on Box { items { name } }
            ... on Bag { items { name } }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      things {
        __typename
        ... on Box {
          items {
            ...a
          }
        }
        ... on Bag {
          _internal_qp_alias_0: items {
            ...a
          }
        }
      }
    }
    fragment a on Item {
      name
    }
  },
},""",
    )


def test_circular_reference_interface() raises:
    assert_equal(
        _plan(
            circular_reference_interface.sdl(),
            """
        query {
          product {
            __typename
            samePriceProduct {
              __typename
              ... on Book {
                id
              }
              samePriceProduct {
                __typename
                ... on Book {
                  id
                }
              }
            }
            ... on Book {
              __typename
              id
              price
              samePriceProduct {
                id
                price
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
        product {
          __typename
          samePriceProduct {
            __typename
            ... on Book {
              ...a
            }
            samePriceProduct {
              __typename
              ... on Book {
                ...a
              }
            }
          }
          ... on Book {
            __typename
            id
            samePriceProduct {
              id
              price
            }
          }
        }
      }
      fragment a on Book {
        id
      }
    },
    Flatten(path: \"product|[Book]\") {
      Fetch(service: \"b\") {
        {
          ... on Book {
            __typename
            id
          }
        } =>
        {
          ... on Book {
            price
          }
        }
      },
    },
  },
},""",
    )


def test_conflict_list_type_in_interface() raises:
    assert_equal(
        _plan(
            mismatch_mix.sdl(),
            """
        query {
            i {
                ... on TypeA {
                    strField # String
                }
                ... on TypeB {
                    strField # [String]
                }
            }
        }
""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      i {
        __typename
        ... on TypeA {
          strField
        }
        ... on TypeB {
          _internal_qp_alias_0: strField
        }
      }
    }
  },
},""",
    )


def test_multiple_mismtaches_same_level() raises:
    assert_equal(
        _plan(
            mismatch_mix.sdl(),
            """
        query {
            i {
                ... on TypeA {
                    strField # String
                    strField2 # String
                }
                ... on TypeB {
                    strField # [String]
                    strField2 # [String]
                }
            }
        }
""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      i {
        __typename
        ... on TypeA {
          strField
          strField2
        }
        ... on TypeB {
          _internal_qp_alias_0: strField
          _internal_qp_alias_1: strField2
        }
      }
    }
  },
},""",
    )


def test_aliasing_both_parent_and_leaf() raises:
    assert_equal(
        _plan(
            testing.sdl(),
            """
            query {
              allProducts: products {
                price {
                  pricing: amount
                  currency
                }
                available: isAvailable
              }
            }""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Sequence {
    Fetch(service: \"store\") {
      {
        allProducts: products {
          __typename
          id
        }
      }
    },
    Flatten(path: \"allProducts\") {
      Fetch(service: \"info\") {
        {
          ... on Product {
            __typename
            id
          }
        } =>
        {
          ... on Product {
            available: isAvailable
            uuid
          }
        }
      },
    },
    Flatten(path: \"allProducts\") {
      Fetch(service: \"cost\") {
        {
          ... on Product {
            __typename
            uuid
          }
        } =>
        {
          ... on Product {
            price {
              pricing: amount
              currency
            }
          }
        }
      },
    },
  },
},""",
    )


def test_simple_mismatch_between_union_fields() raises:
    assert_equal(
        _plan(
            child_type_mismatch.sdl(),
            """
        query {
          users {
            id
            name
          }
          accounts {
            ... on User {
              id
              name
            }
            ... on Admin {
              id
              name
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
          accounts {
            __typename
            ... on User {
              id
              name
            }
            ... on Admin {
              _internal_qp_alias_0: id
              name
            }
          }
        }
      },
      Fetch(service: \"a\") {
        {
          users {
            __typename
            id
          }
        }
      },
    },
    Flatten(path: \"users.@\") {
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
},""",
    )


def test_nested_internal_mismatch_between_fields() raises:
    assert_equal(
        _plan(
            child_type_mismatch.sdl(),
            """
        query NestedInternalAlias {
          users {
            id
            name
          }
          accounts {
            ... on User {
              id
              name
              similarAccounts {
                ... on User {
                  id
                  name
                }
                ... on Admin {
                  id
                  name
                }
              }
            }
            ... on Admin {
              id
              name
              similarAccounts {
                ... on User {
                  id
                  name
                }
                ... on Admin {
                  id
                  name
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
      Fetch(service: \"b\") {
        {
          accounts {
            __typename
            ... on User {
              id
              name
              similarAccounts {
                ...a
              }
            }
            ... on Admin {
              _internal_qp_alias_0: id
              name
              similarAccounts {
                ...a
              }
            }
          }
        }
        fragment a on Account {
          __typename
          ... on User {
            id
            name
          }
          ... on Admin {
            _internal_qp_alias_0: id
            name
          }
        }
      },
      Fetch(service: \"a\") {
        {
          users {
            __typename
            id
          }
        }
      },
    },
    Flatten(path: \"users.@\") {
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
},""",
    )


def test_deeply_nested_internal_mismatch_between_fields() raises:
    assert_equal(
        _plan(
            child_type_mismatch.sdl(),
            """
        query DeeplyNestedInternalAlias {
          users {
            id
            name
          }
          accounts {
            ... on User {
              id
              name
              similarAccounts {
                ... on User {
                  id
                  name
                  similarAccounts {
                    ... on User {
                      id
                      name
                    }
                    ... on Admin {
                      id
                      name
                    }
                  }
                }
                ... on Admin {
                  id
                  name
                  similarAccounts {
                    ... on User {
                      id
                      name
                    }
                    ... on Admin {
                      id
                      name
                    }
                  }
                }
              }
            }
            ... on Admin {
              id
              name
              similarAccounts {
                ... on User {
                  id
                  name
                  similarAccounts {
                    ... on User {
                      id
                      name
                    }
                    ... on Admin {
                      id
                      name
                    }
                  }
                }
                ... on Admin {
                  id
                  name
                  similarAccounts {
                    ... on User {
                      id
                      name
                    }
                    ... on Admin {
                      id
                      name
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
    Parallel {
      Fetch(service: \"b\") {
        {
          accounts {
            __typename
            ... on User {
              id
              name
              similarAccounts {
                ...a
              }
            }
            ... on Admin {
              _internal_qp_alias_0: id
              name
              similarAccounts {
                ...a
              }
            }
          }
        }
        fragment a on Account {
          __typename
          ... on User {
            id
            name
            similarAccounts {
              ...b
            }
          }
          ... on Admin {
            _internal_qp_alias_0: id
            name
            similarAccounts {
              ...b
            }
          }
        }
        fragment b on Account {
          __typename
          ... on User {
            id
            name
          }
          ... on Admin {
            _internal_qp_alias_0: id
            name
          }
        }
      },
      Fetch(service: \"a\") {
        {
          users {
            __typename
            id
          }
        }
      },
    },
    Flatten(path: \"users.@\") {
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
},""",
    )


def test_deeply_nested_no_conflicts() raises:
    assert_equal(
        _plan(
            child_type_mismatch.sdl(),
            """
        query DeeplyNested {
          accounts {
            ... on User {
              name
              similarAccounts {
                ... on User {
                  name
                  similarAccounts {
                    ... on User {
                      name
                    }
                    ... on Admin {
                      name
                    }
                  }
                }
                ... on Admin {
                  name
                  similarAccounts {
                    ... on User {
                      name
                    }
                    ... on Admin {
                      name
                    }
                  }
                }
              }
            }
            ... on Admin {
              name
              similarAccounts {
                ... on User {
                  name
                  similarAccounts {
                    ... on User {
                      name
                    }
                    ... on Admin {
                      name
                    }
                  }
                }
                ... on Admin {
                  name
                  similarAccounts {
                    ... on User {
                      name
                    }
                    ... on Admin {
                      name
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
  Fetch(service: \"b\") {
    {
      accounts {
        __typename
        ... on User {
          name
          similarAccounts {
            ...a
          }
        }
        ... on Admin {
          name
          similarAccounts {
            ...a
          }
        }
      }
    }
    fragment a on Account {
      __typename
      ... on User {
        name
        similarAccounts {
          ...b
        }
      }
      ... on Admin {
        name
        similarAccounts {
          ...b
        }
      }
    }
    fragment b on Account {
      __typename
      ... on User {
        name
      }
      ... on Admin {
        name
      }
    }
  },
},""",
    )


def test_multi_enum_mismatch_across_fragments() raises:
    assert_equal(
        _plan(
            mismatch_mix_enum_scalar.sdl(),
            """
           query GetAllTypesWithConflictingField {
                getTypes {
                    id
                    identifier
                    code
                    metadata {
                        value
                        unit
                    }
                    ... on TypeA {
                        field # maps to EnumA
                    }
                    ... on TypeB {
                        typeBField: field # maps to EnumB
                    }
                    ... on TypeC {
                        typeCField: field # maps to EnumC
                    }
                    ... on TypeD {
                        typeDField: field # maps to EnumD
                    }
                }
            }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"service\") {
    {
      getTypes {
        id
        identifier
        code
        metadata {
          value
          unit
        }
        __typename
        ... on TypeA {
          field
        }
        ... on TypeB {
          typeBField: field
        }
        ... on TypeC {
          typeCField: field
        }
        ... on TypeD {
          typeDField: field
        }
      }
    }
  },
},""",
    )


def test_multi_scalar_mismatch_across_fragments() raises:
    assert_equal(
        _plan(
            mismatch_mix_enum_scalar.sdl(),
            """
           query GetAllTypesWithConflictingField {
                getTypes {
                    id
                    identifier
                    code
                    metadata {
                        value
                        unit
                    }
                    ... on TypeA {
                        isScalar # is a Int
                    }
                    ... on TypeB {
                        scalarB: isScalar # is a Boolean
                    }
                    ... on TypeC {
                        scalarC: isScalar # is a Float
                    }
                    ... on TypeD {
                        scalarD: isScalar # is a Int
                    }
                }
            }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"service\") {
    {
      getTypes {
        id
        identifier
        code
        metadata {
          value
          unit
        }
        __typename
        ... on TypeA {
          isScalar
        }
        ... on TypeB {
          scalarB: isScalar
        }
        ... on TypeC {
          scalarC: isScalar
        }
        ... on TypeD {
          scalarD: isScalar
        }
      }
    }
  },
},""",
    )


def test_conflict_list_type_in_interface_preserves_client_alias() raises:
    assert_equal(
        _plan(
            mismatch_mix.sdl(),
            """
        query {
            i {
                ... on TypeA {
                    clientStrFieldA: strField # [String]
                }
                ... on TypeB {
                    clientStrFieldB: strField # String
                }
            }
        }
""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      i {
        __typename
        ... on TypeA {
          clientStrFieldA: strField
        }
        ... on TypeB {
          clientStrFieldB: strField
        }
      }
    }
  },
},""",
    )


def test_conflict_list_type_in_interface_with_distinct_response_keys() raises:
    assert_equal(
        _plan(
            mismatch_mix.sdl(),
            """
        query {
            i {
                ... on TypeA {
                    typeAField: strField # [String]
                }
                ... on TypeB {
                    typeBField: strField # String
                }
            }
        }
""",
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"a\") {
    {
      i {
        __typename
        ... on TypeA {
          typeAField: strField
        }
        ... on TypeB {
          typeBField: strField
        }
      }
    }
  },
},""",
    )


def test_mismatch_aliases_unique_across_sibling_fragments() raises:
    assert_equal(
        _plan(
            mismatch_mix_enum_scalar.sdl(),
            """
        query {
          getTypes {
            ... on TypeA { isScalar }
            ... on TypeB { isScalar }
            ... on TypeC { isScalar }
          }
        }
        """,
            PlannerOverrideContext.default(),
        ),
        """QueryPlan {
  Fetch(service: \"service\") {
    {
      getTypes {
        __typename
        ... on TypeA {
          isScalar
        }
        ... on TypeB {
          _internal_qp_alias_0: isScalar
        }
        ... on TypeC {
          _internal_qp_alias_1: isScalar
        }
      }
    }
  },
},""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
