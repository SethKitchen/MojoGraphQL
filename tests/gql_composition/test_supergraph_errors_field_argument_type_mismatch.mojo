# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/FIELD_ARGUMENT_TYPE_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_field_argument_type_mismatch() raises:
    # v2.0 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.0 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.0 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.0 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_field_argument_type_mismatch() raises:
    # v2.1 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.1 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.1 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.1 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_field_argument_type_mismatch() raises:
    # v2.2 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.2 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.2 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.2 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_field_argument_type_mismatch() raises:
    # v2.3 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.3 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.3 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.3 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_field_argument_type_mismatch() raises:
    # v2.4 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.4 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.4 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.4 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_field_argument_type_mismatch() raises:
    # v2.5 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.5 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.5 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.5 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_field_argument_type_mismatch() raises:
    # v2.6 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.6 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.6 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.6 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_field_argument_type_mismatch() raises:
    # v2.7 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.7 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.7 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.7 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_field_argument_type_mismatch() raises:
    # v2.8 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.8 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.8 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.8 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_field_argument_type_mismatch() raises:
    # v2.9 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users(type: UserType!): [User!]!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nextend type Query {\n  users(type: String!): [User!]!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.9 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.9 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @a(n: String) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.9 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query {\n  b: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype Query {\n  c: Int\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
