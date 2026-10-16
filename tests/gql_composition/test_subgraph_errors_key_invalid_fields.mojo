# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/KEY_INVALID_FIELDS.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_key_invalid_fields_syntax_error() raises:
    # v2.0 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_0_key_invalid_fields_unknown_directive() raises:
    # v2.0 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_0_key_invalid_fields_unknown_field() raises:
    # v2.0 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_1_key_invalid_fields_syntax_error() raises:
    # v2.1 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_1_key_invalid_fields_unknown_directive() raises:
    # v2.1 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_1_key_invalid_fields_unknown_field() raises:
    # v2.1 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_2_key_invalid_fields_syntax_error() raises:
    # v2.2 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_2_key_invalid_fields_unknown_directive() raises:
    # v2.2 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_2_key_invalid_fields_unknown_field() raises:
    # v2.2 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_3_key_invalid_fields_syntax_error() raises:
    # v2.3 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_3_key_invalid_fields_unknown_directive() raises:
    # v2.3 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_3_key_invalid_fields_unknown_field() raises:
    # v2.3 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_4_key_invalid_fields_syntax_error() raises:
    # v2.4 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_4_key_invalid_fields_unknown_directive() raises:
    # v2.4 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_4_key_invalid_fields_unknown_field() raises:
    # v2.4 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_5_key_invalid_fields_syntax_error() raises:
    # v2.5 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_5_key_invalid_fields_unknown_directive() raises:
    # v2.5 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_5_key_invalid_fields_unknown_field() raises:
    # v2.5 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_6_key_invalid_fields_syntax_error() raises:
    # v2.6 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_6_key_invalid_fields_unknown_directive() raises:
    # v2.6 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_6_key_invalid_fields_unknown_field() raises:
    # v2.6 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_7_key_invalid_fields_syntax_error() raises:
    # v2.7 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_7_key_invalid_fields_unknown_directive() raises:
    # v2.7 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_7_key_invalid_fields_unknown_field() raises:
    # v2.7 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_8_key_invalid_fields_syntax_error() raises:
    # v2.8 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_8_key_invalid_fields_unknown_directive() raises:
    # v2.8 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_8_key_invalid_fields_unknown_field() raises:
    # v2.8 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def test_v2_9_key_invalid_fields_syntax_error() raises:
    # v2.9 > KEY_INVALID_FIELDS: syntax error
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id\"): Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_v2_9_key_invalid_fields_unknown_directive() raises:
    # v2.9 > KEY_INVALID_FIELDS - unknown directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id name @lowercase \") {\n  id: ID!\n  name: String\n}\n\nextend type Query {\n  user(id: ID!): User\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [users] On type \"User\", for @key(fields: \"id name @lowercase \"): Unknown directive \"@lowercase\"",
        ],
    )


def test_v2_9_key_invalid_fields_unknown_field() raises:
    # v2.9 > KEY_INVALID_FIELDS: unknown field
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"skucha\") {\n  sku: String!\n}",
            ),
        ],
        [
            "[KEY_INVALID_FIELDS] [serviceA] On type \"Product\", for @key(fields: \"skucha\"): Cannot query field \"skucha\" on type \"Product\" (the field should either be added to this subgraph or, if it should not be resolved by this subgraph, you need to add it to this subgraph with @external).",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
