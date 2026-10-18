# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for supergraph composition of object types.

The expected SDL is what Hive Federation Composition v0.27.0
`composeServices` prints for the same subgraphs.
"""

from gql_composition.compose import compose_subgraphs
from gql_composition.validate import Subgraph
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal, assert_true


def _sg(name: String, sdl: String) raises -> Subgraph:
    """Parse a subgraph with no URL."""
    return Subgraph(name, None, parse(sdl))


def test_one_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query {\n  user: User\n}\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _ONE)


def test_two_subgraphs() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user: User }\ntype User'
                    ' @key(fields: "id") { id: ID! name: String }\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external"])\nextend type User @key(fields:'
                    ' "id") { id: ID! @external reviews: [String] }\ntype Query'
                    " { review: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _TWO)


def test_enums_in_one_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { role: Role }\nenum Role { ADMIN'
                    " USER }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ENUM_ONE)


def test_enums_in_two_subgraphs() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { role: Role }\nenum Role { ADMIN'
                    " USER }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { review: String }\nenum Role {'
                    " USER GUEST }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ENUM_TWO)


def _from_graphs(sdl: String) -> String:
    """Return the supergraph from `enum join__Graph` onward."""
    var at = sdl.find("enum join__Graph")
    return String(sdl[byte=at:])


def test_an_interface_and_its_implementation() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Node { id: ID! }\ntype User'
                    ' implements Node @key(fields: "id") { id: ID! name: String'
                    " }\ntype Query { user: User }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_ONE)


def test_an_interface_in_two_subgraphs() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Node { id: ID! }\ntype User'
                    ' implements Node @key(fields: "id") { id: ID! name: String'
                    " }\ntype Query { user: User }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Node { id: ID! }\ntype User'
                    ' implements Node @key(fields: "id") { id: ID! reviews:'
                    " [String] }\ntype Query { review: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_TWO)


def test_a_union() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { item: Product }\ntype Book'
                    ' @key(fields: "id") { id: ID! title: String }\ntype Film'
                    ' @key(fields: "id") { id: ID! }\nunion Product = Book |'
                    " Film\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _UNION_ONE)


def test_a_union_across_subgraphs() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { item: Product }\ntype Book'
                    ' @key(fields: "id") { id: ID! }\nunion Product = Book\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { review: String }\ntype Film'
                    ' @key(fields: "id") { id: ID! }\nunion Product = Film\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _UNION_TWO)


def test_an_input_object() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninput ById { id: ID! }\ntype Query { user(by:'
                    " ById): String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INPUT_ONE)


def test_external_and_requires() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\ntype Query { user: User }\ntype User'
                    ' @key(fields: "id") { id: ID! name: String! }\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    ' String }\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n  reviews: [String!]!"
                    ' @requires(fields: "name")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES)


def test_override_removes_the_source_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\ntype Query { user: User }\ntype'
                    ' User @key(fields: "id") { id: ID! name: String'
                    " @shareable }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\ntype Query { review: String'
                    ' }\ntype User @key(fields: "id") { id: ID! name: String'
                    ' @override(from: "users") }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _OVERRIDE)


def test_an_unresolvable_key_and_a_scalar() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\nscalar Date\ntype Query { today: Date user:'
                    ' User }\ntype User @key(fields: "id", resolvable: false) {'
                    " id: ID! }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _SCALAR)


def test_provides_on_a_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype User @key(fields: "id") { id: ID! name:'
                    " String }\ntype Query { users: [User] }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\ntype User'
                    ' @key(fields: "id") { id: ID! name: String @external'
                    ' }\ntype Review @key(fields: "id") { id: ID! author: User'
                    ' @provides(fields: "name") }\ntype Query { reviews:'
                    " [Review] }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _PROVIDES)


def test_two_keys_on_one_type() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype User @key(fields: "id") @key(fields:'
                    ' "email") {\n  id: ID!\n  email: String\n  name:'
                    " String\n}\ntype Query { user(id: ID!): User }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _TWO_KEYS)


def test_a_labeled_override_keeps_both_fields() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\ntype User @key(fields: "id") {'
                    " id: ID! name: String @shareable }\ntype Query { user:"
                    " User }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @shareable @override(from: "users", label:'
                    ' "percent(1)")\n}\ntype Query { reviewUser: User }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _OVERRIDE_LABEL)


def test_a_missing_query_is_an_error() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype User @key(fields: "id") { id: ID! }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 1)
    assert_equal(
        String(result.errors[0]),
        (
            "[NO_QUERIES] No queries found in any subgraph: a supergraph must"
            " have a query root type."
        ),
    )
    assert_equal(result.supergraph_sdl, "")


comptime _ONE = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user: User
}

type User @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String
}'''


comptime _TWO = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  reviews: [String] @join__field(graph: REVIEWS)
  name: String @join__field(graph: USERS)
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}'''


comptime _ENUM_ONE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  role: Role
}

enum Role @join__type(graph: USERS) {
  ADMIN @join__enumValue(graph: USERS)
  USER @join__enumValue(graph: USERS)
}"""


comptime _ENUM_TWO = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  role: Role @join__field(graph: USERS)
}

enum Role @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  USER @join__enumValue(graph: REVIEWS) @join__enumValue(graph: USERS)
  GUEST @join__enumValue(graph: REVIEWS)
  ADMIN @join__enumValue(graph: USERS)
}"""


comptime _INTERFACE_ONE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type User implements Node @join__type(graph: USERS, key: "id") @join__implements(graph: USERS, interface: "Node") {
  id: ID!
  name: String
}

type Query @join__type(graph: USERS) {
  user: User
}

interface Node @join__type(graph: USERS) {
  id: ID!
}"""


comptime _INTERFACE_TWO = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type User implements Node @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") @join__implements(graph: REVIEWS, interface: "Node") @join__implements(graph: USERS, interface: "Node") {
  id: ID!
  reviews: [String] @join__field(graph: REVIEWS)
  name: String @join__field(graph: USERS)
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}

interface Node @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  id: ID!
}"""


comptime _UNION_ONE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  item: Product
}

type Book @join__type(graph: USERS, key: "id") {
  id: ID!
  title: String
}

type Film @join__type(graph: USERS, key: "id") {
  id: ID!
}

union Product @join__type(graph: USERS) @join__unionMember(graph: USERS, member: "Book") @join__unionMember(graph: USERS, member: "Film") = Book | Film"""


comptime _UNION_TWO = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  item: Product @join__field(graph: USERS)
}

type Film @join__type(graph: REVIEWS, key: "id") {
  id: ID!
}

type Book @join__type(graph: USERS, key: "id") {
  id: ID!
}

union Product @join__type(graph: REVIEWS) @join__type(graph: USERS) @join__unionMember(graph: REVIEWS, member: "Film") @join__unionMember(graph: USERS, member: "Book") = Film | Book"""


comptime _INPUT_ONE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user(by: ById): String
}

input ById @join__type(graph: USERS) {
  id: ID!
}"""


comptime _REQUIRES = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String! @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String!]! @join__field(graph: REVIEWS, requires: "name")
}"""


comptime _OVERRIDE = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String @join__field(graph: REVIEWS, override: "users")
}"""


comptime _SCALAR = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

scalar Date @join__type(graph: USERS)

type Query @join__type(graph: USERS) {
  today: Date
  user: User
}

type User @join__type(graph: USERS, key: "id", resolvable: false) {
  id: ID!
}"""


comptime _PROVIDES = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User @join__field(graph: REVIEWS, provides: "name")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  reviews: [Review] @join__field(graph: REVIEWS)
  users: [User] @join__field(graph: USERS)
}"""


comptime _TWO_KEYS = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type User @join__type(graph: USERS, key: "id") @join__type(graph: USERS, key: "email") {
  id: ID!
  email: String
  name: String
}

type Query @join__type(graph: USERS) {
  user(id: ID!): User
}"""


comptime _OVERRIDE_LABEL = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String @join__field(graph: REVIEWS, override: "users", overrideLabel: "percent(1)") @join__field(graph: USERS, overrideLabel: "percent(1)")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  reviewUser: User @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}"""


def test_inaccessible_fields() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\ntype Query {\n  user: User\n '
                    " hidden: String @inaccessible\n}\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  secret: String @inaccessible\n '
                    " name: String\n}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _INACCESSIBLE)


def test_inaccessible_type_enum_value_and_argument() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\ntype Query {\n  q: String\n '
                    " color: Color\n  user(id: ID @inaccessible):"
                    ' String\n}\ntype Hidden @key(fields: "id") @inaccessible'
                    " {\n  id: ID!\n}\nenum Color {\n  RED\n  GREEN"
                    " @inaccessible\n}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _INACCESSIBLE_PLACES)


comptime _INACCESSIBLE = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user: User
  hidden: String @inaccessible
}

type User @join__type(graph: USERS, key: "id") {
  id: ID!
  secret: String @inaccessible
  name: String
}'''


comptime _INACCESSIBLE_PLACES = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  q: String
  color: Color
  user(id: ID @inaccessible): String
}

type Hidden @join__type(graph: USERS, key: "id") @inaccessible {
  id: ID!
}

enum Color @join__type(graph: USERS) {
  RED @join__enumValue(graph: USERS)
  GREEN @join__enumValue(graph: USERS) @inaccessible
}'''


def test_tags() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@tag"])\ntype Query {\n  user(id: ID @tag(name:'
                    ' "arg")): User\n}\ntype User @key(fields: "id") @tag(name:'
                    ' "beta") @tag(name: "alpha") {\n  id: ID!\n  name: String'
                    ' @tag(name: "field")\n}\nenum Color @tag(name: "enum") {\n'
                    '  RED @tag(name: "value")\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _TAGS)


comptime _TAGS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/tag/v0.3") {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user(id: ID @tag(name: "arg")): User
}

type User @join__type(graph: USERS, key: "id") @tag(name: "beta") @tag(name: "alpha") {
  id: ID!
  name: String @tag(name: "field")
}

enum Color @join__type(graph: USERS) @tag(name: "enum") {
  RED @join__enumValue(graph: USERS) @tag(name: "value")
}'''


def test_interface_object() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\ntype Query { product:'
                    " Product }\ntype Product @interfaceObject @key(fields:"
                    ' "id") { id: ID! sku: String }\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { review: Product }\ninterface'
                    ' Product @key(fields: "id") { id: ID! }\ntype Book'
                    ' implements Product @key(fields: "id") { id: ID! title:'
                    " String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _INTERFACE_OBJECT)


comptime _INTERFACE_OBJECT = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  PRODUCTS @join__graph(name: "products", url: "")
  REVIEWS @join__graph(name: "reviews", url: "")
}

type Query @join__type(graph: PRODUCTS) @join__type(graph: REVIEWS) {
  product: Product @join__field(graph: PRODUCTS)
  review: Product @join__field(graph: REVIEWS)
}

type Book implements Product @join__type(graph: REVIEWS, key: "id") @join__implements(graph: REVIEWS, interface: "Product") {
  id: ID!
  title: String
  sku: String @join__field
}

interface Product @join__type(graph: PRODUCTS, key: "id", isInterfaceObject: true) @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  sku: String @join__field(graph: PRODUCTS)
}'''


def test_enum_value_directives_from_one_subgraph() raises:
    var deprecated = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { color: Color @shareable }\n"
                    "enum Color { RED GREEN }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { color: Color @shareable }\n"
                    'enum Color { RED GREEN @deprecated(reason: "old") }\n'
                ),
            ),
        ]
    )
    assert_equal(len(deprecated.errors), 0)
    assert_equal(_from_graphs(deprecated.supergraph_sdl), _ENUM_DEPRECATED)
    var hidden = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@inaccessible", "@shareable"])\n'
                    "type Query { color: Color @shareable }\n"
                    "enum Color { RED GREEN }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@inaccessible", "@shareable"])\n'
                    "type Query { color: Color @shareable }\n"
                    "enum Color { RED GREEN @inaccessible }\n"
                ),
            ),
        ]
    )
    assert_equal(len(hidden.errors), 0)
    assert_equal(_from_graphs(hidden.supergraph_sdl), _ENUM_HIDDEN)


comptime _ENUM_DEPRECATED = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  color: Color
}

enum Color @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  RED @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA)
  GREEN @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA) @deprecated(reason: "old")
}"""


comptime _ENUM_HIDDEN = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  color: Color
}

enum Color @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  RED @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA)
  GREEN @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA) @inaccessible
}"""


def test_mutation_field_prints_type() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { q: String @shareable }\n"
                    "type Mutation { go: String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { q: String @shareable }\n"
                    "type Mutation { go: String! @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _MUTATION_NULLABLE)


comptime _MUTATION_NULLABLE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  q: String
}

type Mutation @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  go: String @join__field(graph: ALPHA, type: "String") @join__field(graph: ZETA, type: "String!")
}"""


def test_interface_field_keeps_the_nullable_type() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node @key(fields:'
                    ' "id") { id: ID! name: String! }\ntype User implements'
                    ' Node @key(fields: "id") { id: ID! name: String!'
                    " @shareable }\ntype Query { user: User }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node @key(fields:'
                    ' "id") { id: ID! name: String }\ntype User implements Node'
                    ' @key(fields: "id") { id: ID! name: String @shareable'
                    " }\ntype Query { node: Node }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_NULLABLE)


comptime _INTERFACE_NULLABLE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type User implements Node @join__type(graph: ALPHA, key: "id") @join__type(graph: ZETA, key: "id") @join__implements(graph: ALPHA, interface: "Node") @join__implements(graph: ZETA, interface: "Node") {
  id: ID!
  name: String @join__field(graph: ALPHA, type: "String!") @join__field(graph: ZETA, type: "String")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user: User @join__field(graph: ALPHA)
  node: Node @join__field(graph: ZETA)
}

interface Node @join__type(graph: ALPHA, key: "id") @join__type(graph: ZETA, key: "id") {
  id: ID!
  name: String
}"""


def test_query_field_keeps_the_nullable_type() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { items: [String]! @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { items: [String] @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _QUERY_NULLABLE)


comptime _QUERY_NULLABLE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  items: [String]
}"""


def test_argument_tag_from_one_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable", "@tag"])\n'
                    "type Query { user(id: ID): String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable", "@tag"])\n'
                    'type Query { user(id: ID @tag(name: "public")):'
                    " String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARG_TAG)


comptime _ARG_TAG = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user(id: ID @tag(name: "public")): String
}"""


def test_argument_cost_keeps_the_highest_weight() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable", "@cost"])\ntype Query { user(id: ID'
                    " @cost(weight: 2)): String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable", "@cost"])\ntype Query { user(id: ID'
                    " @cost(weight: 9)): String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARG_COST)


comptime _ARG_COST = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user(id: ID @cost(weight: 9)): String
}"""


def test_argument_deprecated_from_one_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { user(id: ID): String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    'type Query { user(id: ID @deprecated(reason: "old")):'
                    " String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARG_DEPRECATED)


comptime _ARG_DEPRECATED = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user(id: ID @deprecated(reason: "old")): String
}"""


def test_argument_inaccessible_from_one_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable", "@inaccessible"])\n'
                    "type Query { user(id: ID): String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable", "@inaccessible"])\ntype Query { user(id:'
                    " ID @inaccessible): String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARG_INACCESSIBLE)


comptime _ARG_INACCESSIBLE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user(id: ID @inaccessible): String
}"""


def test_input_default_must_be_in_every_subgraph() raises:
    var missing = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    'input Search { id: ID = "1" }\n'
                    "type Query { search(by: Search): String }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "input Search { id: ID }\n"
                    "type Query { find(by: Search): String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(missing.errors), 0)
    assert_equal(_from_graphs(missing.supergraph_sdl), _INPUT_DEFAULT_OMITTED)
    var present = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    'input Search { id: ID = "1" }\n'
                    "type Query { search(by: Search): String }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    'input Search { id: ID = "1" }\n'
                    "type Query { find(by: Search): String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(present.errors), 0)
    assert_equal(_from_graphs(present.supergraph_sdl), _INPUT_DEFAULT_KEPT)


comptime _INPUT_DEFAULT_OMITTED = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  search(by: Search): String @join__field(graph: ALPHA)
  find(by: Search): String @join__field(graph: ZETA)
}

input Search @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  id: ID
}"""


comptime _INPUT_DEFAULT_KEPT = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  search(by: Search): String @join__field(graph: ALPHA)
  find(by: Search): String @join__field(graph: ZETA)
}

input Search @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  id: ID = "1"
}"""


def test_argument_nullability() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { user(id: ID): String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { user(id: ID!): String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARG_NON_NULL)


comptime _ARG_NON_NULL = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user(id: ID!): String
}"""


def test_argument_default_from_one_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { user(id: ID): String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    'type Query { user(id: ID = "1"): String @shareable }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARG_DEFAULT)


comptime _ARG_DEFAULT = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user(id: ID = "1"): String
}"""


def test_input_field_nullability() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "input Search { id: ID }\n"
                    "type Query { search(by: Search): String }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "input Search { id: ID! }\n"
                    "type Query { find(by: Search): String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INPUT_NULLABLE)


comptime _INPUT_NULLABLE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  search(by: Search): String @join__field(graph: ALPHA)
  find(by: Search): String @join__field(graph: ZETA)
}

input Search @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  id: ID! @join__field(graph: ALPHA, type: "ID") @join__field(graph: ZETA, type: "ID!")
}"""


