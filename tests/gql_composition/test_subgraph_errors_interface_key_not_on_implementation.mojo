# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/INTERFACE_KEY_NOT_ON_IMPLEMENTATION.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_interface_key_not_on_implementation() raises:
    # v2.0 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )


def test_v2_1_interface_key_not_on_implementation() raises:
    # v2.1 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )


def test_v2_2_interface_key_not_on_implementation() raises:
    # v2.2 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )


def test_v2_3_interface_key_not_on_implementation() raises:
    # v2.3 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [users] Key @key(fields: \"id\") on interface type \"User\" is missing on implementation type \"RegisteredUser\".",
        ],
    )


def test_v2_3_no_interface_key_not_on_implementation_on_interfaces() raises:
    # v2.3 > No INTERFACE_KEY_NOT_ON_IMPLEMENTATION on interfaces
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User & Node @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User implements Node {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_interface_key_not_on_implementation() raises:
    # v2.4 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [users] Key @key(fields: \"id\") on interface type \"User\" is missing on implementation type \"RegisteredUser\".",
        ],
    )


def test_v2_4_no_interface_key_not_on_implementation_on_interfaces() raises:
    # v2.4 > No INTERFACE_KEY_NOT_ON_IMPLEMENTATION on interfaces
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User & Node @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User implements Node {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_interface_key_not_on_implementation() raises:
    # v2.5 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [users] Key @key(fields: \"id\") on interface type \"User\" is missing on implementation type \"RegisteredUser\".",
        ],
    )


def test_v2_5_no_interface_key_not_on_implementation_on_interfaces() raises:
    # v2.5 > No INTERFACE_KEY_NOT_ON_IMPLEMENTATION on interfaces
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User & Node @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User implements Node {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_interface_key_not_on_implementation() raises:
    # v2.6 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [users] Key @key(fields: \"id\") on interface type \"User\" is missing on implementation type \"RegisteredUser\".",
        ],
    )


def test_v2_6_no_interface_key_not_on_implementation_on_interfaces() raises:
    # v2.6 > No INTERFACE_KEY_NOT_ON_IMPLEMENTATION on interfaces
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User & Node @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User implements Node {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_interface_key_not_on_implementation() raises:
    # v2.7 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [users] Key @key(fields: \"id\") on interface type \"User\" is missing on implementation type \"RegisteredUser\".",
        ],
    )


def test_v2_7_no_interface_key_not_on_implementation_on_interfaces() raises:
    # v2.7 > No INTERFACE_KEY_NOT_ON_IMPLEMENTATION on interfaces
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User & Node @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User implements Node {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_interface_key_not_on_implementation() raises:
    # v2.8 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [users] Key @key(fields: \"id\") on interface type \"User\" is missing on implementation type \"RegisteredUser\".",
        ],
    )


def test_v2_8_no_interface_key_not_on_implementation_on_interfaces() raises:
    # v2.8 > No INTERFACE_KEY_NOT_ON_IMPLEMENTATION on interfaces
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User & Node @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User implements Node {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_interface_key_not_on_implementation() raises:
    # v2.9 > INTERFACE_KEY_NOT_ON_IMPLEMENTATION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[INTERFACE_KEY_NOT_ON_IMPLEMENTATION] [users] Key @key(fields: \"id\") on interface type \"User\" is missing on implementation type \"RegisteredUser\".",
        ],
    )


def test_v2_9_no_interface_key_not_on_implementation_on_interfaces() raises:
    # v2.9 > No INTERFACE_KEY_NOT_ON_IMPLEMENTATION on interfaces
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype RegisteredUser implements User & Node @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface User implements Node {\n  id: ID!\n  name: String!\n  email: String\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
