# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/INPUT_FIELD_DEFAULT_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_input_field_default_mismatch() raises:
    # v2.0 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_input_field_default_mismatch() raises:
    # v2.1 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_input_field_default_mismatch() raises:
    # v2.2 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_input_field_default_mismatch() raises:
    # v2.3 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_input_field_default_mismatch() raises:
    # v2.4 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_input_field_default_mismatch() raises:
    # v2.5 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_input_field_default_mismatch() raises:
    # v2.6 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_input_field_default_mismatch() raises:
    # v2.7 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_input_field_default_mismatch() raises:
    # v2.8 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_input_field_default_mismatch() raises:
    # v2.9 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\ninput Filter {\n  limit: Int = 5\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ninput Filter {\n  limit: Int = 10\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n}\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FAMILY\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nenum FriendType {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type: FriendType = FRIEND\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
