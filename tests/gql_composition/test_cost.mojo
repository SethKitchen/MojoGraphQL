# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/cost.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_9_cost_cost_in_the_supergraph() raises:
    # v2.9 > @cost > @cost in the supergraph
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\nenum UserType @cost(weight: 15) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @cost(weight: 20)\n}\n\ntype User @cost(weight: 25) @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type User {\n  name: String\n}\n\ntype Query {\n  userCount: Int @cost(weight: 5) @shareable\n  user(id: ID! @cost(weight: 10)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cost_cost_0() raises:
    # v2.9 > @cost > @cost == 0
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@cost\", \"@key\", \"@shareable\"])\n\nenum UserType @cost(weight: 0) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @cost(weight: 0)\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int @cost(weight: 0) @shareable\n  user(id: ID! @cost(weight: 0)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cost_cost_0_2() raises:
    # v2.9 > @cost > @cost < 0
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@cost\", \"@key\", \"@shareable\"])\n\nenum UserType @cost(weight: -1) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @cost(weight: -1)\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int @cost(weight: -1) @shareable\n  user(id: ID! @cost(weight: -1)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cost_cost_on_shareables_be_math_max() raises:
    # v2.9 > @cost > @cost on shareables be Math.max
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\nenum UserType @cost(weight: 15) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @cost(weight: 20)\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int @cost(weight: 5) @shareable\n  user(id: ID! @cost(weight: 10)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\nenum UserType @cost(weight: 30) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @cost(weight: 40)\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int @cost(weight: 10) @shareable\n  user(id: ID! @cost(weight: 20)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cost_incosistent_name_for_cost() raises:
    # v2.9 > @cost > incosistent name for @cost
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\nenum UserType @cost(weight: 15) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @cost(weight: 20)\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int @cost(weight: 5) @shareable\n  user(id: ID! @cost(weight: 15)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", {name: \"@cost\", as: \"@price\"}, \"@shareable\"])\n\nenum UserType @price(weight: 30) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @price(weight: 40)\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int @price(weight: 10) @shareable\n  user(id: ID! @price(weight: 20)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cost_aliased_cost() raises:
    # v2.9 > @cost > aliased @cost
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", {name: \"@cost\", as: \"@price\"}, \"@shareable\"])\n\nenum UserType @price(weight: 15) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @price(weight: 20)\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int @price(weight: 5) @shareable\n  user(id: ID! @price(weight: 10)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", {name: \"@cost\", as: \"@price\"}, \"@shareable\"])\n\nenum UserType @price(weight: 30) {\n  ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int @price(weight: 40)\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int @price(weight: 10) @shareable\n  user(id: ID! @price(weight: 20)): User @shareable\n  userType(id: ID!): UserType @shareable\n  users(filter: UsersFilterInput): [User] @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cost_cost_on_interface_type_is_not_allowed() raises:
    # v2.9 > @cost > @cost on interface type is not allowed
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ninterface Node @cost(weight: 5) {\n  id: ID!\n}\n\ntype User implements Node @cost(weight: 25) @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Directive \"@cost\" may not be used on INTERFACE.",
        ],
    )


def test_v2_9_cost_cost_on_interfaceobject_is_not_allowed() raises:
    # v2.9 > @cost > @cost on interfaceObject is not allowed
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype User implements Node @cost(weight: 25) @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\"])\n\ninterface Node @key(fields: \"id\") @cost(weight: 5) {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [bar] Directive \"@cost\" may not be used on INTERFACE.",
        ],
    )


def test_v2_9_cost_cost_on_interface_field_is_not_allowed() raises:
    # v2.9 > @cost > @cost on interface field is not allowed
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ninterface Node {\n  id: ID! @cost(weight: 5)\n  name(substring: Int @cost(weight: 10)): String\n}\n\ntype User implements Node @cost(weight: 25) @key(fields: \"id\") {\n  id: ID!\n  name(substring: Int @cost(weight: 15)): String\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
        ],
        [
            "[COST_APPLIED_TO_INTERFACE_FIELD] [foo] @cost cannot be applied to interface \"Node.id\"",
            "[COST_APPLIED_TO_INTERFACE_FIELD] [foo] @cost cannot be applied to interface \"Node.name\" argument \"substring\"",
        ],
    )


def test_v2_9_cost_cost_on_interface_field_argument_is_not_allowed() raises:
    # v2.9 > @cost > @cost on interface field argument is not allowed
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ninterface Node {\n  id: ID!\n  name(substring: Int @cost(weight: 10)): String\n}\n\ntype User implements Node @cost(weight: 25) @key(fields: \"id\") {\n  id: ID!\n  name(substring: Int @cost(weight: 15)): String\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
        ],
        [
            "[COST_APPLIED_TO_INTERFACE_FIELD] [foo] @cost cannot be applied to interface \"Node.name\" argument \"substring\"",
        ],
    )


