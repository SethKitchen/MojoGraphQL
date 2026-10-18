# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A small supergraph for the subgraph state and mismatch finder tests.

Subgraph `B` has `Kind` and `Any` by `@join__type`, but no value of `Kind`
and no member of `Any`. Subgraph `A` lists the member `Pet` of `Any` twice.
"""


def sdl() -> String:
    """Return the supergraph SDL.

    Returns:
        The text.
    """
    return String(
        """schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
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

enum join__Graph {
  A @join__graph(name: "a", url: "")
  B @join__graph(name: "b", url: "")
}

type Query @join__type(graph: A) @join__type(graph: B) {
  pet: Pet @join__field(graph: A)
  any: Any @join__field(graph: A)
  name: String @join__field(graph: A)
  kind: Kind @join__field(graph: B)
}

type Pet @join__type(graph: A, key: "id") {
  id: ID!
  name: String
  age: Int
}

enum Kind @join__type(graph: A) @join__type(graph: B) {
  CAT @join__enumValue(graph: A)
}

union Any
  @join__type(graph: A)
  @join__type(graph: B)
  @join__unionMember(graph: A, member: "Pet")
  @join__unionMember(graph: A, member: "Pet") =
  | Pet
"""
    )