def test_argument_missing_from_one_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\ntype Query { user(id: ID, extra:'
                    " String): String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { user(id: ID): String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _SHARED_ARGUMENT)


comptime _SHARED_ARGUMENT = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user(id: ID): String
}"""


def test_input_field_missing_from_one_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "input Search { id: ID name: String }\n"
                    "type Query { search(by: Search): String }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "input Search { id: ID }\n"
                    "type Query { find(by: Search): String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _SHARED_INPUT)


comptime _SHARED_INPUT = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  search(by: Search): String @join__field(graph: ALPHA)
  find(by: Search): String @join__field(graph: ZETA)
}

input Search @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  id: ID
}"""


def test_mutation_and_subscription_roots() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { q: String }\ntype Mutation { m:'
                    " String }\ntype Subscription { s: String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _ROOTS)


comptime _ROOTS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
  query: Query
  mutation: Mutation
  subscription: Subscription
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  q: String
}

type Mutation @join__type(graph: USERS) {
  m: String
}

type Subscription @join__type(graph: USERS) {
  s: String
}'''


def test_default_values() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\nenum Color { RED GREEN }\ninput Search {'
                    ' color: Color = RED limit: Int = 10 name: String = "Ada"'
                    ' }\ntype Query { user(id: ID = "1", color: Color = RED):'
                    " String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEFAULTS)


comptime _DEFAULTS = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user(id: ID = "1", color: Color = RED): String
}

enum Color @join__type(graph: USERS) {
  RED @join__enumValue(graph: USERS)
  GREEN @join__enumValue(graph: USERS)
}

input Search @join__type(graph: USERS) {
  color: Color = RED
  limit: Int = 10
  name: String = "Ada"
}"""


def test_field_type_nullability() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ntype Query { user: User }\ntype'
                    ' User @key(fields: "id") { id: ID! name: String!'
                    " @shareable }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ntype Query { review: User'
                    ' }\ntype User @key(fields: "id") { id: ID! name: String'
                    " @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _NULLABLE_FIELD)


comptime _NULLABLE_FIELD = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: User @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String @join__field(graph: REVIEWS, type: "String") @join__field(graph: USERS, type: "String!")
}"""


def test_specified_by_and_one_of() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\nscalar Date @specifiedBy(url:'
                    ' "https://example.com/date")\ninput Search @oneOf {\n '
                    " byId: ID\n  byName: String\n}\ntype Query { today: Date"
                    " search(by: Search): String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _SPECIFIED_BY)


comptime _SPECIFIED_BY = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @oneOf on INPUT_OBJECT

scalar Date @join__type(graph: USERS) @specifiedBy(url: "https://example.com/date")

type Query @join__type(graph: USERS) {
  today: Date
  search(by: Search): String
}

input Search @join__type(graph: USERS) @oneOf {
  byId: ID
  byName: String
}"""


def test_composed_directive() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema\n  @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"])\n  @link(url:'
                    ' "https://specs.example.com/foo/v1.0", import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\ndirective @foo(bar:'
                    " String) on FIELD_DEFINITION\ntype Query { hello: String"
                    ' @foo(bar: "baz") }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _COMPOSED)


comptime _COMPOSED = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.example.com/foo/v1.0", import: ["@foo"]) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @foo(bar: String) on FIELD_DEFINITION

type Query @join__type(graph: USERS) {
  hello: String @foo(bar: "baz")
}'''


def test_cost_and_list_size() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@listSize"])\ntype Query {\n '
                    " users(first: Int @cost(weight: 5)): [User]"
                    ' @listSize(assumedSize: 10, slicingArguments: ["first"])'
                    ' @cost(weight: 20)\n}\ntype User @key(fields: "id")'
                    " @cost(weight: 3) { id: ID! }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _COST_AND_LIST_SIZE)


comptime _COST_AND_LIST_SIZE = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(url: "https://specs.apollo.dev/cost/v0.1", import: ["@listSize"]) {
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
  overrideLabel: String
  contextArguments: [join__ContextArgument!]
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

input join__ContextArgument {
  name: String!
  type: String!
  context: String!
  selection: join__FieldValue!
}

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

scalar join__FieldValue

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @cost(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR

directive @listSize(
  assumedSize: Int
  slicingArguments: [String!]
  sizedFields: [String!]
  requireOneSlicingArgument: Boolean = true
) on FIELD_DEFINITION

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  users(first: Int @cost(weight: 5)): [User] @cost(weight: 20) @listSize(assumedSize: 10, slicingArguments: ["first"])
}

type User @join__type(graph: USERS, key: "id") @cost(weight: 3) {
  id: ID!
}'''


def test_auth_directives() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@authenticated", "@requiresScopes",'
                    ' "@policy"])\ntype Query {\n  me: User @authenticated\n '
                    ' public: String\n}\ntype User @key(fields: "id")'
                    ' @authenticated @requiresScopes(scopes: [["read"]])'
                    ' @policy(policies: [["admin"]]) {\n  id: ID!\n  name:'
                    ' String @requiresScopes(scopes: [["read", "pii"],'
                    ' ["admin"]])\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _AUTH_DIRECTIVES)


comptime _AUTH_DIRECTIVES = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/policy/v0.1", for: SECURITY) @link(url: "https://specs.apollo.dev/requiresScopes/v0.1", for: SECURITY) @link(url: "https://specs.apollo.dev/authenticated/v0.1", for: SECURITY) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @policy(policies: [[policy__Policy!]!]!) on ENUM | FIELD_DEFINITION | INTERFACE | OBJECT | SCALAR

scalar policy__Policy

directive @requiresScopes(scopes: [[requiresScopes__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

scalar requiresScopes__Scope

directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  me: User @authenticated
  public: String
}

type User @join__type(graph: USERS, key: "id") @authenticated @policy(policies: [["admin"]]) @requiresScopes(scopes: [["read"]]) {
  id: ID!
  name: String @requiresScopes(scopes: [["read", "pii"], ["admin"]])
}'''


def test_deprecated() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query {\n  user(id: ID'
                    ' @deprecated(reason: "use other")): User @deprecated\n '
                    ' old: String @deprecated(reason: "gone")\n}\ntype User'
                    ' @key(fields: "id") { id: ID! }\nenum Color { RED'
                    ' @deprecated GREEN @deprecated(reason: "use RED") }\ninput'
                    ' ById { id: ID @deprecated(reason: "legacy") }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEPRECATED)


comptime _DEPRECATED = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user(id: ID @deprecated(reason: "use other")): User @deprecated
  old: String @deprecated(reason: "gone")
}

type User @join__type(graph: USERS, key: "id") {
  id: ID!
}

enum Color @join__type(graph: USERS) {
  RED @join__enumValue(graph: USERS) @deprecated
  GREEN @join__enumValue(graph: USERS) @deprecated(reason: "use RED")
}

input ById @join__type(graph: USERS) {
  id: ID @deprecated(reason: "legacy")
}"""


def test_descriptions() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n"""A person."""\ntype User @key(fields: "id")'
                    ' {\n  """The id."""\n  id: ID!\n  "Given name."\n '
                    ' name(style: String): String\n}\n"""A color."""\nenum'
                    ' Color {\n  "Red."\n  RED\n}\n"""Lookup."""\ninput ById'
                    ' {\n  """The id."""\n  id: ID!\n}\ntype Query {\n  """Find'
                    ' a user."""\n  user(\n    """By id."""\n    by: ById\n  ):'
                    " User\n  color: Color\n}\nscalar Date\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DESCRIPTIONS)


comptime _DESCRIPTIONS = '''enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

scalar Date @join__type(graph: USERS)

"""
A person.
"""
type User @join__type(graph: USERS, key: "id") {
  """
  The id.
  """
  id: ID!
  """
  Given name.
  """
  name(style: String): String
}

type Query @join__type(graph: USERS) {
  """
  Find a user.
  """
  user("""
  By id.
  """
  by: ById): User
  color: Color
}

"""
A color.
"""
enum Color @join__type(graph: USERS) {
  """
  Red.
  """
  RED @join__enumValue(graph: USERS)
}

"""
Lookup.
"""
input ById @join__type(graph: USERS) {
  """
  The id.
  """
  id: ID!
}'''


def test_used_overridden() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\ntype Query { book: Book }\ninterface Product {'
                    " sku: String }\ntype Book implements Product @key(fields:"
                    ' "id") { id: ID! sku: String }\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\ntype Query { review: Book'
                    " }\ninterface Product { sku: String }\ntype Book"
                    ' implements Product @key(fields: "id") { id: ID! sku:'
                    ' String @override(from: "users") }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _USED_OVERRIDDEN)


comptime _USED_OVERRIDDEN = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Book @join__field(graph: REVIEWS)
  book: Book @join__field(graph: USERS)
}

type Book implements Product @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") @join__implements(graph: REVIEWS, interface: "Product") @join__implements(graph: USERS, interface: "Product") {
  id: ID!
  sku: String @join__field(graph: REVIEWS, override: "users") @join__field(graph: USERS, usedOverridden: true)
}

interface Product @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  sku: String
}"""


def test_context_arguments() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext"])\ntype Member'
                    ' @key(fields: "id") @context(name: "memberCtx") {\n  id:'
                    " ID!\n  plan: String!\n  wallet: Wallet!\n}\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}\nextend type Wallet'
                    ' {\n  apply(plan: String @fromContext(field: "$memberCtx {'
                    ' plan }")): Int!\n}\ntype Query {\n  member(id: ID!):'
                    " Member\n}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _CONTEXT_ARGUMENTS)


comptime _CONTEXT_ARGUMENTS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(url: "https://specs.apollo.dev/context/v0.1", for: SECURITY) {
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
  overrideLabel: String
  contextArguments: [join__ContextArgument!]
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

input join__ContextArgument {
  name: String!
  type: String!
  context: String!
  selection: join__FieldValue!
}

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

scalar join__FieldValue

directive @context(name: String!) repeatable on OBJECT | INTERFACE | UNION

directive @context__fromContext(field: context__ContextFieldValue) on ARGUMENT_DEFINITION

scalar context__ContextFieldValue

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  BENEFITS @join__graph(name: "benefits", url: "")
}

type Member @join__type(graph: BENEFITS, key: "id") @context(name: "benefits__memberCtx") {
  id: ID!
  plan: String!
  wallet: Wallet!
}

type Wallet @join__type(graph: BENEFITS, key: "id") {
  id: ID!
  apply: Int! @join__field(
    graph: BENEFITS
    contextArguments: [{context: "benefits__memberCtx", name: "plan", type: "String", selection: " { plan }"}]
  )
}

type Query @join__type(graph: BENEFITS) {
  member(id: ID!): Member
}'''


def test_federation_v1_omits_an_unused_external_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "type Query { user: User }\n"
                    'type User @key(fields: "id") {\n'
                    "  id: ID!\n"
                    "  name: String\n"
                    "  nickname: String\n"
                    "}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "type Query { review: String }\n"
                    'extend type User @key(fields: "id") {\n'
                    "  id: ID! @external\n"
                    "  name: String @external\n"
                    "  nickname: String @external\n"
                    '  reviews: [String] @requires(fields: "name")\n'
                    "}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _V1_UNUSED_EXTERNAL)
    var only = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "type Query { user: User }\n"
                    'type User @key(fields: "id") {\n'
                    "  id: ID!\n"
                    "  name: String\n"
                    "}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "type Query { review: String }\n"
                    'extend type User @key(fields: "id") {\n'
                    "  id: ID! @external\n"
                    "  name: String @external\n"
                    "  nickname: String @external\n"
                    '  reviews: [String] @requires(fields: "name")\n'
                    "}\n"
                ),
            ),
        ]
    )
    assert_equal(len(only.errors), 0)
    assert_equal(_from_graphs(only.supergraph_sdl), _V1_EXTERNAL_ONLY)


def test_federation_v1_keeps_a_provided_external_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "type Query { user: User }\n"
                    'type User @key(fields: "id") {\n'
                    "  id: ID!\n"
                    "  nickname: String\n"
                    "}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "type Query { review: Review }\n"
                    'type Review @key(fields: "id") {\n'
                    "  id: ID!\n"
                    '  author: User @provides(fields: "nickname")\n'
                    "}\n"
                    'extend type User @key(fields: "id") {\n'
                    "  id: ID! @external\n"
                    "  nickname: String @external\n"
                    "}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _V1_PROVIDED)


comptime _V1_UNUSED_EXTERNAL = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  nickname: String @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "name")
}"""


comptime _V1_EXTERNAL_ONLY = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "name")
}"""


comptime _V1_PROVIDED = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User @join__field(graph: REVIEWS, provides: "nickname")
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  nickname: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  id: ID!
}"""


def test_argument_description_from_a_later_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "type Query { user(by: ID): String @shareable }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "type Query {\n"
                    '  """Find."""\n'
                    "  user(\n"
                    '    """By id."""\n'
                    "    by: ID\n"
                    "  ): String @shareable\n"
                    "}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARG_DESCRIPTION_LATER)
    var first = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "type Query {\n"
                    "  user(\n"
                    '    """First."""\n'
                    "    by: ID\n"
                    "  ): String @shareable\n"
                    "}\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "type Query {\n"
                    "  user(\n"
                    '    """Second."""\n'
                    "    by: ID\n"
                    "  ): String @shareable\n"
                    "}\n"
                ),
            ),
        ]
    )
    assert_equal(len(first.errors), 0)
    assert_equal(_from_graphs(first.supergraph_sdl), _ARG_DESCRIPTION_FIRST)


comptime _ARG_DESCRIPTION_LATER = '''enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  """
  Find.
  """
  user("""
  By id.
  """
  by: ID): String
}'''


comptime _ARG_DESCRIPTION_FIRST = '''enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user("""
  First.
  """
  by: ID): String
}'''


def test_composed_directive_on_arguments_inputs_and_enums() raises:
    var places = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema\n  @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"])\n  @link(url:'
                    ' "https://specs.example.com/foo/v1.0", import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\ndirective @foo(name:'
                    " String) on FIELD_DEFINITION | ARGUMENT_DEFINITION |"
                    " INPUT_FIELD_DEFINITION | ENUM_VALUE | ENUM |"
                    " INPUT_OBJECT\ntype Query { user(by: ID @foo(name:"
                    ' "arg")): String }\ninput ById @foo(name: "inputtype") {\n'
                    '  id: ID @foo(name: "input")\n}\nenum Color @foo(name:'
                    ' "enum") {\n  RED @foo(name: "value")\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(places.errors), 0)
    assert_equal(_from_graphs(places.supergraph_sdl), _COMPOSED_PLACES)
    var later = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "type Query { user(by: ID): String @shareable }\n"
                    "input ById { id: ID }\n"
                    "enum Color { RED }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@composeDirective", "@shareable"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) on ARGUMENT_DEFINITION |"
                    " ENUM_VALUE | INPUT_FIELD_DEFINITION\n"
                    'type Query { user(by: ID @foo(name: "arg")): String'
                    " @shareable }\n"
                    'input ById { id: ID @foo(name: "input") }\n'
                    'enum Color { RED @foo(name: "value") }\n'
                ),
            ),
        ]
    )
    assert_equal(len(later.errors), 0)
    assert_equal(_from_graphs(later.supergraph_sdl), _COMPOSED_LATER)


comptime _COMPOSED_PLACES = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @foo(name: String) on FIELD_DEFINITION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE | ENUM | INPUT_OBJECT

type Query @join__type(graph: USERS) {
  user(by: ID @foo(name: "arg")): String
}

enum Color @foo(name: "enum") @join__type(graph: USERS) {
  RED @foo(name: "value") @join__enumValue(graph: USERS)
}

input ById @foo(name: "inputtype") @join__type(graph: USERS) {
  id: ID @foo(name: "input")
}"""


comptime _COMPOSED_LATER = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

directive @foo(name: String) on ARGUMENT_DEFINITION | ENUM_VALUE | INPUT_FIELD_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user(by: ID @foo(name: "arg")): String
}

enum Color @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  RED @foo(name: "value") @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA)
}

input ById @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  id: ID @foo(name: "input")
}"""


def test_composed_directive_merges_across_subgraphs() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(bar: String) on FIELD_DEFINITION\n"
                    'type Query { hello: String @foo(bar: "a") }\n'
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    'directive @foo(bar: String! = "x", extra: Int) repeatable'
                    " on FIELD_DEFINITION | OBJECT\n"
                    'type Query { other: String @foo(bar: "b", extra: 1) }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _COMPOSED_MERGED)


comptime _COMPOSED_MERGED = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

