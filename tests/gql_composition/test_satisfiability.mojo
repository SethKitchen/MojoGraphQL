# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for object satisfiability.

The expected messages are what Hive `composeServices` reports for the same
subgraphs.
"""

from gql_composition.error_code import ErrorCode
from gql_composition.satisfiability import satisfiability_errors
from gql_composition.validate import Subgraph
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal


def _sg(name: String, sdl: String) raises -> Subgraph:
    """Parse a subgraph with no URL."""
    return Subgraph(name, None, parse(sdl))


def test_requires_fails_when_the_key_cannot_reach_the_other_graph() raises:
    var result = satisfiability_errors(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype Query { users: [User] }\ntype User'
                    ' @key(fields: "id name") { id: ID! name: String! }\n'
                ),
            ),
            _sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query {'
                    " usersByIds(ids: [ID!]!): [User!]! }\nextend type User"
                    ' @key(fields: "id") {\n  id: ID @external\n  name: String!'
                    " @external\n  comments: [String] @requires(fields:"
                    ' "name")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result), 3)
    assert_equal(result[0].code, ErrorCode.SATISFIABILITY_ERROR)
    assert_equal(result[0].message, _NAME)
    assert_equal(result[1].message, _COMMENTS_FROM_FEED)
    assert_equal(result[2].message, _COMMENTS_FROM_USERS)


comptime _NAME = """The following supergraph API query:
{
  usersByIds(ids: []) {
    name
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "feed":
  - field "User.name" is not resolvable because marked @external.
  - cannot move to subgraph "users" using @key(fields: "id name") of "User", the key field(s) cannot be resolved from subgraph "feed"."""


comptime _COMMENTS_FROM_FEED = """The following supergraph API query:
{
  usersByIds(ids: []) {
    comments
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "feed":
  - cannot satisfy @require conditions on field "User.comments".
  - cannot move to subgraph "users" using @key(fields: "id name") of "User", the key field(s) cannot be resolved from subgraph "feed"."""


comptime _COMMENTS_FROM_USERS = """The following supergraph API query:
{
  users {
    comments
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "users": cannot find field "User.comments".
- from subgraph "feed": cannot satisfy @require conditions on field "User.comments"."""


def test_requires_succeeds_when_the_key_is_only_the_shared_id() raises:
    var result = satisfiability_errors(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype Query { users: [User] }\ntype User'
                    ' @key(fields: "id") { id: ID! name: String! }\n'
                ),
            ),
            _sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query {'
                    " usersByIds(ids: [ID!]!): [User!]! }\nextend type User"
                    ' @key(fields: "id") {\n  id: ID @external\n  name: String!'
                    " @external\n  comments: [String] @requires(fields:"
                    ' "name")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result), 0)


def test_a_key_that_needs_a_missing_field_blocks_the_move() raises:
    var result = satisfiability_errors(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype Query { userById: User }\ntype User'
                    ' @key(fields: "id name") { id: ID! name: String! }\n'
                ),
            ),
            _sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external"])\ntype Query { randomUser: User'
                    ' }\nextend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  comments: [String]\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result), 1)
    assert_equal(result[0].code, ErrorCode.SATISFIABILITY_ERROR)
    assert_equal(result[0].message, _RANDOM_USER_NAME)


comptime _RANDOM_USER_NAME = """The following supergraph API query:
{
  randomUser {
    name
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "feed":
  - cannot find field "User.name".
  - cannot move to subgraph "users" using @key(fields: "id name") of "User", the key field(s) cannot be resolved from subgraph "feed"."""


def test_a_nested_entity_uses_the_same_key_check() raises:
    var result = satisfiability_errors(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype Query { userById(id: ID): User }\ntype'
                    ' User @key(fields: "id name") { id: ID! name: String! }\n'
                ),
            ),
            _sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external"])\ntype Query {\n  users:'
                    " UserConnection!\n  randomUser: UserEdge\n}\ntype"
                    " UserConnection { edges: [UserEdge] }\ntype UserEdge {"
                    ' node: User }\nextend type User @key(fields: "id") {\n '
                    " id: ID @external\n  comments: [String]\n}\n"
                ),
            ),
        ]
    )
    assert_equal(len(result), 1)
    assert_equal(result[0].message, _NESTED_NAME)


comptime _NESTED_NAME = """The following supergraph API query:
{
  users {
    edges {
      node {
        name
      }
    }
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "feed":
  - cannot find field "User.name".
  - cannot move to subgraph "users" using @key(fields: "id name") of "User", the key field(s) cannot be resolved from subgraph "feed"."""


def test_a_federation_v1_key_blocks_fields_only_the_other_graph_has() raises:
    var result = satisfiability_errors(
        [
            _sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n'
                    "  id: ID @external\n"
                    "  tags: [String]\n"
                    "}\n"
                    "type Query { usersById(ids: [ID!]!): [User!]! }\n"
                ),
            ),
            _sg(
                "b",
                (
                    'type User @key(fields: "id email") {\n'
                    "  id: ID\n"
                    "  name: String\n"
                    "  email: String\n"
                    "  profile: String\n"
                    "}\n"
                    "type Query { users(ids: [ID!]!): [User!]! }\n"
                ),
            ),
        ]
    )
    assert_equal(len(result), 3)
    assert_equal(result[0].message, _V1_EMAIL)
    assert_equal(result[1].message, _V1_NAME)
    assert_equal(result[2].message, _V1_PROFILE)


comptime _V1_EMAIL = """The following supergraph API query:
{
  usersById(ids: []) {
    email
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "a":
  - cannot find field "User.email".
  - cannot move to subgraph "b" using @key(fields: "id email") of "User", the key field(s) cannot be resolved from subgraph "a"."""


comptime _V1_NAME = """The following supergraph API query:
{
  usersById(ids: []) {
    name
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "a":
  - cannot find field "User.name".
  - cannot move to subgraph "b" using @key(fields: "id email") of "User", the key field(s) cannot be resolved from subgraph "a"."""


comptime _V1_PROFILE = """The following supergraph API query:
{
  usersById(ids: []) {
    profile
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "a":
  - cannot find field "User.profile".
  - cannot move to subgraph "b" using @key(fields: "id email") of "User", the key field(s) cannot be resolved from subgraph "a"."""


def test_an_external_key_on_a_definition_cannot_be_resolved() raises:
    var result = satisfiability_errors(
        [
            _sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@override"])\ntype Query { user:'
                    ' User }\ntype User @key(fields: "id") { id: ID! name:'
                    " String }\n"
                ),
            ),
            _sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@override"])\ntype Query { other:'
                    ' User }\ntype User @key(fields: "id") {\n  id: ID!'
                    ' @external\n  name: String @override(from: "bar")\n}\n'
                ),
            ),
        ]
    )
    assert_equal(len(result), 1)
    assert_equal(result[0].message, _EXTERNAL_KEY)


comptime _EXTERNAL_KEY = """The following supergraph API query:
{
  other {
    id
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "foo":
  - field "User.id" is not resolvable because marked @external.
  - cannot move to subgraph "bar" using @key(fields: "id") of "User", the key field(s) cannot be resolved from subgraph "foo"."""


def test_an_unlabeled_override_removes_the_source_field() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.7", import: ["@key",'
        ' "@external", "@override", "@requires"])\n'
    )
    var result = satisfiability_errors(
        [
            _sg(
                "bar",
                link
                + "type Query { user: User }\n"
                + 'type User @key(fields: "id name") {\n'
                + "  id: ID!\n  name: String!\n  secret: String\n}\n",
            ),
            _sg(
                "foo",
                link
                + "type Query { other: User }\n"
                + 'type User @key(fields: "id") {\n'
                + "  id: ID! @external\n"
                + "  name: String! @external\n"
                + '  secret: String @override(from: "bar")'
                + ' @requires(fields: "name")\n'
                + "}\n",
            ),
        ]
    )
    assert_equal(len(result), 4)
    assert_equal(result[0].message, _OVERRIDE_USER_SECRET)
    assert_equal(result[1].message, _OVERRIDE_ID)
    assert_equal(result[2].message, _OVERRIDE_NAME)
    assert_equal(result[3].message, _OVERRIDE_OTHER_SECRET)


comptime _OVERRIDE_ID = """The following supergraph API query:
{
  other {
    id
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "foo":
  - field "User.id" is not resolvable because marked @external.
  - cannot move to subgraph "bar" using @key(fields: "id name") of "User", the key field(s) cannot be resolved from subgraph "foo"."""


comptime _OVERRIDE_NAME = """The following supergraph API query:
{
  other {
    name
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "foo":
  - field "User.name" is not resolvable because marked @external.
  - cannot move to subgraph "bar" using @key(fields: "id name") of "User", the key field(s) cannot be resolved from subgraph "foo"."""


comptime _OVERRIDE_USER_SECRET = """The following supergraph API query:
{
  user {
    secret
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "bar": cannot find field "User.secret".
- from subgraph "foo": cannot satisfy @require conditions on field "User.secret"."""


comptime _OVERRIDE_OTHER_SECRET = """The following supergraph API query:
{
  other {
    secret
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "foo":
  - cannot satisfy @require conditions on field "User.secret".
  - cannot move to subgraph "bar" using @key(fields: "id name") of "User", the key field(s) cannot be resolved from subgraph "foo"."""


def test_provides_resolves_a_field_the_key_cannot_reach() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.0", import: ["@key",'
        ' "@external", "@provides"])\n'
    )
    var result = satisfiability_errors(
        [
            _sg(
                "users",
                link
                + "type Query { user: User }\n"
                + 'type User @key(fields: "id name") {'
                + " id: ID! name: String! }\n",
            ),
            _sg(
                "reviews",
                link
                + "type Query { review: Review }\n"
                + 'type Review { product: User @provides(fields: "name") }\n'
                + 'extend type User @key(fields: "id") {\n'
                + "  id: ID! @external\n"
                + "  name: String! @external\n"
                + "}\n",
            ),
        ]
    )
    assert_equal(len(result), 0)


def test_a_nested_requires_selection_can_be_resolved() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.0", import: ["@key",'
        ' "@external", "@requires"])\n'
    )
    var result = satisfiability_errors(
        [
            _sg(
                "users",
                link
                + "type Query { user: User }\n"
                + 'type User @key(fields: "id") {\n'
                + "  id: ID!\n  address: Address\n}\n"
                + 'type Address @key(fields: "id") {\n'
                + "  id: ID!\n  city: String\n}\n",
            ),
            _sg(
                "reviews",
                link
                + "type Query { review: User }\n"
                + 'extend type User @key(fields: "id") {\n'
                + "  id: ID! @external\n"
                + "  address: Address @external\n"
                + '  city: String @requires(fields: "address { id }")\n'
                + "}\n"
                + 'extend type Address @key(fields: "id") {\n'
                + "  id: ID! @external\n"
                + "}\n",
            ),
        ]
    )
    assert_equal(len(result), 0)


def test_a_non_resolvable_key_cannot_be_entered() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.0", import: ["@key"])\n'
    )
    var result = satisfiability_errors(
        [
            _sg(
                "catalog",
                link
                + "type Query { publisher: Publisher }\n"
                + 'type Publisher @key(fields: "id", resolvable: false) {\n'
                + "  id: ID!\n  name: String\n}\n",
            ),
            _sg(
                "books",
                link
                + "type Query { featured: Publisher }\n"
                + 'type Publisher @key(fields: "id") {\n'
                + "  id: ID!\n  books: [String]\n}\n",
            ),
        ]
    )
    assert_equal(len(result), 1)
    assert_equal(result[0].message, _UNRESOLVABLE_KEY)


comptime _UNRESOLVABLE_KEY = """The following supergraph API query:
{
  featured {
    name
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "books":
  - cannot find field "Publisher.name".
  - cannot move to subgraph "catalog", which has field "Publisher.name", because type "Publisher" has no @key defined in subgraph "catalog"."""


def test_from_context_needs_an_ancestor_context() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.8", import: ["@key",'
        ' "@context", "@fromContext"])\n'
    )
    var missing = satisfiability_errors(
        [
            _sg(
                "users",
                link
                + "type Query { review: Review }\n"
                + 'type Review @key(fields: "id") {\n'
                + "  id: ID!\n"
                + "  authorName(name: String"
                + ' @fromContext(field: "$userContext { name }")): String\n'
                + "}\n"
                + 'type User @key(fields: "id")'
                + ' @context(name: "userContext") {\n'
                + "  id: ID!\n  name: String\n}\n",
            )
        ]
    )
    assert_equal(len(missing), 1)
    assert_equal(missing[0].message, _MISSING_CONTEXT)
    var own = satisfiability_errors(
        [
            _sg(
                "users",
                link
                + "type Query { user: User }\n"
                + 'type User @key(fields: "id")'
                + ' @context(name: "userContext") {\n'
                + "  id: ID!\n"
                + "  name(value: ID"
                + ' @fromContext(field: "$userContext { id }")): String\n'
                + "}\n",
            )
        ]
    )
    assert_equal(len(own), 1)
    assert_equal(own[0].message, _OWN_CONTEXT)
    var reached = satisfiability_errors(
        [
            _sg(
                "users",
                link
                + "type Query { user: User }\n"
                + 'type User @key(fields: "id")'
                + ' @context(name: "userContext") {\n'
                + "  id: ID!\n  name: String\n  reviews: [Review]\n}\n"
                + 'type Review @key(fields: "id") {\n'
                + "  id: ID!\n"
                + "  authorName(name: String"
                + ' @fromContext(field: "$userContext { name }")): String\n'
                + "}\n",
            )
        ]
    )
    assert_equal(len(reached), 0)


comptime _MISSING_CONTEXT = """The following supergraph API query:
{
  review {
    authorName
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "users": could not find a match for required context for field "Review.authorName"."""


comptime _OWN_CONTEXT = """The following supergraph API query:
{
  user {
    name
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "users": could not find a match for required context for field "User.name"."""


def test_a_labeled_override_keeps_a_resolvable_source() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.7", import: ["@key",'
        ' "@override"])\n'
    )
    var result = satisfiability_errors(
        [
            _sg(
                "books",
                link
                + "type Query { product: Product }\n"
                + 'type Product @key(fields: "id") {\n'
                + "  id: ID!\n  price: Int\n}\n",
            ),
            _sg(
                "reviews",
                link
                + 'type Product @key(fields: "id") {\n'
                + "  id: ID!\n"
                + '  price: Int @override(from: "books",'
                + ' label: "percent(0)")\n'
                + "}\n",
            ),
        ]
    )
    assert_equal(len(result), 0)


def test_a_labeled_override_must_resolve_without_the_source() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.7", import: ["@key",'
        ' "@external", "@override", "@requires"])\n'
    )
    var result = satisfiability_errors(
        [
            _sg(
                "books",
                link
                + "type Query { product: Product }\n"
                + 'type Product @key(fields: "id") {\n'
                + "  id: ID!\n  sku: String\n  price: Int\n}\n",
            ),
            _sg(
                "reviews",
                link
                + 'type Product @key(fields: "id") {\n'
                + "  id: ID! @external\n"
                + "  sku: String @external\n"
                + '  price: Int @requires(fields: "sku")'
                + ' @override(from: "books", label: "percent(0)")\n'
                + "}\n",
            ),
        ]
    )
    assert_equal(len(result), 1)
    assert_equal(result[0].message, _LABELED_OVERRIDE)


comptime _LABELED_OVERRIDE = """The following supergraph API query:
{
  product {
    price
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "books": cannot find field "Product.price".
- from subgraph "reviews": cannot satisfy @require conditions on field "Product.price"."""


def test_a_nested_provides_selection_resolves_the_child() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.0", import: ["@key",'
        ' "@external", "@provides"])\n'
    )
    var result = satisfiability_errors(
        [
            _sg(
                "users",
                link
                + "type Query { user: User }\n"
                + 'type User @key(fields: "id name") {\n'
                + "  id: ID!\n  name: String!\n  address: Address\n}\n"
                + 'type Address @key(fields: "id zip") {\n'
                + "  id: ID!\n  zip: String!\n  city: String!\n}\n",
            ),
            _sg(
                "reviews",
                link
                + "type Query { review: Review }\n"
                + "type Review {\n"
                + "  product: User @provides(fields:"
                + ' "address { city }")\n'
                + "}\n"
                + 'extend type User @key(fields: "id") {\n'
                + "  id: ID! @external\n"
                + "  address: Address @external\n"
                + "}\n"
                + 'extend type Address @key(fields: "id") {\n'
                + "  id: ID! @external\n"
                + "  city: String! @external\n"
                + "}\n",
            ),
        ]
    )
    assert_equal(len(result), 2)
    assert_equal(result[0].message, _NESTED_PROVIDES_ZIP)
    assert_equal(result[1].message, _NESTED_PROVIDES_NAME)


comptime _NESTED_PROVIDES_NAME = """The following supergraph API query:
{
  review {
    product {
      name
    }
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "reviews":
  - cannot find field "User.name".
  - cannot move to subgraph "users" using @key(fields: "id name") of "User", the key field(s) cannot be resolved from subgraph "reviews"."""


comptime _NESTED_PROVIDES_ZIP = """The following supergraph API query:
{
  review {
    product {
      address {
        zip
      }
    }
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "reviews":
  - cannot find field "Address.zip".
  - cannot move to subgraph "users" using @key(fields: "id zip") of "Address", the key field(s) cannot be resolved from subgraph "reviews"."""


def test_an_interface_implementation_uses_the_same_key_check() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3", import: ["@key"])\n'
    )
    var open = satisfiability_errors(
        [
            _sg(
                "a",
                link
                + "type Query { t: T }\n"
                + 'interface T @key(fields: "id") { id: ID! x: Int }\n'
                + 'type A implements T @key(fields: "id") {\n'
                + "  id: ID!\n  x: Int\n}\n",
            ),
            _sg(
                "b",
                link + 'type A @key(fields: "id") { id: ID! y: Int z: Int }\n',
            ),
        ]
    )
    assert_equal(len(open), 0)
    var blocked = satisfiability_errors(
        [
            _sg(
                "a",
                link
                + "type Query { t: T }\n"
                + 'interface T @key(fields: "id") { id: ID! x: Int }\n'
                + 'type A implements T @key(fields: "id") {\n'
                + "  id: ID!\n  x: Int\n}\n",
            ),
            _sg(
                "b",
                link
                + 'type A @key(fields: "id y")'
                + " { id: ID! y: Int z: Int }\n",
            ),
        ]
    )
    assert_equal(len(blocked), 2)
    assert_equal(blocked[0].message, _INTERFACE_Y)
    assert_equal(blocked[1].message, _INTERFACE_Z)


comptime _INTERFACE_Y = """The following supergraph API query:
{
  t {
    ... on A {
      y
    }
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "a":
  - cannot find field "A.y".
  - cannot move to subgraph "b" using @key(fields: "id y") of "A", the key field(s) cannot be resolved from subgraph "a"."""


comptime _INTERFACE_Z = """The following supergraph API query:
{
  t {
    ... on A {
      z
    }
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "a":
  - cannot find field "A.z".
  - cannot move to subgraph "b" using @key(fields: "id y") of "A", the key field(s) cannot be resolved from subgraph "a"."""


def test_a_union_member_uses_the_same_key_check() raises:
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.0", import: ["@key"])\n'
    )
    var open = satisfiability_errors(
        [
            _sg(
                "a",
                link
                + "type Query { t: U }\n"
                + "union U = A\n"
                + 'type A @key(fields: "id") { id: ID! x: Int }\n',
            ),
            _sg(
                "b",
                link
                + "union U = A\n"
                + 'type A @key(fields: "id") { id: ID! y: Int z: Int }\n',
            ),
        ]
    )
    assert_equal(len(open), 0)
    var blocked = satisfiability_errors(
        [
            _sg(
                "a",
                link
                + "type Query { t: U }\n"
                + "union U = A\n"
                + 'type A @key(fields: "id") { id: ID! x: Int }\n',
            ),
            _sg(
                "b",
                link
                + "union U = A\n"
                + 'type A @key(fields: "id y") { id: ID! y: Int z: Int }\n',
            ),
        ]
    )
    assert_equal(len(blocked), 2)
    assert_equal(blocked[0].message, _INTERFACE_Y)
    assert_equal(blocked[1].message, _INTERFACE_Z)


def test_an_interface_object_needs_a_resolvable_key() raises:
    var obj = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3", import: ["@key",'
        ' "@interfaceObject", "@shareable"])\n'
    )
    var impl = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3", import: ["@key",'
        ' "@shareable"])\n'
    )
    var open = satisfiability_errors(
        [
            _sg(
                "users",
                obj
                + "type Query { user: User }\n"
                + 'type User @interfaceObject @key(fields: "id") {\n'
                + "  id: ID!\n  name: String @shareable\n}\n",
            ),
            _sg(
                "reviews",
                impl
                + 'interface User @key(fields: "id")'
                + " { id: ID! name: String }\n"
                + 'type Admin implements User @key(fields: "id") {\n'
                + "  id: ID!\n  name: String @shareable\n"
                + "  reviews: [String]\n}\n",
            ),
        ]
    )
    assert_equal(len(open), 0)
    var blocked = satisfiability_errors(
        [
            _sg(
                "users",
                obj
                + "type Query { user: User }\n"
                + 'type User @interfaceObject @key(fields: "id") {\n'
                + "  id: ID!\n  name: String @shareable\n}\n",
            ),
            _sg(
                "reviews",
                impl
                + 'interface User @key(fields: "id", resolvable: false)'
                + " { id: ID! name: String }\n"
                + "type Admin implements User"
                + ' @key(fields: "id", resolvable: false) {\n'
                + "  id: ID!\n  name: String @shareable\n"
                + "  reviews: [String]\n}\n",
            ),
        ]
    )
    assert_equal(len(blocked), 1)
    assert_equal(blocked[0].message, _INTERFACE_OBJECT)


comptime _INTERFACE_OBJECT = """The following supergraph API query:
{
  user {
    ... on Admin {
      ...
    }
  }
}
cannot be satisfied by the subgraphs because:
- from subgraph "users": no subgraph can be reached to resolve the implementation type of @interfaceObject type "User"."""


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
