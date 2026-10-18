# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for operation normalization.

Ports the tests of Hive Router `1a29df9`
`bin/router/src/query_planner/ast/normalization/mod.rs`. Upstream prints
the result with `graphql-parser`; these tests print it with
`gql_language.printer`, which has the same layout, except one thing:
`graphql-parser` prints `query($v: T)` for an anonymous operation with
variables, and `graphql-js` prints `query ($v: T)`.
"""

from _fixtures import (
    abstract_types,
    corrupted_supergraph_node_id,
    issue_939,
    nested_fragments,
    requires_with_fragments,
    simple_interface_object,
)
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_router.ast import NONE
from gql_router.federation_spec import OperationKind
from gql_router.normalize import (
    RootTypes,
    _drop_duplicates_set,
    normalize_field_set,
    normalize_operation,
    selection_set_from_text,
)
from gql_router.store import Store
from gql_router.supergraph_state import new_supergraph_state
from std.testing import TestSuite, assert_equal, assert_raises


def _normalized(
    schema: String, query: String, operation_name: Optional[String] = None
) raises -> String:
    var store = Store()
    var state = new_supergraph_state(store, parse(schema))
    var operation = normalize_operation(
        store, state, parse(query), operation_name
    )
    return print_ast(parse(operation.text(store)))


def test_introspection() raises:
    var schema = """
        type Query {
          words(len: Int, sep: String): String
        }
    """
    assert_equal(
        _normalized(
            schema,
            """
            query {
              a: __typename
              words:words
              __typename
              __schema {
                __typename
              }
            }
            """,
        ),
        """{
  a: __typename
  words
  __typename
  __schema {
    __typename
  }
}""",
    )


comptime _ACCOUNT_PROFILE_SCHEMA = """
    interface Node {
      id: ID!
    }

    type Profile {
      name: String
    }

    type Account implements Node {
      id: ID!
      profile: Profile
    }

    type Query {
      node: Node
    }
"""


def test_empty_composite_under_inline_fragment_gets_skipped_typename_sentinel() raises:
    assert_equal(
        _normalized(
            _ACCOUNT_PROFILE_SCHEMA,
            """
            query {
              node {
                ... on Account {
                  profile {
                    name @include(if: false)
                  }
                }
              }
            }
            """,
        ),
        """{
  node {
    ... on Account {
      profile {
        __typename
      }
    }
  }
}""",
    )


def test_explicit_typename_wins_over_skipped_typename() raises:
    assert_equal(
        _normalized(
            _ACCOUNT_PROFILE_SCHEMA,
            """
            query {
              node {
                ... on Account {
                  profile {
                    name @include(if: false)
                    __typename
                  }
                }
              }
            }
            """,
        ),
        """{
  node {
    ... on Account {
      profile {
        __typename
      }
    }
  }
}""",
    )


comptime _WORDS_SCHEMA = """
    type Query {
      words(len: Int, sep: String): String
    }
"""


def test_normalize_fields() raises:
    assert_equal(
        _normalized(
            _WORDS_SCHEMA,
            """
            query {
              words: words(sep: ",")
              foo: words(sep: ".", len: 10)
            }
            """,
        ),
        """{
  words(sep: ",")
  foo: words(len: 10, sep: ".")
}""",
    )


def test_drop_unused_operations() raises:
    assert_equal(
        _normalized(
            """
            type Query {
              words: String
            }
            """,
            """
            query foo {
              words
            }

            query bar {
              words
            }
            """,
            String("foo"),
        ),
        """query foo {
  words
}""",
    )


def test_drop_duplicated_fields() raises:
    assert_equal(
        _normalized(
            _WORDS_SCHEMA,
            """
            query {
              words
              c: words(len: 1)
              b: words
              a: words
              words
              c: words(len: 1)
            }
            """,
        ),
        """{
  words
  c: words(len: 1)
  b: words
  a: words
}""",
    )


comptime _PRODUCTS_SCHEMA = """
    interface Node
      @join__type(graph: A)
      @join__type(graph: B)
    {
      id: ID!
    }


    interface WithWarranty
      @join__type(graph: A)
      @join__type(graph: B)
    {
      warranty: Int
    }

    type Oven implements Node & WithWarranty
      @join__implements(graph: B, interface: "Node")
      @join__implements(graph: B, interface: "WithWarranty")
      @join__type(graph: A, key: "id")
      @join__type(graph: B, key: "id") {
      id: ID!
      warranty: Int
      o1: String
      o2: String
      o3: String
      toaster: Toaster
    }

    union Product
      @join__type(graph: A)
      @join__unionMember(graph: A, member: "Oven")
      @join__unionMember(graph: A, member: "Toaster")
     = Oven | Toaster

     type Query
       @join__type(graph: A)
       @join__type(graph: B)
     {
       products: [Product] @join__field(graph: A)
       node(id: ID!): Node @join__field(graph: A)
       nodes: [Node] @join__field(graph: A)
       toasters: [Toaster] @join__field(graph: A)
     }

     type Toaster implements Node & WithWarranty
       @join__implements(graph: A, interface: "Node")
       @join__implements(graph: A, interface: "WithWarranty")
       @join__type(graph: A, key: "id")
     {
      id: ID!
      warranty: Int
      t1: String
      t2: String
      t3: String
      oven: Oven
    }
