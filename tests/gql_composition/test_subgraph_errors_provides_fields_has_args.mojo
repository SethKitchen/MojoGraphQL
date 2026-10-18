# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/PROVIDES_FIELDS_HAS_ARGS.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_provides_fields_has_args() raises:
    # v2.0 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_1_provides_fields_has_args() raises:
    # v2.1 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_2_provides_fields_has_args() raises:
    # v2.2 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_3_provides_fields_has_args() raises:
    # v2.3 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_4_provides_fields_has_args() raises:
    # v2.4 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_5_provides_fields_has_args() raises:
    # v2.5 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_6_provides_fields_has_args() raises:
    # v2.6 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_7_provides_fields_has_args() raises:
    # v2.7 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_8_provides_fields_has_args() raises:
    # v2.8 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def test_v2_9_provides_fields_has_args() raises:
    # v2.9 > PROVIDES_FIELDS_HAS_ARGS
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags(limit:'
                    " UserType = ADMIN): [String]\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "isd") {\n '
                    " id: ID!\n  tags(limit: UserType = REGULAR): [String]"
                    " @external\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_FIELDS_HAS_ARGS] [feed] On field "Article.author",'
                ' for @provides(fields: "tags"): field User.tags cannot be'
                " included because it has arguments (fields with argument are"
                " not allowed in @provides)"
            ),
            (
                '[KEY_INVALID_FIELDS] [feed] On type "User", for @key(fields:'
                ' "isd"): Cannot query field "isd" on type "User" (the field'
                " should either be added to this subgraph or, if it should not"
                " be resolved by this subgraph, you need to add it to this"
                " subgraph with @external)."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
