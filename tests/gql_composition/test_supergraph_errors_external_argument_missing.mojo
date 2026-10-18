# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/EXTERNAL_ARGUMENT_MISSING.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `EXTERNAL_ARGUMENT_MISSING` from
`composeServices` on the same subgraphs. A non-null argument also
reports `REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH` first.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_external_argument_missing() raises:
    # v2.0 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_1_external_argument_missing() raises:
    # v2.1 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_2_external_argument_missing() raises:
    # v2.2 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_3_external_argument_missing() raises:
    # v2.3 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_4_external_argument_missing() raises:
    # v2.4 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_5_external_argument_missing() raises:
    # v2.5 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_6_external_argument_missing() raises:
    # v2.6 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_7_external_argument_missing() raises:
    # v2.7 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_8_external_argument_missing() raises:
    # v2.8 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_v2_9_external_argument_missing() raises:
    # v2.9 > EXTERNAL_ARGUMENT_MISSING
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " Int!): [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "User.tags(limit:)" is required in some subgraphs but does'
                " not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
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
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit: Int):'
                    " [String]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    '  id: ID!\n  author: User! @requires(fields: "author {'
                    ' tags }")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String] @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.tags" is missing'
                ' argument "User.tags(limit:)" in some subgraphs where it is'
                ' marked @external: argument "User.tags(limit:)" is declared in'
                ' subgraph "users" but not in subgraph "feed" (where'
                ' "User.tags" is @external)'
            ),
        ],
    )


def test_hive_case_ea1() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { u: User'
                    ' }\ntype User @key(fields: "id") { id: ID! name(x: Int):'
                    " String }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! name(x: Int): String @external p:'
                    ' String @requires(fields: "name") }'
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! name: String @external q: String'
                    ' @requires(fields: "name") }'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_ARGUMENT_MISSING] Field "User.name" is missing'
                ' argument "User.name(x:)" in some subgraphs where it is'
                ' marked @external: argument "User.name(x:)" is declared'
                ' in subgraph "a" but not in subgraph "c" (where'
                ' "User.name" is @external)'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
