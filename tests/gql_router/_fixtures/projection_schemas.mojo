# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `SCHEMA_1` and `SCHEMA_2` supergraphs of Hive Router `1a29df9`
`bin/router/src/executor/projection/plan/merge.rs` (MIT).

The descriptions of `link__Purpose` are left out; they do not change the
schema metadata.
"""


def _prelude() -> String:
    """Return the `@link` and `@join__*` definitions that both share."""
    return String(
        """schema
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
  SECURITY
  EXECUTION
}

enum join__Graph {
  LOCAL @join__graph(name: "local", url: "")
}
"""
    )


def schema_1() -> String:
    """Return upstream `SCHEMA_1`.

    Returns:
        The supergraph SDL.
    """
    return _prelude() + String(
        """
type Query @join__type(graph: LOCAL) {
  search: [SearchResult!]!
  feed: [Content!]!
  concrete: ConcreteType
}

type ConcreteType @join__type(graph: LOCAL) {
  id: ID!
  test: String!
  someEnum: SomeEnum
  inner: InnerType
}

type InnerType @join__type(graph: LOCAL) {
  inner: Boolean
}

type Article implements Content
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Content") {
  id: ID!
  meta: Meta!
  headline: String!
}

type Video implements Content
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Content") {
  id: ID!
  meta: Meta!
  duration: Int!
}

type Photo implements Content
  @join__type(graph: LOCAL)
  @join__implements(graph: LOCAL, interface: "Content") {
  id: ID!
  meta: Meta!
}

type Meta @join__type(graph: LOCAL) {
  title: String
  wordCount: Int!
  arch: String!
}

interface Content @join__type(graph: LOCAL) {
  id: ID!
  meta: Meta!
}

union SearchResult
  @join__type(graph: LOCAL)
  @join__unionMember(graph: LOCAL, member: "Article")
  @join__unionMember(graph: LOCAL, member: "Video") =
  | Article
  | Video

enum SomeEnum @join__type(graph: LOCAL) {
  TEST @join__enumValue(graph: LOCAL)
}
"""
    )


def schema_2() -> String:
    """Return upstream `SCHEMA_2`.

    Returns:
        The supergraph SDL.
    """
    return _prelude() + String(
        """
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
    )
