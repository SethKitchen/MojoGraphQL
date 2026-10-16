# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/EXTERNAL_ARGUMENT_MISSING.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_external_argument_missing() raises:
    # v2.0 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_external_argument_missing() raises:
    # v2.1 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_external_argument_missing() raises:
    # v2.2 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_external_argument_missing() raises:
    # v2.3 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_external_argument_missing() raises:
    # v2.4 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_external_argument_missing() raises:
    # v2.5 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_external_argument_missing() raises:
    # v2.6 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_external_argument_missing() raises:
    # v2.7 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_external_argument_missing() raises:
    # v2.8 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_external_argument_missing() raises:
    # v2.9 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int!): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@provides\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @provides(fields: \"tags\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String]\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  feed: [Article]\n}\n\ntype Article @key(fields: \"id\") {\n  id: ID!\n  author: User! @requires(fields: \"author { tags }\")\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  tags: [String] @external\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
