# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/REQUIRES_INVALID_FIELDS.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_requires_invalid_fields() raises:
    # v2.0 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_1_requires_invalid_fields() raises:
    # v2.1 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_2_requires_invalid_fields() raises:
    # v2.2 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_3_requires_invalid_fields() raises:
    # v2.3 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_4_requires_invalid_fields() raises:
    # v2.4 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_5_requires_invalid_fields() raises:
    # v2.5 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_6_requires_invalid_fields() raises:
    # v2.6 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_7_requires_invalid_fields() raises:
    # v2.7 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_8_requires_invalid_fields() raises:
    # v2.8 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_9_requires_invalid_fields() raises:
    # v2.9 > REQUIRES_INVALID_FIELDS
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
                    ' "id") {\n  id: ID\n  favoriteFriend: Friend'
                    ' @requires(fields: "id { }")\n  friends: [Friend!]!'
                    ' @requires(fields: "id name")\n  topFriends: [Friend!]!'
                    ' @requires(fields: "leastFavoriteFriend { id }")\n '
                    " topLeastFavoriteFriends: [Friend!]! @requires(fields:"
                    ' "leastFavoriteFriend {}")\n  leastFavoriteFriend: Friend'
                    ' @requires(fields: "leastFavoriteFriend { name'
                    ' }")\n}\n\ntype Friend {\n  id: ID\n  friendsCount: Int\n '
                    " comment: String\n}"
                ),
            ),
        ],
        [
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.favoriteFriend", for @requires(fields: "id { }"):'
                ' Syntax Error: Expected Name, found "}".'
            ),
            (
                "[REQUIRES_FIELDS_MISSING_EXTERNAL] [friends] On field"
                ' "User.friends", for @requires(fields: "id name"): field'
                ' "User.id" should not be part of a @requires since it is'
                " already provided by this subgraph (it is not marked"
                " @external)"
            ),
            (
                '[REQUIRES_INVALID_FIELDS] [friends] On field "User.friends",'
                ' for @requires(fields: "id name"): Cannot query field "name"'
                ' on type "User" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.topLeastFavoriteFriends", for @requires(fields:'
                ' "leastFavoriteFriend {}"): Syntax Error: Expected Name, found'
                ' "}".'
            ),
            (
                "[REQUIRES_INVALID_FIELDS] [friends] On field"
                ' "User.leastFavoriteFriend", for @requires(fields:'
                ' "leastFavoriteFriend { name }"): Cannot query field "name" on'
                ' type "Friend" (if the field is defined in another subgraph,'
                " you need to add it to this subgraph with @external)."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
