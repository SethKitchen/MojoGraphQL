# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/ENUM_VALUE_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `ENUM_VALUE_MISMATCH` from
`composeServices` on the same subgraphs. A sharing error that Hive
reports for the same subgraphs is included. The last tests lock a
value defined in two subgraphs, an input enum with a shared value, and
an output-only enum. They are not in the upstream file.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_enum_value_mismatch() raises:
    # v2.0 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_enum_value_mismatch() raises:
    # v2.1 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_enum_value_mismatch() raises:
    # v2.2 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_enum_value_mismatch() raises:
    # v2.3 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_enum_value_mismatch() raises:
    # v2.4 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_enum_value_mismatch() raises:
    # v2.5 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_enum_value_mismatch() raises:
    # v2.6 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_enum_value_mismatch() raises:
    # v2.7 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_enum_value_mismatch() raises:
    # v2.8 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_enum_value_mismatch() raises:
    # v2.9 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType\n}\n\nenum UserType {\n  REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  usersByType(type: UserType):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " ANONYMOUS\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "ANONYMOUS" is not defined in'
                ' all the subgraphs defining "UserType": "ANONYMOUS" is defined'
                ' in subgraph "feed" but not in subgraph "users"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "UserType" is used as both'
                " input type (for example, as type of"
                ' "Query.usersByType(type:)") and output type (for example, as'
                ' type of "User.type"), but value "REGULAR" is not defined in'
                ' all the subgraphs defining "UserType": "REGULAR" is defined'
                ' in subgraph "users" but not in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " type: UserType @shareable\n}\n\nenum UserType {\n "
                    " REGULAR\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible", "@shareable"])\n\ntype Query'
                    " {\n  usersByType(type: UserType): [User!]!\n}\n\nextend"
                    ' type User @key(fields: "id") {\n  id: ID\n  type:'
                    " UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS"
                    " @inaccessible\n  REGULAR\n}"
                ),
            ),
        ],
        [],
    )


def test_a_value_defined_in_two_subgraphs() raises:
    # `A` is missing from one subgraph, so the list is plural.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  q(t: E): E\n}\n\nenum E {\n '
                    " A\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  p: E\n}\n\nenum E {\n  A\n}'
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  r: Int\n}\n\nenum E {\n '
                    " B\n}"
                ),
            ),
        ],
        [
            (
                '[ENUM_VALUE_MISMATCH] Enum type "E" is used as both input type'
                ' (for example, as type of "Query.q(t:)") and output type (for'
                ' example, as type of "Query.q"), but value "A" is not defined'
                ' in all the subgraphs defining "E": "A" is defined in'
                ' subgraphs "a", "b" but not in subgraph "c"'
            ),
            (
                '[ENUM_VALUE_MISMATCH] Enum type "E" is used as both input type'
                ' (for example, as type of "Query.q(t:)") and output type (for'
                ' example, as type of "Query.q"), but value "B" is not defined'
                ' in all the subgraphs defining "E": "B" is defined in subgraph'
                ' "c" but not in subgraphs "a", "b"'
            ),
        ],
    )


def test_an_input_enum_with_a_shared_value_is_valid() raises:
    # One shared value is enough when the enum is only an input.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  q(t: E): Int\n}\n\nenum E'
                    " {\n  A\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  p(t: E): Int\n}\n\nenum E'
                    " {\n  A\n  B\n}"
                ),
            ),
        ],
        [],
    )


def test_an_output_enum_can_differ() raises:
    # An enum used only as an output does not have to share its values.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  q: E\n}\n\nenum E {\n  A\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  p: E\n}\n\nenum E {\n  B\n}'
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
