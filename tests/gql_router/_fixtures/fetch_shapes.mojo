# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A supergraph for the fetch graph optimizer tests, written for this port:
two subgraphs with interfaces, a union, and interfaces with members only
in the other subgraph or none.
"""


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
  EXTRA @join__graph(name: "extra", url: "")
  MEDIA @join__graph(name: "media", url: "")
}

type Query @join__type(graph: EXTRA) @join__type(graph: MEDIA) {
  media: [Media] @join__field(graph: MEDIA)
  items: [Item] @join__field(graph: MEDIA)
  tracks: [Track] @join__field(graph: MEDIA)
  shelf: Shelf @join__field(graph: MEDIA)
  lonely: Lonely @join__field(graph: MEDIA)
  kind: Kind @join__field(graph: MEDIA)
  extra: Extra @join__field(graph: EXTRA)
}

interface Media @join__type(graph: MEDIA) {
  id: ID!
  title: String
  shelf: Shelf
}

interface Titled @join__type(graph: MEDIA) {
  title: String
}

type Book implements Titled & Media
  @join__type(graph: MEDIA)
  @join__implements(graph: MEDIA, interface: "Titled")
  @join__implements(graph: MEDIA, interface: "Media") {
  id: ID!
  title: String
  shelf: Shelf
  pages: Int
  shared: String
}

type Movie implements Media
  @join__type(graph: MEDIA)
  @join__implements(graph: MEDIA, interface: "Media") {
  id: ID!
  title: String
  shelf: Shelf
  length: Int
  shared: String
}

union Item
  @join__type(graph: MEDIA)
  @join__unionMember(graph: MEDIA, member: "Book")
  @join__unionMember(graph: MEDIA, member: "Movie") =
  | Book
  | Movie

interface Track @join__type(graph: MEDIA) {
  id: ID!
}

type Song implements Track
  @join__type(graph: MEDIA)
  @join__implements(graph: MEDIA, interface: "Track") {
  id: ID!
}

type Album implements Track
  @join__type(graph: MEDIA)
  @join__implements(graph: MEDIA, interface: "Track") {
  id: ID!
}

type Single implements Track
  @join__type(graph: MEDIA)
  @join__implements(graph: MEDIA, interface: "Track") {
  id: ID!
}

type Podcast implements Media
  @join__type(graph: EXTRA)
  @join__implements(graph: EXTRA, interface: "Media") {
  id: ID!
  title: String
  shelf: Shelf
}

interface Remote @join__type(graph: MEDIA) {
  id: ID!
}

type Radio implements Remote
  @join__type(graph: EXTRA)
  @join__implements(graph: EXTRA, interface: "Remote") {
  id: ID!
}

type Shelf @join__type(graph: EXTRA) @join__type(graph: MEDIA) {
  name: String @join__field(graph: MEDIA)
  media: [Media] @join__field(graph: MEDIA)
  items: [Item] @join__field(graph: MEDIA)
  label: String @join__field(graph: EXTRA)
}

interface Lonely @join__type(graph: MEDIA) {
  id: ID!
}

enum Kind @join__type(graph: MEDIA) {
  A @join__enumValue(graph: MEDIA)
}

type Extra @join__type(graph: EXTRA) {
  id: ID!
}
"""
    )