directive @foo(bar: String! = "x", extra: Int) repeatable on FIELD_DEFINITION | OBJECT

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  hello: String @foo(bar: "a") @join__field(graph: ALPHA)
  other: String @foo(bar: "b", extra: 1) @join__field(graph: ZETA)
}"""


def test_composed_directive_argument_tags() raises:
    var one = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective", "@tag", "@inaccessible"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    'directive @foo(bar: String @tag(name: "a")'
                    " @inaccessible) on FIELD_DEFINITION\n"
                    'type Query { hello: String @foo(bar: "a") }\n'
                ),
            )
        ]
    )
    assert_equal(len(one.errors), 0)
    assert_equal(_from_graphs(one.supergraph_sdl), _DIRECTIVE_ARG_TAGS)
    var later = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective", "@tag", "@inaccessible"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    'directive @foo(bar: String @tag(name: "a")) on'
                    " FIELD_DEFINITION\n"
                    'type Query { hello: String @foo(bar: "a") }\n'
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective", "@tag", "@inaccessible"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    'directive @foo(bar: String @tag(name: "b")'
                    " @inaccessible) on FIELD_DEFINITION\n"
                    'type Query { other: String @foo(bar: "b") }\n'
                ),
            ),
        ]
    )
    assert_equal(len(later.errors), 0)
    assert_equal(_from_graphs(later.supergraph_sdl), _DIRECTIVE_ARG_TAGS_LATER)


comptime _DIRECTIVE_ARG_TAGS = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @foo(bar: String @tag(name: "a") @inaccessible) on FIELD_DEFINITION

type Query @join__type(graph: USERS) {
  hello: String @foo(bar: "a")
}"""


comptime _DIRECTIVE_ARG_TAGS_LATER = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

directive @foo(bar: String @tag(name: "a") @tag(name: "b") @inaccessible) on FIELD_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  hello: String @foo(bar: "a") @join__field(graph: ALPHA)
  other: String @foo(bar: "b") @join__field(graph: ZETA)
}"""


def test_input_enum_keeps_shared_values() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "enum Color { RED GREEN }\n"
                    "input Filter { color: Color }\n"
                    "type Query { q: String }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "enum Color { RED BLUE }\n"
                    "input Filter { color: Color }\n"
                    "type Query { z: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INPUT_ENUM)
    var output = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "enum Color { RED GREEN }\n"
                    "type Query { color: Color }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n'
                    "enum Color { RED BLUE }\n"
                    "type Query { shade: Color }\n"
                ),
            ),
        ]
    )
    assert_equal(len(output.errors), 0)
    assert_equal(_from_graphs(output.supergraph_sdl), _OUTPUT_ENUM)


comptime _INPUT_ENUM = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  q: String @join__field(graph: ALPHA)
  z: String @join__field(graph: ZETA)
}

enum Color @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  RED @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA)
}

input Filter @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  color: Color
}"""


comptime _OUTPUT_ENUM = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  color: Color @join__field(graph: ALPHA)
  shade: Color @join__field(graph: ZETA)
}

enum Color @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  RED @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA)
  GREEN @join__enumValue(graph: ALPHA)
  BLUE @join__enumValue(graph: ZETA)
}"""


def test_cost_directive_aliases() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", {name: "@cost", as: "@expense"}, {name:'
                    ' "@listSize", as: "@size"}])\ntype Query {\n  users(first:'
                    " Int @expense(weight: 5)): [User] @size(assumedSize: 10,"
                    ' slicingArguments: ["first"]) @expense(weight:'
                    ' 20)\n}\ntype User @key(fields: "id") @expense(weight: 3)'
                    " { id: ID! }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _COST_ALIAS)


comptime _COST_ALIAS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(
  url: "https://specs.apollo.dev/cost/v0.1"
  import: [{name: "@cost", as: "@expense"}, {name: "@listSize", as: "@size"}]
) {
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
  overrideLabel: String
  contextArguments: [join__ContextArgument!]
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

input join__ContextArgument {
  name: String!
  type: String!
  context: String!
  selection: join__FieldValue!
}

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

scalar join__FieldValue

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @expense(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR

directive @size(
  assumedSize: Int
  slicingArguments: [String!]
  sizedFields: [String!]
  requireOneSlicingArgument: Boolean = true
) on FIELD_DEFINITION

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  users(first: Int @expense(weight: 5)): [User] @expense(weight: 20) @size(assumedSize: 10, slicingArguments: ["first"])
}

type User @join__type(graph: USERS, key: "id") @expense(weight: 3) {
  id: ID!
}'''


def test_list_size_merges_across_subgraphs() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable", "@listSize"])\n'
                    "type Query {\n"
                    "  users(first: Int, last: Int): [String] @shareable"
                    ' @listSize(assumedSize: 10, slicingArguments: ["first"])\n'
                    "}\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable", "@listSize"])\n'
                    "type Query {\n"
                    "  users(first: Int, last: Int): [String] @shareable"
                    ' @listSize(assumedSize: 4, slicingArguments: ["last"],'
                    " requireOneSlicingArgument: false)\n"
                    "}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _LIST_SIZE_MERGED)


comptime _LIST_SIZE_MERGED = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  users(first: Int, last: Int): [String] @listSize(
    requireOneSlicingArgument: false
    assumedSize: 10
    slicingArguments: ["first", "last"]
  )
}"""


def test_list_size_drops_a_partial_slicing_argument() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable", "@listSize"])\n'
                    "type Query {\n"
                    "  users(first: Int, after: Int): [String] @shareable"
                    ' @listSize(slicingArguments: ["first", "after"])\n'
                    "}\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable", "@listSize"])\n'
                    "type Query {\n"
                    "  users(first: Int): [String] @shareable"
                    ' @listSize(slicingArguments: ["first"])\n'
                    "}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _LIST_SIZE_PARTIAL)


comptime _LIST_SIZE_PARTIAL = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  users(first: Int): [String] @listSize(slicingArguments: ["first"])
}"""


def test_interface_list_size_prints_require_one() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n'
                    "interface Node {\n"
                    "  items(first: Int): [String]"
                    ' @listSize(slicingArguments: ["first"])\n'
                    "}\n"
                    "type User implements Node {\n"
                    "  items(first: Int): [String]"
                    ' @listSize(slicingArguments: ["first"])\n'
                    "}\n"
                    "type Query { node: Node }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_LIST_SIZE)


comptime _INTERFACE_LIST_SIZE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type User implements Node @join__type(graph: USERS) @join__implements(graph: USERS, interface: "Node") {
  items(first: Int): [String] @listSize(slicingArguments: ["first"])
}

type Query @join__type(graph: USERS) {
  node: Node
}

interface Node @join__type(graph: USERS) {
  items(first: Int): [String] @listSize(requireOneSlicingArgument: true, slicingArguments: ["first"])
}"""


def test_renamed_tag_prints_as_tag() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", {name: "@tag", as: "@category"}])\ntype Query {'
                    ' hello: String @category(name: "a") }\ntype User'
                    ' @key(fields: "id") @category(name: "b") { id: ID! }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _TAG_ALIAS)


comptime _TAG_ALIAS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/tag/v0.3") {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello: String @tag(name: "a")
}

type User @join__type(graph: USERS, key: "id") @tag(name: "b") {
  id: ID!
}'''


def test_join_field_prints_provides_before_requires() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { reviews: [Review] }\ntype Review'
                    ' @key(fields: "id") { id: ID! country: String }\ntype User'
                    ' @key(fields: "id") { id: ID! name: String }\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@requires", "@external"])\ntype'
                    ' Query { review: Review }\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  country: String @external\n  author: User"
                    ' @provides(fields: "name") @requires(fields:'
                    ' "country")\n}\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String @external\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _PROVIDES_AND_REQUIRES)


comptime _PROVIDES_AND_REQUIRES = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  reviews: [Review] @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  country: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  author: User @join__field(graph: REVIEWS, provides: "name", requires: "country")
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  name: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  id: ID!
}"""


def test_composed_directive_import_alias() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' [{name: "@foo", as: "@bar"}])\n'
                    '  @composeDirective(name: "@bar")\n'
                    "directive @bar(x: String) on FIELD_DEFINITION\n"
                    'type Query { hello: String @bar(x: "a") }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _COMPOSED_ALIAS)


comptime _COMPOSED_ALIAS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(
  url: "https://specs.example.com/foo/v1.0"
  import: [{name: "@foo", as: "@bar"}]
) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @bar(x: String) on FIELD_DEFINITION

type Query @join__type(graph: USERS) {
  hello: String @bar(x: "a")
}'''


def test_feature_link_omits_type_imports() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://specs.example.com/bar/v1.0")\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' ["Foo", "@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "scalar Foo\n"
                    "directive @foo on FIELD_DEFINITION\n"
                    "type Query { hello: Foo @foo }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _FEATURE_LINK_FILTER)


def test_feature_link_keeps_the_highest_version() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.0", import:'
                    ' ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo on FIELD_DEFINITION\n"
                    "type Query { a: String @foo }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.1", import:'
                    ' ["@foo", "@bar"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    '  @composeDirective(name: "@bar")\n'
                    "directive @foo on FIELD_DEFINITION\n"
                    "directive @bar on FIELD_DEFINITION\n"
                    "type Query { z: String @bar }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _FEATURE_LINK_VERSION)


comptime _FEATURE_LINK_FILTER = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.example.com/foo/v1.0", import: ["@foo"]) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @foo on FIELD_DEFINITION

scalar Foo @join__type(graph: USERS)

type Query @join__type(graph: USERS) {
  hello: Foo @foo
}'''


comptime _FEATURE_LINK_VERSION = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.example.com/foo/v1.1", import: ["@foo", "@bar"]) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

directive @foo on FIELD_DEFINITION

directive @bar on FIELD_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  a: String @foo @join__field(graph: ALPHA)
  z: String @bar @join__field(graph: ZETA)
}'''


def test_feature_link_v1_10_stays_above_v1_9() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://specs.example.com/foo/v1.9", import:'
                    ' ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo on FIELD_DEFINITION\n"
                    "type Query { a: String @foo }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema\n  @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"])\n  @link(url:'
                    ' "https://specs.example.com/foo/v1.10", import:'
                    ' ["@foo"])\n  @composeDirective(name: "@foo")\ndirective'
                    " @foo on FIELD_DEFINITION\ntype Query { z: String @foo }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _FEATURE_LINK_V1_10)


comptime _FEATURE_LINK_V1_10 = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.example.com/foo/v1.10", import: ["@foo"]) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

directive @foo on FIELD_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  a: String @foo @join__field(graph: ALPHA)
  z: String @foo @join__field(graph: ZETA)
}'''


def test_executable_directive_locations() raises:
    var shared = compose_subgraphs(
        [
            _sg(
                "alpha",
                "directive @foo on FIELD\ntype Query { hello: String }\n",
            ),
            _sg(
                "zeta",
                (
                    "directive @foo on FIELD | QUERY\ntype Query { hello:"
                    " String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(shared.errors), 0)
    assert_equal(_from_graphs(shared.supergraph_sdl), _EXECUTABLE_FIELD)
    var dropped = compose_subgraphs(
        [
            _sg(
                "alpha",
                "directive @foo on FIELD\ntype Query { hello: String }\n",
            ),
            _sg(
                "zeta",
                "directive @foo on QUERY\ntype Query { hello: String }\n",
            ),
        ]
    )
    assert_equal(len(dropped.errors), 0)
    assert_equal(dropped.supergraph_sdl.find("directive @foo"), -1)
    var partial = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "directive @foo(bar: String) on FIELD\n"
                    "type Query { hello: String }\n"
                ),
            ),
            _sg("zeta", "type Query { hello: String }\n"),
        ]
    )
    assert_equal(len(partial.errors), 0)
    assert_equal(partial.supergraph_sdl.find("directive @foo"), -1)
    var alone = compose_subgraphs(
        [
            _sg(
                "alpha",
                "directive @foo on FIELD\ntype Query { hello: String }\n",
            ),
            _sg("zeta", "type Query { hello: String }\n"),
        ]
    )
    assert_equal(len(alone.errors), 0)
    assert_equal(_from_graphs(alone.supergraph_sdl), _EXECUTABLE_FIELD)
    var schema = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "directive @foo on FIELD | FIELD_DEFINITION\n"
                    "type Query { hello: String }\n"
                ),
            ),
            _sg(
                "zeta",
                "directive @foo on FIELD\ntype Query { hello: String }\n",
            ),
        ]
    )
    assert_equal(len(schema.errors), 0)
    assert_equal(_from_graphs(schema.supergraph_sdl), _EXECUTABLE_FIELD)


comptime _EXECUTABLE_FIELD = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

directive @foo on FIELD

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  hello: String
}"""


def test_requires_omits_key_fields() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\ntype User'
                    ' @key(fields: "id") { id: ID! name: String }\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    ' Review }\ntype Review @key(fields: "id") { id: ID!'
                    ' author: User }\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n  name: String @external\n  reviews:"
                    ' [String] @requires(fields: "id name")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_WITHOUT_KEY)


comptime _REQUIRES_WITHOUT_KEY = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "name")
}"""


def test_requires_keeps_fields_outside_every_key() raises:
    var shared = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\ntype User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!'
                    " email: String name: String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    ' Review }\ntype Review @key(fields: "id") { id: ID!'
                    ' author: User }\nextend type User @key(fields: "id")'
                    ' @key(fields: "id email") {\n  id: ID! @external\n  email:'
                    " String @external\n  name: String @external\n  reviews:"
                    ' [String] @requires(fields: "id email name")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(shared.errors), 0)
    assert_equal(_from_graphs(shared.supergraph_sdl), _REQUIRES_SHARED_KEY)
    var only = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\ntype User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!'
                    " email: String name: String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    ' Review }\ntype Review @key(fields: "id") { id: ID!'
                    ' author: User }\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n  reviews: [String] @requires(fields:"
                    ' "id")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(only.errors), 0)
    assert_equal(_from_graphs(only.supergraph_sdl), _REQUIRES_ONLY_KEY)


comptime _REQUIRES_SHARED_KEY = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: REVIEWS, key: "id email", extension: true) @join__type(graph: USERS, key: "id") @join__type(graph: USERS, key: "email") {
  id: ID!
  email: String
  name: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "email name")
}"""


comptime _REQUIRES_ONLY_KEY = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") @join__type(graph: USERS, key: "email") {
  id: ID!
  reviews: [String] @join__field(graph: REVIEWS)
  email: String @join__field(graph: USERS)
  name: String @join__field(graph: USERS)
}"""


def test_requires_uses_one_space_between_fields() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\ntype User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!'
                    " email: String name: String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    ' Review }\ntype Review @key(fields: "id") { id: ID!'
                    ' author: User }\nextend type User @key(fields: "id")'
                    ' @key(fields: "email") {\n  id: ID! @external\n  email:'
                    " String @external\n  name: String @external\n  reviews:"
                    ' [String] @requires(fields: "id  email, name")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_SPACED)


comptime _REQUIRES_SPACED = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: REVIEWS, key: "email", extension: true) @join__type(graph: USERS, key: "id") @join__type(graph: USERS, key: "email") {
  id: ID!
  email: String
  name: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "id email name")
}"""


def test_provides_uses_one_space_between_fields() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { users: [User] }\ntype User'
                    ' @key(fields: "id") {\n  id: ID! name: String email:'
                    " String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\ntype Query { review:'
                    ' Review }\ntype Review @key(fields: "id") {\n  id: ID!\n '
                    ' author: User @provides(fields: "name  email")\n}\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  email: String @external\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _PROVIDES_SPACED)


comptime _PROVIDES_SPACED = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  users: [User] @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User @join__field(graph: REVIEWS, provides: "name email")
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  name: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  id: ID!
  email: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
}"""


def test_provides_compacts_a_nested_selection() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { users: [User] }\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  address:'
                    ' Address\n}\ntype Address @key(fields: "id") {\n  id:'
                    " ID!\n  city: String\n  zip: String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\ntype Query { review:'
                    ' Review }\ntype Review @key(fields: "id") {\n  id: ID!\n '
                    ' author: User @provides(fields: "address { city  zip'
                    ' }")\n}\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " address: Address @external\n}\ntype Address @key(fields:"
                    ' "id") {\n  id: ID!\n  city: String @external\n  zip:'
                    " String @external\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _PROVIDES_NESTED)


comptime _PROVIDES_NESTED = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  users: [User] @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User @join__field(graph: REVIEWS, provides: "address{city zip}")
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  address: Address @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  id: ID!
}

type Address @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  city: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  id: ID!
  zip: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
}"""


def test_requires_compacts_a_nested_selection() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\ntype User'
                    ' @key(fields: "id") { id: ID! address: Address }\ntype'
                    ' Address @key(fields: "id") {\n  id: ID! city: String zip:'
                    " String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    ' Review }\ntype Review @key(fields: "id") { id: ID!'
                    ' author: User }\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n  address: Address @external\n "
                    ' reviews: [String] @requires(fields: "address { city  zip'
                    ' }")\n}\nextend type Address @key(fields: "id") {\n  id:'
                    " ID! @external\n  city: String @external\n  zip: String"
                    " @external\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_NESTED)


comptime _REQUIRES_NESTED = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  address: Address @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "address{city zip}")
}

type Address @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  city: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  zip: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  id: ID!
}"""


def test_requires_keeps_a_nested_key_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\ntype User'
                    ' @key(fields: "address { id }") { address: Address }\ntype'
                    ' Address @key(fields: "id") { id: ID! city: String }\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    ' Review }\ntype Review @key(fields: "id") { id: ID!'
                    ' author: User }\nextend type User @key(fields: "address {'
                    ' id }") {\n  address: Address @external\n  reviews:'
                    ' [String] @requires(fields: "address { id city'
                    ' }")\n}\nextend type Address @key(fields: "id") {\n  id:'
                    " ID! @external\n  city: String @external\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_NESTED_KEY)


comptime _REQUIRES_NESTED_KEY = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: Review @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  author: User
}

type User @join__type(graph: REVIEWS, key: "address { id }", extension: true) @join__type(graph: USERS, key: "address { id }") {
  address: Address
  reviews: [String] @join__field(graph: REVIEWS, requires: "address{id city}")
}

type Address @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  city: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
}"""


def test_renamed_inaccessible_prints_as_inaccessible() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", {name: "@inaccessible", as: "@hidden"}])\ntype'
                    " Query { hello: String @hidden visible: String }\ntype"
                    ' User @key(fields: "id") @hidden { id: ID! }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _HIDDEN_INACCESSIBLE)


comptime _HIDDEN_INACCESSIBLE = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello: String @inaccessible
  visible: String
}

type User @join__type(graph: USERS, key: "id") @inaccessible {
  id: ID!
}'''


