# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `print_subgraph_schema`, ported from `@apollo/subgraph`
2.14.4 `src/__tests__/printSubgraphSchema.test.ts`, and the `@tag
directive` cases of `src/__tests__/buildSubgraphSchema.test.ts`.

`prints a subgraph correctly` and `prints reviews subgraph correctly` build
the fixtures of `apollo-federation-integration-testsuite`, which is outside
`subgraph-js/` and is not read. These tests build the expected output of
upstream instead, with `FEDERATION2_LINK_WITH_AUTO_EXPANDED_IMPORTS`
written out: upstream prints that SDL back unchanged, as `outputs can be
read by buildSchema` checks. The `@tag` cases with resolvers set a field
resolver only; a `GraphQLScalarType` and enum values cannot be given.
"""

from std.testing import TestSuite, assert_equal
from _helpers import assert_service_sdl, sdl_document, subgraph
from gql_execution.execute import ResolveInfo
from gql_execution.value import Values
from gql_subgraph.build_subgraph_schema import (
    SchemaModule,
    SubgraphResolvers,
    build_subgraph_schema,
)
from gql_subgraph.print_subgraph_schema import print_subgraph_schema

comptime TAG_TYPE_DEFS = """type User @key(fields: "email") @tag(name: "tagOnType") {
  email: String @tag(name: "tagOnField")
}

interface Thing @tag(name: "tagOnInterface") {
  name: String
}

union UserButAUnion @tag(name: "tagOnUnion") = User

scalar CustomScalar @tag(name: "tagOnCustomScalar")

enum Enum @tag(name: "tagOnEnum") {
  ENUM_VALUE @tag(name: "tagOnEnumValue")
}"""

comptime TAG_PRINTED = """type User
  @key(fields: "email")
  @tag(name: "tagOnType")
{
  email: String @tag(name: "tagOnField")
}

interface Thing
  @tag(name: "tagOnInterface")
{
  name: String
}

union UserButAUnion
  @tag(name: "tagOnUnion")
 = User

scalar CustomScalar
  @tag(name: "tagOnCustomScalar")

