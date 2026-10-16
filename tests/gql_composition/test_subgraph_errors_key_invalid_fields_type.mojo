# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/KEY_INVALID_FIELDS_TYPE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_() raises:
    # 
    check(
        [
            sg(
                "a",
                "type User @key(fields: [\"id\", \"uuid\"]) {\n  id: ID!\n  uuid: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_invalid_fields_type() raises:
    # v2.0 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_1_key_invalid_fields_type() raises:
    # v2.1 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_2_key_invalid_fields_type() raises:
    # v2.2 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_3_key_invalid_fields_type() raises:
    # v2.3 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_4_key_invalid_fields_type() raises:
    # v2.4 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_5_key_invalid_fields_type() raises:
    # v2.5 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_6_key_invalid_fields_type() raises:
    # v2.6 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_7_key_invalid_fields_type() raises:
    # v2.7 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_8_key_invalid_fields_type() raises:
    # v2.8 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def test_v2_9_key_invalid_fields_type() raises:
    # v2.9 > KEY_INVALID_FIELDS_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User!]!\n}\n\ntype User @key(fields: true) {\n  id: ID\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS_TYPE] [users] On type \"User\", for @key(fields: true): Invalid value for argument \"fields\": must be a string.",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