"""


def test_inline_fragment_spreads() raises:
    assert_equal(
        _normalized(
            _PRODUCTS_SCHEMA,
            """
            query {
              products {
                ...ToasterFragment
                ... on Toaster {
                  t1
                  t2
                  oven {
                    warranty
                    o1
                    o2
                  }
                }
              }
            }
            fragment ToasterFragment on Toaster {
              t1
              oven {
                o1
                ... on Oven {
                  ... on Oven {
                    o3
                  }
                }
                ...OvenFragment
                ...OvenFragment

              }
            }
            fragment OvenFragment on Oven {
              toaster {
                warranty
                t3
              }
              o3
            }
            """,
        ),
        """{
  products {
    ... on Toaster {
      t1
      oven {
        o1
        o3
        toaster {
          warranty
          t3
        }
        warranty
        o2
      }
      t2
    }
  }
}""",
    )
    assert_equal(
        _normalized(
            _PRODUCTS_SCHEMA,
            """
            query {
              products {
                ... on Node {
                  id
                }
                ... on WithWarranty {
                  warranty
                }
              }
            }
            """,
        ),
        """{
  products {
    ... on Oven {
      id
      warranty
    }
    ... on Toaster {
      id
      warranty
    }
  }
}""",
    )
    assert_equal(
        _normalized(
            _PRODUCTS_SCHEMA,
            """
            query {
              toasters {
                ...ToasterFragment
                ...NodeFragment
              }
            }

            fragment ToasterFragment on Toaster {
              id
            }

            fragment NodeFragment on Node {
              id
              __typename
            }
            """,
        ),
        """{
  toasters {
    id
    ... on Toaster {
      id
      __typename
    }
  }
}""",
    )


def test_normalize_fields_args() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(_WORDS_SCHEMA))
    var operation = normalize_operation(
        store,
        state,
        parse(
            """
            query {
              one: words(sep: ".", len: 10)
              two: words(len: 10, sep: ".")
            }
            """
        ),
    )
    var items = store.children(operation.selection_set)
    assert_equal(len(items), 2)
    assert_equal(store.items[items[0]].args, store.items[items[1]].args)
    assert_equal(
        print_ast(parse(operation.text(store))),
        """{
  one: words(len: 10, sep: ".")
  two: words(len: 10, sep: ".")
}""",
    )


def test_mutation() raises:
    assert_equal(
        _normalized(
            """
            type Mutation {
              createProduct(name: String!): Product
            }

            type Query {
              products: [Product]
            }

            type Product {
              id: ID!
              name: String
            }
            """,
            """
            mutation NewProduct($name: String!) {
              createProduct(name: $name) {
                id
                name
              }
            }
            """,
        ),
        """mutation NewProduct($name: String!) {
  createProduct(name: $name) {
    id
    name
  }
}""",
    )


def test_type_expansion() raises:
    assert_equal(
        _normalized(
            corrupted_supergraph_node_id.sdl(),
            """
            query nodeid($id: ID!) {
              node(id: $id) {
                id
              }
            }
            """,
        ),
        """query nodeid($id: ID!) {
  node(id: $id) {
    ... on Account {
      id
    }
    ... on Chat {
      id
    }
  }
}""",
    )
    assert_equal(
        _normalized(
            corrupted_supergraph_node_id.sdl(),
            """
            query nodeid($id: ID!) {
              node(id: $id) {
                ... on Chat {
                  id
                }
              }
            }
            """,
        ),
        """query nodeid($id: ID!) {
  node(id: $id) {
    ... on Chat {
      id
    }
  }
}""",
    )


def test_type_expansion_2() raises:
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query {
              userFromA {
                profile {
                  displayName
                  ... on Account {
                    accountType
                  }
                }
              }
            }
            """,
        ),
        """{
  userFromA {
    profile {
      displayName
      ... on AdminAccount {
        accountType
      }
      ... on GuestAccount {
        accountType
      }
    }
  }
}""",
    )
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query {
              userFromA {
                profile {
                  displayName
                  ... on Account {
                    accountType
                    ... on AdminAccount {
                      adminLevel
                    }
                    ... on GuestAccount {
                      guestToken
                    }
                  }
                }
              }
            }
            """,
        ),
        """{
  userFromA {
    profile {
      displayName
      ... on AdminAccount {
        accountType
        adminLevel
      }
      ... on GuestAccount {
        accountType
        guestToken
      }
    }
  }
}""",
    )


def test_type_expansion_3() raises:
    assert_equal(
        _normalized(
            abstract_types.sdl(),
            """
            {
              products {
                id
                reviews { id }
              }
            }
            """,
        ),
        """{
  products {
    id
    ... on Book {
      reviews {
        id
      }
    }
    ... on Magazine {
      reviews {
        id
      }
    }
  }
}""",
    )


def test_type_expansion_4() raises:
    assert_equal(
        _normalized(
            simple_interface_object.sdl(),
            """
            query {
              anotherUsers {
                id
                name
                username
              }
            }
            """,
        ),
        """{
  anotherUsers {
    id
    name
    username
  }
}""",
    )


def test_static_skip_include_test() raises:
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query {
              userFromA @include(if: true) {
                profile {
                  displayName @include(if: false)
                  ... on Account @skip(if: false) {
                    accountType
                  }
                }
              }
            }
            """,
        ),
        """{
  userFromA {
    profile {
      ... on AdminAccount {
        accountType
      }
      ... on GuestAccount {
        accountType
      }
    }
  }
}""",
    )


