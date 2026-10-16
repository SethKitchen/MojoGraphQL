# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/FIELD_ARGUMENT_DEFAULT_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_field_argument_default_mismatch() raises:
    # v2.0 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_field_argument_default_mismatch() raises:
    # v2.1 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_field_argument_default_mismatch() raises:
    # v2.2 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_field_argument_default_mismatch() raises:
    # v2.3 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_field_argument_default_mismatch() raises:
    # v2.4 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_field_argument_default_mismatch() raises:
    # v2.5 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_field_argument_default_mismatch() raises:
    # v2.6 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_field_argument_default_mismatch() raises:
    # v2.7 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_field_argument_default_mismatch() raises:
    # v2.8 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_field_argument_default_mismatch() raises:
    # v2.9 > FIELD_ARGUMENT_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FRIEND): [User!]!\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
