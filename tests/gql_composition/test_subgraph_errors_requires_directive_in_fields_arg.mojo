# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/REQUIRES_DIRECTIVE_IN_FIELDS_ARG.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_requires_directive_in_fields_arg() raises:
    # v2.0 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_1_requires_directive_in_fields_arg() raises:
    # v2.1 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_2_requires_directive_in_fields_arg() raises:
    # v2.2 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_3_requires_directive_in_fields_arg() raises:
    # v2.3 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_4_requires_directive_in_fields_arg() raises:
    # v2.4 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_5_requires_directive_in_fields_arg() raises:
    # v2.5 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_6_requires_directive_in_fields_arg() raises:
    # v2.6 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_7_requires_directive_in_fields_arg() raises:
    # v2.7 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_8_requires_directive_in_fields_arg() raises:
    # v2.8 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_9_requires_directive_in_fields_arg() raises:
    # v2.9 > REQUIRES_DIRECTIVE_IN_FIELDS_ARG
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\", \"@requires\"]) @link(url: \"https://myspecs.dev/testkit/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id name\") {\n  id: ID!\n  name: String\n  profile: Profile @requires(fields: \"name @lowercase\")\n}\n\ntype Profile {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[REQUIRES_DIRECTIVE_IN_FIELDS_ARG] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): cannot have directive applications in the @requires(fields:) argument but found @lowercase.",
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"name @lowercase\"): field \"User.name\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
