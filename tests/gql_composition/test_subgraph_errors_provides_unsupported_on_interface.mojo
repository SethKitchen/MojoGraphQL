# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/PROVIDES_UNSUPPORTED_ON_INTERFACE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_provides_unsupported_on_interface() raises:
    # v2.0 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_1_provides_unsupported_on_interface() raises:
    # v2.1 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_2_provides_unsupported_on_interface() raises:
    # v2.2 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_3_provides_unsupported_on_interface() raises:
    # v2.3 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_4_provides_unsupported_on_interface() raises:
    # v2.4 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_5_provides_unsupported_on_interface() raises:
    # v2.5 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_6_provides_unsupported_on_interface() raises:
    # v2.6 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_7_provides_unsupported_on_interface() raises:
    # v2.7 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_8_provides_unsupported_on_interface() raises:
    # v2.8 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def test_v2_9_provides_unsupported_on_interface() raises:
    # v2.9 > PROVIDES_UNSUPPORTED_ON_INTERFACE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    " [User]\n}\n\ntype RegisteredUser implements User"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    ' profile: Profile\n}\n\ninterface User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String!\n  profile: Profile"
                    ' @provides(fields: "name")\n}\n\ntype Profile {\n  name:'
                    " String\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_UNSUPPORTED_ON_INTERFACE] [users] Cannot use"
                ' @provides on field "User.profile" of parent type "User":'
                " @provides is not yet supported within interfaces"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
