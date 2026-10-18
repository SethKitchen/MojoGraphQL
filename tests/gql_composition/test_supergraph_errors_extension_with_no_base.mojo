# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/EXTENSION_WITH_NO_BASE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `EXTENSION_WITH_NO_BASE` from
`composeServices` on the same subgraphs. A case that Hive accepts
expects an empty list. The last tests lock visitor order and the
Federation 2 exception. They are not in the upstream file.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_fed_v1_extension_with_no_base() raises:
    # v2.0 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_extension_with_no_base() raises:
    # v2.0 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_fed_v1_extension_with_no_base() raises:
    # v2.1 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_extension_with_no_base() raises:
    # v2.1 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_fed_v1_extension_with_no_base() raises:
    # v2.2 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_extension_with_no_base() raises:
    # v2.2 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_fed_v1_extension_with_no_base() raises:
    # v2.3 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_extension_with_no_base() raises:
    # v2.3 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_fed_v1_extension_with_no_base() raises:
    # v2.4 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_extension_with_no_base() raises:
    # v2.4 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_fed_v1_extension_with_no_base() raises:
    # v2.5 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_extension_with_no_base() raises:
    # v2.5 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_fed_v1_extension_with_no_base() raises:
    # v2.6 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_extension_with_no_base() raises:
    # v2.6 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_fed_v1_extension_with_no_base() raises:
    # v2.7 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_extension_with_no_base() raises:
    # v2.7 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_fed_v1_extension_with_no_base() raises:
    # v2.8 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_extension_with_no_base() raises:
    # v2.8 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_fed_v1_extension_with_no_base() raises:
    # v2.9 > Fed v1: EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'extend type Product @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}\n\ntype Query {\n  reviews:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [products] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    'type Product @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    " type Product {\n  name: String!\n}\n\nextend type Query"
                    " {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    'type Product @extends @key(fields: "id") {\n  id: ID!'
                    " @external\n  reviews: [String]\n}\n\ntype Query {\n "
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_extension_with_no_base() raises:
    # v2.9 > EXTENSION_WITH_NO_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}\n\nextend type Profile {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Profile" is an'
                ' extension type, but there is no type definition for "Profile"'
                " in any subgraph."
            ),
        ],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nextend type Product {\n  name:"
                    " String\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@extends", "@external"])\n\ntype Product'
                    ' @key(fields: "id") @extends {\n  id: ID! @external\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\nextend type Product {\n  inStock:"
                    " Boolean!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                "type Query {\n  reviews: [String]\n}",
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  products: [Product]\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@extends"])\n\ntype Product @extends'
                    ' @key(fields: "id") {\n  id: ID!\n  reviews:'
                    " [String]\n}\n\ntype Query {\n  reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_federation_2_extensions_in_two_graphs() raises:
    # Two Federation 2 subgraphs. `@extends` is not the exception.
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend type Widget {\n  name:'
                    " String\n}\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend type Widget {\n  price:'
                    " Int\n}\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [reviews] Type "Widget" is an'
                ' extension type, but there is no type definition for "Widget"'
                " in any subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Widget" is an extension'
                ' type, but there is no type definition for "Widget" in any'
                " subgraph."
            ),
        ],
    )


def test_root_type_names_are_skipped() raises:
    # Query, Mutation and Subscription do not need a base definition.
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend type Query {\n  q: Int\n}\n\nextend'
                    " type Mutation {\n  y: Int\n}\n\nextend type Subscription"
                    " {\n  z: Int\n}\n\nextend type Product {\n  id: ID\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )


def test_extension_error_follows_earlier_field_errors() raises:
    # Hive visits Query before Product, so the field errors come first.
    check(
        [
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Int\n}\n\ntype User {\n '
                    " name: String\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  a: String\n}\n\nextend type'
                    " Product {\n  id: ID\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.a" is incompatible'
                ' across subgraphs: it has type "Int" in subgraph "reviews" but'
                ' type "String" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.a" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "reviews" and "users" and defined as non-shareable'
                " in all of them"
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Product" is an'
                ' extension type, but there is no type definition for "Product"'
                " in any subgraph."
            ),
        ],
    )


def test_two_extension_types_keep_source_order() raises:
    # Zebra is declared before Apple, so its error comes first.
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend type Zebra {\n  a: Int\n}\n\nextend'
                    " type Apple {\n  b: Int\n}\n\ntype Query {\n  q: Int\n}"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Zebra" is an extension'
                ' type, but there is no type definition for "Zebra" in any'
                " subgraph."
            ),
            (
                '[EXTENSION_WITH_NO_BASE] [users] Type "Apple" is an extension'
                ' type, but there is no type definition for "Apple" in any'
                " subgraph."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