def test_renamed_authenticated_prints_as_authenticated() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", {name: "@authenticated", as: "@auth"}])\ntype'
                    " Query { hello: String @auth }\ntype User @key(fields:"
                    ' "id") @auth { id: ID! }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _AUTH_ALIAS)


comptime _AUTH_ALIAS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/authenticated/v0.1", for: SECURITY) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello: String @authenticated
}

type User @join__type(graph: USERS, key: "id") @authenticated {
  id: ID!
}'''


def test_renamed_policy_prints_as_policy() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", {name: "@policy", as: "@rule"}])\ntype Query {'
                    ' hello: String @rule(policies: [["admin"]]) }\ntype User'
                    ' @key(fields: "id") @rule(policies: [["reader"]]) { id:'
                    " ID! }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _POLICY_ALIAS)


comptime _POLICY_ALIAS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/policy/v0.1", for: SECURITY) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @policy(policies: [[policy__Policy!]!]!) on ENUM | FIELD_DEFINITION | INTERFACE | OBJECT | SCALAR

scalar policy__Policy

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello: String @policy(policies: [["admin"]])
}

type User @join__type(graph: USERS, key: "id") @policy(policies: [["reader"]]) {
  id: ID!
}'''


def test_renamed_requires_scopes_prints_as_requires_scopes() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", {name: "@requiresScopes", as: "@need"}])\ntype'
                    ' Query { hello: String @need(scopes: [["read"]]) }\ntype'
                    ' User @key(fields: "id") @need(scopes: [["write"]]) { id:'
                    " ID! }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, _SCOPES_ALIAS)


comptime _SCOPES_ALIAS = '''schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url: "https://specs.apollo.dev/requiresScopes/v0.1", for: SECURITY) {
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

directive @join__implements(graph: join__Graph!, interface: String!) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(graph: join__Graph!, member: String!) repeatable on UNION

scalar join__FieldSet

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY
  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

directive @requiresScopes(scopes: [[requiresScopes__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

scalar requiresScopes__Scope

enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello: String @requiresScopes(scopes: [["read"]])
}

type User @join__type(graph: USERS, key: "id") @requiresScopes(scopes: [["write"]]) {
  id: ID!
}'''


def test_field_directives_follow_join_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@tag", "@inaccessible", "@cost",'
                    ' "@shareable"])\ntype Query { user: User }\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @shareable @tag(name: "public") @inaccessible'
                    ' @cost(weight: 2) @deprecated(reason: "old")\n}\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\ntype Query { review: String'
                    ' }\ntype User @key(fields: "id") { id: ID! }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _FIELD_DIRECTIVE_ORDER)


comptime _FIELD_DIRECTIVE_ORDER = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user: User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id") @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String @join__field(graph: USERS) @tag(name: "public") @inaccessible @cost(weight: 2) @deprecated(reason: "old")
}"""


def test_union_prints_tag_and_inaccessible_after_members() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@tag", "@inaccessible"])\ntype Query { product: Product'
                    " @inaccessible ok: String }\ntype Book { title: String"
                    " }\ntype Film { title: String }\nunion Product @tag(name:"
                    ' "media") @inaccessible = Book | Film\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _UNION_MARKS)


comptime _UNION_MARKS = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  product: Product @inaccessible
  ok: String
}

type Book @join__type(graph: USERS) {
  title: String
}

type Film @join__type(graph: USERS) {
  title: String
}

union Product @join__type(graph: USERS) @join__unionMember(graph: USERS, member: "Book") @join__unionMember(graph: USERS, member: "Film") @tag(name: "media") @inaccessible = Book | Film"""


def test_requires_keeps_a_field_argument() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\nenum'
                    ' Language { EN }\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name(lang: Language): String\n  address:"
                    ' Address\n}\ntype Address @key(fields: "id") { id: ID!'
                    " city(kind: String): String }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    " String }\nenum Language { EN }\nextend type User"
                    ' @key(fields: "id") {\n  id: ID! @external\n  name(lang:'
                    " Language): String @external\n  reviews: [String]"
                    ' @requires(fields: "id name(lang: \\"en\\")")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_ARGUMENT)


comptime _REQUIRES_ARGUMENT = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  name(lang: Language): String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "name(lang:\\"en\\")")
  address: Address @join__field(graph: USERS)
}

type Address @join__type(graph: USERS, key: "id") {
  id: ID!
  city(kind: String): String
}

enum Language @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  EN @join__enumValue(graph: REVIEWS) @join__enumValue(graph: USERS)
}"""


def test_requires_compacts_a_nested_field_argument() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\nenum'
                    ' Language { EN }\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name(lang: Language): String\n  address:"
                    ' Address\n}\ntype Address @key(fields: "id") { id: ID!'
                    " city(kind: String): String }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    ' String }\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  address: Address @external\n  reviews:"
                    ' [String] @requires(fields: "address { city(kind:'
                    ' \\"home\\") }")\n}\nextend type Address @key(fields:'
                    ' "id") {\n  id: ID! @external\n  city(kind: String):'
                    " String @external\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_NESTED_ARGUMENT)


comptime _REQUIRES_NESTED_ARGUMENT = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  address: Address @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "address{city(kind:\\"home\\")}")
  name(lang: Language): String @join__field(graph: USERS)
}

type Address @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  city(kind: String): String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  id: ID!
}

enum Language @join__type(graph: USERS) {
  EN @join__enumValue(graph: USERS)
}"""


def test_requires_prints_inline_fragments() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { review(id: ID!): Review }\nunion'
                    ' Product = Book | Film\ntype Book @key(fields: "id") { id:'
                    ' ID! title: String }\ntype Film @key(fields: "id") { id:'
                    ' ID! duration: Int }\ntype Review @key(fields: "id") { id:'
                    " ID! product: Product }\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { latest:'
                    ' Review }\nextend type Review @key(fields: "id") {\n  id:'
                    " ID! @external\n  product: Product @external\n  score: Int"
                    ' @requires(fields: "product { ... on Book { title } ... on'
                    ' Film { duration } }")\n}\nextend type Book @key(fields:'
                    ' "id") { id: ID! @external title: String @external'
                    ' }\nextend type Film @key(fields: "id") { id: ID!'
                    " @external duration: Int @external }\nunion Product = Book"
                    " | Film\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_FRAGMENTS)


comptime _REQUIRES_FRAGMENTS = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  latest: Review @join__field(graph: REVIEWS)
  review(id: ID!): Review @join__field(graph: USERS)
}

type Review @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  product: Product @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  score: Int @join__field(graph: REVIEWS, requires: "product{...on Book{title}...on Film{duration}}")
}

type Book @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  title: String @join__field(graph: USERS)
  id: ID!
}

type Film @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  duration: Int @join__field(graph: USERS)
  id: ID!
}

union Product @join__type(graph: REVIEWS) @join__type(graph: USERS) @join__unionMember(graph: REVIEWS, member: "Book") @join__unionMember(graph: REVIEWS, member: "Film") @join__unionMember(graph: USERS, member: "Book") @join__unionMember(graph: USERS, member: "Film") = Book | Film"""


def test_provides_on_a_union_keeps_its_source_text() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { book(id: ID!): Book }\ntype Book'
                    ' @key(fields: "id") { id: ID! title: String author:'
                    " String }\n"
                ),
            ),
            _sg(
                "films",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { film(id: ID!): Film }\ntype Film'
                    ' @key(fields: "id") { id: ID! title: String director:'
                    " String }\n"
                ),
            ),
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\ntype Query { search:'
                    ' Product @provides(fields: "... on Book { author } ... on'
                    ' Film { director }") }\nunion Product = Book |'
                    ' Film\nextend type Book @key(fields: "id") { id: ID!'
                    " @external author: String @external }\nextend type Film"
                    ' @key(fields: "id") { id: ID! @external director: String'
                    " @external }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _PROVIDES_UNION)


comptime _PROVIDES_UNION = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
  FILMS @join__graph(name: "films", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: BOOKS) @join__type(graph: FILMS) @join__type(graph: USERS) {
  book(id: ID!): Book @join__field(graph: BOOKS)
  film(id: ID!): Film @join__field(graph: FILMS)
  search: Product @join__field(graph: USERS, provides: "... on Book { author } ... on Film { director }")
}

type Book @join__type(graph: BOOKS, key: "id") @join__type(graph: USERS, key: "id", extension: true) {
  id: ID!
  title: String @join__field(graph: BOOKS)
  author: String @join__field(graph: BOOKS)
}

type Film @join__type(graph: FILMS, key: "id") @join__type(graph: USERS, key: "id", extension: true) {
  id: ID!
  title: String @join__field(graph: FILMS)
  director: String @join__field(graph: FILMS)
}

union Product @join__type(graph: USERS) @join__unionMember(graph: USERS, member: "Book") @join__unionMember(graph: USERS, member: "Film") = Book | Film"""


def test_requires_omits_the_space_after_an_argument() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\nenum'
                    ' Language { EN }\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name(lang: Language): String\n  email: String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    " String }\nenum Language { EN }\nextend type User"
                    ' @key(fields: "id") {\n  id: ID! @external\n  name(lang:'
                    " Language): String @external\n  email: String @external\n "
                    ' reviews: [String] @requires(fields: "name(lang: \\"en\\")'
                    ' email")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_ARGUMENT_FIELD)


comptime _REQUIRES_ARGUMENT_FIELD = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  name(lang: Language): String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  email: String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "name(lang:\\"en\\")email")
}

enum Language @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  EN @join__enumValue(graph: REVIEWS) @join__enumValue(graph: USERS)
}"""


def test_requires_compacts_list_and_object_arguments() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID!): User }\ninput'
                    ' Filter { kind: String }\ntype User @key(fields: "id") {\n'
                    "  id: ID!\n  name(ids: [Int], filter: Filter): String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { review:'
                    " String }\ninput Filter { kind: String }\nextend type User"
                    ' @key(fields: "id") {\n  id: ID! @external\n  name(ids:'
                    " [Int], filter: Filter): String @external\n  reviews:"
                    ' [String] @requires(fields: "name(ids: [1, 2], filter: {'
                    ' kind: \\"home\\" })")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REQUIRES_VALUES)


comptime _REQUIRES_VALUES = """enum join__Graph {
  REVIEWS @join__graph(name: "reviews", url: "")
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  review: String @join__field(graph: REVIEWS)
  user(id: ID!): User @join__field(graph: USERS)
}

type User @join__type(graph: REVIEWS, key: "id", extension: true) @join__type(graph: USERS, key: "id") {
  id: ID!
  name(ids: [Int], filter: Filter): String @join__field(graph: REVIEWS, external: true) @join__field(graph: USERS)
  reviews: [String] @join__field(graph: REVIEWS, requires: "name(ids:[1 2]filter:{kind:\\"home\\"})")
}

input Filter @join__type(graph: REVIEWS) @join__type(graph: USERS) {
  kind: String
}"""


def test_interface_field_missing_from_one_graph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node { id: ID! name:'
                    ' String }\ntype User implements Node @key(fields: "id") {'
                    " id: ID! name: String @shareable }\ntype Query { user:"
                    " User }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node { id: ID! }\ntype'
                    " Query { node: Node }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_FIELD_MISSING)


comptime _INTERFACE_FIELD_MISSING = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type User implements Node @join__type(graph: ALPHA, key: "id") @join__implements(graph: ALPHA, interface: "Node") {
  id: ID!
  name: String
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  user: User @join__field(graph: ALPHA)
  node: Node @join__field(graph: ZETA)
}

interface Node @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  id: ID!
  name: String @join__field(graph: ALPHA)
}"""


def test_interface_field_prints_type_only_when_it_differs() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node { id: ID! name:'
                    ' String! }\ntype User implements Node @key(fields: "id") {'
                    " id: ID! name: String! @shareable }\ntype Query { user:"
                    " User }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node { id: ID! name:'
                    ' String }\ntype User implements Node @key(fields: "id") {'
                    " id: ID! name: String @shareable }\ntype Query { person:"
                    " User }\n"
                ),
            ),
            _sg(
                "gamma",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Node { id: ID! }\ntype Query { node:'
                    " Node }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_PARTIAL_TYPE)


comptime _INTERFACE_PARTIAL_TYPE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
  GAMMA @join__graph(name: "gamma", url: "")
}

type User implements Node @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") @join__implements(graph: ALPHA, interface: "Node") @join__implements(graph: BETA, interface: "Node") {
  id: ID!
  name: String @join__field(graph: ALPHA, type: "String!") @join__field(graph: BETA, type: "String")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) @join__type(graph: GAMMA) {
  user: User @join__field(graph: ALPHA)
  person: User @join__field(graph: BETA)
  node: Node @join__field(graph: GAMMA)
}

interface Node @join__type(graph: ALPHA) @join__type(graph: BETA) @join__type(graph: GAMMA) {
  id: ID!
  name: String @join__field(graph: ALPHA, type: "String!") @join__field(graph: BETA)
}"""


def test_interface_field_in_every_graph_omits_join_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@shareable"])\ninterface Node {'
                    " id: ID! name: String @external }\ntype User implements"
                    ' Node @key(fields: "id") { id: ID! name: String @external'
                    " }\ntype Query { user: User }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node { id: ID! name:'
                    ' String }\ntype User implements Node @key(fields: "id") {'
                    " id: ID! name: String @shareable }\ntype Query { person:"
                    " User }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_EXTERNAL)


comptime _INTERFACE_EXTERNAL = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User implements Node @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") @join__implements(graph: ALPHA, interface: "Node") @join__implements(graph: BETA, interface: "Node") {
  id: ID!
  name: String @join__field(graph: ALPHA, external: true) @join__field(graph: BETA)
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User @join__field(graph: ALPHA)
  person: User @join__field(graph: BETA)
}

interface Node @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID!
  name: String
}"""


def test_query_field_in_every_graph_omits_provides() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable", "@provides", "@external"])\ntype'
                    ' Query { user: User @shareable @provides(fields: "name")'
                    ' }\ntype User @key(fields: "id") { id: ID! name: String'
                    " @external }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ntype Query { user: User'
                    ' @shareable }\ntype User @key(fields: "id") { id: ID!'
                    " name: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _QUERY_PROVIDES)


comptime _QUERY_PROVIDES = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  name: String @join__field(graph: ALPHA, external: true) @join__field(graph: BETA)
  id: ID!
}"""


def test_query_field_in_one_graph_keeps_provides() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@external"])\ntype Query { user:'
                    ' User @provides(fields: "name") }\ntype User @key(fields:'
                    ' "id") { id: ID! name: String @external }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { other: String }\ntype User'
                    ' @key(fields: "id") { id: ID! name: String }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _QUERY_PARTIAL_PROVIDES)


comptime _QUERY_PARTIAL_PROVIDES = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User @join__field(graph: ALPHA, provides: "name")
  other: String @join__field(graph: BETA)
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  name: String @join__field(graph: ALPHA, external: true) @join__field(graph: BETA)
  id: ID!
}"""


def test_shareable_query_field_stays_beside_an_override() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\ntype Query { user: String @shareable }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@override"])\ntype Query { user: String @override(from:'
                    ' "alpha") }\n'
                ),
            ),
            _sg(
                "gamma",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\ntype Query { user: String @shareable }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _QUERY_OVERRIDE_SHAREABLE)


comptime _QUERY_OVERRIDE_SHAREABLE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
  GAMMA @join__graph(name: "gamma", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) @join__type(graph: GAMMA) {
  user: String @join__field(graph: BETA, override: "alpha") @join__field(graph: GAMMA)
}"""


def test_labeled_query_override_leaves_the_source_unlabeled() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@shareable"])\n'
                    "type Query { user: String @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@override"])\n'
                    'type Query { user: String @override(from: "alpha",'
                    ' label: "percent(5)") }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _QUERY_OVERRIDE_LABEL)


comptime _QUERY_OVERRIDE_LABEL = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: String @join__field(graph: ALPHA) @join__field(graph: BETA, override: "alpha", overrideLabel: "percent(5)")
}"""


