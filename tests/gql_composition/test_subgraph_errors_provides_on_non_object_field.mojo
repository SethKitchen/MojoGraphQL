# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/PROVIDES_ON_NON_OBJECT_FIELD.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_provides_on_non_object_field() raises:
    # v2.0 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_0_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.0 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.0 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_provides_on_non_object_field() raises:
    # v2.1 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_1_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.1 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.1 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_provides_on_non_object_field() raises:
    # v2.2 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_2_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.2 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.2 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_provides_on_non_object_field() raises:
    # v2.3 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_3_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.3 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.3 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_provides_on_non_object_field() raises:
    # v2.4 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_4_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.4 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.4 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_provides_on_non_object_field() raises:
    # v2.5 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_5_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.5 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.5 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_provides_on_non_object_field() raises:
    # v2.6 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_6_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.6 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.6 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_provides_on_non_object_field() raises:
    # v2.7 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_7_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.7 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.7 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_provides_on_non_object_field() raises:
    # v2.8 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_8_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.8 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.8 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_provides_on_non_object_field() raises:
    # v2.9 > PROVIDES_ON_NON_OBJECT_FIELD
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@provides\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String @provides(fields: \"name\")\n}",
            ),
        ],
        [
            "[PROVIDES_ON_NON_OBJECT_FIELD] [users] Invalid @provides directive on field \"User.email\": field has type \"String\" which is not a Composite Type",
        ],
    )


def test_v2_9_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob() raises:
    # v2.9 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  result: ResultType\n}\n\ntype EntityA {\n  field1: String @external\n  field2: String @external\n}\n\ntype EntityB {\n  field1: String @external\n  field2: String @external\n  field3: String @external\n}\n\nunion UnionType = EntityA | EntityB\n\ntype ResultType {\n  results: [UnionType!]! @provides(fields: \"... on EntityA { field1 field2 } ... on EntityB { field1 field2 field3 }\")\n}",
            ),
            sg(
                "other",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  a: EntityA\n  b: EntityB\n}\n\nunion UnionType = EntityA | EntityB\n\ntype EntityA @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n}\n\ntype EntityB @key(fields: \"field1\") {\n  field1: String @shareable\n  field2: String @shareable\n  field3: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_provides_on_non_object_field_is_not_raised_for_union_field_with_fragment_ob_2() raises:
    # v2.9 > PROVIDES_ON_NON_OBJECT_FIELD: is not raised for union field with fragment object type selection sets (variant)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@provides\", \"@external\"])\n\ntype Query {\n  media: [Media] @shareable @provides(fields: \"... on Book { title }\")\n}\n\nunion Media = Book | Movie\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @external\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}\n\ntype Movie @key(fields: \"id\") {\n  id: ID!\n  title: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
