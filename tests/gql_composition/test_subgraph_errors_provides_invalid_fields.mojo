# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/PROVIDES_INVALID_FIELDS.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_provides_invalid_fields_cannot_query_field() raises:
    # v2.0 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_0_empty_selection_set() raises:
    # v2.0 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_0_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.0 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_provides_invalid_fields_cannot_query_field() raises:
    # v2.1 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_1_empty_selection_set() raises:
    # v2.1 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_1_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.1 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_provides_invalid_fields_cannot_query_field() raises:
    # v2.2 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_2_empty_selection_set() raises:
    # v2.2 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_2_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.2 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_provides_invalid_fields_cannot_query_field() raises:
    # v2.3 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_3_empty_selection_set() raises:
    # v2.3 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_3_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.3 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_provides_invalid_fields_cannot_query_field() raises:
    # v2.4 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_4_empty_selection_set() raises:
    # v2.4 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_4_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.4 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_provides_invalid_fields_cannot_query_field() raises:
    # v2.5 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_5_empty_selection_set() raises:
    # v2.5 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_5_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.5 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_provides_invalid_fields_cannot_query_field() raises:
    # v2.6 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_6_empty_selection_set() raises:
    # v2.6 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_6_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.6 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_provides_invalid_fields_cannot_query_field() raises:
    # v2.7 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_7_empty_selection_set() raises:
    # v2.7 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_7_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.7 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_provides_invalid_fields_cannot_query_field() raises:
    # v2.8 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_8_empty_selection_set() raises:
    # v2.8 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_8_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.8 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_provides_invalid_fields_cannot_query_field() raises:
    # v2.9 > PROVIDES_INVALID_FIELDS > Cannot query field
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
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Post]\n}\n\ntype Post @key(fields: "id") {\n  id:'
                    " ID!\n  author: User @provides(fields:"
                    ' "userId")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @external\n}"
                ),
            ),
        ],
        [
            (
                '[PROVIDES_INVALID_FIELDS] [feed] On field "Post.author", for'
                ' @provides(fields: "userId"): Cannot query field "userId" on'
                ' type "User" (if the field is defined in another subgraph, you'
                " need to add it to this subgraph with @external)."
            ),
        ],
    )


def test_v2_9_empty_selection_set() raises:
    # v2.9 > empty selection set
    check(
        [
            sg(
                "roles",
                (
                    "type Query {\n  team: Team! @provides(fields:"
                    ' "users")\n}\n\ntype User @key(fields: "id") @extends {\n '
                    " id: String! @external\n  role: [Role!]\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n '
                    " users: [User!]\n}\n\ntype Role {\n  id: ID!\n  name:"
                    " String\n}"
                ),
            ),
            sg(
                "teams",
                (
                    'type Team @key(fields: "id") {\n  id: String!\n  name:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " String!\n  name: String\n}"
                ),
            ),
            sg(
                "organization",
                (
                    "type Query {\n  organization(id: String!): Organization!"
                    ' @provides(fields: "teams")\n}\n\ntype Organization {\n '
                    " name: String\n  teams: [Team!]!\n}\n\ntype Team"
                    ' @key(fields: "id") @extends {\n  id: String! @external\n}'
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS] [organization] On field"
                ' "Query.organization", for @provides(fields: "teams"): Invalid'
                ' empty selection set for field "Organization.teams" of'
                " non-leaf type [Team!]!"
            ),
            (
                '[PROVIDES_INVALID_FIELDS] [roles] On field "Query.team", for'
                ' @provides(fields: "users"): Invalid empty selection set for'
                ' field "Team.users" of non-leaf type [User!]'
            ),
        ],
    )


def test_v2_9_error_expected_abstract_indexes_to_be_defined() raises:
    # v2.9 > error: Expected abstract indexes to be defined
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  a:'
                    " Int!\n}\n\ninterface SomeInterface {\n  id: ID!\n "
                    " someField: String!\n}\n\ntype AAAAAAAAAAAAA implements"
                    ' SomeInterface @key(fields: "id") {\n  id: ID!\n '
                    " someField: String! @shareable\n}\n\ntype BBBBBBBBBBBBB"
                    ' @shareable @key(fields: "id") {\n  id: ID!\n '
                    " aaaaaaaaaaaa: SomeInterface!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@shareable", "@external"])\n\ntype'
                    " Query {\n  b: Int!\n}\n\ntype MutationResponse @shareable"
                    " {\n  bbbbbbbbbbbbb: BBBBBBBBBBBBB!\n}\n\ntype"
                    ' BBBBBBBBBBBBB @key(fields: "id") @shareable {\n  id:'
                    " ID!\n  aaaaaaaaaaaa: AAAAAAAAAAAAA!\n}\n\ntype Mutation"
                    " {\n  mutationField: MutationResponse! @provides(fields:"
                    ' "bbbbbbbbbbbbb { aaaaaaaaaaaa { someField }'
                    ' }")\n}\n\ntype AAAAAAAAAAAAA @key(fields: "id") {\n  id:'
                    " ID! @external\n  someField: String! @external\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
