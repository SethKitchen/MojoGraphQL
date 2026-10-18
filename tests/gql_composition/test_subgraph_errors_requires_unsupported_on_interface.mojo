# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/REQUIRES_UNSUPPORTED_ON_INTERFACE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_requires_unsupported_on_interface() raises:
    # v2.0 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_1_requires_unsupported_on_interface() raises:
    # v2.1 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_2_requires_unsupported_on_interface() raises:
    # v2.2 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_3_requires_unsupported_on_interface() raises:
    # v2.3 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_4_requires_unsupported_on_interface() raises:
    # v2.4 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_5_requires_unsupported_on_interface() raises:
    # v2.5 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_6_requires_unsupported_on_interface() raises:
    # v2.6 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_7_requires_unsupported_on_interface() raises:
    # v2.7 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_8_requires_unsupported_on_interface() raises:
    # v2.8 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_9_requires_unsupported_on_interface() raises:
    # v2.9 > REQUIRES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@requires"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' email: String\n}\n\ninterface User @key(fields: "id") {\n'
                    "  id: ID!\n  name: String!\n  email: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                "[REQUIRES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @requires on field "User.email" of parent type "User":'
                " @requires is not yet supported within interfaces"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
