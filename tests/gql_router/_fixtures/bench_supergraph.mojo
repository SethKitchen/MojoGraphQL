# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Hive Router `1a29df9` `bench/supergraph.graphql` and
`bench/operation.graphql` (MIT)."""


def sdl() -> String:
    """Return the fixture text.

    Returns:
        The text.
    """
    return String(
        """schema
  @link(url: \"https://specs.apollo.dev/link/v1.0\")
  @link(url: \"https://specs.apollo.dev/join/v0.3\", for: EXECUTION) {
  query: Query
  subscription: Subscription
}

directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE

directive @join__field(
  graph: join__Graph
  requires: join__FieldSet
  provides: join__FieldSet
  type: String
  external: Boolean
  override: String
  usedOverridden: Boolean
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

directive @join__graph(name: String!, url: String!) on ENUM_VALUE

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

directive @link(
  url: String
  as: String
  for: link__Purpose
  import: [link__Import]
) repeatable on SCHEMA

scalar join__FieldSet

enum join__Graph {
  ACCOUNTS @join__graph(name: \"accounts\", url: \"http://0.0.0.0:4200/accounts\")
  INVENTORY
    @join__graph(name: \"inventory\", url: \"http://0.0.0.0:4200/inventory\")
  PRODUCTS @join__graph(name: \"products\", url: \"http://0.0.0.0:4200/products\")
  REVIEWS @join__graph(name: \"reviews\", url: \"http://0.0.0.0:4200/reviews\")
}

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

type Product
  @join__type(graph: INVENTORY, key: \"upc\")
  @join__type(graph: PRODUCTS, key: \"upc\")
  @join__type(graph: REVIEWS, key: \"upc\") {
  upc: String!
  weight: Int
    @join__field(graph: INVENTORY, external: true)
    @join__field(graph: PRODUCTS)
  price: Int
    @join__field(graph: INVENTORY, external: true)
    @join__field(graph: PRODUCTS)
  inStock: Boolean @join__field(graph: INVENTORY)
  shippingEstimate: Int @join__field(graph: INVENTORY, requires: \"price weight\")
  name: String @join__field(graph: PRODUCTS)
  reviews: [Review] @join__field(graph: REVIEWS)
  notes: String @join__field(graph: PRODUCTS)
  internal: String @join__field(graph: PRODUCTS)
}

type Query
  @join__type(graph: ACCOUNTS)
  @join__type(graph: INVENTORY)
  @join__type(graph: PRODUCTS)
  @join__type(graph: REVIEWS) {
  me: User @join__field(graph: ACCOUNTS)
  user(id: ID!): User @join__field(graph: ACCOUNTS)
  users: [User] @join__field(graph: ACCOUNTS)
  topProducts(first: Int = 5): [Product] @join__field(graph: PRODUCTS)
}

type Subscription @join__type(graph: REVIEWS) {
  reviewAdded(step: Int = 1, intervalInMs: Int = 1000): Review
    @join__field(graph: REVIEWS)
  reviewAddedForProduct(productUpc: String!, intervalInMs: Int = 1000): Review
    @join__field(graph: REVIEWS)
}

type Review @join__type(graph: REVIEWS, key: \"id\") {
  id: ID!
  body: String
  product: Product
  author: User @join__field(graph: REVIEWS, provides: \"username\")
}

type User
  @join__type(graph: ACCOUNTS, key: \"id\")
  @join__type(graph: REVIEWS, key: \"id\") {
  id: ID!
  name: String @join__field(graph: ACCOUNTS)
  username: String
    @join__field(graph: ACCOUNTS)
    @join__field(graph: REVIEWS, external: true)
  birthday: Int @join__field(graph: ACCOUNTS)
  reviews: [Review] @join__field(graph: REVIEWS)
}
"""
    )


def operation() -> String:
    """Return the benchmark operation, upstream `bench/operation.graphql`.

    Returns:
        The text.
    """
    return String(
        """fragment User on User {
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

query TestQuery {
  users {
    ...User
    reviews {
      ...Review
      product {
        ...Product
        reviews {
          ...Review
          author {
            ...User
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
  topProducts {
    ...Product
    reviews {
      ...Review
      author {
        ...User
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
"""
    )