def test_v2_9_cost_cost_on_interfaceobject_field() raises:
    # v2.9 > @cost > @cost on interfaceObject field
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID! @cost(weight: 5)\n}\n\ntype User implements Node @cost(weight: 25) @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@interfaceObject\", \"@cost\"])\n\ntype Node @key(fields: \"id\") @interfaceObject {\n  id: ID! @cost(weight: 10)\n  name(substring: Int @cost(weight: 10)): String\n}",
            ),
        ],
        [
            "[COST_APPLIED_TO_INTERFACE_FIELD] [foo] @cost cannot be applied to interface \"Node.id\"",
        ],
    )


def test_v2_9_cost_cost_on_object_type_implementing_interface() raises:
    # v2.9 > @cost > @cost on object type implementing interface
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") @cost(weight: 5) {\n  id: ID!\n}\n\ntype Bot implements Node @key(fields: \"id\") @cost(weight: 10) {\n  id: ID!\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\"])\n\ntype User @key(fields: \"id\") @cost(weight: 7) {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cost_cost_on_object_type_fields_implementing_interface() raises:
    # v2.9 > @cost > @cost on object type fields implementing interface
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID! @cost(weight: 5)\n}\n\ntype Bot implements Node @key(fields: \"id\") {\n  id: ID! @cost(weight: 10)\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\"])\n\ntype User @key(fields: \"id\") {\n  id: ID! @cost(weight: 7)\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_cost_cost_on_object_type_field_arguments_implementing_interface() raises:
    # v2.9 > @cost > @cost on object type field arguments implementing interface
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n  name(substring: Int): String\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name(substring: Int @cost(weight: 5)): String @shareable\n}\n\ntype Bot implements Node @key(fields: \"id\") {\n  id: ID!\n  name(substring: Int @cost(weight: 10)): String\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@cost\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name(substring: Int @cost(weight: 7)): String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_listsize_on_interface_field() raises:
    # v2.9 > @listSize > @listSize on interface field
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@listSize\", \"@shareable\"])\n\ninterface Node {\n  id: ID!\n  nodes(limit: Int!): [Node] @listSize(slicingArguments: [\"limit\"], sizedFields: [\"nodes\"], assumedSize: 21)\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  nodes(limit: Int!): [Node] @listSize(slicingArguments: [\"limit\"], sizedFields: [\"nodes\"], assumedSize: 11) @shareable\n}\n\ntype Query {\n  node(id: ID): Node @shareable\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@listSize\", \"@shareable\"])\n\ninterface Node {\n  id: ID!\n  nodes(limit: Int!): [Node] @listSize(slicingArguments: [\"limit\"], sizedFields: [\"nodes\"], assumedSize: 20)\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  nodes(limit: Int!): [Node] @listSize(slicingArguments: [\"limit\"], sizedFields: [\"nodes\"], assumedSize: 10) @shareable\n}\n\ntype Query {\n  node(id: ID): Node @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_in_supergraph() raises:
    # v2.9 > @listSize > in supergraph
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype User {\n  id: ID!\n  name: String\n}\n\ntype UserConnection {\n  edges: [User]\n  count: Int!\n}\n\ntype Query {\n  users(first: Int): UserConnection @listSize(slicingArguments: [\"first\"], sizedFields: [\"edges\"])\n  allUsers: [User] @listSize(assumedSize: 1, requireOneSlicingArgument: false)\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_aliased() raises:
    # v2.9 > @listSize > aliased
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [{name: \"@listSize\", as: \"@cartSize\"}])\n\ntype User {\n  id: ID!\n  name: String\n}\n\ntype UserConnection {\n  edges: [User]\n  count: Int!\n}\n\ntype Query {\n  users(first: Int): UserConnection @cartSize(slicingArguments: [\"first\"], sizedFields: [\"edges\"])\n  allUsers: [User] @cartSize(assumedSize: 1, requireOneSlicingArgument: false)\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_inconsistent_name() raises:
    # v2.9 > @listSize > inconsistent name
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [{name: \"@listSize\", as: \"@cartSize\"}])\n\ntype User {\n  id: ID!\n  name: String\n}\n\ntype UserConnection {\n  edges: [User]\n  count: Int!\n}\n\ntype Query {\n  users(first: Int): UserConnection @cartSize(slicingArguments: [\"first\"], sizedFields: [\"edges\"])\n  allUsers: [User] @cartSize(assumedSize: 1, requireOneSlicingArgument: false)\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype Query {\n  words: [String] @listSize(assumedSize: 5)\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_mixing_assumedsize_and_sizedfields() raises:
    # v2.9 > @listSize > mixing assumedSize and sizedFields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: Int!\n}\n\ntype Query {\n  strings(first: Int): StringConnection @listSize(slicingArguments: [\"first\"], sizedFields: [\"edges\"], assumedSize: 1000)\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_non_shared_slicing_argument() raises:
    # v2.9 > @listSize > non-shared slicing argument
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\", \"@shareable\"])\n\ntype StringConnection {\n  edges: [String] @shareable\n  count: Int! @shareable\n}\n\ntype Query {\n  strings(first: Int): StringConnection @shareable @listSize(slicingArguments: [\"first\"], sizedFields: [\"edges\"], assumedSize: 1000, requireOneSlicingArgument: true)\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\", \"@shareable\"])\n\ntype StringConnection {\n  edges: [String] @shareable\n  count: Int! @shareable\n}\n\ntype Query {\n  strings(first: Int, limit: Int): StringConnection @shareable @listSize(slicingArguments: [\"limit\"], sizedFields: [\"edges\"], assumedSize: 2000, requireOneSlicingArgument: false)\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_interface_field() raises:
    # v2.9 > @listSize > interface field
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ninterface Node {\n  id: ID!\n}\n\ninterface NodeConnection {\n  edges: [Node] @listSize(assumedSize: 2)\n  count: Int!\n}\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ntype UserConnection implements NodeConnection {\n  edges: [User] @listSize(assumedSize: 1)\n  count: Int!\n}\n\ntype Query {\n  nodes(first: Int): NodeConnection @listSize(slicingArguments: [\"first\"], sizedFields: [\"edges\"])\n  allNodes: [Node] @listSize(assumedSize: 1, requireOneSlicingArgument: false)\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_interfaceobject_field() raises:
    # v2.9 > @listSize > interfaceObject field
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@listSize\", \"@shareable\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  node(id: ID): Node\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@interfaceObject\", \"@listSize\"])\n\ntype Node @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  accessList: [String] @listSize(assumedSize: 10)\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_negative_assumedsize() raises:
    # v2.9 > @listSize > negative assumedSize
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: Int!\n}\n\ntype Query {\n  strings(first: Int): StringConnection @listSize(assumedSize: -1, sizedFields: [\"edges\"])\n}",
            ),
        ],
        [
            "[LIST_SIZE_INVALID_ASSUMED_SIZE] [foo] \"Query.strings\" has negative @listSize(assumedSize:) value",
        ],
    )


def test_v2_9_listsize_zero_assumedsize() raises:
    # v2.9 > @listSize > zero assumedSize
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: Int!\n}\n\ntype Query {\n  strings(first: Int): StringConnection @listSize(assumedSize: 0, sizedFields: [\"edges\"])\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_listsize_non_list_field_with_the_sizedfields_argument() raises:
    # v2.9 > @listSize > non-list field with the sizedFields argument
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: Int!\n}\n\ntype Query {\n  strings(first: Int): StringConnection @listSize(slicingArguments: [\"first\"], sizedFields: [\"count\"])\n}",
            ),
        ],
        [
            "[LIST_SIZE_APPLIED_TO_NON_LIST] [foo] \"Query.strings\" references \"count\" field in @listSize(sizedFields:) argument that is not a list.",
        ],
    )


def test_v2_9_listsize_non_list_field_without_the_sizedfields_argument() raises:
    # v2.9 > @listSize > non-list field without the sizedFields argument
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: Int!\n}\n\ntype Query {\n  strings(first: String): StringConnection @listSize(slicingArguments: [\"first\"])\n}",
            ),
        ],
        [
            "[LIST_SIZE_INVALID_SIZED_FIELD] [foo] \"Query.strings\" is not a list. Try to add @listSize(sizedFields:) argument.",
        ],
    )


def test_v2_9_listsize_sizedfields_on_non_object_output() raises:
    # v2.9 > @listSize > sizedFields on non-object output
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype Query {\n  strings(first: Int): [String] @listSize(slicingArguments: [\"first\"], sizedFields: [\"edges\"])\n}",
            ),
        ],
        [
            "[LIST_SIZE_INVALID_SIZED_FIELD] [foo] \"Query.strings\" has @listSize(sizedFields:) applied, but the output type is not a composite type",
        ],
    )


def test_v2_9_listsize_sizedfield_should_be_a_list() raises:
    # v2.9 > @listSize > sizedField should be a list
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: String!\n}\n\ntype Query {\n  strings(first: Int): StringConnection @listSize(slicingArguments: [\"first\"], sizedFields: [\"count\"])\n}",
            ),
        ],
        [
            "[LIST_SIZE_APPLIED_TO_NON_LIST] [foo] \"Query.strings\" references \"count\" field in @listSize(sizedFields:) argument that is not a list.",
        ],
    )


def test_v2_9_listsize_sizedfield_should_reference_existing_field() raises:
    # v2.9 > @listSize > sizedField should reference existing field
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: String!\n}\n\ntype Query {\n  strings(first: Int): StringConnection @listSize(slicingArguments: [\"first\"], sizedFields: [\"discount\"])\n}",
            ),
        ],
        [
            "[LIST_SIZE_INVALID_SIZED_FIELD] [foo] \"Query.strings\" references \"discount\" field in @listSize(sizedFields:) argument that does not exist.",
        ],
    )


def test_v2_9_listsize_slicingargument_should_be_int_or_int() raises:
    # v2.9 > @listSize > slicingArgument should be Int or Int!
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: Int!\n}\n\ntype Query {\n  strings(first: String): StringConnection @listSize(slicingArguments: [\"first\"], sizedFields: [\"edges\"])\n}",
            ),
        ],
        [
            "[LIST_SIZE_INVALID_SLICING_ARGUMENT] [foo] \"Query.strings\" references \"first\" argument in @listSize(slicingArguments:) that is not an integer.",
        ],
    )


def test_v2_9_listsize_slicingargument_should_reference_existing_field() raises:
    # v2.9 > @listSize > slicingArgument should reference existing field
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@listSize\"])\n\ntype StringConnection {\n  edges: [String]\n  count: Int!\n}\n\ntype Query {\n  strings(first: Int): StringConnection @listSize(slicingArguments: [\"last\"], sizedFields: [\"edges\"])\n}",
            ),
        ],
        [
            "[LIST_SIZE_INVALID_SLICING_ARGUMENT] [foo] \"Query.strings\" references \"last\" argument in @listSize(slicingArguments:) that does not exist.",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
