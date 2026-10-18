# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `EMPTY_MERGED_INPUT_TYPE` and
`REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH` from `composeServices`
on the same subgraphs. The empty-input error comes first.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_required_input_field_missing_in_some_subgraph() raises:
    # v2.0 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_1_required_input_field_missing_in_some_subgraph() raises:
    # v2.1 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_2_required_input_field_missing_in_some_subgraph() raises:
    # v2.2 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_3_required_input_field_missing_in_some_subgraph() raises:
    # v2.3 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_4_required_input_field_missing_in_some_subgraph() raises:
    # v2.4 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_5_required_input_field_missing_in_some_subgraph() raises:
    # v2.5 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_6_required_input_field_missing_in_some_subgraph() raises:
    # v2.6 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_7_required_input_field_missing_in_some_subgraph() raises:
    # v2.7 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_8_required_input_field_missing_in_some_subgraph() raises:
    # v2.8 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_9_required_input_field_missing_in_some_subgraph() raises:
    # v2.9 > REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype'
                    " Mutation {\n  createUser(input: CreateUser!):"
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n}\n\ninput CreateUser {\n  id: ID!\n  profile:"
                    " ProfileInput!\n}\n\ninput ProfileInput {\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\nextend type Mutation {\n  updateUser(input:'
                    " UpdateUser!): User!\n}\n\nextend type User @key(fields:"
                    ' "id") {\n  id: ID\n}\n\ninput UpdateUser {\n  id: ID!\n '
                    " profile: ProfileInput!\n}\n\nextend input ProfileInput"
                    " {\n  reason: String\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "ProfileInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "ProfileInput.name" is required in some subgraphs but'
                " does not appear in all subgraphs: it is required in subgraph"
                ' "users" but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_required_nullable_and_missing() raises:
    # Only subgraph "a" requires the field; "b" has it nullable.
    var head = String(
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3", import: ["@key"])\n\n'
    )
    check(
        [
            sg(
                "a",
                head
                + "type Query {\n  f(i: In): Int\n}\n\ninput In {\n  x: Int!\n"
                + "  y: Int\n}",
            ),
            sg("b", head + "input In {\n  x: Int\n  y: Int\n}"),
            sg("c", head + "input In {\n  y: Int\n}"),
        ],
        [
            (
                "[REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH] Input object"
                ' field "In.x" is required in some subgraphs but does not'
                " appear in all subgraphs: it is required in subgraph"
                ' "a" but does not appear in subgraph "c"'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
