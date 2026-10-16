# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/KEY_DIRECTIVE_IN_FIELDS_ARG.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_key_directive_in_fields_arg() raises:
    # v2.0 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_1_key_directive_in_fields_arg() raises:
    # v2.1 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def test_v2_2_key_directive_in_fields_arg() raises:
    # v2.2 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def test_v2_3_key_directive_in_fields_arg() raises:
    # v2.3 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def test_v2_4_key_directive_in_fields_arg() raises:
    # v2.4 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def test_v2_5_key_directive_in_fields_arg() raises:
    # v2.5 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def test_v2_6_key_directive_in_fields_arg() raises:
    # v2.6 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def test_v2_7_key_directive_in_fields_arg() raises:
    # v2.7 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def test_v2_8_key_directive_in_fields_arg() raises:
    # v2.8 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def test_v2_9_key_directive_in_fields_arg() raises:
    # v2.9 > KEY_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_DIRECTIVE_IN_FIELDS_ARG] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): cannot have directive applications in the @key(fields:) argument but found @lowercase.",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