def test_static_skip_include_test_2() raises:
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query {
              userFromA {
                profile {
                  displayName @include(if: false)
                  ... on Account {
                    accountType
                    ... on AdminAccount @skip(if: true) {
                      adminLevel
                    }
                    ... on GuestAccount {
                      guestToken
                    }
                  }
                }
              }
            }
            """,
        ),
        """{
  userFromA {
    profile {
      ... on AdminAccount {
        accountType
      }
      ... on GuestAccount {
        accountType
        guestToken
      }
    }
  }
}""",
    )


def test_type_expansion_skip_include_test_1() raises:
    # graphql-js layout: `query ($guest: ...)`, not `query($guest: ...)`.
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query($guest: Boolean!) {
              userFromA {
                profile {
                  displayName @include(if: $guest)
                  ... on Account @skip(if: $guest) {
                    accountType
                    ... on AdminAccount @skip(if: $guest) {
                      adminLevel
                    }
                    ... on GuestAccount {
                      guestToken
                    }
                  }
                }
              }
            }
            """,
        ),
        """query ($guest: Boolean!) {
  userFromA {
    profile {
      displayName @include(if: $guest)
      ... on AdminAccount @skip(if: $guest) {
        accountType
        adminLevel
      }
      ... on GuestAccount @skip(if: $guest) {
        accountType
        guestToken
      }
    }
  }
}""",
    )


def test_type_expansion_skip_include_test_2() raises:
    # graphql-js layout: `query ($guest: ...)`, not `query($guest: ...)`.
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query($guest: Boolean!) {
              userFromA {
                profile {
                  displayName @include(if: $guest)
                  ... on Account {
                    accountType
                    ... on AdminAccount @skip(if: $guest) {
                      adminLevel
                    }
                    ... on GuestAccount {
                      guestToken
                    }
                  }
                }
              }
            }
            """,
        ),
        """query ($guest: Boolean!) {
  userFromA {
    profile {
      displayName @include(if: $guest)
      ... on AdminAccount {
        accountType
      }
      ... on AdminAccount @skip(if: $guest) {
        adminLevel
      }
      ... on GuestAccount {
        accountType
        guestToken
      }
    }
  }
}""",
    )


def test_type_expansion_skip_include_test_3() raises:
    # graphql-js layout: `query ($guest: ...)`, not `query($guest: ...)`.
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query($guest: Boolean!) {
              userFromA {
                profile {
                  displayName @include(if: $guest)
                  ... on Account {
                    accountType @skip(if: $guest)
                    ... on AdminAccount @skip(if: $guest) {
                      adminLevel
                    }
                    ... on GuestAccount {
                      guestToken
                    }
                  }
                }
              }
            }
            """,
        ),
        """query ($guest: Boolean!) {
  userFromA {
    profile {
      displayName @include(if: $guest)
      ... on AdminAccount {
        accountType @skip(if: $guest)
      }
      ... on AdminAccount @skip(if: $guest) {
        adminLevel
      }
      ... on GuestAccount {
        accountType @skip(if: $guest)
        guestToken
      }
    }
  }
}""",
    )


