# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/REQUIRES_INVALID_FIELDS_TYPE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_requires_invalid_fields_type_int() raises:
    # v2.0 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_0_requires_invalid_fields_type_enum() raises:
    # v2.0 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_requires_invalid_fields_type_int() raises:
    # v2.1 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_1_requires_invalid_fields_type_enum() raises:
    # v2.1 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_requires_invalid_fields_type_int() raises:
    # v2.2 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_2_requires_invalid_fields_type_enum() raises:
    # v2.2 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_requires_invalid_fields_type_int() raises:
    # v2.3 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_3_requires_invalid_fields_type_enum() raises:
    # v2.3 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_requires_invalid_fields_type_int() raises:
    # v2.4 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_4_requires_invalid_fields_type_enum() raises:
    # v2.4 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_requires_invalid_fields_type_int() raises:
    # v2.5 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_5_requires_invalid_fields_type_enum() raises:
    # v2.5 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_requires_invalid_fields_type_int() raises:
    # v2.6 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_6_requires_invalid_fields_type_enum() raises:
    # v2.6 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_requires_invalid_fields_type_int() raises:
    # v2.7 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_7_requires_invalid_fields_type_enum() raises:
    # v2.7 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_requires_invalid_fields_type_int() raises:
    # v2.8 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_8_requires_invalid_fields_type_enum() raises:
    # v2.8 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_requires_invalid_fields_type_int() raises:
    # v2.9 > REQUIRES_INVALID_FIELDS_TYPE - INT
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@requires"])\n\nextend type User @key(fields:'
                    ' "id") {\n  id: ID\n  friends: [User!]! @requires(fields:'
                    " 123)\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS_TYPE] [friends] On field"
                ' "User.friends", for @requires(fields: 123): Invalid value for'
                ' argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_9_requires_invalid_fields_type_enum() raises:
    # v2.9 > REQUIRES_INVALID_FIELDS_TYPE - ENUM
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "friends",
                (
                    'extend type User @key(fields: "id") {\n  id: ID\n '
                    " friends: [User!]! @requires(fields: id)\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