def test_shareable_field_stays_beside_a_labeled_override() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\ntype Query { user: User }\ntype'
                    ' User @key(fields: "id") { id: ID! name: String'
                    " @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\ntype Query { person: User }\ntype'
                    ' User @key(fields: "id") { id: ID! name: String'
                    ' @override(from: "alpha", label: "percent(1)") }\n'
                ),
            ),
            _sg(
                "gamma",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\ntype Query { viewer: User'
                    ' }\ntype User @key(fields: "id") { id: ID! name: String'
                    " @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _OVERRIDE_SHAREABLE)


comptime _OVERRIDE_SHAREABLE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
  GAMMA @join__graph(name: "gamma", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) @join__type(graph: GAMMA) {
  user: User @join__field(graph: ALPHA)
  person: User @join__field(graph: BETA)
  viewer: User @join__field(graph: GAMMA)
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") @join__type(graph: GAMMA, key: "id") {
  id: ID!
  name: String @join__field(graph: ALPHA, overrideLabel: "percent(1)") @join__field(graph: BETA, override: "alpha", overrideLabel: "percent(1)") @join__field(graph: GAMMA)
}"""


def test_object_implements_only_the_interfaces_each_graph_defines() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node { id: ID!'
                    " }\ninterface Named { name: String }\ntype User implements"
                    ' Node & Named @key(fields: "id") {\n  id: ID!\n  name:'
                    " String @shareable\n}\ntype Query { user: User }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node { id: ID! }\ntype'
                    ' User implements Node @key(fields: "id") {\n  id: ID!\n '
                    " name: String @shareable\n}\ntype Query { person: User }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _PARTIAL_IMPLEMENTS)


comptime _PARTIAL_IMPLEMENTS = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User implements Node & Named @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") @join__implements(graph: ALPHA, interface: "Node") @join__implements(graph: ALPHA, interface: "Named") @join__implements(graph: BETA, interface: "Node") {
  id: ID!
  name: String
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User @join__field(graph: ALPHA)
  person: User @join__field(graph: BETA)
}

interface Node @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID!
}

interface Named @join__type(graph: ALPHA) {
  name: String
}"""


def test_union_members_follow_each_graphs_order() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { item: Product }\n"
                    "type Film { title: String @shareable }\n"
                    "type Book { title: String @shareable }\n"
                    "union Product = Film | Book\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { other: Product }\n"
                    "type Book { title: String @shareable }\n"
                    "type Film { title: String @shareable }\n"
                    "union Product = Book | Film\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _UNION_ORDER)


comptime _UNION_ORDER = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  item: Product @join__field(graph: ALPHA)
  other: Product @join__field(graph: BETA)
}

type Film @join__type(graph: ALPHA) @join__type(graph: BETA) {
  title: String
}

type Book @join__type(graph: ALPHA) @join__type(graph: BETA) {
  title: String
}

union Product @join__type(graph: ALPHA) @join__type(graph: BETA) @join__unionMember(graph: ALPHA, member: "Film") @join__unionMember(graph: ALPHA, member: "Book") @join__unionMember(graph: BETA, member: "Book") @join__unionMember(graph: BETA, member: "Film") = Film | Book"""


def test_interface_implements_only_where_a_graph_declares_it() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Node { id: ID!'
                    " }\ninterface Named implements Node { id: ID! name: String"
                    ' }\ntype User implements Node & Named @key(fields: "id")'
                    " {\n  id: ID!\n  name: String @shareable\n}\ntype Query {"
                    " user: User }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface Named { name: String'
                    " }\ninterface Node { id: ID! }\ntype User implements Named"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @shareable\n}\ntype Query { person: User }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_IMPLEMENTS)


comptime _INTERFACE_IMPLEMENTS = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User implements Node & Named @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") @join__implements(graph: ALPHA, interface: "Node") @join__implements(graph: ALPHA, interface: "Named") @join__implements(graph: BETA, interface: "Named") {
  id: ID!
  name: String
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User @join__field(graph: ALPHA)
  person: User @join__field(graph: BETA)
}

interface Node @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID!
}

interface Named implements Node @join__type(graph: ALPHA) @join__type(graph: BETA) @join__implements(graph: ALPHA, interface: "Node") {
  id: ID! @join__field(graph: ALPHA)
  name: String
}"""


def test_field_description_keeps_line_breaks() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user: User }\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  """\n  hello\n '
                    ' there\n  """\n  name: String\n}\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { person: User }\ntype User'
                    ' @key(fields: "id") { id: ID! }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _MULTILINE_DESCRIPTION)


comptime _MULTILINE_DESCRIPTION = '''enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User @join__field(graph: ALPHA)
  person: User @join__field(graph: BETA)
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
  """
  hello
  there
  """
  name: String @join__field(graph: ALPHA)
}'''


def test_subgraph_urls_are_escaped() raises:
    var result = compose_subgraphs(
        [
            Subgraph(
                "users",
                Optional[String](String("http://users/graphql")),
                parse(
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user: User }\ntype User'
                    ' @key(fields: "id") { id: ID! }\n'
                ),
            ),
            Subgraph(
                "reviews",
                Optional[String](String('http://reviews/a"b')),
                parse(
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { review: String }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    var sdl = result.supergraph_sdl
    assert_true(
        String(sdl).find(
            'REVIEWS @join__graph(name: "reviews", url: "http://reviews/a\\"b")'
        )
        != -1
    )
    assert_true(
        String(sdl).find(
            'USERS @join__graph(name: "users", url: "http://users/graphql")'
        )
        != -1
    )


def test_tag_names_are_escaped() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@tag"])\ntype Query { hello: String @tag(name:'
                    ' "a\\"b") }\ntype User @key(fields: "id") @tag(name:'
                    ' "c\\nd") { id: ID! }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _TAG_ESCAPED)


comptime _TAG_ESCAPED = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello: String @tag(name: "a\\"b")
}

type User @join__type(graph: USERS, key: "id") @tag(name: "c\\nd") {
  id: ID!
}"""


def test_enum_values_follow_the_first_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { color: Color @shareable }\n"
                    "enum Color { RED BLUE }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { other: Color @shareable }\n"
                    "enum Color { BLUE RED GREEN }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ENUM_ORDER)


comptime _ENUM_ORDER = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  color: Color @join__field(graph: ALPHA)
  other: Color @join__field(graph: BETA)
}

enum Color @join__type(graph: ALPHA) @join__type(graph: BETA) {
  RED @join__enumValue(graph: ALPHA) @join__enumValue(graph: BETA)
  BLUE @join__enumValue(graph: ALPHA) @join__enumValue(graph: BETA)
  GREEN @join__enumValue(graph: BETA)
}"""


def test_custom_root_types_are_printed_as_defaults() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\nschema { query: Root mutation: Change'
                    " subscription: Feed }\ntype Root { hello: String"
                    " @shareable search(by: ById): String }\ntype Change { go:"
                    " String }\ntype Feed { tick: String }\ninput ById { id:"
                    " ID! name: String }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "schema { query: Root }\n"
                    "type Root { other: String @shareable }\n"
                    "input ById { name: String id: ID! extra: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    var sdl = result.supergraph_sdl
    assert_true(
        String(sdl).find(
            "  query: Query\n  mutation: Mutation\n  subscription:"
            " Subscription\n"
        )
        != -1
    )
    assert_equal(_from_graphs(sdl), _CUSTOM_ROOTS)


comptime _CUSTOM_ROOTS = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello: String @join__field(graph: ALPHA)
  search(by: ById): String @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}

type Mutation @join__type(graph: ALPHA) {
  go: String
}

type Subscription @join__type(graph: ALPHA) {
  tick: String
}

input ById @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID!
  name: String
}"""


def test_a_custom_query_root_merges_with_query() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "schema { query: Root }\n"
                    "type Root { hello: String @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { other: String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_true(String(result.supergraph_sdl).find("  query: Query\n") != -1)
    assert_equal(_from_graphs(result.supergraph_sdl), _MERGED_QUERY_ROOT)


comptime _MERGED_QUERY_ROOT = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello: String @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}"""


def test_default_strings_are_escaped() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    'type Query { hello(name: String = "a\\"b",'
                    ' note: String = "c\\nd"): String }\n'
                    'input ById { id: ID = "a\\"b" }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ESCAPED_DEFAULTS)


comptime _ESCAPED_DEFAULTS = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello(name: String = "a\\"b", note: String = "c\\nd"): String
}

input ById @join__type(graph: USERS) {
  id: ID = "a\\"b"
}"""


def test_a_custom_mutation_root_merges_with_mutation() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "schema { mutation: Change }\n"
                    "type Query { hello: String }\n"
                    "type Change { go: String @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { other: String }\n"
                    "type Mutation { stop: String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_true(
        String(result.supergraph_sdl).find("  mutation: Mutation\n") != -1
    )
    assert_equal(_from_graphs(result.supergraph_sdl), _MERGED_MUTATION)


comptime _MERGED_MUTATION = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello: String @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}

type Mutation @join__type(graph: ALPHA) @join__type(graph: BETA) {
  go: String @join__field(graph: ALPHA)
  stop: String @join__field(graph: BETA)
}"""


def test_long_argument_lists_wrap_without_commas() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "enum Color { RED GREEN }\n"
                    'input Filter { kind: String = "x"'
                    ' tags: [String!] = ["a", "b"] }\n'
                    "type Query {\n"
                    "  hello(\n"
                    "    color: Color = RED\n"
                    '    title: String = """\n'
                    "    hello\n"
                    "    there\n"
                    '    """\n'
                    '    tags: [String!] = ["a", "b"]\n'
                    '    filter: Filter = { kind: "x", tags: ["a"] }\n'
                    "  ): String\n"
                    "}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _WRAPPED_ARGUMENTS)


comptime _WRAPPED_ARGUMENTS = '''enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello(
    color: Color = RED
    title: String = """
    hello
    there
    """
    tags: [String!] = ["a", "b"]
    filter: Filter = {kind: "x", tags: ["a"]}
  ): String
}

enum Color @join__type(graph: USERS) {
  RED @join__enumValue(graph: USERS)
  GREEN @join__enumValue(graph: USERS)
}

input Filter @join__type(graph: USERS) {
  kind: String = "x"
  tags: [String!] = ["a", "b"]
}'''


def test_a_long_directive_definition_wraps() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(alpha: String, beta: String, gamma: String,"
                    " delta: String, epsilon: String, zeta: String)"
                    " on FIELD_DEFINITION\n"
                    "type Query { hello: String @foo }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _WRAPPED_DIRECTIVE)


comptime _WRAPPED_DIRECTIVE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @foo(
  alpha: String
  beta: String
  gamma: String
  delta: String
  epsilon: String
  zeta: String
) on FIELD_DEFINITION

type Query @join__type(graph: USERS) {
  hello: String @foo
}"""


def test_a_directive_argument_omits_description_and_cost() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema\n  @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective", "@cost"])\n  @link(url:'
                    ' "https://example.com/foo/v1.0", import: ["@foo"])\n '
                    ' @composeDirective(name: "@foo")\ndirective @foo(\n  """\n'
                    '  The name.\n  """\n  alpha: String @deprecated(reason:'
                    ' "old") @cost(weight: 2)\n) on FIELD_DEFINITION\ntype'
                    " Query { hello: String @foo }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DIRECTIVE_ARG_PLAIN)


comptime _DIRECTIVE_ARG_PLAIN = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @foo(alpha: String) on FIELD_DEFINITION

type Query @join__type(graph: USERS) {
  hello: String @foo
}"""


def test_a_short_argument_description_stays_inline() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user("""The id.""" id: ID!): User'
                    ' }\ntype User @key(fields: "id") { id: ID! }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _SHORT_ARG_DESCRIPTION)


comptime _SHORT_ARG_DESCRIPTION = '''enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user("""
  The id.
  """
  id: ID!): User
}

type User @join__type(graph: USERS, key: "id") {
  id: ID!
}'''


def test_a_wrapped_argument_keeps_its_description() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query {\n  user(\n    """\n    The'
                    " identifier of the user to load from the users subgraph.\n"
                    '    """\n    id: ID!\n    format: String\n  ):'
                    ' User\n}\ntype User @key(fields: "id") { id: ID! }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _WRAPPED_ARG_DESCRIPTION)


comptime _WRAPPED_ARG_DESCRIPTION = '''enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user(
    """
    The identifier of the user to load from the users subgraph.
    """
    id: ID!
    format: String
  ): User
}

type User @join__type(graph: USERS, key: "id") {
  id: ID!
}'''


def test_type_enum_value_and_input_descriptions() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(by: ById): User color: Color'
                    ' }\n"""\nA person.\n"""\ntype User @key(fields: "id") {'
                    ' id: ID! }\ninput ById {\n  """\n  The id.\n  """\n  id:'
                    ' ID! = "x"\n}\nenum Color {\n  """\n  Red.\n  """\n  RED\n'
                    "  GREEN\n}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _PLACED_DESCRIPTIONS)


comptime _PLACED_DESCRIPTIONS = '''enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user(by: ById): User
  color: Color
}

"""
A person.
"""
type User @join__type(graph: USERS, key: "id") {
  id: ID!
}

enum Color @join__type(graph: USERS) {
  """
  Red.
  """
  RED @join__enumValue(graph: USERS)
  GREEN @join__enumValue(graph: USERS)
}

input ById @join__type(graph: USERS) {
  """
  The id.
  """
  id: ID! = "x"
}'''


def test_a_schema_description_is_omitted() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    '"""\nThe API.\n"""\nschema {\n  query: Query\n}\nextend'
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { hello: String }\ntype User'
                    ' @key(fields: "id") { id: ID! }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_true(String(result.supergraph_sdl).find("The API.") == -1)
    assert_true(String(result.supergraph_sdl).find("  query: Query\n") != -1)


def test_a_custom_subscription_root_merges_with_subscription() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "schema { subscription: Feed }\n"
                    "type Query { hello: String }\n"
                    "type Feed { tick: String @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n'
                    "type Query { other: String }\n"
                    "type Subscription { done: String @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_true(
        String(result.supergraph_sdl).find("  subscription: Subscription\n")
        != -1
    )
    assert_equal(_from_graphs(result.supergraph_sdl), _MERGED_SUBSCRIPTION)


comptime _MERGED_SUBSCRIPTION = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello: String @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}

type Subscription @join__type(graph: ALPHA) @join__type(graph: BETA) {
  tick: String @join__field(graph: ALPHA)
  done: String @join__field(graph: BETA)
}"""


def test_specified_by_url_is_escaped() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\nscalar Date'
                    ' @specifiedBy(url: "https://example.com/a\\"b")\ntype'
                    " Query { today: Date }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _SPECIFIED_BY_QUOTE)


comptime _SPECIFIED_BY_QUOTE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

scalar Date @join__type(graph: USERS) @specifiedBy(url: "https://example.com/a\\"b")

type Query @join__type(graph: USERS) {
  today: Date
}"""


def test_one_of_from_one_subgraph_follows_a_tag() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "type Query { hello(by: ById): String }\n"
                    "input ById @oneOf { id: ID name: String }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@tag"])\ntype Query { other(by: ById): String }\ninput'
                    ' ById @tag(name: "lookup") { id: ID name: String }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ONE_OF_AND_TAG)


comptime _ONE_OF_AND_TAG = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @oneOf on INPUT_OBJECT

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello(by: ById): String @join__field(graph: ALPHA)
  other(by: ById): String @join__field(graph: BETA)
}

input ById @join__type(graph: ALPHA) @join__type(graph: BETA) @tag(name: "lookup") @oneOf {
  id: ID
  name: String
}"""


def test_a_deprecated_argument_reason_is_escaped() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user(id: ID @deprecated(reason:'
                    ' "use \\"other\\"")): User }\ntype User @key(fields: "id")'
                    " { id: ID! }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEPRECATED_ARG_QUOTE)


comptime _DEPRECATED_ARG_QUOTE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user(id: ID @deprecated(reason: "use \\"other\\"")): User
}

type User @join__type(graph: USERS, key: "id") {
  id: ID!
}"""


def test_literal_defaults_keep_their_spelling() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "enum Color { RED }\n"
                    "input Filter { kind: String }\n"
                    "type Query {\n"
                    "  hello(\n"
                    "    on: Boolean = true\n"
                    "    off: Boolean = false\n"
                    "    empty: String = null\n"
                    "    amount: Float = 1.5\n"
                    "    tags: [String!] = []\n"
                    "    filter: Filter = {}\n"
                    "    color: Color = RED\n"
                    "  ): String\n"
                    "}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _LITERAL_DEFAULTS)


comptime _LITERAL_DEFAULTS = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello(
    on: Boolean = true
    off: Boolean = false
    empty: String = null
    amount: Float = 1.5
    tags: [String!] = []
    filter: Filter = {}
    color: Color = RED
  ): String
}

enum Color @join__type(graph: USERS) {
  RED @join__enumValue(graph: USERS)
}