enum Enum
  @tag(name: "tagOnEnum")
{
  ENUM_VALUE @tag(name: "tagOnEnumValue")
}"""

comptime FED1_DIRECTIVES = """directive @key(fields: _FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @requires(fields: _FieldSet!) on FIELD_DEFINITION

directive @provides(fields: _FieldSet!) on FIELD_DEFINITION

directive @external(reason: String) on OBJECT | FIELD_DEFINITION

directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @extends on OBJECT | INTERFACE"""

comptime FED1_TYPES = """scalar _FieldSet

scalar _Any

type _Service {
  sdl: String
}

union _Entity = User

type Query {
  _entities(representations: [_Any!]!): [_Entity]!
  _service: _Service!
}"""

comptime FED2_HEADER = """extend schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@tag"])"""

comptime FED2_PRINTED_HEADER = """extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@tag"])"""

comptime FED2_DIRECTIVES = """directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!) on FIELD_DEFINITION"""

comptime FED2_TYPES = '''enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar _Any

type _Service {
  sdl: String
}

union _Entity = User

type Query {
  _entities(representations: [_Any!]!): [_Entity]!
  _service: _Service!
}'''


def _email(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_number(1)


def _validate_tag(
    header: String,
    printed_header: String,
    directives: String,
    types: String,
    with_resolvers: Bool,
) raises:
    var sdl = header + "\n" + TAG_TYPE_DEFS
    var resolvers = SubgraphResolvers()
    if with_resolvers:
        resolvers.field("User", "email", _email)
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(sdl_document(sdl), resolvers^))
    var schema = build_subgraph_schema(modules^)
    var start = String("") if header == "" else header + "\n\n"
    assert_service_sdl(
        schema, start + directives + "\n\n" + TAG_PRINTED + "\n\n" + types
    )
    var printed = String("") if printed_header == "" else printed_header + "\n\n"
    assert_equal(print_subgraph_schema(schema), printed + TAG_PRINTED)


def test_adds_tag_for_fed1_schema() raises:
    _validate_tag("", "", FED1_DIRECTIVES, FED1_TYPES, False)


def test_adds_tag_for_fed2_schema() raises:
    _validate_tag(
        FED2_HEADER, FED2_PRINTED_HEADER, FED2_DIRECTIVES, FED2_TYPES, False
    )


def test_adds_tag_for_fed1_schema_with_resolvers() raises:
    _validate_tag("", "", FED1_DIRECTIVES, FED1_TYPES, True)


def test_adds_tag_for_fed2_schema_with_resolvers() raises:
    _validate_tag(
        FED2_HEADER, FED2_PRINTED_HEADER, FED2_DIRECTIVES, FED2_TYPES, True
    )


def test_prints_a_scalar_without_a_directive_correctly() raises:
    assert_equal(print_subgraph_schema(subgraph("scalar JSON")), "scalar JSON")


comptime READABLE = """extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@shareable"])

type Query {
  t: T
}

type T
  @key(fields: "id")
{
  id: ID!
  x: Int @shareable
}"""


def test_outputs_can_be_read_by_build_schema() raises:
    assert_equal(print_subgraph_schema(subgraph(READABLE)), READABLE)


def test_prints_types_in_schema_order() raises:
    # From @apollo/subgraph in Node.js: an extension-only type comes after
    # the types with a definition, as in the graphql-js type map.
    assert_equal(
        print_subgraph_schema(
            subgraph(
                "type Review { id: ID } extend type Review { title: String }"
                ' extend type Product @key(fields: "upc") { upc: String'
                " @external reviews: [Review] } extend type Query { a: Int }"
            )
        ),
        """type Review {
  id: ID
}

extend type Review {
  title: String
}

type Query

extend type Query {
  a: Int
}

extend type Product
  @key(fields: "upc")
{
  upc: String @external
  reviews: [Review]
}""",
    )


comptime FIXTURE_ACCOUNTS = """schema {
  query: RootQuery
  mutation: Mutation
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.14", import: ["@key", "@requires", "@provides", "@external", "@tag", "@extends", "@shareable", "@inaccessible", "@override", "@composeDirective", "@interfaceObject"])

directive @stream on FIELD

directive @transform(from: String!) on FIELD

directive @cacheControl(maxAge: Int, scope: CacheControlScope, inheritMaxAge: Boolean) on FIELD_DEFINITION | OBJECT | INTERFACE | UNION

enum CacheControlScope
  @tag(name: "from-reviews")
{
  PUBLIC @tag(name: "from-reviews")
  PRIVATE
}

scalar JSON
  @tag(name: "from-reviews")
  @specifiedBy(url: "https://json-spec.dev")

type RootQuery {
  user(id: ID!): User
  me: User @cacheControl(maxAge: 1000, scope: PRIVATE)
}

type PasswordAccount
  @key(fields: "email")
{
  email: String!
}

type SMSAccount
  @key(fields: "number")
{
  number: String
}

union AccountType
  @tag(name: "from-accounts")
 = PasswordAccount | SMSAccount

type UserMetadata {
  name: String
  address: String
  description: String
}

type User
  @key(fields: "id")
  @key(fields: "username name { first last }")
  @tag(name: "from-accounts")
{
  id: ID! @tag(name: "accounts")
  name: Name @cacheControl(inheritMaxAge: true)
  username: String @shareable
  birthDate(locale: String @tag(name: "admin")): String @tag(name: "admin") @tag(name: "dev")
  account: AccountType
  metadata: [UserMetadata]
  ssn: String
}

type Name {
  first: String
  last: String
}

type Mutation {
  login(username: String!, password: String!, userId: String @deprecated(reason: "Use username instead")): User
}

type Library
  @key(fields: "id")
{
  id: ID!
  name: String @external
  userAccount(id: ID! = 1): User @requires(fields: "name")
  description: String @override(from: "books")
}
"""

comptime FIXTURE_REVIEWS = """extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.14", import: ["@key", "@requires", "@provides", "@external", "@tag", "@extends", "@shareable", "@inaccessible", "@override", "@composeDirective", "@interfaceObject"])

directive @stream on FIELD

directive @transform(from: String!) on FIELD

type Query {
  topReviews(first: Int = 5): [Review]
}

type Review
  @key(fields: "id")
{
  id: ID!
  body(format: Boolean = false): String
  author: User @provides(fields: "username")
  product: Product
  metadata: [MetadataOrError]
}

input UpdateReviewInput
  @tag(name: "from-reviews")
{
  id: ID!
  body: String @tag(name: "from-reviews")
}

type UserMetadata {
  address: String @external
}

type User
  @key(fields: "id")
  @tag(name: "from-reviews")
{
  id: ID!
  username: String @external
  reviews: [Review]
  numberOfReviews: Int!
  metadata: [UserMetadata] @external
  goodAddress: Boolean @requires(fields: "metadata { address }")
}

interface Product
  @tag(name: "from-reviews")
{
  reviews: [Review] @tag(name: "from-reviews")
}

type Furniture implements Product
  @key(fields: "upc")
{
  upc: String!
  reviews: [Review]
}

type Book implements Product
  @key(fields: "isbn")
{
  isbn: String!
  reviews: [Review]
  similarBooks: [Book]! @external
  relatedReviews: [Review!]! @requires(fields: "similarBooks { isbn }")
}

interface Vehicle {
  retailPrice: String
}

type Car implements Vehicle
  @key(fields: "id")
{
  id: String!
  price: String @external
  retailPrice: String @requires(fields: "price")
}

type Van implements Vehicle
  @key(fields: "id")
{
  id: String!
  price: String @external
  retailPrice: String @requires(fields: "price")
}

input ReviewProduct {
  upc: String!
  body: String!
  stars: Int @deprecated(reason: "Stars are no longer in use")
}

type Mutation {
  reviewProduct(input: ReviewProduct!): Product
  updateReview(review: UpdateReviewInput! @tag(name: "from-reviews")): Review
  deleteReview(id: ID!): Boolean
}

type KeyValue
  @shareable
  @tag(name: "from-reviews")
{
  key: String! @tag(name: "from-reviews")
  value: String!
}

type Error
  @shareable
{
  code: Int
  message: String
}

union MetadataOrError = KeyValue | Error
"""


def test_prints_a_subgraph_correctly() raises:
    assert_equal(
        print_subgraph_schema(subgraph(FIXTURE_ACCOUNTS)) + "\n",
        FIXTURE_ACCOUNTS,
    )


def test_prints_reviews_subgraph_correctly() raises:
    assert_equal(
        print_subgraph_schema(subgraph(FIXTURE_REVIEWS)) + "\n",
        FIXTURE_REVIEWS,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
