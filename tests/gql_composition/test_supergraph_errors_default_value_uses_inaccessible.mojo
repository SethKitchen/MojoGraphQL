# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/DEFAULT_VALUE_USES_INACCESSIBLE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_default_value_uses_inaccessible() raises:
    # v2.0 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_default_value_uses_inaccessible() raises:
    # v2.1 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_default_value_uses_inaccessible() raises:
    # v2.2 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_default_value_uses_inaccessible() raises:
    # v2.3 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_default_value_uses_inaccessible() raises:
    # v2.4 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_default_value_uses_inaccessible() raises:
    # v2.5 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_default_value_uses_inaccessible() raises:
    # v2.6 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_default_value_uses_inaccessible() raises:
    # v2.7 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_default_value_uses_inaccessible() raises:
    # v2.8 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_default_value_uses_inaccessible() raises:
    # v2.9 > DEFAULT_VALUE_USES_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  friends(type: FriendType = FAMILY @inaccessible): [User!]!\n}\n\nenum FriendType {\n  FAMILY @inaccessible\n  FRIEND\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a @inaccessible\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\nenum FooEnum @inaccessible {\n  a\n}\n\ninput FooInput @inaccessible {\n  foo: FooEnum! = a @inaccessible\n}\n\ntype Query {\n  a: String!\n  b(foo: FooInput @inaccessible): String! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