input Filter @join__type(graph: USERS) {
  kind: String
}"""


def test_numeric_and_list_defaults_keep_their_spelling() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "input Item { kind: String }\n"
                    "type Query {\n"
                    "  hello(\n"
                    "    amount: Float = -1.5e2\n"
                    '    blank: String = ""\n'
                    '    items: [Item!] = [{kind: "a"}, {kind: "b"}]\n'
                    "  ): String\n"
                    "}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _NUMERIC_DEFAULTS)


comptime _NUMERIC_DEFAULTS = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  hello(
    amount: Float = -1.5e2
    blank: String = ""
    items: [Item!] = [{kind: "a"}, {kind: "b"}]
  ): String
}

input Item @join__type(graph: USERS) {
  kind: String
}"""


def test_repeatable_composed_directives_keep_their_arguments() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "users",
                (
                    "extend schema\n  @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"])\n  @link(url:'
                    ' "https://example.com/foo/v1.0", import: ["@foo"])\n '
                    ' @composeDirective(name: "@foo")\ndirective @foo(name:'
                    " String, tags: [String!], filter: Filter) repeatable on"
                    " FIELD_DEFINITION\ninput Filter { kind: String }\ntype"
                    ' Query {\n  hello: String @foo(name: "a", tags: ["x",'
                    ' "y"], filter: { kind: "home" }) @foo(name: "b")\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _REPEATABLE_FOO)


comptime _REPEATABLE_FOO = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

directive @foo(name: String, tags: [String!], filter: Filter) repeatable on FIELD_DEFINITION

type Query @join__type(graph: USERS) {
  hello: String @foo(name: "a", tags: ["x", "y"], filter: {kind: "home"}) @foo(name: "b")
}

input Filter @join__type(graph: USERS) {
  kind: String
}"""


def test_composed_directives_are_deduplicated() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@key", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) repeatable on"
                    " OBJECT | FIELD_DEFINITION\n"
                    "type Query { a: User }\n"
                    'type User @key(fields: "id") @foo(name: "a")'
                    ' @foo(name: "b") { id: ID! }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@key", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) repeatable on"
                    " OBJECT | FIELD_DEFINITION\n"
                    "type Query { b: User }\n"
                    'type User @key(fields: "id") @foo(name: "b")'
                    ' @foo(name: "c") { id: ID! }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEDUPED_FOO)


comptime _DEDUPED_FOO = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo(name: String) repeatable on OBJECT | FIELD_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  a: User @join__field(graph: ALPHA)
  b: User @join__field(graph: BETA)
}

type User @foo(name: "a") @foo(name: "b") @foo(name: "c") @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
}"""


def test_composed_directives_on_an_argument_are_deduplicated() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@shareable", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) repeatable on"
                    " ARGUMENT_DEFINITION\n"
                    'type Query { hello(id: ID @foo(name: "a")'
                    ' @foo(name: "b")): String @shareable }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@shareable", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) repeatable on"
                    " ARGUMENT_DEFINITION\n"
                    'type Query { hello(id: ID @foo(name: "b")'
                    ' @foo(name: "c")): String @shareable }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEDUPED_ARG_FOO)


comptime _DEDUPED_ARG_FOO = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo(name: String) repeatable on ARGUMENT_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello(id: ID @foo(name: "a") @foo(name: "b") @foo(name: "c")): String
}"""


def test_composed_directives_on_an_enum_value_are_deduplicated() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@shareable", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) repeatable on ENUM_VALUE\n"
                    "type Query { color: Color @shareable }\n"
                    'enum Color { RED @foo(name: "a") @foo(name: "b") }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@shareable", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) repeatable on ENUM_VALUE\n"
                    "type Query { other: Color @shareable }\n"
                    'enum Color { RED @foo(name: "b") @foo(name: "c") }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEDUPED_ENUM_FOO)


comptime _DEDUPED_ENUM_FOO = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo(name: String) repeatable on ENUM_VALUE

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  color: Color @join__field(graph: ALPHA)
  other: Color @join__field(graph: BETA)
}

enum Color @join__type(graph: ALPHA) @join__type(graph: BETA) {
  RED @foo(name: "a") @foo(name: "b") @foo(name: "c") @join__enumValue(graph: ALPHA) @join__enumValue(graph: BETA)
}"""


def test_composed_directives_on_an_input_field_are_deduplicated() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) repeatable on"
                    " INPUT_FIELD_DEFINITION\n"
                    "type Query { hello(by: ById): String }\n"
                    'input ById { id: ID @foo(name: "a") @foo(name: "b") }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) repeatable on"
                    " INPUT_FIELD_DEFINITION\n"
                    "type Query { other(by: ById): String }\n"
                    'input ById { id: ID @foo(name: "b") @foo(name: "c") }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEDUPED_INPUT_FOO)


comptime _DEDUPED_INPUT_FOO = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo(name: String) repeatable on INPUT_FIELD_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello(by: ById): String @join__field(graph: ALPHA)
  other(by: ById): String @join__field(graph: BETA)
}

input ById @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID @foo(name: "a") @foo(name: "b") @foo(name: "c")
}"""


def test_a_composed_directive_precedes_join_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@key", "@tag", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(name: String) on FIELD_DEFINITION\n"
                    "type Query { user: User }\n"
                    'type User @key(fields: "id") {\n'
                    "  id: ID!\n"
                    '  name: String @foo(name: "a") @tag(name: "public")\n'
                    "}\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { other: String }\ntype User'
                    ' @key(fields: "id") { id: ID! }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _FOO_BEFORE_JOIN)


comptime _FOO_BEFORE_JOIN = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo(name: String) on FIELD_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
  name: String @foo(name: "a") @join__field(graph: ALPHA) @tag(name: "public")
}"""


def test_composed_directive_order_follows_the_first_subgraph() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@key", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo", "@bar"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    '  @composeDirective(name: "@bar")\n'
                    "directive @foo on OBJECT\n"
                    "directive @bar on OBJECT\n"
                    "type Query { a: User }\n"
                    'type User @key(fields: "id") @foo @bar { id: ID! }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@key", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@bar", "@foo"])\n'
                    '  @composeDirective(name: "@bar")\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @bar on OBJECT\n"
                    "directive @foo on OBJECT\n"
                    "type Query { b: User }\n"
                    'type User @key(fields: "id") @bar @foo { id: ID! }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _FOO_THEN_BAR)


comptime _FOO_THEN_BAR = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo on OBJECT

directive @bar on OBJECT

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  a: User @join__field(graph: ALPHA)
  b: User @join__field(graph: BETA)
}

type User @foo @bar @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
}"""


def test_a_later_composed_directive_is_appended() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@key", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo", "@bar"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    '  @composeDirective(name: "@bar")\n'
                    "directive @foo on OBJECT\n"
                    "directive @bar on OBJECT\n"
                    "type Query { a: User }\n"
                    'type User @key(fields: "id") @foo @bar { id: ID! }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@key", "@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@bar", "@baz"])\n'
                    '  @composeDirective(name: "@bar")\n'
                    '  @composeDirective(name: "@baz")\n'
                    "directive @bar on OBJECT\n"
                    "directive @baz on OBJECT\n"
                    "type Query { b: User }\n"
                    'type User @key(fields: "id") @bar @baz { id: ID! }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _FOO_BAR_BAZ)


comptime _FOO_BAR_BAZ = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo on OBJECT

directive @bar on OBJECT

directive @baz on OBJECT

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  a: User @join__field(graph: ALPHA)
  b: User @join__field(graph: BETA)
}

type User @foo @bar @baz @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
}"""


def test_a_later_directive_adds_an_argument_and_a_location() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(a: String) on OBJECT\n"
                    "type Query { hello: String }\n"
                    'type User @foo(a: "x") { id: ID }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo(a: String!, b: Int = 1) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n"
                    "type Query { other: String }\n"
                    'type User @foo(a: "y", b: 2) { name: String }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _MERGED_FOO)


comptime _MERGED_FOO = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo(a: String!, b: Int = 1) repeatable on OBJECT | FIELD_DEFINITION

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello: String @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}

type User @foo(a: "x") @foo(a: "y", b: 2) @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID @join__field(graph: ALPHA)
  name: String @join__field(graph: BETA)
}"""


def test_a_later_directive_argument_default_replaces_the_earlier() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    'directive @foo(a: String = "alpha") on OBJECT\n'
                    "type Query { hello: String }\n"
                    "type User @foo { id: ID }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    'directive @foo(a: String = "beta") on OBJECT\n'
                    "type Query { other: String }\n"
                    "type User @foo { name: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _LATER_FOO_DEFAULT)


comptime _LATER_FOO_DEFAULT = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo(a: String = "beta") on OBJECT

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello: String @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}

type User @foo @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID @join__field(graph: ALPHA)
  name: String @join__field(graph: BETA)
}"""


def test_directive_argument_tags_are_combined() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective", "@tag",'
                    ' "@inaccessible"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    'directive @foo(a: String @tag(name: "one")) on OBJECT\n'
                    "type Query { hello: String }\n"
                    "type User @foo { id: ID }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective", "@tag",'
                    ' "@inaccessible"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    'directive @foo(a: String @tag(name: "two") @inaccessible)'
                    " on OBJECT\n"
                    "type Query { other: String }\n"
                    "type User @foo { name: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _FOO_ARG_TAGS)


comptime _FOO_ARG_TAGS = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

directive @foo(a: String @tag(name: "one") @tag(name: "two") @inaccessible) on OBJECT

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  hello: String @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}

type User @foo @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID @join__field(graph: ALPHA)
  name: String @join__field(graph: BETA)
}"""


def test_a_composed_directive_keeps_a_schema_location() raises:
    var composed = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo on FIELD | OBJECT\n"
                    "type Query { hello: String }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema\n"
                    '  @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@composeDirective"])\n'
                    '  @link(url: "https://example.com/foo/v1.0",'
                    ' import: ["@foo"])\n'
                    '  @composeDirective(name: "@foo")\n'
                    "directive @foo on FIELD | QUERY\n"
                    "type Query { other: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(composed.errors), 0)
    assert_true(
        String(composed.supergraph_sdl).find(
            "directive @foo on FIELD | OBJECT\n"
        )
        != -1
    )
    var plain = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "directive @foo on FIELD | OBJECT\n"
                    "type Query { hello: String }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "directive @foo on FIELD | QUERY\n"
                    "type Query { other: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(plain.errors), 0)
    assert_true(
        String(plain.supergraph_sdl).find("directive @foo on FIELD\n") != -1
    )


def test_an_override_replaces_an_entity_field_description() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\n"""From'
                    ' alpha."""\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' """Alpha name."""\n  name: String @shareable\n}\ntype'
                    " Query { user: User @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  """Beta name."""\n '
                    ' name: String @override(from: "alpha")\n}\ntype Query {'
                    " user: User @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(
        _from_graphs(result.supergraph_sdl), _OVERRIDE_FIELD_DESCRIPTION
    )


comptime _OVERRIDE_FIELD_DESCRIPTION = '''enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

"""
From alpha.
"""
type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
  """
  Beta name.
  """
  name: String @join__field(graph: BETA, override: "alpha")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User
}'''


def test_an_override_without_a_description_clears_it() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  """Alpha name."""\n '
                    " name: String @shareable\n}\ntype Query { user: User"
                    " @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @override(from: "alpha")\n}\ntype Query { user: User'
                    " @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(
        _from_graphs(result.supergraph_sdl), _OVERRIDE_CLEARS_DESCRIPTION
    )


comptime _OVERRIDE_CLEARS_DESCRIPTION = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
  name: String @join__field(graph: BETA, override: "alpha")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User
}"""


def test_a_shareable_override_keeps_the_first_description() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  """Alpha name."""\n '
                    " name: String @shareable\n}\ntype Query { user: User"
                    " @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  """Beta name."""\n '
                    ' name: String @shareable @override(from: "alpha")\n}\ntype'
                    " Query { user: User @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(
        _from_graphs(result.supergraph_sdl), _SHAREABLE_OVERRIDE_DESCRIPTION
    )


comptime _SHAREABLE_OVERRIDE_DESCRIPTION = '''enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
  """
  Alpha name.
  """
  name: String @join__field(graph: BETA, override: "alpha")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User
}'''


def test_a_non_entity_keeps_the_first_field_description() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\n"""Alpha'
                    ' type."""\ntype User {\n  """Alpha name."""\n  name:'
                    " String @shareable\n}\ntype Query { user: User"
                    " @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User {\n '
                    ' """Beta name."""\n  name: String @override(from:'
                    ' "alpha")\n}\ntype Query { user: User @shareable }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _NON_ENTITY_DESCRIPTION)


comptime _NON_ENTITY_DESCRIPTION = '''enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

"""
Alpha type.
"""
type User @join__type(graph: ALPHA) @join__type(graph: BETA) {
  """
  Alpha name.
  """
  name: String @join__field(graph: BETA, override: "alpha")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User
}'''


def test_a_key_field_override_keeps_its_description() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") {\n  """Alpha id."""\n  id:'
                    " ID!\n}\ntype Query { user: User @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") {\n  """Beta id."""\n  id: ID!'
                    ' @override(from: "alpha")\n}\ntype Query { user: User'
                    " @shareable }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _KEY_OVERRIDE_DESCRIPTION)


comptime _KEY_OVERRIDE_DESCRIPTION = '''enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  """
  Alpha id.
  """
  id: ID! @join__field(graph: ALPHA, usedOverridden: true) @join__field(graph: BETA, override: "alpha")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User
}'''


def test_query_join_includes_a_graph_with_no_query() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { user: String }\ntype Mutation {'
                    " add: String }\ntype Subscription { feed: String }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Review @key(fields: "id") { id: ID! }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _QUERY_JOIN_EVERY_GRAPH)


comptime _QUERY_JOIN_EVERY_GRAPH = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: String @join__field(graph: ALPHA)
}

type Mutation @join__type(graph: ALPHA) {
  add: String
}

type Subscription @join__type(graph: ALPHA) {
  feed: String
}

type Review @join__type(graph: BETA, key: "id") {
  id: ID!
}"""


def test_a_query_key_is_not_printed() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external"])\ninterface Node { id: ID! }\ntype'
                    ' Query implements Node @key(fields: "id") { id: ID! }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external"])\ninterface Node { id: ID!'
                    ' }\nextend type Query implements Node @key(fields: "id") {'
                    " id: ID! @external extra: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _QUERY_KEY_OMITTED)


comptime _QUERY_KEY_OMITTED = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query implements Node @join__type(graph: ALPHA) @join__type(graph: BETA) @join__implements(graph: ALPHA, interface: "Node") @join__implements(graph: BETA, interface: "Node") {
  id: ID!
  extra: String @join__field(graph: BETA)
}

interface Node @join__type(graph: ALPHA) @join__type(graph: BETA) {
  id: ID!
}"""


def test_interface_object_auth_lands_on_an_existing_field() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@interfaceObject", "@authenticated",'
                    ' "@requiresScopes", "@shareable"])\ntype Query { product:'
                    " Product }\ntype Product @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  sku: String @authenticated'
                    ' @requiresScopes(scopes: [["read"]])\n}\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\ntype Query { review: Product'
                    ' }\ninterface Product @key(fields: "id") { id: ID! sku:'
                    ' String }\ntype Book implements Product @key(fields: "id")'
                    " { id: ID! sku: String @shareable title: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_OBJECT_AUTH)


comptime _INTERFACE_OBJECT_AUTH = """enum join__Graph {
  PRODUCTS @join__graph(name: "products", url: "")
  REVIEWS @join__graph(name: "reviews", url: "")
}

type Query @join__type(graph: PRODUCTS) @join__type(graph: REVIEWS) {
  product: Product @join__field(graph: PRODUCTS)
  review: Product @join__field(graph: REVIEWS)
}

type Book implements Product @join__type(graph: REVIEWS, key: "id") @join__implements(graph: REVIEWS, interface: "Product") {
  id: ID!
  sku: String @authenticated @requiresScopes(scopes: [["read"]])
  title: String
}

interface Product @join__type(graph: PRODUCTS, key: "id", isInterfaceObject: true) @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  sku: String @authenticated @requiresScopes(scopes: [["read"]])
}"""


def test_an_interface_keeps_implementor_auth() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@authenticated", "@requiresScopes",'
                    ' "@policy"])\ninterface Product { id: ID! sku: String'
                    ' }\ntype Book implements Product @key(fields: "id")'
                    ' @authenticated @policy(policies: [["admin"]]) {\n  id:'
                    " ID!\n  sku: String @requiresScopes(scopes:"
                    ' [["read"]])\n}\ntype Query { book: Book }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(
        _from_graphs(result.supergraph_sdl), _INTERFACE_IMPLEMENTOR_AUTH
    )


comptime _INTERFACE_IMPLEMENTOR_AUTH = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Book implements Product @join__type(graph: BOOKS, key: "id") @join__implements(graph: BOOKS, interface: "Product") @authenticated @policy(policies: [["admin"]]) {
  id: ID!
  sku: String @requiresScopes(scopes: [["read"]])
}

type Query @join__type(graph: BOOKS) {
  book: Book
}

interface Product @join__type(graph: BOOKS) @authenticated @policy(policies: [["admin"]]) {
  id: ID!
  sku: String @requiresScopes(scopes: [["read"]])
}"""