def test_directive_only_inline_fragment_on_abstract_parent_include() raises:
    # graphql-js layout: `query ($guest: ...)`, not `query($guest: ...)`.
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query($guest: Boolean!) {
              userFromA {
                profile {
                  ... @include(if: $guest) {
                    displayName
                    ... on Account {
                      accountType
                    }
                  }
                }
              }
            }
            """,
        ),
        """query ($guest: Boolean!) {
  userFromA {
    profile {
      ... on AdminAccount @include(if: $guest) {
        displayName
        accountType
      }
      ... on GuestAccount @include(if: $guest) {
        displayName
        accountType
      }
    }
  }
}""",
    )


def test_directive_only_inline_fragment_on_abstract_parent_skip() raises:
    # graphql-js layout: `query ($guest: ...)`, not `query($guest: ...)`.
    assert_equal(
        _normalized(
            requires_with_fragments.sdl(),
            """
            query($guest: Boolean!) {
              userFromA {
                profile {
                  ... @skip(if: $guest) {
                    displayName
                    ... on Account {
                      accountType
                    }
                  }
                }
              }
            }
            """,
        ),
        """query ($guest: Boolean!) {
  userFromA {
    profile {
      ... on AdminAccount @skip(if: $guest) {
        displayName
        accountType
      }
      ... on GuestAccount @skip(if: $guest) {
        displayName
        accountType
      }
    }
  }
}""",
    )


comptime _TSHIRT_EXPECTED = """{
  results {
    __typename
    ... on MultipleColor {
      id
      name
      colorOptions {
        id
        color
      }
    }
    ... on SingleColor {
      id
      name
      colorOption {
        id
        color
      }
    }
  }
}"""


def test_nested_fragment_spreads_1() raises:
    assert_equal(
        _normalized(
            nested_fragments.sdl(),
            """
            query {
              results {
                __typename
                ...on Tshirt {
                  ...TshirtResult
                }
              }
            }

            fragment TshirtResult on Tshirt {
              id
              name
              ...on MultipleColor {
                colorOptions {
                  ...ColorDetails
                }
              }
              ...on SingleColor {
                colorOption {
                  ...ColorDetails
                }
              }
            }

            fragment ColorDetails on TshirtColorOption {
              id
              color
            }
            """,
        ),
        _TSHIRT_EXPECTED,
    )


def test_inlining_nested_fragments_with_same_type() raises:
    assert_equal(
        _normalized(
            nested_fragments.sdl(),
            """
            query {
              results {
                __typename
                ... on Tshirt {
                  ...TshirtResult1
                }
              }
            }

            fragment TshirtResult1 on Tshirt {
              ...TshirtResult2
            }

            fragment TshirtResult2 on Tshirt {
              id
              name
              ...on MultipleColor {
                colorOptions {
                  ...ColorDetails
                }
              }
              ...on SingleColor {
                colorOption {
                  ...ColorDetails
                }
              }
            }

            fragment ColorDetails on TshirtColorOption {
              id
              color
            }
            """,
        ),
        _TSHIRT_EXPECTED,
    )


def test_fragment_spread_on_interface_across_field_boundary_preserves_type_context() raises:
    assert_equal(
        _normalized(
            issue_939.sdl(),
            """
            query SingleNode($id: ID!) {
              node(id: $id) {
                ... on MyNode {
                  content {
                    ... on ITextContent {
                      fragments {
                        contentNode {
                          content {
                            ...ITextContentPreview
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            fragment ITextContentPreview on ITextContent {
              id
            }
            """,
        ),
        """query SingleNode($id: ID!) {
  node(id: $id) {
    ... on MyNode {
      content {
        ... on TextContent {
          fragments {
            contentNode {
              content {
                ... on TextContent {
                  id
                }
                ... on TextGroupContent {
                  id
                }
              }
            }
          }
        }
        ... on TextGroupContent {
          fragments {
            contentNode {
              content {
                ... on TextContent {
                  id
                }
                ... on TextGroupContent {
                  id
                }
              }
            }
          }
        }
      }
    }
  }
}""",
    )


comptime _ACCOUNT_SCHEMA = """
    type Query {
      account: Account
    }

    type Account {
      id: ID!
      name: String!
    }
"""


def test_same_type_fragment_spread_directives_are_preserved() raises:
    # graphql-js layout: `query ($cond: ...)`, not `query($cond: ...)`.
    assert_equal(
        _normalized(
            """
            type Query {
              account: Account
            }

            interface Node {
              id: ID!
            }

            type Account implements Node {
              id: ID!
              name: String!
            }
            """,
            """
            query($cond: Boolean!) {
              account {
                ...AccountFields @include(if: $cond)
              }
            }

            fragment AccountFields on Account {
              name
            }
            """,
        ),
        """query ($cond: Boolean!) {
  account {
    ... on Account @include(if: $cond) {
      name
    }
  }
}""",
    )


def test_same_type_fragment_spread_skip_is_preserved() raises:
    # graphql-js layout: `query ($cond: ...)`, not `query($cond: ...)`.
    assert_equal(
        _normalized(
            _ACCOUNT_SCHEMA,
            """
            query($cond: Boolean!) {
              account {
                ...AccountFields @skip(if: $cond)
              }
            }

            fragment AccountFields on Account {
              name
            }
            """,
        ),
        """query ($cond: Boolean!) {
  account {
    ... on Account @skip(if: $cond) {
      name
    }
  }
}""",
    )


def test_same_type_fragment_spread_include_and_skip_are_preserved() raises:
    # graphql-js layout: `query ($include: ...)`, not `query($include: ...)`.
    assert_equal(
        _normalized(
            _ACCOUNT_SCHEMA,
            """
            query($include: Boolean!, $skip: Boolean!) {
              account {
                ...AccountFields @include(if: $include) @skip(if: $skip)
              }
            }

            fragment AccountFields on Account {
              name
            }
            """,
        ),
        """query ($include: Boolean!, $skip: Boolean!) {
  account {
    ... on Account @skip(if: $skip) @include(if: $include) {
      name
    }
  }
}""",
    )


def test_outer_same_type_fragment_spread_directive_is_preserved_through_nested_spreads() raises:
    # graphql-js layout: `query ($cond: ...)`, not `query($cond: ...)`.
    assert_equal(
        _normalized(
            _ACCOUNT_SCHEMA,
            """
            query($cond: Boolean!) {
              account {
                ...AccountFields1 @include(if: $cond)
              }
            }

            fragment AccountFields1 on Account {
              ...AccountFields2
            }

            fragment AccountFields2 on Account {
              name
            }
            """,
        ),
        """query ($cond: Boolean!) {
  account {
    ... on Account @include(if: $cond) {
      name
    }
  }
}""",
    )


def test_inner_same_type_fragment_spread_directive_is_preserved_through_nested_spreads() raises:
    # graphql-js layout: `query ($cond: ...)`, not `query($cond: ...)`.
    assert_equal(
        _normalized(
            _ACCOUNT_SCHEMA,
            """
            query($cond: Boolean!) {
              account {
                ...AccountFields1
              }
            }

            fragment AccountFields1 on Account {
              ...AccountFields2 @include(if: $cond)
            }

            fragment AccountFields2 on Account {
              name
            }
            """,
        ),
        """query ($cond: Boolean!) {
  account {
    ... on Account @include(if: $cond) {
      name
    }
  }
}""",
    )


def test_field_boundary_fragment_spread_include_is_preserved() raises:
    assert_equal(
        _normalized(
            issue_939.sdl(),
            """
            query SingleNode($cond: Boolean!, $id: ID!) {
              node(id: $id) {
                ... on MyNode {
                  content {
                    ... on ITextContent {
                      fragments {
                        contentNode {
                          content {
                            ...ITextContentPreview @include(if: $cond)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            fragment ITextContentPreview on ITextContent {
              id
            }
            """,
        ),
        """query SingleNode($cond: Boolean!, $id: ID!) {
  node(id: $id) {
    ... on MyNode {
      content {
        ... on TextContent {
          fragments {
            contentNode {
              content {
                ... on TextContent @include(if: $cond) {
                  id
                }
                ... on TextGroupContent @include(if: $cond) {
                  id
                }
              }
            }
          }
        }
        ... on TextGroupContent {
          fragments {
            contentNode {
              content {
                ... on TextContent @include(if: $cond) {
                  id
                }
                ... on TextGroupContent @include(if: $cond) {
                  id
                }
              }
            }
          }
        }
      }
    }
  }
}""",
    )


def test_reusable_fragment_with_mixed_include_conditions_stays_separate() raises:
    # graphql-js layout: `query ($first: ...)`, not `query($first: ...)`.
    assert_equal(
        _normalized(
            _ACCOUNT_SCHEMA,
            """
            query($first: Boolean!, $second: Boolean!) {
              account {
                ...AccountFields @include(if: $first)
                ...AccountFields @include(if: $second)
              }
            }

            fragment AccountFields on Account {
              name
            }
            """,
        ),
        """query ($first: Boolean!, $second: Boolean!) {
  account {
    ... on Account @include(if: $first) {
      name
    }
    ... on Account @include(if: $second) {
      name
    }
  }
}""",
    )


def test_deeply_nested_mixed_abstract_fragments_flatten_to_concrete_object() raises:
    assert_equal(
        _normalized(
            corrupted_supergraph_node_id.sdl(),
            """
            query {
              account(id: "a1") {
                ...NodeFields
              }
            }

            fragment NodeFields on Node {
              ... on Node {
                ... {
                  ... on Node {
                    id
                  }
                  ... on Account {
                    username
                  }
                }
              }
            }
            """,
        ),
        """{
  account(id: "a1") {
    id
    username
  }
}""",
    )


def test_deeply_nested_abstract_fragments_with_conflicting_include_directives_stay_scoped() raises:
    # graphql-js layout: `query ($outer: ...)`, not `query($outer: ...)`.
    assert_equal(
        _normalized(
            corrupted_supergraph_node_id.sdl(),
            """
            query($outer: Boolean!, $inner: Boolean!) {
              account(id: "a1") {
                ... on Node @include(if: $outer) {
                  ... on Node @include(if: $inner) {
                    id
                  }
                  ... on Account {
                    username
                  }
                }
              }
            }
            """,
        ),
        """query ($outer: Boolean!, $inner: Boolean!) {
  account(id: "a1") {
    ... on Account @include(if: $outer) {
      ... on Account @include(if: $inner) {
        id
      }
      username
    }
  }
}""",
    )


def test_deeply_nested_abstract_fragments_with_skip_and_include_preserve_both_conditions() raises:
    # graphql-js layout: `query ($skip: ...)`, not `query($skip: ...)`.
    assert_equal(
        _normalized(
            corrupted_supergraph_node_id.sdl(),
            """
            query($skip: Boolean!, $include: Boolean!) {
              account(id: "a1") {
                ... on Node @skip(if: $skip) {
                  ... on Node @include(if: $include) {
                    ... {
                      id
                    }
                  }
                  ... on Account {
                    username
                  }
                }
              }
            }
            """,
        ),
        """query ($skip: Boolean!, $include: Boolean!) {
  account(id: "a1") {
    ... on Account @skip(if: $skip) @include(if: $include) {
      id
    }
    ... on Account @skip(if: $skip) {
      username
    }
  }
}""",
    )


def test_untyped_inline_fragment_inside_nested_abstract_fragment_inherits_concrete_object_context() raises:
    assert_equal(
        _normalized(
            corrupted_supergraph_node_id.sdl(),
            """
            query {
              account(id: "a1") {
                ... on Node {
                  ... {
                    id
                    ... on Account {
                      username
                    }
                  }
                }
              }
            }
            """,
        ),
        """{
  account(id: "a1") {
    id
    username
  }
}""",
    )


def test_named_fragment_on_abstract_type_with_nested_abstract_directives_preserves_all_conditions() raises:
    # graphql-js layout: `query ($outer: ...)`, not `query($outer: ...)`.
    assert_equal(
        _normalized(
            corrupted_supergraph_node_id.sdl(),
            """
            query($outer: Boolean!, $inner: Boolean!, $skip: Boolean!) {
              account(id: "a1") {
                ...AccountNodeFields
              }
            }

            fragment AccountNodeFields on Node {
              ... on Node @include(if: $outer) {
                id
                ...InnerNode @include(if: $inner)
              }
              ... on Account @skip(if: $skip) {
                username
              }
            }

            fragment InnerNode on Node {
              ... {
                id
              }
            }
            """,
        ),
        """query ($outer: Boolean!, $inner: Boolean!, $skip: Boolean!) {
  account(id: "a1") {
    ... on Account @include(if: $outer) {
      id
      ... on Account @include(if: $inner) {
        id
      }
    }
    ... on Account @skip(if: $skip) {
      username
    }
  }
}""",
    )


comptime _ACCOUNT_USERNAME_SCHEMA = """
    type Query {
      account: Account
    }

    type Account {
      id: ID!
      username: String!
    }
"""


def test_matching_concrete_wrapper_with_typename_and_directive_is_not_flattened() raises:
    # graphql-js layout: `query ($cond: ...)`, not `query($cond: ...)`.
    assert_equal(
        _normalized(
            _ACCOUNT_USERNAME_SCHEMA,
            """
            query($cond: Boolean!) {
              account {
                ... on Account @include(if: $cond) {
                  id
                  __typename
                }
                username
              }
            }
            """,
        ),
        """query ($cond: Boolean!) {
  account {
    ... on Account @include(if: $cond) {
      id
      __typename
    }
    username
  }
}""",
    )


def test_matching_concrete_wrapper_with_both_directives_is_not_flattened() raises:
    # graphql-js layout: `query ($include: ...)`, not `query($include: ...)`.
    assert_equal(
        _normalized(
            _ACCOUNT_USERNAME_SCHEMA,
            """
            query($include: Boolean!, $skip: Boolean!) {
              account {
                ... on Account @include(if: $include) @skip(if: $skip) {
                  id
                }
                username
              }
            }
            """,
        ),
        """query ($include: Boolean!, $skip: Boolean!) {
  account {
    ... on Account @skip(if: $skip) @include(if: $include) {
      id
    }
    username
  }
}""",
    )


def test_matching_concrete_wrapper_with_directive_is_not_flattened() raises:
    # graphql-js layout: `query ($cond: ...)`, not `query($cond: ...)`.
    assert_equal(
        _normalized(
            _ACCOUNT_USERNAME_SCHEMA,
            """
            query($cond: Boolean!) {
              account {
                ... on Account @include(if: $cond) {
                  id
                }
                username
              }
            }
            """,
        ),
        """query ($cond: Boolean!) {
  account {
    ... on Account @include(if: $cond) {
      id
    }
    username
  }
}""",
    )


comptime _PETS_SCHEMA = """
    schema
        @link(url: "https://specs.apollo.dev/link/v1.0")
        @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
        query: Query
    }

    directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE

    directive @join__graph(name: String!, url: String!) on ENUM_VALUE

    directive @join__field(
        graph: join__Graph
        requires: join__FieldSet
        provides: join__FieldSet
        type: String
        external: Boolean
        override: String
        usedOverridden: Boolean
    ) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

    directive @join__implements(
        graph: join__Graph!
        interface: String!
    ) repeatable on OBJECT | INTERFACE

    directive @join__type(
        graph: join__Graph!
        key: join__FieldSet
        extension: Boolean! = false
        resolvable: Boolean! = true
        isInterfaceObject: Boolean! = false
    ) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

    directive @join__unionMember(
        graph: join__Graph!
        member: String!
    ) repeatable on UNION

    scalar join__FieldSet

    directive @link(
        url: String
        as: String
        for: link__Purpose
        import: [link__Import]
    ) repeatable on SCHEMA

    scalar link__Import

    enum link__Purpose {
        \"\"\"
        `SECURITY` features provide metadata necessary to securely resolve fields.
        \"\"\"
        SECURITY

        \"\"\"
        `EXECUTION` features provide metadata necessary for operation execution.
        \"\"\"
        EXECUTION
    }

    enum join__Graph {
        LOCAL @join__graph(name: "local", url: "")
    }

    type Dog implements Pet & Animal & Node
        @join__type(graph: LOCAL)
        @join__implements(graph: LOCAL, interface: "Pet")
        @join__implements(graph: LOCAL, interface: "Animal")
        @join__implements(graph: LOCAL, interface: "Node") {
        id: ID!
        name: String!
        bestFriend: Animal
        weight(unit: WeightUnit = KG): Float
        nickname: String
        tags: [String!]
    }

    type Cat implements Pet & Animal & Node
        @join__type(graph: LOCAL)
        @join__implements(graph: LOCAL, interface: "Pet")
        @join__implements(graph: LOCAL, interface: "Animal")
        @join__implements(graph: LOCAL, interface: "Node") {
        id: ID!
        name: String!
        bestFriend: Cat
        weight(unit: WeightUnit = KG): Float
        age: Int
        tags: [String!]
    }

    type Robot implements Node
        @join__type(graph: LOCAL)
        @join__implements(graph: LOCAL, interface: "Node") {
        id: ID!
        model: String!
        weight(unit: WeightUnit = KG): Float
    }

    type Owner implements Node
        @join__type(graph: LOCAL)
        @join__implements(graph: LOCAL, interface: "Node") {
        id: ID!
        name: String!
        pets: [Pet!]!
        primaryPet: Pet
    }

    type Query @join__type(graph: LOCAL) {
        pet: Pet
        animal: Animal
        node: Node
        search: SearchResult
        searchMany: [SearchResult!]!
        pets: [Pet!]!
        owner: Owner
    }

    interface Node @join__type(graph: LOCAL) {
        id: ID!
    }

    interface Animal implements Node
        @join__type(graph: LOCAL)
        @join__implements(graph: LOCAL, interface: "Node") {
        id: ID!
        name: String!
    }

    interface Pet implements Animal & Node
        @join__type(graph: LOCAL)
        @join__implements(graph: LOCAL, interface: "Animal")
        @join__implements(graph: LOCAL, interface: "Node") {
        id: ID!
        name: String!
        bestFriend: Animal
        weight(unit: WeightUnit = KG): Float
    }

    union SearchResult
        @join__type(graph: LOCAL)
        @join__unionMember(graph: LOCAL, member: "Dog")
        @join__unionMember(graph: LOCAL, member: "Cat")
        @join__unionMember(graph: LOCAL, member: "Robot") =
        | Dog
        | Cat
        | Robot

    enum WeightUnit @join__type(graph: LOCAL) {
        KG @join__enumValue(graph: LOCAL)
        LB @join__enumValue(graph: LOCAL)
        G @join__enumValue(graph: LOCAL)
    }
"""


def test_multiple_directives_and_conditions_and_fragments() raises:
    assert_equal(
        _normalized(
            _PETS_SCHEMA,
            """
            query SpreadDirective($withName: Boolean!, $deep: Boolean!) {
              node {
                id
                ...AnimalBits @include(if: $withName)
                ... on Dog @skip(if: $deep) { nickname }
              }
            }

            fragment AnimalBits on Animal {
              name
              ... on Dog { nickname }
            }
            """,
        ),
        """query SpreadDirective($withName: Boolean!, $deep: Boolean!) {
  node {
    id
    ... on Cat @include(if: $withName) {
      name
    }
    ... on Dog @include(if: $withName) {
      name
      nickname
    }
    ... on Dog @skip(if: $deep) {
      nickname
    }
  }
}""",
    )


comptime _FIELD_SCHEMA = """
    type Query {
      field: String
    }
"""


def test_acyclic_fragment_chain_does_not_overflow_stack() raises:
    # A long acyclic fragment chain must not overflow the stack. A result
    # or an error both mean that normalization survived.
    var n = 10_000
    var document = String("query { ...F1 }\n")
    for i in range(1, n):
        document += "fragment F" + String(i) + " on Query { ...F"
        document += String(i + 1) + " }\n"
    document += "fragment F" + String(n) + " on Query { __typename }\n"
    var store = Store()
    var state = new_supergraph_state(store, parse(_FIELD_SCHEMA))
    var parsed = parse(document)
    try:
        _ = normalize_operation(store, state, parsed)
    except:
        pass


def test_cyclic_fragment_self_reference_returns_error() raises:
    with assert_raises(contains="Cyclic fragment spread detected"):
        _ = _normalized(
            _FIELD_SCHEMA,
            """
            query { ...A }
            fragment A on Query { ...A }
            """,
        )


def test_cyclic_fragment_mutual_reference_returns_error() raises:
    with assert_raises(contains="Cyclic fragment spread detected"):
        _ = _normalized(
            _FIELD_SCHEMA,
            """
            query { ...A }
            fragment A on Query { ...B }
            fragment B on Query { ...A }
            """,
        )


def test_cyclic_fragment_self_reference_with_sibling_field_returns_error() raises:
    with assert_raises(contains="Cyclic fragment spread detected"):
        _ = _normalized(
            """
            type Query {
              x: String
            }
            """,
            """
            query { ...A }
            fragment A on Query { x ...A }
            """,
        )


def test_cyclic_fragment_self_reference_with_directive_returns_error() raises:
    with assert_raises(contains="Cyclic fragment spread detected"):
        _ = _normalized(
            _FIELD_SCHEMA,
            """
            query ($c: Boolean!) { ...A }
            fragment A on Query { ...A @include(if: $c) }
            """,
        )


# The tests below have no upstream counterpart. They check the paths of the
# passes that the upstream tests do not reach: empty sets, unknown names,
# abstract types with no possible types, and the type expansion rules of a
# federated interface.

comptime _PLAIN_SCHEMA = """
    type Query {
      cat: Cat
      node: Node
      lonely: Lonely
      pet: Pet
      i: I
      a: Int
      b: Int
    }
    interface Node { id: ID }
    interface Lonely { id: ID }
    interface Other { id: ID }
    interface I { a: Int sub: Cat }
    type Cat implements Node @join__implements(graph: A, interface: "Node") {
      id: ID
      name: String
    }
    type Dog implements Node @join__implements(graph: A, interface: "Node") {
      id: ID
      bark: String
    }
    type T implements I @join__implements(graph: A, interface: "I") { a: Int }
    union Pet @join__unionMember(graph: A, member: "Cat")
      @join__unionMember(graph: A, member: "Dog") = Cat | Dog
    enum Color { RED }
"""


def _normalize_only(schema: String, query: String) raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(schema))
    _ = normalize_operation(store, state, parse(query))


def test_root_types_type_for() raises:
    var roots = RootTypes(1, NONE, 3)
    assert_equal(roots.type_for(OperationKind.SUBSCRIPTION), 3)
    assert_equal(roots.type_for(OperationKind.QUERY), 1)
    with assert_raises(
        contains="Type for operation kind 'mutation' not found."
    ):
        _ = roots.type_for(OperationKind.MUTATION)


def test_unknown_names_raise() raises:
    with assert_raises(contains="Fragment definition for 'Missing' not found."):
        _ = _normalized(_PLAIN_SCHEMA, "{ ...Missing }")
    with assert_raises(contains="Schema type 'Ghost' not found."):
        _ = _normalized(_PLAIN_SCHEMA, "{ ... on Ghost { a } }")
    with assert_raises(contains="Field 'nope' not found in type 'Query'."):
        _ = _normalized(_PLAIN_SCHEMA, "{ nope }")
    with assert_raises(contains="Specified operation 'C' not found."):
        _ = _normalized(_PLAIN_SCHEMA, "query A { a }", String("C"))
    with assert_raises(contains="An operation was expected"):
        _ = _normalized(_PLAIN_SCHEMA, "fragment F on Query { a }")


def test_operation_choice_skips_other_definitions() raises:
    assert_equal(
        _normalized(_PLAIN_SCHEMA, "query A { a } query B { b }", String("B")),
        "query B {\n  b\n}",
    )
    assert_equal(_normalized(_PLAIN_SCHEMA, "scalar X\n{ a }"), "{\n  a\n}")


def test_directives_are_sorted_and_read() raises:
    assert_equal(
        _normalized(
            _PLAIN_SCHEMA,
            """
            query ($x: Boolean!, $y: Boolean!) {
              a @skip(if: $x) @include(if: $y)
              b @include(if: $y) @skip(if: $x)
            }
            """,
        ),
        (
            "query ($x: Boolean!, $y: Boolean!) {\n  a @skip(if: $x)"
            " @include(if: $y)\n  b @skip(if: $x) @include(if: $y)\n}"
        ),
    )
    assert_equal(
        _normalized(_PLAIN_SCHEMA, "query ($v: Boolean!) { a @foo(if: $v) }"),
        # The plan keeps only `@skip` and `@include`.
        "query ($v: Boolean!) {\n  a\n}",
    )


def test_empty_fragments_are_dropped() raises:
    assert_equal(
        _normalized(
            _PLAIN_SCHEMA,
            """
            { ... on Query { ...F } b }
            fragment F on Query { a @skip(if: true) }
            """,
        ),
        "{\n  b\n}",
    )
    var empty_pet = "{\n  pet {\n    __typename\n  }\n}"
    assert_equal(
        _normalized(
            _PLAIN_SCHEMA, "{ pet { ... on Node { id @skip(if: true) } } }"
        ),
        empty_pet,
    )
    assert_equal(
        _normalized(
            _PLAIN_SCHEMA,
            "{ pet { ... on Node { ... on Cat { id @skip(if: true) } } } }",
        ),
        empty_pet,
    )
    assert_equal(
        _normalized(
            _PLAIN_SCHEMA,
            """
            query ($v: Boolean!) {
              pet { ... on Node { ... on Cat @include(if: $v) { id @skip(if: true) } } }
            }
            """,
        ),
        "query ($v: Boolean!) {\n  pet {\n    __typename\n  }\n}",
    )
    _normalize_only(
        _PLAIN_SCHEMA,
        """
        query ($v: Boolean!) {
          cat {
            ... on Cat @include(if: $v) {
              ... on Cat @include(if: $v) { name @skip(if: true) }
            }
          }
        }
        """,
    )


def test_fragments_that_cannot_apply_are_dropped() raises:
    assert_equal(
        _normalized(_PLAIN_SCHEMA, "{ cat { ... on Dog { bark } name } }"),
        "{\n  cat {\n    name\n  }\n}",
    )
    assert_equal(
        _normalized(_PLAIN_SCHEMA, "{ ... on Color { a } b }"), "{\n  b\n}"
    )
    var empty_lonely = "{\n  lonely {\n    __typename\n  }\n}"
    assert_equal(
        _normalized(_PLAIN_SCHEMA, "{ lonely { ... on Other { id } } }"),
        empty_lonely,
    )
    assert_equal(
        _normalized(_PLAIN_SCHEMA, "{ lonely { ... on Node { id } } }"),
        empty_lonely,
    )
    assert_equal(
        _normalized(
            _PLAIN_SCHEMA,
            (
                "{ pet { ... on Node { ... on Pet { id } ... on Lonely { id }"
                " } } }"
            ),
        ),
        (
            "{\n  pet {\n    ... on Cat {\n      id\n    }\n    ... on Dog {\n"
            "      id\n    }\n  }\n}"
        ),
    )


def test_nested_fragments_with_equal_directives_merge() raises:
    assert_equal(
        _normalized(
            _PLAIN_SCHEMA,
            """
            query ($v: Boolean!) {
              cat { ... on Cat @include(if: $v) { ... on Cat @include(if: $v) { name } } }
            }
            """,
        ),
        (
            "query ($v: Boolean!) {\n  cat {\n    ... on Cat @include(if: $v)"
            " {\n      name\n    }\n  }\n}"
        ),
    )


def test_interface_fields_of_plain_interfaces() raises:
    assert_equal(
        _normalized(_PLAIN_SCHEMA, "{ lonely { id } }"),
        "{\n  lonely {\n    id\n  }\n}",
    )
    assert_equal(
        _normalized(_PLAIN_SCHEMA, "{ node { id } }"),
        "{\n  node {\n    id\n  }\n}",
    )
    # `T` has no `sub`: the type expansion moves the field into a fragment
    # on `T` as it is, and the next pass does not find it.
    with assert_raises(contains="Field 'sub' not found in type 'T'."):
        _ = _normalized(_PLAIN_SCHEMA, "{ i { sub { name } } }")


comptime _FEDERATED_SCHEMA = """
    enum join__Graph {
      A @join__graph(name: "a", url: "http://a")
      B @join__graph(name: "b", url: "http://b")
      C @join__graph(name: "c", url: "http://c")
    }
    type Query @join__type(graph: A) @join__type(graph: B) {
      node: Node
      union2: Pet2
    }
    interface Node
      @join__type(graph: A)
      @join__type(graph: B)
      @join__type(graph: C, isInterfaceObject: true) {
      id: ID
      free: Int @join__field
      objectOnly: Int @join__field(graph: C)
      both: Int @join__field(graph: A) @join__field(graph: B)
      one: Int @join__field(graph: A) @join__field(graph: B, external: true)
    }
    type Cat implements Node
      @join__implements(graph: A, interface: "Node")
      @join__implements(graph: B, interface: "Node")
      @join__type(graph: A)
      @join__type(graph: B) {
      id: ID @join__field(graph: A, override: "ghost") @join__field(graph: B)
      free: Int
      objectOnly: Int
      both: Int
      one: Int
    }
    union Pet2 @join__type(graph: B)
      @join__unionMember(graph: B, member: "Cat") = Cat
"""


def test_type_expansion_of_a_federated_interface() raises:
    for field in ["id", "free", "objectOnly", "both"]:
        assert_equal(
            _normalized(_FEDERATED_SCHEMA, "{ node { " + field + " } }"),
            "{\n  node {\n    " + field + "\n  }\n}",
        )
    assert_equal(
        _normalized(_FEDERATED_SCHEMA, "{ node { one } }"),
        "{\n  node {\n    ... on Cat {\n      one\n    }\n  }\n}",
    )


def test_field_set_with_a_type_of_another_subgraph() raises:
    var store = Store()
    var state = new_supergraph_state(store, parse(_FEDERATED_SCHEMA))
    with assert_raises(contains="Possible types for 'Pet2' not found."):
        _ = normalize_field_set(
            store,
            state,
            store.sym("Query"),
            store.sym("A"),
            "node { ... on Pet2 { id } }",
        )


def test_drop_duplicated_leaf_fields() raises:
    var store = Store()
    var set = selection_set_from_text(
        store, "{ ... on T { a a } a { x } a a { y } }"
    )
    _drop_duplicates_set(store, set)
    assert_equal(store.count(set), 4)
    assert_equal(store.count(store.children(set)[0]), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
