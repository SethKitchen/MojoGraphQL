# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/INPUT_FIELD_DEFAULT_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `INPUT_FIELD_DEFAULT_MISMATCH` from
`composeServices` on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_input_field_default_mismatch() raises:
    # v2.0 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_1_input_field_default_mismatch() raises:
    # v2.1 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_2_input_field_default_mismatch() raises:
    # v2.2 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_3_input_field_default_mismatch() raises:
    # v2.3 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_4_input_field_default_mismatch() raises:
    # v2.4 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_5_input_field_default_mismatch() raises:
    # v2.5 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_6_input_field_default_mismatch() raises:
    # v2.6 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_7_input_field_default_mismatch() raises:
    # v2.7 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_8_input_field_default_mismatch() raises:
    # v2.8 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_v2_9_input_field_default_mismatch() raises:
    # v2.9 > INPUT_FIELD_DEFAULT_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\ninput Filter'
                    " {\n  limit: Int = 5\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ninput Filter {\n  limit: Int = 10\n}'
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.limit" has'
                " incompatible default values across subgraphs: it has default"
                ' value 10 in subgraph "friends" but default value 5 in'
                ' subgraph "users"'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n}\n\nenum FriendType'
                    " {\n  FAMILY\n  FRIEND\n}\n\ninput Filter {\n  type:"
                    " FriendType = FAMILY\n}"
                ),
            ),
            sg(
                "friends",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\nenum FriendType {\n  FAMILY\n '
                    " FRIEND\n}\n\ninput Filter {\n  type: FriendType ="
                    " FRIEND\n}"
                ),
            ),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "Filter.type" has'
                " incompatible default values across subgraphs: it has default"
                ' value FRIEND in subgraph "friends" but default value FAMILY'
                ' in subgraph "users"'
            ),
        ],
    )


def test_three_defaults_and_a_shared_default() raises:
    # Three groups: Hive joins the third with "and", and a group of two
    # subgraphs says "subgraphs".
    var head = String(
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3", import: ["@key"])\n\n'
    )
    check(
        [
            sg(
                "a",
                head
                + "type Query {\n  f(i: In): Int\n}\n\ninput In {\n  x: Int ="
                " 1\n}",
            ),
            sg("b", head + "input In {\n  x: Int = 1\n}"),
            sg("c", head + "input In {\n  x: Int = 2\n}"),
            sg("d", head + "input In {\n  x: Int = 3\n}"),
        ],
        [
            (
                '[INPUT_FIELD_DEFAULT_MISMATCH] Input field "In.x" has'
                " incompatible default values across subgraphs: it has"
                ' default value 1 in subgraphs "a", "b" but default value 2'
                ' in subgraph "c" and default value 3 in subgraph "d"'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