def test_implementor_scopes_are_merged_onto_the_interface() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@requiresScopes"])\ninterface Product { id: ID!'
                    " name: String }\ntype Book implements Product @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String'
                    ' @requiresScopes(scopes: [["read"]])\n}\ntype Film'
                    ' implements Product @key(fields: "id") {\n  id: ID!\n '
                    " name: String @requiresScopes(scopes:"
                    ' [["watch"]])\n}\ntype Query { book: Book film: Film }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_MERGED_SCOPES)


comptime _INTERFACE_MERGED_SCOPES = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Book implements Product @join__type(graph: BOOKS, key: "id") @join__implements(graph: BOOKS, interface: "Product") {
  id: ID!
  name: String @requiresScopes(scopes: [["read"]])
}

type Film implements Product @join__type(graph: BOOKS, key: "id") @join__implements(graph: BOOKS, interface: "Product") {
  id: ID!
  name: String @requiresScopes(scopes: [["watch"]])
}

type Query @join__type(graph: BOOKS) {
  book: Book
  film: Film
}

interface Product @join__type(graph: BOOKS) {
  id: ID!
  name: String @requiresScopes(scopes: [["read", "watch"]])
}"""


def test_an_extended_interface_without_a_key_omits_extension() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\nextend interface Node { id: ID! }\ntype Book'
                    " implements Node { id: ID! title: String }\ntype Query {"
                    " book: Book }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_EXTEND_NO_KEY)


comptime _INTERFACE_EXTEND_NO_KEY = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Book implements Node @join__type(graph: BOOKS) @join__implements(graph: BOOKS, interface: "Node") {
  id: ID!
  title: String
}

type Query @join__type(graph: BOOKS) {
  book: Book
}

interface Node @join__type(graph: BOOKS) {
  id: ID!
}"""


def test_an_extended_interface_with_a_key_prints_extension() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Node @key(fields: "id") { id: ID!'
                    " }\nextend interface Node { extra: String }\ntype Book"
                    ' implements Node @key(fields: "id") { id: ID! extra:'
                    " String title: String }\ntype Query { book: Book }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(
        _from_graphs(result.supergraph_sdl), _INTERFACE_EXTEND_WITH_KEY
    )


comptime _INTERFACE_EXTEND_WITH_KEY = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Book implements Node @join__type(graph: BOOKS, key: "id") @join__implements(graph: BOOKS, interface: "Node") {
  id: ID!
  extra: String
  title: String
}

type Query @join__type(graph: BOOKS) {
  book: Book
}

interface Node @join__type(graph: BOOKS, key: "id", extension: true) {
  id: ID!
  extra: String
}"""


def test_an_inaccessible_enum_value_stays_when_the_enum_is_both() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@inaccessible"])\n'
                    "enum Color { RED GREEN @inaccessible }\n"
                    "input Filter { color: Color }\n"
                    "type Query { color: Color }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@inaccessible"])\n'
                    "enum Color { RED BLUE @inaccessible }\n"
                    "input Filter { color: Color }\n"
                    "type Query { shade: Color }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ENUM_BOTH_INACCESSIBLE)


comptime _ENUM_BOTH_INACCESSIBLE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  color: Color @join__field(graph: ALPHA)
  shade: Color @join__field(graph: ZETA)
}

enum Color @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  RED @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA)
  GREEN @join__enumValue(graph: ALPHA) @inaccessible
  BLUE @join__enumValue(graph: ZETA) @inaccessible
}

input Filter @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  color: Color
}"""


def test_an_input_enum_drops_an_unshared_inaccessible_value() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@inaccessible"])\n'
                    "enum Color { RED GREEN @inaccessible }\n"
                    "input Filter { color: Color }\n"
                    "type Query { q: String }\n"
                ),
            ),
            _sg(
                "zeta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@inaccessible"])\n'
                    "enum Color { RED BLUE @inaccessible }\n"
                    "input Filter { color: Color }\n"
                    "type Query { z: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INPUT_ENUM_DROPS_HIDDEN)


comptime _INPUT_ENUM_DROPS_HIDDEN = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  ZETA @join__graph(name: "zeta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  q: String @join__field(graph: ALPHA)
  z: String @join__field(graph: ZETA)
}

enum Color @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  RED @join__enumValue(graph: ALPHA) @join__enumValue(graph: ZETA)
}

input Filter @join__type(graph: ALPHA) @join__type(graph: ZETA) {
  color: Color
}"""


def test_an_interface_argument_omits_inaccessible() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@interfaceObject", "@inaccessible",'
                    ' "@tag"])\ntype Query { product: Product }\ntype Product'
                    ' @interfaceObject @key(fields: "id") {\n  id: ID!\n '
                    ' sku(filter: String @inaccessible @tag(name: "one")):'
                    " String\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\ntype Query { review: Product }\ninterface'
                    ' Product @key(fields: "id") { id: ID! }\ntype Book'
                    ' implements Product @key(fields: "id") { id: ID! title:'
                    " String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(
        _from_graphs(result.supergraph_sdl), _INTERFACE_ARG_INACCESSIBLE
    )


comptime _INTERFACE_ARG_INACCESSIBLE = """enum join__Graph {
  PRODUCTS @join__graph(name: "products", url: "")
  REVIEWS @join__graph(name: "reviews", url: "")
}

type Query @join__type(graph: PRODUCTS) @join__type(graph: REVIEWS) {
  product: Product @join__field(graph: PRODUCTS)
  review: Product @join__field(graph: REVIEWS)
}

type Book implements Product @join__type(graph: REVIEWS, key: "id") @join__implements(graph: REVIEWS, interface: "Product") {
  id: ID!
  title: String
  sku(filter: String @tag(name: "one")): String @join__field
}

interface Product @join__type(graph: PRODUCTS, key: "id", isInterfaceObject: true) @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  sku(filter: String @tag(name: "one")): String @join__field(graph: PRODUCTS)
}"""


def test_the_first_specified_by_url_wins() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0")\n'
                    'scalar Date @specifiedBy(url: "https://example.com/a")\n'
                    "type Query { a: Date }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0")\n'
                    'scalar Date @specifiedBy(url: "https://example.com/b")\n'
                    "type Query { b: Date }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _FIRST_SPECIFIED_BY)


comptime _FIRST_SPECIFIED_BY = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

scalar Date @join__type(graph: ALPHA) @join__type(graph: BETA) @specifiedBy(url: "https://example.com/a")

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  a: Date @join__field(graph: ALPHA)
  b: Date @join__field(graph: BETA)
}"""


def test_a_copied_interface_object_field_keeps_inaccessible() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@interfaceObject", "@inaccessible"])\ntype'
                    " Query { product: Product }\ntype Product @interfaceObject"
                    ' @key(fields: "id") {\n  id: ID!\n  sku: String'
                    " @inaccessible\n}\n"
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\ntype Query { review: Product }\ninterface'
                    ' Product @key(fields: "id") { id: ID! }\ntype Book'
                    ' implements Product @key(fields: "id") { id: ID! title:'
                    " String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(
        _from_graphs(result.supergraph_sdl), _COPIED_FIELD_INACCESSIBLE
    )


comptime _COPIED_FIELD_INACCESSIBLE = """enum join__Graph {
  PRODUCTS @join__graph(name: "products", url: "")
  REVIEWS @join__graph(name: "reviews", url: "")
}

type Query @join__type(graph: PRODUCTS) @join__type(graph: REVIEWS) {
  product: Product @join__field(graph: PRODUCTS)
  review: Product @join__field(graph: REVIEWS)
}

type Book implements Product @join__type(graph: REVIEWS, key: "id") @join__implements(graph: REVIEWS, interface: "Product") {
  id: ID!
  title: String
  sku: String @join__field @inaccessible
}

interface Product @join__type(graph: PRODUCTS, key: "id", isInterfaceObject: true) @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  sku: String @join__field(graph: PRODUCTS) @inaccessible
}"""


def test_an_explicit_default_deprecated_reason_is_printed() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query {\n  old: String'
                    ' @deprecated(reason: "No longer supported")\n  gone:'
                    ' String @deprecated(reason: "")\n  user(id: ID'
                    ' @deprecated(reason: "No longer supported")):'
                    ' String\n}\nenum Color { RED @deprecated(reason: "No'
                    ' longer supported") }\ninput ById { id: ID'
                    ' @deprecated(reason: "No longer supported") }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(
        _from_graphs(result.supergraph_sdl), _DEFAULT_DEPRECATED_REASON
    )


comptime _DEFAULT_DEPRECATED_REASON = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  old: String @deprecated(reason: "No longer supported")
  gone: String @deprecated(reason: "")
  user(id: ID @deprecated(reason: "No longer supported")): String
}

enum Color @join__type(graph: BOOKS) {
  RED @join__enumValue(graph: BOOKS) @deprecated(reason: "No longer supported")
}

input ById @join__type(graph: BOOKS) {
  id: ID @deprecated(reason: "No longer supported")
}"""


def test_control_characters_in_a_string_are_escaped() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@tag"])\ntype Query { user: String @tag(name:'
                    ' "a\bb\fc\u0001d") }\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ESCAPED_CONTROLS)


comptime _ESCAPED_CONTROLS = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  user: String @tag(name: "a\\bb\\fc\\u0001d")
}"""


def test_a_cost_and_assumed_size_of_zero_are_printed() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@cost", "@listSize"])\ntype Query @cost(weight: 0) {\n '
                    " users(first: Int @cost(weight: 0)): [String]"
                    " @cost(weight: 0) @listSize(assumedSize: 0,"
                    ' slicingArguments: ["first"])\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ZERO_COST)


comptime _ZERO_COST = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) @cost(weight: 0) {
  users(first: Int @cost(weight: 0)): [String] @cost(weight: 0) @listSize(assumedSize: 0, slicingArguments: ["first"])
}"""


def test_an_empty_list_size_list_is_printed() raises:
    var slicing = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n'
                    "type Query {\n"
                    "  users(first: Int): [String]"
                    " @listSize(slicingArguments: [])\n"
                    "}\n"
                ),
            )
        ]
    )
    assert_equal(len(slicing.errors), 0)
    assert_equal(_from_graphs(slicing.supergraph_sdl), _EMPTY_SLICING)
    var sized = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n'
                    "type Query {\n"
                    "  users: [String] @listSize(sizedFields: [])\n"
                    "}\n"
                ),
            )
        ]
    )
    assert_equal(len(sized.errors), 0)
    assert_equal(_from_graphs(sized.supergraph_sdl), _EMPTY_SIZED)
    var both = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n'
                    "type Query {\n"
                    "  users(first: Int): [String]"
                    " @listSize(assumedSize: 1, slicingArguments: [])\n"
                    "}\n"
                ),
            )
        ]
    )
    assert_equal(len(both.errors), 0)
    assert_equal(_from_graphs(both.supergraph_sdl), _EMPTY_SLICING_WITH_SIZE)


comptime _EMPTY_SLICING = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  users(first: Int): [String] @listSize(slicingArguments: [])
}"""


comptime _EMPTY_SIZED = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  users: [String] @listSize(sizedFields: [])
}"""


comptime _EMPTY_SLICING_WITH_SIZE = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  users(first: Int): [String] @listSize(assumedSize: 1, slicingArguments: [])
}"""


def test_a_negative_cost_keeps_the_higher_weight() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@cost", "@shareable"])\ntype Query {\n  users: [String]'
                    " @shareable @cost(weight: -5)\n}\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@cost", "@shareable"])\ntype Query {\n  users: [String]'
                    " @shareable @cost(weight: -1)\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _NEGATIVE_COST)


comptime _NEGATIVE_COST = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  users: [String] @cost(weight: -1)
}"""


def test_a_negative_argument_cost_keeps_the_higher_weight() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@cost", "@shareable"])\ntype Query {\n  users(first:'
                    " Int @cost(weight: -5)): String @shareable\n}\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@cost", "@shareable"])\ntype Query {\n  users(first:'
                    " Int @cost(weight: -1)): String @shareable\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _NEGATIVE_ARGUMENT_COST)


comptime _NEGATIVE_ARGUMENT_COST = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  users(first: Int @cost(weight: -1)): String
}"""


def test_an_empty_auth_group_is_printed() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@requiresScopes"])\ntype Query {\n  me:'
                    " String @policy(policies: [[]]) @requiresScopes(scopes:"
                    " [[]])\n}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _EMPTY_AUTH_GROUP)


comptime _EMPTY_AUTH_GROUP = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  me: String @policy(policies: [[]]) @requiresScopes(scopes: [[]])
}"""


def test_an_empty_policy_group_merges_with_a_named_group() raises:
    var named = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@shareable"])\ntype Query { me: String'
                    " @shareable @policy(policies: [[]]) }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@shareable"])\ntype Query { me: String'
                    ' @shareable @policy(policies: [["admin"]]) }\n'
                ),
            ),
        ]
    )
    assert_equal(len(named.errors), 0)
    assert_equal(_from_graphs(named.supergraph_sdl), _EMPTY_POLICY_MERGED)
    var empty = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@shareable"])\ntype Query { me: String'
                    " @shareable @policy(policies: [[]]) }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@shareable"])\ntype Query { me: String'
                    " @shareable @policy(policies: [[]]) }\n"
                ),
            ),
        ]
    )
    assert_equal(len(empty.errors), 0)
    assert_equal(_from_graphs(empty.supergraph_sdl), _EMPTY_POLICY_TWICE)


comptime _EMPTY_POLICY_MERGED = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  me: String @policy(policies: [["admin"]])
}"""


comptime _EMPTY_POLICY_TWICE = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  me: String @policy(policies: [[]])
}"""


def test_a_policy_group_that_contains_another_is_dropped() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@shareable"])\ntype Query { me: String'
                    ' @shareable @policy(policies: [["admin"], ["admin",'
                    ' "read"]]) }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@shareable"])\ntype Query { me: String'
                    ' @shareable @policy(policies: [["admin"]]) }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _POLICY_SUBSET)
    var ordered = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@shareable"])\ntype Query { me: String'
                    ' @shareable @policy(policies: [["b"]]) }\n'
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@policy", "@shareable"])\ntype Query { me: String'
                    ' @shareable @policy(policies: [["a"], ["c"]]) }\n'
                ),
            ),
        ]
    )
    assert_equal(len(ordered.errors), 0)
    assert_equal(_from_graphs(ordered.supergraph_sdl), _POLICY_SORTED)


comptime _POLICY_SUBSET = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  me: String @policy(policies: [["admin"]])
}"""


comptime _POLICY_SORTED = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  me: String @policy(policies: [["a", "b"], ["b", "c"]])
}"""


def test_context_arguments_escape_a_quote() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext"])\ntype Member'
                    ' @key(fields: "id") @context(name: "memberCtx") {\n  id:'
                    " ID!\n  plan: String!\n  note: String!\n  wallet:"
                    ' Wallet!\n}\ntype Wallet @key(fields: "id") { id: ID!'
                    " }\nextend type Wallet {\n  apply(\n    plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")\n    note:'
                    ' String @fromContext(field: "$memberCtx { note(kind:'
                    ' \\"a\\") }")\n  ): Int!\n}\ntype Query { member(id: ID!):'
                    " Member }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _CONTEXT_QUOTE)


comptime _CONTEXT_QUOTE = """enum join__Graph {
  BENEFITS @join__graph(name: "benefits", url: "")
}

type Member @join__type(graph: BENEFITS, key: "id") @context(name: "benefits__memberCtx") {
  id: ID!
  plan: String!
  note: String!
  wallet: Wallet!
}

type Wallet @join__type(graph: BENEFITS, key: "id") {
  id: ID!
  apply: Int! @join__field(
    graph: BENEFITS
    contextArguments: [{context: "benefits__memberCtx", name: "plan", type: "String", selection: " { plan }"}, {context: "benefits__memberCtx", name: "note", type: "String", selection: " { note(kind: \\"a\\") }"}]
  )
}

