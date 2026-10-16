# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/ROOT_SUBSCRIPTION_USED.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_root_subscription_used() raises:
    # v2.0 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_1_root_subscription_used() raises:
    # v2.1 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_2_root_subscription_used() raises:
    # v2.2 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_3_root_subscription_used() raises:
    # v2.3 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_4_root_subscription_used() raises:
    # v2.4 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_5_root_subscription_used() raises:
    # v2.5 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_6_root_subscription_used() raises:
    # v2.6 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_7_root_subscription_used() raises:
    # v2.7 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_8_root_subscription_used() raises:
    # v2.8 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def test_v2_9_root_subscription_used() raises:
    # v2.9 > ROOT_SUBSCRIPTION_USED
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Subscription {\n  users: [User!]!\n}\n\nschema {\n  subscription: RootSubscription\n}\n\ntype RootSubscription {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends: [User!]!\n}",
            ),
        ],
        [
            "[ROOT_SUBSCRIPTION_USED] [users] The schema has a type named \"Subscription\" but it is not set as the subscription root type (\"RootSubscription\" is instead): this is not supported by federation. If a root type does not use its default name, there should be no other type with that default name.",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
