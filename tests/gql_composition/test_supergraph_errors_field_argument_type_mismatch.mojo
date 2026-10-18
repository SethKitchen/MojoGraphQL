# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/FIELD_ARGUMENT_TYPE_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `FIELD_ARGUMENT_TYPE_MISMATCH` from
`composeServices` on the same subgraphs. A sharing error that Hive
reports for the same subgraphs is included. The last tests lock a
third argument type and a directive that is not executable. They are
not in the upstream file.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_field_argument_type_mismatch() raises:
    # v2.0 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_0_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.0 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_0_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.0 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_0_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.0 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_1_field_argument_type_mismatch() raises:
    # v2.1 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_1_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.1 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_1_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.1 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_1_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.1 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_2_field_argument_type_mismatch() raises:
    # v2.2 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_2_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.2 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_2_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.2 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_2_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.2 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_3_field_argument_type_mismatch() raises:
    # v2.3 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_3_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.3 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_3_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.3 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_3_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.3 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_4_field_argument_type_mismatch() raises:
    # v2.4 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_4_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.4 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_4_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.4 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_4_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.4 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_5_field_argument_type_mismatch() raises:
    # v2.5 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_5_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.5 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_5_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.5 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_5_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.5 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_6_field_argument_type_mismatch() raises:
    # v2.6 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_6_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.6 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_6_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.6 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_6_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.6 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_7_field_argument_type_mismatch() raises:
    # v2.7 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_7_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.7 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_7_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.7 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_7_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.7 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_8_field_argument_type_mismatch() raises:
    # v2.8 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_8_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.8 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_8_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.8 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_8_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.8 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_v2_9_field_argument_type_mismatch() raises:
    # v2.9 > FIELD_ARGUMENT_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users(type: UserType!):'
                    ' [User!]!\n}\n\ntype User @key(fields: "id") {\n  id: ID\n'
                    "  type: UserType\n}\n\nenum UserType {\n  REGULAR\n "
                    " ADMIN\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\nextend type Query {\n  users(type: String!):'
                    ' [User!]!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID\n  type: UserType\n}\n\nenum UserType {\n "
                    " REGULAR\n  ADMIN\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(type:)" is incompatible across subgraphs: it has'
                ' type "String!" in subgraph "feed" but type "UserType!" in'
                ' subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.type" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
        ],
    )


def test_v2_9_field_argument_type_mismatch_directive_definition_arguments_do_not_match() raises:
    # v2.9 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_9_field_argument_type_mismatch_directive_definition_arguments_do_not_match_3() raises:
    # v2.9 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (3 different definitions)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on FIELD\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraph'
                ' "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_v2_9_field_argument_type_mismatch_directive_definition_arguments_do_not_match_pl() raises:
    # v2.9 > FIELD_ARGUMENT_TYPE_MISMATCH: directive definition arguments do not match (plural)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Boolean) on FIELD\n\ntype'
                    " Query {\n  c: Int\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@a(n:)" is'
                ' incompatible across subgraphs: it has type "Int" in subgraphs'
                ' "a" and "b" but type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_three_argument_types() raises:
    # Three named types. Hive joins the third group with "and".
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users(x: Int):'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users(x: String):'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users(x: Boolean):'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a", "b" and "c" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.users(x:)" is incompatible across subgraphs: it has'
                ' type "Int" in subgraph "a" but type "String" in subgraph "b"'
                ' and type "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_a_non_null_argument_matches_the_nullable_type() raises:
    # `String` and `String!` are the same argument type.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users(x: String): Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users(x: String!): Int\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
        ],
    )


def test_a_type_system_directive_is_not_checked() raises:
    # `@a` applies only to objects, so Hive skips its arguments.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on OBJECT\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: String) on OBJECT\n\ntype'
                    " Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_a_directive_argument_missing_from_one_subgraph_is_not_checked() raises:
    # The argument must exist in every subgraph.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_hive_case_fa1() raises:
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
                    '","@context","@fromContext"])\ntype Query { f(x: Int):'
                    " String @shareable }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { f(x: Int):'
                    " String @shareable }"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { f(x: String):'
                    " String @shareable }"
                ),
            ),
        ],
        [
            (
                "[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument"
                ' "Query.f(x:)" is incompatible across subgraphs: it has'
                ' type "Int" in subgraphs "a", "b" but type "String" in'
                ' subgraph "c"'
            ),
        ],
    )


def test_hive_case_fa2() raises:
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
                    '","@context","@fromContext"])\ndirective @d(x: Int, y:'
                    " String) on FIELD\ntype Query { a: String }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ndirective @d(x: Int, y:'
                    " String) on FIELD\ntype Query { b: String }"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ndirective @d(x: Int, y:'
                    " String) on FIELD\ntype Query { c: String }"
                ),
            ),
            sg(
                "d",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ndirective @d(x: String, y:'
                    " String) on FIELD\ntype Query { d: String }"
                ),
            ),
            sg(
                "e",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ndirective @d(x: Boolean,'
                    " y: String) on FIELD\ntype Query { e: String }"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@d(x:)"'
                ' is incompatible across subgraphs: it has type "Int" in'
                ' subgraphs "a", "b", and "c" but type "String" in'
                ' subgraph "d" and type "Boolean" in subgraph "e"'
            ),
        ],
    )


def test_hive_case_fa3() raises:
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
                    '","@context","@fromContext"])\ndirective @d(x: Int) on'
                    " FIELD\ntype Query { a: String }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ndirective @d(x: Int) on'
                    " FIELD\ntype Query { b: String }"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ndirective @d(x: String) on'
                    " FIELD\ntype Query { c: String }"
                ),
            ),
        ],
        [
            (
                '[FIELD_ARGUMENT_TYPE_MISMATCH] Type of argument "@d(x:)"'
                ' is incompatible across subgraphs: it has type "Int" in'
                ' subgraphs "a" and "b" but type "String" in subgraph "c"'
            ),
        ],
    )


def test_hive_case_fa4_partial_directive() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    # Subgraph "c" defines no directive, so `@d` is not checked.
    comptime link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.9", import: ["@key"])\n'
    )
    check(
        [
            sg(
                "a",
                link
                + "directive @e on FIELD\ndirective @d(x: Int) on FIELD\n"
                + "type Query { a: String }",
            ),
            sg(
                "b",
                link
                + "directive @d(x: String) on FIELD\ntype Query { b: String }",
            ),
            sg("c", link + "type Query { c: String }"),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
