# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/TYPE_DEFINITION_INVALID.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_type_definition_invalid() raises:
    # v2.0 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_1_type_definition_invalid() raises:
    # v2.1 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_2_type_definition_invalid() raises:
    # v2.2 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_3_type_definition_invalid() raises:
    # v2.3 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_4_type_definition_invalid() raises:
    # v2.4 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_5_type_definition_invalid() raises:
    # v2.5 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_6_type_definition_invalid() raises:
    # v2.6 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_7_type_definition_invalid() raises:
    # v2.7 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_8_type_definition_invalid() raises:
    # v2.8 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def test_v2_9_type_definition_invalid() raises:
    # v2.9 > TYPE_DEFINITION_INVALID
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"FieldSet\"])\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ninput FieldSet {\n  fields: [String!]!\n}\n\ntype User @key(fields: \"id name \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type FieldSet: FieldSet should be a ScalarType but is defined as a InputObjectType",
            "[INVALID_GRAPHQL] [users] Invalid value for \"@key(fields:)\" of type \"FieldSet!\" in application of \"@key\" to \"User\".",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
