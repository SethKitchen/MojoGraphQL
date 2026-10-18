# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/PROVIDES_FIELDS_MISSING_EXTERNAL.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_provides_fields_missing_external() raises:
    # v2.0 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_0_provides_fields_missing_external_on_external_historical() raises:
    # v2.0 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_0_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.0 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_1_provides_fields_missing_external() raises:
    # v2.1 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_1_provides_fields_missing_external_on_external_historical() raises:
    # v2.1 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_1_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.1 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_2_provides_fields_missing_external() raises:
    # v2.2 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_2_provides_fields_missing_external_on_external_historical() raises:
    # v2.2 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_2_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.2 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_3_provides_fields_missing_external() raises:
    # v2.3 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_3_provides_fields_missing_external_on_external_historical() raises:
    # v2.3 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_3_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.3 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_4_provides_fields_missing_external() raises:
    # v2.4 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_4_provides_fields_missing_external_on_external_historical() raises:
    # v2.4 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_4_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.4 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_5_provides_fields_missing_external() raises:
    # v2.5 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_5_provides_fields_missing_external_on_external_historical() raises:
    # v2.5 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_5_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.5 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_6_provides_fields_missing_external() raises:
    # v2.6 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_6_provides_fields_missing_external_on_external_historical() raises:
    # v2.6 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_6_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.6 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_7_provides_fields_missing_external() raises:
    # v2.7 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_7_provides_fields_missing_external_on_external_historical() raises:
    # v2.7 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_7_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.7 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_provides_fields_missing_external() raises:
    # v2.8 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_8_provides_fields_missing_external_on_external_historical() raises:
    # v2.8 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_8_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.8 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_provides_fields_missing_external() raises:
    # v2.9 > PROVIDES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@provides"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " internalId: ID!\n  profile: Profile @provides(fields:"
                    ' "name")\n}\n\ntype Profile {\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [users] On field"
                ' "User.profile", for @provides(fields: "name"): field'
                ' "Profile.name" should not be part of a @provides since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
        ],
    )


def test_v2_9_provides_fields_missing_external_on_external_historical() raises:
    # v2.9 > PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@provides", "@external", "@extends"])\n\ntype'
                    " Query {\n  review: Review\n}\n\ntype Review {\n  author:"
                    ' User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_FIELDS_MISSING_EXTERNAL] [reviews] On field"
                ' "Review.author", for @provides(fields: "id"): field "User.id"'
                " should not be part of a @provides since it is already"
                ' "effectively" provided by this subgraph (while it is marked'
                " @external, it is a @key field of an extension type, which are"
                " not internally considered external for historical/backward"
                " compatibility reasons)"
            ),
        ],
    )


def test_v2_9_fed_v1_no_provides_fields_missing_external_on_external_historical() raises:
    # v2.9 > Fed v1: NO PROVIDES_FIELDS_MISSING_EXTERNAL on external (historical)
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "reviews",
                (
                    "type Query {\n  review: Review\n}\n\ntype Review {\n "
                    ' author: User! @provides(fields: "id")\n}\n\ntype User'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
