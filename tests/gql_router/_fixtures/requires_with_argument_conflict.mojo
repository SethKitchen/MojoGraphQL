# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Hive Router `1a29df9` `bin/router/fixture/tests/requires-with-argument-conflict.supergraph.graphql` (MIT)."""


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

type Category @join__type(graph: A) @join__type(graph: B) {
  averagePrice(currency: String!): Int
    @join__field(graph: A, external: true)
    @join__field(graph: B)
}

scalar join__FieldSet

enum join__Graph {
  A
    @join__graph(
      name: \"a\"
      url: \"http://localhost:4200/requires-with-argument-conflict/a\"
    )
  B
    @join__graph(
      name: \"b\"
      url: \"http://localhost:4200/requires-with-argument-conflict/b\"
    )
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
  @join__type(graph: A, key: \"upc\")
  @join__type(graph: B, key: \"upc\") {
  upc: String!
  weight: Int @join__field(graph: A, external: true) @join__field(graph: B)
  price(currency: String!): Int
    @join__field(graph: A, external: true)
    @join__field(graph: B)
  shippingEstimate: Int
    @join__field(graph: A, requires: \"price(currency: \\\"USD\\\") weight\")
  shippingEstimateEUR: Int
    @join__field(graph: A, requires: \"price(currency: \\\"EUR\\\") weight\")
  category: Category
    @join__field(graph: A, external: true)
    @join__field(graph: B)
  isExpensiveCategory: Boolean
    @join__field(
      graph: A
      requires: \"category { averagePrice(currency: \\\"USD\\\") }\"
    )
  name: String @join__field(graph: B)
}

type Query @join__type(graph: A) @join__type(graph: B) {
  products: [Product] @join__field(graph: B)
}
"""
    )
