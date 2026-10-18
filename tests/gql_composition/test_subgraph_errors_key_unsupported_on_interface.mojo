# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/KEY_UNSUPPORTED_ON_INTERFACE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_key_unsupported_on_interface() raises:
    # v2.0 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )


def test_v2_1_key_unsupported_on_interface() raises:
    # v2.1 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )


def test_v2_2_key_unsupported_on_interface() raises:
    # v2.2 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )


def test_v2_3_key_unsupported_on_interface() raises:
    # v2.3 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_key_unsupported_on_interface() raises:
    # v2.4 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_key_unsupported_on_interface() raises:
    # v2.5 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_key_unsupported_on_interface() raises:
    # v2.6 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_key_unsupported_on_interface() raises:
    # v2.7 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_key_unsupported_on_interface() raises:
    # v2.8 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_key_unsupported_on_interface() raises:
    # v2.9 > KEY_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
