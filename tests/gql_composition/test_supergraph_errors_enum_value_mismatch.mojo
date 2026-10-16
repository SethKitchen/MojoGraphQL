# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/ENUM_VALUE_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_enum_value_mismatch() raises:
    # v2.0 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_enum_value_mismatch() raises:
    # v2.1 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_enum_value_mismatch() raises:
    # v2.2 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_enum_value_mismatch() raises:
    # v2.3 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_enum_value_mismatch() raises:
    # v2.4 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_enum_value_mismatch() raises:
    # v2.5 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_enum_value_mismatch() raises:
    # v2.6 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_enum_value_mismatch() raises:
    # v2.7 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_enum_value_mismatch() raises:
    # v2.8 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_enum_value_mismatch() raises:
    # v2.9 > ENUM_VALUE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  ANONYMOUS\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  REGULAR\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@shareable\"])\n\ntype Query {\n  usersByType(type: UserType): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType @shareable\n}\n\nenum UserType {\n  ANONYMOUS @inaccessible\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