type Query @join__type(graph: BENEFITS) {
  member(id: ID!): Member
}"""


def test_a_subgraph_name_is_escaped_in_a_context() raises:
    var result = compose_subgraphs(
        [
            _sg(
                'a"b\bc',
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context"])\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n}\ntype Query {'
                    " member: Member }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ESCAPED_SUBGRAPH_NAME)


comptime _ESCAPED_SUBGRAPH_NAME = """enum join__Graph {
  A_B_C @join__graph(name: "a\\"b\\bc", url: "")
}

type Member @join__type(graph: A_B_C, key: "id") @context(name: "a\\"b\\bc__memberCtx") {
  id: ID!
}

type Query @join__type(graph: A_B_C) {
  member: Member
}"""


def test_an_override_escapes_the_source_name() raises:
    var result = compose_subgraphs(
        [
            _sg(
                'a"b',
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") { id: ID! name: String @shareable'
                    " }\ntype Query { user: User @shareable }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@override"])\ntype User'
                    ' @key(fields: "id") { id: ID! name: String @override(from:'
                    ' "a\\"b") }\ntype Query { user: User @shareable }\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _OVERRIDE_ESCAPED_NAME)


comptime _OVERRIDE_ESCAPED_NAME = """enum join__Graph {
  A_B @join__graph(name: "a\\"b", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User @join__type(graph: A_B, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
  name: String @join__field(graph: BETA, override: "a\\"b")
}

type Query @join__type(graph: A_B) @join__type(graph: BETA) {
  user: User
}"""


def test_an_unused_scalar_is_printed() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { x: String }\nscalar Date\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _UNUSED_SCALAR)


comptime _UNUSED_SCALAR = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

scalar Date @join__type(graph: BOOKS)

type Query @join__type(graph: BOOKS) {
  x: String
}"""


def test_a_union_with_one_member_prints_that_member() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Book { title: String }\nunion Media ='
                    " Book\ntype Query { media: Media }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ONE_MEMBER_UNION)


comptime _ONE_MEMBER_UNION = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Book @join__type(graph: BOOKS) {
  title: String
}

type Query @join__type(graph: BOOKS) {
  media: Media
}

union Media @join__type(graph: BOOKS) @join__unionMember(graph: BOOKS, member: "Book") = Book"""


def test_a_deprecated_reason_escapes_control_characters() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query {\n  old: String'
                    ' @deprecated(reason: "a\\nb\\bc\\fd")\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEPRECATED_CONTROLS)


comptime _DEPRECATED_CONTROLS = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  old: String @deprecated(reason: "a\\nb\\bc\\fd")
}"""


def test_a_delete_character_stays_in_a_string() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@tag"])\ntype Query {\n  hello(name: String ='
                    ' "a\\u007Fb"): String @tag(name: "a\\u007Fb")\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DELETE_CHARACTER)


comptime _DELETE_CHARACTER = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  hello(name: String = "a\u007Fb"): String @tag(name: "a\u007Fb")
}"""


def test_a_block_string_default_is_printed_on_multiple_lines() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "type Query {\n"
                    '  hello(title: String = """hi"""): String\n'
                    "}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _BLOCK_DEFAULT)


comptime _BLOCK_DEFAULT = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  hello(title: String = """
  hi
  """): String
}'''


def test_a_directive_argument_block_string_is_multiline() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    'directive @foo(title: String = """hi""") on FIELD\n'
                    "type Query { hello: String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DIRECTIVE_BLOCK_DEFAULT)


comptime _DIRECTIVE_BLOCK_DEFAULT = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

directive @foo(title: String = """
hi
""") on FIELD

type Query @join__type(graph: BOOKS) {
  hello: String
}'''


def test_a_null_default_is_printed() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3")\n'
                    "enum Color { RED }\n"
                    "input Box { name: String }\n"
                    "type Query {\n"
                    "  hello(\n"
                    '    items: [String] = [null, "a"]\n'
                    "    color: Color = RED\n"
                    "    box: Box = {name: null}\n"
                    "  ): String\n"
                    "}\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _NULL_DEFAULTS)


comptime _NULL_DEFAULTS = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  hello(items: [String] = [null, "a"], color: Color = RED, box: Box = {name: null}): String
}

enum Color @join__type(graph: BOOKS) {
  RED @join__enumValue(graph: BOOKS)
}

input Box @join__type(graph: BOOKS) {
  name: String
}"""


def test_cost_is_printed_on_a_scalar_and_an_enum() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@cost"])\nscalar Date @cost(weight: 0)\nenum Color'
                    " @cost(weight: -2) { RED }\ntype Query { color: Color day:"
                    " Date }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _SCALAR_ENUM_COST)


comptime _SCALAR_ENUM_COST = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

scalar Date @join__type(graph: BOOKS) @cost(weight: 0)

type Query @join__type(graph: BOOKS) {
  color: Color
  day: Date
}

enum Color @join__type(graph: BOOKS) @cost(weight: -2) {
  RED @join__enumValue(graph: BOOKS)
}"""


def test_scalar_directives_follow_join_type() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible", "@authenticated",'
                    ' "@cost"])\n"""A day."""\nscalar Date @tag(name: "one")'
                    " @inaccessible @authenticated @cost(weight: 1)"
                    ' @specifiedBy(url: "https://example.com/date")\ntype Query'
                    " { ok: String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _SCALAR_DIRECTIVES)


comptime _SCALAR_DIRECTIVES = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

"""
A day.
"""
scalar Date @join__type(graph: BOOKS) @tag(name: "one") @inaccessible @authenticated @cost(weight: 1) @specifiedBy(url: "https://example.com/date")

type Query @join__type(graph: BOOKS) {
  ok: String
}'''


def test_input_directives_follow_join_type() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible", "@cost"])\n"""Lookup."""\ninput'
                    ' ById @tag(name: "one") @inaccessible @oneOf {\n  id: ID'
                    ' @cost(weight: 2) @deprecated(reason: "old")\n}\ntype'
                    " Query { find(by: ById @inaccessible): String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INPUT_DIRECTIVES)


comptime _INPUT_DIRECTIVES = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

directive @oneOf on INPUT_OBJECT

type Query @join__type(graph: BOOKS) {
  find(by: ById @inaccessible): String
}

"""
Lookup.
"""
input ById @join__type(graph: BOOKS) @tag(name: "one") @inaccessible @oneOf {
  id: ID @cost(weight: 2) @deprecated(reason: "old")
}'''


def test_enum_value_directives_follow_join_enum_value() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible", "@authenticated",'
                    ' "@cost"])\n"""A color."""\nenum Color @tag(name: "one")'
                    " @inaccessible @authenticated @cost(weight: 1) {\n "
                    ' """Red."""\n  RED @tag(name: "hot") @inaccessible'
                    ' @deprecated(reason: "old")\n}\ntype Query { ok:'
                    " String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ENUM_VALUE_DIRECTIVES)


comptime _ENUM_VALUE_DIRECTIVES = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  ok: String
}

"""
A color.
"""
enum Color @join__type(graph: BOOKS) @tag(name: "one") @inaccessible @authenticated @cost(weight: 1) {
  """
  Red.
  """
  RED @join__enumValue(graph: BOOKS) @tag(name: "hot") @inaccessible @deprecated(reason: "old")
}'''


def test_field_directives_follow_tag_then_cost() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible", "@authenticated", "@cost",'
                    ' "@listSize"])\ntype Query {\n  ok: String\n '
                    ' """Readers."""\n  users(first: Int): [String]\n   '
                    ' @tag(name: "one")\n    @inaccessible\n   '
                    " @authenticated\n    @cost(weight: 3)\n   "
                    ' @listSize(assumedSize: 2, slicingArguments: ["first"])\n '
                    '   @deprecated(reason: "old")\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _FIELD_DIRECTIVES)


comptime _FIELD_DIRECTIVES = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  ok: String
  """
  Readers.
  """
  users(first: Int): [String] @tag(name: "one") @inaccessible @authenticated @cost(weight: 3) @listSize(assumedSize: 2, slicingArguments: ["first"]) @deprecated(reason: "old")
}'''


def test_argument_directives_follow_the_description() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible", "@cost"])\ntype Query {\n '
                    ' hello(\n    """The id."""\n    id: ID @tag(name: "one")'
                    " @inaccessible @cost(weight: 4) @deprecated(reason:"
                    ' "old")\n  ): String\n}\n'
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARGUMENT_DIRECTIVES)


comptime _ARGUMENT_DIRECTIVES = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Query @join__type(graph: BOOKS) {
  hello(
    """
    The id.
    """
    id: ID @tag(name: "one") @inaccessible @cost(weight: 4) @deprecated(reason: "old")
  ): String
}'''


def test_object_directives_follow_join_implements() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@tag", "@authenticated", "@cost"])\ninterface'
                    ' Node { id: ID! }\n"""A book."""\ntype Book implements'
                    ' Node @key(fields: "id") @tag(name: "one") @authenticated'
                    " @cost(weight: 2) {\n  id: ID!\n  title: String\n}\ntype"
                    " Query { book: Book }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _OBJECT_DIRECTIVES)


comptime _OBJECT_DIRECTIVES = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

"""
A book.
"""
type Book implements Node @join__type(graph: BOOKS, key: "id") @join__implements(graph: BOOKS, interface: "Node") @tag(name: "one") @authenticated @cost(weight: 2) {
  id: ID!
  title: String
}

type Query @join__type(graph: BOOKS) {
  book: Book
}

interface Node @join__type(graph: BOOKS) @authenticated {
  id: ID!
}'''


def test_union_directives_follow_members() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible"])\ntype Book { title: String'
                    ' }\ntype Film { title: String }\n"""Media."""\nunion Media'
                    ' @tag(name: "one") @inaccessible = Book | Film\ntype Query'
                    " { ok: String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _UNION_DIRECTIVES)


comptime _UNION_DIRECTIVES = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Book @join__type(graph: BOOKS) {
  title: String
}

type Film @join__type(graph: BOOKS) {
  title: String
}

type Query @join__type(graph: BOOKS) {
  ok: String
}

"""
Media.
"""
union Media @join__type(graph: BOOKS) @join__unionMember(graph: BOOKS, member: "Book") @join__unionMember(graph: BOOKS, member: "Film") @tag(name: "one") @inaccessible = Book | Film'''


def test_interface_directives_follow_join_implements() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag"])\ninterface Node { id: ID!'
                    ' }\n"""Named."""\ninterface Named implements Node'
                    ' @tag(name: "one") {\n  id: ID!\n  name: String @tag(name:'
                    ' "label") @deprecated(reason: "old")\n}\ntype Book'
                    " implements Named & Node { id: ID! name: String title:"
                    " String }\ntype Query { ok: String }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_DIRECTIVES)


comptime _INTERFACE_DIRECTIVES = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Book implements Named & Node @join__type(graph: BOOKS) @join__implements(graph: BOOKS, interface: "Named") @join__implements(graph: BOOKS, interface: "Node") {
  id: ID!
  name: String
  title: String
}

type Query @join__type(graph: BOOKS) {
  ok: String
}

interface Node @join__type(graph: BOOKS) {
  id: ID!
}

"""
Named.
"""
interface Named implements Node @join__type(graph: BOOKS) @join__implements(graph: BOOKS, interface: "Node") @tag(name: "one") {
  id: ID!
  name: String @tag(name: "label") @deprecated(reason: "old")
}'''


def test_a_defined_and_extended_object_omits_extension() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype User @key(fields: "id") { id: ID! name:'
                    " String }\nextend type User { email: String }\ntype Query"
                    " { user: User }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _DEFINED_AND_EXTENDED)


comptime _DEFINED_AND_EXTENDED = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type User @join__type(graph: BOOKS, key: "id") {
  id: ID!
  name: String
  email: String
}

type Query @join__type(graph: BOOKS) {
  user: User
}"""


def test_extends_prints_extension() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@extends"])\ntype User @key(fields: "id")'
                    " @extends { id: ID! name: String }\ntype Query { user:"
                    " User }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _EXTENDS_DIRECTIVE)


comptime _EXTENDS_DIRECTIVE = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type User @join__type(graph: BOOKS, key: "id", extension: true) {
  id: ID!
  name: String
}

type Query @join__type(graph: BOOKS) {
  user: User
}"""


def test_federation_v1_extend_omits_extension() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    'type User @key(fields: "id") { id: ID! name: String }\n'
                    "type Query { user: User }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    'extend type User @key(fields: "id") { id: ID! email:'
                    " String }\ntype Query { other: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _V1_EXTEND)


comptime _V1_EXTEND = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id") {
  id: ID!
  name: String @join__field(graph: ALPHA)
  email: String @join__field(graph: BETA)
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}"""


def test_federation_v1_extends_prints_extension() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "alpha",
                (
                    'type User @key(fields: "id") { id: ID! name: String }\n'
                    "type Query { user: User }\n"
                ),
            ),
            _sg(
                "beta",
                (
                    'type User @key(fields: "id") @extends {'
                    " id: ID! email: String }\n"
                    "type Query { other: String }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _V1_EXTENDS)


comptime _V1_EXTENDS = """enum join__Graph {
  ALPHA @join__graph(name: "alpha", url: "")
  BETA @join__graph(name: "beta", url: "")
}

type User @join__type(graph: ALPHA, key: "id") @join__type(graph: BETA, key: "id", extension: true) {
  id: ID!
  name: String @join__field(graph: ALPHA)
  email: String @join__field(graph: BETA)
}

type Query @join__type(graph: ALPHA) @join__type(graph: BETA) {
  user: User @join__field(graph: ALPHA)
  other: String @join__field(graph: BETA)
}"""


def test_a_later_key_can_be_unresolvable() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype User @key(fields: "id") @key(fields:'
                    ' "email", resolvable: false) {\n  id: ID!\n  email:'
                    " String\n}\ntype Query { user: User }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _UNRESOLVABLE_KEY)


comptime _UNRESOLVABLE_KEY = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type User @join__type(graph: BOOKS, key: "id") @join__type(graph: BOOKS, key: "email", resolvable: false) {
  id: ID!
  email: String
}

type Query @join__type(graph: BOOKS) {
  user: User
}"""


def test_an_interface_key_can_be_unresolvable() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Node @key(fields: "id", resolvable:'
                    " false) { id: ID! }\ntype Book implements Node"
                    ' @key(fields: "id") { id: ID! title: String }\ntype Query'
                    " { book: Book }\n"
                ),
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INTERFACE_UNRESOLVABLE)


comptime _INTERFACE_UNRESOLVABLE = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
}

type Book implements Node @join__type(graph: BOOKS, key: "id") @join__implements(graph: BOOKS, interface: "Node") {
  id: ID!
  title: String
}

type Query @join__type(graph: BOOKS) {
  book: Book
}

interface Node @join__type(graph: BOOKS, key: "id", resolvable: false) {
  id: ID!
}"""


def test_the_first_subgraph_keeps_its_deprecated_reason() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\nenum Color { RED @deprecated(reason:'
                    ' "from-reviews") }\ninput Filter { kind: String'
                    ' @deprecated(reason: "from-reviews") }\ntype Query {\n '
                    ' color(kind: String @deprecated(reason: "from-reviews")):'
                    ' Color @shareable @deprecated(reason: "from-reviews")\n}\n'
                ),
            ),
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\nenum Color { RED @deprecated(reason:'
                    ' "from-books") }\ninput Filter { kind: String'
                    ' @deprecated(reason: "from-books") }\ntype Query {\n '
                    ' color(kind: String @deprecated(reason: "from-books")):'
                    ' Color @shareable @deprecated(reason: "from-books")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _FIRST_DEPRECATION)


comptime _FIRST_DEPRECATION = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
  REVIEWS @join__graph(name: "reviews", url: "")
}

type Query @join__type(graph: BOOKS) @join__type(graph: REVIEWS) {
  color(kind: String @deprecated(reason: "from-books")): Color @deprecated(reason: "from-books")
}

enum Color @join__type(graph: BOOKS) @join__type(graph: REVIEWS) {
  RED @join__enumValue(graph: BOOKS) @join__enumValue(graph: REVIEWS) @deprecated(reason: "from-books")
}

input Filter @join__type(graph: BOOKS) @join__type(graph: REVIEWS) {
  kind: String @deprecated(reason: "from-books")
}"""


def test_id_order_sets_type_field_and_enum_value_order() raises:
    var result = compose_subgraphs(
        [
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n"""From reviews."""\ntype Zebra { id:'
                    " ID! }\nenum Color { ZEBRA GREEN }\ntype User {\n "
                    ' """Review field."""\n  z: String @shareable\n  a: String'
                    " @shareable\n}\ntype Query {\n  zebra: Zebra\n  color:"
                    " Color @shareable\n  user: User @shareable\n}\n"
                ),
            ),
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n"""From books."""\ntype Apple { id: ID!'
                    ' }\nenum Color { RED GREEN }\ntype User {\n  """Book'
                    ' field."""\n  a: String @shareable\n  m: String'
                    " @shareable\n  z: String @shareable\n}\ntype Query {\n "
                    " apple: Apple\n  color: Color @shareable\n  user: User"
                    " @shareable\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ID_ORDER)


comptime _ID_ORDER = '''enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
  REVIEWS @join__graph(name: "reviews", url: "")
}

"""
From books.
"""
type Apple @join__type(graph: BOOKS) {
  id: ID!
}

type User @join__type(graph: BOOKS) @join__type(graph: REVIEWS) {
  """
  Book field.
  """
  a: String
  m: String @join__field(graph: BOOKS)
  """
  Review field.
  """
  z: String
}

type Query @join__type(graph: BOOKS) @join__type(graph: REVIEWS) {
  apple: Apple @join__field(graph: BOOKS)
  color: Color
  user: User
  zebra: Zebra @join__field(graph: REVIEWS)
}

"""
From reviews.
"""
type Zebra @join__type(graph: REVIEWS) {
  id: ID!
}

enum Color @join__type(graph: BOOKS) @join__type(graph: REVIEWS) {
  RED @join__enumValue(graph: BOOKS)
  GREEN @join__enumValue(graph: BOOKS) @join__enumValue(graph: REVIEWS)
  ZEBRA @join__enumValue(graph: REVIEWS)
}'''


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
