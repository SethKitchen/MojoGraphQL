# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A one-subgraph supergraph with `@authenticated`, `@requiresScopes` and
`@policy` on fields and on a type."""


def auth_sdl() -> String:
    """Return the supergraph SDL."""
    return String(
        """schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION)
  @link(url: "https://specs.apollo.dev/authenticated/v0.1", for: SECURITY)
  @link(url: "https://specs.apollo.dev/requiresScopes/v0.1", for: SECURITY)
  @link(url: "https://specs.apollo.dev/policy/v0.1", for: SECURITY)
{
  query: Query
  mutation: Mutation
}

directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE
directive @join__field(graph: join__Graph, requires: join__FieldSet, provides: join__FieldSet, type: String, external: Boolean, override: String, usedOverridden: Boolean) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION
directive @join__graph(name: String!, url: String!) on ENUM_VALUE
directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE
directive @join__type(graph: join__Graph!, key: join__FieldSet, extension: Boolean! = false, resolvable: Boolean! = true, isInterfaceObject: Boolean! = false) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR
directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION
directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA
directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @requiresScopes(scopes: [[requiresScopes__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @policy(policies: [[policy__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

scalar join__FieldSet
scalar requiresScopes__Scope
scalar policy__Policy

enum join__Graph {
  ACCOUNTS @join__graph(name: "accounts", url: "http://127.0.0.1:14001/graphql")
}

scalar link__Import

enum link__Purpose {
  SECURITY
  EXECUTION
}

type Query @join__type(graph: ACCOUNTS) {
  me: User @join__field(graph: ACCOUNTS)
  secret: String @join__field(graph: ACCOUNTS) @authenticated
  admin: String @join__field(graph: ACCOUNTS) @requiresScopes(scopes: [["admin", "write"], ["root"]])
  audited: String @join__field(graph: ACCOUNTS) @policy(policies: [["audit"]])
}

type Mutation @join__type(graph: ACCOUNTS) {
  wipe: Boolean @join__field(graph: ACCOUNTS) @authenticated
  ping: Boolean @join__field(graph: ACCOUNTS)
}

type User @join__type(graph: ACCOUNTS) {
  name: String
  email: String! @authenticated
  card: Card
}

type Card @join__type(graph: ACCOUNTS) @authenticated {
  number: String
}
"""
    )
