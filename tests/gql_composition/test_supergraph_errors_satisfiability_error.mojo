# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/SATISFIABILITY_ERROR.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_cannot_satisfy_require_conditions() raises:
    # v2.0 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.0 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.0 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_works_with_override() raises:
    # v2.0 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.0 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.0 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.0 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_unreachable_from_root() raises:
    # v2.0 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_identical_keys_fields() raises:
    # v2.0 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_unresolvable_because_of_external_no_idea() raises:
    # v2.0 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_external_but_somehow_resolvable() raises:
    # v2.0 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_field_resolvable_via_entity_type_s_child() raises:
    # v2.0 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.0 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.0 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.0 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_moving_between_entity_with_key_and_without_it() raises:
    # v2.0 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.0 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.0 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.0 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_resolve_missing_field_by_parent_entity() raises:
    # v2.0 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.0 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_ignore_overridden_root_fields() raises:
    # v2.0 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_make_sure_we_avoid_infinite_loops() raises:
    # v2.0 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_fed1_external_and_extends_extend() raises:
    # v2.0 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_requires_with_interface_field() raises:
    # v2.0 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_requires_with_a_lot_of_nested_entities() raises:
    # v2.0 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_require_in_interfaceobject() raises:
    # v2.0 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.0 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.0 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.0 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_cannot_satisfy_require_conditions() raises:
    # v2.1 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.1 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.1 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_works_with_override() raises:
    # v2.1 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.1 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.1 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.1 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_unreachable_from_root() raises:
    # v2.1 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_identical_keys_fields() raises:
    # v2.1 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_unresolvable_because_of_external_no_idea() raises:
    # v2.1 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_external_but_somehow_resolvable() raises:
    # v2.1 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_field_resolvable_via_entity_type_s_child() raises:
    # v2.1 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.1 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.1 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.1 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_moving_between_entity_with_key_and_without_it() raises:
    # v2.1 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.1 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.1 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.1 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_resolve_missing_field_by_parent_entity() raises:
    # v2.1 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.1 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_ignore_overridden_root_fields() raises:
    # v2.1 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_make_sure_we_avoid_infinite_loops() raises:
    # v2.1 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_fed1_external_and_extends_extend() raises:
    # v2.1 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_requires_with_interface_field() raises:
    # v2.1 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_requires_with_a_lot_of_nested_entities() raises:
    # v2.1 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_require_in_interfaceobject() raises:
    # v2.1 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.1 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.1 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.1 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_cannot_satisfy_require_conditions() raises:
    # v2.2 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.2 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.2 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_works_with_override() raises:
    # v2.2 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.2 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.2 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.2 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_unreachable_from_root() raises:
    # v2.2 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_identical_keys_fields() raises:
    # v2.2 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_unresolvable_because_of_external_no_idea() raises:
    # v2.2 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_external_but_somehow_resolvable() raises:
    # v2.2 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_field_resolvable_via_entity_type_s_child() raises:
    # v2.2 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.2 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.2 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.2 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_moving_between_entity_with_key_and_without_it() raises:
    # v2.2 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.2 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.2 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.2 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_resolve_missing_field_by_parent_entity() raises:
    # v2.2 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.2 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_ignore_overridden_root_fields() raises:
    # v2.2 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_make_sure_we_avoid_infinite_loops() raises:
    # v2.2 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_fed1_external_and_extends_extend() raises:
    # v2.2 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_requires_with_interface_field() raises:
    # v2.2 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_requires_with_a_lot_of_nested_entities() raises:
    # v2.2 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_require_in_interfaceobject() raises:
    # v2.2 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.2 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.2 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.2 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_cannot_satisfy_require_conditions() raises:
    # v2.3 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.3 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.3 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_works_with_override() raises:
    # v2.3 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.3 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.3 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.3 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_unreachable_from_root() raises:
    # v2.3 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_identical_keys_fields() raises:
    # v2.3 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_unresolvable_because_of_external_no_idea() raises:
    # v2.3 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_external_but_somehow_resolvable() raises:
    # v2.3 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_field_resolvable_via_entity_type_s_child() raises:
    # v2.3 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.3 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.3 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.3 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_moving_between_entity_with_key_and_without_it() raises:
    # v2.3 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.3 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.3 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.3 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_resolve_missing_field_by_parent_entity() raises:
    # v2.3 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.3 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_ignore_overridden_root_fields() raises:
    # v2.3 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_make_sure_we_avoid_infinite_loops() raises:
    # v2.3 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_fed1_external_and_extends_extend() raises:
    # v2.3 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_requires_with_interface_field() raises:
    # v2.3 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_requires_with_a_lot_of_nested_entities() raises:
    # v2.3 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_require_in_interfaceobject() raises:
    # v2.3 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.3 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.3 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.3 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_cannot_satisfy_require_conditions() raises:
    # v2.4 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.4 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.4 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_works_with_override() raises:
    # v2.4 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.4 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.4 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.4 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_unreachable_from_root() raises:
    # v2.4 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_identical_keys_fields() raises:
    # v2.4 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_unresolvable_because_of_external_no_idea() raises:
    # v2.4 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_external_but_somehow_resolvable() raises:
    # v2.4 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_field_resolvable_via_entity_type_s_child() raises:
    # v2.4 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.4 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.4 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.4 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_moving_between_entity_with_key_and_without_it() raises:
    # v2.4 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.4 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.4 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.4 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_resolve_missing_field_by_parent_entity() raises:
    # v2.4 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.4 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_ignore_overridden_root_fields() raises:
    # v2.4 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_make_sure_we_avoid_infinite_loops() raises:
    # v2.4 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_fed1_external_and_extends_extend() raises:
    # v2.4 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_requires_with_interface_field() raises:
    # v2.4 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_requires_with_a_lot_of_nested_entities() raises:
    # v2.4 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_require_in_interfaceobject() raises:
    # v2.4 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.4 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.4 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.4 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_cannot_satisfy_require_conditions() raises:
    # v2.5 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.5 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.5 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_works_with_override() raises:
    # v2.5 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.5 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.5 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.5 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_unreachable_from_root() raises:
    # v2.5 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_identical_keys_fields() raises:
    # v2.5 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_unresolvable_because_of_external_no_idea() raises:
    # v2.5 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_external_but_somehow_resolvable() raises:
    # v2.5 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_field_resolvable_via_entity_type_s_child() raises:
    # v2.5 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.5 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.5 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.5 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_moving_between_entity_with_key_and_without_it() raises:
    # v2.5 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.5 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.5 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.5 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_resolve_missing_field_by_parent_entity() raises:
    # v2.5 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.5 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_ignore_overridden_root_fields() raises:
    # v2.5 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_make_sure_we_avoid_infinite_loops() raises:
    # v2.5 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_fed1_external_and_extends_extend() raises:
    # v2.5 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_requires_with_interface_field() raises:
    # v2.5 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_requires_with_a_lot_of_nested_entities() raises:
    # v2.5 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_require_in_interfaceobject() raises:
    # v2.5 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.5 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.5 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.5 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_cannot_satisfy_require_conditions() raises:
    # v2.6 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.6 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.6 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_works_with_override() raises:
    # v2.6 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.6 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.6 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.6 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_unreachable_from_root() raises:
    # v2.6 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_identical_keys_fields() raises:
    # v2.6 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_unresolvable_because_of_external_no_idea() raises:
    # v2.6 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_external_but_somehow_resolvable() raises:
    # v2.6 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_field_resolvable_via_entity_type_s_child() raises:
    # v2.6 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.6 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.6 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.6 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_moving_between_entity_with_key_and_without_it() raises:
    # v2.6 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.6 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.6 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.6 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_resolve_missing_field_by_parent_entity() raises:
    # v2.6 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.6 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_ignore_overridden_root_fields() raises:
    # v2.6 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_make_sure_we_avoid_infinite_loops() raises:
    # v2.6 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_fed1_external_and_extends_extend() raises:
    # v2.6 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_requires_with_interface_field() raises:
    # v2.6 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_requires_with_a_lot_of_nested_entities() raises:
    # v2.6 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_require_in_interfaceobject() raises:
    # v2.6 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.6 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.6 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.6 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_cannot_satisfy_require_conditions() raises:
    # v2.7 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.7 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.7 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_works_with_override() raises:
    # v2.7 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.7 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.7 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.7 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_unreachable_from_root() raises:
    # v2.7 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_identical_keys_fields() raises:
    # v2.7 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_unresolvable_because_of_external_no_idea() raises:
    # v2.7 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_external_but_somehow_resolvable() raises:
    # v2.7 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_field_resolvable_via_entity_type_s_child() raises:
    # v2.7 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.7 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.7 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.7 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_moving_between_entity_with_key_and_without_it() raises:
    # v2.7 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.7 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.7 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.7 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_resolve_missing_field_by_parent_entity() raises:
    # v2.7 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.7 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_ignore_overridden_root_fields() raises:
    # v2.7 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_make_sure_we_avoid_infinite_loops() raises:
    # v2.7 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_fed1_external_and_extends_extend() raises:
    # v2.7 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_requires_with_interface_field() raises:
    # v2.7 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_requires_with_a_lot_of_nested_entities() raises:
    # v2.7 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_require_in_interfaceobject() raises:
    # v2.7 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.7 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.7 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.7 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_cannot_satisfy_require_conditions() raises:
    # v2.8 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.8 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.8 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_works_with_override() raises:
    # v2.8 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.8 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.8 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.8 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_unreachable_from_root() raises:
    # v2.8 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_identical_keys_fields() raises:
    # v2.8 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_unresolvable_because_of_external_no_idea() raises:
    # v2.8 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_external_but_somehow_resolvable() raises:
    # v2.8 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_field_resolvable_via_entity_type_s_child() raises:
    # v2.8 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.8 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.8 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.8 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_moving_between_entity_with_key_and_without_it() raises:
    # v2.8 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.8 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.8 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.8 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_resolve_missing_field_by_parent_entity() raises:
    # v2.8 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.8 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_ignore_overridden_root_fields() raises:
    # v2.8 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_make_sure_we_avoid_infinite_loops() raises:
    # v2.8 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_fed1_external_and_extends_extend() raises:
    # v2.8 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_requires_with_interface_field() raises:
    # v2.8 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_requires_with_a_lot_of_nested_entities() raises:
    # v2.8 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_require_in_interfaceobject() raises:
    # v2.8 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.8 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.8 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.8 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cannot_satisfy_require_conditions() raises:
    # v2.9 > cannot satisfy @require conditions
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  name: String! @external\n  comments: [String] @requires(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_insufficient_key_fields_to_move_between_graphs() raises:
    # v2.9 > insufficient key fields to move between graphs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  userById: User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n  tags: [String]\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id email\") {\n  id: ID\n  name: String\n  email: String\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_insufficient_key_fields_to_move_between_graphs_entity_many_level_deep_from() raises:
    # v2.9 > insufficient key fields to move between graphs (entity many level deep from root type)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: UserConnection!\n  randomUser: UserEdge\n}\n\ntype UserConnection {\n  edges: [UserEdge]\n}\n\ntype UserEdge {\n  node: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_works_with_override() raises:
    # v2.9 > works with @override
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries! @shareable\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "directive @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  view: Queries!\n}\n\ntype Queries {\n  aaa: [String!]! @override(from: \"bar\")\n  bbb: String! @override(from: \"bar\")\n  ccc: String! @override(from: \"bar\")\n  user: User! @override(from: \"bar\")\n}\n\ntype User {\n  id: ID! @override(from: \"bar\")\n  name: String! @override(from: \"bar\")\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Query @shareable {\n  _internal: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries @shareable {\n  aaa: [String!]!\n  bbb: String!\n  ccc: String!\n  ddd: String!\n  eee: String!\n  fff: String!\n  user: User!\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _bazInternal: Boolean @inaccessible\n}\n\ntype Queries {\n  _bazQueriesInternal: Boolean @inaccessible\n}",
            ),
            sg(
                "qux",
                "type Query {\n  qux: String\n}",
            ),
            sg(
                "quux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  _quux: Boolean @inaccessible\n  view: Queries!\n}\n\ntype Queries {\n  _quux: Boolean @inaccessible\n  quux: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_insufficient_key_fields_to_move_between_graphs_completely_different_key_fie() raises:
    # v2.9 > insufficient key fields to move between graphs (completely different key fields)
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  usersByIds(ids: [ID!]!): [User!]!\n}\n\nextend type User @key(fields: \"email\") {\n  email: String\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cannot_move_as_not_shareable_and_no_keys() raises:
    # v2.9 > cannot move as not shareable and no keys
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users(filter: UsersFilter, role: Role): [User]\n}\n\ninput UsersFilter {\n  limit: Int!\n  after: ID!\n  user: UserFilter\n}\n\ninput UserFilter {\n  role: Role\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  \"\"\"Note: age is nullable, but limit is not\"\"\"\n  usersByAge(age: Int, limit: Int!): [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cannot_move_as_not_shareable_and_no_keys_mutation_and_subscription() raises:
    # v2.9 > cannot move as not shareable and no keys (mutation and subscription)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Mutation {\n  createRandomUser: User\n}\n\ntype Subscription {\n  onUserCreated: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_unreachable_from_root() raises:
    # v2.9 > unreachable from root
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User {\n  name: String\n}\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nextend type User {\n  age: Int\n}\n\ntype Query {\n  usersByAge(age: Int): [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_identical_keys_fields() raises:
    # v2.9 > identical keys fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: String\n}\n\ntype Query {\n  users(ids: [ID!]!): [User!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_unresolvable_because_of_external_no_idea() raises:
    # v2.9 > unresolvable because of external (no idea...)
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") @key(fields: \"key { code type } fooCriteria\") {\n  fooId: String! @inaccessible\n  fooCriteria: String @inaccessible\n  publicId: ID!\n  key: Key\n}\n\ntype Key {\n  code: Int!\n  type: ProductType!\n}\n\nenum ProductType {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID! @external\n  fooCriteria: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String\n  available: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"publicId fooCriteria\") {\n  publicId: ID!\n  fooCriteria: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id policy\") {\n  internalId: String! @inaccessible\n  id: ID!\n  policy: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID! @external\n  policy: String @external\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: Boolean!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Product @key(fields: \"id policy\") {\n  id: ID!\n  policy: String @inaccessible\n}\n\ntype Query {\n  productInQux: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_external_but_somehow_resolvable() raises:
    # v2.9 > external but somehow resolvable
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInProducts: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "env",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentallyFriendly: String!\n}\n\ntype Query {\n  productInEnv: Product\n}",
            ),
            sg(
                "random",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  productInRandom: Product\n}",
            ),
            sg(
                "prices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  productInPrices: Product\n}",
            ),
            sg(
                "base",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  productInBase: Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_field_resolvable_via_entity_type_s_child() raises:
    # v2.9 > field resolvable via entity type's child
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: Foo\n}\n\ntype Foo {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") @extends {\n  id: ID!\n  profile: Profile! @external\n}\n\ntype Profile @extends {\n  id: ID!\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: Bar\n}\n\ntype Bar {\n  user: User\n}\n\ntype User @key(fields: \"id profile { id }\") {\n  id: ID!\n  profile: Profile!\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_fed_v1_same_types_but_extra_root_field_in_a_subgraph_missing_a_field() raises:
    # v2.9 > fed v1: same types but extra root field in a subgraph missing a field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_fed_v1_same_types_but_extra_root_field_in_a_subgraph_defining_extra_field() raises:
    # v2.9 > fed v1: same types but extra root field in a subgraph defining extra field
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
            sg(
                "c",
                "type Query {\n  userById(id: ID): User\n  randomUser: User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_fed_v1_same_root_fields_same_types_additional_fields() raises:
    # v2.9 > fed v1: same root fields, same types, additional fields
    check(
        [
            sg(
                "a",
                "type Query {\n  userById(id: ID): User\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User {\n  id: ID!\n  name: String!\n  nickname: String\n}\n\ntype Mutation {\n  createUser(name: String!): User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_moving_between_entity_with_key_and_without_it() raises:
    # v2.9 > moving between entity with @key and without it
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n  email: String\n}\n\ntype Query {\n  usersById(ids: [ID!]!): [User!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User {\n  profile: String\n}\n\nunion Account = User | Admin\n\ntype Admin {\n  id: ID\n  photo: String\n}\n\ntype Query {\n  accounts(ids: [ID!]!): [Account!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_gateway_can_move_from_one_graph_to_another_through_other_subgraphs() raises:
    # v2.9 > gateway can move from one graph to another through other subgraphs
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id category\") {\n  id: ID!\n  categoryDescription: String\n  category: String\n}\n\ntype Query {\n  productInFoo: Product\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id stockId\") {\n  id: ID!\n  freeBar: Boolean!\n  stockId: String\n}\n\ntype Query {\n  productInBar: Product\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  environmentFriendly: String!\n}\n\ntype Query {\n  productInBaz: Product\n}",
            ),
            sg(
                "qux",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id\") {\n  id: ID! @external\n  randomThing: String\n}\n\ntype Query {\n  carInQux: Car\n}",
            ),
            sg(
                "qux2",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Car @key(fields: \"id stockId\") {\n  id: ID! @external\n  stockId: String\n  price: Float\n}\n\ntype Query {\n  carInQux2: Car\n}",
            ),
            sg(
                "qux3",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Car @key(fields: \"id\") @key(fields: \"id stockId\") @key(fields: \"id category\") {\n  id: ID!\n  stockId: String\n  category: String\n}\n\ntype Query {\n  carInQux3: Car\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cannot_move_subgraphs_without_key_and_common_query_path() raises:
    # v2.9 > cannot move subgraphs without @key and common query path
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User {\n  id: String!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend type User {\n  tags: [Tag]\n}\n\ntype Tag {\n  id: String!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_from_root_field_subgraph_a_to_entity_subgraph_a_b_with_missing_key_b() raises:
    # v2.9 > from root field (subgraph A) to entity (subgraph A,B) with missing key (B)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String! @external\n  nickname: String!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"email\") {\n  email: String!\n  country: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_resolve_missing_field_by_parent_entity() raises:
    # v2.9 > resolve missing field by parent entity
    check(
        [
            sg(
                "product",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  products: [Product!]!\n}\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n}\n\ntype Category @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "product-category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id pid\") {\n  id: ID!\n  pid: ID\n  category: Category\n}\n\ntype Category @key(fields: \"id name\") @key(fields: \"cid\") {\n  id: ID!\n  cid: ID!\n  name: String!\n}",
            ),
            sg(
                "category",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Category @key(fields: \"id cid\") {\n  id: ID!\n  cid: ID\n  details: CategoryDetails\n}\n\ntype CategoryDetails {\n  products: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_resolve_missing_field_by_resolving_first_deeply_nested_key_fields_from_mult() raises:
    # v2.9 > resolve missing field by resolving first deeply nested key fields from multiple subgraphs...
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Query {\n  topProducts: ProductList!\n}\n\ntype ProductList @key(fields: \"products{id}\") {\n  products: [Product!]!\n}\n\ntype Product @extends @key(fields: \"id\") {\n  id: String! @external\n  category: Category @shareable\n}\n\ntype Category @key(fields: \"id\") {\n  mainProduct: Product! @shareable\n  id: String!\n  tag: String @shareable\n}",
            ),
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") @key(fields: \"id pid\") {\n  id: String!\n  pid: String!\n}",
            ),
            sg(
                "product-list",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid\") {\n  id: String!\n  pid: String\n}",
            ),
            sg(
                "product-price",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype ProductList @key(fields: \"products{id pid category{id tag}} last{id}\") {\n  products: [Product!]!\n  first: Product @shareable\n  last: Product @shareable\n}\n\ntype Product @key(fields: \"id pid category{id tag}\") {\n  id: String!\n  price: Price\n  pid: String\n  category: Category\n}\n\ntype Category @key(fields: \"id tag\") {\n  id: String!\n  tag: String\n}\n\ntype Price {\n  price: Float!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_ignore_overridden_root_fields() raises:
    # v2.9 > ignore overridden root fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Query {\n  data: Data\n}\n\ntype Data {\n  id: String\n  name: String\n  notInA: String\n  shared: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@override\", \"@shareable\"])\n\ntype Query {\n  data: Data @override(from: \"a\")\n}\n\ntype Data {\n  id: String @override(from: \"a\")\n  name: String @override(from: \"a\")\n  shared: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_make_sure_we_avoid_infinite_loops() raises:
    # v2.9 > make sure we avoid infinite loops
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  account(id: String!): Account\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID!\n  username: String!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID! @external\n  account: Account!\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  node(id: ID!): Node @shareable\n  chat(id: String!): Chat\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Account implements Node @key(fields: \"id\") {\n  id: ID! @external\n  chats: [Chat!]!\n}\n\ntype Chat implements Node @key(fields: \"id\") {\n  id: ID!\n  text: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_fed1_external_and_extends_extend() raises:
    # v2.9 > Fed1: @external and @extends/extend
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID! @external\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  randomUser: User\n}\n\ntype User @extends {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "b",
                "type Query {\n  userById(id: ID): User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  nickname: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_requires_with_interface_field() raises:
    # v2.9 > @requires with interface field
    check(
        [
            sg(
                "a",
                "type Query {\n  userFromA(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address @external\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
            sg(
                "b",
                "type Query {\n  userFromB(id: ID): User\n}\n\ninterface Address {\n  id: ID!\n}\n\ntype HomeAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype WorkAddress implements Address @key(fields: \"id\") {\n  id: ID!\n  city: String\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  address: Address\n  city: String @requires(fields: \"address { id }\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_requires_with_a_lot_of_nested_entities() raises:
    # v2.9 > @requires with a lot of nested entities
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype Details @key(fields: \"id\") {\n  publisher: Publisher!\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Publisher @key(fields: \"id\") {\n  id: ID!\n  books: [Book!]!\n}\n\ntype Book @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]!\n}\n\ntype Genre {\n  details: Details!\n  name: String\n}\n\ntype Details @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  noop: String\n}\n\ntype Mutation {\n  order: Book!\n}\n\ntype Genre {\n  name: String @external\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  genres: [Genre!]! @external\n  price: Float @requires(fields: \"genres { name }\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") {\n  id: ID!\n  isbn: ID\n  title: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name}\") {\n  id: ID!\n  isbn: ID\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name nickname}} last{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n  last: Book @shareable\n  related: BookList!\n}\n\ntype Author @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  nickname: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id isbn title\") @key(fields: \"id publisher\") {\n  id: ID!\n  isbn: ID\n  title: String\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id isbn title}\") {\n  books: [Book!]!\n  first: Book @shareable\n  groupBy: [BookList!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\ntype Author @key(fields: \"id\") {\n  id: ID!\n  name: String @shareable\n}\n\ntype Book @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n  first: Book @shareable\n}\n\ntype Query {\n  books: [Book]!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id isbn author{id name country}\") {\n  id: ID!\n  isbn: String\n  author: Author\n}\n\ntype BookList @key(fields: \"books{id isbn author{id name country}} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}\n\ntype Author @key(fields: \"id name country\") {\n  name: String!\n  country: String\n  id: ID\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: ID!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  books: BookList!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id title isbn\") {\n  id: ID!\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Book @extends @key(fields: \"id publisher\") {\n  id: ID! @external\n  publisher: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") {\n  books: [Book!]!\n  last: Book @shareable\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") @key(fields: \"id publisher\") @key(fields: \"id title isbn\") {\n  id: ID!\n  publisher: String\n  title: String\n  isbn: String\n}\n\ntype BookList @key(fields: \"books{id publisher} last{id}\") @key(fields: \"books{id title isbn}\") {\n  books: [Book!]!\n  fav: Book\n  last: Book @shareable\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Author @key(fields: \"id name\") {\n  name: String!\n  country: String @shareable\n  id: String!\n}\n\ntype Book @extends @key(fields: \"id\") {\n  author: Author @shareable\n  id: ID! @external\n}\n\ntype BookList @key(fields: \"books{id}\") {\n  books: [Book!]!\n}\n\ntype Query {\n  allBooks: BookList!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_require_in_interfaceobject() raises:
    # v2.9 > @require in interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  category: Category!\n}\n\ntype Category @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@requires\", \"@external\"])\n\ntype Product @key(fields: \"id\") @interfaceObject {\n  id: String!\n  categoryName: String @requires(fields: \"category { name }\")\n  category: Category! @external\n}\n\ntype Category {\n  name: String! @external\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Product @key(fields: \"id\") {\n  id: String!\n}\n\ntype Tile implements Product @key(fields: \"id\") {\n  id: String!\n  size: Int!\n}\n\ntype Query {\n  tiles: [Tile!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # v2.9 > deeply nested interfaces with @requires(fields: <fragment>)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ninterface Product {\n  id: ID!\n}\n\ninterface Location {\n  id: ID!\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]! @external\n}\n\ntype Lidl @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!] @external\n  products(location: ID): [Product]! @requires(fields: \"\"\"\n  locations {\n    ... on Warsaw {\n      products {\n        id\n      }\n    }\n  }\n  \"\"\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]!\n}\n\ninterface Shop @key(fields: \"id\") {\n  id: ID!\n}\n\ninterface Location @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Lidl implements Shop @key(fields: \"id\") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype Warsaw implements Location @key(fields: \"id\") {\n  id: ID!\n  products: [Product!]!\n}\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  shops: [Shop!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_unreachable_interface_implementation_interfaceobject_interface_lacks_key() raises:
    # v2.9 > unreachable interface implementation (@interfaceObject) - interface lacks @key
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData @key(fields: \"id\") {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface IData {\n  id: String\n}\n\ntype Data implements IData @key(fields: \"id\") {\n  id: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  idata: IData\n}\n\ntype IData @interfaceObject @key(fields: \"id\") {\n  id: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_make_sure_moving_from_interfaceobject_to_an_implementation_of_the_interface() raises:
    # v2.9 > make sure moving from @interfaceObject to an implementation of the interface is allowed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  products: Product!\n}\n\ntype Product @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Product @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Bread implements Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
