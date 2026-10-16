# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/EXTENSION_WITH_NO_BASE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_fed_v1_extension_with_no_base() raises:
    # v2.0 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_extension_with_no_base() raises:
    # v2.0 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_fed_v1_extension_with_no_base() raises:
    # v2.1 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_extension_with_no_base() raises:
    # v2.1 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_fed_v1_extension_with_no_base() raises:
    # v2.2 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_extension_with_no_base() raises:
    # v2.2 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_fed_v1_extension_with_no_base() raises:
    # v2.3 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_extension_with_no_base() raises:
    # v2.3 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_fed_v1_extension_with_no_base() raises:
    # v2.4 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_extension_with_no_base() raises:
    # v2.4 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_fed_v1_extension_with_no_base() raises:
    # v2.5 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_extension_with_no_base() raises:
    # v2.5 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_fed_v1_extension_with_no_base() raises:
    # v2.6 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_extension_with_no_base() raises:
    # v2.6 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_fed_v1_extension_with_no_base() raises:
    # v2.7 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_extension_with_no_base() raises:
    # v2.7 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_fed_v1_extension_with_no_base() raises:
    # v2.8 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_extension_with_no_base() raises:
    # v2.8 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_fed_v1_extension_with_no_base() raises:
    # v2.9 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend type Product @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String!\n}\n\nextend type Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Product @extends @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_extension_with_no_base() raises:
    # v2.9 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\nextend type Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n}\n\nextend type Product {\n  name: String\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@extends\", \"@external\"])\n\ntype Product @key(fields: \"id\") @extends {\n  id: ID! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type Product {\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@extends\"])\n\ntype Product @extends @key(fields: \"id\") {\n  id: ID!\n  reviews: [String]\n}\n\ntype Query {\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
